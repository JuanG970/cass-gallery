-- title: Bioluminescent Tide
-- author: Cass
-- desc: A deep-sea scene with slow drifting plankton, a breathing jellyfish,
--       and a faint caustic light from above. Cool palette, no controls.
-- script: lua

-- ============================================================
-- Bioluminescent Tide — slow-drifting deep ocean ambience
--
-- Layers (back to front):
--   1. Vertical depth gradient (deep navy at the bottom, mid-blue up top)
--   2. Caustic light shafts from the surface (faint vertical bands that
--      pulse and drift sideways)
--   3. Far plankton (very dim, slow drift, sparse)
--   4. Jellyfish (one, breathing — body pulses with a slow sin wave)
--   5. Near plankton (brighter, faster, denser)
--   6. Bottom silhouette (kelp / rocks hint)
--   7. Subtle vignette
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
  depth_deep   = 0,   -- black, the abyss at the bottom
  depth_mid    = 15,  -- dark slate, the midwater
  depth_top    = 8,   -- dark blue, the shallows (where light enters)
  caustic      = 7,   -- dark teal, faint shafts from above
  caustic_warm = 10,  -- light blue, brighter shafts
  j_body       = 11,  -- pale cyan, jellyfish translucent body
  j_core       = 12,  -- white, the bright center
  j_rim        = 9,   -- blue, the rim of the bell
  j_tent       = 11,  -- pale cyan, tentacles
  plank_dim    = 7,   -- dark teal, distant plankton
  plank_bright = 11,  -- pale cyan, near plankton
  plank_warm   = 5,   -- yellow-green, occasional warm plankton
  bottom       = 0,   -- black, the seabed silhouette
  bottom_mid   = 15,  -- dark slate, lifted
  kelp         = 7,   -- dark teal
}

-- ============================================================
-- Deterministic PRNG so the scene is reproducible
-- ============================================================

local SEED = 4242
local function srand(seed)
  local state = seed
  return function()
    state = (state * 1103515245 + 12345) & 0x7fffffff
    return state % 1000 / 1000.0
  end
end
local rng = srand(SEED)

-- ============================================================
-- Depth gradient — drawn as 3 horizontal bands
-- ============================================================

local function draw_depth()
  -- bottom: deep abyss
  rect(0, 0,   240, 50,  C.depth_deep)
  -- middle
  rect(0, 50,  240, 40,  C.depth_mid)
  -- top: where light enters
  rect(0, 90,  240, 46,  C.depth_top)
end

-- ============================================================
-- Caustics — vertical light shafts from the surface
--
-- Implementation note: TIC-80 has no per-pixel transparency, so we
-- approximate caustics with a sparse pattern of dim vertical pixels
-- whose intensity pulses with a slow sin wave per band. Looks like
-- rippling water above.
-- ============================================================

local CAUSTICS = {}
for i = 1, 8 do
  CAUSTICS[#CAUSTICS + 1] = {
    x = 5 + rng() * 230,
    w = 4 + math.floor(rng() * 6),     -- 4..9 px wide band
    drift = (rng() - 0.5) * 0.15,      -- horizontal drift speed
    phase = rng() * 6.28,              -- pulse phase
    speed = 0.005 + rng() * 0.01,
  }
end

local function draw_caustics(t)
  for i = 1, #CAUSTICS do
    local c = CAUSTICS[i]
    -- shift the band over time (slowly)
    local x_off = math.sin(t * c.drift) * 4
    local x0 = c.x + x_off
    local pulse = 0.5 + 0.5 * math.sin(t * c.speed + c.phase)
    -- a band of vertical pixels from the top to mid-depth
    for y = 0, 50 do
      -- intensity falls off with depth and with horizontal distance from band center
      local dx = 0
      -- banding: only paint every other column
      for dx_local = 0, c.w - 1 do
        local px = x0 + dx_local
        if px >= 0 and px < 240 then
          -- pulse modulates brightness; only some columns light up
          local col_pulse = 0.5 + 0.5 * math.sin(t * c.speed * 0.7 + dx_local * 1.3 + c.phase)
          if col_pulse > 0.5 then
            local depth_falloff = 1 - (y / 50)   -- 1 at top, 0 at mid
            if col_pulse * depth_falloff * pulse > 0.55 then
              -- pick the brighter caustic color for stronger pulses
              if pulse * col_pulse > 0.75 and y < 20 then
                pix(px, y, C.caustic_warm)
              else
                pix(px, y, C.caustic)
              end
            end
          end
        end
      end
      dx = dx + 1
    end
  end
end

-- ============================================================
-- Plankton — two layers. Far is dim and slow; near is bright and faster.
-- Each particle has a "twinkle" phase that controls when it lights.
-- ============================================================

local PLANK_FAR = {}
for i = 1, 45 do
  PLANK_FAR[#PLANK_FAR + 1] = {
    x = rng() * 240,
    y = 30 + rng() * 90,    -- mid-to-bottom
    vx = (rng() - 0.5) * 0.18,  -- mostly horizontal drift
    vy = (rng() - 0.5) * 0.05,  -- tiny vertical wobble
    p = rng() * 6.28,
    spd = 0.04 + rng() * 0.05,
  }
end

local PLANK_NEAR = {}
for i = 1, 25 do
  PLANK_NEAR[#PLANK_NEAR + 1] = {
    x = rng() * 240,
    y = 20 + rng() * 100,
    vx = (rng() - 0.5) * 0.35,
    vy = (rng() - 0.5) * 0.12,
    p = rng() * 6.28,
    spd = 0.08 + rng() * 0.08,
    warm = rng() > 0.85,    -- a few warm-toned particles
  }
end

local function draw_plankton(t)
  -- far layer: very subtle, only paints a few at a time
  for i = 1, #PLANK_FAR do
    local p = PLANK_FAR[i]
    -- drift
    p.x = p.x + p.vx
    p.y = p.y + p.vy
    if p.x < 0 then p.x = p.x + 240 elseif p.x > 240 then p.x = p.x - 240 end
    if p.y < 0 then p.y = p.y + 136 elseif p.y > 136 then p.y = p.y - 136 end
    -- twinkle: a short pulse window per cycle
    local s = 0.5 + 0.5 * math.sin(t * p.spd + p.p)
    if s > 0.85 then
      pix(p.x, p.y, C.plank_dim)
    end
  end

  -- near layer: brighter, with two intensity levels
  for i = 1, #PLANK_NEAR do
    local p = PLANK_NEAR[i]
    p.x = p.x + p.vx
    p.y = p.y + p.vy
    if p.x < 0 then p.x = p.x + 240 elseif p.x > 240 then p.x = p.x - 240 end
    if p.y < 0 then p.y = p.y + 136 elseif p.y > 136 then p.y = p.y - 136 end
    local s = 0.5 + 0.5 * math.sin(t * p.spd + p.p)
    if s > 0.7 then
      if p.warm and s > 0.9 then
        pix(p.x, p.y, C.plank_warm)
      else
        pix(p.x, p.y, C.plank_bright)
      end
    end
  end
end

-- ============================================================
-- Jellyfish — one, breathing.
--
-- A small bell + 3 trailing tentacles. The bell scales in/out with
-- a slow sin wave (the "breath"), the tentacles are a few pixels
-- each, also pulsing.
-- ============================================================

local JELLY = {
  x = 120,
  y = 68,
  breath_phase = 0,
  drift_phase = 0,
  -- tentacles are 3 trails of pixels, each a length of 5-8
  tent_offsets = {},
}
for i = 1, 3 do
  JELLY.tent_offsets[i] = {
    dx = (i - 2) * 2,    -- -2, 0, 2
    len = 5 + i,
    sway_phase = i * 1.7,
  }
end

local function draw_jelly(t)
  -- gentle horizontal drift
  local drift = math.sin(t * 0.0035) * 18
  JELLY.x = 120 + drift

  -- breath: a slow in-out cycle. r goes 6..9 over ~3.5s
  local breath = 0.5 + 0.5 * math.sin(t * 0.018)
  local bell_r = 6 + math.floor(breath * 3)   -- 6..9

  local jx = math.floor(JELLY.x)
  local jy = JELLY.y

  -- Tentacles: a vertical line of pixels below the bell, swaying sideways.
  -- Draw 3 tentacles with slight horizontal offsets that wave in different phases.
  for ti = 1, #JELLY.tent_offsets do
    local to = JELLY.tent_offsets[ti]
    for k = 1, to.len do
      -- each segment sways with its own phase
      local sway = math.sin(t * 0.05 + to.sway_phase + k * 0.4) * 1.2
      local tx = jx + to.dx + math.floor(sway)
      local ty = jy + bell_r + k - 1
      -- tip tentacles fade with k
      if k < to.len - 1 then
        pix(tx, ty, C.j_tent)
      end
    end
  end

  -- Bell: a filled disc with a brighter core and a dimmer rim.
  -- We use circ() for the rim, then a small bright cluster in the center.
  -- Because the bell is 6-9 px radius, we draw with a few concentric rings.
  -- r=bell_r: outer rim (blue)
  circb(jx, jy, bell_r, C.j_rim)
  -- r=bell_r-1: a translucent-ish band (pale cyan)
  if bell_r > 6 then
    circb(jx, jy, bell_r - 1, C.j_body)
  end
  -- center: a 2x2 white core
  pix(jx,     jy,     C.j_core)
  pix(jx + 1, jy,     C.j_core)
  pix(jx,     jy + 1, C.j_core)
  pix(jx + 1, jy + 1, C.j_core)

  -- a few "spike" pixels on the top of the bell (the curve highlight)
  for dx = -2, 2 do
    local dy = -math.floor(math.sqrt(math.max(0, (bell_r - 1)^2 - dx*dx)))
    pix(jx + dx, jy + dy, C.j_body)
  end
end

-- ============================================================
-- Bottom silhouette — a soft kelp/rock shape
-- ============================================================

local BOTTOM = {}
for x = 0, 239 do
  -- silhouette height varies: a few "rocks" and "kelp stalks"
  BOTTOM[x + 1] = 4 + math.floor(math.sin(x * 0.07) * 2 + math.sin(x * 0.21) * 1.5)
end
-- add a couple of taller kelp stalks at deterministic x positions
local kelp_xs = {22, 60, 95, 142, 188}
for i = 1, #kelp_xs do
  local x = kelp_xs[i]
  BOTTOM[x + 1] = 12 + (i % 3) * 2
end

local function draw_bottom()
  for x = 0, 239 do
    local h = BOTTOM[x + 1]
    -- draw a vertical column of bottom color from (136-h) to 136
    rect(x, 136 - h, 1, h, C.bottom)
  end
  -- kelp tips: a slightly lighter line at the top of each kelp stalk
  for i = 1, #kelp_xs do
    local x = kelp_xs[i]
    local h = BOTTOM[x + 1]
    pix(x, 136 - h, C.bottom_mid)
  end
end

-- ============================================================
-- Vignette — a few dim pixels in the corners, like a camera lens
-- ============================================================

local function draw_vignette()
  -- top corners: a few dark pixels
  for i = 0, 14 do
    pix(i, 0, C.depth_deep)
    pix(i, 1, C.depth_deep)
    pix(239 - i, 0, C.depth_deep)
    pix(239 - i, 1, C.depth_deep)
  end
end

-- ============================================================
-- Main loop
-- ============================================================

local t = 0

function TIC()
  t = t + 1

  draw_depth()
  draw_caustics(t)
  draw_plankton(t)
  draw_jelly(t)
  draw_bottom()
  draw_vignette()
end
