/*  Two Metres Down — caustics on the bottom of a pool
 *  Plain Canvas 2D, no library. 960x540 (light computed at 480x270, upscaled).
 *
 *  Nothing here draws a bright line. The pool floor is drawn once — tiles,
 *  grout, one lane line — and then light is *added* on top of it. For every
 *  pixel of that floor the sketch asks a backwards question: which patch of
 *  the rippling surface sent me this light? The surface tilts, refraction
 *  bends the ray toward the normal (n = 1.333), and it lands somewhere other
 *  than straight below. Where a large patch of surface is squeezed into a
 *  small patch of floor the light concentrates; where it is spread out the
 *  floor is dim. The caustic net is the map of that squeeze:
 *
 *      p = q + kd * grad h(q)              kd = depth * (1 - 1/n)
 *      I = 1 / |det(dp/dq)|                det = (1+kd.hxx)(1+kd.hyy) - (kd.hxy)^2
 *
 *  The bright arcs are not shapes. They are places where the determinant of
 *  the surface-to-floor mapping passes through zero.
 */
(function () {
  'use strict';

  var W = 960, H = 540;
  var LW = 480, LH = 270;             // light map resolution
  var canvas = document.getElementById('pool');
  var ctx = canvas.getContext('2d');
  var still = /(\?|&)still=1/.test(location.search);

  var N_WATER = 1.333;
  var DEPTH = 2.0;                    // metres — the piece's namesake
  var PX_PER_M = 240;                 // 960 px across ~4 m of pool
  // px of floor displacement per unit of surface slope
  var KD = DEPTH * PX_PER_M * (1 - 1 / N_WATER) * 0.62;

  // ---------- rng ----------
  function mulberry32(a) {
    return function () {
      a |= 0; a = a + 0x6D2B79F5 | 0;
      var t = Math.imul(a ^ a >>> 15, 1 | a);
      t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t;
      return ((t ^ t >>> 14) >>> 0) / 4294967296;
    };
  }
  var rnd = mulberry32(0x5EA51DE);

  // ---------- sine table ----------
  // The field build is 4 waves x 82,944 cells; Math.sin twice per wave there
  // costs ~30ms a frame on its own, which is more than the rest of the optics.
  var SINBITS = 12, SINSIZE = 1 << SINBITS, SINMASK = SINSIZE - 1;
  var SIN = new Float32Array(SINSIZE + 1);
  (function () {
    for (var i = 0; i <= SINSIZE; i++) SIN[i] = Math.sin(i / SINSIZE * 6.283185307179586);
  })();
  var SCALE = SINSIZE / 6.283185307179586;
  function sinL(p) {                   // p in radians, any range
    var k = (p * SCALE) | 0;
    return SIN[k & SINMASK];
  }
  function cosL(p) { return sinL(p + 1.5707963267948966); }

  // ---------- the surface ----------
  // Four travelling waves, 4 cm to 14 cm. The floor gets the big net and the
  // slow warp that shifts it; finer waves only add beads.
  // Four travelling waves. More waves than this and the interference stops
  // being a net and becomes a texture: the fold set fragments into closed
  // loops and the floor reads as a microscope slide, not as water. Four is
  // what gives cells big enough to look like cells.
  var NW = 4;
  var WAVES = [
    { a: 9.0, kx:  0.0400, ky:  0.0180, w: 0.40, p: 0.0 },
    { a: 6.0, kx: -0.0290, ky:  0.0520, w: 0.55, p: 1.7 },
    { a: 4.0, kx:  0.0620, ky: -0.0280, w: 0.78, p: 3.1 },
    { a: 2.6, kx: -0.0800, ky: -0.0470, w: 1.05, p: 4.4 }
  ];

  // derivative + intensity field on a torus-wrapped grid
  var GW = 384, GH = 216;
  var gx = new Float32Array(GW * GH), gy = new Float32Array(GW * GH);
  var IF = new Float32Array(GW * GH);
  var SW = LW / GW, SH = LH / GH;

  var ripples = [];                   // click the water

  function buildField(t) {
    var i = 0, y, x, u, v, k, W_;
    for (y = 0; y < GH; y++) {
      v = y * SH;
      for (x = 0; x < GW; x++, i++) {
        u = x * SW;
        var dx = 0, dy = 0, dxx = 0, dxy = 0, dyy = 0;
        for (k = 0; k < NW; k++) {
          W_ = WAVES[k];
          var ph = W_.kx * u + W_.ky * v + W_.w * t + W_.p;
          var c = cosL(ph), s = sinL(ph);
          dx  += W_.a * W_.kx * c;
          dy  += W_.a * W_.ky * c;
          dxx += -W_.a * W_.kx * W_.kx * s;
          dxy += -W_.a * W_.kx * W_.ky * s;
          dyy += -W_.a * W_.ky * W_.ky * s;
        }
        // ripples: an expanding ring, decaying in space and in time
        for (var r = 0; r < ripples.length; r++) {
          var R = ripples[r], age = t - R.t0;
          if (age < 0 || age > 9) continue;
          var ex = u - R.x, ey = v - R.y;
          var d = Math.sqrt(ex * ex + ey * ey);
          if (d < 1) d = 1;
          var front = d - age * 62;
          var env = Math.exp(-(front * front) / 3025) * Math.exp(-d / 340) * Math.exp(-age / 6.0);
          if (env < 0.002) continue;
          var kk = 0.078, amp = 26.0 * env;
          var ph2 = kk * front;
          var s2 = sinL(ph2), c2 = cosL(ph2);
          var ux = ex / d, uy = ey / d;
          var dAmp = amp * (kk * c2 - s2 / 340);
          var d2Amp = amp * (-kk * kk * s2 - 2 * kk * c2 / 340 + s2 / 115600);
          dx  += dAmp * ux;
          dy  += dAmp * uy;
          dxx += d2Amp * ux * ux;
          dxy += d2Amp * ux * uy;
          dyy += d2Amp * uy * uy;
        }
        gx[i] = dx; gy[i] = dy;

        // intensity at this surface point, relative to flat water (I = 1)
        var det = (1 + KD * dxx) * (1 + KD * dyy) - (KD * dxy) * (KD * dxy);
        var ad = det < 0 ? -det : det;
        var I = 1 / (ad + 0.02);
        IF[i] = I > 4.5 ? 4.5 : I;
      }
    }
  }

  // bilinear sample of a grid, wrapping
  function samp(A, u, v) {
    var fx = u / SW, fy = v / SH;
    var x0 = Math.floor(fx), y0 = Math.floor(fy);
    var tx = fx - x0, ty = fy - y0;
    x0 = ((x0 % GW) + GW) % GW;
    y0 = ((y0 % GH) + GH) % GH;
    var x1 = (x0 + 1) % GW, y1 = (y0 + 1) % GH;
    var i00 = y0 * GW + x0, i10 = y0 * GW + x1,
        i01 = y1 * GW + x0, i11 = y1 * GW + x1;
    var a = A[i00] + (A[i10] - A[i00]) * tx;
    var b = A[i01] + (A[i11] - A[i01]) * tx;
    return a + (b - a) * ty;
  }

  // ---------- the light ----------
  var lightCanvas = document.createElement('canvas');
  lightCanvas.width = LW; lightCanvas.height = LH;
  var lctx = lightCanvas.getContext('2d');
  var frame = lctx.createImageData(LW, LH);
  var bytes = frame.data;

  var LI = new Float32Array(LW * LH);
  var TA = new Float32Array(LW * LH);
  var TB = new Float32Array(LW * LH);

  // bloom source: a quarter-size canvas, softened by the downscale itself
  var bloomCanvas = document.createElement('canvas');
  bloomCanvas.width = LW >> 2; bloomCanvas.height = LH >> 2;
  var blctx = bloomCanvas.getContext('2d');

  // light colour ramp: cool dim scatter -> white hot focus
  var RAMP = 512;
  var rampR = new Uint8ClampedArray(RAMP), rampG = new Uint8ClampedArray(RAMP),
      rampB = new Uint8ClampedArray(RAMP), rampA = new Uint8ClampedArray(RAMP);

  (function buildRamp() {
    var stops = [
      [0.00,  10,  38,  54,   0],
      [0.16,  30,  84, 104,  20],
      [0.38,  76, 152, 178,  58],
      [0.62, 144, 214, 232, 108],
      [0.84, 212, 244, 252, 176],
      [1.00, 250, 255, 255, 226]
    ];
    for (var i = 0; i < RAMP; i++) {
      var t = i / (RAMP - 1), j = 0;
      while (j < stops.length - 2 && t > stops[j + 1][0]) j++;
      var A_ = stops[j], B_ = stops[j + 1];
      var f = (t - A_[0]) / (B_[0] - A_[0]);
      rampR[i] = A_[1] + (B_[1] - A_[1]) * f;
      rampG[i] = A_[2] + (B_[2] - A_[2]) * f;
      rampB[i] = A_[3] + (B_[3] - A_[3]) * f;
      rampA[i] = A_[4] + (B_[4] - A_[4]) * f;
    }
  })();

  function renderLight(t) {
    buildField(t);

    // ---- pass 1: walk each floor pixel back to the surface ----
    // inlined bilinear, clamped at the frame edge rather than wrapped: the
    // modulo pair in samp() alone cost about a third of the whole frame
    var i = 0, x, y, o, k, a, c;
    var ISX = 1 / SW, ISY = 1 / SH;
    for (y = 0; y < LH; y++) {
      for (x = 0; x < LW; x++, i++) {
        // two backwards steps are enough: the displacement is small next to
        // the wavelength, so this converges to within a pixel or two
        var qx = x, qy = y, fx, fy, x0, y0, tx, ty, i00, i10, i01, i11;
        for (var st = 0; st < 2; st++) {
          fx = qx * ISX; fy = qy * ISY;
          if (fx < 0) fx = 0; else if (fx > GW - 1.001) fx = GW - 1.001;
          if (fy < 0) fy = 0; else if (fy > GH - 1.001) fy = GH - 1.001;
          x0 = fx | 0; y0 = fy | 0;
          tx = fx - x0; ty = fy - y0;
          i00 = y0 * GW + x0;
          i10 = i00 + 1; i01 = i00 + GW; i11 = i01 + 1;
          var ga = gx[i00] + (gx[i10] - gx[i00]) * tx;
          var gb = gx[i01] + (gx[i11] - gx[i01]) * tx;
          var ggx = ga + (gb - ga) * ty;
          var ha = gy[i00] + (gy[i10] - gy[i00]) * tx;
          var hb = gy[i01] + (gy[i11] - gy[i01]) * tx;
          var ggy = ha + (hb - ha) * ty;
          qx = x - KD * ggx;
          qy = y - KD * ggy;
        }
        // the last iteration leaves gx/gy at the preimage; sample I there
        fx = qx * ISX; fy = qy * ISY;
        if (fx < 0) fx = 0; else if (fx > GW - 1.001) fx = GW - 1.001;
        if (fy < 0) fy = 0; else if (fy > GH - 1.001) fy = GH - 1.001;
        x0 = fx | 0; y0 = fy | 0;
        tx = fx - x0; ty = fy - y0;
        i00 = y0 * GW + x0; i10 = i00 + 1; i01 = i00 + GW; i11 = i01 + 1;
        var ia = IF[i00] + (IF[i10] - IF[i00]) * tx;
        var ib = IF[i01] + (IF[i11] - IF[i01]) * tx;
        LI[i] = ia + (ib - ia) * ty;
      }
    }

    // ---- pass 2: blur the intensity, not the picture ----
    for (y = 0; y < LH; y++) {
      o = y * LW;
      for (x = 0; x < LW; x++) {
        k = o + x;
        a = LI[k - (x > 0 ? 1 : 0)];
        c = LI[k + (x < LW - 1 ? 1 : 0)];
        TB[k] = (a + 2 * LI[k] + c) * 0.25;
      }
    }
    for (x = 0; x < LW; x++) {
      for (y = 0; y < LH; y++) {
        k = y * LW + x;
        a = TB[k - (y > 0 ? LW : 0)];
        c = TB[k + (y < LH - 1 ? LW : 0)];
        TA[k] = (a + 2 * TB[k] + c) * 0.25;
      }
    }

    // a second smoothing pass: a caustic line is thinner than a light-map
    // pixel, and one 3-tap pass leaves it as a string of beads
    for (y = 0; y < LH; y++) {
      o = y * LW;
      for (x = 0; x < LW; x++) {
        k = o + x;
        a = TA[k - (x > 0 ? 1 : 0)];
        c = TA[k + (x < LW - 1 ? 1 : 0)];
        TB[k] = (a + 2 * TA[k] + c) * 0.25;
      }
    }
    for (x = 0; x < LW; x++) {
      for (y = 0; y < LH; y++) {
        k = y * LW + x;
        a = TB[k - (y > 0 ? LW : 0)];
        c = TB[k + (y < LH - 1 ? LW : 0)];
        TA[k] = (a + 2 * TB[k] + c) * 0.25;
      }
    }

    // ---- pass 3: tone map and colour ----
    i = 0;
    for (y = 0; y < LH; y++) {
      var vy = (y - LH * 0.30) / LH;
      for (x = 0; x < LW; x++, i++) {
        var b = (TA[i] - 0.62) * 0.34;
        if (b < 0) b = 0;
        b = b * Math.sqrt(b);            // gamma 1.5 without Math.pow
        if (b > 1) b = 1;

        // the sun is at one end of the pool: the net fades into shade
        var vx = (x - LW * 0.34) / LW;
        var fall = 1 - 0.74 * Math.min(1, (vx * vx + vy * vy * 1.30) * 1.40);
        if (fall < 0.10) fall = 0.10;
        b *= fall;

        var idx = (b * (RAMP - 1)) | 0;
        o = i * 4;
        bytes[o] = rampR[idx];
        bytes[o + 1] = rampG[idx];
        bytes[o + 2] = rampB[idx];
        bytes[o + 3] = rampA[idx];
      }
    }
    lctx.putImageData(frame, 0, 0);

    blctx.clearRect(0, 0, bloomCanvas.width, bloomCanvas.height);
    blctx.drawImage(lightCanvas, 0, 0, bloomCanvas.width, bloomCanvas.height);
  }

  // ---------- the floor (drawn once) ----------
  var base = document.createElement('canvas');
  base.width = W; base.height = H;
  var bctx = base.getContext('2d');

  function buildFloor() {
    var TILE = 64;                     // ~27 cm tiles
    var g = bctx.createLinearGradient(0, 0, W * 0.6, H);
    g.addColorStop(0, '#1b5c6e');
    g.addColorStop(0.55, '#154c5a');
    g.addColorStop(1, '#0b2e38');
    bctx.fillStyle = g;
    bctx.fillRect(0, 0, W, H);

    // per-tile colour jitter so the floor is glazed ceramic, not paint
    for (var ty = 0; ty < H; ty += TILE) {
      for (var tx = 0; tx < W; tx += TILE) {
        var j = (rnd() - 0.5) * 0.14;
        bctx.fillStyle = 'rgba(' + (j > 0 ? 255 : 0) + ',' +
                         (j > 0 ? 255 : 0) + ',' + (j > 0 ? 255 : 0) + ',' +
                         Math.abs(j) + ')';
        bctx.fillRect(tx + 1, ty + 1, TILE - 2, TILE - 2);
      }
    }

    // grout
    bctx.strokeStyle = 'rgba(5,30,40,0.9)';
    bctx.lineWidth = 2;
    bctx.beginPath();
    for (var x = 0; x <= W; x += TILE) { bctx.moveTo(x + 0.5, 0); bctx.lineTo(x + 0.5, H); }
    for (var y = 0; y <= H; y += TILE) { bctx.moveTo(0, y + 0.5); bctx.lineTo(W, y + 0.5); }
    bctx.stroke();

    // the one thing that says "swimming pool" and gives the eye a scale
    var LX = 268, LWID = 56;
    bctx.fillStyle = 'rgba(4,22,30,0.88)';
    bctx.fillRect(LX, 0, LWID, H);
    bctx.fillStyle = 'rgba(120,190,205,0.10)';
    bctx.fillRect(LX, 0, 2, H);
    bctx.fillRect(LX + LWID - 2, 0, 2, H);

    // the drain cover: the only object on the floor, and the thing that makes
    // the frame a pool instead of a tiled surface
    var DX = 742, DY = 396, DR = 58;
    bctx.fillStyle = 'rgba(2,12,17,0.6)';
    bctx.beginPath();
    bctx.arc(DX + 5, DY + 7, DR + 10, 0, 6.2832);
    bctx.fill();
    bctx.fillStyle = '#2a6b7d';
    bctx.beginPath();
    bctx.arc(DX, DY, DR, 0, 6.2832);
    bctx.fill();
    bctx.strokeStyle = 'rgba(6,26,34,0.95)';
    bctx.lineWidth = 5;
    bctx.beginPath();
    bctx.arc(DX, DY, DR - 3, 0, 6.2832);
    bctx.stroke();
    // grate: slots radiating from the centre
    bctx.lineWidth = 7;
    for (var s = 0; s < 10; s++) {
      var ang = s * 0.6283 + 0.31;
      bctx.beginPath();
      bctx.moveTo(DX + Math.cos(ang) * 16, DY + Math.sin(ang) * 16);
      bctx.lineTo(DX + Math.cos(ang) * (DR - 11), DY + Math.sin(ang) * (DR - 11));
      bctx.stroke();
    }
    bctx.strokeStyle = 'rgba(150,210,224,0.30)';
    bctx.lineWidth = 2;
    bctx.beginPath();
    bctx.arc(DX, DY, 14, 0, 6.2832);
    bctx.stroke();

    // the light spreads from one side of the pool; corners lose it
    var vg = bctx.createRadialGradient(W * 0.42, H * 0.30, H * 0.22,
                                       W * 0.42, H * 0.30, H * 1.35);
    vg.addColorStop(0, 'rgba(0,0,0,0)');
    vg.addColorStop(0.55, 'rgba(2,16,22,0.20)');
    vg.addColorStop(1, 'rgba(1,10,14,0.74)');
    bctx.fillStyle = vg;
    bctx.fillRect(0, 0, W, H);
  }

  // ---------- compose ----------
  function draw(t) {
    renderLight(t);
    ctx.drawImage(base, 0, 0);
    ctx.save();
    ctx.globalCompositeOperation = 'lighter';
    ctx.imageSmoothingEnabled = true;
    ctx.imageSmoothingQuality = 'high';
    ctx.globalAlpha = 0.95;
    ctx.drawImage(lightCanvas, 0, 0, LW, LH, 0, 0, W, H);
    ctx.globalAlpha = 0.34;
    ctx.drawImage(bloomCanvas, 0, 0, bloomCanvas.width, bloomCanvas.height, 0, 0, W, H);
    ctx.restore();
  }

  // ---------- loop ----------
  var t0 = 0;

  function loop(ts) {
    if (!t0) t0 = ts;
    draw((ts - t0) / 1000 + 12.5);
    requestAnimationFrame(loop);
  }

  buildFloor();

  if (still) {
    // a fixed moment, no loop: byte-reproducible poster frame.
    // ?stone=x,y,age seeds one ripple at a chosen age, so a capture can show
    // the surface answering a click without waiting for a real one.
    var st = /[?&]stone=([0-9.]+),([0-9.]+),([0-9.]+)/.exec(location.search);
    if (st) ripples.push({ x: +st[1], y: +st[2], t0: 12.5 - +st[3] });
    draw(12.5);
    canvas.dataset.frames = '1';
  } else {
    requestAnimationFrame(loop);
    canvas.addEventListener('click', function (e) {
      var r = canvas.getBoundingClientRect();
      ripples.push({
        x: (e.clientX - r.left) / r.width * LW,
        y: (e.clientY - r.top) / r.height * LH,
        t0: (performance.now() - t0) / 1000 + 12.5
      });
      if (ripples.length > 5) ripples.shift();
    });
    var counted = 0, mark = 0;
    (function fpsProbe() {
      requestAnimationFrame(function f(ts2) {
        if (!mark) mark = ts2;
        counted++;
        if (ts2 - mark > 1000) {
          canvas.dataset.fps = (counted * 1000 / (ts2 - mark)).toFixed(0);
          counted = 0; mark = ts2;
        }
        requestAnimationFrame(f);
      });
    })();
  }
})();
