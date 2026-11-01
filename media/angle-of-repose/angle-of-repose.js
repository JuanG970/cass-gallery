/*  Angle of Repose — a dune's lee face failing
 *  Plain Canvas 2D, no library. 960x540.
 *
 *  A dune has two slopes and only one angle. The windward side is shallow and
 *  rippled; the lee side stands at the angle dry sand will hold — about 34
 *  degrees — and not a degree more. Sand arrives over the brink, piles into a
 *  lens, and when the lens gets too steep it lets go as one body and runs down
 *  to the toe, where it comes to rest against the sand already there.
 *
 *  No slope is drawn anywhere in this sketch. The diagonal is the crest. The
 *  dark side is a plane in shadow; everything bright on it is sand, and sand
 *  here is a count — grains accumulating in a place until the place goes pale.
 */
(function () {
  'use strict';

  var W = 960, H = 540;
  var N = 46000;                       // grains
  var NX = 0.22, NY = 0.975;           // down the lee face, in screen units
  var REPOSE = 34.0;                   // degrees

  var canvas = document.getElementById('dune');
  var ctx = canvas.getContext('2d');
  var still = /(\?|&)still=1/.test(location.search);

  // ---------- rng ----------
  function mulberry32(a) {
    return function () {
      a |= 0; a = a + 0x6D2B79F5 | 0;
      var t = Math.imul(a ^ a >>> 15, 1 | a);
      t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t;
      return ((t ^ t >>> 14) >>> 0) / 4294967296;
    };
  }
  var rnd = mulberry32(0x5EED11);

  // ---------- the crest ----------
  function crestAt(x) {
    return 290 - 0.44 * (x - 480)
         + 22 * Math.sin(x * 0.0062 + 0.8)
         + 8 * Math.sin(x * 0.0175 + 2.1);
  }
  var CY = new Float32Array(W);
  for (var ci = 0; ci < W; ci++) CY[ci] = crestAt(ci);

  // ---------- colour ramp ----------
  var RAMP = 512;
  var rampR = new Uint8ClampedArray(RAMP),
      rampG = new Uint8ClampedArray(RAMP),
      rampB = new Uint8ClampedArray(RAMP);

  (function buildRamp() {
    var stops = [
      [0.000,  11,   9,  16],
      [0.060,  21,  16,  19],
      [0.150,  47,  35,  28],
      [0.300,  90,  66,  44],
      [0.460, 138, 104,  67],
      [0.620, 186, 147, 100],
      [0.780, 222, 188, 140],
      [0.900, 245, 221, 176],
      [1.000, 255, 248, 228]
    ];
    for (var i = 0; i < RAMP; i++) {
      var t = i / (RAMP - 1), k = 0;
      while (k < stops.length - 2 && t > stops[k + 1][0]) k++;
      var a = stops[k], c = stops[k + 1];
      var f = (t - a[0]) / Math.max(1e-6, c[0] - a[0]);
      f = f < 0 ? 0 : f > 1 ? 1 : f;
      rampR[i] = a[1] + (c[1] - a[1]) * f;
      rampG[i] = a[2] + (c[2] - a[2]) * f;
      rampB[i] = a[3] + (c[3] - a[3]) * f;
    }
  })();

  // sand over shadow: what a given grain count per pixel is worth
  var DLUT = 256;
  var dR = new Uint8ClampedArray(DLUT),
      dG = new Uint8ClampedArray(DLUT),
      dB = new Uint8ClampedArray(DLUT);
  (function () {
    for (var i = 0; i < DLUT; i++) {
      var d = i / 32;
      // one grain on its own should be barely there; four in the same place
      // should be sand. Without the toe of this curve the whole face turns
      // into glitter.
      var t = Math.pow(d * 0.30, 1.7);
      if (t > 1) t = 1;
      dR[i] = 108 * t;
      dG[i] = 92 * t;
      dB[i] = 63 * t;
    }
  })();

  // ---------- static surfaces ----------
  var baseCanvas = document.createElement('canvas');
  baseCanvas.width = W; baseCanvas.height = H;
  var baseCtx = baseCanvas.getContext('2d');
  var baseBytes = null;   // rippled sand
  var slipBytes = null;   // the smooth plane a slide exposes

  function buildBase() {
    var img = baseCtx.createImageData(W, H);
    var d = img.data;
    var img2 = baseCtx.createImageData(W, H);
    var d2 = img2.data;

    for (var y = 0; y < H; y++) {
      for (var x = 0; x < W; x++) {
        var p = (y * W + x) * 4;
        var cy = CY[x];
        var dy = y - cy;
        var v, vs;

        if (dy < 0) {
          // windward: shallow and lit. Ripples run parallel to the crest and
          // the wavelength drifts, so this is wind and not corduroy.
          var wl = 24 + 7 * Math.sin(x * 0.0031 + 2.2) + 3.5 * Math.sin(x * 0.0121);
          var ph = (cy - y) / wl
                 + 0.30 * Math.sin(x * 0.0105 + 1.3)
                 + 0.17 * Math.sin(x * 0.0301 + 0.6)
                 + 0.05 * Math.sin((cy - y) * 0.021 + x * 0.002);
          var f1 = ph - Math.floor(ph);
          var rip = Math.pow(f1, 1.9);
          var away = -dy / 560; if (away > 1) away = 1;
          v = (0.54 + 0.30 * rip) * (1 - 0.38 * away);
          v += ((((x * 7919 + y * 104729) % 97) / 97) - 0.5) * 0.055;
          // the ground itself is not flat: a slow swell across the slope
          v *= 1 + 0.055 * Math.sin(x * 0.0092 + y * 0.0035 + 1.1);
          vs = 0.50 * (1 - 0.38 * away);
        } else {
          // lee face: no sun in it, and it falls away into shadow
          var s = dy / NY;
          var sm = 0.25 * Math.exp(-s / 175) + 0.05 * Math.exp(-s / 600) + 0.022;
          var ph2 = s / 31 + 0.55 * Math.sin(x * 0.0042 + 0.9);
          var f2 = ph2 - Math.floor(ph2);
          v = sm + 0.048 * Math.pow(f2, 1.7) * Math.exp(-s / 300);
          v += ((((x * 5011 + y * 91771) % 89) / 89) - 0.5) * 0.010;
          vs = sm * 0.42;                      // bare slip plane, no ripples
          if (dy < 5) { v *= 0.30 + 0.14 * dy; vs *= 0.30 + 0.14 * dy; }
        }

        // the crest: the only edge in the frame, and the brightest thing
        var ad = dy < 0 ? -dy : dy;
        var bloom = 0.54 * Math.exp(-(ad * ad) / 30) + 0.12 * Math.exp(-ad / 30);
        v += bloom;
        vs += bloom;

        var qx = (x - W * 0.5) / (W * 0.5), qy = (y - H * 0.5) / (H * 0.5);
        var vig = 1 - 0.24 * (qx * qx + qy * qy);
        v *= vig; vs *= vig;

        if (v < 0) v = 0; else if (v > 1) v = 1;
        if (vs < 0) vs = 0; else if (vs > 1) vs = 1;
        var vi = (v * (RAMP - 1)) | 0, si = (vs * (RAMP - 1)) | 0;
        d[p] = rampR[vi]; d[p + 1] = rampG[vi]; d[p + 2] = rampB[vi]; d[p + 3] = 255;
        d2[p] = rampR[si]; d2[p + 1] = rampG[si]; d2[p + 2] = rampB[si]; d2[p + 3] = 255;
      }
    }
    baseCtx.putImageData(img, 0, 0);
    baseBytes = new Uint8ClampedArray(baseCtx.getImageData(0, 0, W, H).data);
    slipBytes = new Uint8ClampedArray(d2);
  }

  // ---------- grains ----------
  var gu = new Float32Array(N);
  var gs = new Float32Array(N);
  var gv = new Float32Array(N);
  var gw = new Float32Array(N);
  var gr = new Float32Array(N);
  var gt = new Uint8Array(N);          // 0 resting, 1 in the air
  var gse = new Float32Array(N);
  var gtoe = new Float32Array(N);      // where this grain's toe actually is
  var gj = new Float32Array(N);        // ... and how far past it, per grain

  function sExit(u) {
    var x = u * W;
    if (x < 0) x = 0; else if (x > W - 1) x = W - 1;
    var cy = CY[x | 0];
    var tb = (H - cy - 6) / NY;
    return tb > 6 ? tb : 6;
  }

  // the toe is not a straight line — it wanders, because dunes do
  function toeFrac(u) {
    return 0.80 + 0.085 * Math.sin(u * 9.4 + 0.6) + 0.055 * Math.sin(u * 23.1 + 2.4);
  }

  // ---------- the failure ----------
  var FR = 0;
  var laneU = 0.72, laneW = 0.060;
  var evT = 0, EVENT = 7.2, FMAX = 104, DECAY = 4.6;

  function frontAt(u) {
    var q = (u - laneU) / laneW;
    var e = Math.exp(-q * q);
    var qa = (u - laneU - laneW * 1.85) / (laneW * 0.75);
    var qb = (u - laneU + laneW * 1.35) / (laneW * 0.95);
    e += 0.32 * Math.exp(-qa * qa);
    e += 0.20 * Math.exp(-qb * qb);
    return FR * e;
  }

  function release() {
    // the lens at the brink lets go as one body, not grain by grain
    for (var i = 0; i < N; i++) {
      if (gt[i] === 0 && gs[i] < frontAt(gu[i])) {
        gr[i] = (gr[i] + 0.7548776662) % 1;
        if (gr[i] < 0.70) {
          gt[i] = 1;
          gv[i] = 0.9 + gr[i] * 0.8;
        }
      }
    }
  }

  function eventFrame() {
    var was = evT;
    evT += 1 / 60;
    if (evT > EVENT) {
      evT = 0;
      laneU = 0.50 + rnd() * 0.34;
      laneW = 0.045 + rnd() * 0.050;
    }
    if (was < 0.001) { FR = FMAX; release(); }
    var k = evT / DECAY;
    if (k >= 1) k = 1;
    FR = FMAX * (1 - k * k * (3 - 2 * k));     // the slip face fills back in
  }

  function seed() {
    for (var i = 0; i < N; i++) {
      gu[i] = 0.03 + rnd() * 0.94;
      gse[i] = sExit(gu[i]);
      gj[i] = (rnd() - 0.5) * 26;
      gtoe[i] = gse[i] * toeFrac(gu[i]) + gj[i];
      gw[i] = 0.58 + rnd() * 0.86;
      gr[i] = rnd();
      gv[i] = 0; gt[i] = 0;
      var r = rnd();
      if (r < 0.66) gs[i] = gtoe[i] * (0.86 + rnd() * 0.16);   // the toe fan
      else if (r < 0.80) gs[i] = gtoe[i] * rnd() * 0.55;       // the swept face
      else gs[i] = rnd() * 100;                                 // the brink lens
    }
  }

  function respawn(i) {
    gt[i] = 0; gv[i] = 0;
    gu[i] = 0.03 + rnd() * 0.94;
    gse[i] = sExit(gu[i]);
    gj[i] = (rnd() - 0.5) * 26;
    gtoe[i] = gse[i] * toeFrac(gu[i]) + gj[i];
    gs[i] = rnd() * (FR > 14 ? FR * 0.92 : 14);
  }

  function step() {
    eventFrame();
    for (var i = 0; i < N; i++) {
      var u1 = gr[i];
      gr[i] = (gr[i] + 0.7548776662) % 1;

      if (gt[i] === 0) {
        var s = gs[i];
        if (s < frontAt(gu[i]) && u1 < 0.0040) {
          gt[i] = 1; gv[i] = 0.5 + u1 * 1.1;
        } else if (s < gtoe[i]) {
          gs[i] = s + 0.045;                   // it never quite holds still
        } else if (s > gtoe[i]) {
          // at the toe the slope is broken, so it stops — and slowly works
          // its way back to the brink, because that is where the wind is
          if (u1 < 0.0022) respawn(i);
          else gs[i] = gtoe[i] + (s - gtoe[i]) * 0.90;
        }
        continue;
      }

      gv[i] += 0.045;
      if (gv[i] > 1.6) gv[i] = 1.6;
      var ns = gs[i] + gv[i] * (0.70 + 0.62 * u1);
      if (ns >= gtoe[i]) { gt[i] = 0; gv[i] = 0; gs[i] = gtoe[i]; }
      else gs[i] = ns;
    }
  }

  // ---------- render ----------
  var frame = null, fd = null;
  var dep = new Float32Array(W * H);

  function draw() {
    if (!fd) { frame = ctx.createImageData(W, H); fd = frame.data; }
    fd.set(baseBytes);

    // the slip face: ripples gone, plane exposed, and a bright lip at the
    // break where the slab is still peeling away
    for (var x = 0; x < W; x++) {
      var f = frontAt(x / W);
      if (f < 2) continue;
      var dep0 = f * (1 + 0.11 * Math.sin(x * 0.0087 + 1.4))
               + 7 * Math.sin(x * 0.021 + 2.2);
      if (dep0 < 2) continue;
      var cy0 = CY[x];
      var y0 = cy0 | 0; if (y0 < 0) y0 = 0;
      for (var y = y0; y < H; y++) {
        var sp = (y - cy0) / NY;
        var q = dep0 - sp;
        if (q < -8) break;
        var idx = (y * W + x) * 4;
        var k = q > 3 ? 1 : (q + 8) / 11;
        fd[idx]     += (slipBytes[idx]     - fd[idx])     * k * 0.92;
        fd[idx + 1] += (slipBytes[idx + 1] - fd[idx + 1]) * k * 0.92;
        fd[idx + 2] += (slipBytes[idx + 2] - fd[idx + 2]) * k * 0.92;
        var lq = q / 2.2;
        var lip = 1 / (1 + lq * lq);
        fd[idx]     += lip * 82;
        fd[idx + 1] += lip * 69;
        fd[idx + 2] += lip * 47;
      }
    }

    // sand is a count, not a mark: accumulate every grain into a density
    // field and let the tone come out of the accumulation
    dep.fill(0);
    for (var i = 0; i < N; i++) {
      var u = gu[i], s = gs[i];
      var cxp = u * W;
      // a slide fans out as it runs: the lateral offset is a fraction of the
      // room that is left, so no grain is ever pushed off the right edge
      var sx = cxp + (W - 4 - cxp) * 0.20 * (s / gse[i]);
      var sy = CY[cxp | 0] + s * NY;
      var w = gw[i];

      if (gt[i] === 1) {
        // in the air: a short comet, so the flow reads as flow
        var n = gv[i];
        for (var k2 = 0; k2 < 3; k2++) {
          var px = sx - k2 * NX * n * 1.6, py = sy - k2 * NY * n * 1.6;
          if (px < 1 || px >= W - 2 || py < 1 || py >= H - 2) break;
          var xi = px | 0, yi = py | 0;
          var fx = px - xi, fy = py - yi;
          var ww = w * (13.0 - k2 * 3.4);
          var b0 = yi * W + xi;
          dep[b0]         += (1 - fx) * (1 - fy) * ww;
          dep[b0 + 1]     += fx * (1 - fy) * ww;
          dep[b0 + W]     += (1 - fx) * fy * ww;
          dep[b0 + W + 1] += fx * fy * ww;
        }
      } else {
        if (sx < 1 || sx >= W - 2 || sy < 1 || sy >= H - 2) continue;
        var xj = sx | 0, yj = sy | 0;
        var gx2 = sx - xj, gy2 = sy - yj;
        var b1 = yj * W + xj;
        dep[b1]         += (1 - gx2) * (1 - gy2) * w;
        dep[b1 + 1]     += gx2 * (1 - gy2) * w;
        dep[b1 + W]     += (1 - gx2) * gy2 * w;
        dep[b1 + W + 1] += gx2 * gy2 * w;
      }
    }

    // tone-map the accumulation onto the shadowed lee face only
    for (var xx = 0; xx < W; xx++) {
      var cyv = CY[xx];
      var yb = cyv | 0; if (yb < 0) yb = 0;
      for (var yy = yb; yy < H; yy++) {
        var ii = yy * W + xx;
        var dv = dep[ii];
        if (dv < 0.004) continue;
        var li = (dv * 32) | 0;
        if (li > DLUT - 1) li = DLUT - 1;
        var q4 = ii * 4;
        fd[q4]     += dR[li];
        fd[q4 + 1] += dG[li];
        fd[q4 + 2] += dB[li];
      }
    }

    ctx.putImageData(frame, 0, 0);

    if (!still) {
      ctx.save();
      ctx.font = '13px ui-monospace, Menlo, "DejaVu Sans Mono", monospace';
      ctx.shadowColor = 'rgba(0,0,0,0.85)';
      ctx.shadowBlur = 7;
      ctx.fillStyle = 'rgba(255,240,212,0.78)';
      ctx.fillText(REPOSE.toFixed(1) + '\u00B0', 34, H - 34);
      ctx.fillStyle = 'rgba(255,240,212,0.44)';
      ctx.fillText('the angle the sand will hold', 34, H - 16);
      ctx.textAlign = 'right';
      ctx.fillStyle = 'rgba(255,240,212,0.44)';
      ctx.fillText(N.toLocaleString('en-US') + ' grains', W - 34, H - 16);
      ctx.fillStyle = 'rgba(255,240,212,0.36)';
      ctx.fillText(FR > 12 ? 'the face is letting go' : 'the face is filling in', W - 34, H - 34);
      ctx.restore();
    }
  }

  // ---------- loop ----------
  var paused = false, last = 0, acc = 0;

  function tick(now) {
    var t = now / 1000;
    var dt = last ? Math.min(0.05, t - last) : 0.016;
    last = t;
    if (!paused) {
      acc += dt;
      var fixed = 1 / 60, guard = 0;
      while (acc >= fixed && guard < 4) { step(); acc -= fixed; guard++; }
      if (acc > fixed) acc = 0;
    }
    draw();
    requestAnimationFrame(tick);
  }

  // ---------- interaction ----------
  canvas.addEventListener('pointerdown', function (e) {
    e.preventDefault();
    evT = 0.001;
    FR = FMAX;
    release();
  });

  window.addEventListener('keydown', function (e) {
    if (e.key === ' ') { paused = !paused; e.preventDefault(); }
    else if (e.key === 's' || e.key === 'S') {
      var a = document.createElement('a');
      a.download = 'angle-of-repose.png';
      a.href = canvas.toDataURL('image/png');
      a.click();
    }
  });

  // ---------- boot ----------
  buildBase();
  seed();

  if (still) {
    FR = FMAX; release();
    for (var f2 = 0; f2 < 96; f2++) step();
    draw();
    var air = 0;
    for (var a2 = 0; a2 < N; a2++) if (gt[a2] === 1) air++;
    canvas.dataset.ready = '1';
    canvas.dataset.grains = String(N);
    canvas.dataset.fr = FR.toFixed(1);
    canvas.dataset.air = String(air);
  } else {
    requestAnimationFrame(tick);
  }
})();
