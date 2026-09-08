-- title: Sailboat at Dawn
-- author: Cass
-- desc: A small sailboat with white sails on calm water at dawn, gentle rocking
-- script: lua

local C = {
  -- sky bands (top to bottom): deep night fading to dawn
  sky0 = 0,    -- very dark navy (night)
  sky1 = 8,    -- dark blue
  sky2 = 9,    -- blue
  sky3 = 1,    -- dark purple → magenta (dawn glow)
  sky4 = 3,    -- red-orange (horizon warmth)
  sky5 = 4,    -- orange (low dawn)
  -- water
  water0 = 15, -- dark slate
  water1 = 8,  -- dark blue
  water2 = 9,  -- blue
  water3 = 1,  -- purple-magenta (dawn reflection)
  -- boat
  hull = 15,   -- dark slate (hull silhouette)
  hull2 = 14,  -- mid gray (hull highlight)
  sail = 12,   -- off-white (sails lit by dawn)
  sail2 = 13,  -- light gray (sail shadow side)
  mast = 14,   -- mid gray
  -- stars (fading — a few still visible at dawn)
  s1 = 13, s2 = 14,
  -- sun
  sun = 4,     -- orange
  sun2 = 3,    -- red-orange halo
}

-- persistent state
local stars = {}
math.randomseed(37)
for i = 1, 12 do
  stars[i] = {
    x = math.random(0, 239),
    y = math.random(0, 40),
    phase = math.random() * 80,
    period = 100 + math.random() * 50,
  }
end

-- ripples on water (deterministic positions)
local ripples = {}
for i = 1, 5 do
  ripples[i] = {
    y = 96 + i * 8,
    phase = i * 2.3,
    period = 40 + i * 15,
  }
end

-- helpers (pix 5-arg is broken in 1.1.2837)
local function hline(x, y, w, color)
  for i = 0, w - 1 do pix(x + i, y, color) end
end

local function rectfill(x, y, w, h, color)
  for j = 0, h - 1 do hline(x, y + j, w, color) end
end

function TIC()
  local t = time() / 60.0
  cls(C.sky0)

  -- === SKY GRADIENT ===
  -- Layered horizontal bands from deep night (top) to dawn glow (horizon)
  -- y=0..24: deep night (#0)
  -- y=25..40: dark blue (#8)
  -- y=41..58: blue (#9) 
  -- y=59..70: purple/magenta (#1) — dawn transition
  -- y=71..80: red-orange (#3) — dawn glow
  -- y=81..92: orange (#4) — low horizon warmth
  hline(0, 25, 240, C.sky1)
  for y = 26, 40 do hline(0, y, 240, C.sky1) end
  for y = 41, 58 do hline(0, y, 240, C.sky2) end
  for y = 59, 70 do hline(0, y, 240, C.sky3) end
  for y = 71, 80 do hline(0, y, 240, C.sky4) end
  for y = 81, 92 do hline(0, y, 240, C.sky5) end

  -- === FADING STARS ===
  -- A few faint stars still visible in the upper sky at dawn
  for _, s in ipairs(stars) do
    local b = 0.4 + 0.6 * math.sin((t + s.phase) * 6.283 / s.period)
    if b > 0.45 then
      pix(s.x, s.y, C.s1)
    elseif b > 0.3 then
      pix(s.x, s.y, C.s2)
    end
  end

  -- === DAWN SUN ===
  -- Small warm sun on the horizon, slightly right of center
  local sunx = 155
  local suny = 86
  -- halo (2 concentric rings)
  circ(sunx, suny, 7, C.sun2)
  circ(sunx, suny, 5, C.sun)
  circ(sunx, suny, 3, C.sail) -- bright core (off-white)
  -- subtle warm glow spread on horizon
  hline(sunx - 14, suny, 28, C.sun2)
  hline(sunx - 10, suny - 1, 20, C.sun2)
  hline(sunx - 10, suny + 1, 20, C.sun2)

  -- === WATER ===
  -- y=93..135: water
  for y = 93, 100 do hline(0, y, 240, C.water0) end
  for y = 101, 110 do hline(0, y, 240, C.water1) end
  for y = 111, 120 do hline(0, y, 240, C.water2) end
  for y = 121, 135 do hline(0, y, 240, C.water0) end

  -- dawn reflection on water (vertical streak from sun position)
  local refl_w = 5
  for y = 93, 120 do
    local fade = 1.0 - (y - 93) / 27.0
    if fade > 0.3 then
      local w = math.max(2, math.floor(refl_w * (1.0 + (1.0 - fade) * 2)))
      local cx = sunx + math.sin(t * 0.8 + y * 0.3) * 1.5
      if fade > 0.6 then
        hline(math.floor(cx - w / 2), y, w, C.water3)
      else
        hline(math.floor(cx - w / 2), y, w, C.water2)
      end
    end
  end

  -- ripples (horizontal bands that pulse slowly)
  for _, r in ipairs(ripples) do
    local p = 0.5 + 0.5 * math.sin((t + r.phase) * 6.283 / r.period)
    if p > 0.55 then
      hline(0, r.y, 240, C.water1)
      -- broken segments for natural feel
      local off = math.floor(t * 0.5) % 20
      hline(off, r.y, 8, C.water0)
      hline(off + 40, r.y, 6, C.water0)
      hline(off + 90, r.y, 10, C.water0)
      hline(off + 150, r.y, 7, C.water0)
      hline(off + 200, r.y, 9, C.water0)
    end
  end

  -- === SAILBOAT ===
  -- Gentle rocking: horizontal sway + slight rotation effect via offset
  local sway = math.sin(t * 0.35) * 6
  local bx = 95 + sway        -- boat center x
  local hor = 92              -- horizon line (water surface)
  local bob = math.sin(t * 0.35 + 0.5) * 1.5  -- vertical bob
  local by = hor + bob        -- boat base y (at waterline)

  -- mast (vertical, from hull up)
  local mast_top = by - 42
  local mast_bot = by - 2
  line(bx, mast_top, bx, mast_bot, C.mast)

  -- mainsail (triangle: mast top → mast bottom-right → boom end)
  -- Lit side (facing dawn = right side, warm light)
  local sail_top = mast_top + 2
  local sail_bot = by - 4
  local sail_r = bx + 24
  -- Filled triangle for mainsail
  tri(bx, sail_top, sail_r, sail_bot, bx, sail_bot, C.sail)
  -- Shadow stripe on the left edge of mainsail (facing away from dawn)
  tri(bx, sail_top, bx + 3, sail_bot, bx, sail_bot, C.sail2)

  -- jib (front sail, smaller triangle on left of mast)
  local jib_top = sail_top + 3
  local jib_bot = by - 6
  local jib_l = bx - 16
  tri(bx, jib_top, bx, jib_bot, jib_l, jib_bot, C.sail2)
  -- lit edge (right side of jib, near mast)
  tri(bx, jib_top, bx, jib_bot, bx - 2, jib_bot, C.sail)

  -- boom (horizontal line at sail bottom)
  line(bx - 4, sail_bot, sail_r, sail_bot, C.mast)

  -- hull (boat body): a low trapezoid at the waterline
  -- Hull: 30px wide, 5px tall, slight taper at bottom
  local hw = 15  -- half-width
  local hh = 5   -- height
  -- top edge (deck)
  hline(bx - hw, by - hh, hw * 2, C.hull)
  -- sides
  line(bx - hw, by - hh, bx - hw + 3, by, C.hull)
  line(bx + hw, by - hh, bx + hw - 3, by, C.hull)
  -- bottom
  hline(bx - hw + 3, by, hw * 2 - 6, C.hull)
  -- fill the hull
  rectfill(bx - hw + 1, by - hh + 1, hw * 2 - 2, hh - 1, C.hull)
  -- hull highlight (warm side, right edge catching dawn light)
  line(bx + hw - 1, by - hh, bx + hw - 3, by, C.hull2)

  -- reflection of boat in water (faint, inverted)
  local refl_y = by + 2
  -- hull reflection
  hline(bx - hw + 3, refl_y, hw * 2 - 6, C.water1)
  hline(bx - hw + 4, refl_y + 1, hw * 2 - 8, C.water2)
  -- sail reflection (very faint)
  for i = 0, 8 do
    local ry = refl_y + 2 + i * 2
    if ry < 120 then
      local rw = math.max(2, hw * 2 - 6 - i * 3)
      hline(bx - math.floor(rw / 2), ry, rw, C.water1)
    end
  end

  -- gentle wake behind the boat (2 short horizontal lines that shift)
  local wake_y = by + 1
  local wake_off = math.floor(t * 0.8) % 30
  hline(bx - hw - 6 - wake_off, wake_y, 4, C.water2)
  hline(bx - hw - 14 - wake_off, wake_y + 1, 3, C.water2)
end