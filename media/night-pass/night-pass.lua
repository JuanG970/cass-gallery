-- title: Night Pass
-- author: Juan Gonzalez
-- desc: A low-orbit satellite crosses the night side of Earth as dawn clears the limb
-- script: lua

local C = {
  void = 0, purple = 1, rust = 2, coral = 3, amber = 4,
  green = 6, teal = 7, deepBlue = 8, blue = 9, skyBlue = 10,
  cyan = 11, white = 12, silver = 13, slate = 14, shadow = 15
}

local stars = {}
local cityLights = {
  {42, 113}, {45, 113}, {48, 114}, {51, 113}, {54, 115}, {59, 113}, {61, 114},
  {151, 112}, {154, 110}, {158, 112}, {162, 111}, {165, 113}, {168, 112}, {172, 114},
  {188, 115}, {193, 114}, {198, 115}, {204, 114}, {207, 117}, {210, 116}
}

math.randomseed(260926)
for i = 1, 31 do
  stars[i] = {
    x = math.random(3, 237),
    y = math.random(4, 67),
    phase = math.random() * 6.283,
    period = 18 + math.random() * 28,
    bright = math.random() < 0.16
  }
end

local function hline(x, y, w, color)
  local x0 = math.max(0, math.floor(x))
  local x1 = math.min(239, math.floor(x + w - 1))
  if y >= 0 and y <= 135 then
    for px = x0, x1 do pix(px, y, color) end
  end
end

local function rectfill(x, y, w, h, color)
  for py = math.floor(y), math.floor(y + h - 1) do
    hline(x, py, w, color)
  end
end

local function limbY(x)
  local q = (x - 120) / 156
  local v = 1 - q * q
  if v <= 0 then return 174 end
  return 174 - 93 * math.sqrt(v)
end

local function drawStars(t)
  for i, s in ipairs(stars) do
    local pulse = 0.5 + 0.5 * math.sin((t + s.phase) * 6.283 / s.period)
    if pulse > 0.73 then
      pix(s.x, s.y, s.bright and C.white or C.cyan)
      if s.bright and pulse > 0.94 then
        pix(s.x - 1, s.y, C.silver)
        pix(s.x + 1, s.y, C.silver)
      end
    elseif pulse > 0.38 then
      pix(s.x, s.y, C.slate)
    end
  end
end

local function drawEarth(sunx, suny)
  -- The sun is behind the curved limb; only its upper half clears the horizon.
  circ(sunx, suny, 15, C.rust)
  circ(sunx, suny, 11, C.coral)
  circ(sunx, suny, 7, C.amber)
  circ(sunx, suny, 3, C.white)

  -- Fill a broad elliptical slice, shaded from the thin blue limb into night.
  for y = 81, 135 do
    local dy = (y - 174) / 93
    local v = 1 - dy * dy
    if v > 0 then
      local half = 156 * math.sqrt(v)
      local color = y < 105 and C.deepBlue or (y < 121 and C.shadow or C.void)
      hline(120 - half, y, half * 2, color)
    end
  end

  -- Broad, uneven coastlines: shapes, not mountain peaks.
  hline(56, 109, 12, C.teal)
  hline(48, 110, 28, C.teal)
  hline(39, 111, 44, C.teal)
  hline(32, 112, 53, C.teal)
  hline(29, 113, 56, C.teal)
  hline(27, 114, 52, C.teal)
  hline(31, 115, 47, C.teal)
  hline(35, 116, 39, C.teal)
  hline(41, 117, 32, C.teal)
  hline(45, 118, 25, C.teal)
  hline(48, 119, 17, C.teal)
  hline(157, 108, 13, C.teal)
  hline(149, 109, 30, C.teal)
  hline(144, 110, 45, C.teal)
  hline(139, 111, 60, C.teal)
  hline(137, 112, 74, C.teal)
  hline(139, 113, 79, C.teal)
  hline(145, 114, 74, C.teal)
  hline(152, 115, 64, C.teal)
  hline(159, 116, 52, C.teal)
  hline(168, 117, 39, C.teal)
  hline(176, 118, 25, C.teal)

  -- Sparse city clusters: human light, not a second star field.
  for i, p in ipairs(cityLights) do
    local y = p[2]
    if y > limbY(p[1]) + 4 then
      local color = (i % 4 == 0) and C.coral or C.amber
      hline(p[1], y, (i % 3 == 0) and 2 or 1, color)
      if i % 4 == 0 then pix(p[1], y + 1, C.amber) end
    end
  end

  -- Atmospheric rim and the warmer seam where sunrise is catching the edge.
  for x = 0, 239 do
    local y = math.floor(limbY(x))
    pix(x, y - 3, C.deepBlue)
    pix(x, y - 2, C.skyBlue)
    if math.abs(x - sunx) < 16 then pix(x, y - 1, C.amber) end
  end
end

local function drawOrbit(t)
  -- A broken, low-contrast track: just enough geometry to explain the pass.
  for x = 0, 239, 3 do
    local y = math.floor(57 - 20 * math.sin((x / 239) * math.pi))
    pix(x, y, C.shadow)
  end

  -- One complete pass across the frame in about ten seconds.
  local phase = (t * 0.1) % 1
  local sx = -22 + phase * 284
  local sy = 57 - 20 * math.sin(phase * math.pi)

  -- Brief telemetry pips trail the satellite; they fade into the orbital path.
  for i = 1, 5 do
    local px = sx - i * 3
    local py = sy + i * 0.6
    if px >= 0 and px < 240 then
      pix(px, py, i < 3 and C.cyan or C.skyBlue)
    end
  end

  -- Solar wings: blue cells, pale frames, warm bus, gold instrument body.
  rectfill(sx - 21, sy - 4, 10, 8, C.deepBlue)
  rectfill(sx + 11, sy - 4, 10, 8, C.deepBlue)
  rectfill(sx - 19, sy - 3, 2, 6, C.blue)
  rectfill(sx - 15, sy - 3, 2, 6, C.blue)
  rectfill(sx - 11, sy - 3, 2, 6, C.blue)
  rectfill(sx + 13, sy - 3, 2, 6, C.blue)
  rectfill(sx + 17, sy - 3, 2, 6, C.blue)
  rectfill(sx + 21, sy - 3, 1, 6, C.blue)
  line(sx - 11, sy, sx - 4, sy, C.silver)
  line(sx + 4, sy, sx + 11, sy, C.silver)
  rectfill(sx - 4, sy - 5, 9, 10, C.rust)
  rectfill(sx - 2, sy - 4, 5, 8, C.amber)
  pix(sx, sy - 2, C.white)

  -- A dish and its receiving horn make the little object read as a machine.
  line(sx + 1, sy - 5, sx + 6, sy - 10, C.silver)
  line(sx + 6, sy - 10, sx + 11, sy - 9, C.silver)
  pix(sx + 11, sy - 9, C.cyan)
  line(sx - 1, sy + 5, sx - 5, sy + 9, C.slate)
  pix(sx - 5, sy + 9, C.coral)
end

function TIC()
  local t = time() / 60.0
  cls(C.void)

  -- Unbroken deep-space field; only the orbital path cuts across it.
  drawStars(t)

  local sunx = 163
  local suny = limbY(sunx) + 2
  drawEarth(sunx, suny)
  drawOrbit(t)
end
