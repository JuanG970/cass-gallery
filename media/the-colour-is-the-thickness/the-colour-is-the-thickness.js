/* Thin Film — Cass Gallery piece #110
   Plain Canvas 2D. No library.

   Soap bubbles drifting in front of a window, and the whole picture is one
   physical function: the colour of a soap film is the reflectance of a thin
   dielectric layer at that thickness, integrated against the eye's three
   response curves. Nothing here is tinted by hand — the bands exist because
   the film is 200 nm thick in one place and 600 nm in another, and the
   numbers come out magenta and gold on their own.

   The film drains, so it is thin at the top of every sphere and thick at the
   bottom; that is why the orders crowd downward. It is also seen obliquely
   near the rim, which shortens the optical path and bends the bands into
   arcs. The rim itself is Fresnel: at grazing incidence the film stops
   transmitting and mirrors the room. */

(function () {
  'use strict';

  var W = 960, H = 540;
  var canvas = document.getElementById('bubbles');
  if (!canvas) return;
  var ctx = canvas.getContext('2d', { alpha: false });

  var params = new URLSearchParams(location.search);
  var STILL = params.get('still') === '1';
  function q(k, d) {
    var v = params.get(k);
    return v === null ? d : parseFloat(v);
  }

  /* ======================================================= the thin film
     Reflectance of a free soap film at normal incidence, two-beam:
        R(lambda) = Rm * sin^2(2*pi*n*d/lambda)
     with n = 1.34 and Rm = 4r^2 = 0.084 for r = (1-1.34)/(1+1.34).
     Fold that against analytic CIE 1931 matching functions (Wyman, Sloan &
     Shirley 2013), convert XYZ to linear sRGB, normalise so a fully
     constructive wavelength reads 1.0, and you get a lookup table from
     film thickness to the colour a photograph would record. */
  var LUT_N = 900, LUT_DMAX = 1800.0, N_FILM = 1.34, RM = 0.0841;
  var LUT = new Float32Array(LUT_N * 3);

  function lobe(lam, mu, s1, s2) {
    var s = lam < mu ? s1 : s2;
    var t = (lam - mu) / s;
    return Math.exp(-0.5 * t * t);
  }

  (function buildLut() {
    for (var i = 0; i < LUT_N; i++) {
      var d = LUT_DMAX * i / (LUT_N - 1);
      var X = 0, Y = 0, Z = 0, YS = 0;
      for (var lam = 380; lam <= 728; lam += 4) {
        var a = 2 * Math.PI * N_FILM * d / lam;
        var sn = Math.sin(a);
        var R = RM * sn * sn;
        var cx = 1.056 * lobe(lam, 599.8, 37.9, 31.0) + 0.362 * lobe(lam, 442.0, 16.0, 26.7) - 0.065 * lobe(lam, 501.1, 20.4, 26.2);
        var cy = 0.821 * lobe(lam, 568.8, 46.9, 40.5) + 0.286 * lobe(lam, 530.9, 16.3, 31.1);
        var cz = 1.217 * lobe(lam, 437.0, 11.8, 36.0) + 0.681 * lobe(lam, 459.0, 26.0, 13.8);
        X += R * cx; Y += R * cy; Z += R * cz; YS += cy;
      }
      X /= YS; Y /= YS; Z /= YS;
      var r = 3.2406 * X - 1.5372 * Y - 0.4986 * Z;
      var g = -0.9689 * X + 1.8758 * Y + 0.0415 * Z;
      var b = 0.0557 * X - 0.2040 * Y + 1.0570 * Z;
      LUT[i * 3] = Math.max(r, 0) / RM;
      LUT[i * 3 + 1] = Math.max(g, 0) / RM;
      LUT[i * 3 + 2] = Math.max(b, 0) / RM;
    }
  })();

  // linear -> sRGB byte, precomputed: Math.pow three times per pixel is the
  // single most expensive thing in this sketch
  var GAM = new Uint8Array(1025);
  (function () {
    for (var i = 0; i <= 1024; i++) {
      var c = i / 1024;
      var v = c > 0.0031308 ? 1.055 * Math.pow(c, 1 / 2.4) - 0.055 : 12.92 * c;
      GAM[i] = Math.round(Math.max(0, Math.min(1, v)) * 255);
    }
  })();
  function srgbByte(c) {
    if (c <= 0) return 0;
    if (c >= 1) return 255;
    return GAM[(c * 1024) | 0];
  }

  /* ============================================================== noise
     Value noise is enough: the film's thickness field only needs to be
     smooth and to have a large-scale blob structure. */
  function hash2(x, y, seed) {
    var h = x * 374761393 + y * 668265263 + seed * 2147483647;
    h = (h ^ (h >> 13)) * 1274126177;
    return ((h ^ (h >> 16)) >>> 0) / 4294967296;
  }

  function vnoise(x, y, seed) {
    var xi = Math.floor(x), yi = Math.floor(y);
    var xf = x - xi, yf = y - yi;
    var u = xf * xf * (3 - 2 * xf), v = yf * yf * (3 - 2 * yf);
    var a = hash2(xi, yi, seed), b = hash2(xi + 1, yi, seed);
    var c = hash2(xi, yi + 1, seed), d = hash2(xi + 1, yi + 1, seed);
    return (a + (b - a) * u) + ((c + (d - c) * u) - (a + (b - a) * u)) * v;
  }

  function fbm(x, y, seed, oct) {
    var sum = 0, amp = 1, tot = 0, f = 1;
    for (var o = 0; o < oct; o++) {
      sum += amp * vnoise(x * f, y * f, seed + o * 17);
      tot += amp; amp *= 0.5; f *= 2.07;
    }
    return sum / tot;
  }

  /* =============================================================== room
     The room is baked once: a dark wall and one tall window on the left,
     which is the light that puts a rim on every bubble. */
  var roomCv = document.createElement('canvas');
  roomCv.width = W; roomCv.height = H;
  var rctx = roomCv.getContext('2d');
  var roomData = null;

  function bakeRoom() {
    rctx.fillStyle = '#0e0f12';
    rctx.fillRect(0, 0, W, H);

    // the wall: warm near the window, falling into darkness to the right
    var wg = rctx.createLinearGradient(0, 0, W, 0);
    wg.addColorStop(0.00, 'rgba(52,42,30,0.34)');
    wg.addColorStop(0.35, 'rgba(30,25,20,0.10)');
    wg.addColorStop(1.00, 'rgba(0,0,0,0.60)');
    rctx.fillStyle = wg;
    rctx.fillRect(0, 0, W, H);

    // the window is drawn out of focus on its own canvas, then laid down soft
    var wc = document.createElement('canvas');
    wc.width = W; wc.height = H;
    var w2 = wc.getContext('2d');
    var wx = 96, wy = 34, ww = 276, wh = 436;

    // the light the window throws into the room
    var gg = w2.createRadialGradient(wx + ww * 0.5, wy + wh * 0.45, 12,
                                     wx + ww * 0.5, wy + wh * 0.45, 430);
    gg.addColorStop(0, 'rgba(214,176,124,0.72)');
    gg.addColorStop(0.45, 'rgba(150,116,76,0.34)');
    gg.addColorStop(1, 'rgba(60,44,28,0)');
    w2.fillStyle = gg;
    w2.fillRect(wx - 330, wy - 330, ww + 660, wh + 660);

    // what is outside: a pale sky above, a dark garden below
    var pg = w2.createLinearGradient(wx, wy, wx, wy + wh);
    pg.addColorStop(0.00, '#c9bda4');
    pg.addColorStop(0.34, '#cfc0a2');
    pg.addColorStop(0.52, '#8d8b7c');
    pg.addColorStop(0.62, '#3f453f');
    pg.addColorStop(1.00, '#22261f');
    w2.fillStyle = pg;
    w2.fillRect(wx, wy, ww, wh);

    // a hedge line and a few soft masses of foliage
    w2.fillStyle = 'rgba(26,32,26,0.80)';
    w2.beginPath();
    w2.moveTo(wx, wy + wh * 0.70);
    for (var i = 0; i <= 12; i++) {
      var fx = wx + (ww * i) / 12;
      var fy = wy + wh * (0.66 + 0.05 * Math.sin(i * 1.9) + 0.03 * Math.sin(i * 4.7));
      w2.lineTo(fx, fy);
    }
    w2.lineTo(wx + ww, wy + wh);
    w2.lineTo(wx, wy + wh);
    w2.closePath();
    w2.fill();
    w2.fillStyle = 'rgba(250,244,224,0.22)';
    w2.fillRect(wx + 6, wy + wh * 0.30, ww - 12, wh * 0.08);

    // muntins and frame
    w2.fillStyle = 'rgba(30,25,20,0.92)';
    w2.fillRect(wx + ww * 0.5 - 4.5, wy, 9, wh);
    w2.fillRect(wx, wy + wh * 0.44 - 4.5, ww, 9);
    w2.strokeStyle = 'rgba(16,13,10,0.95)';
    w2.lineWidth = 14;
    w2.strokeRect(wx - 7, wy - 7, ww + 14, wh + 14);
    w2.fillStyle = 'rgba(22,18,14,0.95)';
    w2.fillRect(wx - 26, wy + wh + 4, ww + 52, 16);
    w2.fillStyle = 'rgba(112,96,74,0.55)';
    w2.fillRect(wx - 24, wy + wh + 2, ww + 48, 4);

    rctx.save();
    rctx.filter = 'blur(7px)';
    rctx.drawImage(wc, 0, 0);
    rctx.restore();

    // a shallow pool of reflected window light on the wall, right of the pane
    var lx = rctx.createLinearGradient(wx + ww, 0, W, 0);
    lx.addColorStop(0, 'rgba(150,118,80,0.10)');
    lx.addColorStop(0.55, 'rgba(90,70,48,0.04)');
    lx.addColorStop(1, 'rgba(0,0,0,0)');
    rctx.fillStyle = lx;
    rctx.fillRect(wx + ww, 0, W - wx - ww, H);

    roomData = rctx.getImageData(0, 0, W, H);
  }

  /* ============================================================ bubbles */
  // (x, y, radius, drift px/s, wobble phase, mean thickness, drainage span, seed)
  var BUBBLES = [
    [640, 300, 96, 3.1, 0.7, 6.15, 1.70, 3],
    [512, 196, 62, 4.0, 2.1, 6.32, 1.35, 7],
    [742, 168, 50, 4.6, 4.0, 6.44, 1.15, 11],
    [430, 330, 40, 5.2, 1.4, 6.05, 1.55, 13],
    [586, 402, 34, 5.6, 5.2, 6.50, 1.20, 17],
    [820, 330, 30, 6.0, 3.3, 6.22, 1.45, 19],
    [688, 232, 24, 6.4, 0.2, 6.38, 1.10, 23],
    [470, 116, 21, 6.8, 5.8, 6.28, 1.30, 29],
    [560, 106, 16, 7.2, 2.6, 6.55, 1.05, 31],
    [348, 240, 15, 7.6, 4.6, 6.18, 1.40, 37],
    [620, 358, 12, 8.0, 1.0, 6.40, 1.15, 41],
    [762, 424, 11, 8.4, 3.8, 6.30, 1.25, 43],
    [900, 220, 13, 7.0, 5.0, 6.10, 1.35, 47]
  ];

  // light direction: from the window, up and to the left of the viewer
  var LDX = -0.66, LDY = -0.50, LDZ = 0.56;
  var LN = Math.sqrt(LDX * LDX + LDY * LDY + LDZ * LDZ);
  LDX /= LN; LDY /= LN; LDZ /= LN;

  var out = ctx.createImageData(W, H);
  var od = out.data;
  var rd = null;

  var FIELD = [];
  function buildField(b) {
    var R = Math.ceil(b[2]) + 2;
    var n = 2 * R + 1;
    var f = new Float32Array(n * n);
    var seed = b[7] * 13.7;
    for (var j = 0; j < n; j++) {
      for (var i = 0; i < n; i++) {
        var n1 = fbm((i + seed * 5) * 0.0034 * R / 96, (j + seed * 7) * 0.0034 * R / 96, 11, 3) - 0.5;
        var n2 = fbm((i + seed * 3) * 0.0115 * R / 96, (j + seed * 4) * 0.0115 * R / 96, 37, 2) - 0.5;
        f[j * n + i] = Math.exp(0.95 * n1 + 0.90 * n2);
      }
    }
    return { f: f, n: n, R: R };
  }

  function shadeBubble(b, t) {
    var cx = b[0], cy = b[1], R = b[2];
    var Lmid = b[5] - 0.16 * Math.sin(t * 0.055 + b[7]);   // the film drains
    var Lspan = b[6];
    var seed = b[7] * 13.7;

    var x0 = Math.max(0, Math.floor(cx - R)), x1 = Math.min(W - 1, Math.ceil(cx + R));
    var y0 = Math.max(0, Math.floor(cy - R)), y1 = Math.min(H - 1, Math.ceil(cy + R));
    var invR = 1.0 / R;
    var fld = b[8];
    var fn = fld.n, fR = fld.R, ff = fld.f;

    for (var y = y0; y <= y1; y++) {
      var v = (y - cy) * invR;
      var v2 = v * v;
      if (v2 > 1) continue;
      var rowBase = (y * W) * 4;
      var s = (v + 1) * 0.5;
      if (s < 0) s = 0; else if (s > 1) s = 1;

      // drainage profile: thin at the pole, thick at the foot
      var baseL = Lmid + Lspan * (s - 0.5);
      var thin = s / 0.32;
      if (thin > 1) thin = 1;
      var thinDrop = Math.pow(1 - thin, 1.7) * 1.55;
      var rowScale = Math.exp(baseL - thinDrop);
      var fj = Math.round((y - cy) + fR);

      for (var x = x0; x <= x1; x++) {
        var u = (x - cx) * invR;
        var r2 = u * u + v2;
        if (r2 > 1) continue;
        var zz = Math.sqrt(1 - r2);

        // thickness field, read out of the bubble's own cached map
        var fi_ = Math.round((x - cx) + fR);
        var d = rowScale * ff[fj * fn + fi_];

        // oblique incidence shortens the optical path: the bands bend
        var cosIn = 1 - zz * zz;
        var cost = Math.sqrt(Math.max(0.05, 1 - cosIn / (N_FILM * N_FILM)));
        d *= cost;

        var fi = d * (LUT_N - 1) / LUT_DMAX;
        if (fi < 0) fi = 0; else if (fi > LUT_N - 1.001) fi = LUT_N - 1.001;
        var i0 = fi | 0, fr = fi - i0, o = i0 * 3;
        var ir = LUT[o] + (LUT[o + 3] - LUT[o]) * fr;
        var ig = LUT[o + 1] + (LUT[o + 4] - LUT[o + 1]) * fr;
        var ib = LUT[o + 2] + (LUT[o + 5] - LUT[o + 2]) * fr;

        // a film seen against a bright surround reads paler than a pure
        // interference colour: pull a fifth of the way to its own luminance
        var iy = 0.299 * ir + 0.587 * ig + 0.114 * ib;
        ir = ir * 0.80 + iy * 0.20;
        ig = ig * 0.80 + iy * 0.20;
        ib = ib * 0.80 + iy * 0.20;

        // Fresnel at the sphere's surface
        var g1 = 1 - zz;
        var F = 0.021 + 0.979 * g1 * g1 * (1 + 0.6 * g1);

        // specular: the window's own reflection, placed by the normal
        var ndl = u * LDX + v * LDY + zz * LDZ;
        if (ndl < 0) ndl = 0;
        var rz = 2 * ndl * zz - LDZ;
        if (rz < 0) rz = 0;
        var sp = rz * rz * rz * rz * rz * rz * rz * rz;          // sharp
        var spb = rz * rz * rz * rz * rz * rz * rz * rz * rz * rz * rz * rz * rz * rz;

        // transmitted room, then the film's own reflected colour, then the rim
        var tr = (1 - F * 0.90) * 0.78;
        var p = rowBase + x * 4;
        var kr = rd[p] / 255, kg = rd[p + 1] / 255, kb = rd[p + 2] / 255;

        var rr = kr * tr + ir * (0.40 + 0.60 * F);
        var gg = kg * tr + ig * (0.40 + 0.60 * F);
        var bb = kb * tr + ib * (0.40 + 0.60 * F);
        var rim = F * 0.70;
        rr += rim * 0.95; gg += rim * 0.90; bb += rim * 0.80;
        rr += sp * 1.25; gg += sp * 1.20; bb += sp * 1.07;
        rr += spb * 0.20; gg += spb * 0.194; bb += spb * 0.18;

        od[p] = srgbByte(rr);
        od[p + 1] = srgbByte(gg);
        od[p + 2] = srgbByte(bb);
        od[p + 3] = 255;
      }
    }
  }

  function draw(t) {
    if (!rd) rd = roomData.data;
    od.set(rd);

    // sort by radius so the near bubbles are painted over the far ones
    var list = [];
    for (var i = 0; i < BUBBLES.length; i++) {
      var b = BUBBLES[i];
      // bubbles hang in the light rather than travelling: a slow bob and a
      // slower sideways wander, so the composition holds and the loop closes
      var y = b[1] - 7.5 * Math.sin(t * 0.24 + b[4]) - 2.2 * Math.sin(t * 0.61 + b[4] * 1.7);
      var x = b[0] + 8.5 * Math.sin(t * 0.19 + b[4] * 0.8);
      var r = b[2] * (1 + 0.012 * Math.sin(t * 0.7 + b[4]));
      list.push([x, y, r, b, FIELD[i]]);
    }
    list.sort(function (a, b) { return a[2] - b[2]; });
    for (var j = 0; j < list.length; j++) {
      shadeBubble([list[j][0], list[j][1], list[j][2], 0, list[j][3][4],
                   list[j][3][5], list[j][3][6], list[j][3][7], list[j][4]], t);
    }

    ctx.putImageData(out, 0, 0);
    canvas.dataset.bubbles = BUBBLES.length;
  }

  bakeRoom();
  for (var bi = 0; bi < BUBBLES.length; bi++) FIELD.push(buildField(BUBBLES[bi]));

  if (STILL) {
    draw(q('t', 0));
    canvas.dataset.still = '1';
    return;
  }

  var t0 = performance.now();
  var frames = 0, fWin = 0, fT0 = 0;
  function frame(now) {
    draw((now - t0) / 1000);
    frames++;
    canvas.dataset.frames = frames;
    if (!fT0) fT0 = now;
    fWin++;
    if (now - fT0 > 1000) {
      canvas.dataset.fps = (fWin * 1000 / (now - fT0)).toFixed(1);
      fWin = 0; fT0 = now;
    }
    requestAnimationFrame(frame);
  }
  requestAnimationFrame(frame);
})();
