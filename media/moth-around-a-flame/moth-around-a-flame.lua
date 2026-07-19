-- title: Moth Around a Flame
-- author: Cass
-- desc: A single lit candle in a dim interior. The flame is a small
--       teardrop with a white-hot tip and an orange body, flickering
--       on a slow noise phase. A moth with visible wings orbits the
--       candle on a slow lissajous path, always close enough to
--       catch the light. The wall is uniform dark-slate with a
--       single faint warmth halo concentrated near the flame. One
--       ember drifts up and fades. Pure ambience, no controls.
-- script: lua

-- ============================================================
-- Moth Around a Flame — slow intimate ambient
--
-- Composition (back to front):
--   1. Wall: solid dark slate (cleared each frame).
--   2. Warmth halo: a thin annulus of dark-red + dark-blue around
--      the candle. Drawn as annulus, NOT a filled disc.
--   3. Outer halo: a sparse ring of red-orange + mid-gray.
--   4. Candle body: a tall white/cream column (3 px wide, 32 tall)
--      that anchors the composition. A subtle warm tint near the
--      top from the flame.
--   5. Flame: hand-painted teardrop on top of the candle, 7 rows
--      tall, 3 px wide at body, with a 1-px white tip.
--   6. Wick: 1 px dark-red between flame and candle.
--   7. Ember: 1 active ember rising and fading.
--   8. Moth: a 5-pixel sprite (body + 4 wings) on a slow orbit
--      inside a 30x18 region around the candle. Wings flap
--      between spread and folded every 0.3s.
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
  wall          = 15, -- dark slate (the wall)
  warmth_ring   = 2,  -- dark red (the 1-2 px ring around the candle)
  warmth_faint  = 8,  -- dark blue (the outer faint ring)
  halo_warm     = 3,  -- red-orange (sparse outer halo)
  halo_faint    = 14, -- mid gray (the faintest outermost ring)
  flame_tip     = 12, -- white (the hottest pixel at the flame tip)
  flame_bright  = 4,  -- orange (the body of the flame)
  flame_dim     = 3,  -- red-orange (the lower, dimmer part)
  flame_base    = 2,  -- dark red (the base of the flame)
  wick          = 2,  -- dark red (the wick itself)
  candle_body   = 4,  -- orange (the candle wax, lit by the flame)
  candle_dim    = 3,  -- red-orange (the candle wax, mid section)
  candle_dark   = 14, -- mid gray (the candle wax, far from flame)
  candle_shadow = 0,  -- black (the candle's far edge, away from flame)
  ember_bright  = 4,  -- orange (newly-spawned ember)
  ember_fading  = 3,  -- red-orange (fading ember)
  ember_dying   = 2,  -- dark red (nearly-extinct ember)
  moth_body     = 12, -- white (moth body — bright, contrasts well at thumb size)
  moth_wing     = 4,  -- orange (moth wings — orange, lit by the flame)
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

-- LCG PRNG.
local function lcg(seed)
  local s = seed
  return function()
    s = (s * 1103515245 + 12345) % 2147483648
    return s / 2147483648
  end
end

-- ============================================================
-- Ember state.
-- ============================================================
local G_spawn_ember
do
  local r = lcg(91)
  function G_spawn_ember()
    return {
      x = 120 + (r() - 0.5) * 4,
      y = 70 + (r() - 0.5) * 2,
      vx = (r() - 0.5) * 0.08,
      vy = -0.22 - r() * 0.10,
      life = 0,
      max_life = 90 + r() * 90,
    }
  end
end
local ember = G_spawn_ember()

-- ============================================================
-- Flame: hand-painted teardrop at (cx, cy).
-- ============================================================
local function paint_flame(cx, cy, t)
  local xj = 0
  if math.floor(t * 11) % 2 == 0 then xj = 1 end

  -- Tip (row cy-6): 1 px white, occasionally 2.
  pix(cx + xj, cy - 6, C.flame_tip)
  if math.floor(t * 13) % 5 == 0 then
    pix(cx + xj + 1, cy - 6, C.flame_tip)
  end

  -- Row cy-5: 1-2 px orange.
  if math.floor(t * 9) % 3 == 0 then
    pix(cx + xj,     cy - 5, C.flame_bright)
    pix(cx + xj + 1, cy - 5, C.flame_bright)
  else
    pix(cx + xj,     cy - 5, C.flame_bright)
  end

  -- Row cy-4: 2-3 px orange.
  hline(cx + xj, cy - 4, 2, C.flame_bright)
  if math.floor(t * 8) % 4 == 0 then
    hline(cx + xj - 1, cy - 4, 1, C.flame_bright)
  end

  -- Row cy-3: 3 px wide orange, with red-orange tips.
  hline(cx + xj - 1, cy - 3, 3, C.flame_bright)
  pix(cx + xj - 1, cy - 3, C.flame_dim)
  pix(cx + xj + 1, cy - 3, C.flame_dim)

  -- Row cy-2: 3 px wide orange, with red-orange tips.
  hline(cx + xj - 1, cy - 2, 3, C.flame_bright)
  pix(cx + xj - 1, cy - 2, C.flame_dim)
  pix(cx + xj + 1, cy - 2, C.flame_dim)

  -- Row cy-1: 3 px wide, red-orange center, dark-red tips.
  hline(cx + xj - 1, cy - 1, 3, C.flame_dim)
  pix(cx + xj - 1, cy - 1, C.flame_base)
  pix(cx + xj + 1, cy - 1, C.flame_base)

  -- Base: 1 px dark red.
  pix(cx + xj, cy, C.flame_base)
end

-- ============================================================
-- Candle body: 3 px wide, 30 tall, with a warm gradient.
--   - Top 8 rows: warm (lit by flame).
--   - Middle 16 rows: medium warm.
--   - Bottom 6 rows: dim (far from flame).
-- The right edge of the candle is shadowed (away from light).
-- ============================================================
local function paint_candle(cx, top_y, bottom_y)
  local height = bottom_y - top_y
  for j = 0, height - 1 do
    local y = top_y + j
    local row_frac = j / height
    local col
    if row_frac < 0.2 then
      col = C.candle_body  -- top 20%, warm orange (lit by flame)
    elseif row_frac < 0.7 then
      col = C.candle_dim   -- mid 50%, red-orange
    else
      col = C.candle_dark  -- bottom 30%, mid gray
    end
    -- 3 px wide column.
    hline(cx - 1, y, 3, col)
    -- Right edge shadow.
    pix(cx + 1, y, C.candle_shadow)
  end
end

-- ============================================================
-- TIC() — main draw. Time is in 60Hz ticks.
-- ============================================================
function TIC()
  local t = time() / 60.0
  -- Anchor positions. Candle is centered horizontally; flame sits
  -- on top of the candle. Flame Y is the wick; flame body extends
  -- upward from there.
  local CANDLE_X = 120
  local CANDLE_TOP = 70   -- top of candle (where the wick emerges)
  local CANDLE_BOTTOM = 130  -- bottom of candle (sits in shadow)
  local FLAME_Y = 70       -- the wick is here; flame body extends UP

  -- Clear to the deep wall color.
  cls(C.wall)

  ----------------------------------------
  -- 1. Warmth halo (annulus around the candle top).
  ----------------------------------------
  local flicker = 0.85 + 0.10 * math.sin(t * 7.3) +
                       0.05 * math.sin(t * 13.1 + 1.7)
  if flicker < 0.7 then flicker = 0.7 end

  -- Inner warmth ring (dark red, 1 px) around the flame.
  for k = 0, 47 do
    local ang = (k / 48) * 2 * math.pi
    if math.sin(ang) > -0.5 then
      local r = 5 * flicker
      local hx = CANDLE_X + math.floor(r * math.cos(ang) + 0.5)
      local hy = FLAME_Y + math.floor(r * math.sin(ang) + 0.5)
      pix(hx, hy, C.warmth_ring)
    end
  end

  -- Outer faint ring (dark blue, sparser).
  for k = 0, 47 do
    local ang = (k / 48) * 2 * math.pi
    if math.sin(ang) > -0.6 then
      local r = 9 * flicker
      local hx = CANDLE_X + math.floor(r * math.cos(ang) + 0.5)
      local hy = FLAME_Y + math.floor(r * math.sin(ang) + 0.5)
      if (k * 7) % 5 < 3 then
        pix(hx, hy, C.warmth_faint)
      end
    end
  end

  -- Red-orange halo (sparse ring).
  for k = 0, 31 do
    local ang = (k / 32) * 2 * math.pi
    if math.sin(ang) > -0.7 then
      local r = 13 * flicker
      local hx = CANDLE_X + math.floor(r * math.cos(ang) + 0.5)
      local hy = FLAME_Y + math.floor(r * math.sin(ang) * 0.85 + 0.5)
      if (k * 7) % 5 < 1 then
        pix(hx, hy, C.halo_warm)
      end
    end
  end

  -- Faint mid-gray outer ring.
  for k = 0, 39 do
    local ang = (k / 40) * 2 * math.pi
    if math.sin(ang) > -0.7 then
      local r = 18 * flicker
      local hx = CANDLE_X + math.floor(r * math.cos(ang) + 0.5)
      local hy = FLAME_Y + math.floor(r * math.sin(ang) * 0.85 + 0.5)
      if (k * 11) % 7 < 1 then
        pix(hx, hy, C.halo_faint)
      end
    end
  end

  ----------------------------------------
  -- 2. Candle body.
  ----------------------------------------
  paint_candle(CANDLE_X, CANDLE_TOP, CANDLE_BOTTOM)

  ----------------------------------------
  -- 3. Flame (teardrop, on top of the candle).
  ----------------------------------------
  paint_flame(CANDLE_X, FLAME_Y, t)

  -- Wick: 1 px dark-red at the very top of the candle (between
  -- candle and flame).
  pix(CANDLE_X, FLAME_Y - 1, C.wick)
  pix(CANDLE_X, CANDLE_TOP, C.candle_body)  -- make sure top is warm

  ----------------------------------------
  -- 4. Rising ember (well above the flame, in the upper third).
  ----------------------------------------
  ember.life = ember.life + 1
  ember.x = ember.x + ember.vx
  ember.y = ember.y + ember.vy
  ember.vx = ember.vx + math.sin(t * 3) * 0.002

  local life_frac = ember.life / ember.max_life
  local col
  if life_frac < 0.3 then col = C.ember_bright
  elseif life_frac < 0.7 then col = C.ember_fading
  else col = C.ember_dying end

  if ember.x >= 0 and ember.x < 240 and ember.y >= 0 and ember.y < 136 and life_frac < 0.95 then
    pix(math.floor(ember.x + 0.5), math.floor(ember.y + 0.5), col)
  end

  if ember.life >= ember.max_life or ember.y < 16 then
    ember = G_spawn_ember()
  end

  ----------------------------------------
  -- 5. Moth. Lissajous orbit inside a 30x18 region around the
  --    flame. Slow (~14s period). Drawn as a 5-pixel sprite.
  ----------------------------------------
  local orbit_t = t * 0.45
  local mx = CANDLE_X + math.floor(18 * math.sin(orbit_t) +
                                   7 * math.sin(orbit_t * 2.3 + 1.0) + 0.5)
  local my = FLAME_Y + math.floor(10 * math.cos(orbit_t * 0.9) +
                                   4 * math.sin(orbit_t * 2.7) + 0.5)

  -- Don't draw the moth if it would be on top of the flame.
  local ddx = mx - CANDLE_X
  local ddy = my - FLAME_Y
  if ddx*ddx + ddy*ddy > 3 * 3 and my > 50 then  -- keep moth above the candle
    -- Body.
    pix(mx, my, C.moth_body)
    -- Wings: 1 pixel each side at body level.
    pix(mx - 1, my, C.moth_wing)
    pix(mx + 1, my, C.moth_wing)
    -- Wing tips (above body, flapping on a 0.3s cycle).
    if math.floor(t * 3) % 2 == 0 then
      pix(mx - 1, my - 1, C.moth_wing)
      pix(mx + 1, my - 1, C.moth_wing)
    end
  end
end
