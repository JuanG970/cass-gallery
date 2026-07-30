-- title: Rowboat at Night
-- author: Cass
-- desc: A single small rowboat floating on a still dark lake at night.
--       A tiny warm lantern hangs from the bow, casting a thin vertical
--       reflection into the water below. The boat drifts slowly across
--       the frame on a long period, bobbing on a faster secondary
--       rhythm. Above: a faint starfield and a low horizon line of
--       distant trees. The lantern breathes on a slow flicker. Pure
--       ambient loop, no controls.
-- script: lua

-- ============================================================
-- Rowboat at Night — slow ambient lake scene
--
-- Composition (back to front):
--   1. Sky: deep navy-to-purple gradient
--   2. Stars: sparse, slow twinkle
--   3. Distant tree silhouette on the horizon line
--   4. Water: deep purple, with a slightly lighter band on top
--   5. Boat reflection: a vertical warm streak in the water
--   6. Boat: small 9-px-wide hull with a 1-px lantern at the bow
--   7. Lantern glow: a small warm halo + the 1-px hot center
--   8. Subtle ripples: 2-3 horizontal lines passing through
--      the reflection
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
  sky_top      = 1,  -- dark purple (top of the sky)
  sky_mid      = 8,  -- dark blue (middle of the sky)
  sky_low      = 9,  -- blue (warmer band near the horizon)
  star_bright  = 12, -- white (a few prominent stars)
  star_dim     = 13, -- light gray (the rest of the starfield)
  treeline     = 0,  -- black (the distant tree silhouette)
  treeline_dim = 15, -- dark slate (the slightly closer trees)
  water_top    = 8,  -- dark blue (the water just below the horizon)
  water_mid    = 1,  -- dark purple (the deeper water)
  water_deep   = 0,  -- black (the very bottom of the frame)
  ripple       = 11, -- pale cyan (the horizontal ripple lines)
  boat_hull    = 14, -- mid gray (the wood of the boat)
  boat_dark    = 15, -- dark slate (the inside of the boat, and the
                     --             bottom of the hull)
  boat_rim     = 13, -- light gray (the upper edge of the boat)
  lantern_warm = 4,  -- orange (the lantern body)
  lantern_hot  = 12, -- white (the brightest pixel of the lantern)
  lantern_glow = 3,  -- red-orange (the lantern's warm halo)
  lantern_faint = 2, -- dark red (the outer faint glow)
  reflect_warm = 3,  -- red-orange (the warm reflection)
  reflect_dim  = 2,  -- dark red (the dimmer part of the reflection)
}

-- ============================================================
-- Helpers
-- ============================================================
local function hline(x, y, w, color)
  for i = 0, w - 1 do
    pix(x + i, y, color)
  end
end

local function make_lcg(seed)
  local s = seed or 1337
  return function()
    s = (s * 1103515245 + 12345) % 2147483648
    return s / 2147483648
  end
end

-- ============================================================
-- Constants for the composition
-- ============================================================
local HORIZON_Y = 78       -- y of the horizon line
local WATER_TOP_Y = 79     -- first row of water (just below horizon)
local FRAME_W = 240        -- TIC-80 native width
local FRAME_H = 136        -- TIC-80 native height

-- ============================================================
-- Pre-pass: stars. Sparse, fixed positions, slow twinkle.
-- ============================================================
local stars = {}
local star_rnd = make_lcg(31337)
for i = 1, 18 do
  stars[i] = {
    x = math.floor(star_rnd() * FRAME_W),
    y = 4 + math.floor(star_rnd() * (HORIZON_Y - 8)),
    phase = star_rnd() * math.pi * 2,
    period = 4 + star_rnd() * 6,  -- 4-10s twinkle period
    bright = star_rnd() < 0.30,   -- ~30% are bright
  }
end

-- ============================================================
-- Pre-pass: treeline. A jagged silhouette just above the horizon.
-- Drawn as a list of "spike" heights for x=0..239.
-- ============================================================
local tree = {}
local tree_rnd = make_lcg(991)
for x = 0, FRAME_W - 1 do
  -- Heights are an envelope + a small jitter so it reads as a
  -- continuous forest, not a single repeating shape.
  local h = 2 + math.floor(tree_rnd() * 4)         -- 2-5
  if tree_rnd() < 0.18 then h = h + 2 end          -- occasional taller
  if tree_rnd() < 0.05 then h = h + 3 end          -- rare tall spike
  tree[x + 1] = h
end

-- ============================================================
-- Pre-pass: ripples. Three slow horizontal lines that pass
-- through the boat's reflection. Each has its own period.
-- ============================================================
local ripples = {
  { y_off = 0,  period = 5.7, phase = 0.0,   amp = 6,  bright = 0.55 },
  { y_off = 14, period = 7.3, phase = 2.1,   amp = 4,  bright = 0.40 },
  { y_off = 26, period = 9.1, phase = 4.4,   amp = 3,  bright = 0.30 },
}

-- ============================================================
-- Pre-pass: a moon disc (no, just stars — the subject is the
-- boat). We intentionally leave a slightly darker patch in the
-- upper-right where the brightest cluster sits.
-- ============================================================

-- ============================================================
-- Paint the boat at (cx, cy).
--
-- The boat is a tapered rowboat shape, 11 px wide, 4 px tall.
-- Layout (x relative to cx):
--   row cy-1:  ..  ..  ..  ..  ..  X  X  X  ..  ..  ..   <- rim (sparse ends)
--   row cy  :  X  X  X  X  X  X  X  X  X  X  X          <- top of hull (full width)
--   row cy+1:  ..  X  X  X  X  X  X  X  X  X  ..        <- body, tapered
--   row cy+2:  ..  ..  X  X  X  X  X  X  ..  ..  ..     <- bottom of hull
--
-- The lantern is a warm point on a thin mast at the bow (cx-4),
-- 3 px above the rim, with a small warm halo.
-- ============================================================
local function paint_boat(cx, cy, t)
  local flicker = 0.85 + 0.10 * math.sin(t * 7.3) +
                       0.05 * math.sin(t * 13.1 + 1.7)

  -- Top rim (the gunwale) — full width 11 px, lighter color
  -- so the boat stands out from the dark water.
  hline(cx - 5, cy,     11, C.boat_rim)

  -- Hull body — 9 px wide, slightly narrower than the rim,
  -- creates the taper. Mid gray.
  hline(cx - 4, cy + 1, 9, C.boat_hull)

  -- Bottom of the hull — 7 px wide, narrower still. A slightly
  -- darker mid gray so the boat has a clear underbelly without
  -- being invisible.
  hline(cx - 3, cy + 2, 7, C.boat_dark)

  -- Interior hollow: 3 dark pixels along the top inside the rim.
  for x = cx - 2, cx + 2 do
    pix(x, cy, C.boat_dark)
  end

  -- A single oarlock suggestion at the stern: 1 px at (cx+5, cy-1).
  pix(cx + 5, cy - 1, C.boat_rim)

  -- Mast at the bow: a thin 1-px line from the rim up to the lantern.
  pix(cx - 4, cy - 1, C.boat_rim)

  -- The lantern body at the top of the mast.
  --   1 px wide warm orange.
  pix(cx - 4, cy - 2, C.lantern_warm)
  --   1 px white hot center (the brightest pixel).
  pix(cx - 4, cy - 2, C.lantern_hot)
  -- Wait — the second pix overwrites the first. Set warm first, then
  -- a 1-px white TIP at cy-3.
  pix(cx - 4, cy - 3, C.lantern_hot)
  -- (A clean re-do below for the body; the warm stays at cy-2.)
  pix(cx - 4, cy - 2, C.lantern_warm)

  -- Warm halo: a 3x3 ring of red-orange + dark red around the lantern.
  -- Inner ring (red-orange):
  pix(cx - 3, cy - 2, C.lantern_glow)
  pix(cx - 5, cy - 2, C.lantern_glow)
  pix(cx - 4, cy - 1, C.lantern_glow)
  -- Outer ring (dark red, sparser):
  pix(cx - 3, cy - 3, C.lantern_faint)
  pix(cx - 5, cy - 3, C.lantern_faint)
  pix(cx - 4, cy - 4, C.lantern_faint)
  pix(cx - 2, cy - 2, C.lantern_faint)
  pix(cx - 6, cy - 2, C.lantern_faint)

  -- Faint warmth on the boat (the lantern's light catching the
  -- gunwale near the bow).
  if flicker > 0.85 then
    pix(cx - 5, cy, C.lantern_glow)
    pix(cx + 4, cy, C.boat_rim)
  end
end

-- ============================================================
-- Paint the boat's reflection below the water surface.
-- A vertical streak of warm colors, dimmer than the lantern,
-- broken by ripples.
-- ============================================================
local function paint_reflection(cx, t)
  -- The reflection extends from WATER_TOP_Y down to the bottom of
  -- the frame. Each row is one row of warm color, with a few
  -- darker breaks where ripples pass.
  for j = 0, 8 do
    local y = WATER_TOP_Y + j
    -- Color: bright at top, dim at the bottom.
    local col
    if j < 2 then col = C.reflect_warm
    elseif j < 5 then col = C.reflect_dim
    else col = C.reflect_dim end
    -- Centered at cx, 1 px wide.
    pix(cx - 3, y, col)
  end
  -- Faint spread: 2 px on either side at the top of the reflection.
  pix(cx - 4, WATER_TOP_Y,     C.reflect_dim)
  pix(cx - 2, WATER_TOP_Y,     C.reflect_dim)
  pix(cx - 4, WATER_TOP_Y + 1, C.lantern_faint)
  pix(cx - 2, WATER_TOP_Y + 1, C.lantern_faint)
end

-- ============================================================
-- TIC() — main draw loop. TIC-80 calls this at 60Hz.
-- ============================================================
function TIC()
  local t = time() / 60.0

  -- ===========================================================
  -- 1. Sky gradient (3 bands, top to horizon).
  -- ===========================================================
  for y = 0, HORIZON_Y - 1 do
    local row_frac = y / HORIZON_Y
    local col
    if row_frac < 0.55 then col = C.sky_top
    elseif row_frac < 0.85 then col = C.sky_mid
    else col = C.sky_low end
    hline(0, y, FRAME_W, col)
  end

  -- ===========================================================
  -- 2. Stars: draw all 18 with a slow twinkle phase.
  -- ===========================================================
  for i = 1, 18 do
    local s = stars[i]
    local twinkle = 0.5 + 0.5 * math.sin(t * (2 * math.pi / s.period) + s.phase)
    if twinkle > 0.3 then
      local col = s.bright and C.star_bright or C.star_dim
      -- A few bright stars have a tiny halo.
      if s.bright and twinkle > 0.85 then
        pix(s.x,     s.y,     col)
        pix(s.x - 1, s.y,     C.star_dim)
        pix(s.x + 1, s.y,     C.star_dim)
        pix(s.x,     s.y - 1, C.star_dim)
        pix(s.x,     s.y + 1, C.star_dim)
      else
        pix(s.x, s.y, col)
      end
    end
  end

  -- ===========================================================
  -- 3. Treeline: jagged silhouette just above the horizon.
  -- ===========================================================
  for x = 0, FRAME_W - 1 do
    local h = tree[x + 1]
    -- Draw the tree as a column of dark pixels from the horizon
    -- upward, with the lower rows in pure black and the upper
    -- rows in dark slate (suggests distance).
    for j = 0, h - 1 do
      local y = HORIZON_Y - 1 - j
      if y >= 0 then
        if j == 0 then pix(x, y, C.treeline)
        else pix(x, y, C.treeline_dim) end
      end
    end
  end
  -- Solid horizon line.
  hline(0, HORIZON_Y, FRAME_W, C.treeline)

  -- ===========================================================
  -- 4. Water: deep purple gradient, darker at the bottom.
  -- ===========================================================
  for y = WATER_TOP_Y, FRAME_H - 1 do
    local row_frac = (y - WATER_TOP_Y) / (FRAME_H - WATER_TOP_Y)
    local col
    if row_frac < 0.30 then col = C.water_top
    elseif row_frac < 0.70 then col = C.water_mid
    else col = C.water_deep end
    hline(0, y, FRAME_W, col)
  end

  -- ===========================================================
  -- 5. Boat position: slow horizontal drift + a faster bob.
  --    The boat's center X drifts on a 24s period; the Y bobs
  --    on a 1.7s period.
  -- ===========================================================
  local BOAT_Y = 86   -- the waterline of the boat
  local drift_period = 24
  local boat_cx = 80 + math.floor(40 * math.sin(t * (2 * math.pi / drift_period)) + 0.5)
  local bob = math.floor(math.sin(t * (2 * math.pi / 1.7)) * 0.6 + 0.5)
  local boat_cy = BOAT_Y + bob

  -- ===========================================================
  -- 6. Boat reflection (drawn BEFORE the boat, so the boat
  --    overwrites the top of the reflection).
  -- ===========================================================
  paint_reflection(boat_cx, t)

  -- ===========================================================
  -- 7. Ripples: three slow horizontal lines on the water.
  --    Each is a single horizontal line that moves slightly
  --    vertically on its own period.
  -- ===========================================================
  for _, r in ipairs(ripples) do
    local y = WATER_TOP_Y + 4 + r.y_off +
              math.floor(r.amp * math.sin(t * (2 * math.pi / r.period) + r.phase) + 0.5)
    if y >= WATER_TOP_Y and y < FRAME_H then
      -- A short ripple segment near the boat's x, with a chance
      -- of being present based on the ripple's bright value.
      local x_start = math.max(0, boat_cx - 16)
      local x_end   = math.min(FRAME_W, boat_cx + 16)
      for x = x_start, x_end - 1 do
        -- Only draw if x is in a "bright" segment of the ripple.
        local phase = (x - x_start) * 0.4 + t * 1.2
        if (math.sin(phase) + 1) / 2 < r.bright then
          pix(x, y, C.ripple)
        end
      end
    end
  end

  -- ===========================================================
  -- 8. The boat itself.
  -- ===========================================================
  paint_boat(boat_cx, boat_cy, t)
end
