/*  The Analemma — one frame, one year, one clock time
 *  Plain Canvas 2D, no library. 960x540.
 *
 *  Every day of a year the sun is photographed once, at the same time on the
 *  clock, from the same place. Put the 365 photographs on one frame and the
 *  sun does not sit still: it traces a figure eight.
 *
 *  The vertical axis is declination, which swings +/-23.44 deg over the year
 *  because the axis is tilted. The horizontal axis is the equation of time —
 *  the difference between mean clock time and the sun's actual hour angle,
 *  up to about +/-16 minutes because the orbit is an ellipse and the axis is
 *  tilted. Two periodic terms at right angles to each other is a figure
 *  eight, so the shape is a consequence of two real wobbles, not a drawing.
 *
 *  Nothing here draws a line. Each of the 365 days adds one sun to an
 *  additive buffer. Where consecutive days land on top of each other — the
 *  solstice lobes, where declination stops moving — the exposure accumulates
 *  and burns white. Where the sun is moving fast, near the equinoxes, the
 *  same number of days spread into a thin trace. The lobes are not painted
 *  brighter; they are brighter because the sun spends more days there.
 *
 *  Clock times: 9, 11, 13, 15. Click the sky to move the hour. At noon the
 *  eight is tall and nearly vertical; in the afternoon it leans, because the
 *  same wobble is measured across a different part of the sky.
 */
(function () {
  'use strict';

  var W = 960, H = 540;
  var canvas = document.getElementById('analemma');
  var ctx = canvas.getContext('2d');
  var still = /(\?|&)still=1/.test(location.search);

  var DEG = Math.PI / 180;
  var LAT = 40 * DEG;                 // the place we are standing
  var HOURS = [9, 11, 13, 15];        // clock times, one exposure each
  var hourIdx = 3;                    // 3pm: the leaning eight
  var stillDay = 196;                 // mid-July, the frame's one bright sun
  var hourArg = /[?&]hour=(\d+)/.exec(location.search);
  if (hourArg) hourIdx = Math.min(HOURS.length - 1, +hourArg[1]);

  // ---------- solar position (NOAA low-precision series) ----------
  // Declination to about 0.01 deg and the equation of time to a few seconds,
  // finer than one pixel of this frame.
  function sunAt(n, hour) {
    var g = 2 * Math.PI * (n - 1) / 365;
    var eot = 229.18 * (0.000075 + 0.001868 * Math.cos(g) - 0.032077 * Math.sin(g)
      - 0.014615 * Math.cos(2 * g) - 0.040849 * Math.sin(2 * g));     // minutes
    var dec = 0.006918 - 0.399912 * Math.cos(g) + 0.070257 * Math.sin(g)
      - 0.006758 * Math.cos(2 * g) + 0.000907 * Math.sin(2 * g)
      - 0.002697 * Math.cos(3 * g) + 0.00148 * Math.sin(3 * g);       // radians
    // apparent hour angle: mean clock time corrected by the equation of time
    var hh = (hour - 12 + eot / 60) * 15 * DEG;
    var alt = Math.asin(Math.sin(LAT) * Math.sin(dec)
      + Math.cos(LAT) * Math.cos(dec) * Math.cos(hh));
    var az = Math.atan2(-Math.cos(dec) * Math.sin(hh),
      Math.sin(dec) * Math.cos(LAT) - Math.cos(dec) * Math.sin(LAT) * Math.cos(hh));
    return { alt: alt, az: (az + 2 * Math.PI) % (2 * Math.PI) };
  }

  // ---------- camera ----------
  // Gnomic projection onto a frame aimed at the middle of the year. Focal
  // length and pitch are fitted to the sky itself: the eight fills the upper
  // half, and the horizon lands at 80% of the frame height.
  var cam = { az: 0, el: 30 * DEG, f: 400, cx: W / 2, cy: H / 2 };

  function project(az, alt) {
    var ca = Math.cos(alt);
    var px = Math.sin(az) * ca, py = Math.cos(az) * ca, pz = Math.sin(alt);
    var f = [Math.sin(cam.az) * Math.cos(cam.el), Math.cos(cam.az) * Math.cos(cam.el), Math.sin(cam.el)];
    var r = [Math.cos(cam.az), -Math.sin(cam.az), 0];
    var u = [r[1] * f[2] - r[2] * f[1], r[2] * f[0] - r[0] * f[2], r[0] * f[1] - r[1] * f[0]];
    var dotf = px * f[0] + py * f[1] + pz * f[2];
    if (dotf < 0.08) dotf = 0.08;
    return {
      x: cam.cx + cam.f * ((px * r[0] + py * r[1] + pz * r[2]) / dotf),
      y: cam.cy - cam.f * ((px * u[0] + py * u[1] + pz * u[2]) / dotf)
    };
  }

  var pts = [];

  function buildPoints() {
    var days = [], i;
    for (i = 1; i <= 365; i++) days.push(sunAt(i, hour));

    // aim at the vector mean of the year, then fit focal length and pitch
    var sx = 0, sy = 0, sz = 0;
    for (i = 0; i < days.length; i++) {
      var ca = Math.cos(days[i].alt);
      sx += Math.sin(days[i].az) * ca;
      sy += Math.cos(days[i].az) * ca;
      sz += Math.sin(days[i].alt);
    }
    cam.az = Math.atan2(sx, sy);
    if (cam.az < 0) cam.az += 2 * Math.PI;
    cam.el = Math.asin(sz / Math.sqrt(sx * sx + sy * sy + sz * sz));

    for (var pass = 0; pass < 4; pass++) {
      var x0 = 1e9, x1 = -1e9, y0 = 1e9, y1 = -1e9;
      for (i = 0; i < days.length; i++) {
        var p = project(days[i].az, days[i].alt);
        if (p.x < x0) x0 = p.x;
        if (p.x > x1) x1 = p.x;
        if (p.y < y0) y0 = p.y;
        if (p.y > y1) y1 = p.y;
      }
      cam.f *= Math.min((H * 0.58) / Math.max(y1 - y0, 1e-6), (W * 0.33) / Math.max(x1 - x0, 1e-6));
      cam.el = Math.atan((H * 0.35) / cam.f);        // horizon at 85% of H
    }

    pts.length = 0;
    for (i = 0; i < days.length; i++) {
      var q = project(days[i].az, days[i].alt);
      // atmospheric dimming: a low sun comes through more air
      q.w = 0.34 + 0.66 * Math.pow(Math.max(0, Math.sin(days[i].alt)), 0.5);
      q.n = i + 1;
      pts.push(q);
    }
  }

  // ---------- terrain ----------
  // Two ridges and a floor, each a function of x. A filled profile reads as
  // land; a closed shape reads as a hill standing on nothing.
  var SINBITS = 12, SINSIZE = 1 << SINBITS, SINMASK = SINSIZE - 1;
  var SIN = new Float32Array(SINSIZE + 1);
  (function () {
    for (var i = 0; i <= SINSIZE; i++) SIN[i] = Math.sin(i / SINSIZE * 6.283185307179586);
  })();
  var SCS = SINSIZE / 6.283185307179586;
  function sinL(p) { return SIN[((p * SCS) | 0) & SINMASK]; }

  function ridgeFar(x) {
    return 4.4 + 2.9 * sinL(x * 0.0037) + 1.5 * sinL(x * 0.0093 + 1.7) + 0.5 * sinL(x * 0.031 + 4.1);
  }
  function ridgeNear(x) {
    return 2.2 + 2.7 * sinL(x * 0.0031 + 2.2) + 1.2 * sinL(x * 0.0087 + 0.6) + 0.45 * sinL(x * 0.026 + 3.3);
  }
  function horizonRow(deg) { return H / 2 + H * 0.35 - deg * DEG * cam.f; }

  // ---------- layers ----------
  function mk() {
    var c = document.createElement('canvas');
    c.width = W; c.height = H;
    return c;
  }
  var skyC = mk(), sky = skyC.getContext('2d');
  var landC = mk(), land = landC.getContext('2d');
  var burnC = mk(), burn = burnC.getContext('2d');
  var grainC = mk(), grain = grainC.getContext('2d');

  var burnAt = 0, burning = false, hour = HOURS[hourIdx];

  function buildSky() {
    var g = sky.createLinearGradient(0, 0, 0, H);
    g.addColorStop(0.00, '#0a2450');
    g.addColorStop(0.20, '#12406f');
    g.addColorStop(0.46, '#3d7ba4');
    g.addColorStop(0.66, '#8fb9c6');
    g.addColorStop(0.82, '#e2d8be');
    g.addColorStop(1.00, '#c4ae8c');
    sky.fillStyle = g;
    sky.fillRect(0, 0, W, H);

    // the year's own haze, sitting at its mean position
    var mx = 0, my = 0;
    for (var i = 0; i < pts.length; i++) { mx += pts[i].x; my += pts[i].y; }
    mx /= pts.length; my /= pts.length;
    var haze = sky.createRadialGradient(mx, my, 8, mx, my, W * 0.66);
    haze.addColorStop(0, 'rgba(255,240,204,0.40)');
    haze.addColorStop(0.34, 'rgba(255,224,172,0.15)');
    haze.addColorStop(1, 'rgba(255,214,160,0)');
    sky.fillStyle = haze;
    sky.fillRect(0, 0, W, H);

    // land into its own layer: it is the only thing that can occlude a sun
    land.clearRect(0, 0, W, H);
    for (var pass = 0; pass < 2; pass++) {
      var fn = pass === 0 ? ridgeFar : ridgeNear;
      var step = pass === 0 ? 4 : 3;
      land.beginPath();
      land.moveTo(0, H);
      for (var x = 0; x <= W; x += step) land.lineTo(x, horizonRow(fn(x)));
      land.lineTo(W, H);
      land.closePath();
      var fill;
      if (pass === 0) {
        fill = land.createLinearGradient(0, horizonRow(ridgeFar(0)) - 30, 0, horizonRow(ridgeFar(0)) + 80);
        fill.addColorStop(0, '#93a9b6');
        fill.addColorStop(1, '#70879a');
      } else {
        fill = land.createLinearGradient(0, horizonRow(ridgeNear(0)) - 20, 0, H);
        fill.addColorStop(0, '#404f42');
        fill.addColorStop(0.5, '#253027');
        fill.addColorStop(1, '#141c16');
      }
      land.fillStyle = fill;
      land.fill();
    }
    // the crest catches the sky: one pixel, low alpha, both ridges
    land.strokeStyle = 'rgba(206,222,226,0.20)';
    land.lineWidth = 1;
    for (var pr = 0; pr < 2; pr++) {
      var rf = pr === 0 ? ridgeFar : ridgeNear;
      land.beginPath();
      for (var x2 = 0; x2 <= W; x2 += 3) {
        var yy = horizonRow(rf(x2));
        if (x2 === 0) land.moveTo(x2, yy); else land.lineTo(x2, yy);
      }
      land.globalAlpha = pr === 0 ? 0.5 : 0.75;
      land.stroke();
    }
    land.globalAlpha = 1;

    // one conifer in the near foreground, cropped by the frame: depth, and a
    // second scale of tree from the spikes on the ridge
    land.fillStyle = '#0e150f';
    (function pine(x, baseY, hgt, halfW) {
      var tiers = 9;
      for (var k = 0; k < tiers; k++) {
        var f = k / tiers;
        var bw = halfW * (1 - 0.66 * f);
        var by = baseY - hgt * 0.72 * f;
        var th = hgt * 0.34;
        land.beginPath();
        land.moveTo(x, by - th);
        land.lineTo(x + bw, by);
        land.lineTo(x - bw, by);
        land.closePath();
        land.fill();
      }
      land.fillRect(x - 2, baseY - 4, 4, 10);
    })(58, H + 18, 196, 44);
    land.fillStyle = '#0b120c';
    (function pine2(x, baseY, hgt, halfW) {
      var tiers = 8;
      for (var k = 0; k < tiers; k++) {
        var f = k / tiers;
        var bw = halfW * (1 - 0.66 * f);
        var by = baseY - hgt * 0.72 * f;
        var th = hgt * 0.34;
        land.beginPath();
        land.moveTo(x, by - th);
        land.lineTo(x + bw, by);
        land.lineTo(x - bw, by);
        land.closePath();
        land.fill();
      }
    })(934, H + 8, 150, 34);

    // a treeline in clumps, not a fence of spikes: the spacing is what makes
    // a silhouette read as woodland instead of as a saw
    land.fillStyle = '#1a231b';
    var clumps = [52, 148, 246, 352, 520, 664, 796, 908];
    for (var c = 0; c < clumps.length; c++) {
      var count = 3 + ((c * 6151) % 5);
      for (var t = 0; t < count; t++) {
        var tx = clumps[c] + (t - count / 2) * (5 + ((c * 31 + t * 17) % 7)) + ((t * 13 + c * 29) % 5) - 2;
        if (tx < 6 || tx > W - 6) continue;
        var base = horizonRow(ridgeNear(tx)) + 2.5;
        var hgt = 5 + ((c * 7 + t * 11) % 9) + (t === 0 ? 4 : 0);
        var wid = 1.5 + ((c * 3 + t * 5) % 5) * 0.42;
        land.beginPath();
        land.moveTo(tx, base - hgt);
        land.lineTo(tx + wid, base);
        land.lineTo(tx - wid, base);
        land.closePath();
        land.fill();
      }
    }
  }

  function buildGrain() {
    var img = grain.createImageData(W, H), d = img.data;
    var a = 0;
    function r32() {
      a |= 0; a = a + 0x6D2B79F5 | 0;
      var t = Math.imul(a ^ a >>> 15, 1 | a);
      t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t;
      return ((t ^ t >>> 14) >>> 0) / 4294967296;
    }
    for (var i = 0; i < d.length; i += 4) {
      var v = r32();
      d[i] = d[i + 1] = d[i + 2] = v > 0.5 ? 255 : 0;
      d[i + 3] = Math.abs(v - 0.5) * 2 * 24;
    }
    grain.putImageData(img, 0, 0);
  }

  // ---------- one sun, added to the exposure ----------
  // Two passes, and the difference between them is the whole piece. Every
  // day gets a two-pixel grain of light, so the path the sun took is faintly
  // there and the solstice lobes brighten on their own where the days pile
  // up. Every seventh day gets a full exposure: a small hard disk with a
  // short halo, which is what a photograph of the sun looks like on film.
  function addSun(p, r, alpha) {
    var g = burn.createRadialGradient(p.x, p.y, 0, p.x, p.y, r);
    g.addColorStop(0, 'rgba(255,255,250,' + alpha + ')');
    g.addColorStop(0.34, 'rgba(255,246,214,' + (alpha * 0.92) + ')');
    g.addColorStop(0.44, 'rgba(255,226,168,' + (alpha * 0.42) + ')');
    g.addColorStop(0.72, 'rgba(255,196,126,' + (alpha * 0.13) + ')');
    g.addColorStop(1, 'rgba(255,174,96,0)');
    burn.fillStyle = g;
    burn.fillRect(p.x - r, p.y - r, r * 2, r * 2);
  }

  function burnSuns(upto) {
    burn.globalCompositeOperation = 'lighter';
    for (var i = burnAt; i < upto && i < pts.length; i++) {
      var p = pts[i];
      addSun(p, 3.0, 0.012 * p.w);                 // the ghost of every day
      if ((p.n - 1) % 7 === 0) addSun(p, 8.4, 0.44 * p.w);    // one photograph a week
    }
    burnAt = Math.min(upto, pts.length);
  }

  function resetExposure() {
    burn.clearRect(0, 0, W, H);
    burnAt = 0;
  }

  // ---------- compose ----------
  var liveN = stillDay, t0 = 0;

  function drawSun(p, pulse) {
    ctx.save();
    ctx.globalCompositeOperation = 'lighter';
    var fl = ctx.createRadialGradient(p.x, p.y, 0, p.x, p.y, 34);
    fl.addColorStop(0, 'rgba(255,251,232,' + (0.26 + 0.12 * pulse) + ')');
    fl.addColorStop(0.26, 'rgba(255,231,176,' + (0.13 + 0.07 * pulse) + ')');
    fl.addColorStop(1, 'rgba(255,192,112,0)');
    ctx.fillStyle = fl;
    ctx.fillRect(p.x - 34, p.y - 34, 68, 68);
    var core = ctx.createRadialGradient(p.x, p.y, 0, p.x, p.y, 6.5);
    core.addColorStop(0, 'rgba(255,255,253,0.98)');
    core.addColorStop(0.5, 'rgba(255,248,220,0.6)');
    core.addColorStop(1, 'rgba(255,238,186,0)');
    ctx.fillStyle = core;
    ctx.fillRect(p.x - 7, p.y - 7, 14, 14);
    ctx.restore();
  }

  function draw(t) {
    ctx.drawImage(skyC, 0, 0);
    ctx.save();
    ctx.globalCompositeOperation = 'lighter';
    ctx.drawImage(burnC, 0, 0);
    ctx.restore();

    if (pts.length && !still) {
      var li = Math.floor(liveN) - 1;
      if (li < 0) li = 0;
      if (li > pts.length - 1) li = pts.length - 1;
      drawSun(pts[li], 0.5 + 0.5 * Math.sin(t * 0.8));
    }

    ctx.drawImage(landC, 0, 0);

    var vg = ctx.createRadialGradient(W / 2, H * 0.52, H * 0.30, W / 2, H * 0.52, H * 0.98);
    vg.addColorStop(0, 'rgba(0,0,0,0)');
    vg.addColorStop(1, 'rgba(8,10,16,0.36)');
    ctx.fillStyle = vg;
    ctx.fillRect(0, 0, W, H);
    ctx.globalAlpha = 0.45;
    ctx.drawImage(grainC, 0, 0);
    ctx.globalAlpha = 1;
  }

  // ---------- boot ----------
  buildPoints();
  buildSky();
  buildGrain();
  resetExposure();

  if (still) {
    burnSuns(pts.length);
    draw(0);
    canvas.dataset.frames = '1';
  } else {
    burning = true;

    function loop(ts) {
      if (!t0) t0 = ts;
      var t = (ts - t0) / 1000;
      if (burning) {
        burnSuns(burnAt + 6);
        if (burnAt >= pts.length) burning = false;
      }
      liveN = 1 + ((t * (364 / 90)) % 364);
      draw(t);
      requestAnimationFrame(loop);
    }
    requestAnimationFrame(loop);

    canvas.addEventListener('click', function () {
      hourIdx = (hourIdx + 1) % HOURS.length;
      hour = HOURS[hourIdx];
      buildPoints();
      buildSky();
      resetExposure();
      burning = true;
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
