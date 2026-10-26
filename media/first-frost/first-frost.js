// First Frost — ice crystals creeping across a windowpane.
// Plain Canvas 2D, no library, no CDN. 960x540.
//
// The mechanic: the frame buffer is never cleared. Every crystal drawn stays
// drawn, so the picture is an accumulation rather than a render — what you see
// is the whole history of the growth, oldest at the cold metal, newest at the
// tips. That is the one thing this medium has that SVG, ASCII and the carts
// do not: memory.
//
// Growth is a spine-and-rib model, which is how ice actually forms on glass.
// A nucleus on cold metal puts out a spine; the spine puts out ribs at about
// sixty degrees; ribs put out shorter ribs. Length, width and brightness fall
// with each generation, so the fronds thin out toward their tips and leave the
// middle of each pane clear.
//
// The colour is not an overlay. Every crystal takes its brightness from how
// deep in the frond it is and its warmth from how close it is to the lamp
// behind the glass.
//
// Query param ?still=1 grows the whole thing at once and stops, so the preview
// image is deterministic.

(function () {
  'use strict';

  var W = 960, H = 540;
  var SEED = 20261026;

  var BARW = 12;
  var LAMP = { x: W * 0.63, y: H * 0.68, r: 430 };

  // ---- deterministic RNG (mulberry32) ------------------------------------
  var _s = SEED >>> 0;
  function rnd() {
    _s = (_s + 0x6D2B79F5) | 0;
    var t = Math.imul(_s ^ (_s >>> 15), 1 | _s);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  }

  var canvas, ctx;
  var stamps = [];       // flat queue: x, y, size, tier, lightstep
  var revealed = 0;
  var paused = false;
  var REVEAL_AT_OPEN = 0.62;   // fraction already on the glass at first paint

  // ---- palette -----------------------------------------------------------
  var PAL = [];
  var TIERS = [
    [[243, 251, 255], [255, 247, 228]],   // 0 crystal tip, catches the light
    [[196, 219, 234], [247, 226, 196]],   // 1 spine
    [[150, 178, 199], [228, 198, 162]]    // 2 packed mass near the metal
  ];
  var JIT = 8, STEPS = 25;

  function buildPalette() {
    for (var t2 = 0; t2 < 3; t2++) {
      var cool = TIERS[t2][0], warm = TIERS[t2][1];
      var out = [];
      for (var s = 0; s < STEPS; s++) {
        var f = s / (STEPS - 1);
        var r = cool[0] + (warm[0] - cool[0]) * f;
        var g = cool[1] + (warm[1] - cool[1]) * f;
        var b = cool[2] + (warm[2] - cool[2]) * f;
        var row = [];
        for (var j = 0; j < JIT; j++) {
          var k = 0.90 + (j / (JIT - 1)) * 0.18;
          row.push('rgb(' + Math.round(r * k) + ',' + Math.round(g * k) + ',' +
                             Math.round(b * k) + ')');
        }
        out.push(row);
      }
      PAL.push(out);
    }
  }

  function lightAt(x, y) {
    var dx = (x - LAMP.x) / LAMP.r, dy = (y - LAMP.y) / LAMP.r;
    var v = Math.exp(-(dx * dx + dy * dy) * 0.72);
    return v > 1 ? 1 : v;
  }

  // ---- the glass ---------------------------------------------------------
  function paintGlass(g) {
    var y, t;
    for (y = 0; y < H; y++) {
      t = y / (H - 1);
      g.fillStyle = 'rgb(' + Math.round(5 + t * 5) + ',' +
                              Math.round(9 + t * 8) + ',' +
                              Math.round(18 + t * 12) + ')';
      g.fillRect(0, y, W, 1);
    }

    var i;
    for (i = 26; i >= 1; i--) {
      var rr = LAMP.r * (i / 26);
      var a = 0.030 * (1 - i / 26) + 0.008;
      var grd = g.createRadialGradient(LAMP.x, LAMP.y, 0, LAMP.x, LAMP.y, rr);
      grd.addColorStop(0, 'rgba(255,186,104,' + (a * 1.5).toFixed(4) + ')');
      grd.addColorStop(0.55, 'rgba(196,120,58,' + (a * 0.9).toFixed(4) + ')');
      grd.addColorStop(1, 'rgba(120,70,40,0)');
      g.fillStyle = grd;
      g.beginPath();
      g.arc(LAMP.x, LAMP.y, rr, 0, Math.PI * 2);
      g.fill();
    }

    var core = g.createRadialGradient(LAMP.x, LAMP.y, 0, LAMP.x, LAMP.y, 132);
    core.addColorStop(0, 'rgba(255,208,144,0.32)');
    core.addColorStop(0.35, 'rgba(214,140,72,0.15)');
    core.addColorStop(1, 'rgba(120,70,40,0)');
    g.fillStyle = core;
    g.beginPath();
    g.arc(LAMP.x, LAMP.y, 132, 0, Math.PI * 2);
    g.fill();

    var cx = W / 2, cy = H / 2;
    g.fillStyle = '#232a38';
    g.fillRect(cx - BARW / 2, 0, BARW, H);
    g.fillRect(0, cy - BARW / 2, W, BARW);
    g.fillStyle = 'rgba(126,146,176,0.15)';
    g.fillRect(cx - BARW / 2, 0, 1, H);
    g.fillRect(cx + BARW / 2 - 1, 0, 1, H);
    g.fillRect(0, cy - BARW / 2, W, 1);
    g.fillRect(0, cy + BARW / 2 - 1, W, 1);

    g.fillStyle = 'rgba(0,0,0,0.5)';
    g.fillRect(0, 0, W, 5);
    g.fillRect(0, H - 5, W, 5);
    g.fillRect(0, 0, 5, H);
    g.fillRect(W - 5, 0, 5, H);
  }

  // ---- growth ------------------------------------------------------------
  function pushStamp(x, y, size, tier) {
    if (x < 2 || y < 2 || x > W - 3 || y > H - 3) return;
    stamps.push(x, y, size, tier, Math.round(lightAt(x, y) * (STEPS - 1)));
  }

  // One frond generation. The spine curves slightly and tapers; ribs come off
  // in matched pairs every few pixels at roughly sixty degrees — the angle
  // hexagonal ice actually branches at — and each pair is shorter than the
  // pair before it, which is what turns a spine into a feather rather than
  // into a comb.
  function frond(x, y, ang, len, width, tier, depth) {
    var i, side, t, w, rib, ra, k;
    var curve = (rnd() - 0.5) * 0.035;

    for (i = 0; i < len; i++) {
      ang += curve + (rnd() - 0.5) * 0.03;
      x += Math.cos(ang) * 1.15;
      y += Math.sin(ang) * 1.15;

      t = i / len;
      w = Math.max(1, Math.round(width * (1 - t * 0.6)));
      pushStamp(x, y, w, t > 0.5 ? Math.min(tier, 0) : tier);

      if (depth > 0 && i > 2 && (i % 3) === 0) {
        rib = len * 0.36 * (1 - t * 0.88);
        if (rib > 3) {
          for (side = -1; side <= 1; side += 2) {
            k = 1 + (rnd() - 0.5) * 0.18;
            ra = ang + side * (0.80 + rnd() * 0.46) * k;
            frond(x, y, ra, rib, Math.max(1, w - 1),
                  Math.min(2, tier + 1), depth - 1);
          }
        }
      }
    }
  }

  // A nucleus: two to four feathers fanned across `spread`, all pointing away
  // from the metal they started on.
  var nuclei = 0;
  function nucleus(x, y, ang, spread, len) {
    var n = 2 + ((rnd() * 3) | 0), i, r;
    nuclei++;

    // the root: a few packed crystals where the frond meets cold metal, so
    // every feather is visibly attached to something
    pushStamp(x, y, 5, 2);
    for (r = 0; r < 5; r++) {
      pushStamp(x + (rnd() - 0.5) * 7, y + (rnd() - 0.5) * 7,
                2 + ((rnd() * 3) | 0), 2);
    }
    for (i = 0; i < n; i++) {
      var a = ang + (i / ((n - 1) || 1) - 0.5) * spread + (rnd() - 0.5) * 0.22;
      frond(x, y, a, len * (0.7 + rnd() * 0.5), 3, 1, 1);
    }
  }

  // Cold metal: the sill, the muntin bars, the jambs, the corners. Frost
  // starts where the frame pulls heat out of the glass, so the seeds are all
  // on the frame side of the pane and every frond grows inward.
  function seedWindow() {
    var i, x, y;
    var HALF = Math.PI / 2;

    // sill — the densest edge, fronds standing up into the panes
    for (i = 0; i < 26; i++) {
      x = 8 + rnd() * (W - 16);
      nucleus(x, H - 6 - rnd() * 8, -HALF + (rnd() - 0.5) * 0.7,
              0.9, 55 + rnd() * 75);
    }
    // head of the window — sparser, hanging down
    for (i = 0; i < 13; i++) {
      x = 8 + rnd() * (W - 16);
      nucleus(x, 6 + rnd() * 8, HALF + (rnd() - 0.5) * 0.7, 0.9, 40 + rnd() * 55);
    }
    // jambs
    for (i = 0; i < 9; i++) {
      y = rnd() * (H * 0.45);
      nucleus(7 + rnd() * 6, y, (rnd() - 0.5) * 0.5, 0.8, 32 + rnd() * 48);
      nucleus(W - 7 - rnd() * 6, y, Math.PI + (rnd() - 0.5) * 0.5, 0.8, 32 + rnd() * 48);
    }
    // vertical bar, both faces, evenly spaced so the frost runs along it
    for (i = 0; i < 14; i++) {
      y = 14 + i * ((H - 28) / 13);
      if (Math.abs(y - H / 2) < 26) continue;
      if (rnd() < 0.3) continue;
      nucleus(W / 2 - BARW / 2 - 1, y, Math.PI + (rnd() - 0.5) * 0.6, 0.8, 28 + rnd() * 44);
      nucleus(W / 2 + BARW / 2 + 1, y, (rnd() - 0.5) * 0.6, 0.8, 28 + rnd() * 44);
    }
    // horizontal bar, both faces
    for (i = 0; i < 24; i++) {
      x = 14 + i * ((W - 28) / 23);
      if (Math.abs(x - W / 2) < 26) continue;
      if (rnd() < 0.3) continue;
      nucleus(x, H / 2 - BARW / 2 - 1, -HALF + (rnd() - 0.5) * 0.6, 0.8, 26 + rnd() * 38);
      nucleus(x, H / 2 + BARW / 2 + 1, HALF + (rnd() - 0.5) * 0.6, 0.8, 26 + rnd() * 38);
    }
  }

  function nucleusAt(px, py) {
    nucleus(px, py, rnd() * Math.PI * 2, 0.9, 60 + rnd() * 50);
  }

  // ---- drawing -----------------------------------------------------------
  function stamp(x, y, size, tier, ls) {
    var j = (rnd() * JIT) | 0;
    ctx.fillStyle = PAL[tier][ls][j];
    ctx.fillRect(x - size / 2, y - size / 2, size, size);
    if (size > 1) {
      ctx.globalAlpha = 0.045;
      ctx.fillStyle = '#dceaf7';
      ctx.fillRect(x - size, y - size, size * 2, size * 2);
      ctx.globalAlpha = 1;
    }
  }

  function reveal(n) {
    var end = Math.min(revealed + n * 5, stamps.length);
    for (var i = revealed; i < end; i += 5) {
      stamp(stamps[i], stamps[i + 1], stamps[i + 2], stamps[i + 3], stamps[i + 4]);
    }
    revealed = end;
  }

  // ---- boot --------------------------------------------------------------
  function boot() {
    canvas = document.getElementById('frost');
    ctx = canvas.getContext('2d');
    canvas.width = W;
    canvas.height = H;

    buildPalette();
    paintGlass(ctx);

    var still = /(\?|&)still=1/.test(location.search);

    seedWindow();
    var total = stamps.length / 5;

    if (still) {
      reveal(total);
    } else {
      reveal(Math.floor(total * REVEAL_AT_OPEN));
      var last = performance.now(), acc = 0;
      function frame(now) {
        acc += now - last;
        last = now;
        if (!paused && revealed < stamps.length) {
          // finish the last forty percent over about fifteen seconds
          reveal(Math.max(1, Math.round((stamps.length - revealed) / 5 / 900)));
        }
        requestAnimationFrame(frame);
      }
      requestAnimationFrame(frame);
    }

    // A cold veil over the whole pane. Real frost is not only the feathers —
    // the glass between them is frosted too, faintly, which is what keeps the
    // fronds from looking like separate stickers.
    var veil = 150;
    [[0, 0, 0, 1], [0, H, 0, -1], [0, 0, 1, 0], [W, 0, -1, 0]].forEach(function (e) {
      var g2 = ctx.createLinearGradient(e[0], e[1], e[0] + e[2] * veil, e[1] + e[3] * veil);
      g2.addColorStop(0, 'rgba(188,214,236,0.085)');
      g2.addColorStop(1, 'rgba(188,214,236,0)');
      ctx.fillStyle = g2;
      ctx.fillRect(0, 0, W, H);
    });

    // One bloom pass: the glass scatters light through the ice, so the mass
    // sits in a faint halo instead of stopping at a hard edge.
    ctx.save();
    ctx.globalAlpha = 0.30;
    ctx.filter = 'blur(5px)';
    ctx.drawImage(canvas, 0, 0);
    ctx.restore();

    canvas.dataset.crystals = String(Math.floor(revealed / 5));
    canvas.dataset.nuclei = String(nuclei);
  }

  window.addEventListener('DOMContentLoaded', function () {
    boot();

    document.getElementById('frost').addEventListener('click', function (e) {
      var r = this.getBoundingClientRect();
      var px = (e.clientX - r.left) * (W / r.width);
      var py = (e.clientY - r.top) * (H / r.height);
      var before = stamps.length;
      nucleusAt(px, py);
      // the new frond appears at once rather than waiting its turn
      revealed = before;
      reveal((stamps.length - before) / 5);
      canvas.dataset.crystals = String(Math.floor(revealed / 5));
    });

    document.addEventListener('keydown', function (e) {
      if (e.key === ' ') {
        e.preventDefault();
        paused = !paused;
        document.getElementById('hint-state').textContent = paused ? 'growth paused' : 'growing';
      }
      if (e.key === 's') {
        var a = document.createElement('a');
        a.download = 'first-frost.png';
        a.href = canvas.toDataURL('image/png');
        a.click();
      }
      if (e.key === 'r') location.reload();
    });
  });
})();
