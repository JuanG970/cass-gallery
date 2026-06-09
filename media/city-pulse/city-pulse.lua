-- title: City Pulse
-- author: Cass
-- desc: A midnight skyline that breathes. Parallax stars, drifting rain,
--       occasional shooting stars, and windows in the buildings that
--       flicker on and off. No controls.
-- script: lua

-- ============================================================
-- City Pulse — a breathing midnight skyline for TIC-80
--
-- Layers (back to front):
--   1. Deep gradient sky (purple-magenta)
--   2. Two parallax starfields
--   3. Moon (a soft glowing disc with a crator hint)
--   4. Shooting stars (rare, streak across the sky)
--   5. Rain (drifting streaks)
--   6. City silhouette (pseudorandom skyline with windows)
--   7. Foreground reflection of the sky
--   8. Scanline-ish vignette
-- ============================================================

-- TIC-80 DB16 palette (verified against 1.1.2837):
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
--  10  light blue      #41a6f6
--  11  pale cyan       #73eff7
--  12  white           #f4f4f4
--  13  light gray      #94b0c2
--  14  mid gray        #566c86
--  15  dark slate      #333c57

local C = {
  sky_top   = 1,   -- dark purple (deepest part of the night sky)
  sky_mid   = 15,  -- dark slate (cool midnight band)
  sky_low   = 8,   -- dark blue (horizon glow)
  star_dim  = 11,  -- pale cyan (dim stars)
  star_bright = 12,-- white (bright stars)
  moon      = 4,   -- orange (warm yellow moon)
  moon_glow = 5,   -- yellow-green (soft halo)
  rain      = 11,  -- pale cyan
  bldg_dark = 0,   -- pure black silhouette
  bldg_mid  = 15,  -- dark slate (slightly lifted silhouette for variety)
  win_off   = 0,
  win_warm  = 4,   -- orange (warm room light)
  win_cool  = 11,  -- pale cyan (cold office light)
  win_dim   = 14,  -- mid gray (dim light)
  shoot     = 12,  -- white
  shoot_trail = 4, -- orange
  reflect   = 8,   -- dark blue
}

-- ============================================================
-- Setup — build a deterministic city skyline once.
-- ============================================================

-- Building seed (deterministic)
local BUILDINGS = {}
local SEED = 1337

local function hash(x)
  -- simple 1D hash, returns 0..65535
  x = (x * 1103515245 + 12345) & 0x7fffffff
  return x % 65536
end

local function srand(seed)
  -- tiny LCG so each "frame" of build phase gets a stable value
  local state = seed
  return function()
    state = (state * 1103515245 + 12345) & 0x7fffffff
    return state % 1000 / 1000.0  -- 0..1
  end
end

-- Build 24 building columns, each with a height, width, color, and
-- a pre-baked list of "windows" (x, y, color, on/off schedule).
local rng = srand(SEED)
local COLS = 24
for col = 0, COLS - 1 do
  local w = 6 + math.floor(rng() * 4)         -- 6..9 px wide
  local h = 18 + math.floor(rng() * 50)       -- 18..67 px tall
  local x = math.floor(col * (240 / COLS) + (rng() - 0.5) * 1.5)
  local shade = (rng() > 0.5) and C.bldg_dark or C.bldg_mid
  local bw = {}
  -- windows in a grid, 2px on, 2px off, with a random skip
  for wy = 2, h - 2, 4 do
    for wx = 1, w - 1, 3 do
      if rng() > 0.35 then
        local on_p = rng()                  -- 0..1
        local phase = math.floor(rng() * 600)  -- when in the 600-frame cycle
        local col_choice
        if rng() > 0.7 then col_choice = C.win_warm
        elseif rng() > 0.5 then col_choice = C.win_cool
        else col_choice = C.win_dim end
        bw[#bw + 1] = {wx = wx, wy = wy, p = on_p, phase = phase, col = col_choice}
      end
    end
  end
  BUILDINGS[#BUILDINGS + 1] = {x = x, w = w, h = h, shade = shade, wins = bw}
end

-- Pre-roll the building positions so the visible canvas is covered.
-- The 24 buildings may not span the full 240px width depending on
-- the jitter; add a couple more "spacer" buildings on the edges.
-- (We pre-baked enough variance that the skyline usually fills the
-- width. If not, gaps are fine — they're "sky between buildings".)

-- ============================================================
-- Starfield — two layers, one slow, one fast.
-- ============================================================

local STARS = {}
for i = 1, 60 do
  STARS[#STARS + 1] = {
    x = rng() * 240,
    y = rng() * 90,            -- sky region
    r = 0.4 + rng() * 0.7,     -- twinkle speed
    p = rng() * 6.28,          -- twinkle phase
    c = rng() > 0.7 and C.star_bright or C.star_dim,
  }
end
local STARS_FAR = {}
for i = 1, 35 do
  STARS_FAR[#STARS_FAR + 1] = {
    x = rng() * 240,
    y = rng() * 60,
    r = 0.1 + rng() * 0.2,
    p = rng() * 6.28,
  }
end

-- ============================================================
-- Shooting star scheduler
-- ============================================================

local next_shoot_t = 180   -- first one in 3 seconds
local shoot = nil           -- {x, y, vx, vy, life}

local function spawn_shoot()
  -- start near top, drift down-and-right
  local y = 5 + rng() * 30
  local x = -10 + rng() * 30
  shoot = {x = x, y = y, vx = 3.2 + rng() * 0.6, vy = 0.6 + rng() * 0.2, life = 0}
end

-- ============================================================
-- Drawing helpers
-- ============================================================

-- Vertical sky gradient: top, middle, low (we draw in 3 bands for a
-- clean stepped look on a 16-color palette).
local function draw_sky()
  local TOP_H = 50
  local MID_H = 25
  local LOW_H = 30
  -- Top band: deep purple
  rect(0, 0, 240, TOP_H, C.sky_top)
  -- Middle band: magenta (dusk)
  rect(0, TOP_H, 240, MID_H, C.sky_mid)
  -- Bottom band: indigo (where city will be reflected)
  rect(0, TOP_H + MID_H, 240, LOW_H, C.sky_low)
end

-- Moon — a soft disc with a halo. Single bright disc, then 2 rings
-- of dimmer color. The DB16 palette is limited, so we approximate
-- a glow with 2 concentric rings of C.moon_glow.
local function draw_moon()
  local mx, my = 175, 22
  -- outer halo (2 rings of soft yellow-green)
  circb(mx, my, 9, C.moon_glow)
  circb(mx, my, 7, C.moon_glow)
  -- the disc itself: filled with a 5x5 block of moon color
  for dy = -2, 2 do
    for dx = -2, 2 do
      if math.abs(dx) + math.abs(dy) <= 4 then
        pix(mx + dx, my + dy, C.moon)
      end
    end
  end
  -- a single "crater" hint pixel
  pix(mx - 1, my - 1, C.moon_glow)
end

-- Stars: two parallax layers, twinkling in sine.
local function draw_stars(t)
  for i = 1, #STARS_FAR do
    local s = STARS_FAR[i]
    local a = 0.5 + 0.5 * math.sin(t * s.r + s.p)
    if a > 0.55 then
      pix(s.x, s.y, C.star_dim)
    end
  end
  for i = 1, #STARS do
    local s = STARS[i]
    local a = 0.5 + 0.5 * math.sin(t * s.r + s.p)
    if a > 0.65 then
      pix(s.x, s.y, s.c)
    elseif a > 0.4 then
      pix(s.x, s.y, C.star_dim)
    end
  end
end

-- Shooting star (one at a time). A short trail of decreasing brightness.
local function draw_shoot()
  if not shoot then return end
  shoot.life = shoot.life + 1
  shoot.x = shoot.x + shoot.vx
  shoot.y = shoot.y + shoot.vy
  -- Draw a 6-pixel trail
  for k = 0, 5 do
    local tx = shoot.x - k * shoot.vx * 0.4
    local ty = shoot.y - k * shoot.vy * 0.4
    local c
    if k == 0 then c = C.shoot
    elseif k < 2 then c = C.shoot_trail
    elseif k < 4 then c = C.moon_glow
    else c = C.star_dim end
    pix(tx, ty, c)
  end
  -- End conditions: off-screen, or life too long
  if shoot.x > 250 or shoot.y > 90 or shoot.life > 50 then
    shoot = nil
  end
end

-- Rain: short vertical streaks drifting down. Density tuned for 240x136.
local RAIN = {}
for i = 1, 55 do
  RAIN[#RAIN + 1] = {
    x = rng() * 240,
    y = rng() * 130,
    v = 0.7 + rng() * 1.4,
    len = 1 + math.floor(rng() * 2),
  }
end
local function draw_rain()
  for i = 1, #RAIN do
    local d = RAIN[i]
    d.y = d.y + d.v
    if d.y > 136 then
      d.y = -d.len
      d.x = rng() * 240
    end
    -- short streak
    for k = 0, d.len - 1 do
      pix(d.x, d.y - k, C.rain)
    end
  end
end

-- City silhouette + windows.
local function draw_city(t)
  for i = 1, #BUILDINGS do
    local b = BUILDINGS[i]
    -- city sits at the bottom; top of building = 136 - b.h
    local top = 136 - b.h
    rect(b.x, top, b.w, b.h, b.shade)
    -- windows: each has a deterministic "on" schedule based on frame t
    for j = 1, #b.wins do
      local w = b.wins[j]
      -- light is on for half the cycle, off for the other half,
      -- but the start phase is random per-window
      local phase = (t + w.phase) % 600
      local lit
      if phase < 30 then
        -- a 30-frame "off flicker" every 600 frames
        lit = false
      else
        -- most windows mostly on; some flicker briefly
        lit = (phase % 200) < (180 + math.floor(w.p * 20))
      end
      if lit then
        pix(b.x + w.wx, top + w.wy, w.col)
      end
    end
  end
end

-- Foreground reflection: a dimmer band of the sky color at the very
-- bottom, broken up by a few horizontal "shimmer" lines.
local function draw_reflect(t)
  -- a thin band suggesting wet pavement reflection of the city lights
  rect(0, 136 - 4, 240, 4, C.reflect)
  -- a few faint horizontal shimmer lines
  for k = 0, 2 do
    local y = 134 + k
    local phase = (t * 0.3 + k * 1.7) % 6.28
    for x = 0, 239, 4 do
      if 0.5 + 0.5 * math.sin(phase + x * 0.05) > 0.7 then
        pix(x, y, C.moon_glow)
      end
    end
  end
end

-- ============================================================
-- Main loop
-- ============================================================

local t = 0

function TIC()
  t = t + 1

  draw_sky()
  draw_moon()
  draw_stars(t)
  draw_shoot()
  draw_rain()
  draw_city(t)
  draw_reflect(t)

  -- shooting star scheduler
  next_shoot_t = next_shoot_t - 1
  if next_shoot_t <= 0 and not shoot then
    spawn_shoot()
    next_shoot_t = 220 + math.floor(rng() * 380)  -- 3.6s to 10s
  end

  -- A subtle "pulse" on the sky magenta band, suggesting a deep city hum.
  -- We don't animate the sky color (16-color palette), but we can flicker
  -- a single pixel line at the horizon to add a hint of life.
  if t % 18 == 0 then
    pix(120, 75, C.moon_glow)
  end
end
