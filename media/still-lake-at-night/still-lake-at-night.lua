-- title: A Still Lake at Night
-- author: Cass
-- desc: A deep-night scene. No moon worth mentioning, no horizon glow.
--       A sky full of stars over a still black lake. Each star has
--       a reflection on the water, slightly offset, occasionally
--       broken by slow horizontal ripples. A low distant treeline
--       silhouette separates sky from water. No human presence.
--       Pure deep-night ambience, no controls.
-- script: lua

-- ============================================================
-- A Still Lake at Night — deep-night ambient
--
-- Layers (back to front):
--   1. Sky gradient (black at zenith, very dark blue low)
--   2. Stars (32 stars in upper sky, varied brightness, slow twinkle)
--   3. Faint hint of the Milky Way (a soft band of slightly lighter
--      blue across the middle of the sky)
--   4. Distant treeline (low silhouette, very dark)
--   5. Water surface (lower half, near-black, layered)
--   6. Star reflections on water (mirrored positions, dimmer, offset)
--   7. Ripples (slow horizontal pulse, distorting reflections)
--   8. A single faint horizon glow (the only warm pixel in the scene)
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
  sky_zenith  = 0,  -- black (top of sky)
  sky_high    = 15, -- dark slate (high sky)
  sky_mid     = 8,  -- dark blue (mid sky, the Milky Way band)
  sky_low     = 15, -- dark slate (low sky, just above the treeline) — was 1 (magenta) which read wrong
  sky_horizon = 8,  -- dark blue (faint horizon glow — provides contrast for the treeline)
  star_dim    = 14, -- mid gray (faint stars)
  star_mid    = 13, -- light gray (medium stars)
  star_bright = 12, -- white (bright stars, ~15% of population)
  star_halo   = 14, -- mid gray (the halo around the brightest star)
  moon        = 13, -- light gray (the moon's lit crescent)
  moon_dim    = 14, -- mid gray (the moon's "shadow" side, faintly visible)
  milky_way   = 7,  -- dark teal (soft band, slightly lighter than sky) — was 8
  treeline    = 0,  -- black (distant treeline silhouette)
  treeline_tip = 14, -- mid gray (top edge of treeline, visible against dark sky)
  water_top   = 15, -- dark slate (water right at horizon, catches the faintest light)
  water_mid   = 8,  -- dark blue (mid water) — was 1 (magenta) which read wrong
  water_deep  = 0,  -- black (foreground water, deep)
  reflection_dim   = 14, -- mid gray (faint star reflections)
  reflection_mid   = 13, -- light gray (brighter star reflections)
  reflection_bright = 11, -- pale cyan (brightest reflection, very rare)
  ripple      = 13, -- light gray (ripple highlights)
  horizon_glow = 8, -- dark blue (the single-pixel horizon band)
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
-- Star pre-pass: 32 stars in the upper sky (y < 48).
-- Each has a position, brightness tier, and a slow twinkle phase.
-- Star density is highest in the upper third (y < 28) where
-- the sky is darkest, falling off near the horizon.
-- ============================================================
local stars = {}
local star_rnd = make_lcg(3141)
for i = 1, 32 do
  local y_bias = star_rnd()  -- 0..1, used to bias stars toward the top
  local y = math.floor(y_bias * y_bias * 48)  -- quadratic bias toward top, y=0..47
  local bright_tier = star_rnd()
  local bright
  if bright_tier < 0.15 then
    bright = "bright"
  elseif bright_tier < 0.55 then
    bright = "mid"
  else
    bright = "dim"
  end
  stars[i] = {
    x = math.floor(star_rnd() * 240),
    y = y,
    bright = bright,
    tw_phase = star_rnd() * 6.28,
    tw_period = 60 + star_rnd() * 90,  -- 60-150s slow twinkle
  }
end

-- ============================================================
-- Distant treeline pre-pass: a row of small triangular
-- tree silhouettes. Each tree is 6-9 pixels tall, with a
-- 2-3 pixel-wide triangular canopy and a thin stem. The
-- trees sit against the faint horizon-glow band (y=48..53)
-- which provides the contrast needed to read the silhouette.
-- ============================================================
local treeline = {}
local tl_rnd = make_lcg(7777)
local tl_x = 0
while tl_x < 240 do
  local canopy_w = 2 + math.floor(tl_rnd() * 2)  -- 2-3 px canopy
  local total_h = 6 + math.floor(tl_rnd() * 3)    -- 6-8 px total
  treeline[#treeline + 1] = {
    x = tl_x,
    cx = tl_x + math.floor(canopy_w / 2),  -- center x
    w = canopy_w,
    h = total_h,
  }
  -- Each tree occupies canopy_w + 1-2 px gap
  local gap = 1 + math.floor(tl_rnd() * 2)  -- 1-2 px gap
  tl_x = tl_x + canopy_w + gap
end
-- A taller back row, with bigger gaps — peeks above the front
local treeline2 = {}
local tl2_rnd = make_lcg(8888)
local tl2_x = 0
while tl2_x < 240 do
  local canopy_w = 2 + math.floor(tl2_rnd() * 2)  -- 2-3 px
  local total_h = 8 + math.floor(tl2_rnd() * 2)    -- 8-9 px (taller)
  treeline2[#treeline2 + 1] = {
    x = tl2_x,
    cx = tl2_x + math.floor(canopy_w / 2),
    w = canopy_w,
    h = total_h,
  }
  local gap = 2 + math.floor(tl2_rnd() * 3)  -- 2-4 px gap (sparser)
  tl2_x = tl2_x + canopy_w + gap
end

-- ============================================================
-- Ripple pre-pass: just 2 horizontal "wavelets" on the
-- water, very subtle. They briefly break the reflections
-- in their Y range, and draw a small highlight. Two is
-- the right number: one is invisible, three starts to
-- look like floating debris.
-- ============================================================
local ripples = {}
local ripple_rnd = make_lcg(2024)
local ripple_band_ys = { 78, 105 }
for _, y in ipairs(ripple_band_ys) do
  ripples[#ripples + 1] = {
    y = y,
    phase = ripple_rnd() * 6.28,
    speed = 0.4 + ripple_rnd() * 0.4,
    width = 0.5 + ripple_rnd() * 0.5,
  }
end

-- ============================================================
-- Moon pre-pass: a thin crescent moon in the upper-right
-- quadrant of the sky. The moon is the focal point of
-- the composition — without it, the eye wanders. A
-- crescent (rather than full) keeps the deep-night mood
-- (a full moon would brighten the scene too much).
-- Position: x=200, y=14. Size: small (5x5 px max).
-- ============================================================
local MOON_X = 200
local MOON_Y = 14
local MOON_R = 4  -- radius
-- A crescent is created by drawing a filled disc, then
-- "subtracting" a smaller offset disc. Since we don't
-- have a subtraction primitive, we draw the moon as a
-- series of 1-pixel rects that form a crescent shape.

-- ============================================================
-- The Milky Way: a soft band of slightly lighter sky across
-- the middle of the visible sky (y=20..38). Implemented as
-- a few short dashes of dark blue in a horizontal band, with
-- large gaps so it reads as scattered star-haze, not a band
-- of stripes. Only 5 segments total.
-- ============================================================
local milky_segments = {}
local mw_rnd = make_lcg(5555)
local mw_x = 0
local seg_count = 0
while mw_x < 280 and seg_count < 5 do
  local seg_w = 8 + math.floor(mw_rnd() * 12)
  local seg_y = 20 + math.floor(mw_rnd() * 14)  -- y=20..33
  milky_segments[#milky_segments + 1] = { x = mw_x, y = seg_y, w = seg_w }
  mw_x = mw_x + seg_w + 30 + math.floor(mw_rnd() * 25)
  seg_count = seg_count + 1
end

-- ============================================================
-- TIC-80 entry point
-- ============================================================
function TIC()
  local t = time() / 60.0  -- seconds since boot (time() returns 60fps ticks)

  cls(C.sky_zenith)

  -- -------------------------------------------------------
  -- 1. Sky gradient: 3 horizontal bands, dark night.
  -- Mostly black, with a slightly bluer band where the
  -- Milky Way sits, and a final horizon-glow band
  -- (also dark blue) right above the treeline. The
  -- overall palette is intentionally very dark — this
  -- is a deep-night scene, not a twilight one.
  -- -------------------------------------------------------
  local sky_bands = {
    { y0 = 0,  y1 = 30, c = C.sky_zenith },  -- y=0..29: black (zenith)
    { y0 = 30, y1 = 48, c = C.sky_mid },     -- y=30..47: dark blue (Milky Way band)
    { y0 = 48, y1 = 54, c = C.sky_horizon }, -- y=48..53: dark blue (faint horizon glow)
  }
  for _, b in ipairs(sky_bands) do
    rect(0, b.y0, 240, b.y1 - b.y0, b.c)
  end

  -- -------------------------------------------------------
  -- 2. The Milky Way: a soft band of slightly-lighter
  -- blue dashes across y=18..37. Reads as a band of
  -- dense star-haze, not a solid bar. The dashes are
  -- in the same dark blue as the sky mid-band, but
  -- because the band above and below is darker, the
  -- contrast makes them visible as a "soft band of
  -- brightness" rather than individual stars.
  -- -------------------------------------------------------
  for _, m in ipairs(milky_segments) do
    local sx = (m.x - t * 0.3) % 280
    if sx < 0 then sx = sx + 280 end
    local x0 = sx - 20
    if x0 >= 0 and x0 + m.w <= 240 then
      rect(x0, m.y, m.w, 1, C.milky_way)
    end
  end

  -- -------------------------------------------------------
  -- 2b. The Moon: a thin crescent in the upper-right.
  -- A crescent is created by drawing a filled disc, then
  -- "subtracting" a smaller offset disc on the right side.
  -- We use a halo of mid gray (the moon_dim color) to
  -- suggest the moon's glow, then the lit crescent in
  -- light gray. The dark side of the moon is implied by
  -- the absence of the lit crescent against the sky.
  -- -------------------------------------------------------
  -- Soft halo: a slightly larger circle around the moon
  circ(MOON_X, MOON_Y, MOON_R + 2, C.moon_dim)
  -- Lit crescent: a full disc
  circ(MOON_X, MOON_Y, MOON_R, C.moon)
  -- Shadow side: an offset disc, slightly smaller, that
  -- "eats" the right side of the moon. We use the sky
  -- color (sky_zenith = black) for the shadow so it
  -- blends with the night sky. The remaining lit crescent
  -- faces left, suggesting a waning crescent.
  circ(MOON_X + 2, MOON_Y, MOON_R - 1, C.sky_zenith)
  -- -------------------------------------------------------
  for _, s in ipairs(stars) do
    local tw = 0.5 + 0.5 * math.sin(t * 2 * math.pi / s.tw_period + s.tw_phase)
    if s.bright == "bright" then
      -- Bright stars: always visible, but pulse through mid gray to white
      if tw > 0.7 then
        pix(s.x, s.y, C.star_bright)
      elseif tw > 0.3 then
        pix(s.x, s.y, C.star_mid)
      else
        pix(s.x, s.y, C.star_dim)
      end
    elseif s.bright == "mid" then
      -- Mid stars: visible most of the time, blink off briefly
      if tw > 0.15 then
        pix(s.x, s.y, C.star_mid)
      end
    else
      -- Dim stars: only visible at the peak of their twinkle
      if tw > 0.7 then
        pix(s.x, s.y, C.star_dim)
      end
    end
  end

  -- -------------------------------------------------------
  -- 4. Distant treeline: two layers of triangular tree
  -- silhouettes. Each tree has a wider triangular canopy
  -- and a thin stem. The trees sit against the horizon-glow
  -- band, which provides the contrast needed to read
  -- the silhouette at this small size.
  -- -------------------------------------------------------
  local base_y = 54  -- horizon (just below sky_horizon band)
  -- Back row first (taller, peeks above the front)
  for _, p in ipairs(treeline2) do
    local cw = p.w
    -- Row 1 (top, narrowest)
    rect(p.cx, base_y - p.h, 1, 1, C.treeline)
    -- Row 2 (slightly wider)
    if cw >= 2 then
      rect(p.cx - math.floor((cw - 1) / 2), base_y - p.h + 1, cw - 1, 1, C.treeline)
    end
    -- Row 3 (widest, near the bottom of the canopy)
    rect(p.cx - math.floor(cw / 2), base_y - p.h + 2, cw, 1, C.treeline)
    -- Stem: 1px wide, from canopy down to base
    local stem_top = base_y - p.h + 3
    if stem_top < base_y then
      rect(p.cx, stem_top, 1, base_y - stem_top, C.treeline)
    end
  end
  -- Front row (drawn second, dominant silhouette)
  for _, p in ipairs(treeline) do
    local cw = p.w
    -- Row 1 (top, narrowest)
    rect(p.cx, base_y - p.h, 1, 1, C.treeline)
    -- Row 2 (slightly wider)
    if cw >= 2 then
      rect(p.cx - math.floor((cw - 1) / 2), base_y - p.h + 1, cw - 1, 1, C.treeline)
    end
    -- Row 3 (widest)
    rect(p.cx - math.floor(cw / 2), base_y - p.h + 2, cw, 1, C.treeline)
    -- Stem
    local stem_top = base_y - p.h + 3
    if stem_top < base_y then
      rect(p.cx, stem_top, 1, base_y - stem_top, C.treeline)
    end
    -- Top edge highlight: a single light-gray pixel at the apex
    pix(p.cx, base_y - p.h, C.treeline_tip)
  end
  -- Solid horizon line below the treeline
  rect(0, 54, 240, 1, C.treeline)

  -- -------------------------------------------------------
  -- 5. Water surface: lower half (y=55..135), mostly black
  -- for the deep-night mood. Only a single-row horizon
  -- glow at the top (dark blue) suggests the last trace
  -- of sky-light. The rest of the water is black, so the
  -- star reflections stand out clearly.
  -- -------------------------------------------------------
  -- Single-pixel horizon glow (drawn first as part of
  -- the water surface pass)
  rect(0, 55, 240, 1, C.horizon_glow)
  -- The rest of the water is black
  rect(0, 56, 240, 80, C.water_deep)

  -- -------------------------------------------------------
  -- 6. Star reflections on water: each star has a mirrored
  -- position on the water. The reflection is offset slightly
  -- (by a small phase from t) so it looks like the water
  -- is gently moving. The reflection is also dimmer than
  -- the source star — the bright stars reflect as mid gray,
  -- the mid stars reflect as light gray/dim gray, and the
  -- dim stars don't reflect at all.
  -- The moon also gets a reflection: a vertical bright
  -- streak on the water directly below the moon, broken
  -- by ripples like a sun reflection on a dawn lake.
  -- -------------------------------------------------------
  local horizon_y = 54
  for _, s in ipairs(stars) do
    -- The reflection y is mirrored about the horizon at y=54.
    -- So a star at sky y=10 reflects at water y=(54 + (54-10))=98.
    -- A small time-varying offset simulates gentle water motion.
    local refl_y = horizon_y + (horizon_y - s.y)
    -- Only reflect if the mirror lands in the water (y < 136)
    if refl_y < 136 and refl_y >= 55 then
      -- Compute the ripple state for this y. If a ripple is
      -- at its peak at this y, the reflection is broken.
      local broken = false
      for _, rp in ipairs(ripples) do
        if rp.y == refl_y then
          local phase = math.sin(t * rp.speed + rp.phase)
          if phase > 0.6 then
            broken = true
            break
          end
        end
      end

      if not broken then
        -- Horizontal wobble: the reflection x drifts slightly
        -- with a slow phase based on t. This is the "water
        -- moving" effect.
        local x_off = math.floor(math.sin(t * 0.3 + s.x * 0.05) * 1.5)
        local refl_x = s.x + x_off
        if refl_x >= 0 and refl_x < 240 then
          if s.bright == "bright" then
            -- Bright stars reflect as light gray, occasionally
            -- a pale-cyan flash at the peak of the twinkle
            local tw = 0.5 + 0.5 * math.sin(t * 2 * math.pi / s.tw_period + s.tw_phase)
            if tw > 0.85 then
              pix(refl_x, refl_y, C.reflection_bright)
            else
              pix(refl_x, refl_y, C.reflection_mid)
            end
          elseif s.bright == "mid" then
            pix(refl_x, refl_y, C.reflection_dim)
          end
          -- Dim stars don't reflect — too faint to see in water
        end
      end
    end
  end

  -- -------------------------------------------------------
  -- 6b. Moon reflection: a vertical bright streak on the
  -- water directly below the moon. The streak is widest
  -- right at the horizon and narrows as it recedes into
  -- the foreground, broken occasionally by ripples. Only
  -- extends partway down the water — a long full-canvas
  -- streak reads as a pillar, not a reflection.
  -- -------------------------------------------------------
  local refl_x_center = MOON_X
  local refl_top = horizon_y + 1
  local refl_bottom = 90  -- only top half of the water
  for y = refl_top, refl_bottom do
    local depth = y - refl_top
    local half_w = math.max(1, math.floor(3 - depth * 0.06))
    -- Break the reflection at ripple bands
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
      -- The streak is brightest near the moon, fading toward the foreground
      local c = (depth < 15) and C.moon or C.moon_dim
      rect(refl_x_center - half_w, y, half_w * 2, 1, c)
    end
  end

  -- -------------------------------------------------------
  -- 7. Ripples: thin pale-gray horizontal highlights on
  -- the water, pulsing slowly. Subtle — just 2 short
  -- segments per band, not the 3 wide blocks of v1. The
  -- goal is "occasional glint" not "horizontal striping."
  -- -------------------------------------------------------
  for _, rp in ipairs(ripples) do
    local phase = math.sin(t * rp.speed + rp.phase)
    if phase > 0.1 then
      local w = math.floor(6 + phase * rp.width * 15)  -- 6-21px wide
      -- Two short segments at fixed positions per ripple
      -- (positions are set per-ripple in the pre-pass; we
      -- read them back here). To keep the visual
      -- deterministic and the gif compressible, the
      -- segments do NOT move over time.
      local bx1 = ((rp.y * 17) % 100) + 20
      local bx2 = ((rp.y * 31) % 80) + 130
      for _, bx in ipairs({bx1, bx2}) do
        if bx >= 0 and bx + w <= 240 and w > 0 then
          rect(bx, rp.y, w, 1, C.ripple)
        end
      end
    end
  end
end
