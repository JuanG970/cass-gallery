/* Underside — plain Canvas 2D, no library.
   A stairwell with one lamp at the foot of the flight, below the frame.
   Someone is standing on the eighth step, above the light.

   The body is drawn twice: once as a black occluder (a hole in the light),
   then again as the only light it catches — an uplight rim computed from
   the gradient of its own distance field, so no normal map is involved.
   Geometry is a real perspective projection; the flight is lit by the
   lamp's inverse square, which is why it dies out before the top. */
(function () {
  'use strict';

  var W = 960, H = 540;
  var F = 880, CX = 480, CY = 452;
  var TH = 4 * Math.PI / 180;
  var CT = Math.cos(TH), ST = Math.sin(TH);
  var YAW = 7.0 * Math.PI / 180;
  var CYw = Math.cos(YAW), SYw = Math.sin(YAW);
  var EYE = 0.90;                            // crouched in the light

  /* the lamp: below the frame, at knee height, 2.2 m out */
  var LX = 0.06, LY = 0.40, LZ = 2.05, LAMP = 3.2;

  /* stairwell, metres */
  var Z0 = 2.62, RUN = 0.285, RISE = 0.178, NSTEP = 15, HALF = 1.48, WALLH = 5.6;
  var FIGSTEP = 8;

  var DEEP = [26, 14, 10], HOT = [255, 222, 180];

  var canvas = document.getElementById('under');
  var ctx = canvas.getContext('2d');
  var still = /[?&]still=1/.test(location.search);

  function clamp(v, a, b) { return v < a ? a : v > b ? b : v; }

  function proj(X, Y, Z) {
    var xr = X * CYw + Z * SYw;
    var zr = -X * SYw + Z * CYw;
    var d = (Y - EYE) * ST + zr * CT;
    var u = (Y - EYE) * CT - zr * ST;
    if (d < 0.05) d = 0.05;
    return [CX + F * xr / d, CY - F * u / d, d];
  }

  /* how strongly a surface with this normal, at this point, meets the lamp */
  function lit(X, Y, Z, nx, ny, nz) {
    var dx = LX - X, dy = LY - Y, dz = LZ - Z;
    var d2 = dx * dx + dy * dy + dz * dz, d = Math.sqrt(d2);
    var c = (nx * dx + ny * dy + nz * dz) / d;
    return c <= 0 ? 0 : c * LAMP / Math.max(0.5, d2);
  }

  function tone(v) {
    /* warm ladder: deep ember up to incandescent, with a punch at the top */
    v = clamp(v, 0, 1);
    var hot = Math.pow(v, 2.2);
    var r = Math.round(clamp(26 + 214 * v + 22 * hot, 0, 255));
    var g = Math.round(clamp(14 + 168 * v + 46 * hot, 0, 255));
    var b = Math.round(clamp(9 + 104 * v + 62 * hot, 0, 255));
    return 'rgb(' + r + ',' + g + ',' + b + ')';
  }

  function quad(p0, p1, p2, p3, fill) {
    ctx.fillStyle = fill;
    ctx.beginPath();
    ctx.moveTo(p0[0], p0[1]); ctx.lineTo(p1[0], p1[1]);
    ctx.lineTo(p2[0], p2[1]); ctx.lineTo(p3[0], p3[1]);
    ctx.closePath(); ctx.fill();
  }

  /* ---------- the flight ---------- */

  function bake() {
    ctx.fillStyle = 'rgb(4,4,7)';
    ctx.fillRect(0, 0, W, H);

    /* walls: dark plaster that only catches the spill near the bottom.
       Drawn as two flat panels with a vertical gradient clipped to them. */
    for (var side = -1; side <= 1; side += 2) {
      var X = HALF * side;
      var p0 = proj(X, 0, Z0 - 0.9), p1 = proj(X, WALLH, Z0 - 0.9);
      var p2 = proj(X, WALLH, Z0 + RUN * NSTEP), p3 = proj(X, 0, Z0 + RUN * NSTEP);
      var yTop = Math.min(p1[1], p2[1]);
      var yBot = Math.max(p0[1], p3[1]);
      ctx.save();
      ctx.beginPath();
      ctx.moveTo(p0[0], p0[1]); ctx.lineTo(p1[0], p1[1]);
      ctx.lineTo(p2[0], p2[1]); ctx.lineTo(p3[0], p3[1]);
      ctx.closePath(); ctx.clip();
      var wg = ctx.createLinearGradient(0, clamp(yTop, -200, H), 0, clamp(yBot, 0, H));
      wg.addColorStop(0, 'rgb(6,5,7)');
      wg.addColorStop(0.55, 'rgb(19,13,11)');
      wg.addColorStop(0.85, 'rgb(48,32,23)');
      wg.addColorStop(1, 'rgb(56,36,24)');
      ctx.fillStyle = wg;
      ctx.fillRect(0, 0, W, H);
      ctx.restore();
    }

    /* the far wall, behind the top of the flight */
    var Zf = Z0 + RUN * NSTEP + 0.9;
    var fw0 = proj(-HALF, 0, Zf), fw1 = proj(HALF, 0, Zf);
    var fw2 = proj(HALF, WALLH, Zf), fw3 = proj(-HALF, WALLH, Zf);
    var fyBot = Math.max(fw0[1], fw1[1]), fyTop = Math.min(fw2[1], fw3[1]);
    ctx.save();
    ctx.beginPath();
    ctx.moveTo(fw0[0], fw0[1]); ctx.lineTo(fw1[0], fw1[1]);
    ctx.lineTo(fw2[0], fw2[1]); ctx.lineTo(fw3[0], fw3[1]);
    ctx.closePath(); ctx.clip();
    var fg2 = ctx.createLinearGradient(0, clamp(fyTop, -400, H), 0, clamp(fyBot, 0, H + 300));
    fg2.addColorStop(0, 'rgb(3,3,5)');
    fg2.addColorStop(0.55, 'rgb(17,12,10)');
    fg2.addColorStop(0.86, 'rgb(38,25,18)');
    fg2.addColorStop(1, 'rgb(56,36,25)');
    ctx.fillStyle = fg2;
    ctx.fillRect(0, 0, W, H);
    ctx.restore();

    /* risers and soffits, from the far step back to the near one */
    for (var i = NSTEP - 1; i >= 0; i--) {
      var zA = Z0 + RUN * i, zB = zA + RUN;
      var yLo = RISE * i, yHi = RISE * (i + 1);

      /* riser: faces the camera, squarely toward the lamp */
      var lr = lit(0, (yLo + yHi) * 0.5, zA, 0, 0, -1);
      var vr = clamp(Math.pow(lr, 0.85) * 1.15, 0, 1);

      var a = proj(-HALF, yHi, zA), b = proj(HALF, yHi, zA);
      var c = proj(HALF, yLo, zA), d = proj(-HALF, yLo, zA);
      var g = ctx.createLinearGradient(a[0], a[1], d[0], d[1]);
      g.addColorStop(0, tone(vr * 0.72));
      g.addColorStop(0.55, tone(vr * 0.94));
      g.addColorStop(1, tone(vr * 0.80));
      quad(a, b, c, d, g);

      /* and across: the lamp is one point, so the flight falls away
         toward both walls instead of being a flat bar of light */
      var hg = ctx.createLinearGradient(a[0], 0, b[0], 0);
      hg.addColorStop(0, 'rgba(4,3,4,0.40)');
      hg.addColorStop(0.26, 'rgba(4,3,4,0.06)');
      hg.addColorStop(0.66, 'rgba(4,3,4,0.03)');
      hg.addColorStop(1, 'rgba(4,3,4,0.38)');
      quad(a, b, c, d, hg);

      /* soffit: the underside of the tread above — faces down, so it is
         lit nearly as hard as the riser even though it is thinner */
      var ls = lit(0, yHi, zA + RUN * 0.5, 0, -1, 0);
      var vs = clamp(Math.pow(ls, 0.85) * 1.05, 0, 1);
      var s1 = proj(-HALF, yHi, zB), s2 = proj(HALF, yHi, zB);
      ctx.fillStyle = tone(vs);
      ctx.beginPath();
      ctx.moveTo(a[0], a[1]); ctx.lineTo(b[0], b[1]);
      ctx.lineTo(s2[0], s2[1]); ctx.lineTo(s1[0], s1[1]);
      ctx.closePath(); ctx.fill();

      /* the nosing: one dark line, and it is what makes it a stair */
      ctx.strokeStyle = 'rgba(10,7,6,0.92)';
      ctx.lineWidth = Math.max(1, 26 / a[2]);
      ctx.beginPath(); ctx.moveTo(a[0], a[1]); ctx.lineTo(b[0], b[1]); ctx.stroke();
    }

    /* air: the lamp lights the room it is in, and this is the only reason
       a dark figure has anything to stand against up there */
    var lpp = proj(LX, LY, LZ);
    ctx.globalCompositeOperation = 'lighter';
    var air = ctx.createRadialGradient(lpp[0], lpp[1], 40, lpp[0], lpp[1], 700);
    air.addColorStop(0, 'rgba(255,196,138,0.20)');
    air.addColorStop(0.28, 'rgba(216,132,78,0.085)');
    air.addColorStop(0.62, 'rgba(140,74,40,0.028)');
    air.addColorStop(1, 'rgba(90,44,24,0)');
    ctx.fillStyle = air;
    ctx.fillRect(0, 0, W, H);

    /* the lamp's own halo, sitting under the bottom edge of the frame */
    var glow = ctx.createRadialGradient(lpp[0], lpp[1], 0, lpp[0], lpp[1], 380);
    glow.addColorStop(0, 'rgba(255,224,178,0.55)');
    glow.addColorStop(0.22, 'rgba(255,180,116,0.26)');
    glow.addColorStop(0.55, 'rgba(212,120,66,0.07)');
    glow.addColorStop(1, 'rgba(160,84,42,0)');
    ctx.fillStyle = glow;
    ctx.fillRect(lpp[0] - 380, lpp[1] - 380, 760, 760);
    ctx.globalCompositeOperation = 'source-over';
  }

  /* ---------- the figure ---------- */

  function figurePath(m, h, w, lift) {
    /* drawn in units of the figure's own height; hands-off proportions */
    function P(u, v) { return [w * u, h * v - (v < 0.315 ? lift : 0)]; }
    function poly(pts) {
      m.beginPath();
      m.moveTo(pts[0][0], pts[0][1]);
      for (var i = 1; i < pts.length; i++) m.lineTo(pts[i][0], pts[i][1]);
      m.closePath(); m.fill();
    }
    function ell(u, v, ru, rv) {
      m.beginPath();
      m.ellipse(w * u, h * v - (v < 0.315 ? lift : 0), w * ru, h * rv, 0, 0, 6.2832);
      m.fill();
    }

    /* head, turned slightly away to its left */
    ell(0.484, 0.075, 0.088, 0.058);
    /* neck */
    poly([P(0.462, 0.118), P(0.540, 0.118), P(0.546, 0.166), P(0.458, 0.166)]);
    /* shoulders (the left one dropped) and torso */
    poly([P(0.356, 0.174), P(0.432, 0.156), P(0.578, 0.162), P(0.652, 0.180),
          P(0.666, 0.252), P(0.648, 0.330), P(0.636, 0.398), P(0.374, 0.396),
          P(0.358, 0.330), P(0.344, 0.254)]);
    /* hips and an uneven coat hem */
    poly([P(0.368, 0.388), P(0.642, 0.390), P(0.650, 0.470), P(0.360, 0.468)]);
    poly([P(0.378, 0.462), P(0.446, 0.474), P(0.512, 0.460), P(0.575, 0.472),
          P(0.638, 0.458), P(0.636, 0.494), P(0.556, 0.502), P(0.470, 0.492),
          P(0.392, 0.500)]);
    /* left arm, hanging */
    poly([P(0.354, 0.190), P(0.408, 0.186), P(0.402, 0.302), P(0.412, 0.404),
          P(0.358, 0.410), P(0.340, 0.302)]);
    /* right arm, held a little away from the body: the gap is what makes
       a silhouette read as a person rather than as a sack */
    poly([P(0.644, 0.190), P(0.700, 0.202), P(0.706, 0.298), P(0.674, 0.386),
          P(0.638, 0.382), P(0.646, 0.298)]);
    ell(0.660, 0.400, 0.030, 0.026);
    /* legs, left taking the weight */
    poly([P(0.386, 0.498), P(0.494, 0.500), P(0.496, 0.760), P(0.478, 0.950),
          P(0.404, 0.948), P(0.392, 0.758)]);
    poly([P(0.512, 0.496), P(0.626, 0.500), P(0.634, 0.756), P(0.622, 0.944),
          P(0.546, 0.946), P(0.520, 0.758)]);
    ell(0.442, 0.962, 0.062, 0.026);
    ell(0.584, 0.956, 0.060, 0.026);
  }

  var FIG = null;

  function buildFigure() {
    var hM = 1.70;
    var X = -0.18, Zs = Z0 + RUN * FIGSTEP, footY = RISE * FIGSTEP;
    var feetP = proj(X, footY, Zs), headP = proj(X, footY + hM, Zs);
    var scrH = feetP[1] - headP[1];

    /* generous box; the ink bbox is measured afterwards */
    var bw = Math.ceil(scrH * 0.95), bh = Math.ceil(scrH * 1.055);
    var pad = 8, mw = bw + pad * 2, mh = bh + pad * 2;

    function maskAt(lift) {
      var mc = document.createElement('canvas');
      mc.width = mw; mc.height = mh;
      var m = mc.getContext('2d');
      m.setTransform(1, 0, 0, 1, pad, pad);
      m.fillStyle = '#fff';
      figurePath(m, scrH, bw, lift);
      return mc;
    }

    function inkBox(mc) {
      var px = mc.getContext('2d').getImageData(0, 0, mw, mh).data;
      var x0 = 1e9, x1 = -1, y0 = 1e9, y1 = -1;
      for (var y = 0; y < mh; y++) {
        for (var x = 0; x < mw; x++) {
          if (px[(y * mw + x) * 4 + 3] > 127) {
            if (x < x0) x0 = x; if (x > x1) x1 = x;
            if (y < y0) y0 = y; if (y > y1) y1 = y;
          }
        }
      }
      return { x0: x0, x1: x1, y0: y0, y1: y1 };
    }

    function distField(mc) {
      var d = new Float32Array(mw * mh);
      var px = mc.getContext('2d').getImageData(0, 0, mw, mh).data;
      var i, x, y, a, b, c, e, v;
      for (i = 0; i < d.length; i++) d[i] = px[i * 4 + 3] > 127 ? 1e9 : 0;

      for (y = 0; y < mh; y++) {
        for (x = 0; x < mw; x++) {
          i = y * mw + x; v = d[i]; if (v === 0) continue;
          if (x > 0) { a = d[i - 1] + 1; if (a < v) v = a; }
          if (y > 0) {
            b = d[i - mw] + 1; if (b < v) v = b;
            if (x > 0) { c = d[i - mw - 1] + 1.414; if (c < v) v = c; }
            if (x < mw - 1) { e = d[i - mw + 1] + 1.414; if (e < v) v = e; }
          }
          d[i] = v;
        }
      }
      for (y = mh - 1; y >= 0; y--) {
        for (x = mw - 1; x >= 0; x--) {
          i = y * mw + x; v = d[i]; if (v === 0) continue;
          if (x < mw - 1) { a = d[i + 1] + 1; if (a < v) v = a; }
          if (y < mh - 1) {
            b = d[i + mw] + 1; if (b < v) v = b;
            if (x < mw - 1) { c = d[i + mw + 1] + 1.414; if (c < v) v = c; }
            if (x > 0) { e = d[i + mw - 1] + 1.414; if (e < v) v = e; }
          }
          d[i] = v;
        }
      }
      return d;
    }

    function blackMask(mc) {
      var o = document.createElement('canvas');
      o.width = mw; o.height = mh;
      var oc = o.getContext('2d');
      oc.drawImage(mc, 0, 0);
      oc.globalCompositeOperation = 'source-in';
      oc.fillStyle = 'rgb(5,4,6)';
      oc.fillRect(0, 0, mw, mh);
      return o;
    }

    /* Two lobes, because the source is not a point: the lit flight below
       the figure is a broad bright surface, so light arrives both from
       underneath and from in front. Screen space, y down. */
    var LB = [0.03, 0.90, 0.436], LF = [0.00, 0.26, 0.966];
    var ldx = LB[0], ldy = LB[1], ldz = LB[2];

    var RAD = 26;                          // half-thickness of a limb, px
    var ink = inkBox(maskAt(0));
    var iy0 = ink.y0, iyh = Math.max(1, ink.y1 - ink.y0);
    var gain = clamp(lit(X, footY + 1.0, Zs, 0, -1, 0) * 9.0, 0.5, 2.4);

    function shade(mc) {
      var d = distField(mc);
      var out = document.createElement('canvas');
      out.width = mw; out.height = mh;
      var octx = out.getContext('2d');
      var img = octx.createImageData(mw, mh);
      var o = img.data;

      for (var y = 1; y < mh - 1; y++) {
        /* the lamp is at the bottom of the flight: less of it reaches
           the shoulders than the hem */
        var vloc = clamp((y - iy0) / iyh, 0, 1);
        var att = gain * (0.05 + 0.95 * Math.pow(vloc, 0.85));

        for (var x = 1; x < mw - 1; x++) {
          var i = y * mw + x;
          var di = d[i];
          if (di <= 0) continue;

          /* the field's gradient points INTO the shape */
          var gx = (d[i + 1] - d[i - 1]) * 0.5;
          var gy = (d[i + mw] - d[i - mw]) * 0.5;
          var gm = Math.sqrt(gx * gx + gy * gy);
          if (gm < 1e-4) continue;
          gx /= gm; gy /= gm;

          var phi = Math.acos(clamp(di / RAD, 0, 1));
          var sp = Math.sin(phi), cp = Math.cos(phi);
          var nx = -gx * sp, ny = -gy * sp, nz = cp;

          var lb = nx * LB[0] + ny * LB[1] + nz * LB[2]; if (lb < 0) lb = 0;
          /* the front lobe is a large source, so it wraps past the
             terminator: that wrap is the only reason the sides of the
             body carry any rim at all against light from underneath */
          var lf = (nx * LF[0] + ny * LF[1] + nz * LF[2] + 0.62) / 1.62;
          if (lf < 0) lf = 0;
          var lam = 0.28 * lb + 0.72 * lf;

          /* the light only lives in the outer shell of the body: without
             this every overhanging hem lights a 15px slab and reads as
             an apron instead of an edge */
          var sh = clamp(1 - di / 9.5, 0, 1);
          sh = sh * sh * (3 - 2 * sh);
          var li = Math.pow(lam, 1.5) * att * (0.13 + 0.87 * sh);
          if (li < 0.006) continue;

          /* the lamp is under this figure, so anything with body below it
             is in its own shadow. Without this every concavity — the gap
             under an arm, the hem, the jaw — glows like a white patch. */
          /* march the shadow ray from just OUTSIDE the surface, or it
             runs along the contour and shadows the whole rim it sits on */
          var ox2 = x - gx * 2.6, oy2 = y - gy * 2.6;
          var occ = 0;
          for (var k = 3; k <= 27; k += 3) {
            var sx = (ox2 + ldx * k + 0.5) | 0;
            var sy = (oy2 + ldy * k + 0.5) | 0;
            if (sy >= mh || sx < 0 || sx >= mw) break;
            if (d[sy * mw + sx] > 0) occ++;
          }
          li *= 1 - 0.62 * (occ / 9);
          if (li < 0.006) continue;

          /* same warm ladder as the flight, so the figure and the stairs
             are lit by visibly the same lamp */
          var L = clamp(li * 1.55, 0, 1);
          var hot = L * L * L;
          var k = i * 4;
          o[k] = clamp(26 + 214 * L + 22 * hot, 0, 255);
          o[k + 1] = clamp(14 + 168 * L + 46 * hot, 0, 255);
          o[k + 2] = clamp(9 + 104 * L + 62 * hot, 0, 255);
          o[k + 3] = clamp(255 * Math.min(1, L * 3.4), 0, 255);
        }
      }
      octx.putImageData(img, 0, 0);
      return out;
    }

    /* place the ink box: horizontally centred on the projected figure,
       its bottom on the projected tread */
    var ox = Math.round(feetP[0] - (ink.x0 + ink.x1) * 0.5);
    var oy = Math.round(feetP[1] - ink.y1);

    var phases = [];
    for (var p = 0; p < 6; p++) {
      var lift = Math.sin(p / 6 * 6.2832) * 1.6;
      var mc = maskAt(lift);
      phases.push({ dark: blackMask(mc), light: shade(mc) });
    }

    FIG = { ox: ox, oy: oy, w: mw, h: mh, phases: phases, att: gain };
  }

  /* ---------- dust ---------- */

  var MOTES = [];
  function initMotes() {
    var s = 20261126;
    function rnd() { s = (s * 1664525 + 1013904223) % 4294967296; return s / 4294967296; }
    for (var i = 0; i < 170; i++) {
      MOTES.push({
        x: -HALF + rnd() * HALF * 2,
        y: 0.20 + rnd() * 3.2,
        z: 2.5 + rnd() * 5.0,
        s: 0.6 + rnd() * 1.6,
        v: 0.014 + rnd() * 0.055,
        ph: rnd() * 6.2832
      });
    }
  }

  var baked = null;

  function drawScene(t) {
    ctx.globalCompositeOperation = 'source-over';
    ctx.globalAlpha = 1;
    ctx.drawImage(baked, 0, 0);

    if (FIG) {
      var ph = ((Math.floor(t / 0.95) % 6) + 6) % 6;
      var f = FIG.phases[ph];
      /* the body: a hole in the light */
      ctx.drawImage(f.dark, FIG.ox, FIG.oy, FIG.w, FIG.h);
      /* then the only part of it the lamp finds */
      ctx.globalCompositeOperation = 'lighter';
      ctx.drawImage(f.light, FIG.ox, FIG.oy, FIG.w, FIG.h);
      ctx.globalCompositeOperation = 'source-over';
    }

    /* the lamp is below the frame; only its breathing reaches up here */
    var lp = proj(LX, LY, LZ);
    var flick = 0.020 * Math.sin(t * 1.9) + 0.011 * Math.sin(t * 6.3 + 1.1);
    ctx.globalCompositeOperation = 'lighter';
    var glow = ctx.createRadialGradient(lp[0], lp[1], 0, lp[0], lp[1], 360);
    glow.addColorStop(0, 'rgba(255,214,164,' + (0.085 + flick) + ')');
    glow.addColorStop(0.5, 'rgba(220,140,84,' + (0.030 + flick * 0.5) + ')');
    glow.addColorStop(1, 'rgba(150,78,38,0)');
    ctx.fillStyle = glow;
    ctx.fillRect(lp[0] - 360, lp[1] - 360, 720, 720);

    /* dust rising off it */
    for (var i = 0; i < MOTES.length; i++) {
      var m = MOTES[i];
      var yy = m.y + (t * m.v) % 3.0;
      var xx = m.x + 0.030 * Math.sin(t * 0.35 + m.ph);
      var p = proj(xx, yy, m.z);
      if (p[0] < -30 || p[0] > W + 30 || p[1] < -30 || p[1] > H + 30) continue;
      var b = lit(xx, yy, m.z, 0, -1, 0);
      var al = clamp(Math.pow(b, 0.5) * 0.05, 0, 0.42) * (0.4 + 0.6 * Math.abs(Math.sin(t * 0.5 + m.ph)));
      if (al < 0.005) continue;
      ctx.fillStyle = 'rgba(255,212,168,' + al.toFixed(3) + ')';
      ctx.fillRect(p[0], p[1], m.s, m.s);
    }
    ctx.globalCompositeOperation = 'source-over';
  }

  /* ---------- boot ---------- */

  function start() {
    bake();
    var b = document.createElement('canvas');
    b.width = W; b.height = H;
    b.getContext('2d').drawImage(canvas, 0, 0);
    baked = b;

    buildFigure();
    initMotes();

    if (still) { drawScene(0); return; }

    var t0 = performance.now(), frames = 0, acc = 0, last = t0;
    function loop(now) {
      var dt = (now - last) / 1000; last = now; acc += dt;
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
