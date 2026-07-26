-- title: Lit Window
-- author: Cass
-- desc: A single warm window glows on a dark building facade at night. The
--       window has four panes divided by a thin mullion; the upper-right
--       pane is slightly dimmer than the others, suggesting a curtain
--       drawn halfway or a candle just behind the glass. The window's
--       warm light spills down onto the wall below it. A pale moon hangs
--       in the upper-left sky. A few stars dot the void. The only motion
--       is the window's flicker — a slow, breath-like pulse on a 3.6s
--       period, as if the candle inside the room is settling. The stars
--       twinkle on a slower 9-15s cycle. Pure ambience, no controls.
-- script: lua

-- ============================================================
-- Lit Window — single warm object against a dark field.
--
-- Composition (back to front):
--   1. Sky: deep midnight navy (DB16 #1a1c2c).
--   2. Stars: scattered small bright dots, twinkle on slow periods.
--   3. Moon: pale disc at upper-left, with a soft halo.
--   4. Building wall: solid very-dark-purple, fills the bottom 80% of the
--      cart.
--   5. Window glow (the only motion): four panes of warm light, divided
--      by a thin mullion (vertical) and a transom (horizontal). The
--      upper-right pane is slightly dimmer (suggests curtain / candle).
--      Each pane flickers on a slow 3.6s period (the breath of the
--      candle/TV inside the room).
--   6. Window frame: dark slate border around the panes.
--   7. Warm spill: a faint warm halo bleeding downward from the window
--      onto the wall, fading over ~20 rows.
--   8. Sill: a single horizontal bright line just below the window,
--      catching the warm light.
--   9. Ground line: a horizontal mid-gray line at the bottom (the street
--      or the building's base).
--
-- Color palette references TIC-80 DB16 (verified against 1.1.2837):
--   0  black           #1a1c2c
--   1  dark purple     #5d275d
--   2  dark red        #b13e53
--   3  red-orange      #ef7d57
--   4  orange          #ffcd75
--   5  yellow-green    #a7f070
--   6  green           #38b764
--   7  dark teal       #257179
--   8  dark blue       #29366f
--   9  blue            #3b5dc9
--   10 light blue      #41a6f6
--   11 pale cyan       #73eff7
--   12 white           #f4f4f4
--   13 light gray      #94b0c2
--   14 mid gray        #566c86
--   15 dark slate      #333c57
-- ============================================================

local C = {
  sky         = 0,  -- black (the deep night sky)
  sky_edge    = 1,  -- dark purple (very faint sky variation)
  -- The wall is darker than the spill but brighter than pure black
  -- so the spill has something to *brighten against*. #0 (black)
  -- would make the spill read as a halo on a void; #1 (dark purple)
  -- reads as the building's stone wall at night, with warm
  -- pixels visible as light against it.
  wall        = 1,  -- dark purple (the building facade)
  wall_dark   = 0,  -- black (deep shadow at the wall edges)

  moon_body   = 13, -- light gray (the moon disc)
  moon_halo   = 14, -- mid gray (soft moon halo)
  moon_halo_far = 15, -- dark slate (faintest halo)
  star_bright = 12, -- white (the brightest stars)
  star_dim    = 13, -- light gray (mid stars)

  pane_warm       = 4,  -- orange (lit pane, full bright)
  pane_warm_mid   = 4,  -- orange (lit pane, mid flicker - SAME for unified look)
  -- Dim pane uses the same char class as the lit panes but at a
  -- slightly cooler (less bright) position. This makes the dim
  -- pane read as "part of the same window, with a curtain drawn
  -- across it" rather than "a different-colored block."
  pane_dim        = 2,  -- dark red (the dim pane - curtain behind)
  pane_dim_mid    = 1,  -- dark purple (dim pane, mid flicker)

  frame       = 15, -- dark slate (window frame)
  mullion     = 15, -- dark slate (the vertical mullion)
  transom     = 15, -- dark slate (the horizontal transom)

  -- The warm spill needs to be *visible* against the dark purple
  -- wall, so it uses brighter colors than the wall (#1). The wall
  -- is dark purple (#1), so anything brighter than #1 will read
  -- as warm glow. Use #3 (red-orange) for the brightest spill,
  -- #2 (dark red) for the mid spill, and #1 (dark purple) for the
  -- faintest edge.
  spill_bright   = 3,  -- red-orange (the brightest warm spill on the wall)
  spill_warm     = 2,  -- dark red (the mid warm spill)
  spill_dim      = 1,  -- dark purple (the faintest spill edge - matches wall)
  sill           = 4,  -- orange (the warm sill, hottest)
  sill_dim       = 3,  -- red-orange (the sill edge)
  ground         = 14, -- mid gray (the ground line)
}

-- ============================================================
-- Cart helpers: 5-arg pix(x,y,w,h,color) is broken in 1.1.2837.
-- ============================================================
local function hline(x, y, w, color)
  for i = 0, w - 1 do pix(x + i, y, color) end
end
local function vline(x, y, h, color)
  for j = 0, h - 1 do pix(x, y + j, color) end
end
local function rect(x, y, w, h, color)
  for j = 0, h - 1 do hline(x, y + j, w, color) end
end
local function clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

-- LCG PRNG (deterministic at boot, for reproducible star layout).
local function lcg(seed)
  local s = seed
  return function()
    s = (s * 1103515245 + 12345) % 2147483648
    return s / 2147483648
  end
end

-- ============================================================
-- Window geometry. The window is centered horizontally on the
-- 240-wide cart. It has 4 panes: 2 columns x 2 rows. The
-- upper-right pane is the "dim" one (suggests curtain or
-- candle flickering behind glass). The window occupies ~50% of
-- the cart height — large enough to read as the dominant
-- element at thumbnail size.
-- ============================================================
local WIN_X0     = 72   -- left edge of window
local WIN_Y0     = 50   -- top edge of window (slightly higher)
local WIN_W      = 96   -- 96 pixels wide (was 68)
local WIN_H      = 64   -- 64 pixels tall (was 50)
local WIN_X1     = WIN_X0 + WIN_W    -- 168
local WIN_Y1     = WIN_Y0 + WIN_H    -- 114

local FRAME_W    = 2    -- frame thickness (in pixels)
local MULLION_X  = WIN_X0 + WIN_W // 2  -- vertical divider: col 120
local TRANSOM_Y  = WIN_Y0 + WIN_H // 2  -- horizontal divider: row 82

-- Pane rectangles (interior, inside the frame).
local PANES = {
  -- upper-left (lit)
  { x0 = WIN_X0 + FRAME_W,         y0 = WIN_Y0 + FRAME_W,
    x1 = MULLION_X,                y1 = TRANSOM_Y,
    warm = true,  phase = 0.0 },
  -- upper-right (DIM — curtain / candle behind)
  { x0 = MULLION_X + 1,            y0 = WIN_Y0 + FRAME_W,
    x1 = WIN_X1 - FRAME_W,         y1 = TRANSOM_Y,
    warm = false, phase = 1.4 },
  -- lower-left (lit)
  { x0 = WIN_X0 + FRAME_W,         y0 = TRANSOM_Y + 1,
    x1 = MULLION_X,                y1 = WIN_Y1 - FRAME_W,
    warm = true,  phase = 2.1 },
  -- lower-right (lit)
  { x0 = MULLION_X + 1,            y0 = TRANSOM_Y + 1,
    x1 = WIN_X1 - FRAME_W,         y1 = WIN_Y1 - FRAME_W,
    warm = true,  phase = 0.7 },
}

-- Moon position (upper-left of sky)
local MOON_X = 22
local MOON_Y = 14
local MOON_R = 4

-- ============================================================
-- Stars: scatter 18 stars across the sky region. Each star has
-- a phase offset so they twinkle out of sync. Some are bright,
-- some are dim.
-- ============================================================
local function make_stars(seed)
  local r = lcg(seed)
  local stars = {}
  -- Keep stars out of the moon halo (radius 8 from moon center).
  -- Keep stars above the wall line (rows 0-54 only).
  for i = 1, 18 do
    local x, y
    repeat
      x = math.floor(r() * 240)
      y = math.floor(r() * 50)
    until (x - MOON_X) * (x - MOON_X) + (y - MOON_Y) * (y - MOON_Y) > 100
    stars[i] = {
      x = x,
      y = y,
      bright = r() < 0.35,
      phase  = r() * 10.0,         -- twinkle phase offset
      period = 9.0 + r() * 6.0,    -- 9-15s twinkle period
    }
  end
  return stars
end

local STARS = make_stars(7919)

-- ============================================================
-- Pane flicker: each pane has its own phase. The flicker is a
-- sum of two slow sines to give a non-trivial breath — not a
-- simple on/off pulse.
-- ============================================================
local function pane_brightness(t, pane)
  -- base 0.7-1.0 range, with two superimposed slow sines
  local p1 = math.sin(t * 2 * math.pi / 3.6 + pane.phase)
  local p2 = 0.5 * math.sin(t * 2 * math.pi / 7.2 + pane.phase * 1.7)
  local b = 0.85 + 0.10 * p1 + 0.05 * p2
  return clamp(b, 0.0, 1.0)
end

-- ============================================================
-- Paint the sky background.
-- ============================================================
local function paint_sky()
  rect(0, 0, 240, 56, C.sky)
  -- Very subtle gradient on the sky: row 0 = sky, row 55 = sky_edge
  for y = 0, 55 do
    hline(0, y, 240, C.sky)
  end
end

-- ============================================================
-- Paint the moon. Disc with a soft halo (filled annulus).
-- ============================================================
local function paint_moon()
  -- Outer halo (large, dim)
  for dy = -7, 7 do
    for dx = -7, 7 do
      local dist = math.sqrt(dx * dx + dy * dy)
      if dist >= 5.5 and dist < 7.5 then
        local x, y = MOON_X + dx, MOON_Y + dy
        if x >= 0 and x < 240 and y >= 0 and y < 56 then
          -- Sparse halo: skip some pixels for dithered softness
          if (dx + dy * 7) % 5 < 2 then
            pix(x, y, C.moon_halo_far)
          end
        end
      end
    end
  end
  -- Inner halo (small, brighter)
  for dy = -5, 5 do
    for dx = -5, 5 do
      local dist = math.sqrt(dx * dx + dy * dy)
      if dist >= 4.0 and dist < 5.5 then
        local x, y = MOON_X + dx, MOON_Y + dy
        if x >= 0 and x < 240 and y >= 0 and y < 56 then
          pix(x, y, C.moon_halo)
        end
      end
    end
  end
  -- Body (filled disc)
  for dy = -3, 3 do
    for dx = -3, 3 do
      if dx * dx + dy * dy <= MOON_R * MOON_R - 1 then
        pix(MOON_X + dx, MOON_Y + dy, C.moon_body)
      end
    end
  end
end

-- ============================================================
-- Paint the stars. Twinkle: brightness cycles on each star's
-- own period, with a phase offset. Stars are visible most of
-- the time (no threshold blink — they cycle slowly through
-- bright and dim, never fully invisible).
-- ============================================================
local function paint_stars(t)
  for _, s in ipairs(STARS) do
    local cycle = 0.5 + 0.5 * math.sin(t * 2 * math.pi / s.period + s.phase)
    -- cycle is in [0, 1]. Bright stars use 12 (white) for the upper
    -- half of the cycle and 13 (light gray) for the lower half.
    -- Dim stars use 13 always, but skip the pixel on the bottom half
    -- (they're tiny dots that fade in and out).
    if s.bright then
      local col = (cycle > 0.5) and C.star_bright or C.star_dim
      pix(s.x, s.y, col)
    else
      if cycle > 0.4 then
        pix(s.x, s.y, C.star_dim)
      end
    end
  end
end

-- ============================================================
-- Paint the building wall.
-- ============================================================
local function paint_wall()
  rect(0, 55, 240, 81, C.wall)
end

-- ============================================================
-- Paint the warm spill below the window. A vertical gradient
-- of warm pixels fading from bright (just below the window)
-- to invisible (15 rows down). The spill needs to be visibly
-- *brighter* than the wall so it reads as light bleeding off
-- the glass.
-- ============================================================
local function paint_spill(t)
  local b = pane_brightness(t, PANES[1])  -- sync with the lit panes
  -- The spill extends from WIN_Y1 downward, fading over ~16 rows.
  local spill_x0 = WIN_X0 + 2
  local spill_x1 = WIN_X1 - 2
  local spill_w  = spill_x1 - spill_x0
  for y = WIN_Y1, math.min(WIN_Y1 + 16, 134) do
    local dy = y - WIN_Y1
    local v_intensity = 1.0 - dy / 16.0  -- vertical falloff
    if v_intensity > 0.15 then
      -- Pick color based on vertical intensity
      local col
      if v_intensity > 0.7 then
        col = C.spill_bright
      elseif v_intensity > 0.35 then
        col = C.spill_warm
      else
        col = C.spill_dim
      end
      -- Horizontal falloff: center is brighter than edges
      for x = spill_x0, spill_x1 do
        local dx = math.abs(x - (spill_x0 + spill_w // 2))
        local h_intensity = 1.0 - dx / (spill_w / 2)
        -- Only paint where the combined intensity is high enough
        if h_intensity * v_intensity > 0.18 then
          -- Pulse with the brightness
          if v_intensity > 0.5 and (b > 0.92 or h_intensity > 0.85) then
            pix(x, y, C.spill_bright)
          elseif v_intensity > 0.3 then
            pix(x, y, col)
          else
            pix(x, y, C.spill_dim)
          end
        end
      end
    end
  end
end

-- ============================================================
-- Paint a single pane. The "warm" panes pulse on a bright
-- orange/red-orange cycle; the "dim" pane (curtain behind)
-- uses the warm palette at reduced brightness, with only
-- the central 60% of the pane lit. The dim pane's edges
-- stay the wall color, suggesting a curtain hangs there.
-- ============================================================
local function paint_pane(pane, t)
  local b = pane_brightness(t, pane)
  -- b in [0,1]. Lit panes: b=1 -> orange (4), b=0.85 -> red-orange (3).
  -- Dim pane: also in the warm range, but lower brightness.
  if pane.warm then
    local col = (b > 0.92) and C.pane_warm or C.pane_warm_mid
    rect(pane.x0, pane.y0, pane.x1 - pane.x0, pane.y1 - pane.y0, col)
  else
    -- Dim pane: only the central portion is lit. Use the same warm
    -- palette but at a cooler position.
    local col = (b > 0.92) and C.pane_dim or C.pane_dim_mid
    local w = pane.x1 - pane.x0
    local h = pane.y1 - pane.y0
    local inner_x0 = pane.x0 + math.floor(w * 0.25)
    local inner_x1 = pane.x1 - math.floor(w * 0.25)
    local inner_y0 = pane.y0 + math.floor(h * 0.20)
    local inner_y1 = pane.y1 - math.floor(h * 0.20)
    rect(inner_x0, inner_y0, inner_x1 - inner_x0, inner_y1 - inner_y0, col)
    -- A thin warm edge along the top (catches more light from above)
    if b > 0.85 then
      hline(pane.x0 + 3, pane.y0 + 1, (pane.x1 - pane.x0) - 6, C.pane_warm_mid)
    end
  end
end

-- ============================================================
-- Paint the window frame and dividers.
-- ============================================================
local function paint_frame()
  -- Outer frame (top, bottom, left, right)
  hline(WIN_X0, WIN_Y0, WIN_W, C.frame)
  hline(WIN_X0, WIN_Y1, WIN_W, C.frame)
  vline(WIN_X0, WIN_Y0, WIN_H, C.frame)
  vline(WIN_X1, WIN_Y0, WIN_H, C.frame)
  -- Mullion (vertical, single column)
  vline(MULLION_X, WIN_Y0, WIN_H, C.mullion)
  -- Transom (horizontal, single row)
  hline(WIN_X0, TRANSOM_Y, WIN_W, C.transom)
end

-- ============================================================
-- Paint the sill (a single bright horizontal line just below
-- the window, catching the warm spill).
-- ============================================================
local function paint_sill(t)
  local b = pane_brightness(t, PANES[1])
  local col = (b > 0.92) and C.sill or C.sill_dim
  hline(WIN_X0 - 1, WIN_Y1 + 1, WIN_W + 2, col)
end

-- ============================================================
-- Paint the ground line (horizontal mid-gray line at the very
-- bottom of the cart).
-- ============================================================
local function paint_ground()
  hline(0, 134, 240, C.ground)
end

-- ============================================================
-- TIC() — main loop.
-- ============================================================
local t = 0

function TIC()
  -- Sky: deep midnight, with a faint scatter on the very top row.
  paint_sky()

  -- Stars + moon (above the wall line)
  paint_stars(t)
  paint_moon()

  -- Wall (everything below row 55)
  paint_wall()

  -- Window: panes first, then frame on top
  for _, p in ipairs(PANES) do
    paint_pane(p, t)
  end
  paint_frame()

  -- Warm spill (the light bleeding onto the wall below the window)
  paint_spill(t)

  -- Sill (just below the window)
  paint_sill(t)

  -- Ground line (bottom of cart)
  paint_ground()

  t = t + 1 / 60
end