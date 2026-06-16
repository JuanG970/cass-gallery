-- title: Lanterns on Still Water
-- author: Cass
-- desc: Paper lanterns floating on a still dark pond at dusk. Each lantern
--       breathes on its own slow timer, drifts on a soft current, and casts
--       a vertical reflection. The water has faint horizontal ripple lines
--       that pass through the reflections. Distant trees silhouette the
--       horizon. No controls, pure loop.
-- script: lua

-- ============================================================
-- Lanterns on Still Water — slow ambient pond scene
--
-- Layers (back to front):
--   1. Sky gradient (deep purple at top, warm band near horizon)
--   2. Stars (sparse, slow twinkle)
--   3. Far tree silhouette on the horizon line
--   4. Water (blue surface, midtone band, deeper purple)
--   5. Distant glow halos above the horizon (off-screen lanterns)
--   6. Lantern reflections (vertical streaks, dimmer than lanterns)
--   7. Ripples (horizontal bands, sparse, on top of reflections)
--   8. Lanterns (paper bag shape, with a slow brightness breath)
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
--   10 light blue      #41a6f6
--   11 pale cyan       #73eff7
--   12 white           #f4f4f4
--   13 light gray      #94b0c2
--   14 mid gray        #566c86
--   15 dark slate      #333c57

local C = {
  sky_top    = 1,   -- dark purple
  sky_mid    = 8,   -- dark blue
  sky_glow   = 9,   -- blue (warm band near horizon)
  star       = 12,  -- white
  star_dim   = 13,  -- light gray
  horizon    = 0,   -- black (treeline)
  water_top  = 9,   -- blue (lit by glow)
  water_mid  = 8,   -- dark blue
  water_deep = 1,   -- dark purple
  water_ripple = 11, -- pale cyan
  glow_far   = 4,   -- orange
  glow_near  = 3,   -- red-orange
  l_body     = 4,   -- orange
  l_body_bright = 12, -- white (hot center)
  l_body_dim = 3,   -- red-orange (base)
  l_top      = 1,   -- dark purple (cap/base)
  l_frame    = 14,  -- mid gray (wire)
  l_reflect  = 2,   -- dark red
  l_reflect_top = 1, -- dark purple
}

-- ============================================================
-- Helper: fill a horizontal span
-- ============================================================
local function hline(x, y, w, color)
  for i = 0, w - 1 do
    pix(x + i, y, color)
  end
end

-- ============================================================
-- Deterministic PRNG so the scene is reproducible
-- ============================================================

local function make_lcg(seed)
  local s = seed or 1337
  return function()
    s = (s * 1103515245 + 12345) % 2147483648
    return s / 2147483648
  end
end

-- ============================================================
-- Star pre-pass: 12 stars in the upper third, fixed positions
-- ============================================================

local stars = {}
local star_rnd = make_lcg(2024)
for i = 1, 12 do
  stars[i] = {
    x = math.floor(star_rnd() * 240),
    y = math.floor(star_rnd() * 50),
    phase = star_rnd() * math.pi * 2,
    period = 4 + star_rnd() * 6,  -- 4-10s
  }
end

-- ============================================================
-- Lantern pre-pass: 8 lanterns, each with its own drift and breath
-- ============================================================

local lanterns = {}
local lan_rnd = make_lcg(7777)
for i = 1, 8 do
  local x = 18 + (i - 1) * 30 + math.floor(lan_rnd() * 6) - 3
  local y_base = 99
  lanterns[i] = {
    x0 = x,
    y_base = y_base,
    x_drift_amp = 1 + lan_rnd() * 2,
    x_drift_period = 7 + lan_rnd() * 6,
    x_drift_phase = lan_rnd() * math.pi * 2,
    y_breath_amp = 1,
    y_breath_period = 3 + lan_rnd() * 2,
    y_breath_phase = lan_rnd() * math.pi * 2,
    bright_phase = lan_rnd() * math.pi * 2,
    bright_period = 4 + lan_rnd() * 4,
    drift_vx = (lan_rnd() - 0.5) * 0.05,
    x_offset = 0,
  }
end

-- ============================================================
-- Off-screen distant glows: 3 dim warm halos that don't have lanterns
-- ============================================================

local glows = {}
for i = 1, 3 do
  glows[i] = {
    x = 30 + i * 70,
    y = 90,
    period = 6 + lan_rnd() * 4,
    phase = lan_rnd() * math.pi * 2,
    amp = 0.4 + lan_rnd() * 0.2,
  }
end

-- ============================================================
-- Ripple line state
-- ============================================================

local ripples = {}
for i = 1, 3 do
  ripples[i] = {
    y = 106 + i * 4,         -- 110, 114, 118
    period = 8 + i * 3,
    phase = i * 1.7,
  }
end

-- ============================================================
-- Drawn primitives
-- ============================================================

local function draw_sky()
  for y = 0, 99 do
    if y < 50 then
      hline(0, y, 240, C.sky_top)
    elseif y < 85 then
      hline(0, y, 240, C.sky_mid)
    else
      hline(0, y, 240, C.sky_glow)
    end
  end
end

local function draw_stars(time)
  for i = 1, #stars do
    local s = stars[i]
    local b = 0.5 + 0.5 * math.sin(time / s.period + s.phase)
    if b > 0.55 then
      if b > 0.85 then
        pix(s.x, s.y, C.star)
      else
        pix(s.x, s.y, C.star_dim)
      end
    end
  end
end

local function draw_treeline()
  local h = 5
  local rising = false
  for x = 0, 239 do
    if rising then
      h = h + 1
      if h >= 8 then rising = false end
    else
      h = h - 1
      if h <= 2 then rising = true end
    end
    if (x % 17) == 0 or (x % 23) == 0 then
      h = 2
    end
    if (x % 31) == 13 then
      h = 9
    end
    if (x % 41) == 27 then
      h = 8
    end
    for dy = 0, h - 1 do
      pix(x, 99 - dy, C.horizon)
    end
  end
end

local function draw_water()
  -- Water occupies y=100 to y=135
  for y = 100, 105 do
    hline(0, y, 240, C.water_top)
  end
  for y = 106, 115 do
    hline(0, y, 240, C.water_mid)
  end
  for y = 116, 135 do
    hline(0, y, 240, C.water_deep)
  end
end

local function draw_glows(time)
  for i = 1, #glows do
    local g = glows[i]
    local b = 0.5 + 0.5 * math.sin(time / g.period + g.phase)
    b = b * g.amp
    if b > 0.15 then
      local r = math.floor(3 + b * 5)
      for dy = -r, r do
        for dx = -r, r do
          if dx*dx + dy*dy <= r*r then
            local px = g.x + dx
            local py = g.y + dy
            if px >= 0 and px < 240 and py >= 80 and py <= 99 then
              local d2 = dx*dx + dy*dy
              if d2 < (r/2)*(r/2) then
                pix(px, py, C.glow_near)
              else
                pix(px, py, C.glow_far)
              end
            end
          end
        end
      end
    end
  end
end

local function draw_lantern_reflection(lan)
  local x = math.floor(lan.x0 + lan.x_offset)
  local y_water = 101
  for dy = 0, 5 do
    local fade = 1 - (dy / 6)
    if dy % 2 == 0 then
      if fade > 0.5 then
        hline(x - 2, y_water + dy, 5, C.l_reflect)
      elseif fade > 0.2 then
        hline(x - 1, y_water + dy, 3, C.l_reflect)
      else
        pix(x, y_water + dy, C.l_reflect_top)
      end
    end
  end
end

local function draw_lantern(lan, time)
  local x = math.floor(lan.x0 + lan.x_offset)
  local breath = math.sin(time / lan.y_breath_period + lan.y_breath_phase)
  local y_base = lan.y_base + breath * lan.y_breath_amp * 0.3
  local y_top_int = math.floor(y_base - 7)

  -- Wire handle: small cross above the cap
  pix(x, y_top_int - 2, C.l_frame)
  pix(x - 1, y_top_int - 2, C.l_frame)
  pix(x + 1, y_top_int - 2, C.l_frame)
  pix(x, y_top_int - 1, C.l_frame)

  -- top cap (3 wide)
  hline(x - 1, y_top_int, 3, C.l_top)

  -- body shoulder (5 wide)
  hline(x - 2, y_top_int + 1, 5, C.l_body)

  -- body main (4 rows of 7 wide)
  for dy = 2, 5 do
    hline(x - 3, y_top_int + dy, 7, C.l_body)
  end

  -- bottom shoulder (5 wide, dim color)
  hline(x - 2, y_top_int + 6, 5, C.l_body_dim)

  -- base (3 wide)
  hline(x - 1, y_top_int + 7, 3, C.l_top)

  -- Brightness breath overlay: brighten the body's hot center
  local bright = 0.5 + 0.5 * math.sin(time / lan.bright_period + lan.bright_phase)
  if bright > 0.4 then
    pix(x, y_top_int + 3, C.l_body_bright)
    pix(x - 1, y_top_int + 3, C.l_body_bright)
    pix(x + 1, y_top_int + 3, C.l_body_bright)
    pix(x, y_top_int + 4, C.l_body_bright)
  end
end

local function draw_ripples(time)
  for i = 1, #ripples do
    local r = ripples[i]
    local pulse = 0.5 + 0.5 * math.sin(time / r.period + r.phase)
    if pulse > 0.75 then
      local y = r.y
      if y >= 100 and y <= 135 then
        for x = 0, 239 do
          if (x + i * 3) % 5 == 0 then
            pix(x, y, C.water_ripple)
          end
        end
      end
    end
  end
end

-- ============================================================
-- Main loop
-- ============================================================

local t_frame = 0

function TIC()
  t_frame = t_frame + 1
  local t = t_frame / 60
  cls(C.sky_top)

  draw_sky()
  draw_stars(t)
  draw_treeline()
  draw_water()
  draw_glows(t)

  -- update lantern positions
  for i = 1, #lanterns do
    local lan = lanterns[i]
    local drift = math.sin(t / lan.x_drift_period + lan.x_drift_phase) * lan.x_drift_amp
    lan.x_offset = drift + lan.drift_vx * (t * 60)
    if lan.x_offset + lan.x0 > 250 then
      lan.x_offset = lan.x_offset - 300
    elseif lan.x_offset + lan.x0 < -10 then
      lan.x_offset = lan.x_offset + 300
    end
  end

  -- draw reflections (on the water, behind ripples)
  for i = 1, #lanterns do
    draw_lantern_reflection(lanterns[i])
  end

  -- ripples go on top of reflections to break them up
  draw_ripples(t)

  -- draw the lanterns on the waterline (in front of the glows and water)
  for i = 1, #lanterns do
    draw_lantern(lanterns[i], t)
  end
end
