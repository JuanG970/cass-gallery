/* Dwell — Cass Gallery piece #113
   Plain Canvas 2D. No library.

   A harmonograph: a pen hanging from two pendulums, drawing on a card.
   The pen position is four decaying sinusoids at near-rational frequency
   ratios, so the figure never quite closes — it precesses and slowly fills
   itself in — and the amplitudes die away, so each pass is smaller and
   slower than the last. The machine runs for five minutes of its own time;
   you get to watch it in one.

   The only thing that makes the picture is the ink rule: alpha per segment
   is proportional to how long the pen spent on that segment. The dark
   places in the figure are not drawn dark. They are the places the pen was
   slow — the turning point of every swing, and the whole middle of the card
   once the pendulums have nearly stopped. A camera and a pendulum record the
   same quantity from opposite directions: exposure is time, and so is this. */

(function () {
  'use strict';

  var W = 960, H = 540;
  var canvas = document.getElementById('dwell');
  if (!canvas) return;
  var ctx = canvas.getContext('2d', { alpha: false });

  var params = new URLSearchParams(location.search);
  var STILL = params.get('still') === '1';
  var SEED_OVERRIDE = params.get('seed');

  /* card geometry, in screen space */
  var CW = 690, CH = 440;
  var cardCX = W / 2 - 4, cardCY = H / 2 + 6;
  var ROT = -1.15 * Math.PI / 180;

  /* pen origin inside the card, nudged off centre — a machine levelled by
     hand is never centred */
  var OX = CW / 2 - 9, OY = CH / 2 + 4;

  var INK = '28,24,20';

  /* ============================================================ the maths
     Four pendulums. x is driven by two of them (the lateral swing and its
     octave), y by two more (the third harmonic and its double). Frequencies
     are near-rational, not rational: the detune is what stops the figure
     closing on itself, so instead of one line retraced a hundred times the
     pen lays a slightly different line every pass and the drawing creeps
     into a lace. */
  var DUR = 300.0;                /* seconds of the machine's own time */
  var SIM_RATE = 5.0;             /* machine seconds per wall second */
  var KDECAY = 1 / 105;           /* amplitude e-folding, 1/s */

  function mulberry32(a) {
    return function () {
      a |= 0; a = a + 0x6D2B79F5 | 0;
      var t = Math.imul(a ^ a >>> 15, 1 | a);
      t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t;
      return ((t ^ t >>> 14) >>> 0) / 4294967296;
    };
  }

  function makeFigure(seed) {
    var r = mulberry32(seed * 7919 + 104729);
    var base = 0.42 + 0.06 * r();
    var d = function () { return (r() * 2 - 1) * 0.017; };
    var p = function () { return r() * Math.PI * 2; };
    return {
      base: base,
      f: [base * (1 + d()), base * (2 + d()), base * (1.5 + d()), base * (3 + d())],
      ph: [p(), p(), p(), p()],
      /* amplitude, px. The x pairs swing wider than the y pairs, because the
         card is a landscape and a circular figure on a landscape card reads
         as a coin on a table. */
      A: [152 + 18 * r(), 58 + 12 * r(), 132 + 16 * r(), 50 + 10 * r()],
      k: [KDECAY * (0.95 + 0.10 * r()), KDECAY * (1.0 + 0.08 * r()),
          KDECAY * (0.97 + 0.10 * r()), KDECAY * (1.0 + 0.08 * r())],
      blot: 0.9 + 0.5 * r(),
      tilt: (r() * 2 - 1) * 0.012
    };
  }

  function pos(F, t, out) {
    var x = 0, y = 0, i, e, a;
    for (i = 0; i < 2; i++) {
      e = Math.exp(-F.k[i] * t);
      a = Math.PI * 2 * F.f[i] * t + F.ph[i];
      x += F.A[i] * e * Math.sin(a);
    }
    for (i = 2; i < 4; i++) {
      e = Math.exp(-F.k[i] * t);
      a = Math.PI * 2 * F.f[i] * t + F.ph[i];
      y += F.A[i] * e * Math.sin(a);
    }
    out[0] = OX + x;
    out[1] = OY + y;
  }

  /* ======================================================== the materials */
  var paper = document.createElement('canvas'); paper.width = CW; paper.height = CH;
  var ink = document.createElement('canvas'); ink.width = CW; ink.height = CH;
  var bg = document.createElement('canvas'); bg.width = W; bg.height = H;
  var inkx = ink.getContext('2d');

  function buildPaper() {
    var c = paper.getContext('2d');
    var r = mulberry32(20261120);
    c.fillStyle = '#e6dcc6';
    c.fillRect(0, 0, CW, CH);

    /* mottling: the sheet is not one colour, it is a slow cloud of them */
    var i, x, y, rad, g;
    for (i = 0; i < 620; i++) {
      x = r() * CW; y = r() * CH; rad = 30 + r() * 90;
      g = c.createRadialGradient(x, y, 0, x, y, rad);
      var warm = r() < 0.5;
      g.addColorStop(0, warm ? 'rgba(240,231,209,0.075)' : 'rgba(201,187,158,0.075)');
      g.addColorStop(1, 'rgba(230,220,198,0)');
      c.fillStyle = g;
      c.fillRect(x - rad, y - rad, rad * 2, rad * 2);
    }

    /* fibres: short horizontal flecks, the thing that says pulp and not card */
    c.lineWidth = 1;
    for (i = 0; i < 2400; i++) {
      x = r() * CW; y = r() * CH;
      var len = 2 + r() * 12;
      c.strokeStyle = r() < 0.5 ? 'rgba(255,250,238,0.035)' : 'rgba(150,132,102,0.032)';
      c.beginPath();
      c.moveTo(x, y);
      c.lineTo(x + len, y + (r() - 0.5) * 1.2);
      c.stroke();
    }

    /* the sheet has aged at the edges, and it is lit from the upper left */
    g = c.createRadialGradient(CW * 0.42, CH * 0.34, CH * 0.14, CW * 0.5, CH * 0.5, CH * 0.95);
    g.addColorStop(0, 'rgba(255,250,232,0.22)');
    g.addColorStop(0.60, 'rgba(255,250,232,0)');
    g.addColorStop(1, 'rgba(138,112,74,0.24)');
    c.fillStyle = g;
    c.fillRect(0, 0, CW, CH);

    /* one foxing spot, low left, well clear of the figure */
    g = c.createRadialGradient(CW * 0.10, CH * 0.84, 0, CW * 0.10, CH * 0.84, 34);
    g.addColorStop(0, 'rgba(160,120,70,0.11)');
    g.addColorStop(1, 'rgba(160,120,70,0)');
    c.fillStyle = g;
    c.fillRect(0, 0, CW, CH);

    /* cut edge */
    c.strokeStyle = 'rgba(116,100,74,0.40)';
    c.lineWidth = 1;
    c.strokeRect(0.5, 0.5, CW - 1, CH - 1);
  }

  function roundRect(c, x, y, w, h, rad) {
    c.beginPath();
    c.moveTo(x + rad, y);
    c.lineTo(x + w - rad, y); c.quadraticCurveTo(x + w, y, x + w, y + rad);
    c.lineTo(x + w, y + h - rad); c.quadraticCurveTo(x + w, y + h, x + w - rad, y + h);
    c.lineTo(x + rad, y + h); c.quadraticCurveTo(x, y + h, x, y + h - rad);
    c.lineTo(x, y + rad); c.quadraticCurveTo(x, y, x + rad, y);
    c.closePath();
  }

  function buildBg() {
    var c = bg.getContext('2d');
    var r = mulberry32(778899);
    c.fillStyle = '#0c0a09';
    c.fillRect(0, 0, W, H);

    var g = c.createRadialGradient(300, 90, 40, 430, 200, 980);
    g.addColorStop(0, 'rgba(86,62,42,0.55)');
    g.addColorStop(0.55, 'rgba(44,32,24,0.30)');
    g.addColorStop(1, 'rgba(9,8,7,0)');
    c.fillStyle = g;
    c.fillRect(0, 0, W, H);

    /* table grain: long slow waves, barely there */
    var i, y, x;
    for (i = 0; i < 150; i++) {
      y = r() * H;
      c.beginPath();
      c.moveTo(0, y);
      for (x = 0; x <= W; x += 24) {
        c.lineTo(x, y + Math.sin(x * 0.006 + i) * 6 + Math.sin(x * 0.021 + i * 3) * 1.6);
      }
      c.strokeStyle = r() < 0.5 ? 'rgba(96,72,50,0.045)' : 'rgba(0,0,0,0.11)';
      c.lineWidth = 0.8 + r() * 1.6;
      c.stroke();
    }

    /* shadow cast by the card, light from the upper left */
    c.save();
    c.translate(cardCX, cardCY);
    c.rotate(ROT);
    if ('filter' in c) c.filter = 'blur(22px)';
    c.fillStyle = 'rgba(0,0,0,0.62)';
    roundRect(c, -CW / 2 + 16, -CH / 2 + 22, CW, CH, 3);
    c.fill();
    c.restore();

    c.save();
    c.translate(cardCX, cardCY);
    c.rotate(ROT);
    if ('filter' in c) c.filter = 'blur(5px)';
    c.fillStyle = 'rgba(0,0,0,0.55)';
    roundRect(c, -CW / 2 + 5, -CH / 2 + 8, CW, CH, 2);
    c.fill();
    c.restore();
  }

  /* ============================================================= the pen */
  var fig = null;
  var tSim = 0;
  var prev = [0, 0], cur = [0, 0];
  var penDown = false;
  var vEst = 900;

  var MIN_A = 0.004, K_INK = 260, CAP = 0.34;

  function reset(seed) {
    fig = makeFigure(seed);
    tSim = 0;
    inkx.clearRect(0, 0, CW, CH);
    pos(fig, 0, prev);
    cur[0] = prev[0]; cur[1] = prev[1];
    penDown = false;
    vEst = Math.PI * 2 * fig.base *
      (fig.A[0] * fig.f[0] / fig.base + fig.A[2] * fig.f[2] / fig.base);
  }

  /* one substep: move the pen, lay down ink proportional to dwell time */
  function step(dt) {
    pos(fig, tSim, cur);
    if (penDown) {
      var dx = cur[0] - prev[0], dy = cur[1] - prev[1];
      var len = Math.sqrt(dx * dx + dy * dy);
      if (len > 1e-6) {
        /* alpha = ink per unit length / speed: the pen spends dt on len px */
        var a = MIN_A + K_INK * (dt / len);
        if (a > CAP) a = CAP;
        inkx.strokeStyle = 'rgba(' + INK + ',' + a.toFixed(4) + ')';
        inkx.lineWidth = 1.15;
        inkx.lineCap = 'round';
        inkx.beginPath();
        inkx.moveTo(prev[0], prev[1]);
        inkx.lineTo(cur[0], cur[1]);
        inkx.stroke();
        vEst = 0.92 * vEst + 0.08 * (len / dt);
      }
    } else {
      /* the pen comes down: a blot, because it was lowered and it sat */
      var rr = fig.blot;
      inkx.fillStyle = 'rgba(' + INK + ',0.50)';
      inkx.beginPath();
      inkx.arc(prev[0], prev[1], rr, 0, Math.PI * 2);
      inkx.fill();
      inkx.fillStyle = 'rgba(' + INK + ',0.09)';
      inkx.beginPath();
      inkx.arc(prev[0] + 1.2, prev[1] + 1.0, rr * 2.7, 0, Math.PI * 2);
      inkx.fill();
      penDown = true;
    }
    prev[0] = cur[0]; prev[1] = cur[1];
    tSim += dt;
  }

  /* the pen is driven at a constant segment length rather than a constant
     timestep: a chord of 1.8 px is below the eye's threshold at any speed,
     and the machine moves through twenty times as much card when the
     pendulums are swinging as it does when they are dying. */
  var TARGET_LEN = 1.8;

  function stepAdaptive(budget) {
    var used = 0, guard = 0;
    while (used < budget && tSim < DUR && guard++ < 900) {
      var dt = TARGET_LEN / Math.max(vEst, 40);
      if (dt > budget - used) dt = budget - used;
      if (tSim + dt > DUR) dt = DUR - tSim;
      if (dt <= 0) break;
      step(dt);
      used += dt;
    }
    return used;
  }

  /* ========================================================== the picture */
  var cardAlpha = 1;

  function draw() {
    ctx.drawImage(bg, 0, 0);
    ctx.save();
    ctx.translate(cardCX, cardCY);
    ctx.rotate(ROT);
    ctx.globalAlpha = cardAlpha;
    ctx.drawImage(paper, -CW / 2, -CH / 2);
    ctx.drawImage(ink, -CW / 2, -CH / 2);
    ctx.restore();
    ctx.globalAlpha = 1;
  }

  /* ============================================================== running */
  var HOLD = 7.0, FADE = 1.6;
  var phase = 'draw', phaseT = 0, seed = 0;
  var last = 0;

  function tick(now) {
    if (!last) last = now;
    var dtReal = Math.min(0.05, (now - last) / 1000);
    last = now;

    if (phase === 'draw') {
      stepAdaptive(dtReal * SIM_RATE);
      if (tSim >= DUR) { phase = 'hold'; phaseT = 0; }
    } else if (phase === 'hold') {
      phaseT += dtReal;
      if (phaseT > HOLD) { phase = 'fade'; phaseT = 0; }
    } else {
      phaseT += dtReal;
      cardAlpha = Math.max(0, 1 - phaseT / FADE);
      if (phaseT >= FADE) {
        seed++;
        reset(seed);
        phase = 'draw'; phaseT = 0;
        cardAlpha = 1;
      }
    }

    draw();
    requestAnimationFrame(tick);
  }

  /* ============================================================= the still */
  buildPaper();
  buildBg();

  if (STILL) {
    reset(SEED_OVERRIDE === null ? 2 : parseInt(SEED_OVERRIDE, 10));
    var guard = 0;
    while (tSim < DUR && guard++ < 200000) {
      var dt = TARGET_LEN / Math.max(vEst, 40);
      if (tSim + dt > DUR) dt = DUR - tSim;
      step(dt);
    }
    cardAlpha = 1;
    draw();
    window._dwellReady = true;
  } else {
    reset(2);
    draw();
    requestAnimationFrame(tick);
  }
})();
