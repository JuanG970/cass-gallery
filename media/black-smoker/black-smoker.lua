-- title: Black Smoker
-- author: Juan Gonzalez
-- desc: A hydrothermal vent at depth, where the only light is the animals and the mouth
-- script: lua

local C = {
  void = 0, purple = 1, rust = 2, coral = 3, amber = 4, leaf = 5,
  green = 6, teal = 7, deepBlue = 8, blue = 9, skyBlue = 10,
  cyan = 11, white = 12, silver = 13, slate = 14, shadow = 15
}

-- ---------------------------------------------------------------- primitives
local function hlin(x, y, w, color)
  for i = 0, w - 1 do
    local px = x + i
    if px >= 0 and px < 240 and y >= 0 and y < 136 then pix(px, y, color) end
  end
end

local function rect(x, y, w, h, color)
  for j = 0, h - 1 do hlin(x, y + j, w, color) end
end

-- Ordered dither. At this depth every value is one step away from every other
-- value, so nothing here is a gradient: it is all crosshatch density.
local BAYER = {
   0,  8,  2, 10,
  12,  4, 14,  6,
   3, 11,  1,  9,
  15,  7, 13,  5
}
local function bayer(x, y) return BAYER[(y % 4) * 4 + (x % 4) + 1] end

-- A hash built from modular arithmetic lattices; a real noise tile does not.
math.randomseed(31)
local NOISE = {}
for y = 0, 63 do
  NOISE[y] = {}
  for x = 0, 63 do NOISE[y][x] = math.random(0, 99) end
end
local function hash(x, y) return NOISE[y % 64][x % 64] end

-- ---------------------------------------------------------------- composition
local MX, MY = 96, 60        -- vent mouth centre

local function floorY(x)
  return 120 + math.floor(math.sin(x * 0.045) * 2.4 + math.sin(x * 0.013 + 1.7) * 2.0)
end

-- No sunlight reaches this frame. The water is one flat value; the only
-- variation in it is the faint bounce off the rock at the bottom of the frame.
-- Precomputed once: 32K hash calls per frame is 2M/sec and TIC-80's Lua has
-- better things to do at 60fps. The snow does not move; it only falls.
local SNOW = {}
for y = 0, 135 do
  for x = 0, 239 do
    local h = hash(x, y)
    if h < 1 then SNOW[#SNOW + 1] = { x, y, C.shadow }
    elseif h == 1 and (x + y) % 7 == 0 then SNOW[#SNOW + 1] = { x, y, C.slate } end
  end
end

local function drawWater(t)
  -- A bayer lattice across open water reads as a printed grid. Suspended
  -- particles are hash-scattered, and at this depth they are the only thing
  -- in the water at all: marine snow, falling forever.
  for i = 1, #SNOW do
    pix(SNOW[i][1], SNOW[i][2], SNOW[i][3])
  end
end

local function drawFloor(t)
  for x = 0, 239 do
    local fy = floorY(x)
    hlin(x, fy, 1, C.shadow)
    for y = fy + 1, 135 do pix(x, y, C.shadow) end
    -- mineral speckle on the crust, denser near the vent
    local near = 1.0 - math.min(1.0, math.abs(x - MX) / 90.0)
    for y = fy, math.min(135, fy + 5) do
      if hash(x, y) < 12 + near * 26 then pix(x, y, C.slate) end
    end
  end
  -- chemosynthetic mat: pale bacterial crust, breathing on a long cycle.
  -- It is the second light source in the frame and it is alive.
  for x = 34, 210 do
    local fy = floorY(x)
    local patch = math.max(0, math.sin(x * 0.031 + 0.6)) * (1.0 - math.min(1.0, math.abs(x - MX) / 130.0))
    local dens = patch * (7.0 + 4.5 * math.sin(t * 0.35 + x * 0.06))
    if dens > 0.6 then
      for y = fy - 2, fy + 2 do
        if hash(x, y) < dens then pix(x, y, C.amber) end
      end
    end
  end
end

-- Heat above the mouth: a low ring of amber that never quite resolves into a
-- shape. Density only, no silhouette.
local function drawGlow(t)
  -- A wide low-density halo resolves into a ring of sparks: the eye finds the
  -- circumference where density crosses the dither threshold, not the centre.
  -- Keep it small and let the core be nearly solid, so it reads as heat.
  for y = MY - 6, MY + 5 do
    for x = MX - 11, MX + 11 do
      if x >= 0 and x < 240 and y >= 0 and y < 136 then
        local dx, dy = (x - MX) / 10.5, (y - (MY - 2)) / 5.5
        local rr = dx * dx + dy * dy
        if rr < 1 then
          local d = (1 - rr)
          if bayer(x, y) < d * d * 26 then pix(x, y, C.amber) end
          if d > 0.72 and bayer(x + 2, y + 1) < 9 then pix(x, y, C.coral) end
        end
      end
    end
  end
  -- the mouth itself: white flicker in a black cavity
  local f = math.floor(t * 9) % 3
  pix(MX - 2, MY + 1, C.white)
  pix(MX + 1, MY + 2, C.coral)
  pix(MX, MY + 1, f == 0 and C.white or C.amber)
  pix(MX - 1, MY + 3, C.rust)
end

-- The smoke is mineral, not fire: it leaves the mouth white and cools through
-- coral, silver, slate into the water, so the column is a temperature scale
-- read top to bottom. It widens and drifts right on a current it never had.
local function drawPlume(t)
  for y = 0, MY - 1 do
    local h = (MY - y) / MY
    local half = 4.5 + h * h * 27
    local cx = MX + h * 21
      + math.sin(t * 0.55 + y * 0.10) * 2.2
      + math.sin(t * 0.21 + y * 0.041) * 4.5 * h
    local dens = 96 - h * 80
    local col
    if h < 0.06 then col = C.white
    elseif h < 0.14 then col = C.coral
    elseif h < 0.30 then col = C.silver
    elseif h < 0.54 then col = C.slate
    else col = C.shadow end
    local wob = 0.78 + 0.22 * math.sin(t * 0.7 + y * 0.23)
    for x = math.floor(cx - half), math.floor(cx + half) do
      if x >= 0 and x < 240 then
        local dc = math.abs(x - cx) / half
        local d = dens * (1 - dc * dc * 0.9) * wob
        if bayer(x, y) < d * 0.16 then pix(x, y, col) end
      end
    end
  end
end

-- A chimney is a stack of mineral ledges that grew at different rates, so no
-- two ledges span the same width and none of them start at the same place.
-- The body has to stay within one value of the water, though: the mouth is the
-- only lamp. A evenly grain-lit column reads as grey concrete instead.
local LEDGES = {
  { 71, 0.30, 0.75 }, { 79, 0.10, 0.55 }, { 86, 0.45, 1.00 },
  { 95, 0.15, 0.65 }, { 103, 0.55, 1.10 }, { 112, 0.05, 0.80 },
  { 119, 0.35, 1.20 }, { 125, 0.00, 1.35 },
}

local function chimneyHalf(y)
  local hw = 4.5 + (y - MY) * 0.072
  if y > 118 then hw = hw + (y - 118) * 0.55 end   -- talus pile at the foot
  return hw
end

local function chimneyCx(y)
  return MX + (y - MY) * 0.045
end

local function drawChimney(t)
  for y = MY, 127 do
    local hw, cx = chimneyHalf(y), chimneyCx(y)
    local x0 = math.floor(cx - hw)
    local w = math.floor(2 * hw)
    hlin(x0, y, w, C.shadow)
    -- mineral grain, only where the mouth is still lighting it
    if y < 94 and y % 2 == 0 then
      for x = x0, x0 + w do
        if bayer(x, y) < 1 then pix(x, y, C.slate) end
      end
    end
    -- talus at the foot catches the mat, not the vent
    if y > 120 then
      for x = x0 - 1, x0 + w + 1 do
        if bayer(x, y) < 2 then pix(x, y, C.slate) end
      end
    end
  end

  -- rim light: only the top of the spire, only the flank facing the mouth
  for y = MY, MY + 16 do
    local hw, cx = chimneyHalf(y), chimneyCx(y)
    local d = (1 - (y - MY) / 16.0) * 6
    for x = math.floor(cx - hw) - 1, math.floor(cx + hw) do
      if bayer(x, y) < d then pix(x, y, C.slate) end
    end
  end

  -- ledges: full slate only near the mouth, an edge beyond it
  for i = 1, #LEDGES do
    local y, a, b = LEDGES[i][1], LEDGES[i][2], LEDGES[i][3]
    local hw, cx = chimneyHalf(y), chimneyCx(y)
    local x0 = math.floor(cx - hw)
    local w = math.floor(2 * hw)
    local s0 = x0 + math.floor(w * a)
    local s1 = x0 + math.floor(w * b)
    if y < 88 then
      hlin(s0, y, s1 - s0, C.slate)
    else
      pix(s0, y, C.slate)
      pix(s1, y, C.slate)
      if i % 2 == 0 then hlin(s0, y, s1 - s0, C.slate) end
    end
    pix(s0 - 1, y - 1, C.slate)
    pix(s1 + 1, y, C.silver)
  end

  -- the cavity
  hlin(MX - 3, MY, 6, C.void)
  hlin(MX - 4, MY + 1, 8, C.void)
  hlin(MX - 4, MY + 2, 8, C.void)

  -- an older, dead spire behind and to the right: silhouette only, two flakes
  for y = 106, 127 do
    local hw = (3.0 + (y - 106) * 0.10)
    local cx = 157 + (y - 106) * 0.04
    hlin(math.floor(cx - hw), y, math.floor(2 * hw), C.shadow)
  end
  pix(155, 106, C.slate)
  pix(156, 107, C.slate)
end

-- Riftia: a tube, a red plume. Clumped, never evenly spaced, and the tips of a
-- stand lean on the same current the smoke does.
local WORMS = {
  -- near clump, left of the vent
  { 43, 17, 0.2, 1 }, { 47, 26, 1.6, 1 }, { 50, 12, 3.1, 1 },
  { 54, 22, 0.9, 1 }, { 57, 30, 4.2, 1 }, { 61, 15, 2.4, 1 },
  { 65, 20, 5.0, 1 }, { 69, 11, 1.1, 1 },
  -- near clump, right of the vent
  { 111, 24, 3.6, 1 }, { 115, 14, 0.6, 1 }, { 119, 29, 2.0, 1 },
  { 123, 18, 4.7, 1 }, { 127, 11, 1.4, 1 }, { 131, 26, 3.3, 1 },
  { 136, 16, 5.4, 1 }, { 141, 21, 2.8, 1 }, { 146, 13, 0.4, 1 },
  -- distant clump: shorter, dimmer, no rim light
  { 197, 11, 1.9, 0 }, { 202, 16, 3.8, 0 }, { 207, 9, 0.7, 0 },
  { 212, 14, 2.6, 0 },
}

local function drawWorms(t)
  for i = 1, #WORMS do
    local bx, h, ph, near = WORMS[i][1], WORMS[i][2], WORMS[i][3], WORMS[i][4]
    local by = floorY(bx) + 1
    local tube = near == 1 and C.silver or C.slate
    local shade = near == 1 and C.slate or C.shadow
    local tip = math.sin(t * 0.8 + ph) * (1.2 + h * 0.05)
    for j = 0, h - 1 do
      local f = j / h
      local xo = math.floor(tip * f * f + 0.5)
      local y = by - j
      if y >= 0 and y < 136 then
        pix(bx + xo, y, tube)
        if j % 3 == 0 then pix(bx + xo + 1, y, shade) end
      end
    end
    -- the plume is a tuft, not a bud: three wide at the head, rust below it
    local tx = bx + math.floor(tip + 1.5)
    local ty = by - h
    if ty >= 3 then
      pix(tx, ty, C.coral)
      pix(tx, ty - 1, C.coral)
      pix(tx - 1, ty - 1, C.rust)
      pix(tx + 1, ty - 1, C.rust)
      pix(tx, ty - 2, C.rust)
      if near == 1 then pix(tx, ty - 3, C.rust) end
    end
  end
end

-- A few shrimp riding the plume. Two pixels each; at this size a shrimp is a
-- direction, not an animal.
local SHRIMP = {
  { 132, 96, 0.4, 0.30 }, { 118, 78, 2.2, 0.24 },
  { 146, 66, 1.1, 0.19 }, { 84, 52, 3.4, 0.15 },
}

local function drawShrimp(t)
  for i = 1, #SHRIMP do
    local s = SHRIMP[i]
    local x = math.floor(s[1] + math.sin(t * s[4] + s[3]) * 7)
    local y = math.floor(s[2] - ((t * 7 + s[3] * 9) % 26))
    if y < 40 then y = y + 26 end
    pix(x, y, C.white)
    pix(x - 1, y, C.silver)
    pix(x - 2, y + 1, C.slate)
    pix(x - 1, y + 1, C.slate)
  end
end

-- ---------------------------------------------------------------------- frame
function TIC()
  cls(C.void)
  local t = time() / 60.0
  drawWater(t)
  drawFloor(t)
  drawGlow(t)
  drawPlume(t)
  drawChimney(t)
  drawWorms(t)
  drawShrimp(t)
end
