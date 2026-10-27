-- title: Kelp at Ten Meters
-- author: Juan Gonzalez
-- desc: A kelp forest breathing in green water while a school of amber fish crosses
-- script: lua

local C = {
  void = 0, purple = 1, rust = 2, coral = 3, amber = 4, leaf = 5,
  green = 6, teal = 7, deepBlue = 8, blue = 9, skyBlue = 10,
  cyan = 11, white = 12, silver = 13, slate = 14, shadow = 15
}

-- A real 64x64 noise tile. A hash function built from modular arithmetic shows
-- visible diagonal lattices when you dither with it, which is what made the
-- first pass look like dotted ladders instead of light.
math.randomseed(7)
local NOISE = {}
for y = 0, 63 do
  NOISE[y] = {}
  for x = 0, 63 do NOISE[y][x] = math.random(0, 99) end
end

local function hash(x, y)
  return NOISE[y % 64][x % 64]
end

-- Ordered 4x4 dither for the depth gradient. Random speckle across a band seam
-- reads as television static; a Bayer crosshatch reads as a gradient, which is
-- what the water column actually is.
local BAYER = {
   0,  8,  2, 10,
  12,  4, 14,  6,
   3, 11,  1,  9,
  15,  7, 13,  5
}

local function bayer(x, y)
  return BAYER[(y % 4) * 4 + (x % 4) + 1]
end

-- ---------------------------------------------------------------- water body
-- Anchors are (row, colour). Each band dissolves into the next over its last
-- eight rows so the column reads as depth instead of as painted stripes.
-- Fourth field is how many rows the band spends dissolving into the next one,
-- fifth is the peak density of that dissolve. Long+weak for the surface, short
-- for the middle boundaries: heavy speckle over eight rows reads as TV static.
local ANCH = {
  { 0,   C.cyan,     12, 30 }, { 14,  C.skyBlue,   7, 52 },
  { 38,  C.blue,      9, 46 }, { 64,  C.deepBlue, 11, 40 },
  { 100, C.deepBlue, 10, 42 }, { 136, C.void,      0, 0  }
}

local bgRow = {}
local bgMix = {}
for i = 1, #ANCH - 1 do
  local y0, y1 = ANCH[i][1], ANCH[i + 1][1]
  local ca, cb = ANCH[i][2], ANCH[i + 1][2]
  local mixlen, maxd = ANCH[i][3], ANCH[i][4]
  for y = y0, y1 - 1 do bgRow[y] = ca end
  if ca ~= cb and mixlen > 0 then
    local solidTo = y1 - mixlen
    for y = solidTo, y1 - 1 do
      local d = (y - solidTo + 1) / mixlen
      for x = 0, 239 do
        if bayer(x, y) < d * maxd * 0.16 then bgMix[#bgMix + 1] = { x, y, cb } end
      end
    end
  end
end

local function drawWater()
  for y = 0, 135 do rect(0, y, 240, 1, bgRow[y]) end
  for i = 1, #bgMix do
    local p = bgMix[i]
    pix(p[1], p[2], p[3])
  end
end

-- ------------------------------------------------------------------ surface
-- Seen from below. A bright ceiling with a slow swell in its lower edge; this
-- is the cheapest way to say "you are underwater" without a single label.
-- A bright ceiling with a few glints riding on it. An explicit wavy line here
-- reads as a waterline seen from the side, i.e. a cross-section, which is the
-- wrong camera. The dissolve in the water table does the fading instead.
local function drawSurface(t)
  for x = 0, 239 do
    pix(x, 0, C.white)
    pix(x, 1, C.cyan)
    for y = 2, 4 do pix(x, y, C.cyan) end
    local shimmer = math.sin(x * 0.09 + t * 1.1) * 0.5 + 0.5
    if shimmer > 0.72 and hash(x, 33) < 55 then pix(x, 1, C.white) end
  end
end

-- -------------------------------------------------------------- light shafts
-- Widening cones with a density falloff toward both edges, so they have soft
-- sides. Colour steps down with depth: white at the surface, blue by the kelp.
-- Three wedges, not four columns. A beam narrower than about ten pixels at the
-- surface cannot render as light: at any workable density it collapses into a
-- single beaded vertical line. Width is what makes a shaft read.
local SHAFTS = {
  { topx = 30,  w0 = 13, slant = 0.20, speed = 0.19, phase = 0.0 },
  { topx = 102, w0 = 17, slant = 0.13, speed = 0.15, phase = 2.4 },
  { topx = 164, w0 = 11, slant = 0.26, speed = 0.22, phase = 4.3 },
  { topx = 214, w0 = 15, slant = 0.17, speed = 0.12, phase = 1.1 },
}

-- Three failed approaches live in the history of this function, and the third
-- one is the one that works. Scattered random dots at low density read as
-- static; a solid wedge reads as an opaque slab painted over the water. What
-- reads as light is 50-60% ordered dither in a colour exactly one step lighter
-- than the rows it sits on, tapering to nothing at both edges and with depth.
local function drawShafts(t)
  for i = 1, #SHAFTS do
    local s = SHAFTS[i]
    for y = 4, 108 do
      local dens = 62 * (1.0 - (y - 4) / 104.0) - 8
      if dens > 3 then
        local cx = s.topx + y * s.slant + math.sin(t * s.speed + s.phase + y * 0.013) * 5.0
        local half = (s.w0 + y * 0.30) * 0.5
        local col
        if y < 14 then col = C.white
        elseif y < 38 then col = C.cyan
        elseif y < 66 then col = C.skyBlue
        else col = C.blue end
        local x0, x1 = math.floor(cx - half), math.floor(cx + half)
        for x = x0, x1 do
          local dc = math.abs(x - cx) / half
          if bayer(x, y) < dens * (1 - dc * dc) * 0.16 then pix(x, y, col) end
        end
      end
    end
  end
end

-- ------------------------------------------------------------- seabed + rocks
local ROCKS = {
  { x = 24,  y = 134, r = 9 },
  { x = 96,  y = 136, r = 7 },
  { x = 166, y = 133, r = 10 },
  { x = 224, y = 136, r = 6 },
}

local function drawRocks()
  for i = 1, #ROCKS do
    local r = ROCKS[i]
    circ(r.x, r.y, r.r, C.shadow)
    circ(r.x, r.y - 1, r.r - 2, C.slate)
    pix(r.x - 3, r.y - r.r + 3, C.white)
    pix(r.x - 2, r.y - r.r + 3, C.white)
  end
end

local function drawCaustics(t)
  local sx = {}
  for x = 0, 239 do sx[x] = math.sin((x + t * 16) * 0.082) end
  for y = 118, 135 do
    local cy = math.cos((y - 118) * 0.5 + t * 0.9)
    if cy > 0.15 then
      for x = 0, 239 do
        if sx[x] * cy > 0.55 then pix(x, y, C.green) end
      end
    end
  end
end

-- ---------------------------------------------------------------------- kelp
-- Clumped, not evenly spaced. An even rhythm of nine verticals reads as
-- wallpaper; kelp grows in stands with gaps between them.
local KELP = {
  { x = 10,  front = false, h = 74,  amp = 6,  phase = 1.2 },
  { x = 38,  front = true,  h = 118, amp = 15, phase = 0.4 },
  { x = 47,  front = false, h = 96,  amp = 7,  phase = 3.9 },
  { x = 84,  front = true,  h = 106, amp = 12, phase = 2.6 },
  { x = 118, front = false, h = 68,  amp = 5,  phase = 5.1 },
  { x = 126, front = true,  h = 124, amp = 16, phase = 1.1 },
  { x = 170, front = true,  h = 98,  amp = 13, phase = 4.4 },
  { x = 178, front = false, h = 82,  amp = 6,  phase = 0.7 },
  { x = 210, front = true,  h = 112, amp = 14, phase = 3.2 },
  { x = 219, front = false, h = 62,  amp = 5,  phase = 2.0 },
}

for i = 1, #KELP do
  KELP[i].speed = 0.46 + (i % 4) * 0.11
  KELP[i].lean = ((i % 3) - 1) * 0.12
end

-- Mid-ground. Short, dim, numerous: a kelp forest is a thicket, and six tall
-- stalks in open water read as vines on a wall no matter how good the sway is.
local MID = {}
for i = 1, 11 do
  MID[i] = {
    x = 6 + i * 21 + math.random(-8, 8),
    h = math.random(34, 62),
    amp = 4 + math.random() * 4,
    phase = math.random() * 6.283,
    speed = 0.40 + math.random() * 0.35,
    lean = (math.random() - 0.5) * 0.18,
    front = false,
    mid = true,
  }
end

-- Two frequencies along the stalk so it bends in an S instead of leaning like
-- a stick, and the sway is squared against height so the holdfast stays put.
local function drawStalk(s, t)
  local coreC = s.front and C.green or C.teal
  local hiC   = s.front and C.leaf  or C.green
  local shC   = s.front and C.teal  or C.deepBlue
  local w     = s.front and 4 or 2
  if s.mid then coreC = C.deepBlue; hiC = C.teal; shC = C.deepBlue; w = 1 end

  for k = 0, s.h - 1 do
    local y = 136 - k
    local f = k / s.h
    local bend =
      math.sin(t * s.speed + s.phase + k * 0.105) * 0.75 +
      math.sin(t * s.speed * 0.63 + s.phase * 1.7 + k * 0.058) * 0.45
    local x = math.floor(s.x + s.amp * f * f * bend + s.lean * k)

    for i = 0, w - 1 do pix(x + i, y, coreC) end
    if k % 2 == 0 then pix(x - 1, y, hiC) end
    if k % 3 == 0 then pix(x + w, y, shC) end

    -- Blades: long enough to curve, drooping as they lengthen.
    if k > 14 and k % 12 == 0 then
      local side = (((k / 12) % 2) < 1) and 1 or -1
      local bl = 7 + (k % 5)
      for j = 1, bl do
        local bx = x + (w - 1) + side * j
        local by = y + math.floor((j * j) / (bl * 1.35))
        pix(bx, by, coreC)
        pix(bx, by + 1, coreC)
        if j >= bl - 2 then pix(bx, by + 2, hiC) end
      end
    end

    -- Gas bladders. This is the shape that says kelp rather than grass.
    if s.front and k > 20 and k % 15 == 0 then
      pix(x,     y - 1, hiC)
      pix(x + 1, y - 1, hiC)
      pix(x,     y - 2, hiC)
      pix(x + 1, y - 2, hiC)
      pix(x,     y - 3, hiC)
    end
  end
end

-- ---------------------------------------------------------------------- fish
local FISH = {}
for i = 1, 12 do
  FISH[i] = {
    dx  = math.random(-19, 19),
    dy  = math.random(-8, 8),
    ph  = math.random() * 6.283,
    big = math.random() < 0.35,
  }
end

local schoolX = -46
local schoolY = 58

local function updateSchool(t)
  schoolX = schoolX + 0.62
  if schoolX > 288 then
    schoolX = -46
    schoolY = 42 + math.random(0, 32)
  end
  for i = 1, #FISH do
    local f = FISH[i]
    local fx = schoolX + f.dx + math.sin(t * 1.1 + f.ph) * 3.5
    local fy = schoolY + f.dy + math.sin(t * 1.7 + f.ph * 1.9) * 2.6
    local x, y = math.floor(fx), math.floor(fy)
    local len = f.big and 4 or 3
    for j = 0, len - 1 do
      pix(x + j, y, (j == 0) and C.amber or C.coral)
    end
    pix(x + 1, y - 1, C.amber)
    pix(x - 1, y, C.coral)
    pix(x - 1, y - 1, C.rust)
    pix(x - 1, y + 1, C.rust)
  end
end

-- ------------------------------------------------------------------- bubbles
local BUBBLES = {}
for i = 1, 9 do
  BUBBLES[i] = {
    x   = math.random(8, 232),
    y   = math.random(0, 135),
    sp  = 0.20 + math.random() * 0.34,
    ph  = math.random() * 6.283,
    big = math.random() < 0.3,
  }
end

local function drawBubbles(t)
  for i = 1, #BUBBLES do
    local b = BUBBLES[i]
    b.y = b.y - b.sp
    if b.y < -2 then
      b.y = 138
      b.x = math.random(8, 232)
    end
    local x = math.floor(b.x + math.sin(t * 1.3 + b.ph) * 2.2)
    local y = math.floor(b.y)
    if b.big then
      pix(x, y, C.white)
      pix(x + 1, y, C.white)
      pix(x, y + 1, C.cyan)
    else
      pix(x, y, C.white)
    end
  end
end

-- ---------------------------------------------------------------------- frame
function TIC()
  local t = time() / 60.0
  cls(C.void)

  drawWater()
  drawSurface(t)
  drawShafts(t)
  drawCaustics(t)
  drawRocks()

  for i = 1, #MID do drawStalk(MID[i], t) end

  for i = 1, #KELP do
    if not KELP[i].front then drawStalk(KELP[i], t) end
  end

  updateSchool(t)

  for i = 1, #KELP do
    if KELP[i].front then drawStalk(KELP[i], t) end
  end

  drawBubbles(t)
end
