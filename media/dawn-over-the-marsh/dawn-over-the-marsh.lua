-- title: Dawn Over the Marsh
-- author: Cass
-- desc: First light over a still marsh. A low sun crests the distant treeline,
--       warm gold spilling into a cool teal sky. A heron stands motionless in
--       the shallows. Reeds tuft the foreground. Mist drifts slowly on the
--       water. Pure ambience, no controls.
-- script: lua

-- ============================================================
-- Dawn Over the Marsh — slow first-light ambient
--
-- Layers (back to front):
--   1. Sky gradient (cool teal-blue at top, warm gold at horizon)
--   2. Distant treeline (low silhouette, mid-tone)
--   3. Sun (a half-disk, warm yellow-orange, with a soft halo)
--   4. Sun reflection on water (vertical warm streak, broken by ripple bands)
--   5. Water surface (lower half, layered teal with horizontal ripple banding)
--   6. Mist on water (slow horizontal drift, two layers, semi-transparent)
--   7. Far reeds (8-10 thin vertical strokes at the far water edge)
--   8. Foreground reed tufts (3 large, asymmetrically placed)
--   9. The heron (silhouette, motionless, off-center)
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
  sky_top       = 11, -- pale cyan (the high dawn — light, not midnight)
  sky_mid       = 10, -- light blue (mid sky, slightly warmer than the top)
  sky_low       = 3,  -- red-orange (the warm wash just above the horizon)
  sky_horizon   = 4,  -- orange (the warmest band, right at the horizon)
  sky_glow      = 4,  -- orange (the warm halo around the sun)
  treeline_far  = 1,  -- dark purple (distant treeline silhouette)
  sun_core      = 4,  -- orange (sun body)
  sun_warm      = 3,  -- red-orange (sun lower edge)
  sun_halo      = 4,  -- orange (soft glow, low alpha)
  water_deep    = 7,  -- dark teal (deep water, far)
  water_mid     = 9,  -- blue (mid water)
  water_near    = 15, -- dark slate (foreground water, slightly warmer)
  water_ripple  = 11, -- pale cyan (ripple highlights)
  reflection    = 4,  -- orange (sun reflection on water)
  reflection_dim = 3, -- red-orange (reflection broken by ripple)
  mist          = 13, -- light gray (mist on water, low alpha)
  reed_far      = 1,  -- dark purple (far reeds)
  reed_fg       = 0,  -- black (foreground reeds)
  heron         = 0,  -- black (heron silhouette)
  heron_warm    = 3,  -- red-orange (subtle warm catch-light on the heron's back)
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
-- Far reed pre-pass: 10 thin vertical strokes at the far water edge.
-- ============================================================
local far_reeds = {}
local far_reed_rnd = make_lcg(4242)
for i = 1, 10 do
  far_reeds[i] = {
    x = math.floor(far_reed_rnd() * 240),
    h = 3 + math.floor(far_reed_rnd() * 3),  -- 3-5 px tall
    lean = (far_reed_rnd() - 0.5) * 0.6,       -- slight right/left lean
  }
end

-- ============================================================
-- Foreground reed tuft pre-pass: dense, varied clusters.
-- Each tuft is a set of tall black strokes with varying heights.
-- The two largest tufts (left and right) are the "near bank"
-- reed walls; smaller tufts in between fill the foreground.
-- ============================================================
local fg_tufts = {
  { x = 14,  count = 8, base_h = 28, lean = 0.10, spread = 8 },
  { x = 42,  count = 3, base_h = 18, lean = -0.05, spread = 3 },
  { x = 70,  count = 2, base_h = 14, lean = 0.05, spread = 2 },
  { x = 198, count = 6, base_h = 26, lean = -0.12, spread = 7 },
  { x = 224, count = 4, base_h = 18, lean = 0.05, spread = 4 },
}
local fg_reeds = {}
local fg_reed_rnd = make_lcg(9090)
for _, t in ipairs(fg_tufts) do
  for j = 1, t.count do
    local dx = math.floor((fg_reed_rnd() - 0.5) * t.spread)
    local dh = math.floor((fg_reed_rnd() - 0.5) * 8)
    fg_reeds[#fg_reeds + 1] = {
      x = t.x + dx,
      h = t.base_h + dh,
      lean = t.lean + (fg_reed_rnd() - 0.5) * 0.10,
    }
  end
end

-- ============================================================
-- Ripple pre-pass: a set of horizontal lines on the water that
-- pulse subtly on independent timers. The reflection is broken
-- at the same Y coordinates as the ripples to make the warm
-- streak look like it's being chopped by tiny waves.
-- ============================================================
local ripples = {}
local ripple_rnd = make_lcg(2024)
local ripple_band_ys = { 76, 80, 84, 88, 92, 97, 103, 109, 115, 121, 127, 133 }
for _, y in ipairs(ripple_band_ys) do
  ripples[#ripples + 1] = {
    y = y,
    phase = ripple_rnd() * 6.28,
    speed = 0.6 + ripple_rnd() * 0.5,
    width = 0.4 + ripple_rnd() * 0.6,
  }
end

-- ============================================================
-- Mist pre-pass: two drifting horizontal mist strips on the water.
-- Each is a row of segments with gaps, semi-transparent, that
-- drift left at slightly different speeds.
-- ============================================================
local mist_layers = {}
for li = 1, 2 do
  local segments = {}
  local base_y = (li == 1) and 88 or 102
  local drift_speed = (li == 1) and 0.012 or 0.018
  local r = make_lcg(3000 + li * 1111)
  local x = 0
  while x < 280 do
    local seg_w = 8 + math.floor(r() * 14)
    segments[#segments + 1] = { start = x, w = seg_w }
    x = x + seg_w + 4 + math.floor(r() * 6)
  end
  mist_layers[li] = {
    y = base_y,
    drift = drift_speed,
    segments = segments,
    base_x = 0,
  }
end

-- ============================================================
-- The heron: a static silhouette standing in the shallows.
-- Built from a small set of line segments drawn around a center
-- point. Drawn once, never moves.
-- ============================================================
local HERON_X = 90
local HERON_BASE_Y = 110
local HERON_SCALE = 1.0

-- ============================================================
-- TIC-80 entry point
-- ============================================================
function TIC()
  local t = time() / 60.0  -- 0 at boot, 1 per second at 60fps

  cls(C.sky_top)

  -- -------------------------------------------------------
  -- 1. Sky gradient: 5 horizontal bands.
  -- The dawn sky fades from a pale-cyan zenith down through
  -- light blue and a warm wash into a hot orange band right
  -- at the horizon. The warm band is wider than the cool
  -- bands — most of the visible sky is *warm*, not cool.
  -- -------------------------------------------------------
  local sky_bands = {
    { y0 = 0,   y1 = 12,  c = C.sky_top },
    { y0 = 12,  y1 = 30,  c = C.sky_mid },
    { y0 = 30,  y1 = 48,  c = C.sky_low },
    { y0 = 48,  y1 = 60,  c = C.sky_horizon },
    { y0 = 60,  y1 = 68,  c = C.sky_glow },
  }
  for _, b in ipairs(sky_bands) do
    rect(0, b.y0, 240, b.y1 - b.y0, b.c)
  end

  -- (Sun drawing moved below the treeline section, so the
  -- sun's half-disk paints over the horizon line rather
  -- than getting sliced by it.)

  -- -------------------------------------------------------
  -- 3. Distant treeline silhouette
  -- A jagged forest silhouette across y=54..72. Each tree
  -- is a 1-pixel-wide stem topped with a wider canopy. The
  -- trees have HEAVILY varying heights (3-12 pixels) and
  -- canopy widths (1-5 pixels), with irregular gaps, so the
  -- treeline reads as an organic forest edge — not a fence.
  -- Every 7th tree is a "feature" tree: taller and wider,
  -- breaking the rhythm. A HERO tree (height 14, width 5)
  -- is drawn first at x=44 to guarantee a dominant focal
  -- tree off-center from the sun.
  -- -------------------------------------------------------
  local treeline_rnd = make_lcg(1010)

  -- Draw the HERO tree first, at a known position.
  local HERO_X = 44
  local HERO_W = 5
  local HERO_H = 14
  local HERO_CX = HERO_X + math.floor(HERO_W / 2)
  -- Canopy: 3 rows, narrowing toward the top
  rect(HERO_CX - 2, 68 - HERO_H, 5, 1, C.treeline_far)
  rect(HERO_CX - 3, 69 - HERO_H, 7, 1, C.treeline_far)
  rect(HERO_CX - 2, 70 - HERO_H, 5, 1, C.treeline_far)
  rect(HERO_CX - 1, 71 - HERO_H, 3, 1, C.treeline_far)
  -- Stem (tall, narrow)
  rect(HERO_CX, 72 - HERO_H, 1, HERO_H - 4, C.treeline_far)

  -- Now draw the rest of the treeline, skipping the area
  -- the hero tree occupies.
  local tree_x = 0
  local tree_count = 0
  -- Skip the area before the hero (x < HERO_X - 4)
  while tree_x < HERO_X - 4 do
    tree_count = tree_count + 1
    local is_feature = (tree_count % 6 == 0)
    local canopy_w
    local total_h
    if is_feature then
      canopy_w = 3 + math.floor(treeline_rnd() * 2)  -- 3..4
      total_h = 7 + math.floor(treeline_rnd() * 3)   -- 7..9
    else
      canopy_w = 1 + math.floor(treeline_rnd() * 3)  -- 1..3
      total_h = 3 + math.floor(treeline_rnd() * 4)  -- 3..6
    end
    local cx = tree_x + math.floor(canopy_w / 2)
    rect(cx - math.floor(canopy_w / 2), 68 - total_h, canopy_w, 1, C.treeline_far)
    rect(cx - math.floor((canopy_w + 1) / 2), 69 - total_h, canopy_w + 1, 1, C.treeline_far)
    if total_h > 5 then
      rect(cx - 1, 70 - total_h, 3, 1, C.treeline_far)
    end
    rect(cx, math.max(70 - total_h + 2, 60), 1, math.min(8, 68 - math.max(70 - total_h + 2, 60)), C.treeline_far)
    local gap = 1 + math.floor(treeline_rnd() * 3)
    tree_x = tree_x + canopy_w + gap
  end
  -- Skip the hero's footprint
  tree_x = HERO_X + HERO_W + 2
  -- Continue the rest of the treeline
  while tree_x < 240 do
    tree_count = tree_count + 1
    local is_feature = (tree_count % 6 == 0)
    local canopy_w
    local total_h
    if is_feature then
      canopy_w = 3 + math.floor(treeline_rnd() * 2)
      total_h = 7 + math.floor(treeline_rnd() * 3)
    else
      canopy_w = 1 + math.floor(treeline_rnd() * 3)
      total_h = 3 + math.floor(treeline_rnd() * 4)
    end
    local cx = tree_x + math.floor(canopy_w / 2)
    rect(cx - math.floor(canopy_w / 2), 68 - total_h, canopy_w, 1, C.treeline_far)
    rect(cx - math.floor((canopy_w + 1) / 2), 69 - total_h, canopy_w + 1, 1, C.treeline_far)
    if total_h > 5 then
      rect(cx - 1, 70 - total_h, 3, 1, C.treeline_far)
    end
    rect(cx, math.max(70 - total_h + 2, 60), 1, math.min(8, 68 - math.max(70 - total_h + 2, 60)), C.treeline_far)
    local gap = 1 + math.floor(treeline_rnd() * 3)
    tree_x = tree_x + canopy_w + gap
  end
  -- Solid horizon line below the treeline
  rect(0, 68, 240, 1, C.treeline_far)

  -- -------------------------------------------------------
  -- 2b. Sun: half-disk rising at the horizon.
  -- Drawn AFTER the treeline so the sun paints over the
  -- horizon line at its location. The sun is centered on
  -- (120, 70) with radius 14, and we clip to y >= 68 so
  -- only the lower half is visible. A bright white-hot
  -- core makes the sun unambiguous against the warm band.
  -- -------------------------------------------------------
  -- Soft halo: a slightly larger circle, drawn full. The
  -- halo above the horizon is invisible against the orange
  -- band; the part below reads as atmospheric glow.
  circ(120, 70, 22, C.sky_horizon)
  circ(120, 70, 19, C.sky_glow)
  circ(120, 70, 17, C.sky_glow)

  -- Half-sun: clip to y >= 68
  clip(0, 68, 240, 68)
  -- Sun body
  circ(120, 70, 14, C.sun_core)
  -- A bright white-hot core
  circ(120, 70, 6, 12)
  -- A warm gradient on the lower edge
  circ(120, 76, 11, C.sun_warm)
  -- Reset clip
  clip(0, 0, 240, 136)

  -- -------------------------------------------------------
  -- 4. Water surface: lower half, layered teal
  -- Three horizontal bands of water, with a horizontal ripple
  -- pulse on each band. The reflection is drawn in the same
  -- Y range. The uppermost water band catches the most dawn
  -- light, so it's slightly warmer (deeper teal mixing into
  -- the orange band above).
  -- -------------------------------------------------------
  local water_bands = {
    { y0 = 72,  y1 = 95,  c = C.water_deep },
    { y0 = 95,  y1 = 115, c = C.water_mid },
    { y0 = 115, y1 = 136, c = C.water_near },
  }
  for _, b in ipairs(water_bands) do
    rect(0, b.y0, 240, b.y1 - b.y0, b.c)
  end
  -- A warm bleed: a single-pixel row right at the horizon's
  -- edge, in a warm tone, so the upper water feels lit.
  rect(0, 69, 240, 1, C.reflection_dim)

  -- -------------------------------------------------------
  -- 5. Sun reflection: a vertical warm streak from the horizon
  -- down to the foreground water, broken by ripple bands.
  -- The streak is centered on the sun (x=120) and is widest
  -- just below the horizon, narrowing as it recedes.
  -- -------------------------------------------------------
  local refl_x_center = 120
  local refl_top = 68
  local refl_bottom = 134
  -- Draw the streak as a series of horizontal "broken" segments.
  -- For each y in 72..134, draw a rect centered on x=120 with
  -- width depending on (y - refl_top) and a horizontal gap from
  -- the ripple timing.
  for y = refl_top, refl_bottom do
    local depth = y - refl_top
    local half_w = math.max(1, math.floor(8 - depth * 0.10))
    -- Pulse: most of the time the segment is visible; a ripple
    -- briefly "breaks" it. Compute ripple at this y.
    local broken = false
    for _, rp in ipairs(ripples) do
      if rp.y == y then
        local phase = math.sin(t * rp.speed + rp.phase)
        if phase > 0.55 then
          broken = true
          break
        end
      end
    end
    if not broken then
      -- The reflection is warmest near the sun, fading toward the foreground.
      local c = (depth < 20) and C.reflection or C.reflection_dim
      rect(refl_x_center - half_w, y, half_w * 2, 1, c)
    end
  end

  -- -------------------------------------------------------
  -- 6. Ripples: thin pale-cyan horizontal highlights on the
  -- water, pulsing on independent timers. They read as light
  -- catching the tops of tiny waves.
  -- -------------------------------------------------------
  for _, rp in ipairs(ripples) do
    local phase = math.sin(t * rp.speed + rp.phase)
    if phase > 0.0 then
      local a = phase * rp.width
      local w = math.floor(20 + a * 60)
      -- Draw two short highlights on each side of the reflection,
      -- and a few more scattered. To keep it from looking like
      -- a uniform row, we use three "blocks" of varying widths.
      local blocks = { { -90, 30 }, { -50, 25 }, { 20, 35 }, { 60, 25 } }
      for _, b in ipairs(blocks) do
        local bx = refl_x_center + b[1]
        if bx >= 0 and bx + b[2] <= 240 then
          rect(bx, rp.y, b[2], 1, C.water_ripple)
        end
      end
    end
  end

  -- -------------------------------------------------------
  -- 7. Mist on water: two drifting layers of semi-transparent
  -- horizontal segments. Drawn in light-gray at low visual
  -- weight (single-pixel rows in a slightly cooler tone).
  -- -------------------------------------------------------
  for _, m in ipairs(mist_layers) do
    -- Slowly drift the base x position
    m.base_x = m.base_x + m.drift
    if m.base_x > 14 then m.base_x = m.base_x - 14 end
    for _, seg in ipairs(m.segments) do
      local sx = (seg.start + m.base_x) % 260 - 10
      -- Clamp to visible range with a soft fade at the edges
      local x0 = math.max(0, math.floor(sx))
      local x1 = math.min(240, math.floor(sx + seg.w))
      if x1 > x0 then
        rect(x0, m.y, x1 - x0, 1, C.mist)
        -- A second pixel row below for a slightly thicker band
        rect(x0, m.y + 1, x1 - x0, 1, C.mist)
      end
    end
  end

  -- -------------------------------------------------------
  -- 8. Far reeds: thin vertical strokes at the far water edge
  -- -------------------------------------------------------
  for _, r in ipairs(far_reeds) do
    local x0 = math.floor(r.x)
    local x1 = x0 + 1
    local y0 = 68  -- sit on the horizon line
    local y1 = y0 + r.h
    -- A single-pixel-wide vertical line, with a 1-pixel lean
    rect(x0, y0, 1, y1 - y0, C.reed_far)
    if r.lean > 0.05 then
      rect(x0 + 1, y0 + 1, 1, y1 - y0 - 1, C.reed_far)
    elseif r.lean < -0.05 then
      rect(x0 - 1, y0 + 1, 1, y1 - y0 - 1, C.reed_far)
    end
  end

  -- -------------------------------------------------------
  -- 9. Foreground reed tufts: tall black strokes, asymmetric
  -- -------------------------------------------------------
  for _, r in ipairs(fg_reeds) do
    local x0 = math.floor(r.x)
    local y0 = 136 - r.h
    rect(x0, y0, 1, r.h, C.reed_fg)
    if r.lean > 0.05 then
      rect(x0 + 1, y0 + 1, 1, r.h - 2, C.reed_fg)
    elseif r.lean < -0.05 then
      rect(x0 - 1, y0 + 1, 1, r.h - 2, C.reed_fg)
    end
  end

  -- -------------------------------------------------------
  -- 10. The heron: a still silhouette standing in the shallows
  -- Built from line segments. The heron is a long-legged wading
  -- bird — narrow body, long neck, pointed beak, two long thin
  -- legs. Drawn in black on top of the water.
  -- -------------------------------------------------------
  -- Body (an elongated diamond at the heron's mid-height)
  local body_x = HERON_X
  local body_y = HERON_BASE_Y - 14
  -- Body shape: short fat oval, drawn as a horizontal stack
  -- of single-pixel rects with a couple of pixels of width
  rect(body_x - 1, body_y,     3, 1, C.heron)
  rect(body_x - 2, body_y + 1, 5, 2, C.heron)
  rect(body_x - 1, body_y + 3, 3, 1, C.heron)

  -- Tail: a short angled stroke going back-right
  rect(body_x + 1, body_y + 2, 2, 1, C.heron)
  rect(body_x + 2, body_y + 3, 1, 1, C.heron)

  -- Neck: a single-pixel column rising from the front of the body
  rect(body_x - 2, body_y - 5, 1, 5, C.heron)
  -- Neck has a slight S-curve: shift left 1 pixel halfway up
  rect(body_x - 3, body_y - 7, 1, 2, C.heron)

  -- Head: a 2x2 black square at the top of the neck
  rect(body_x - 3, body_y - 9, 3, 2, C.heron)
  rect(body_x - 3, body_y - 8, 2, 1, C.heron)

  -- Beak: a thin horizontal stroke to the right
  rect(body_x, body_y - 8, 4, 1, C.heron)

  -- Legs: two parallel vertical strokes going down into the water
  rect(body_x - 1, body_y + 4, 1, 8, C.heron)
  rect(body_x + 1, body_y + 4, 1, 8, C.heron)

  -- Subtle warm catch-light: a single orange pixel on the heron's back
  -- so it reads as "lit by the rising sun" rather than pure silhouette.
  rect(body_x - 1, body_y - 1, 1, 1, C.heron_warm)

  -- -------------------------------------------------------
  -- Final pass: very subtle horizon glow bleed.
  -- A 1-pixel band of warm-orange just below the horizon line,
  -- so the water right at the horizon reads as "lit by the sun"
  -- -------------------------------------------------------
  rect(0, 70, 240, 1, C.reflection_dim)
  rect(0, 71, 240, 1, C.water_deep)
end
