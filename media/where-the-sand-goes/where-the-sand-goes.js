/*  Where the Sand Goes — a Chladni plate
 *  Plain Canvas 2D, no library. 960x540.
 *
 *  A steel plate is driven from a bolt at its centre. Sand is scattered on it.
 *  Where the plate is moving the sand is thrown into the air; where the plate
 *  is still, it lands and stays. The still places are the nodal lines of the
 *  standing wave, so the sand ends up drawing the zeros of the vibration.
 *
 *  f(u,v) = cos(n.pi.u) cos(m.pi.v) - cos(m.pi.u) cos(n.pi.v)
 *
 *  Grain model: a grain is either resting or in the air. A resting grain in a
 *  moving region gets thrown; an airborne grain that slows to a stop in a still
 *  region sticks. There is no attraction term — the figure is where the sand
 *  stops, not where it is pulled.
 */
(function () {
  'use strict';

  var W = 960, H = 540;
  var PLATE = 430;                    // plate side, px
  var PX = (W - PLATE) / 2;           // 260
  var PY = (H - PLATE) / 2;           // 50
  var GRID = 221;                     // field samples across the plate (2 px apart)
  var GSTEP = PLATE / (GRID - 1);
  var N = 42000;                      // grains
  var HOLD = 9.0, EXCITE = 1.0;       // seconds per mode / seconds of ringing
  var STICK = 0.075;                  // |f| below this is "still enough to land"

  var canvas = document.getElementById('sand');
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
  var rnd = mulberry32(0xC0FFEE);

  // ---------- surfaces ----------
  var voidCanvas = document.createElement('canvas');
  voidCanvas.width = W; voidCanvas.height = H;

  var plateCanvas = document.createElement('canvas');
  plateCanvas.width = PLATE; plateCanvas.height = PLATE;
  var plateCtx = plateCanvas.getContext('2d');

  var frame = plateCtx.createImageData(PLATE, PLATE);
  var baseBytes = null;               // steel under the sand, precomputed

  var density = new Float32Array(PLATE * PLATE);
  var glowA = new Float32Array(PLATE * PLATE);
  var glowB = new Float32Array(PLATE * PLATE);
  var tmp = new Float32Array(PLATE * PLATE);

  // sand tone ramp: index 0..1023 -> added colour
  var RAMP = 1024;
  var rampR = new Uint8ClampedArray(RAMP), rampG = new Uint8ClampedArray(RAMP),
      rampB = new Uint8ClampedArray(RAMP);
  var glowR = new Uint8ClampedArray(RAMP), glowG = new Uint8ClampedArray(RAMP),
      glowBc = new Uint8ClampedArray(RAMP);

  (function buildRamps() {
    var sand = [
      [0.00, 0, 0, 0],
      [0.10, 30, 23, 13],
      [0.30, 104, 82, 46],
      [0.56, 186, 158, 106],
      [0.80, 232, 214, 172],
      [1.00, 255, 252, 240]
    ];
    var glow = [
      [0.00, 0, 0, 0],
      [0.40, 18, 12, 5],
      [0.75, 52, 36, 16],
      [1.00, 84, 61, 28]
    ];
    function fill(stops, r, g, b) {
      for (var i = 0; i < RAMP; i++) {
        var t = i / (RAMP - 1), k = 0;
        while (k < stops.length - 2 && t > stops[k + 1][0]) k++;
        var a = stops[k], c = stops[k + 1];
        var f = (t - a[0]) / Math.max(1e-6, c[0] - a[0]);
        f = f < 0 ? 0 : f > 1 ? 1 : f;
        r[i] = a[1] + (c[1] - a[1]) * f;
        g[i] = a[2] + (c[2] - a[2]) * f;
        b[i] = a[3] + (c[3] - a[3]) * f;
      }
    }
    fill(sand, rampR, rampG, rampB);
    fill(glow, glowR, glowG, glowBc);
  })();

  function buildVoid() {
    var c = voidCanvas.getContext('2d');
    var g = c.createRadialGradient(W * 0.28, H * 0.10, 30, W * 0.46, H * 0.48, W * 0.90);
    g.addColorStop(0, '#101319');
    g.addColorStop(0.42, '#090b0f');
    g.addColorStop(1, '#040507');
    c.fillStyle = g;
    c.fillRect(0, 0, W, H);
    // a little dust in the air, so the void is not a flat card
    for (var i = 0; i < 500; i++) {
      c.fillStyle = 'rgba(188,204,236,' + (0.010 + rnd() * 0.030).toFixed(3) + ')';
      c.fillRect(rnd() * W | 0, rnd() * H | 0, 1, 1);
    }
  }

  function buildPlate() {
    var img = plateCtx.createImageData(PLATE, PLATE);
    var d = img.data;
    var cx = PLATE / 2, cy = PLATE / 2;
    for (var y = 0; y < PLATE; y++) {
      for (var x = 0; x < PLATE; x++) {
        var i = (y * PLATE + x) * 4;
        // bead-blasted steel: soft cloudy mottling from two incommensurate
        // waves, plus a fine speckle. No single-axis grain — a regular streak
        // reads as scanlines, not metal.
        var mottle = (Math.sin(x * 0.071 + y * 0.031) + Math.sin(x * 0.017 - y * 0.043)) * 0.5;
        var speck = (((x * 7919 + y * 104729) % 101) / 101);
        var base = 34 + mottle * 3.4 + speck * 6.0;
        // the lamp: upper left, close, so the sheen falls off fast
        var dx = (x - PLATE * 0.30) / 150, dy = (y - PLATE * 0.18) / 120;
        var sheen = Math.exp(-(dx * dx + dy * dy)) * 40;
        // a second, weaker reflection low right
        var ex2 = (x - PLATE * 0.78) / 130, ey2 = (y - PLATE * 0.86) / 90;
        var sheen2 = Math.exp(-(ex2 * ex2 + ey2 * ey2)) * 12;
        // a gentle falloff to the rim, so the plate has some curvature
        var ex = (x - cx) / cx, ey = (y - cy) / cy;
        var rr = Math.sqrt(ex * ex + ey * ey) * 0.7071;
        var vig = 1 - 0.30 * Math.pow(Math.max(0, rr - 0.45) / 0.55, 1.6);
        var v = (base + sheen + sheen2) * vig;
        d[i] = v * 0.92;
        d[i + 1] = v * 0.97;
        d[i + 2] = v * 1.18;
        d[i + 3] = 255;
      }
    }
    plateCtx.putImageData(img, 0, 0);

    // the bolt at the centre: the driver. Always a node, so it wears a cap of sand.
    var bg = plateCtx.createRadialGradient(cx - 4, cy - 5, 1, cx, cy, 16);
    bg.addColorStop(0, '#6a7280');
    bg.addColorStop(0.5, '#2b313b');
    bg.addColorStop(0.86, '#181c23');
    bg.addColorStop(1, '#101319');
    plateCtx.fillStyle = bg;
    plateCtx.beginPath(); plateCtx.arc(cx, cy, 15, 0, 6.2832); plateCtx.fill();
    plateCtx.strokeStyle = 'rgba(160,178,204,0.28)';
    plateCtx.lineWidth = 1;
    plateCtx.beginPath(); plateCtx.arc(cx, cy, 15, 0, 6.2832); plateCtx.stroke();
    plateCtx.strokeStyle = 'rgba(0,0,0,0.45)';
    plateCtx.beginPath(); plateCtx.arc(cx, cy, 19, 0, 6.2832); plateCtx.stroke();

    // the rim: lit on the far side, dark on the near side, so the plate has thickness
    plateCtx.strokeStyle = 'rgba(176,192,218,0.26)';
    plateCtx.lineWidth = 1.5;
    plateCtx.beginPath();
    plateCtx.moveTo(1, PLATE - 2); plateCtx.lineTo(1, 1); plateCtx.lineTo(PLATE - 2, 1);
    plateCtx.stroke();
    plateCtx.strokeStyle = 'rgba(0,0,0,0.65)';
    plateCtx.beginPath();
    plateCtx.moveTo(PLATE - 1, 2); plateCtx.lineTo(PLATE - 1, PLATE - 1); plateCtx.lineTo(2, PLATE - 1);
    plateCtx.stroke();

    baseBytes = new Uint8ClampedArray(plateCtx.getImageData(0, 0, PLATE, PLATE).data);
  }

  // ---------- the field ----------
  var F, GX, GY;

  function buildField(n, m) {
    F = new Float32Array(GRID * GRID);
    GX = new Float32Array(GRID * GRID);
    GY = new Float32Array(GRID * GRID);
    var np = n * Math.PI, mp = m * Math.PI;
    for (var j = 0; j < GRID; j++) {
      var v = j / (GRID - 1);
      var cnv = Math.cos(np * v), cmv = Math.cos(mp * v);
      var snv = Math.sin(np * v), smv = Math.sin(mp * v);
      for (var i = 0; i < GRID; i++) {
        var u = i / (GRID - 1);
        var cu = Math.cos(np * u), cmu = Math.cos(mp * u);
        var su = Math.sin(np * u), smu = Math.sin(mp * u);
        var f = cu * cnv - cmu * cmv;
        var fu = -np * su * cnv + mp * smu * cmv;
        var fv = -mp * cu * smv + np * cmu * snv;
        var k = j * GRID + i;
        F[k] = f < 0 ? -f : f;
        GX[k] = fu;
        GY[k] = fv;
      }
    }
  }

  // ---------- grains ----------
  var gx = new Float32Array(N), gy = new Float32Array(N);
  var gvx = new Float32Array(N), gvy = new Float32Array(N);
  var gw = new Float32Array(N);          // grain weight, so the sand is not uniform
  var grnd = new Float32Array(N);
  var gstate = new Uint8Array(N);        // 0 = resting on the plate, 1 = in the air

  var mode = 0;
  var MODES = [[3, 5], [4, 7], [2, 5], [4, 9], [3, 8], [5, 8], [2, 7], [6, 9]];
  var amp = 0.30;
  var excited = 0;

  function u1(i) { var r = grnd[i]; return (r * 1.6180339887) % 1; }
  function u2(i) { var r = grnd[i]; return (r * 2.4142135623) % 1; }
  function advance(i) { grnd[i] = (grnd[i] + 0.7548776662) % 1; }

  function scatter() {
    for (var i = 0; i < N; i++) {
      gx[i] = rnd() * PLATE;
      gy[i] = rnd() * PLATE;
      gvx[i] = 0; gvy[i] = 0;
      gstate[i] = 0;
      gw[i] = 0.55 + rnd() * 0.9;
      grnd[i] = rnd();
    }
  }

  function throwAll(power) {
    for (var k = 0; k < N; k++) {
      gvx[k] += (rnd() - 0.5) * power;
      gvy[k] += (rnd() - 0.5) * power;
      gstate[k] = 1;
    }
  }

  function setMode(i, ring) {
    mode = ((i % MODES.length) + MODES.length) % MODES.length;
    buildField(MODES[mode][0], MODES[mode][1]);
    if (ring) {
      excited = EXCITE;
      throwAll(9.0);
    }
  }

  function step(dt) {
    var ringing = excited > 0;
    var a = ringing ? 1.0 : 0.30;
    var pRest = ringing ? 0.0022 : 0.00035;
    var restKick = 1.1 + 2.6 * a;

    for (var i = 0; i < N; i++) {
      var xi = gx[i], yi = gy[i];
      var ci = (xi / GSTEP) | 0, cj = (yi / GSTEP) | 0;
      if (ci < 0) ci = 0; else if (ci > GRID - 1) ci = GRID - 1;
      if (cj < 0) cj = 0; else if (cj > GRID - 1) cj = GRID - 1;
      var k = cj * GRID + ci;
      var m = F[k];

      if (gstate[i] === 0) {
        // resting: it only leaves the plate where the plate is moving
        if (m > STICK) {
          var p = pRest * (m + 0.15);
          if (u1(i) < p) {
            var f = restKick * (0.4 + m * 0.9);
            gvx[i] = (u1(i) - 0.5) * f * 2;
            gvy[i] = (u2(i) - 0.5) * f * 2;
            gstate[i] = 1;
          }
        }
        advance(i);
        continue;
      }

      // in the air
      gvx[i] *= 0.870; gvy[i] *= 0.870;
      var vx = gvx[i], vy = gvy[i];
      xi += vx; yi += vy;

      if (xi < 0.5) { xi = 0.5; gvx[i] = -vx * 0.25; }
      else if (xi > PLATE - 1.5) { xi = PLATE - 1.5; gvx[i] = -vx * 0.25; }
      if (yi < 0.5) { yi = 0.5; gvy[i] = -vy * 0.25; }
      else if (yi > PLATE - 1.5) { yi = PLATE - 1.5; gvy[i] = -vy * 0.25; }

      var sp = vx * vx + vy * vy;
      if (sp < 0.13) {
        // it has come to a stop. If the plate is quiet here, it stays.
        if (m < STICK) {
          gstate[i] = 0;
          gvx[i] = 0; gvy[i] = 0;
        } else {
          var f2 = a * (0.9 + m * 3.4);
          gvx[i] = (u1(i) - 0.5) * f2 * 2;
          gvy[i] = (u2(i) - 0.5) * f2 * 2;
        }
      }
      advance(i);
      gx[i] = xi; gy[i] = yi;
    }

    if (ringing) {
      excited -= dt;
      if (excited < 0) excited = 0;
    }
  }

  // ---------- render ----------
  function splat() {
    density.fill(0);
    for (var i = 0; i < N; i++) {
      var x = gx[i], y = gy[i];
      var xi = x | 0, yi = y | 0;
      var fx = x - xi, fy = y - yi;
      if (xi > PLATE - 2) { xi = PLATE - 2; fx = 1; }
      if (yi > PLATE - 2) { yi = PLATE - 2; fy = 1; }
      var w = gw[i];
      var i00 = yi * PLATE + xi;
      var i10 = i00 + 1, i01 = i00 + PLATE, i11 = i01 + 1;
      density[i00] += (1 - fx) * (1 - fy) * w;
      density[i10] += fx * (1 - fy) * w;
      density[i01] += (1 - fx) * fy * w;
      density[i11] += fx * fy * w;
    }
  }

  function blur(src, dst) {
    var x, y, i, row;
    for (y = 0; y < PLATE; y++) {
      row = y * PLATE;
      for (x = 0; x < PLATE; x++) {
        i = row + x;
        var l = x > 0 ? src[i - 1] : src[i];
        var r = x < PLATE - 1 ? src[i + 1] : src[i];
        tmp[i] = (l + src[i] * 2 + r) * 0.25;
      }
    }
    for (y = 0; y < PLATE; y++) {
      row = y * PLATE;
      var up = y > 0 ? (y - 1) * PLATE : row;
      var dn = y < PLATE - 1 ? (y + 1) * PLATE : row;
      for (x = 0; x < PLATE; x++) {
        i = row + x;
        dst[i] = (tmp[up + x] + tmp[i] * 2 + tmp[dn + x]) * 0.25;
      }
    }
  }

  var data = null;
  function draw() {
    ctx.drawImage(voidCanvas, 0, 0);

    // shadow under the plate, so it sits in the room instead of on the page
    ctx.save();
    ctx.shadowColor = 'rgba(0,0,0,0.85)';
    ctx.shadowBlur = 34;
    ctx.shadowOffsetX = 10;
    ctx.shadowOffsetY = 16;
    ctx.fillStyle = '#04050a';
    ctx.fillRect(PX, PY, PLATE, PLATE);
    ctx.restore();

    splat();
    blur(density, glowA);
    blur(glowA, glowB);

    var d = frame.data;
    d.set(baseBytes);

    var gain = 150, ggain = 130;
    for (var i = 0, p = 0; i < density.length; i++, p += 4) {
      var s = density[i] * gain;
      if (s > 0.5) {
        var si = s > RAMP - 1 ? RAMP - 1 : s | 0;
        d[p] += rampR[si]; d[p + 1] += rampG[si]; d[p + 2] += rampB[si];
      }
      var q = glowB[i] * ggain;
      if (q > 1.5) {
        var qi = q > RAMP - 1 ? RAMP - 1 : q | 0;
        d[p] += glowR[qi]; d[p + 1] += glowG[qi]; d[p + 2] += glowBc[qi];
      }
    }
    plateCtx.putImageData(frame, 0, 0);
    ctx.drawImage(plateCanvas, PX, PY);
    if (!still) drawReadout();   // the still is a poster frame, not a readout
  }

  function drawReadout() {
    var n = MODES[mode][0], m = MODES[mode][1];
    var hz = 41.7 * (n * n + m * m);
    ctx.save();
    ctx.font = '13px ui-monospace, Menlo, "DejaVu Sans Mono", monospace';
    ctx.fillStyle = 'rgba(0,245,255,0.60)';
    ctx.fillText('n=' + n + '   m=' + m, 40, H - 34);
    ctx.fillStyle = 'rgba(232,232,255,0.30)';
    ctx.fillText((hz | 0) + ' Hz', 40, H - 16);
    ctx.textAlign = 'right';
    ctx.fillStyle = 'rgba(232,232,255,0.30)';
    ctx.fillText(N.toLocaleString('en-US') + ' grains of sand', W - 40, H - 16);
    ctx.fillStyle = 'rgba(232,232,255,0.20)';
    ctx.fillText('the sand stops where the plate is still', W - 40, H - 34);
    ctx.restore();
  }

  // ---------- loop ----------
  var paused = false, last = 0, acc = 0, modeT = 0;

  function tick(now) {
    var t = now / 1000;
    var dt = last ? Math.min(0.05, t - last) : 0.016;
    last = t;
    if (!paused) {
      acc += dt;
      var fixed = 1 / 60, guard = 0;
      while (acc >= fixed && guard < 4) { step(fixed); acc -= fixed; guard++; }
      if (acc > fixed) acc = 0;
      modeT += dt;
      if (modeT > HOLD) { modeT = 0; setMode(mode + 1, true); }
      amp = excited > 0 ? 0.85 : 0.30;
    }
    draw();
    requestAnimationFrame(tick);
  }

  // ---------- interaction ----------
  canvas.addEventListener('pointerdown', function (e) {
    e.preventDefault();
    excited = EXCITE * 1.2;
    throwAll(10.5);
  });

  window.addEventListener('keydown', function (e) {
    if (e.key === ' ') { paused = !paused; e.preventDefault(); }
    else if (e.key === 's' || e.key === 'S') {
      var a = document.createElement('a');
      a.download = 'where-the-sand-goes.png';
      a.href = canvas.toDataURL('image/png');
      a.click();
    } else if (e.key === 'n' || e.key === 'N') { modeT = 0; setMode(mode + 1, true); }
  });

  // ---------- boot ----------
  buildVoid();
  buildPlate();
  scatter();
  setMode(0, false);

  var mq = /[?&]mode=(\d+)/.exec(location.search);
  if (mq) setMode(parseInt(mq[1], 10), true);

  // the plate is struck once on load, so the first figure draws itself
  excited = EXCITE;
  throwAll(8.0);

  if (still) {
    for (var s = 0; s < 1400; s++) step(1 / 60);
    excited = 0;
    draw();
    canvas.dataset.ready = '1';
    canvas.dataset.grains = String(N);
  } else {
    requestAnimationFrame(tick);
  }
})();
