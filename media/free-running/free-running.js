// Free Running — an oscilloscope with the trigger switched off.
// p5.js (global mode). 960x540. Phosphor-green CRT, two channels, no lock.
//
// The mechanic: the sweep retraces at a fixed 0.55s whether or not the signal
// has finished a cycle, so every sweep begins at a different phase and the
// waveform slides sideways. The persistence layer keeps the last several
// sweeps alive. Click the screen to press the trigger — the figure stands
// still for 1.6s, then slips out of lock again.
//
// Glass effects (vignette, scanlines, glare) live in CSS on the wrapper.
// They must NOT be painted per-frame onto the persistence buffer: an overlay
// re-composited every frame compounds against the fading trace and eats it.

const W = 960, H = 540;
const PX = 56, PTOP = 44, PBOT = 58;
const X0 = PX, X1 = W - PX, Y0 = PTOP, Y1 = H - PBOT;
const COLS = 10, ROWS = 6;
const CX = (X0 + X1) / 2, CY = (Y0 + Y1) / 2;
const HALF_H = (Y1 - Y0) / 2;

const SWEEP = 0.55;   // seconds per left-to-right sweep
// Cycles per sweep. Both are tuned just under a whole number, so each new
// sweep starts almost where the last one did: the ghosts sit a few tens of
// pixels apart instead of smearing into noise. CH1 sits under 2 and creeps
// right; CH2 sits under 1 and creeps left. The two channels separate slowly.
const CY1   = 1.94;   // ghosts shift +0.06 cycle/sweep (to the right)
const CY2   = 0.94;   // ghosts shift -0.06 cycle/sweep (to the left)
const AMP1  = 0.62, AMP2 = 0.40;

const C_BG    = [4, 14, 10];
const C_GRID  = [90, 255, 170];
const C_CH1   = [120, 255, 170];
const C_HOT   = [150, 255, 184];
const C_CH2   = [255, 179, 71];
const C_TEXT  = [160, 255, 205];

let lockUntil = -1;
let lastP = 0;
let lastSweep = -1;
let beamLayer;          // cleared every frame: the beam head must not persist
let clock0 = 0;
let frozenAt = 0;
let paused = false;

function setup() {
  const c = createCanvas(W, H);
  c.parent('scope');
  pixelDensity(1);
  frameRate(60);
  textFont('monospace');
  beamLayer = createGraphics(W, H);
  beamLayer.pixelDensity(1);
  beamLayer.noStroke();
  lastP = 0;
}

function now() {
  return paused ? frozenAt : (millis() - clock0) / 1000;
}

// ---- signals -------------------------------------------------------------

function y1(u, phase) {
  const a = u * TWO_PI * CY1 + phase;
  return CY + AMP1 * HALF_H * (
    0.82 * Math.sin(a) +
    0.14 * Math.sin(2 * a + 1.1) +
    0.05 * Math.sin(3 * a + 2.4)
  );
}

function y2(u, phase) {
  const a = u * TWO_PI * CY2 + phase;
  return CY + AMP2 * HALF_H * (
    0.94 * Math.sin(a + 0.9) +
    0.06 * Math.sin(2 * a + 0.2)
  );
}

// ---- drawing -------------------------------------------------------------

function draw() {
  const t = now();
  const locked = t * 1000 < lockUntil;

  // persistence: wipe a little of the frame each tick. Tuned so the sweep in
  // progress stays legible end to end while roughly three previous sweeps
  // survive as ghosts. Faster wipe than this and only the beam head is bright.
  noStroke();
  fill(C_BG[0], C_BG[1], C_BG[2], 8);
  rect(0, 0, W, H);

  drawGraticule();

  if (locked) {
    // Trigger engaged: the phase is pinned, so every sweep retraces the
    // exact same curve and the ghosts collapse onto one line.
    drawTrace(y2, 0, 0, 1, C_CH2, C_CH2, 40, 215, 5.2, 1.7);
    drawTrace(y1, 0, 0, 1, C_CH1, C_HOT, 50, 245, 6.6, 1.9);
  } else {
    // Phase is CONSTANT for the duration of a sweep and jumps at retrace.
    // That is what makes each sweep a coherent curve instead of a string of
    // mismatched chunks, and it is exactly what an untriggered scope does.
    const k = Math.floor(t / SWEEP);
    const p = t / SWEEP - k;
    if (k !== lastSweep) { lastSweep = k; lastP = 0; }   // retrace: blank
    const a = lastP;
    if (p > a) {
      const ph1 = TWO_PI * CY1 * k;
      const ph2 = TWO_PI * CY2 * k;
      drawTrace(y2, ph2, a, p, C_CH2, C_CH2, 34, 200, 5.0, 1.7);
      drawTrace(y1, ph1, a, p, C_CH1, C_HOT, 46, 225, 6.4, 1.8);
    }
    lastP = p;
    drawBeam(p, y1(p, TWO_PI * CY1 * k));
  }

  drawReadout(t, locked);
}

function drawTrace(fn, phase, ua, ub, col, hot, aBloom, aCore, wBloom, wCore) {
  const n = Math.max(2, Math.ceil((ub - ua) * 320));
  const span = X1 - X0;
  noFill();

  stroke(col[0], col[1], col[2], aBloom);
  strokeWeight(wBloom);
  beginShape();
  for (let i = 0; i <= n; i++) {
    const u = ua + (ub - ua) * i / n;
    vertex(X0 + u * span, fn(u, phase));
  }
  endShape();

  stroke(hot[0], hot[1], hot[2], aCore);
  strokeWeight(wCore);
  beginShape();
  for (let i = 0; i <= n; i++) {
    const u = ua + (ub - ua) * i / n;
    vertex(X0 + u * span, fn(u, phase));
  }
  endShape();
}

function drawBeam(p, y) {
  const x = X0 + p * (X1 - X0);
  beamLayer.clear();
  beamLayer.noStroke();
  beamLayer.fill(C_HOT[0], C_HOT[1], C_HOT[2], 235);
  beamLayer.ellipse(x, y, 3.0, 3.0);
  image(beamLayer, 0, 0);
}

function drawGraticule() {
  const dw = (X1 - X0) / COLS;
  const dh = (Y1 - Y0) / ROWS;

  strokeWeight(1);
  stroke(C_GRID[0], C_GRID[1], C_GRID[2], 21);
  for (let i = 0; i <= COLS; i++) line(X0 + i * dw, Y0, X0 + i * dw, Y1);
  for (let j = 0; j <= ROWS; j++) line(X0, Y0 + j * dh, X1, Y0 + j * dh);

  stroke(C_GRID[0], C_GRID[1], C_GRID[2], 38);
  line(CX, Y0, CX, Y1);
  line(X0, CY, X1, CY);

  // minor ticks along the centre axes
  stroke(C_GRID[0], C_GRID[1], C_GRID[2], 30);
  for (let i = 0; i <= COLS * 5; i++) {
    const x = X0 + (i * (X1 - X0)) / (COLS * 5);
    const big = i % 5 === 0;
    line(x, CY - (big ? 6 : 3), x, CY + (big ? 6 : 3));
  }
  for (let j = 0; j <= ROWS * 5; j++) {
    const y = Y0 + (j * (Y1 - Y0)) / (ROWS * 5);
    const big = j % 5 === 0;
    line(CX - (big ? 6 : 3), y, CX + (big ? 6 : 3), y);
  }

  stroke(C_GRID[0], C_GRID[1], C_GRID[2], 55);
  noFill();
  rect(X0, Y0, X1 - X0, Y1 - Y0);
}

function drawReadout(t, locked) {
  const yTop = H - 30, yBot = H - 11;

  noStroke();
  textAlign(LEFT, CENTER);
  textSize(14);
  fill(C_CH1[0], C_CH1[1], C_CH1[2], 235);
  text('CH1 2.00V', X0, yTop);
  fill(C_CH2[0], C_CH2[1], C_CH2[2], 215);
  text('CH2 0.50V', X0 + 104, yTop);

  fill(C_TEXT[0], C_TEXT[1], C_TEXT[2], 190);
  text('2ms/div', CX - 32, yTop);

  textSize(11);
  fill(C_TEXT[0], C_TEXT[1], C_TEXT[2], 120);
  text('SWP ' + String(Math.floor(t / SWEEP)).padStart(6, '0'), X0, yBot);
  text(locked ? 'TRIG HOLD' : '1.82 Hz  FREE-RUN', CX - 62, yBot);

  textAlign(RIGHT, CENTER);
  textSize(14);
  if (locked) {
    fill(C_HOT[0], C_HOT[1], C_HOT[2], 255);
    text('TRIG: AUTO', X1, yTop);
    textSize(11);
    fill(C_CH1[0], C_CH1[1], C_CH1[2], 165);
    text('LOCKED', X1, yBot);
  } else {
    fill(C_CH2[0], C_CH2[1], C_CH2[2], 225);
    text('TRIG: FREE', X1, yTop);
    textSize(11);
    fill(C_CH2[0], C_CH2[1], C_CH2[2], 140);
    text('UNLOCKED', X1, yBot);
  }
}

// ---- controls ------------------------------------------------------------

function mousePressed() {
  if (mouseX < 0 || mouseX > W || mouseY < 0 || mouseY > H) return;
  lockUntil = now() * 1000 + 1600;
}

function keyPressed() {
  if (key === 's' || key === 'S') saveCanvas('free-running', 'png');
  if (key === ' ') {
    // Stop the draw loop, not just the clock: the persistence wipe runs inside
    // draw(), so freezing time alone keeps eating the phosphor until the
    // screen is blank.
    if (paused) {
      clock0 = millis() - frozenAt * 1000;
      paused = false;
      loop();
    } else {
      frozenAt = now();
      paused = true;
      noLoop();
    }
  }
}
