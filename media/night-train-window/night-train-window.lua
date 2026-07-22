-- title: Night Train Window
-- author: Cass
-- desc: A dark train cabin interior at night. A single large window
--       fills the right two-thirds of the cart; outside the glass,
--       distant station lights and signal lamps streak past as long
--       horizontal segments on a black field. A small warm seat-back
--       reading lamp glows on the left, with a single round halo.
--       The streaks are the only thing that moves: they scroll
--       leftward at three depths (near, mid, far) on independent
--       speeds. The interior is still. Pure ambience, no controls.
-- script: lua

-- ============================================================
-- Night Train Window — slow horizontal motion
--
-- Composition (back to front):
--   1. Wall: solid deep midnight (the cabin interior).
--   2. Window pane: black inside the frame (the world seen at night).
--   3. Light streaks: three parallax layers of horizontal
--      bright segments scrolling leftward. Near layer: long,
--      warm, fast. Mid: medium, mixed, slower. Far: short, cool,
--      slowest. The streaks are deterministic at boot (an LCG
--      seeds the spawn positions) so the cart looks the same on
--      every run.
--   4. Distant signal lights: a few small bright dots that flash
--      on a slow period, never moving.
--   5. Window mullion: a thin vertical divider on the glass.
--   6. Window frame: dark slate border around the pane.
--   7. Seat-back reading lamp: a single small warm dot at left,
--      with a soft warm halo extending onto the wall and slightly
--      onto the lower-left of the window glass.
--   8. Reflection: a very faint warm stripe across the lower
--      third of the window (the lamp's reflection in the glass).
--   9. Passenger silhouette: a soft dark dome at the very
--      bottom-left edge of the cart (a head/shoulder just barely
--      in frame), anchoring the "we are inside, looking out."
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
  wall           = 0,  -- black (the cabin interior)
  wall_dark      = 1,  -- dark purple (subtle wall gradient)
  frame          = 15, -- dark slate (window frame)
  frame_edge     = 14, -- mid gray (frame highlight)
  pane           = 1,  -- dark purple (the dark night sky behind glass)
  pane_deep      = 0,  -- black (the deepest sky)
  mullion        = 15, -- dark slate (vertical divider)

  -- Light streak layers (parallax: near / mid / far)
  streak_near_bright = 4,  -- orange (close warm streetlamps)
  streak_near_dim    = 3,  -- red-orange (close warm tails)
  streak_mid_bright  = 12, -- white (mid-distance station lights)
  streak_mid_dim     = 13, -- light gray (mid-distance tails)
  streak_far_bright  = 10, -- light blue (distant signal lamps)
  streak_far_dim     = 8,  -- dark blue (distant tails)

  -- Signal lights
  signal_warm  = 4,  -- orange (a slow-flashing warm signal)
  signal_cool  = 10, -- light blue (a slow-flashing cool signal)

  -- Reading lamp
  lamp_tip     = 12, -- white (the hottest pixel at the lamp center)
  lamp_bright  = 4,  -- orange (the lamp body)
  lamp_dim     = 3,  -- red-orange (the lamp's outer ring)
  lamp_halo    = 2,  -- dark red (the soft halo)
  lamp_halo_far = 8, -- dark blue (the faintest halo)

  -- Reflection
  reflection   = 3,  -- red-orange (the lamp's faint reflection on glass)
  reflection_dim = 1, -- dark purple (the dimmest reflection line)

  -- Passenger silhouette
  silhouette   = 15, -- dark slate (the head/shoulder in foreground)
  silhouette_edge = 14, -- mid gray (a subtle highlight on the dome)
}

-- ============================================================
-- Cart helper: 5-arg pix(x,y,w,h,color) is broken in 1.1.2837.
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

-- LCG PRNG.
local function lcg(seed)
  local s = seed
  return function()
    s = (s * 1103515245 + 12345) % 2147483648
    return s / 2147483648
  end
end

-- ============================================================
-- Streak layers. Each layer has N streaks. A streak has a fixed
-- y, a fixed length, and an x that advances leftward per frame
-- on a per-layer speed. When a streak's right edge has crossed
-- the left edge of the pane, it wraps to the right edge with
-- a fresh random y, length, and brightness.
-- ============================================================
local function make_layer(seed, count, pane_x0, pane_x1, pane_y0, pane_y1,
                          speed, len_min, len_max, bright_col, dim_col,
                          weight_bright)
  local r = lcg(seed)
  local pane_w = pane_x1 - pane_x0
  local pane_h = pane_y1 - pane_y0
  local streaks = {}
  for i = 1, count do
    local len = len_min + r() * (len_max - len_min)
    streaks[i] = {
      x = pane_x0 + r() * pane_w,
      y = pane_y0 + r() * pane_h,
      len = len,
      bright = r() < weight_bright,
    }
  end
  return {
    streaks = streaks,
    speed = speed,
    pane_x0 = pane_x0,
    pane_x1 = pane_x1,
    pane_y0 = pane_y0,
    pane_y1 = pane_y1,
    bright_col = bright_col,
    dim_col = dim_col,
    r = r,
  }
end

local function update_layer(L)
  for i, s in ipairs(L.streaks) do
    s.x = s.x - L.speed
    -- Wrap: when the right edge of the streak has moved past the
    -- left edge of the pane, respawn at the right edge.
    if s.x + s.len < L.pane_x0 then
      s.x = L.pane_x1 + L.r() * 20
      s.y = L.pane_y0 + L.r() * (L.pane_y1 - L.pane_y0)
      s.len = 8 + L.r() * 28
      s.bright = L.r() < 0.3
    end
  end
end

local function paint_layer(L)
  local MULLION = 146  -- vertical divider (inlined; the constant
                       -- isn't yet defined when this closure is
                       -- created, so the upvalue lookup fails
                       -- if we reference the local directly).
  for _, s in ipairs(L.streaks) do
    if s.x >= L.pane_x0 and s.x < L.pane_x1 then
      -- The streak is mostly to the right of the left edge of the
      -- pane, so draw the visible portion.
      local x0 = math.floor(s.x)
      local x1 = math.min(L.pane_x1, math.floor(s.x + s.len))
      if x1 > x0 then
        -- Streaks must NOT cross the mullion. The mullion is a
        -- single column at MULLION. If a streak would cross it,
        -- split the streak into two halves (left half, right half)
        -- with the same color and brightness.
        local col = s.bright and L.bright_col or L.dim_col
        if x0 < MULLION and x1 > MULLION + 1 then
          -- Left half: from x0 up to MULLION.
          hline(x0, math.floor(s.y), MULLION - x0, col)
          -- Right half: from MULLION + 1 to x1.
          hline(MULLION + 1, math.floor(s.y), x1 - MULLION - 1, col)
        else
          hline(x0, math.floor(s.y), x1 - x0, col)
        end
      end
    end
  end
end

-- ============================================================
-- Window geometry. The pane is the inside-the-frame area where
-- the world is visible. The frame is a thin border around the
-- pane, with a single vertical mullion splitting the pane.
-- Defined here so the layer functions can reference MULLION_X
-- as an upvalue (must be defined before any closure that
-- captures it).
-- ============================================================
local PANE_X0 = 60
local PANE_X1 = 232
local PANE_Y0 = 18
local PANE_Y1 = 116
local FRAME_W = 3
local MULLION_X = 146  -- vertical divider
local LAMP_X = 24
local LAMP_Y = 84

-- Layer instances.
local layer_near = make_layer(101, 7, PANE_X0, PANE_X1, PANE_Y0 + 6, PANE_Y1 - 6,
                              1.6, 14, 32, C.streak_near_bright, C.streak_near_dim, 0.4)
local layer_mid  = make_layer(202, 9, PANE_X0, PANE_X1, PANE_Y0 + 4, PANE_Y1 - 4,
                              0.8, 8, 22, C.streak_mid_bright, C.streak_mid_dim, 0.5)
local layer_far  = make_layer(303, 11, PANE_X0, PANE_X1, PANE_Y0 + 2, PANE_Y1 - 2,
                              0.35, 4, 12, C.streak_far_bright, C.streak_far_dim, 0.5)

-- ============================================================
-- Static signal lights. Two slow-flashing dots in the pane.
-- ============================================================
local function paint_signals(t)
  -- Warm signal: 4-second period, mostly on.
  local warm_phase = (t % 4.0) / 4.0
  if warm_phase < 0.85 then
    pix(98, 32, C.signal_warm)
    pix(99, 32, C.signal_warm)
  end
  -- Cool signal: 6-second period, brief flash.
  local cool_phase = (t % 6.0) / 6.0
  if cool_phase < 0.15 then
    pix(178, 48, C.signal_cool)
    pix(178, 49, C.signal_cool)
    pix(179, 48, C.signal_cool)
  end
end

-- ============================================================
-- Reading lamp: a clear warm shape (5-px white core + orange
-- body) at left, with a soft warm halo. The lamp is the only
-- warm light in the cabin, and it has to read at gallery-card
-- size, so the core is intentionally chunky, not a single dot.
-- ============================================================
local function paint_lamp(t)
  -- Subtle flicker on a slow noise.
  local flicker = 0.94 + 0.05 * math.sin(t * 4.1) +
                        0.02 * math.sin(t * 9.3 + 1.2)
  if flicker < 0.88 then flicker = 0.88 end

  -- Lamp base: a small dark-red stem attaching the lamp to
  -- the wall above. 1 px wide, 2 px tall, in dark red.
  pix(LAMP_X, LAMP_Y - 4, C.flame_base)
  pix(LAMP_X, LAMP_Y - 3, C.flame_base)

  -- Lamp shade: a 5x3 white-orange "shade" shape, narrower
  -- at the top, wider at the bottom. This reads as a hanging
  -- lamp shade, not a pumpkin.
  hline(LAMP_X - 2, LAMP_Y - 2, 5, C.lamp_tip)
  hline(LAMP_X - 2, LAMP_Y - 1, 5, C.lamp_bright)
  hline(LAMP_X - 1, LAMP_Y,     3, C.lamp_tip)
  -- Bottom edge highlight.
  pix(LAMP_X - 2, LAMP_Y, C.lamp_bright)
  pix(LAMP_X + 2, LAMP_Y, C.lamp_bright)

  -- Light spill: a 3x2 white-orange "bulb glow" just below
  -- the shade.
  hline(LAMP_X - 1, LAMP_Y + 1, 3, C.lamp_bright)
  hline(LAMP_X,     LAMP_Y + 2, 1, C.lamp_dim)

  -- Inner ring: orange, 2 px from center.
  for k = 0, 23 do
    local ang = (k / 24) * 2 * math.pi
    local r = 4 * flicker
    local hx = LAMP_X + math.floor(r * math.cos(ang) + 0.5)
    local hy = LAMP_Y + math.floor(r * math.sin(ang) + 0.5)
    pix(hx, hy, C.lamp_bright)
  end

  -- 5-px ring: red-orange, sparser.
  for k = 0, 23 do
    local ang = (k / 24) * 2 * math.pi
    if math.cos(ang) > -0.3 then
      local r = 6 * flicker
      local hx = LAMP_X + math.floor(r * math.cos(ang) + 0.5)
      local hy = LAMP_Y + math.floor(r * math.sin(ang) + 0.5)
      if (k * 7) % 5 < 4 then
        pix(hx, hy, C.lamp_dim)
      end
    end
  end

  -- Outer warm halo: 8-px ring, dark-red, sparse.
  for k = 0, 47 do
    local ang = (k / 48) * 2 * math.pi
    if math.cos(ang) > -0.2 and math.sin(ang) < 0.5 then
      local r = 10 * flicker
      local hx = LAMP_X + math.floor(r * math.cos(ang) + 0.5)
      local hy = LAMP_Y + math.floor(r * math.sin(ang) + 0.5)
      if (k * 11) % 7 < 2 then
        pix(hx, hy, C.lamp_halo)
      end
    end
  end

  -- Faintest: 13-px ring, dark blue, very sparse.
  for k = 0, 47 do
    local ang = (k / 48) * 2 * math.pi
    if math.cos(ang) > -0.1 and math.sin(ang) < 0.4 then
      local r = 16 * flicker
      local hx = LAMP_X + math.floor(r * math.cos(ang) + 0.5)
      local hy = LAMP_Y + math.floor(r * math.sin(ang) + 0.5)
      if (k * 13) % 11 < 1 then
        pix(hx, hy, C.lamp_halo_far)
      end
    end
  end
end

-- ============================================================
-- Lamp reflection on the window glass: a faint warm stripe
-- across the lower third of the pane. Two horizontal warm
-- bands that fade left-to-right (the lamp at (24, 84) is
-- off-screen-left, so the reflection's bright end is on the
-- left of the pane and dims toward the right edge).
-- ============================================================
local function paint_reflection(t)
  -- Subtle pulse on a slow 8s period.
  local pulse = 0.8 + 0.2 * math.sin(t * 0.78)
  if pulse < 0.6 then pulse = 0.6 end

  -- Lower warm band: a thicker line near the bottom of the
  -- pane, fading right.
  for x = PANE_X0 + 4, PANE_X1 - 4 do
    local dx = (x - PANE_X0) / (PANE_X1 - PANE_X0)
    local intensity = (1 - dx) * pulse
    if intensity > 0.45 and x ~= MULLION_X then
      pix(x, PANE_Y1 - 6, C.reflection)
    end
    -- Below it, a dimmer row.
    if intensity > 0.55 and x ~= MULLION_X then
      pix(x, PANE_Y1 - 4, C.reflection_dim)
    end
  end

  -- Upper warm stripe: a thin line ~12 rows up, even dimmer.
  for x = PANE_X0 + 8, PANE_X1 - 12 do
    local dx = (x - (PANE_X0 + 12)) / (PANE_X1 - PANE_X0 - 24)
    if dx > 0 and dx < 1 then
      local intensity = (1 - dx) * pulse
      if intensity > 0.6 and x ~= MULLION_X then
        pix(x, PANE_Y1 - 14, C.reflection_dim)
      end
    end
  end
end

-- ============================================================
-- Lower interior: a small passenger head silhouette in the
-- bottom-left, framed by the lamp's halo. The silhouette is
-- a back-of-the-head profile — the viewer is sitting in the
-- seat in front of a passenger who is looking out the window.
-- The head is dark (against the dark wall, just a step lighter
-- at the edge), but the lamp's halo provides a soft warm rim
-- light on the upper edge of the head.
-- ============================================================
local function paint_silhouette()
  -- A small head profile in the bottom-left, x=0-26, y=110-128.
  -- The head is drawn as a half-oval (the bottom of the head
  -- is cut off by the bottom of the cart).
  --
  -- Center: x=13, y=130. Radius x=14, y=22.
  for y = 108, 130 do
    local dy = (y - 130) / 22
    if dy > -1 and dy < 0 then
      local rx = 14 * math.sqrt(1 - dy * dy)
      for x = 0, math.floor(rx) do
        if x < 56 then  -- don't intrude on the window area
          pix(x, y, C.silhouette)
        end
      end
    end
  end
  -- A thin warm rim on the upper-right of the head, where the
  -- lamp's halo would catch the edge. 2-px orange highlights.
  pix(20, 110, C.lamp_halo)
  pix(19, 111, C.lamp_halo)
  pix(18, 112, C.lamp_halo)
end

-- ============================================================
-- TIC() — main draw. Time is in 60Hz ticks.
-- ============================================================
function TIC()
  local t = time() / 60.0

  -- 1. Wall (the cabin interior, dark).
  cls(C.wall)

  -- 2. Window pane: a deep dark area where the world is visible.
  --    We fill it with the deepest sky color (almost black).
  rect(PANE_X0, PANE_Y0, PANE_X1 - PANE_X0, PANE_Y1 - PANE_Y0, C.pane_deep)

  -- 3. Update and paint the three streak layers.
  update_layer(layer_far)
  update_layer(layer_mid)
  update_layer(layer_near)
  paint_layer(layer_far)
  paint_layer(layer_mid)
  paint_layer(layer_near)

  -- 4. Static signal lights (slow-flashing dots in the pane).
  paint_signals(t)

  -- 5. Mullion: a single vertical divider on the glass.
  vline(MULLION_X, PANE_Y0, PANE_Y1 - PANE_Y0, C.mullion)

  -- 6. Window frame: dark border around the pane.
  --    Top.
  rect(PANE_X0 - FRAME_W, PANE_Y0 - FRAME_W,
       (PANE_X1 - PANE_X0) + 2 * FRAME_W, FRAME_W, C.frame)
  -- Bottom.
  rect(PANE_X0 - FRAME_W, PANE_Y1,
       (PANE_X1 - PANE_X0) + 2 * FRAME_W, FRAME_W, C.frame)
  -- Left.
  rect(PANE_X0 - FRAME_W, PANE_Y0 - FRAME_W, FRAME_W,
       (PANE_Y1 - PANE_Y0) + 2 * FRAME_W, C.frame)
  -- Right.
  rect(PANE_X1, PANE_Y0 - FRAME_W, FRAME_W,
       (PANE_Y1 - PANE_Y0) + 2 * FRAME_W, C.frame)
  -- Subtle edge highlight on the upper-left of the frame.
  for i = 0, FRAME_W - 1 do
    pix(PANE_X0 - FRAME_W + i, PANE_Y0 - FRAME_W + i, C.frame_edge)
  end

  -- 7. Lamp reflection on the glass (drawn AFTER the streaks
  --    and signals so it sits on top of the world).
  paint_reflection(t)

  -- 8. Reading lamp at left.
  paint_lamp(t)

  -- 9. Passenger head silhouette in the lower-left.
  paint_silhouette()
end
