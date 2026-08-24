-- title:  Ferris Wheel at Night
-- author: Cass
-- desc:   A slowly rotating ferris wheel with warm-lit cabins under a starry sky
-- script: lua

-- DB16 palette indices:
-- 0=black/navy, 1=magenta, 2=dark red, 3=salmon, 4=orange,
-- 5=yellow-green, 6=green, 7=dark teal, 8=dark blue, 9=blue,
-- 10=light blue, 11=pale cyan, 12=off-white, 13=light gray,
-- 14=mid gray, 15=dark slate

local C = {
  bg       = 0,   -- deep night sky
  sky_mid  = 8,   -- dark blue (horizon glow band)
  sky_lo   = 15,  -- dark slate (horizon haze)
  star_b   = 12,  -- bright star (off-white)
  star_m   = 13,  -- mid star (light gray)
  star_d   = 14,  -- dim star (mid gray)
  wheel    = 13,  -- wheel structure (light gray)
  wheel_d  = 14,  -- wheel structure shadow (mid gray)
  cabin    = 4,   -- warm cabin light (orange)
  cabin_b  = 3,   -- cabin bright (salmon)
  cabin_g  = 12,  -- cabin glow (off-white)
  ground   = 15,  -- ground (dark slate)
  ground_d = 0,   -- ground shadow
  support  = 14,  -- support structure (mid gray)
}

-- Center of the wheel
local CX = 120
local CY = 68
local RADIUS = 48    -- wheel radius
local NSPOKES = 8    -- number of spokes
local NCABINS = 8    -- one cabin per spoke end

-- Star field
local stars = {}
local function init_stars()
  stars = {}
  for i = 1, 35 do
    local tier
    if i <= 5 then tier = 0       -- bright
    elseif i <= 17 then tier = 1  -- mid
    else tier = 2                 -- dim
    end
    stars[i] = {
      x = math.random(0, 239),
      y = math.random(0, 80),  -- upper sky only (above wheel)
      tier = tier,
      phase = math.random() * 6.28,
      period = 40 + math.random() * 60,
    }
  end
end

-- Helpers (5-arg pix is broken in this build)
local function hline(x, y, w, color)
  for i = 0, w - 1 do
    local px = x + i
    if px >= 0 and px < 240 and y >= 0 and y < 136 then
      pix(px, y, color)
    end
  end
end

local function lline(x0, y0, x1, y1, color)
  -- Bresenham
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

local function disc(cx, cy, r, color)
  for j = -r, r do
    local w = math.floor(math.sqrt(r * r - j * j) + 0.5)
    hline(cx - w, cy + j, 2 * w + 1, color)
  end
end

-- Animation state
local t = 0
local angle = 0

-- Draw a circle outline using the midpoint algorithm
local function circle_outline(cx, cy, r, color)
  local x = r
  local y = 0
  local err = 0
  while x >= y do
    -- 8 octants
    for _, pt in ipairs({
      {cx+x, cy+y}, {cx+y, cy+x}, {cx-y, cy+x}, {cx-x, cy+y},
      {cx-x, cy-y}, {cx-y, cy-x}, {cx+y, cy-x}, {cx+x, cy-y},
    }) do
      local px, py = pt[1], pt[2]
      if px >= 0 and px < 240 and py >= 0 and py < 136 then
        pix(px, py, color)
      end
    end
    y = y + 1
    if err <= 0 then
      err = err + 2 * y + 1
    end
    if err > 0 then
      x = x - 1
      err = err - 2 * x + 1
    end
  end
end

function TIC()
  t = t + 1

  -- Background: deep night sky
  cls(C.bg)

  -- Horizon glow band (dark blue, 2px) + dark slate (1px)
  hline(0, 116, 240, C.sky_mid)
  hline(0, 117, 240, C.sky_mid)
  hline(0, 118, 240, C.sky_lo)

  -- Stars (twinkle)
  for _, s in ipairs(stars) do
    local tw = math.sin(t * 6.28 / s.period + s.phase)
    local brightness
    if s.tier == 0 then
      brightness = tw > -0.3 and C.star_b or C.star_m
    elseif s.tier == 1 then
      brightness = tw > 0 and C.star_m or C.star_d
    else
      brightness = tw > 0.5 and C.star_d or -1
    end
    if brightness >= 0 then
      pix(s.x, s.y, brightness)
    end
  end

  -- Ground
  hline(0, 119, 240, C.ground)
  for y = 120, 135 do
    hline(0, y, 240, C.ground_d)
  end

  -- Support structure (A-frame legs going down to ground)
  lline(CX - 25, CY + 18, CX - 42, 119, C.support)
  lline(CX + 25, CY + 18, CX + 42, 119, C.support)
  -- Cross brace
  lline(CX - 16, CY + 32, CX + 16, CY + 32, C.support)
  lline(CX - 10, CY + 45, CX + 10, CY + 45, C.support)

  -- Wheel rotation
  angle = angle + 0.004  -- slow rotation (~one revolution per 26 seconds at 60fps)

  -- Draw wheel rim using midpoint circle algorithm (continuous, no gaps)
  circle_outline(CX, CY, RADIUS, C.wheel)
  circle_outline(CX, CY, RADIUS - 1, C.wheel_d)  -- inner rim for depth

  -- Spokes (8 lines from center to rim, rotating with angle)
  for i = 0, NSPOKES - 1 do
    local a = angle + (i * 6.28 / NSPOKES)
    local ex = CX + math.cos(a) * RADIUS
    local ey = CY + math.sin(a) * RADIUS
    lline(CX, CY, math.floor(ex + 0.5), math.floor(ey + 0.5), C.wheel_d)
  end

  -- Hub (center)
  disc(CX, CY, 3, C.wheel)
  pix(CX, CY, C.wheel_d)

  -- Cabins at spoke ends (warm-lit, rotating with wheel)
  for i = 0, NCABINS - 1 do
    local a = angle + (i * 6.28 / NCABINS)
    local ex = CX + math.cos(a) * RADIUS
    local ey = CY + math.sin(a) * RADIUS
    local px = math.floor(ex + 0.5)
    local py = math.floor(ey + 0.5)

    -- Cabin glow (halo: 2px in each direction)
    for dx = -2, 2 do
      for dy = -2, 2 do
        if math.abs(dx) + math.abs(dy) <= 2 then
          local tx, ty = px + dx, py + dy
          if tx >= 0 and tx < 240 and ty >= 0 and ty < 136 then
            if math.abs(dx) <= 1 and math.abs(dy) <= 1 then
              pix(tx, ty, C.cabin)     -- inner glow (orange)
            else
              pix(tx, ty, C.cabin_b)   -- outer glow (salmon, dimmer)
            end
          end
        end
      end
    end

    -- Cabin bright center
    if px >= 0 and px < 240 and py >= 0 and py < 136 then
      pix(px, py, C.cabin_g)  -- off-white bright center
    end
  end

  -- Faint ground reflection of wheel cabins (warm dots near ground)
  for i = 0, NCABINS - 1 do
    local a = angle + (i * 6.28 / NCABINS)
    local ex = CX + math.cos(a) * RADIUS
    local ey = CY + math.sin(a) * RADIUS
    -- Only reflect cabins in the lower half of the wheel
    if ey > CY then
      local rpx = math.floor(ex + 0.5)
      local rpy = 120 + math.floor((ey - CY) * 0.1)
      if rpx >= 0 and rpx < 240 and rpy >= 120 and rpy < 135 then
        pix(rpx, rpy, C.cabin)
      end
    end
  end
end

-- Initialize
math.randomseed(42)
init_stars()