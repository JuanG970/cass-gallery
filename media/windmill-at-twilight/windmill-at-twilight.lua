-- title: Windmill at Twilight
-- author: Cass
-- desc: A Dutch windmill silhouette against a twilight sky, blades slowly turning
-- script: lua

local C = {
  sky_top = 15,
  sky_up = 8,
  sky_mid = 8,
  sky_low = 1,
  sky_horizon = 4,
  ground = 0,
  ground_far = 15,
  mill = 0,
  mill_edge = 15,
  blade = 13,
  blade_sail = 12,
  star = 12,
  star_dim = 13,
  window = 4,
  window_glow = 3,
}

-- helpers
local function hline(x, y, w, color)
  for i = 0, w - 1 do
    local px = x + i
    if px >= 0 and px < 240 and y >= 0 and y < 136 then
      pix(px, y, color)
    end
  end
end

local function rect(x, y, w, h, color)
  for j = 0, h - 1 do
    hline(x, y + j, w, color)
  end
end

local function lline(x0, y0, x1, y1, color)
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

-- stars
local stars = {}
for i = 1, 22 do
  stars[i] = {
    x = math.random(0, 239),
    y = math.random(0, 35),
    bright = math.random() > 0.4,
    phase = math.random() * 120,
    period = 80 + math.random() * 80,
  }
end

-- windmill geometry — much larger
local MILL_X = 120
local MILL_BASE_Y = 115
local MILL_TOP = 42
local MILL_W_BASE = 26
local MILL_W_TOP = 16
local BLADE_LEN = 48
local BLADE_CX = MILL_X
local BLADE_CY = MILL_TOP - 4

function TIC()
  local t = time() / 60.0

  cls(C.sky_top)

  -- sky gradient: dark slate -> dark blue -> dark blue -> purple -> orange (thin)
  for y = 0, 114 do
    local color
    if y < 10 then
      color = C.sky_top
    elseif y < 30 then
      color = C.sky_up
    elseif y < 70 then
      color = C.sky_mid
    elseif y < 95 then
      color = C.sky_low
    elseif y < 105 then
      color = C.sky_low
    else
      color = C.sky_horizon
    end
    hline(0, y, 240, color)
  end

  -- stars (upper sky only)
  for _, s in ipairs(stars) do
    local twinkle = math.sin((t + s.phase) / s.period * math.pi * 2)
    local brightness = (twinkle + 1) / 2
    if s.bright then
      if brightness > 0.3 then
        pix(s.x, s.y, C.star)
      end
    else
      if brightness > 0.55 then
        pix(s.x, s.y, C.star_dim)
      end
    end
  end

  -- ground
  rect(0, 115, 240, 21, C.ground)
  -- thin horizon line (orange glow)
  hline(0, 114, 240, C.sky_horizon)
  hline(0, 115, 240, C.ground_far)
  -- field texture
  for x = 0, 239, 4 do
    pix(x, 118, C.ground_far)
  end
  for x = 2, 239, 5 do
    pix(x, 122, C.ground_far)
  end

  -- windmill tower (tapered trapezoid silhouette, much larger)
  for y = MILL_TOP, MILL_BASE_Y do
    local progress = (y - MILL_TOP) / (MILL_BASE_Y - MILL_TOP)
    local w = math.floor(MILL_W_TOP + (MILL_W_BASE - MILL_W_TOP) * progress)
    local x_start = MILL_X - math.floor(w / 2)
    hline(x_start, y, w, C.mill)
  end

  -- tower cap (dome) — smaaller relative to larger tower
  hline(MILL_X - 9, MILL_TOP - 4, 18, C.mill)
  hline(MILL_X - 8, MILL_TOP - 6, 16, C.mill)
  hline(MILL_X - 7, MILL_TOP - 8, 14, C.mill)
  hline(MILL_X - 6, MILL_TOP - 10, 12, C.mill)
  hline(MILL_X - 5, MILL_TOP - 11, 10, C.mill)

  -- warm window on tower (slightly larger, with glow)
  rect(MILL_X - 2, MILL_BASE_Y - 18, 5, 6, C.window)
  pix(MILL_X - 3, MILL_BASE_Y - 17, C.window_glow)
  pix(MILL_X + 3, MILL_BASE_Y - 17, C.window_glow)
  pix(MILL_X - 3, MILL_BASE_Y - 14, C.window_glow)
  pix(MILL_X + 3, MILL_BASE_Y - 14, C.window_glow)

  -- draw blades (rotating slowly, much longer)
  local angle = t * 0.2
  for arm = 0, 3 do
    local a = angle + arm * math.pi / 2
    local ex = BLADE_CX + math.cos(a) * BLADE_LEN
    local ey = BLADE_CY + math.sin(a) * BLADE_LEN

    -- blade arm line (thicker: draw 2 parallel lines)
    local perp_x = -math.sin(a)
    local perp_y = math.cos(a)

    -- main arm
    lline(BLADE_CX, BLADE_CY, math.floor(ex), math.floor(ey), C.blade)

    -- parallel arm line (1px offset for thickness)
    local ox = math.floor(BLADE_CX + perp_x)
    local oy = math.floor(BLADE_CY + perp_y)
    local ex2 = math.floor(ex + perp_x)
    local ey2 = math.floor(ey + perp_y)
    lline(ox, oy, ex2, ey2, C.blade)

    -- sail lattice (perpendicular cross-pieces along arm)
    for d = 6, BLADE_LEN - 3, 4 do
      local dx_arm = BLADE_CX + math.cos(a) * d
      local dy_arm = BLADE_CY + math.sin(a) * d
      for s = -2, 2 do
        local px = math.floor(dx_arm + perp_x * s)
        local py = math.floor(dy_arm + perp_y * s)
        if px >= 0 and px < 240 and py >= 0 and py < 136 then
          pix(px, py, C.blade_sail)
        end
      end
    end

    -- sail tip cluster (brighter)
    for td = -2, 0 do
      local tip_d = BLADE_LEN + td
      local tip_x = math.floor(BLADE_CX + math.cos(a) * tip_d)
      local tip_y = math.floor(BLADE_CY + math.sin(a) * tip_d)
      if tip_x >= 0 and tip_x < 240 and tip_y >= 0 and tip_y < 136 then
        pix(tip_x, tip_y, C.blade_sail)
      end
    end
  end

  -- blade hub (4x4 block)
  rect(BLADE_CX - 1, BLADE_CY - 1, 4, 4, C.blade_sail)

  -- faint edge highlight on tower left side
  for y = MILL_TOP + 5, MILL_BASE_Y - 5, 3 do
    local progress = (y - MILL_TOP) / (MILL_BASE_Y - MILL_TOP)
    local w = math.floor(MILL_W_TOP + (MILL_W_BASE - MILL_W_TOP) * progress)
    local x_start = MILL_X - math.floor(w / 2)
    pix(x_start, y, C.mill_edge)
  end
end