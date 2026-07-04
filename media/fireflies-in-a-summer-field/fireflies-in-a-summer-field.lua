-- title: Fireflies in a Summer Field
-- author: Cass
-- desc: A summer twilight meadow. A warm orange-pink horizon fades up to
--       deep indigo. A low distant treeline. A foreground of soft grass.
--       Twelve fireflies drift and twinkle on independent slow timers.
--       Pure ambience, no controls.
-- script: lua

-- ============================================================
-- Fireflies in a Summer Field — slow twilight ambient
--
-- Layers (back to front):
--   1. Sky gradient (indigo at top, warm orange at horizon, 4 bands)
--   2. Stars (8 dim stars in upper sky, mostly static)
--   3. Distant treeline (low silhouette, mid-tone)
--   4. Foreground grass (3 clusters of tall vertical strokes)
--   5. Fireflies (12 points, drift on slow lissajous paths,
--      fade in/out on independent 10-25s periods)
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
  sky_top     = 1,  -- dark purple (zenith)
  sky_high    = 8,  -- dark blue (high sky)
  sky_mid     = 2,  -- dark red (mid sky, the warm wash starting)
  sky_low     = 3,  -- red-orange (low sky, intense)
  sky_horizon = 4,  -- orange (the warm band right at horizon)
  star        = 13, -- light gray (dim stars)
  star_bright = 12, -- white (one or two brighter stars)
  treeline    = 0,  -- black (distant treeline silhouette)
  treeline_hi = 14, -- mid gray (top edge of treeline highlights)
  grass_dark  = 0,  -- black (foreground grass)
  grass_mid   = 14, -- mid gray (grass mid)
  grass_far   = 15, -- dark slate (far grass shadow)
  ground      = 15, -- dark slate (ground/foreground base)
  firefly     = 4,  -- orange (the firefly body when lit)
  firefly_dim = 3,  -- red-orange (faint firefly glow halo)
  firefly_bright = 12, -- white (peak brightness pulse)
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
-- Star pre-pass: 8 stars in the upper sky (y < 50)
-- Mostly static, slow individual twinkle.
-- ============================================================
local stars = {}
local star_rnd = make_lcg(2025)
for i = 1, 8 do
  stars[i] = {
    x = math.floor(star_rnd() * 240),
    y = math.floor(star_rnd() * 50),
    bright = star_rnd() < 0.20,  -- ~20% are brighter
    tw_phase = star_rnd() * 6.28,
    tw_period = 45 + star_rnd() * 60,  -- 45-105s slow twinkle
  }
end

-- ============================================================
-- Distant treeline pre-pass: low silhouette of a tree line.
-- A series of triangular peaks at varying heights across y=68-78.
-- ============================================================
local treeline = {}
local tl_rnd = make_lcg(7777)
local tl_x = 0
while tl_x < 240 do
  local peak_h = 7 + math.floor(tl_rnd() * 5)  -- 7-11 px (taller, more visible)
  local peak_w = 4 + math.floor(tl_rnd() * 5)  -- 4-8 px wide (tighter, denser)
  treeline[#treeline + 1] = { x = tl_x, w = peak_w, h = peak_h }
  tl_x = tl_x + peak_w  -- no overlap; tighter packing
end
-- A second back-row of peaks slightly TALLER, behind the first.
-- This is the classic "distant hills higher than foreground hills" trick:
-- back row extends above the front row's peaks in the gaps.
local treeline2 = {}
local tl2_rnd = make_lcg(8888)
local tl2_x = 0
while tl2_x < 240 do
  local peak_h = 9 + math.floor(tl2_rnd() * 5)  -- 9-13 px (taller than front row)
  local peak_w = 7 + math.floor(tl2_rnd() * 8)  -- 7-14 px
  treeline2[#treeline2 + 1] = { x = tl2_x, w = peak_w, h = peak_h }
  tl2_x = tl2_x + peak_w + 2
end

-- ============================================================
-- Foreground grass pre-pass: 3 clusters of tall vertical
-- strokes at the bottom of the screen.
-- ============================================================
local grass_clusters = {
  { x = 6,   count = 18, base_h = 26, spread = 28 },
  { x = 88,  count = 10, base_h = 20, spread = 16 },
  { x = 178, count = 20, base_h = 28, spread = 30 },
}
local grass = {}
local gr_rnd = make_lcg(9090)
for _, cl in ipairs(grass_clusters) do
  for j = 1, cl.count do
    local dx = math.floor((gr_rnd() - 0.5) * cl.spread)
    local dh = math.floor((gr_rnd() - 0.5) * 10)
    grass[#grass + 1] = {
      x = cl.x + dx,
      h = cl.base_h + dh,
    }
  end
end

-- Background distant grass — a band of short vertical strokes
-- right at the treeline to soften the horizon transition.
local bg_grass = {}
local bg_rnd = make_lcg(8181)
for i = 1, 80 do
  bg_grass[i] = {
    x = math.floor(bg_rnd() * 240),
    h = 1 + math.floor(bg_rnd() * 3),  -- 1-3 px
  }
end

-- ============================================================
-- Firefly pre-pass: 12 fireflies, each with a drift path
-- (lissajous), an independent twinkle period, and a
-- base position. They drift on slow circular paths and
-- pulse on/off. To keep the gif compressible AND the
-- fireflies readable at any frame, periods are 10-25s
-- and each firefly has both a "dim" body and a bright peak.
-- ============================================================
local fireflies = {}
local ff_rnd = make_lcg(4242)
for i = 1, 12 do
  fireflies[i] = {
    -- base position in the middle of the screen
    bx = 20 + math.floor(ff_rnd() * 200),
    by = 80 + math.floor(ff_rnd() * 48),  -- y=80-128 (mid-canvas, above grass)
    -- drift path
    amp_x = 4 + math.floor(ff_rnd() * 6),  -- 4-9 px horizontal drift
    amp_y = 2 + math.floor(ff_rnd() * 3),  -- 2-4 px vertical drift
    freq_x = 0.05 + ff_rnd() * 0.08,       -- slow lissajous
    freq_y = 0.06 + ff_rnd() * 0.10,
    phase_x = ff_rnd() * 6.28,
    phase_y = ff_rnd() * 6.28,
    -- twinkle
    tw_period = 10 + ff_rnd() * 15,        -- 10-25s twinkle
    tw_phase = ff_rnd() * 6.28,
  }
end

-- ============================================================
-- Init: nothing more to do at boot.
-- ============================================================
function TIC()
  local t = time() / 60.0  -- seconds since boot (time() returns 60fps ticks)

  -- 1. Sky gradient: 4 bands, each a horizontal stripe
  -- TIC-80 screen is 240x136. Sky covers y=0..70 (above the treeline).
  rect(0, 0, 240, 16, C.sky_top)      -- y=0-15
  rect(0, 16, 240, 18, C.sky_high)    -- y=16-33
  rect(0, 34, 240, 18, C.sky_mid)     -- y=34-51
  rect(0, 52, 240, 18, C.sky_low)     -- y=52-69
  -- bright horizon band right at the treeline
  rect(0, 68, 240, 2, C.sky_horizon)

  -- 2. Stars: a few in the upper sky, mostly static with slow twinkle
  for _, s in ipairs(stars) do
    local tw = 0.5 + 0.5 * (math.sin(t * 2 * math.pi / s.tw_period + s.tw_phase) + 1) * 0.5
    local col = s.bright and C.star_bright or C.star
    if tw > 0.3 then
      pix(s.x, s.y, col)
    end
  end

  -- 3. Distant treeline: two layers for depth.
  -- Back row: slightly shorter, mid-tone.
  for _, p in ipairs(treeline2) do
    local base_y = 78
    for k = 0, p.h - 1 do
      local half_w = math.floor(p.w / 2) - math.floor(k / 2)
      for dx = -half_w, half_w do
        local px = p.x + math.floor(p.w / 2) + dx
        if px >= 0 and px < 240 then
          pix(px, base_y - k, C.treeline_hi)
        end
      end
    end
  end
  -- Front row: taller, black silhouette.
  for _, p in ipairs(treeline) do
    local base_y = 78
    for k = 0, p.h - 1 do
      local half_w = math.floor(p.w / 2) - math.floor(k / 2)
      for dx = -half_w, half_w do
        local px = p.x + math.floor(p.w / 2) + dx
        if px >= 0 and px < 240 then
          pix(px, base_y - k, C.treeline)
        end
      end
    end
  end

  -- 4. Foreground ground: solid dark band y=78..136
  rect(0, 78, 240, 58, C.ground)

  -- 5. Background distant grass: short strokes right at the horizon
  for _, bg in ipairs(bg_grass) do
    for k = 0, bg.h - 1 do
      pix(bg.x, 78 + k, C.grass_far)
    end
  end

  -- 6. Foreground grass: tall vertical strokes, black with gray tips
  for _, g in ipairs(grass) do
    for k = 0, g.h - 1 do
      local py = 136 - k - 1
      if py >= 78 then
        pix(g.x, py, C.grass_dark)
      end
    end
    if g.h >= 22 then
      pix(g.x, 136 - g.h, C.grass_mid)
    end
  end

  -- 7. Fireflies: 12 points, drift + slow twinkle
  for _, f in ipairs(fireflies) do
    local dx = math.sin(t * 2 * math.pi * f.freq_x + f.phase_x) * f.amp_x
    local dy = math.cos(t * 2 * math.pi * f.freq_y + f.phase_y) * f.amp_y
    local px = math.floor(f.bx + dx)
    local py = math.floor(f.by + dy)
    -- twinkle: a 0-1 brightness value, peaks are bright, valleys are dim
    local raw = math.sin(t * 2 * math.pi / f.tw_period + f.tw_phase)
    local bri = (raw + 1) / 2  -- 0..1

    -- Always render the body, but vary the brightness via color.
    -- bri < 0.30: use firefly_dim (faint orange, still visible)
    -- 0.30..0.65: use firefly (orange)
    -- 0.65..0.90: use firefly_bright (white)
    -- > 0.90: full glow (white body + orange halo + diagonal)
    local body_col = C.firefly_dim
    if bri > 0.65 then body_col = C.firefly_bright
    elseif bri > 0.30 then body_col = C.firefly end
    pix(px, py, body_col)

    -- soft glow halo: 4 cardinal pixels at orange — visible when bri > 0.45
    if bri > 0.45 then
      if px > 0 then pix(px - 1, py, C.firefly) end
      if px < 239 then pix(px + 1, py, C.firefly) end
      if py > 0 then pix(px, py - 1, C.firefly) end
      if py < 135 then pix(px, py + 1, C.firefly) end
    end

    -- Diagonal glow on bright pulse only
    if bri > 0.80 then
      if px > 0 and py > 0 then pix(px - 1, py - 1, C.firefly_dim) end
      if px < 239 and py > 0 then pix(px + 1, py - 1, C.firefly_dim) end
      if px > 0 and py < 135 then pix(px - 1, py + 1, C.firefly_dim) end
      if px < 239 and py < 135 then pix(px + 1, py + 1, C.firefly_dim) end
    end
  end
end
