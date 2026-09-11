-- title:  Kite at Sunset
-- author: Cass
-- desc:   A diamond kite with a long ribbon tail swaying against a warm sunset sky
-- script: lua

-- TIC-80 default palette (verified from rendered output):
-- 0: #1a1c2c dark navy     1: #5d275d dark magenta  2: #b13e53 red
-- 3: #ef7d57 orange        4: #ffcd75 amber/gold   5: #a7f070 green
-- 6: #38b764 dark green     7: #257179 teal        8: #29366f dark blue
-- 9: #3b5dc9 blue          10: #41a6f6 light blue  11: #73eff7 cyan
-- 12: #f4f4f4 white        13: #94b0c2 light steel 14: #566c86 steel
-- 15: #333c57 dark steel

local C = {
  navy     = 0,   -- dark navy (deep sky top, kite silhouette)
  dMagenta = 1,   -- dark magenta
  red      = 2,   -- red (sunset band)
  orange   = 3,   -- orange (sunset band)
  amber    = 4,   -- amber/gold (horizon glow)
  green    = 5,
  dGreen   = 6,
  teal     = 7,
  dBlue    = 8,   -- dark blue (sky band)
  blue     = 9,   -- blue (sky band)
  lBlue    = 10,  -- light blue (sky band)
  cyan     = 11,  -- cyan (sky band)
  white    = 12,  -- white (bright stars)
  lSteel   = 13,  -- light steel (dim stars)
  steel    = 14,  -- steel (tail line)
  dSteel   = 15,  -- dark steel
}

-- === helper functions ===
local function hlin(x, y, w, color)
  for i = 0, w - 1 do
    local px = x + i
    if px >= 0 and px < 240 and y >= 0 and y < 136 then
      pix(px, y, color)
    end
  end
end

local function vlin(x, y, h, color)
  for j = 0, h - 1 do
    local py = y + j
    if py >= 0 and py < 136 and x >= 0 and x < 240 then
      pix(x, py, color)
    end
  end
end

local function bline(x0, y0, x1, y1, color)
  local dx = math.abs(x1 - x0)
  local dy = math.abs(y1 - y0)
  local sx = x0 < x1 and 1 or -1
  local sy = y0 < y1 and 1 or -1
  local err = dx - dy
  local x, y = x0, y0
  while true do
    if x >= 0 and x < 240 and y >= 0 and y < 136 then
      pix(x, y, color)
    end
    if x == x1 and y == y1 then break end
    local e2 = 2 * err
    if e2 > -dy then err = err - dy; x = x + sx end
    if e2 < dx then err = err + dx; y = y + sy end
  end
end

-- === stars ===
local stars = {}
for i = 1, 22 do
  stars[i] = {
    x = math.random(0, 239),
    y = math.random(0, 50),
    phase = math.random() * math.pi * 2,
    period = 80 + math.random() * 60,
    bright = math.random() > 0.5,
  }
end

-- === sky gradient ===
-- Seven-band sunset: deep navy -> dark blue -> blue -> light blue -> red -> orange -> amber
-- This mirrors a real sunset: dark sky at top, warm horizon at bottom
local bands = {
  {0,  10, C.navy},    -- deep night (top)
  {10, 20, C.dBlue},   -- dark blue
  {20, 32, C.blue},    -- blue
  {32, 42, C.lBlue},   -- light blue (twilight zone)
  {42, 54, C.red},     -- red (sunset band)
  {54, 68, C.orange},  -- orange
  {68, 96, C.amber},   -- amber (horizon glow)
  {96, 128, C.amber},  -- warm ground glow
}

local function draw_sky()
  for _, b in ipairs(bands) do
    local y0, y1, col = b[1], b[2], b[3]
    for y = y0, y1 - 1 do
      hlin(0, y, 240, col)
    end
  end

  -- Horizon glow: warm disc behind the kite area (subtle sun remnant)
  local sunY = 76
  local sunX = 120
  for r = 20, 10, -2 do
    for j = -r, r do
      local w = math.floor(math.sqrt(r * r - j * j) + 0.5)
      for x = sunX - w, sunX + w do
        local y = sunY + j
        if x >= 0 and x < 240 and y >= 64 and y < 96 then
          pix(x, y, C.orange)
        end
      end
    end
  end
end

local function draw_stars(t)
  for _, s in ipairs(stars) do
    local tw = 0.5 + 0.5 * math.sin(t / s.period * math.pi * 2 + s.phase)
    if tw > 0.55 then
      local col = s.bright and C.white or C.lSteel
      pix(s.x, s.y, col)
      if tw > 0.85 and s.bright then
        if s.x + 1 < 240 then pix(s.x + 1, s.y, C.lSteel) end
        if s.y + 1 < 136 then pix(s.x, s.y + 1, C.lSteel) end
      end
    end
  end
end

-- === kite ===
-- Diamond kite: 24px wide, 30px tall (about 10% canvas width at native, but the
-- full stack with tail is ~60% canvas height). At gallery card 200x113, the kite
-- diamond will be ~20px wide — readable.
local function draw_kite(cx, cy, t)
  local halfW = 12   -- half width = 24px total
  local topH  = 14   -- top half height
  local botH  = 16   -- bottom half height (longer = kite shape)

  -- Fill diamond with dark silhouette
  for j = 0, topH do
    local w = math.floor(halfW * j / topH + 0.5)
    hlin(cx - w, cy - topH + j, 2 * w + 1, C.navy)
  end
  for j = 0, botH do
    local w = math.floor(halfW * (botH - j) / botH + 0.5)
    hlin(cx - w, cy + j, 2 * w + 1, C.navy)
  end

  -- Frame outline (diamond edges)
  bline(cx, cy - topH, cx + halfW, cy, C.red)
  bline(cx + halfW, cy, cx, cy + botH, C.red)
  bline(cx, cy + botH, cx - halfW, cy, C.red)
  bline(cx - halfW, cy, cx, cy - topH, C.red)

  -- Warm rim on lower edges (sunset backlight from below)
  for j = 0, botH do
    local w = math.floor(halfW * (botH - j) / botH + 0.5)
    if cx + w >= 0 and cx + w < 240 and cy + j >= 0 and cy + j < 136 then
      pix(cx + w, cy + j, C.orange)
    end
    if cx - w >= 0 and cx - w < 240 and cy + j >= 0 and cy + j < 136 then
      pix(cx - w, cy + j, C.orange)
    end
  end

  -- Center cross point
  pix(cx, cy, C.amber)
end

-- === tail ===
-- 14 segments, ~72px long, undulating sine wave
local function draw_tail(cx, cy, t)
  local segments = 14
  local segLen = 5  -- pixels per segment
  local waveAmp = 8
  local waveLen = 5
  local waveSpeed = 0.012

  local prevX = cx
  local prevY = cy

  for i = 1, segments do
    local frac = i / segments
    local baseY = cy + i * segLen
    local sway = math.sin(i / waveLen * math.pi * 2 + t * waveSpeed * math.pi * 2) * waveAmp
    sway = sway * (1.0 - frac * 0.15)
    local sx = math.floor(cx + sway)
    local sy = math.floor(baseY)

    bline(prevX, prevY, sx, sy, C.dBlue)

    -- Small bow ties at each segment
    local bowColor = C.red
    if i % 2 == 0 then bowColor = C.dMagenta end
    pix(sx, sy, bowColor)
    if sx + 1 < 240 then pix(sx + 1, sy, bowColor) end
    if sy + 1 < 136 then pix(sx, sy + 1, bowColor) end

    prevX = sx
    prevY = sy
  end
end

-- === string ===
-- Faint string from kite to lower-right (implied viewer on the ground)
local function draw_string(cx, cy)
  bline(cx, cy, 210, 130, C.steel)
end

-- === ground / horizon ===
local function draw_ground()
  -- Thin ground line
  hlin(0, 126, 240, C.dSteel)
  hlin(0, 127, 240, C.navy)
  hlin(0, 128, 240, C.dBlue)

  -- Distant hill silhouettes
  for x = 0, 70 do
    local h = math.floor(4 * math.sin(x / 22 * math.pi) + 2)
    vlin(x, 126 - h, h + 1, C.navy)
  end
  for x = 160, 239 do
    local h = math.floor(5 * math.sin((x - 160) / 28 * math.pi) + 2)
    vlin(x, 126 - h, h + 1, C.navy)
  end
end

-- === main loop ===
local t = 0

function TIC()
  t = t + 1

  draw_sky()
  draw_stars(t)
  draw_ground()

  -- Kite position: gentle sway
  local swayAmp = 18
  local swayPeriod = 300  -- ~5 seconds at 60fps
  local swayX = math.sin(t / swayPeriod * math.pi * 2) * swayAmp
  local kiteX = 120 + math.floor(swayX)
  -- Slight vertical bob (90 degrees out of phase)
  local kiteY = 42 + math.floor(math.sin(t / swayPeriod * math.pi * 2 + 1.57) * 3)

  draw_string(kiteX, kiteY)
  draw_kite(kiteX, kiteY, t)
  draw_tail(kiteX, kiteY + 16, t)
end