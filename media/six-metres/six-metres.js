/* Six Metres — plain Canvas 2D, no library.
   A single-scatter fog field with one lamp, two people, and the distance
   between them. The field is baked once; the live layer only drifts. */
(function () {
  'use strict';

  var W = 960, H = 540, F = 1060, EYE = 1.55;
  var SIG = 1 / 30, FOGMAX = 60, SRC = 1.10;

  var POST = [2.60, 4.00, 12.5];          // post foot position
  var ARM = 0.65;                          // bracket length, light hangs at its end
  var LX = POST[0] - ARM, LY = POST[1], LZ = POST[2];

  var ALB = 0.30, KSURF = 20, KAIR = 0.020, KPOST = 1.0;
  var KRIM = 3.4, RIMW = 2.4, WET = 4.5, CORE = 5.0;
  var POSTW = 0.055, POSTALB = 0.55, EXP = 3.0;

  // six metres exactly, by construction
  var NEAR = { x: -0.80, z: 2.40, rim: 16.0, albedo: 0.10, shw: 0.36, shs: 0.90 };
  var FAR = { x: 0.95, z: 2.40 + Math.sqrt(36 - 1.75 * 1.75), rim: 2.6,
              albedo: 0.10, shw: 0.34, shs: 0.85 };
  var FIGS = [FAR, NEAR];                  // far first, then near

  var canvas = document.getElementById('six');
  var ctx = canvas.getContext('2d');
  var still = /[?&]still=1/.test(location.search);

  /* ---------- small helpers ---------- */
  function project(x, y, z, f, cx, cy) {
    return [cx + f * x / z, cy - f * (y - EYE) / z];
  }

  function boxBlur(src, w, h, r, passes) {
    var a = Float32Array.from(src), b = new Float32Array(w * h);
    var rr = Math.max(1, Math.round(r));
    for (var p = 0; p < passes; p++) {
      for (var y = 0; y < h; y++) {
        var row = y * w, acc = 0;
        for (var x = -rr; x <= rr; x++) acc += a[row + Math.min(w - 1, Math.max(0, x))];
        for (x = 0; x < w; x++) {
          b[row + x] = acc / (2 * rr + 1);
          acc += a[row + Math.min(w - 1, x + rr + 1)] - a[row + Math.max(0, x - rr)];
        }
      }
      for (x = 0; x < w; x++) {
        var acc2 = 0;
        for (var y2 = -rr; y2 <= rr; y2++) acc2 += b[Math.min(h - 1, Math.max(0, y2)) * w + x];
        for (y = 0; y < h; y++) {
          a[y * w + x] = acc2 / (2 * rr + 1);
          acc2 += b[Math.min(h - 1, y + rr + 1) * w + x] - b[Math.max(0, y - rr) * w + x];
        }
      }
    }
    return a;
  }

  /* ---------- figure silhouettes ---------- */
  var PROFILE = [
    [-0.098, 1.520], [-0.086, 1.588], [-0.058, 1.660], [-0.014, 1.700],
    [0.026, 1.706], [0.056, 1.688], [0.072, 1.660], [0.080, 1.628],
    [0.077, 1.608], [0.080, 1.598], [0.098, 1.578], [0.106, 1.560],
    [0.100, 1.550], [0.086, 1.544], [0.088, 1.530], [0.093, 1.520],
    [0.089, 1.510], [0.084, 1.500], [0.079, 1.494], [0.083, 1.484],
    [0.076, 1.472], [0.058, 1.462], [0.030, 1.452], [0.004, 1.444],
    [-0.008, 1.412], [-0.014, 1.372], [0.006, 1.340], [0.052, 1.316],
    [0.098, 1.300], [0.150, 1.276], [0.196, 1.220], [0.216, 1.120],
    [0.222, 0.900],
    [-0.176, 0.900], [-0.182, 1.120], [-0.168, 1.220], [-0.140, 1.286],
    [-0.116, 1.330], [-0.104, 1.386], [-0.100, 1.440], [-0.106, 1.482]
  ];

  var OUTER = [[0.86, 0.170], [0.95, 0.186], [1.10, 0.200], [1.25, 0.214],
               [1.38, 0.222], [1.43, 0.206], [1.47, 0.120], [1.50, 0.056]];

  function makeMask(fig) {
    var ss = 2, cw = W * ss, ch = H * ss, f = F * ss, cx = cw / 2, cy = ch / 2;
    var off = document.createElement('canvas');
    off.width = cw; off.height = ch;
    var c = off.getContext('2d');
    c.fillStyle = '#fff';

    function poly(pts, fill) {
      c.beginPath();
      for (var i = 0; i < pts.length; i++) {
        var p = project(fig.x + pts[i][0], pts[i][1], fig.z, f, cx, cy);
        if (i === 0) c.moveTo(p[0], p[1]); else c.lineTo(p[0], p[1]);
      }
      c.closePath();
      c.fillStyle = fill;
      c.fill();
    }
    function ell(x0, y0, rx, ry, fill) {
      var p = project(fig.x + x0, y0, fig.z, f, cx, cy);
      c.beginPath();
      c.ellipse(p[0], p[1], f * rx / fig.z, f * ry / fig.z, 0, 0, 6.2832);
      c.fillStyle = fill;
      c.fill();
    }

    if (fig === NEAR) {
      poly(PROFILE, '#fff');
    } else {
      var L = [], R = [];
      for (var i = 0; i < OUTER.length; i++) {
        L.push([-OUTER[i][1], OUTER[i][0]]);
        R.push([OUTER[i][1], OUTER[i][0]]);
      }
      poly(L.concat(R.reverse()), '#fff');
      poly([[-0.170, 0.86], [0.170, 0.86], [0.156, 0.83], [-0.156, 0.83]], '#fff');
      poly([[-0.150, 0.86], [-0.022, 0.86], [-0.014, 0.10], [-0.116, 0.10]], '#fff');
      poly([[0.022, 0.86], [0.150, 0.86], [0.116, 0.10], [0.014, 0.10]], '#fff');
      ell(-0.062, 0.038, 0.058, 0.026, '#fff');
      ell(0.062, 0.038, 0.058, 0.026, '#fff');
      poly([[-0.052, 1.36], [0.052, 1.36], [0.046, 1.512], [-0.046, 1.512]], '#fff');
      ell(0.0, 1.612, 0.096, 0.118, '#fff');
    }

    var down = document.createElement('canvas');
    down.width = W; down.height = H;
    var dc = down.getContext('2d');
    dc.imageSmoothingEnabled = true;
    dc.drawImage(off, 0, 0, W, H);
    var id = dc.getImageData(0, 0, W, H).data;
    var m = new Float32Array(W * H);
    for (var k = 0; k < W * H; k++) m[k] = id[k * 4 + 3] / 255;
    return m;
  }

  /* ---------- the bake ---------- */
  function bake() {
    var img = ctx.createImageData(W, H), d = img.data;

    var masks = FIGS.map(makeMask);
    var mb = masks.map(function (m) { return boxBlur(m, W, H, 2, 2); });
    var mb2 = masks.map(function (m) { return boxBlur(m, W, H, 3, 2); });

    var sxPost = W / 2 + F * POST[0] / POST[2];
    var yTop = H / 2 - F * (POST[1] - EYE) / POST[2];
    var yBot = H / 2 + F * EYE / POST[2];
    var hw = F * POSTW / POST[2];
    var brx0 = W / 2 + F * LX / POST[2];
    var brt = F * 0.05 / POST[2];

    var postMask = new Float32Array(W * H);
    for (var y = 0; y < H; y++) {
      var pyc = y + 0.5;
      for (var x = 0; x < W; x++) {
        var pxc = x + 0.5;
        var inp = Math.abs(pxc - sxPost) < hw && pyc > yTop && pyc < yBot;
        var inb = pxc > brx0 && pxc < sxPost + hw && Math.abs(pyc - yTop) < brt;
        if (inp || inb) postMask[y * W + x] = 1;
      }
    }
    postMask = boxBlur(postMask, W, H, 1, 1);

    var lxS = W / 2 + F * LX / POST[2];
    var lyS = H / 2 - F * (LY - EYE) / POST[2];
    var figDir = FIGS.map(function (f) {
      var p = project(f.x, 1.0, f.z, F, W / 2, H / 2);
      var vx = lxS - p[0], vy = lyS - p[1], n = Math.hypot(vx, vy) || 1;
      return [vx / n, vy / n];
    });

    for (y = 0; y < H; y++) {
      for (x = 0; x < W; x++) {
        var dx = (x + 0.5 - W / 2) / F, dy = (y + 0.5 - H / 2) / F;
        var N = Math.sqrt(dx * dx + dy * dy + 1);
        var ux = dx / N, uy = -dy / N, uz = 1 / N;

        // closed-form single scatter: ∫ ds/((s-a)²+b²)
        var vx2 = LX, vy2 = LY - EYE, vz2 = LZ;
        var aa = ux * vx2 + uy * vy2 + uz * vz2;
        var vv = vx2 * vx2 + vy2 * vy2 + vz2 * vz2;
        var b = Math.sqrt(Math.max(vv - aa * aa, 0));
        if (b < SRC) b = SRC;
        var att = Math.exp(-SIG * (aa > 0 ? aa : 0));
        var atA = Math.atan(aa / b);
        var full = att * (Math.atan((FOGMAX - aa) / b) + atA) / b;

        var scene = 0;
        var tg = dy > 1e-5 ? EYE / dy : -1;

        if (tg > 0) {
          var gx = dx * tg, gz = tg;
          var rx = gx - LX, rz = gz - LZ;
          var r2 = rx * rx + LY * LY + rz * rz;
          var r = Math.sqrt(r2);
          var E = LY / (r2 * r);
          var patch = 0.5 + 0.5 * Math.sin(gx * 0.52 + gz * 0.19) * Math.sin(gz * 0.71 - gx * 0.17);
          var fine = 0.5 + 0.5 * Math.sin(gx * 3.1 - gz * 2.3) * Math.sin(gz * 2.7 + gx * 1.9);
          var alb = ALB * (0.84 + 0.26 * patch + 0.10 * fine);
          var diff = alb * E * Math.exp(-SIG * (r + tg));

          // specular lobe on wet tarmac
          var Vn = Math.sqrt(gx * gx + EYE * EYE + gz * gz);
          var vX = -gx / Vn, vY = EYE / Vn, vZ = -gz / Vn;
          var ln = Math.sqrt(rx * rx + LY * LY + rz * rz);
          var Hx = -rx / ln + vX, Hy = LY / ln + vY, Hz = -rz / ln + vZ;
          var hn = Math.sqrt(Hx * Hx + Hy * Hy + Hz * Hz) || 1;
          var hy = Math.abs(Hy / hn);
          var spec = Math.pow(hy, 22) * WET / r2 * Math.exp(-SIG * (ln + tg));

          // cast shadow: vertical body extruded away from the light
          var shade = 0;
          for (var fi = 0; fi < FIGS.length; fi++) {
            var fg = FIGS[fi];
            var k = 1.72 / (LY - 1.72);
            var bx = fg.x + (fg.x - LX) * k, bz = fg.z + (fg.z - LZ) * k;
            var ax0 = fg.x, az0 = fg.z;
            var svx = bx - ax0, svz = bz - az0;
            var wx = gx - ax0, wz = gz - az0;
            var tt = (wx * svx + wz * svz) / (svx * svx + svz * svz);
            tt = tt < 0 ? 0 : tt > 1 ? 1 : tt;
            var dd = Math.hypot(wx - tt * svx, wz - tt * svz);
            var q = 1 - (dd / fg.shw) * (dd / fg.shw);
            if (q > 0) {
              var v2 = fg.shs * Math.pow(q, 0.65);
              if (v2 > shade) shade = v2;
            }
          }
          scene = (diff + spec) * KSURF * (1 - 0.8 * shade) * Math.exp(-SIG * tg);
        }

        scene += full * KAIR;

        // post and bracket
        var pmv = postMask[y * W + x];
        if (pmv > 0.002) {
          var Yp = EYE - (y + 0.5 - H / 2) * POST[2] / F;
          var Xp = (x + 0.5 - W / 2) * POST[2] / F;
          var dp2 = (Xp - LX) * (Xp - LX) + (Yp - (LY - 0.03)) * (Yp - (LY - 0.03));
          if (dp2 < 0.30) dp2 = 0.30;
          var postE = Math.min(POSTALB / dp2, 0.55) * Math.exp(-SIG * (Math.sqrt(dp2) + POST[2]));
          scene = scene * (1 - pmv) + pmv * postE * KPOST;
        }

        // figures
        for (var fj = 0; fj < FIGS.length; fj++) {
          var m = masks[fj][y * W + x];
          if (m <= 0.02) continue;
          var f2 = FIGS[fj], dpt = f2.z;
          var front = att * (Math.atan((dpt - aa) / b) + atA) / b * KAIR;

          var i0 = y * W + x;
          var gxN = (mb[fj][y * W + Math.min(W - 1, x + 1)] - mb[fj][y * W + Math.max(0, x - 1)]);
          var gyN = (mb[fj][Math.min(H - 1, y + 1) * W + x] - mb[fj][Math.max(0, y - 1) * W + x]);
          var gn = Math.hypot(gxN, gyN) || 1;
          // the mask gradient points into the body; flip it to get the outward normal
          var nx = -gxN / gn, ny = -gyN / gn;
          var dwv = nx * figDir[fj][0] + ny * figDir[fj][1];
          if (dwv < 0) dwv = 0;

          var ew = m - mb2[fj][i0];
          if (ew < 0) ew = 0; else if (ew > 0.30) ew = 0.30;
          ew = ew / 0.30;

          var pxp = dx * dpt, pyp = EYE - dy * dpt;
          var lvx = LX - pxp, lvy = LY - pyp, lvz = LZ - dpt;
          var ln2 = Math.sqrt(lvx * lvx + lvy * lvy + lvz * lvz);
          var Ypix = EYE - (y + 0.5 - H / 2) * dpt / F;
          var hd = (Ypix - 1.545) / 0.190;
          var hmod = 0.44 + 0.56 * Math.exp(-hd * hd);

          var rad = f2.albedo * LY / (ln2 * ln2 * ln2)
                  + f2.rim * KRIM * ew * Math.pow(dwv, 0.7) * hmod / (ln2 * ln2);

          // wet reflection under the feet
          var feet = H / 2 + F * EYE / dpt;
          if (y > feet && feet < H - 4) {
            var src = feet - (y - feet) / 0.42;
            if (src > 0 && src < H) {
              var rm = mb2[fj][Math.floor(src) * W + x];
              var fade = Math.exp(-(y - feet) / 26);
              var rb = rm * fade * 0.62;
              scene = scene * (1 - rb);
            }
          }
          scene = rad * Math.exp(-SIG * dpt) + front;
        }

        // the lamp itself
        var dlx = x + 0.5 - lxS, dly = y + 0.5 - lyS;
        var rr2 = dlx * dlx + dly * dly;
        scene += Math.exp(-rr2 / (2.2 * 2.2)) * CORE
               + Math.exp(-rr2 / (8.0 * 8.0)) * CORE * 0.12;

        // tone map
        var xv = scene * EXP;
        if (xv < 0) xv = 0;
        var yv = Math.pow(1 - Math.exp(-xv), 1 / 2.2);
        var tt2 = scene * EXP * 1.5;
        if (tt2 > 1) tt2 = 1;
        var i4 = (y * W + x) * 4;
        d[i4] = 255 * yv * (0.42 + (1.00 - 0.42) * tt2);
        d[i4 + 1] = 255 * yv * (0.58 + (0.70 - 0.58) * tt2);
        d[i4 + 2] = 255 * yv * (1.00 + (0.42 - 1.00) * tt2);
        d[i4 + 3] = 255;
      }
    }
    ctx.putImageData(img, 0, 0);
  }

  /* ---------- drifting wisps, visible only inside the lamp's light ---------- */
  var wisps = [];
  function makeWisp(r) {
    var c = document.createElement('canvas');
    c.width = c.height = r * 2;
    var g = c.getContext('2d');
    var grd = g.createRadialGradient(r, r, 0, r, r, r);
    grd.addColorStop(0, 'rgba(255,214,160,0.55)');
    grd.addColorStop(0.45, 'rgba(255,196,140,0.20)');
    grd.addColorStop(1, 'rgba(255,190,130,0)');
    g.fillStyle = grd;
    g.fillRect(0, 0, r * 2, r * 2);
    return c;
  }

  function initWisps() {
    var spec = [[150, 78, 11.0, 118, 205], [220, 60, 7.5, 300, 150],
                [120, 96, 14.5, 96, 250], [280, 130, 5.2, 430, 300],
                [170, 110, 9.0, 250, 380]];
    for (var i = 0; i < spec.length; i++) {
      wisps.push({ img: makeWisp(spec[i][1] | 0), r: spec[i][1],
                   sp: spec[i][2], x0: spec[i][3], y0: spec[i][4],
                   ph: spec[i][0] });
    }
  }

  function drawScene(t) {
    ctx.clearRect(0, 0, W, H);
    if (bake.canvas) ctx.drawImage(bake.canvas, 0, 0);

    // wisps: only where the lamp's glow is, so they read as lit fog
    ctx.globalCompositeOperation = 'lighter';
    var lxS = W / 2 + F * LX / POST[2];
    var lyS = H / 2 - F * (LY - EYE) / POST[2];
    for (var i = 0; i < wisps.length; i++) {
      var w = wisps[i];
      var span = W + 2 * w.r;
      var xp = ((w.x0 + t * w.sp) % span) - w.r;
      var yp = w.y0 + 8 * Math.sin(t * 0.09 + i);
      var ddx = (xp - lxS) / 420, ddy = (yp - lyS) / 300;
      var lit = Math.exp(-(ddx * ddx + ddy * ddy) * 2.2);
      if (lit < 0.04) continue;
      ctx.globalAlpha = 0.24 * lit;
      ctx.drawImage(w.img, xp, yp, w.r * 2, w.r * 2);
    }

    // a lamp with a slightly tired ballast
    var flick = 1 + 0.045 * Math.sin(t * 2.3) + 0.025 * Math.sin(t * 5.1 + 1.3)
              + 0.012 * Math.sin(t * 11.7 + 0.4);
    var g2 = ctx.createRadialGradient(lxS, lyS, 0, lxS, lyS, 120);
    g2.addColorStop(0, 'rgba(255,226,180,' + (0.16 * flick) + ')');
    g2.addColorStop(0.4, 'rgba(255,196,140,' + (0.05 * flick) + ')');
    g2.addColorStop(1, 'rgba(255,180,120,0)');
    ctx.globalAlpha = 1;
    ctx.fillStyle = g2;
    ctx.fillRect(lxS - 120, lyS - 120, 240, 240);
    ctx.globalCompositeOperation = 'source-over';
  }

  /* ---------- boot ---------- */
  var t0 = performance.now();

  function start() {
    bake();
    var baked = document.createElement('canvas');
    baked.width = W; baked.height = H;
    baked.getContext('2d').drawImage(canvas, 0, 0);
    bake.canvas = baked;

    initWisps();
    if (still) { drawScene(0); return; }

    var frames = 0, acc = 0, last = performance.now();
    function loop(now) {
      var dt = (now - last) / 1000;
      last = now;
      acc += dt;
      drawScene((now - t0) / 1000);
      frames++;
      if (acc >= 1) { canvas.dataset.fps = (frames / acc).toFixed(1); frames = 0; acc = 0; }
      requestAnimationFrame(loop);
    }
    requestAnimationFrame(loop);
  }

  if (document.readyState === 'complete') start();
  else window.addEventListener('load', start);
})();
