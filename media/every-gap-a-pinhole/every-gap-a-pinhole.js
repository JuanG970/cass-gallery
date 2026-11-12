/* Every Gap a Pinhole — plain Canvas 2D, no library.
   Under a tree during a deep partial eclipse every small hole in the canopy
   is a pinhole camera pointed at the same sun, so the ground is covered in
   crescents that all face the same way. */
(function () {
  'use strict';

  var cv = document.getElementById('pinhole');
  if (!cv) return;
  var ctx = cv.getContext('2d');
  var W = 960, H = 540;

  // ---- optics -------------------------------------------------------------
  var SUN_HALF_ANG = 0.00463;       // rad — half the sun's 0.532 deg

  // ---- params -------------------------------------------------------------
  var params = {};
  location.search.replace(/[?&]([a-zA-Z]+)=([^&]+)/g, function (m, k, v) { params[k] = v; });
  var STILL = params.still === '1';
  var DEBUG = params.big === '1';
  var PX_PER_M = params.ppm ? +params.ppm : 1550;
  var K = PX_PER_M / 1000;          // every pixel quantity scales with the view

  // ---- deterministic rng --------------------------------------------------
  function mulberry32(a) {
    return function () {
      a |= 0; a = a + 0x6D2B79F5 | 0;
      var t = Math.imul(a ^ a >>> 15, 1 | a);
      t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t;
      return ((t ^ t >>> 14) >>> 0) / 4294967296;
    };
  }
  var seed = params.seed ? +params.seed : 20261112;
  var rnd = mulberry32(seed);

  function hash2(x, y) {
    var h = Math.imul(x, 374761393) + Math.imul(y, 668265263) + 1013904223;
    h = Math.imul(h ^ h >>> 13, 1274126177);
    return ((h ^ h >>> 16) >>> 0) * 2.3283064365386963e-10;
  }
  function vnoise(x, y) {
    var xi = Math.floor(x), yi = Math.floor(y);
    var xf = x - xi, yf = y - yi;
    var u = xf * xf * (3 - 2 * xf), v = yf * yf * (3 - 2 * yf);
    var a = hash2(xi, yi), b = hash2(xi + 1, yi), c = hash2(xi, yi + 1), d = hash2(xi + 1, yi + 1);
    return a + (b - a) * u + (c - a) * v + (a - b - c + d) * u * v;
  }

  function boxBlur(src, w, h, r) {
    if (r < 1) return src;
    var tmp = new Float32Array(src.length), out = new Float32Array(src.length);
    var inv = 1 / (2 * r + 1), x, y;
    for (y = 0; y < h; y++) {
      var row = y * w, acc = 0;
      for (x = -r; x <= r; x++) acc += src[row + Math.max(0, Math.min(w - 1, x))];
      for (x = 0; x < w; x++) {
        tmp[row + x] = acc * inv;
        acc += src[row + Math.min(w - 1, x + r + 1)] - src[row + Math.max(0, x - r)];
      }
    }
    for (x = 0; x < w; x++) {
      var acc2 = 0;
      for (y = -r; y <= r; y++) acc2 += tmp[Math.max(0, Math.min(h - 1, y)) * w + x];
      for (y = 0; y < h; y++) {
        out[y * w + x] = acc2 * inv;
        acc2 += tmp[Math.min(h - 1, y + r + 1) * w + x] - tmp[Math.max(0, y - r) * w + x];
      }
    }
    return out;
  }

  // ---- eclipse geometry ---------------------------------------------------
  // The moon's disc is very slightly larger than the sun's (1.04), so a small
  // offset covers it completely. Ask for a visible fraction; solve for the
  // centre separation that produces it.
  var MR = 1.04;
  function overlapArea(d) {
    if (d <= 0) return Math.PI;
    if (d >= 1 + MR) return 0;
    var a1 = Math.acos(Math.max(-1, Math.min(1, (d * d + 1 - MR * MR) / (2 * d))));
    var a2 = Math.acos(Math.max(-1, Math.min(1, (d * d + MR * MR - 1) / (2 * d * MR))));
    return (a1 - Math.sin(2 * a1) / 2) + MR * MR * (a2 - Math.sin(2 * a2) / 2);
  }
  function separationFor(visibleFrac) {
    var target = Math.PI * (1 - Math.min(1, Math.max(0, visibleFrac)));
    var lo = 0, hi = 1 + MR, mid, i;
    // the overlap shrinks as the two discs separate
    for (i = 0; i < 36; i++) {
      mid = (lo + hi) / 2;
      if (overlapArea(mid) > target) lo = mid; else hi = mid;
    }
    return (lo + hi) / 2;
  }

  // fraction of the sun still showing at each click
  var VIS = [1.0, 0.62, 0.40, 0.26, 0.15, 0.075, 0.03, 0.012];
  if (params.vislist) VIS = params.vislist.split(',').map(Number);
  var phaseIdx = params.phase ? Math.min(VIS.length - 1, +params.phase) : 4;

  // image radius buckets, in pixels of ground; blur is the aperture's own
  // softness in the same units
  var BUCKETS = [9.5, 12.5, 16, 20, 25, 32].map(function (v) { return v * K; });
  var BLUR = [0.5, 0.8, 1.3, 2.2, 3.4, 5.0].map(function (v) { return v * K; });

  // ---- crescent sprites ---------------------------------------------------
  var MOON_DIR = 0.62;
  var spriteSets = [];

  function buildSprite(visFrac, radPx, blurR) {
    var S = Math.ceil(radPx * 2) + 8;
    var half = S / 2;
    var d = separationFor(visFrac);
    var ux = Math.cos(MOON_DIR), uy = Math.sin(MOON_DIR);
    var mc = d * radPx;
    var R2 = radPx * radPx, MR2 = R2 * MR * MR;

    var mask = new Float32Array(S * S);
    var SS = 3, inv = 1 / (SS * SS);
    for (var y = 0; y < S; y++) {
      for (var x = 0; x < S; x++) {
        var acc = 0;
        for (var sy = 0; sy < SS; sy++) {
          for (var sx = 0; sx < SS; sx++) {
            var px = x + (sx + 0.5) / SS - half;
            var py = y + (sy + 0.5) / SS - half;
            var r2 = px * px + py * py;
            if (r2 > R2) continue;
            var mx = px - ux * mc, my = py - uy * mc;
            if (mx * mx + my * my < MR2) continue;
            acc += 0.88 + 0.12 * (1 - r2 / R2);      // limb darkening
          }
        }
        mask[y * S + x] = acc * inv;
      }
    }

    var blurred = boxBlur(mask, S, S, Math.round(blurR));
    var c = document.createElement('canvas');
    c.width = S; c.height = S;
    var g = c.getContext('2d');
    var img = g.createImageData(S, S);
    var dat = img.data;
    for (var i = 0; i < S * S; i++) {
      var aa = blurred[i];
      if (aa > 1) aa = 1;
      var o = i * 4;
      dat[o] = 255; dat[o + 1] = 236; dat[o + 2] = 197;
      dat[o + 3] = (aa * 255) | 0;
    }
    g.putImageData(img, 0, 0);
    return c;
  }

  function buildSprites() {
    for (var p = 0; p < VIS.length; p++) {
      var set = [];
      for (var b = 0; b < BUCKETS.length; b++) set.push(buildSprite(VIS[p], BUCKETS[b], BLUR[b]));
      spriteSets.push(set);
    }
  }

  // ---- the light field ----------------------------------------------------
  // Leaf clusters are masses, not gradients: threshold a noise field into
  // clumps, then give it a penumbra by blurring. What is left over is sunlight.
  var MW = W >> 1, MH = H >> 1;
  var LIGHT = new Float32Array(MW * MH);   // 0 deep shade .. 1 open sky
  var GRAIN = new Float32Array(MW * MH);

  function buildLightField() {
    var m = PX_PER_M;
    var raw = new Float32Array(MW * MH);
    var i, j, x, y, idx;
    for (j = 0; j < MH; j++) {
      for (i = 0; i < MW; i++) {
        x = i * 2; y = j * 2;
        raw[j * MW + i] = 0.54 * vnoise(x / (0.30 * m) + 3.1, y / (0.25 * m) + 8.7)
                        + 0.29 * vnoise(x / (0.108 * m) + 21.4, y / (0.108 * m) + 4.2)
                        + 0.17 * vnoise(x / (0.042 * m) + 77.7, y / (0.042 * m) + 13.9);
      }
    }
    // two scales of leaf mass: clumps and the small foliage inside them, so
    // the shade edge is articulated rather than a smooth spotlight
    var small = new Float32Array(MW * MH);
    for (j = 0; j < MH; j++) {
      for (i = 0; i < MW; i++) {
        x = i * 2; y = j * 2;
        small[j * MW + i] = 0.6 * vnoise(x / (0.062 * m) + 12.7, y / (0.062 * m) + 33.1)
                          + 0.4 * vnoise(x / (0.021 * m) + 5.5, y / (0.021 * m) + 61.3);
      }
    }
    var mask = new Float32Array(MW * MH);
    for (idx = 0; idx < mask.length; idx++) {
      mask[idx] = (raw[idx] > 0.508 ? 0.74 : 0) + (small[idx] > 0.512 ? 0.26 : 0);
    }
    var pr = Math.max(2, Math.round(0.010 * m / 2));
    mask = boxBlur(mask, MW, MH, pr);
    mask = boxBlur(mask, MW, MH, Math.round(pr * 0.6));

    for (j = 0; j < MH; j++) {
      for (i = 0; i < MW; i++) {
        idx = j * MW + i;
        // the canopy opens toward the upper right
        var grad = 1 - (0.46 * (1 - i / MW) + 0.54 * (j / MH));
        var g = 0.34 + 0.66 * Math.max(0, Math.min(1, (grad - 0.12) / 0.78));
        LIGHT[idx] = (1 - 0.84 * mask[idx]) * g;
        x = i * 2; y = j * 2;
        GRAIN[idx] = 0.5 * vnoise(x / (0.030 * m), y / (0.030 * m))
                   + 0.32 * vnoise(x / (0.0085 * m) + 51.7, y / (0.0085 * m))
                   + 0.18 * vnoise(x / (0.0029 * m) + 7.3, y / (0.0029 * m));
      }
    }
  }

  function lightAt(x, y) {
    var i = (x * 0.5) | 0, j = (y * 0.5) | 0;
    if (i < 0) i = 0; else if (i >= MW) i = MW - 1;
    if (j < 0) j = 0; else if (j >= MH) j = MH - 1;
    return LIGHT[j * MW + i];
  }

  // ---- what is between the sun and the ground -----------------------------
  // One bough crosses the frame overhead. Nothing grows under it, so the
  // dapples stop dead at its shadow - the one place in the picture where the
  // pattern has an edge.
  var BOUGH = [[-70, 496], [150, 452], [372, 384], [640, 316], [980, 258]];
  var TWIGS = [
    [[318, 396], [360, 330], [404, 272]],
    [[690, 312], [754, 344], [812, 386]]
  ];

  function segDist(x, y, ax, ay, bx, by) {
    var dx = bx - ax, dy = by - ay;
    var t = ((x - ax) * dx + (y - ay) * dy) / (dx * dx + dy * dy);
    t = t < 0 ? 0 : t > 1 ? 1 : t;
    var px = ax + t * dx, py = ay + t * dy;
    return Math.sqrt((x - px) * (x - px) + (y - py) * (y - py));
  }
  var SHADOW_DX = 13, SHADOW_DY = -9;      // the shadow is thrown a little
  function inBough(x, y, pad) {
    var i, d = 1e9;
    for (i = 0; i < BOUGH.length - 1; i++) {
      d = Math.min(d, segDist(x, y, BOUGH[i][0] + SHADOW_DX, BOUGH[i][1] + SHADOW_DY,
                                   BOUGH[i + 1][0] + SHADOW_DX, BOUGH[i + 1][1] + SHADOW_DY));
    }
    if (d < 16 * K + pad) return true;
    for (i = 0; i < TWIGS.length; i++) {
      var tw = TWIGS[i];
      for (var j = 0; j < tw.length - 1; j++) {
        d = segDist(x, y, tw[j][0] + SHADOW_DX, tw[j][1] + SHADOW_DY,
                         tw[j + 1][0] + SHADOW_DX, tw[j + 1][1] + SHADOW_DY);
        if (d < 4.5 * K + pad) return true;
      }
    }
    return false;
  }

  // ---- ground -------------------------------------------------------------
  var base = document.createElement('canvas');
  base.width = W; base.height = H;
  var bctx = base.getContext('2d');

  function buildBase() {
    buildLightField();
    var img = bctx.createImageData(W, H);
    var d = img.data;
    for (var yy = 0; yy < H; yy++) {
      var row = (yy >> 1) * MW;
      for (var xx = 0; xx < W; xx++) {
        var li = row + (xx >> 1);
        var L = LIGHT[li], f = GRAIN[li];
        // dry stone, lit by however much sky gets through
        var lvl = 15 + 188 * L * (0.80 + 0.40 * f) + 12 * f;
        var g1 = (hash2(xx * 3 + 17, yy * 5 + 29) - 0.5) * 12;
        var g2 = hash2(xx * 11 + 3, yy * 7 + 91);
        if (g2 > 0.976) g1 += 24;
        else if (g2 < 0.024) g1 -= 18;
        var l = lvl + g1;
        if (l < 6) l = 6;
        var o = (yy * W + xx) * 4;
        d[o] = l * 1.01 + 9;
        d[o + 1] = l * 0.99 + 7;
        d[o + 2] = l * 1.02 + 9;
        d[o + 3] = 255;
      }
    }
    bctx.putImageData(img, 0, 0);

    // old water stains, so the stone is not one flat grey
    bctx.globalCompositeOperation = 'multiply';
    for (var s2 = 0; s2 < 12; s2++) {
      var sx = hash2(s2 * 7, 3) * W, sy = hash2(s2 * 3, 91) * H;
      var sr = (34 + hash2(s2, 17) * 150) * K;
      var gr = bctx.createRadialGradient(sx, sy, 0, sx, sy, sr);
      var dk = 0.86 + hash2(s2, 23) * 0.11;
      gr.addColorStop(0, 'rgba(' + ((dk * 255) | 0) + ',' + ((dk * 252) | 0) + ',' + ((dk * 255) | 0) + ',0.9)');
      gr.addColorStop(1, 'rgba(255,255,255,0)');
      bctx.fillStyle = gr;
      bctx.beginPath(); bctx.arc(sx, sy, sr, 0, 6.283); bctx.fill();
    }
    bctx.globalCompositeOperation = 'source-over';

    // paving joints, cut by hand rather than ruled
    function joint(seed2, vertical, pos) {
      var n = vertical ? H : W, pts = [], i;
      for (i = 0; i <= n; i += 30) {
        var wob = (hash2(i, seed2) - 0.5) * 4 * K;
        pts.push([vertical ? pos + wob : i, vertical ? i : pos + wob]);
      }
      function trace(off) {
        bctx.beginPath();
        bctx.moveTo(pts[0][0] + (vertical ? off : 0), pts[0][1] + (vertical ? 0 : off));
        for (i = 1; i < pts.length; i++) {
          var a = pts[i - 1], b = pts[i];
          bctx.quadraticCurveTo(a[0], a[1], (a[0] + b[0]) / 2, (a[1] + b[1]) / 2);
        }
        var last = pts[pts.length - 1];
        bctx.lineTo(last[0] + (vertical ? off : 0), last[1] + (vertical ? 0 : off));
      }
      bctx.lineCap = 'round';
      bctx.strokeStyle = 'rgba(34,32,32,0.34)';
      bctx.lineWidth = 6 * K;
      trace(0); bctx.stroke();
      bctx.strokeStyle = 'rgba(12,10,12,0.44)';
      bctx.lineWidth = 1.9 * K;
      trace(0); bctx.stroke();
      bctx.strokeStyle = 'rgba(210,212,222,0.10)';
      bctx.lineWidth = 1.2 * K;
      trace(vertical ? 4 * K : -4 * K); bctx.stroke();
    }
    joint(41, true, 232);
    joint(97, true, 664);
    joint(63, false, 392);

    // the bough's shadow, soft-edged and only as dark as a 15% sun allows
    bctx.save();
    bctx.filter = 'blur(3.5px)';
    bctx.translate(SHADOW_DX, SHADOW_DY);
    bctx.lineCap = 'round';
    bctx.lineJoin = 'round';
    bctx.strokeStyle = 'rgba(14,13,16,0.46)';
    bctx.lineWidth = 30 * K;
    bctx.beginPath();
    bctx.moveTo(BOUGH[0][0], BOUGH[0][1]);
    for (var bi = 1; bi < BOUGH.length - 1; bi++) {
      var mx = (BOUGH[bi][0] + BOUGH[bi + 1][0]) / 2, my = (BOUGH[bi][1] + BOUGH[bi + 1][1]) / 2;
      bctx.quadraticCurveTo(BOUGH[bi][0], BOUGH[bi][1], mx, my);
    }
    bctx.lineTo(BOUGH[BOUGH.length - 1][0], BOUGH[BOUGH.length - 1][1]);
    bctx.stroke();
    bctx.strokeStyle = 'rgba(14,13,16,0.26)';
    bctx.lineWidth = 5 * K;
    bctx.filter = 'blur(5px)';
    for (var ti = 0; ti < TWIGS.length; ti++) {
      var tw2 = TWIGS[ti];
      bctx.beginPath();
      bctx.moveTo(tw2[0][0], tw2[0][1]);
      bctx.quadraticCurveTo(tw2[1][0], tw2[1][1], tw2[2][0], tw2[2][1]);
      bctx.stroke();
    }
    bctx.restore();
    bctx.filter = 'none';

    // grit where the slab meets the joint
    for (var k = 0; k < 46; k++) {
      var gx = hash2(k * 7, 19) * W, gy = hash2(k * 11, 37) * H;
      var gr2 = (0.7 + hash2(k, 5) * 1.7) * K;
      var sh = 0.45 + hash2(k, 41) * 0.5;
      bctx.fillStyle = 'rgba(' + ((168 * sh) | 0) + ',' + ((166 * sh) | 0) + ',' + ((170 * sh) | 0) + ',0.42)';
      bctx.beginPath();
      bctx.ellipse(gx, gy, gr2 * 1.5, gr2, hash2(k, 3) * 3, 0, 6.283);
      bctx.fill();
    }

    // a dry leaf — the one object in the frame with a known size
    bctx.save();
    bctx.translate(186, 466);
    bctx.scale(K, K);
    bctx.rotate(-0.44);
    bctx.beginPath();
    bctx.moveTo(-56, 0);
    bctx.quadraticCurveTo(-20, -24, 34, -10);
    bctx.quadraticCurveTo(54, -5, 58, 0);
    bctx.quadraticCurveTo(54, 5, 34, 10);
    bctx.quadraticCurveTo(-20, 24, -56, 0);
    bctx.fillStyle = '#463a2c';
    bctx.fill();
    bctx.strokeStyle = '#584835';
    bctx.lineWidth = 1.1;
    bctx.beginPath(); bctx.moveTo(-54, 0); bctx.lineTo(55, 0); bctx.stroke();
    for (var v = 1; v <= 7; v++) {
      var xv = -46 + v * 13;
      var len = 17 * (1 - Math.abs(xv) / 90);
      bctx.beginPath(); bctx.moveTo(xv, 0); bctx.lineTo(xv + 6, -len); bctx.stroke();
      bctx.beginPath(); bctx.moveTo(xv, 0); bctx.lineTo(xv + 6, len); bctx.stroke();
    }
    bctx.restore();
  }

  // ---- apertures ----------------------------------------------------------
  // A hole's image radius is (canopy height x the sun's angular radius) plus
  // half its own width, so a high thin gap and a low wide one can throw the
  // same sized dapple. Holes only exist where the canopy lets light through.
  var HOLES = [];
  var TARGET = 132;

  function addHole(x, y, wideGap) {
    var hMetres = 1.5 + rnd() * rnd() * 1.9;
    var apMM = 1.0 + Math.pow(rnd(), 1.7) * 17;
    var rad = hMetres * SUN_HALF_ANG * PX_PER_M + apMM * 0.5;
    if (wideGap) rad = BUCKETS[BUCKETS.length - 1];
    var b = 0, bd = 1e9, i;
    for (i = 0; i < BUCKETS.length; i++) {
      var dd = Math.abs(BUCKETS[i] - rad);
      if (dd < bd) { bd = dd; b = i; }
    }
    // a hole behind a leaf edge is dimmer and softer than an open one
    var soft = (rnd() < 0.34 && b < BUCKETS.length - 1) ? b + 1 : b;
    HOLES.push({
      x: x, y: y, b: b, sb: soft, rad: BUCKETS[b],
      s: 0.88 + rnd() * 0.24,
      amp: 0.5 + rnd() * 1.9,
      ph: rnd() * 6.283,
      f: 0.42 + rnd() * 0.9,
      f2: 0.9 + rnd() * 1.4,
      el: 1.0 + Math.pow(rnd(), 1.6) * 0.62,
      ea: rnd() * 3.14159,
      gain: 0.16 + 0.84 * Math.pow(rnd(), 0.75)
    });
  }

  // Light does not arrive evenly. It comes in patches where the canopy thins,
  // and each patch is a handful of holes at different heights, so the middle
  // of a patch merges and its edge breaks into single crescents.
  function buildHoles() {
    var guard = 0;
    while (HOLES.length < TARGET && guard < 600) {
      guard++;
      var cx = rnd() * W, cy = rnd() * H;
      var L = lightAt(cx, cy);
      if (rnd() > Math.pow(Math.max(0, L - 0.18) / 0.82, 1.2)) continue;
      var patchR = (26 + rnd() * rnd() * 120) * K;
      var n = 3 + Math.floor(rnd() * rnd() * 10);
      for (var k = 0; k < n; k++) {
        var a = rnd() * 6.283, rr = patchR * Math.pow(rnd(), 0.6);
        var hx = cx + Math.cos(a) * rr, hy = cy + Math.sin(a) * rr;
        if (hx < 4 || hx > W - 4 || hy < 4 || hy > H - 4) continue;
        if (lightAt(hx, hy) < 0.22) continue;
        if (inBough(hx, hy, 3)) continue;
        addHole(hx, hy, false);
      }
      if (rnd() < 0.08) addHole(cx, cy, true);
    }
  }

  // ---- buffers ------------------------------------------------------------
  var lcan = document.createElement('canvas'); lcan.width = W; lcan.height = H;
  var lctx = lcan.getContext('2d');
  var bcan = document.createElement('canvas'); bcan.width = W >> 1; bcan.height = H >> 1;
  var bc = bcan.getContext('2d');

  function drawDapples(t, phaseI) {
    var set = spriteSets[phaseI];
    // a crescent keeps the sun's surface brightness however thin it gets; what
    // falls away at totality is the area it covers, not its intensity
    var flux = 0.84 + 0.12 * Math.pow(VIS[phaseI], 0.4);
    lctx.setTransform(1, 0, 0, 1, 0, 0);
    lctx.globalCompositeOperation = 'source-over';
    lctx.clearRect(0, 0, W, H);
    lctx.globalCompositeOperation = 'lighter';
    for (var i = 0; i < HOLES.length; i++) {
      var h = HOLES[i];
      var wx = h.x + h.amp * Math.sin(t * h.f + h.ph) + h.amp * 0.5 * Math.sin(t * h.f2 * 1.7 + h.ph * 2.1);
      var wy = h.y + h.amp * 0.8 * Math.cos(t * h.f * 0.83 + h.ph * 1.4);
      var spr = set[h.sb];
      var w = spr.width * (h.rad / BUCKETS[h.sb]) * h.s;
      var flick = 0.9 + 0.1 * Math.sin(t * h.f2 * 0.7 + h.ph * 3.3);
      lctx.globalAlpha = Math.min(1, h.gain * flux * flick * 0.80);
      lctx.drawImage(spr, wx - w / 2, wy - w / 2, w, w);
    }
    lctx.globalAlpha = 1;
    lctx.globalCompositeOperation = 'source-over';
  }

  function composite() {
    ctx.globalCompositeOperation = 'source-over';
    ctx.globalAlpha = 1;
    ctx.drawImage(base, 0, 0);
    bc.clearRect(0, 0, bcan.width, bcan.height);
    bc.drawImage(lcan, 0, 0, bcan.width, bcan.height);
    ctx.globalCompositeOperation = 'lighter';
    ctx.drawImage(lcan, 0, 0);
    ctx.globalAlpha = 0.26;
    ctx.drawImage(bcan, 0, 0, W, H);
    ctx.globalAlpha = 1;
    ctx.globalCompositeOperation = 'source-over';
  }

  // ---- boot ---------------------------------------------------------------
  buildBase();

  if (DEBUG) {
    cv.dataset.still = '1';
    return;
  }

  buildSprites();
  buildHoles();
  cv.dataset.dapples = HOLES.length;
  cv.dataset.phase = String(phaseIdx);

  if (STILL) {
    drawDapples(0, phaseIdx);
    composite();
    cv.dataset.still = '1';
    return;
  }

  var t0 = performance.now();
  var frames = 0, fpsT = 0;

  function frame(now) {
    var t = (now - t0) / 1000;
    drawDapples(t, phaseIdx);
    composite();
    frames++;
    if (t - fpsT > 1) { cv.dataset.fps = (frames / (t - fpsT)).toFixed(1); frames = 0; fpsT = t; }
    requestAnimationFrame(frame);
  }
  requestAnimationFrame(frame);

  cv.addEventListener('click', function () {
    phaseIdx = (phaseIdx + 1) % VIS.length;
    cv.dataset.phase = String(phaseIdx);
  });
})();
