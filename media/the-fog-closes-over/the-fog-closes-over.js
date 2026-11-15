/* The Fog Closes Over — Cass Gallery piece #109
   Plain Canvas 2D. No library.

   A fogged window at night with a sodium-lit street behind it. Wipe a hole
   in the condensation and the street comes through; let go and the fog
   closes back over it.

   The fog is a real field: a half-resolution density buffer that
   re-condenses toward saturation, diffuses a little every frame, and is
   wiped along the pointer path. The picture is that field mixed into the
   defocused street behind the glass — so the warmth you see through a wipe
   is the street, not the wipe. */

(function () {
  'use strict';

  var W = 960, H = 540;
  var canvas = document.getElementById('fog');
  if (!canvas) return;
  var ctx = canvas.getContext('2d', { alpha: false });

  var params = new URLSearchParams(location.search);
  var STILL = params.get('still') === '1';
  function q(k, d) {
    var v = params.get(k);
    return v === null ? d : parseFloat(v);
  }

  function mulberry32(a) {
    return function () {
      a |= 0; a = a + 0x6D2B79F5 | 0;
      var t = Math.imul(a ^ a >>> 15, 1 | a);
      t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t;
      return ((t ^ t >>> 14) >>> 0) / 4294967296;
    };
  }
  var rnd = mulberry32(20261115);

  // ============================================================= the street
  // Behind the glass: houses, one street lamp, a wet road, a parked car.
  // Deliberately warm and deliberately out of focus — the fog has to have
  // something worth hiding.
  var viewCv = document.createElement('canvas');
  viewCv.width = W; viewCv.height = H;
  var vctx = viewCv.getContext('2d');
  var viewData = null;

  function litWindow(x, y, w, h, col, glow) {
    var g = vctx.createRadialGradient(x + w / 2, y + h / 2, 2, x + w / 2, y + h / 2, w * 3.0);
    g.addColorStop(0, 'rgba(' + col + ',' + glow + ')');
    g.addColorStop(0.28, 'rgba(' + col + ',' + (glow * 0.30).toFixed(3) + ')');
    g.addColorStop(1, 'rgba(' + col + ',0)');
    vctx.fillStyle = g;
    vctx.fillRect(x - w * 3, y - h * 3, w * 7, h * 7);
    vctx.fillStyle = 'rgb(' + col + ')';
    vctx.fillRect(x, y, w, h);
    vctx.fillStyle = 'rgba(34,20,9,0.5)';
    vctx.fillRect(x + w * 0.46, y, w * 0.07, h);
    vctx.fillRect(x, y + h * 0.44, w, h * 0.08);
  }

  function bakeView() {
    vctx.fillStyle = '#0a0a0c';
    vctx.fillRect(0, 0, W, H);

    // sky
    var sky = vctx.createLinearGradient(0, 0, 0, 250);
    sky.addColorStop(0, '#1e222a');
    sky.addColorStop(0.7, '#2b2a2a');
    sky.addColorStop(1, '#2a2318');
    vctx.fillStyle = sky;
    vctx.fillRect(0, 0, W, 252);

    // the houses opposite
    vctx.fillStyle = '#241c14';
    vctx.beginPath();
    vctx.moveTo(-10, 268); vctx.lineTo(-10, 198); vctx.lineTo(112, 180);
    vctx.lineTo(238, 200); vctx.lineTo(332, 178); vctx.lineTo(432, 202);
    vctx.lineTo(520, 188); vctx.lineTo(642, 206); vctx.lineTo(762, 186);
    vctx.lineTo(882, 208); vctx.lineTo(970, 198); vctx.lineTo(970, 268);
    vctx.closePath();
    vctx.fill();

    litWindow(96, 208, 42, 46, '252,212,150', 0.60);
    litWindow(706, 216, 30, 34, '244,198,140', 0.40);

    // road
    var road = vctx.createLinearGradient(0, 300, 0, H);
    road.addColorStop(0, '#41301c');
    road.addColorStop(0.32, '#3a2a17');
    road.addColorStop(1, '#2a1e11');
    vctx.fillStyle = road;
    vctx.fillRect(0, 300, W, H - 300);

    // sodium wash off the wet surface
    var wash = vctx.createRadialGradient(360, 372, 30, 360, 372, 660);
    wash.addColorStop(0, 'rgba(255,190,110,0.44)');
    wash.addColorStop(0.42, 'rgba(238,158,78,0.22)');
    wash.addColorStop(1, 'rgba(180,112,44,0.03)');
    vctx.fillStyle = wash;
    vctx.fillRect(0, 252, W, H - 252);

    // kerb: the horizon of the piece, and the line the wipe will cross
    vctx.fillStyle = 'rgba(255,224,172,0.32)';
    vctx.fillRect(0, 350, W, 3);
    vctx.fillStyle = 'rgba(20,13,7,0.6)';
    vctx.fillRect(0, 353, W, 6);
    vctx.fillStyle = 'rgba(255,214,158,0.12)';
    vctx.fillRect(0, 359, W, 22);

    // the lamp
    var lampX = 330, headY = 206;
    vctx.fillStyle = '#1b1610';
    vctx.fillRect(lampX - 4, headY, 8, 250);
    vctx.fillStyle = '#221b13';
    vctx.beginPath();
    vctx.ellipse(lampX, headY - 3, 19, 8, 0, 0, Math.PI * 2);
    vctx.fill();
    var lg = vctx.createRadialGradient(lampX, headY + 8, 0, lampX, headY + 8, 98);
    lg.addColorStop(0, 'rgba(255,246,222,1)');
    lg.addColorStop(0.05, 'rgba(255,232,186,0.95)');
    lg.addColorStop(0.20, 'rgba(255,204,138,0.34)');
    lg.addColorStop(0.55, 'rgba(240,172,100,0.09)');
    lg.addColorStop(1, 'rgba(220,150,90,0)');
    vctx.fillStyle = lg;
    vctx.fillRect(lampX - 110, headY - 92, 220, 220);
    var lr = vctx.createLinearGradient(0, 352, 0, 500);
    lr.addColorStop(0, 'rgba(255,214,160,0.42)');
    lr.addColorStop(0.5, 'rgba(255,196,140,0.15)');
    lr.addColorStop(1, 'rgba(255,180,120,0)');
    vctx.fillStyle = lr;
    vctx.fillRect(lampX - 22, 352, 44, 148);

    // the car
    vctx.fillStyle = '#1a1510';
    vctx.beginPath();
    vctx.moveTo(618, 372); vctx.lineTo(646, 330); vctx.lineTo(760, 322);
    vctx.lineTo(806, 362); vctx.lineTo(852, 370); vctx.lineTo(852, 400);
    vctx.lineTo(618, 400); vctx.closePath();
    vctx.fill();
    vctx.fillStyle = 'rgba(255,214,168,0.15)';
    vctx.beginPath();
    vctx.moveTo(654, 332); vctx.lineTo(756, 326); vctx.lineTo(786, 356);
    vctx.lineTo(670, 360); vctx.closePath();
    vctx.fill();
    vctx.fillStyle = 'rgba(255,120,70,0.5)';
    vctx.fillRect(838, 372, 13, 8);
    vctx.fillStyle = '#0e0b08';
    vctx.beginPath(); vctx.arc(668, 400, 17, 0, Math.PI * 2); vctx.fill();
    vctx.beginPath(); vctx.arc(812, 400, 17, 0, Math.PI * 2); vctx.fill();

    // bin and bollard
    vctx.fillStyle = '#191410';
    vctx.fillRect(512, 318, 34, 44);
    vctx.fillStyle = 'rgba(255,206,150,0.10)';
    vctx.fillRect(512, 318, 34, 4);
    vctx.fillStyle = '#221a12';
    vctx.fillRect(196, 322, 9, 40);

    // defocus
    var soft = document.createElement('canvas');
    soft.width = W; soft.height = H;
    var s2 = soft.getContext('2d');
    s2.filter = 'blur(' + q('blur', 2.4) + 'px)';
    s2.drawImage(viewCv, 0, 0);
    s2.filter = 'none';
    vctx.clearRect(0, 0, W, H);
    vctx.drawImage(soft, 0, 0);

    viewData = vctx.getImageData(0, 0, W, H).data;
  }

  // ================================================================== fog
  var FW = W >> 1, FH = H >> 1;
  var dens = new Float32Array(FW * FH);
  var dens2 = new Float32Array(FW * FH);

  var fogR = new Float32Array(W * H);
  var fogG = new Float32Array(W * H);
  var fogB = new Float32Array(W * H);

  function bakeFogColour() {
    for (var y = 0; y < H; y++) {
      for (var x = 0; x < W; x++) {
        var i = y * W + x;
        // thickness: three incommensurate waves, so the mottling never repeats
        var t = Math.sin(x * 0.0113 + 0.7) * Math.cos(y * 0.0091 + 1.9) +
                0.5 * Math.sin(x * 0.0291 + 2.3) * Math.cos(y * 0.0233 + 0.4) +
                0.25 * Math.sin(x * 0.0537 + 4.1) * Math.cos(y * 0.0471 + 3.2);
        var base = 1 + 0.150 * t;
        base *= 0.95 + 0.12 * (y / H);      // condensation gathers low
        // vignette: the pane is lit from the street, so its corners fall away
        var vx2 = (x - W / 2) / (W / 2), vy2 = (y - H / 2) / (H / 2);
        base *= 1 - 0.30 * Math.min(1, (vx2 * vx2 + vy2 * vy2) * 0.55);
        var r = 84 * base, g = 95 * base, b = 108 * base;
        // light bleeding through the fog near the lamp, which is the one thing
        // that makes a fogged pane look lit rather than painted
        var bx = (x - 330) / 260, by = (y - 214) / 260;
        var bl = Math.exp(-(bx * bx + by * by) * 2.2);
        r += 40 * bl; g += 24 * bl; b += 6 * bl;
        fogR[i] = r; fogG[i] = g; fogB[i] = b;
      }
    }
  }

  function addBeads() {
    // Condensation is a bead field, not a wash. Beads are lenses: a slightly
    // darker rim with a lighter centre. At card size this is only texture.
    for (var b = 0; b < 1400; b++) {
      var cx = rnd() * W, cy = rnd() * H;
      var r = 1.6 + rnd() * 3.2;
      var x0 = Math.max(0, Math.floor(cx - r * 2)), x1 = Math.min(W - 1, Math.ceil(cx + r * 2));
      var y0 = Math.max(0, Math.floor(cy - r * 2)), y1 = Math.min(H - 1, Math.ceil(cy + r * 2));
      for (var y = y0; y <= y1; y++) {
        for (var x = x0; x <= x1; x++) {
          var dx = (x - cx) / r, dy = (y - cy) / r;
          var dd = Math.sqrt(dx * dx + dy * dy);
          if (dd > 2) continue;
          var i = y * W + x;
          var k;
          if (dd < 0.5) k = 0.026;
          else if (dd < 1.1) k = -0.018;
          else k = 0.007;
          fogR[i] *= 1 + k;
          fogG[i] *= 1 + k;
          fogB[i] *= 1 + k * 0.9;
        }
      }
    }
  }

  function buildDensity() {
    var i;
    for (i = 0; i < dens.length; i++) dens[i] = 1;
    // runnels: where water has already run down the glass
    var runnels = [
      { x0: 168, x1: 182, w: 13 },
      { x0: 604, x1: 588, w: 10 },
      { x0: 812, x1: 824, w: 8 }
    ];
    for (i = 0; i < runnels.length; i++) {
      var R = runnels[i];
      var y0 = 16 + rnd() * 130;
      var y1 = y0 + 130 + rnd() * 210;
      for (var y = Math.floor(y0); y < Math.min(FH, y1); y++) {
        var t = (y - y0) / (y1 - y0);
        var xc = (R.x0 + (R.x1 - R.x0) * t) / 2;
        for (var dx = -R.w; dx <= R.w; dx++) {
          var gx = Math.floor(xc + dx);
          if (gx < 0 || gx >= FW) continue;
          var fall = 1 - Math.abs(dx) / (R.w + 1);
          dens[y * FW + gx] *= 1 - 0.24 * fall * fall;
        }
      }
    }
  }

  // ============================================================== physics
  var REGROW = q('regrow', 0.085);
  var DIFFUSE = 0.055;

  function stepFog(dt) {
    var y, x, i;
    for (y = 0; y < FH; y++) {
      var row = y * FW;
      for (x = 0; x < FW; x++) {
        i = row + x;
        var l = dens[i - (x > 0 ? 1 : 0)];
        var r = dens[i + (x < FW - 1 ? 1 : 0)];
        var u = dens[i - (y > 0 ? FW : 0)];
        var d = dens[i + (y < FH - 1 ? FW : 0)];
        dens2[i] = dens[i] + DIFFUSE * (0.25 * (l + r + u + d) - dens[i]);
      }
    }
    var grow = REGROW * dt;
    for (i = 0; i < dens.length; i++) {
      var dd = dens2[i];
      // a thin film stays clear longer than a thick one, which is what glass
      // actually does — the wipe's own edge is the last thing to close
      dd += grow * (0.30 + 0.95 * dd) * (1 - dd);
      dens[i] = dd > 1 ? 1 : dd;
    }
  }

  var BRUSH = q('brush', 96);

  function wipe(x, y, radius, amount) {
    var cx = x / 2, cy = y / 2, rad = radius / 2;
    var x0 = Math.max(0, Math.floor(cx - rad * 1.9));
    var x1 = Math.min(FW - 1, Math.ceil(cx + rad * 1.9));
    var y0 = Math.max(0, Math.floor(cy - rad * 1.9));
    var y1 = Math.min(FH - 1, Math.ceil(cy + rad * 1.9));
    for (var yy = y0; yy <= y1; yy++) {
      for (var xx = x0; xx <= x1; xx++) {
        var dx = xx - cx, dy = yy - cy;
        var ang = Math.atan2(dy, dx);
        var rag = 1 + 0.07 * Math.sin(ang * 5 + 0.8) + 0.035 * Math.sin(ang * 9 + 2.6) +
                  0.018 * Math.sin(ang * 15 + 4.7);
        var dd = Math.sqrt(dx * dx + dy * dy) / (rad * rag);
        if (dd > 1.9) continue;
        var i = yy * FW + xx;
        if (dd < 1.0) {
          var fall = 1 - dd * dd * 0.55;
          dens[i] -= amount * fall;
          if (dens[i] < 0) dens[i] = 0;
        } else {
          // what the finger clears is pushed to the rim, which is the whole
          // difference between wiped glass and a stroke of paint
          var push = (1.9 - dd) / 0.9;
          dens[i] += amount * 0.15 * push * push;
          if (dens[i] > 1) dens[i] = 1;
        }
      }
    }
  }

  // ================================================================ frame
  // The pane has to be *in* something. A casement frame in front of the glass
  // is the cue that turns a fogged field into a window.
  var frameCv = document.createElement('canvas');
  frameCv.width = W; frameCv.height = H;

  function bakeFrame() {
    var f = frameCv.getContext('2d');
    var B = 30;                      // frame width
    var MULX = 690, MULW = 26;       // the vertical mullion

    function bar(x, y, w, h) {
      var g = f.createLinearGradient(x, y, x + w, y + h);
      g.addColorStop(0, '#241d16');
      g.addColorStop(0.45, '#191410');
      g.addColorStop(1, '#0f0c09');
      f.fillStyle = g;
      f.fillRect(x, y, w, h);
    }
    bar(0, 0, W, B);                       // head
    bar(0, H - B, W, B);                   // sill
    bar(0, 0, B, H);                       // left stile
    bar(W - B, 0, B, H);                   // right stile
    bar(MULX, 0, MULW, H);                 // mullion

    // the paint catching the street light, on the pane side of each bar
    function edge(x, y, w, h) {
      var g = f.createLinearGradient(x, y, x, y + h);
      g.addColorStop(0, 'rgba(255,196,132,0.20)');
      g.addColorStop(1, 'rgba(255,190,120,0.02)');
      f.fillStyle = g;
      f.fillRect(x, y, w, h);
    }
    edge(MULX + MULW, 0, 3, H);
    edge(B, B, 3, H - B * 2);
    edge(B, H - B - 3, W - B * 2, 3);

    // shadow the frame casts on the glass
    f.fillStyle = 'rgba(0,0,0,0.34)';
    f.fillRect(MULX - 5, 0, 5, H);
    f.fillRect(0, B, W, 4);
  }

  // =============================================================== render
  var out = ctx.createImageData(W, H);

  function render() {
    var d = out.data, vd = viewData;
    for (var y = 0; y < H; y++) {
      var f0 = (y >> 1) * FW;
      var f1 = Math.min(FH - 1, (y >> 1) + 1) * FW;
      var rowv = y * W;
      for (var x = 0; x < W; x++) {
        var fx = x >> 1;
        var f = (dens[f0 + fx] + dens[f1 + fx]) * 0.5;
        if (f > 1) f = 1;
        var k = (rowv + x) << 2;
        var fm = rowv + x;
        d[k] = vd[k] + (fogR[fm] - vd[k]) * f;
        d[k + 1] = vd[k + 1] + (fogG[fm] - vd[k + 1]) * f;
        d[k + 2] = vd[k + 2] + (fogB[fm] - vd[k + 2]) * f;
        d[k + 3] = 255;
      }
    }
    ctx.putImageData(out, 0, 0);
    ctx.drawImage(frameCv, 0, 0);
  }

  // ================================================================ input
  var down = false, lastX = 0, lastY = 0, hasLast = false;

  function toCanvas(ev) {
    var r = canvas.getBoundingClientRect();
    return {
      x: (ev.clientX - r.left) * (W / r.width),
      y: (ev.clientY - r.top) * (H / r.height)
    };
  }

  function onDown(ev) {
    ev.preventDefault();
    down = true;
    var p = toCanvas(ev);
    lastX = p.x; lastY = p.y; hasLast = true;
    wipe(p.x, p.y, BRUSH, 0.85);
    kick();
  }

  function onMove(ev) {
    if (!down) return;
    ev.preventDefault();
    var p = toCanvas(ev);
    if (!hasLast) {
      hasLast = true; lastX = p.x; lastY = p.y;
      wipe(p.x, p.y, BRUSH, 0.6);
      kick();
      return;
    }
    var dx = p.x - lastX, dy = p.y - lastY;
    var dist = Math.sqrt(dx * dx + dy * dy);
    if (dist < 1.5) return;
    var steps = Math.max(1, Math.min(24, Math.round(dist / (BRUSH * 0.22))));
    for (var s = 1; s <= steps; s++) {
      var t = s / steps;
      wipe(lastX + dx * t, lastY + dy * t, BRUSH, 1.1 / steps);
    }
    lastX = p.x; lastY = p.y;
    kick();
  }

  function onUp() { down = false; hasLast = false; }

  canvas.addEventListener('pointerdown', onDown);
  canvas.addEventListener('pointermove', onMove);
  window.addEventListener('pointerup', onUp);
  window.addEventListener('pointercancel', onUp);
  canvas.addEventListener('pointerleave', function () { hasLast = false; });
  canvas.style.touchAction = 'none';

  // ================================================================= loop
  var running = false, lastT = 0, frames = 0, fpsN = 0, fpsT = 0;

  function kick() {
    if (running) return;
    running = true; lastT = 0;
    requestAnimationFrame(frame);
  }

  function meanDensity() {
    var s = 0;
    for (var i = 0; i < dens.length; i += 7) s += dens[i];
    return s / (dens.length / 7);
  }

  function frame(ts) {
    if (!lastT) lastT = ts;
    var dt = (ts - lastT) / 1000;
    lastT = ts;
    if (dt > 0.1) dt = 0.1;
    fpsN++; fpsT += dt;
    if (fpsT > 0.5) {
      canvas.dataset.fps = (fpsN / fpsT).toFixed(1);
      fpsT = 0; fpsN = 0;
    }
    stepFog(dt);
    render();
    frames++;
    canvas.dataset.frames = frames;
    canvas.dataset.dens = meanDensity().toFixed(4);
    requestAnimationFrame(frame);
  }

  // ================================================================= boot
  bakeView();
  bakeFogColour();
  addBeads();
  bakeFrame();
  buildDensity();

  if (STILL) {
    var i2, j;
    function smear(cx, cy, r, passes, amt) {
      for (var p = 0; p < passes; p++) {
        var a = (p / passes) * Math.PI * 2 + 0.6;
        var ox = Math.cos(a) * r * 0.28, oy = Math.sin(a) * r * 0.22;
        wipe(cx + ox, cy + oy, r, amt);
      }
    }

    // the older wipe, over the small window across the street, already
    // closing over: what is left of it is a thin clear ring
    smear(706, 228, 74, 2, 0.30);
    for (i2 = 0; i2 < 40; i2++) stepFog(0.10);

    // the fresh one, a palm's width, over the street lamp: the whole point is
    // that the light only exists where the glass is clear
    smear(330, 230, 100, 6, 0.62);
    for (i2 = 0; i2 < 12; i2++) {
      var t3 = i2 / 11;
      wipe(330 - 30 * t3, 272 + 74 * t3, 54, 0.28);
      stepFog(0.05);
    }
    for (i2 = 0; i2 < q('heal', 2); i2++) stepFog(0.10);

    render();
    canvas.dataset.still = '1';
    canvas.dataset.dens = meanDensity().toFixed(4);
  } else {
    render();
    setTimeout(function () {
      // one small clear patch on arrival, so the pane shows what it is for
      wipe(W * 0.66, H * 0.44, BRUSH * 1.2, 0.8);
      kick();
    }, 900);
    setTimeout(kick, 80);
  }
})();
