-- title:  Squall Line
-- author: Cass
-- desc:   a rain front crossing a field of grass, and the gust that gets there first
-- script: lua

-- DB16 slots, named after what they actually render as
local C = {
  ink=0, dPurple=1, red=2, salmon=3, amber=4, lime=5, green=6, teal=7,
  dBlue=8, blue=9, ltBlue=10, cyan=11, white=12, ltGray=13, slate=14, dSlate=15,
}

local W, H   = 240, 136
local LOOP   = 5.0
local PERIOD = 300

local B4 = {{0,8,2,10},{12,4,14,6},{3,11,1,9},{15,7,13,5}}
local function dith(x, y, d, c)
  if d <= 0 then return end
  local xi, yi = math.floor(x), math.floor(y)
  if B4[yi % 4 + 1][xi % 4 + 1] < d then pix(xi, yi, c) end
end
local function vline(x, y, h, c)
  for j = 0, h - 1 do pix(x, y + j, c) end
end
local function hash(a, b)
  local n = (a * 374761393 + b * 668265263) % 2147483647
  n = (n * 1274126177) % 2147483647
  return n % 1024
end

local ticks = 0
local fx = 0

-- 0..1 rain intensity, measured back from the front's leading edge
local function rain_u(x, y)
  local edge = fx - (60 - y) * 0.30
  local w = (edge - x) % W
  if w < 0 then w = w + W end
  if w < 3 then return w / 3 end
  if w < 78 then return 1 end
  if w < 126 then return 1 - (w - 78) / 48 end
  return 0
end

-- the outflow gust: a band that runs ahead of the rain
local function wind_at(x, delay)
  local s = ((x - (fx - (delay or 0)) + 120) % W) - 120
  local d = s - 16
  local span = 54
  if d < 0 then span = 112 end
  local a = math.abs(d)
  if a > span then return 0.16 end
  local c = math.cos(a / span * 1.5707963)
  return 0.16 + 0.84 * c * c
end

-- four depths of grass. Each layer is a mass with blades breaking its own top
-- edge, so the picture has no horizon to get wrong.
local LAYERS = {
  { base = 46,  n = 78, h0 =  6, h1 = 17, col = C.ltGray, bend = 4,  delay = 26 },
  { base = 68,  n = 84, h0 = 10, h1 = 27, col = C.slate,  bend = 7,  delay = 16 },
  { base = 96,  n = 76, h0 = 16, h1 = 40, col = C.dSlate, bend = 11, delay = 7  },
}
local BLADES = {}
for L = 1, #LAYERS do
  local lay = LAYERS[L]
  BLADES[L] = {}
  for i = 1, lay.n do
    BLADES[L][i] = {
      x = (hash(L * 977 + i, 131) % (W + 30)) - 15,
      base = lay.base + (hash(L * 977 + i, 132) % 5) - 2,
      len = lay.h0 + hash(L * 977 + i, 133) % (lay.h1 - lay.h0 + 1),
      ph = hash(L * 977 + i, 134) % 7,
    }
  end
end

-- the closest grass: taller, sparser, and the only blades with lit tips
local NEAR = {}
for i = 1, 54 do
  NEAR[i] = {
    x = (hash(i, 231) % (W + 60)) - 30,
    base = H - 1 - (hash(i, 232) % 4),
    len = 30 + hash(i, 233) % 34,
    tip = hash(i, 234) % 3 == 0,
    ph = hash(i, 235) % 7,
  }
end

function TIC()
  ticks = ticks + 1
  cls(C.dSlate)

  local ph = (ticks % PERIOD) / PERIOD
  fx = ph * W
  local rain_off = ph * 210
  local tsec = ph * LOOP

  -------------------------------------------------------------------- the sky
  -- rows 0..7 stay flat: that band is the capture anchor
  rect(0, 8, W, 16, C.dSlate)
  for y = 24, 27 do
    local th = (y - 23) * 5
    for x = 0, W - 1 do
      if B4[y % 4 + 1][x % 4 + 1] < th then pix(x, y, C.slate) else pix(x, y, C.dSlate) end
    end
  end
  rect(0, 28, W, 10, C.slate)
  for y = 38, 41 do
    local th = (y - 37) * 5
    for x = 0, W - 1 do
      if B4[y % 4 + 1][x % 4 + 1] < th then pix(x, y, C.ltGray) else pix(x, y, C.slate) end
    end
  end
  rect(0, 42, W, 8, C.ltGray)

  -------------------------------------------------------------- the rain wall
  -- it darkens the pale air it crosses; against the dark upper sky only its
  -- own streaks give it away
  for x = 0, W - 1 do
    local u = rain_u(x, 34)
    if u > 0.04 then
      local th = math.floor(u * 20)
      for y = 8, 52 do
        local c = (y < 28) and C.dSlate or C.slate
        if B4[y % 4 + 1][x % 4 + 1] < th then pix(x, y, c) end
      end
    end
  end

  ------------------------------------------------------------ rain streaks
  for bx = 0, W - 1 do
    local u = rain_u(bx, 30)
    if hash(bx, 19) % 100 < u * 78 then
      local c = C.ltGray
      if u > 0.92 and hash(bx, 21) % 9 == 0 then c = C.white end
      -- further forward the rain dims against the dark grass
      if hash(bx, 27) % 3 == 0 then c = C.slate end
      local step = 19 + hash(bx, 24) % 8
      local y = (hash(bx, 18) % step) - step - ((rain_off * 1.6) % step)
      while y < 112 do
        local yy = math.floor(y)
        if yy >= 8 then
          for j = 0, 5 + hash(bx, 26) % 4 do
            local y2 = yy + j
            local x2 = bx + math.floor(j * 0.45)
            if y2 < 112 and x2 < W then pix(x2, y2, c) end
          end
        end
        y = y + step
      end
    end
  end

  ------------------------------------------------------------------ the grass
  for L = 1, #LAYERS do
    local lay = LAYERS[L]
    local B = BLADES[L]
    -- the body of this depth: a ragged-topped mass, not a ruled line
    for x = 0, W - 1 do
      local top = lay.base + (hash(x, L * 71) % 11) - 5
      top = top + math.floor(3 * math.sin(x * 0.07 + L))
      vline(x, top, H - top, lay.col)
    end
    -- and the blades that break its top edge
    for i = 1, #B do
      local b = B[i]
      local wnd = wind_at(b.x, lay.delay)
      local sway = 0.85 + 0.15 * math.sin(tsec * 6.2832 * 2 + b.ph)
      local bend = (wnd * lay.bend + 1) * sway
      for j = 1, b.len do
        local pp = j / b.len
        local dx = math.floor(bend * pp * pp + 0.5)
        local y = b.base - j
        if y >= 0 then pix(b.x + dx, y, lay.col) end
      end
    end
  end

  -- a lit edge where the light gets under the front's edge, behind the grass
  for x = 0, W - 1 do
    if rain_u(x, 44) < 0.4 then
      pix(x, 44, C.ltGray)
      dith(x, 45, 8, C.ltGray)
    end
  end

  --------------------------------------------------------------- the closest grass
  for i = 1, #NEAR do
    local g = NEAR[i]
    local wnd = wind_at(g.x, 0)
    local sway = 0.85 + 0.15 * math.sin(tsec * 6.2832 * 2 + g.ph)
    local bend = (wnd * 15 + 2) * sway
    for j = 0, g.len - 1 do
      local pp = j / g.len
      local dx = math.floor(bend * pp * pp + 0.5)
      local y = g.base - j
      if y >= 0 and y < H then
        local c = C.ink
        if g.tip and j > g.len - 5 then c = C.green end
        pix(g.x + dx, y, c)
      end
    end
  end
end
