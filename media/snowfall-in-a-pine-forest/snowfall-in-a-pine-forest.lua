-- title: Snowfall in a Pine Forest
-- author: Cass
-- desc: A quiet winter night in a pine forest. A pale moon hangs low above
--       the treeline, snow falls slowly through cold air, and a single warm
--       cabin light glows in the far distance. Foreground pines silhouette
--       against the snow. Pure ambience, no controls.
-- script: lua

-- ============================================================
-- Snowfall in a Pine Forest — slow winter ambient
--
-- Layers (back to front):
--   1. Sky gradient (deep midnight at top, cold steel-blue near horizon)
--   2. Stars (sparse, dim, slow twinkle behind the moon)
--   3. Moon (pale disk with soft glow halo)
--   4. Distant tree silhouette on the horizon line
--   5. Far warm cabin glow (small orange dot near treeline)
--   6. Mid-distance pine silhouettes (3-4 trees, mid-tone)
--   7. Foreground pines (3 trees, black, slightly off-center)
--   8. Snow ground (gradient from snow-shadow blue to white)
--   9. Snowflakes (60 particles, drift down with sinusoidal sway)
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
  sky_top    = 8,   -- dark blue (midnight)
  sky_mid    = 15,  -- dark slate
  sky_horizon = 14, -- mid gray (steel blue near horizon)
  star       = 12,  -- white (but used at low alpha only)
  star_dim   = 13,  -- light gray
  moon       = 13,  -- light gray
  moon_glow  = 14,  -- mid gray (soft halo)
  far_treeline = 1, -- dark purple (distant treeline)
  cabin_glow = 4,   -- orange
  cabin_glow_warm = 3, -- red-orange
  mid_pine   = 1,   -- dark purple
  fg_pine    = 0,   -- black
  snow_top   = 13,  -- light gray (snow at horizon, slightly blue)
  snow_mid   = 12,  -- white (mid snow)
  snow_fg    = 12,  -- white (foreground snow)
  snow_shadow = 14, -- mid gray (snow in shadow)
  flake      = 12,  -- white
  flake_dim  = 13,  -- light gray
}

-- ============================================================
-- PRNG for deterministic randomness
-- ============================================================
local function make_lcg(seed)
  local s = seed or 1337
  return function()
    s = (s * 1103515245 + 12345) % 2147483648
    return s / 2147483648
  end
end

-- ============================================================
-- Star pre-pass: 18 stars in the upper sky, fixed positions,
-- slow independent twinkle.
-- ============================================================
local stars = {}
local star_rnd = make_lcg(7777)
for i = 1, 18 do
  stars[i] = {
    x = math.floor(star_rnd() * 240),
    y = math.floor(star_rnd() * 50),
    phase = star_rnd() * math.pi * 2,
    period = 5 + star_rnd() * 7,  -- 5-12s
    base_dim = star_rnd() < 0.5,   -- half are dim baseline
  }
end

-- ============================================================
-- Snowflake pre-pass: 60 flakes, fixed X-jitter seed,
-- each gets an independent fall period and sway phase.
-- ============================================================
local flakes = {}
local flake_rnd = make_lcg(31415)
for i = 1, 60 do
  flakes[i] = {
    -- horizontal anchor + sway amplitude
    x_base = flake_rnd() * 240,
    sway_amp = 4 + flake_rnd() * 8,        -- 4-12 px horizontal sway
    sway_period = 3 + flake_rnd() * 4,     -- 3-7s per sway
    sway_phase = flake_rnd() * math.pi * 2,
    -- vertical fall
    fall_period = 7 + flake_rnd() * 6,     -- 7-13s top to bottom
    fall_phase = flake_rnd(),              -- 0..1 starting offset
    size = 1,                              -- 1px single pixel
    dim = flake_rnd() < 0.4,               -- 40% dimmer (depth)
  }
end

-- ============================================================
-- Mid-distance pine pre-pass: 4 trees at fixed X positions
-- Each tree is a tall triangle with a slight asymmetric lean.
-- ============================================================
local mid_pines = {
  { x = 30,  height = 36, width = 14, lean = -1 },
  { x = 95,  height = 44, width = 18, lean =  1 },
  { x = 158, height = 32, width = 12, lean =  0 },
  { x = 215, height = 40, width = 16, lean = -1 },
}

-- ============================================================
-- Foreground pines: 3 trees, larger, darker, with prominent
-- branches. Each is a stack of triangles plus a trunk.
-- ============================================================
local fg_pines = {
  { x = 35,  base_y = 110, height = 60, width = 28 },
  { x = 130, base_y = 116, height = 70, width = 34 },  -- anchor center
  { x = 210, base_y = 112, height = 64, width = 30 },
}

-- ============================================================
-- Drawing helpers
-- ============================================================
local function hline(x, y, w, color)
  for i = 0, w - 1 do
    if x + i >= 0 and x + i < 240 and y >= 0 and y < 136 then
      pix(x + i, y, color)
    end
  end
end

local function vline(x, y, h, color)
  for i = 0, h - 1 do
    if x >= 0 and x < 240 and y + i >= 0 and y + i < 136 then
      pix(x, y + i, color)
    end
  end
end

-- Filled triangle (pointing up), centered at top_x, base at y_base.
local function triangle(cx, top_y, base_y, half_width, color)
  local height = base_y - top_y
  if height <= 0 then return end
  for row = 0, height do
    local frac = row / height
    local hw = math.floor(half_width * frac)
    local y = top_y + row
    if y >= 0 and y < 136 then
      hline(cx - hw, y, hw * 2 + 1, color)
    end
  end
end

-- ============================================================
-- Scene rendering
-- ============================================================
local horizon_y = 78       -- y of horizon line
local ground_top = 79
local moon_x, moon_y = 175, 36
local moon_r = 7

local t = 0

function TIC()
  t = t + 1

  -- 1. Sky gradient (top to horizon)
  for y = 0, horizon_y do
    local frac = y / horizon_y
    local col
    if frac < 0.4 then
      col = C.sky_top
    elseif frac < 0.75 then
      col = C.sky_mid
    else
      col = C.sky_horizon
    end
    hline(0, y, 240, col)
  end

  -- 2. Stars (slow twinkle, only upper sky < 50y)
  for i = 1, 18 do
    local s = stars[i]
    -- opacity approximated by alternating between two palette slots
    local phase = (t / 60) * (math.pi * 2 / s.period) + s.phase
    local bright = (math.sin(phase) + 1) / 2  -- 0..1
    -- half the stars stay dim baseline, the other half twinkle higher
    if s.base_dim then
      bright = 0.2 + bright * 0.3
    else
      bright = 0.4 + bright * 0.5
    end
    if bright > 0.55 then
      pix(s.x, s.y, C.star)
    else
      pix(s.x, s.y, C.star_dim)
    end
  end

  -- 3. Moon (pale disk with soft halo glow)
  -- Halo: a soft outer ring drawn as a filled annulus with sparse
  -- pixels (fewer than 360 to read as a glow, not a solid circle).
  local halo_r_outer = moon_r + 4
  local halo_r_inner = moon_r + 1
  for dy = -halo_r_outer, halo_r_outer do
    for dx = -halo_r_outer, halo_r_outer do
      local d2 = dx * dx + dy * dy
      if d2 >= halo_r_inner * halo_r_inner and d2 <= halo_r_outer * halo_r_outer then
        -- sparse pattern: only ~30% of ring pixels draw, makes it look like a halo
        if (dx + dy * 7) % 5 < 2 then
          local px = moon_x + dx
          local py = moon_y + dy
          if px >= 0 and px < 240 and py >= 0 and py < horizon_y then
            pix(px, py, C.moon_glow)
          end
        end
      end
    end
  end
  -- Inner brighter halo (one ring, full circle, denser)
  for dy = -halo_r_inner, halo_r_inner do
    for dx = -halo_r_inner, halo_r_inner do
      local d2 = dx * dx + dy * dy
      if d2 >= moon_r * moon_r and d2 <= halo_r_inner * halo_r_inner then
        local px = moon_x + dx
        local py = moon_y + dy
        if px >= 0 and px < 240 and py >= 0 and py < horizon_y then
          pix(px, py, C.moon_glow)
        end
      end
    end
  end
  -- Moon disk
  for dy = -moon_r, moon_r do
    for dx = -moon_r, moon_r do
      if dx * dx + dy * dy <= moon_r * moon_r then
        local px = moon_x + dx
        local py = moon_y + dy
        if px >= 0 and px < 240 and py >= 0 and py < horizon_y then
          pix(px, py, C.moon)
        end
      end
    end
  end
  -- Subtle highlight on top-left of moon
  for dy = -2, 0 do
    for dx = -3, -1 do
      if dx * dx + dy * dy <= moon_r * moon_r then
        local px = moon_x + dx
        local py = moon_y + dy
        if px >= 0 and px < 240 and py >= 0 and py < horizon_y then
          pix(px, py, C.star)  -- bright spot
        end
      end
    end
  end

  -- 4. Distant treeline (low silhouette on horizon)
  -- A jagged line of dark purple with a few vertical tree shapes
  hline(0, horizon_y, 240, C.far_treeline)
  -- random small treetops poking up
  local treeline_rnd = make_lcg(2026)
  local tx = 0
  while tx < 240 do
    local h = 2 + math.floor(treeline_rnd() * 4)  -- 2-5 px tall
    local w = 3 + math.floor(treeline_rnd() * 5)   -- 3-7 px wide
    for dy = -h, 0 do
      local hw = math.floor(w * (1 + dy / h) / 2)
      for ddx = -hw, hw do
        local px = tx + w / 2 + ddx
        local py = horizon_y + dy
        if px >= 0 and px < 240 and py >= 0 and py < horizon_y then
          pix(math.floor(px), py, C.far_treeline)
        end
      end
    end
    tx = tx + w + math.floor(treeline_rnd() * 3)
  end

  -- 5. Distant cabin glow (small orange dot, near treeline)
  -- soft halo around it
  for r = 4, 1, -1 do
    local col = (r % 2 == 0) and C.cabin_glow_warm or C.cabin_glow
    for dx = -r, r do
      for dy = -r, r do
        if dx * dx + dy * dy <= r * r then
          local px = 70 + dx
          local py = horizon_y - 1 - r + dy
          if px >= 0 and px < 240 and py >= 0 and py < horizon_y then
            pix(px, py, col)
          end
        end
      end
    end
  end
  -- bright center
  pix(70, horizon_y - 1, C.star)

  -- 6. Mid-distance pines (dark purple, smaller, between trees)
  for _, p in ipairs(mid_pines) do
    -- trunk
    vline(p.x, horizon_y - 4, 6, C.mid_pine)
    -- triangle canopy
    triangle(p.x, horizon_y - p.height, horizon_y - 2, p.width / 2, C.mid_pine)
  end

  -- 7. Snow ground (gradient from light gray near horizon to white)
  for y = ground_top, 135 do
    local frac = (y - ground_top) / (135 - ground_top)
    local col
    if frac < 0.25 then
      col = C.snow_shadow    -- blue-gray snow in distance
    elseif frac < 0.6 then
      col = C.snow_mid
    else
      col = C.snow_fg
    end
    hline(0, y, 240, col)
  end

  -- Subtle texture: occasional darker pixels in the snow (snow shadows,
  -- depth) — sparse, not stripes.
  local snow_rnd = make_lcg(90125)
  for i = 1, 18 do
    local sx = math.floor(snow_rnd() * 240)
    local sy = ground_top + 4 + math.floor(snow_rnd() * 50)
    if sy < 134 then
      pix(sx, sy, C.snow_shadow)
      pix(sx + 1, sy, C.snow_shadow)
    end
  end

  -- 8. Foreground pines (largest, darkest, in front of snow)
  for _, p in ipairs(fg_pines) do
    -- trunk (wider at base)
    for dy = 0, 8 do
      local hw = math.floor(2 + dy / 8)
      hline(p.x - hw, p.base_y + dy, hw * 2 + 1, C.fg_pine)
    end
    -- layered triangles (3 levels for fuller pine)
    local levels = 3
    for level = 0, levels - 1 do
      local ly = p.base_y - math.floor(p.height * (level + 1) / levels)
      local hw = math.floor(p.width / 2 * (1 + level * 0.1))
      triangle(p.x, ly, p.base_y - 4 - level * 2, hw, C.fg_pine)
    end
  end

  -- 9. Snowflakes (drift down with sinusoidal sway)
  for i = 1, 60 do
    local f = flakes[i]
    -- vertical fall: 0..1 across fall_period
    local phase = ((t / 60) / f.fall_period + f.fall_phase) % 1.0
    local y = math.floor(phase * 135)
    -- horizontal sway: sin oscillation
    local sway_phase = (t / 60) * (math.pi * 2 / f.sway_period) + f.sway_phase
    local x_offset = math.floor(math.sin(sway_phase) * f.sway_amp)
    local x = math.floor(f.x_base + x_offset)
    if x >= 0 and x < 240 and y >= 0 and y < 136 then
      -- foreground flakes (lower y) get the bright color, distance flakes get dim
      local col = (y > 80 and not f.dim) and C.flake or C.flake_dim
      pix(x, y, col)
    end
  end

end
