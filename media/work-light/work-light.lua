-- Work Light
-- A glassblower at the glory hole. One lamp in the room, and it is the work.
-- 2026-11-21

local C = {
  void   = 0,
  dkred  = 2,
  coral  = 3,
  orange = 4,
  white  = 12,
  silver = 13,
  slate  = 14,
  dslate = 15,
}

local B4 = {
  { 0,  8,  2, 10},
  {12,  4, 14,  6},
  { 3, 11,  1,  9},
  {15,  7, 13,  5},
}

-- the glory hole: an arch cut in the brick
local MX, MY = 37, 64          -- middle of the opening
local AX0, AX1 = 20, 54        -- opening, left and right
local AY0, AY1 = 43, 81        -- opening, top and bottom
local FLOOR_Y  = 122

-- ---------------- helpers ----------------

local function pxx(x, y, c)
  local xi, yi = math.floor(x), math.floor(y)
  if xi >= 0 and xi < 240 and yi >= 0 and yi < 136 then pix(xi, yi, c) end
end

local function hln(y, x0, x1, c)
  local yy = math.floor(y)
  if yy < 0 or yy > 135 then return end
  local a, b = math.floor(x0), math.floor(x1)
  if a > b then a, b = b, a end
  if a < 0 then a = 0 end
  if b > 239 then b = 239 end
  for x = a, b do pix(x, yy, c) end
end

local function bxr(x, y, w, h, c)
  for j = 0, h - 1 do hln(y + j, x, x + w - 1, c) end
end

local function clamp(v, lo, hi)
  if v < lo then return lo elseif v > hi then return hi else return v end
end

-- coords floored inside the helper: a float index on B4 is nil and blows up,
-- and so does a nan out of a sqrt, so both are stopped here rather than at
-- thirty call sites
local function dth(x, y, d, c)
  if not (d > 0) then return end
  local xi, yi = math.floor(x), math.floor(y)
  if not (xi == xi) or not (yi == yi) then return end
  if B4[yi % 4 + 1][xi % 4 + 1] < d then pxx(xi, yi, c) end
end

-- how far into the arch each row starts, so the top is a rounded opening
-- rather than a letterbox
local function arch_inset(y)
  if y >= AY0 + 9 then return 0 end
  local u = clamp((AY0 + 9 - y) / 9, 0, 1)
  return math.floor(0.5 + 11 * (1 - math.sqrt(1 - u * u)))
end

local function in_arch(x, y)
  if y < AY0 or y > AY1 then return false end
  local i0 = arch_inset(y)
  return x >= AX0 + i0 and x <= AX1 - i0
end

-- ---------------- the static room, built once ----------------
-- wall, brick and floor never move. the fire, the man and the embers are
-- redrawn every frame; ~12k blits beat 30k dither tests inside TIC().

local BX, BY, BC = {}, {}, {}
local function bset(x, y, c)
  local n = #BX + 1
  BX[n], BY[n], BC[n] = x, y, c
end

local function bdth(x, y, d, c)
  if not (d > 0) then return end
  local xi, yi = math.floor(x), math.floor(y)
  if B4[yi % 4 + 1][xi % 4 + 1] < d then bset(xi, yi, c) end
end

local function build_room()
  -- the furnace wall runs the width of the shed. a flat lit panel with four
  -- edges round it is a doorway; courses of brick are a surface, and a dark
  -- figure cutting across them reads as a figure.
  for y = 7, FLOOR_Y - 1 do
    for x = 0, 206 do bset(x, y, C.dslate) end
  end
  -- the bricks near the mouth are at temperature: a value step, not a
  -- scatter. a dotted halo round a light reads as sparks, not as heat.
  for y = 10, 135 do
    for x = 0, 206 do
      local ex, ey = (x - MX) / 17, (y - (MY - 3)) / 20
      local e = math.sqrt(ex * ex + ey * ey)
      if e < 1.05 then bset(x, y, C.orange)
      elseif e < 1.30 then bset(x, y, C.coral)
      elseif e < 1.72 then bset(x, y, C.dkred) end
    end
  end
  -- courses every 11 rows, joints staggered, all of them one pixel
  local ci = 0
  for y = 18, FLOOR_Y - 1, 11 do
    ci = ci + 1
    for x = 0, 206 do bset(x, y, C.void) end
    local off = (ci % 2 == 0) and 8 or 0
    for x = off, 206, 16 do
      for yy = y - 10, y - 1 do bset(x, yy, C.void) end
    end
  end
  -- shadow under the beam
  for x = 0, 206 do
    for y = 7, 9 do bdth(x, y, 14 - (y - 7) * 4, C.void) end
  end
  for x = 12, 62 do
    local d = clamp(1 - math.abs(x - 37) / 30, 0, 1)
    bset(x, 82, d > 0.25 and C.slate or C.dslate)
    bdth(x, 83, d * 9, C.dkred)
    bdth(x, 84, d * 4, C.void)
  end

  -- the floor: dark boards, with the fire spilt across the near half and
  -- the man's shadow cutting into the spill from his feet
  for y = FLOOR_Y, 135 do
    local fy = (y - FLOOR_Y) / 13
    for x = 0, 239 do
      bdth(x, y, 1.3, C.dslate)
      local px, py = (x - 40) / 62, (y - FLOOR_Y) / 9
      local dens = (1 - math.sqrt(px * px + py * py)) * 16
      if dens >= 12 then bset(x, y, C.dkred)
      else bdth(x, y, dens, C.dkred) end
      if dens >= 7 then bdth(x, y, (dens - 7) * 0.9, C.coral) end
    end
  end
  for x = 6, 239, 26 do
    for y = FLOOR_Y, 135 do bdth(x, y, 3, C.void) end
  end
end

build_room()

-- ---------------- the man ----------------
-- per-row spans, built once into SH so the rim light can walk the front edge

local SHY, SHX0, SHX1 = {}, {}, {}
local function span(y, x0, x1)
  local n = #SHY + 1
  SHY[n], SHX0[n], SHX1[n] = y, x0, x1
end

local function lerp(a, b, u) return a + (b - a) * u end

local function build_man()
  -- torso: keypoints top to hips, interpolated
  local K = {
    {52, 96, 110},
    {56, 90, 118},
    {60, 89, 118},
    {68, 91, 114},
    {76, 92, 110},
    {83, 94, 108},
    {88, 94, 112},
    {94, 94, 116},
  }
  for i = 1, #K - 1 do
    local a, b = K[i], K[i + 1]
    for y = a[1], b[1] - 1 do
      local u = (y - a[1]) / (b[1] - a[1])
      span(y, math.floor(lerp(a[2], b[2], u)), math.floor(lerp(a[3], b[3], u)))
    end
  end
  for y = 49, 52 do span(y, 99, 108) end   -- neck

  -- legs: front leg braced, back leg taking the weight
  local L = {
    {94,  94, 103, 107, 116},
    {103, 94, 102, 108, 116},
    {111, 95, 102, 109, 116},
    {118, 96, 103, 110, 116},
    {121, 96, 103, 110, 117},
  }
  for i = 1, #L - 1 do
    local a, b = L[i], L[i + 1]
    for y = a[1], b[1] - 1 do
      local u = (y - a[1]) / (b[1] - a[1])
      span(y, math.floor(lerp(a[2], b[2], u)), math.floor(lerp(a[3], b[3], u)))
      span(y, math.floor(lerp(a[4], b[4], u)), math.floor(lerp(a[5], b[5], u)))
    end
  end
  span(121, 92, 104)                       -- feet
  span(121, 106, 118)

  -- the arm running forward to the pipe
  local A = {
    {56, 87, 94},
    {59, 83, 93},
    {62, 78, 92},
    {65, 77, 91},
    {67, 79, 91},
  }
  for i = 1, #A - 1 do
    local a, b = A[i], A[i + 1]
    for y = a[1], b[1] - 1 do
      local u = (y - a[1]) / (b[1] - a[1])
      span(y, math.floor(lerp(a[2], b[2], u)), math.floor(lerp(a[3], b[3], u)))
    end
  end
  for y = 63, 67 do span(y, 76, 82) end    -- hand closed round the pipe
end

build_man()

local function draw_man(t)
  -- a breath: the shoulders lift a pixel and settle. nothing else moves.
  local br = (math.sin(t * math.pi / 1.25) > 0.72) and -1 or 0

  for i = 1, #SHY do
    local y = SHY[i] + br
    for x = SHX0[i], SHX1[i] do pxx(x, y, C.void) end
  end
  circ(100, 45 + br, 6, C.void)            -- head, leaning in
  bxr(90, 39 + br, 16, 3, C.void)          -- flat cap, brim forward

  -- the fire is behind and left of him, so the front edge takes the light.
  -- kept sparse: a solid neon outline would read as a drawn edge, not light.
  for i = 1, #SHY do
    local y = SHY[i] + br
    local x0 = SHX0[i]
    if y <= 96 then
      local d = clamp(1 - (x0 - 52) / 54, 0, 1) * clamp(1 - math.abs(y - MY) / 58, 0, 1)
      if d > 0.18 then
        dth(x0, y, d * 20, C.silver)
        if d > 0.6 then dth(x0, y, (d - 0.6) * 30, C.dkred) end
      end
    end
  end
  -- the head sits a hand's width from the mouth, so it takes more than the body
  for y = 39, 51 do
    local d = clamp(1 - math.abs(y - 45) / 16, 0, 1)
    local xl = 100 - math.floor(math.sqrt(math.max(0, 36 - (y - 45) ^ 2)))
    dth(xl, y + br, d * 15, C.silver)
    if d > 0.35 then dth(xl, y + br, 6, C.dkred) end
  end
  dth(90, 40 + br, 8, C.silver)
  dth(91, 39 + br, 8, C.silver)
  hln(39 + br, 92, 101, C.dkred)
end

-- ---------------- the pipe ----------------

local function draw_pipe()
  for x = 24, 94 do
    local y = 59 + (x - 24) * 0.055
    pxx(x, y, C.void)
    pxx(x, y + 1, C.void)
    if not in_arch(x, y) and x < 74 then pxx(x, y - 1, C.slate) end
  end
end

-- ---------------- the fire ----------------

local function draw_fire(t)
  local flick  = math.sin(t * math.pi / 1.25)
  local flick2 = math.sin(t * math.pi * 2 / 1.6667)

  -- the opening: a white-hot band at working height, wider than it is tall,
  -- ragged at its edge, cooling to coral at the crown. no clean concentric
  -- boundary anywhere -- a ring of one colour inside another is a target.
  local hx, hy = MX - 2 + flick * 1.5, MY + 3
  for y = AY0, AY1 do
    local i0 = arch_inset(y)
    for x = AX0 + i0, AX1 - i0 do
      local dx, dy = (x - hx) / 19, (y - hy) / 15
      local r2 = dx * dx + dy * dy
      local c
      if r2 < 0.42 then
        c = C.white
      elseif r2 < 0.92 then
        local k = (0.92 - r2) / 0.50 * 15
        c = (B4[y % 4 + 1][x % 4 + 1] < k) and C.white or C.orange
      elseif r2 < 1.0 then
        c = C.orange
      else
        c = C.coral
      end
      if y < AY0 + 6 then c = C.coral end
      pxx(x, y, c)
    end
  end
  -- flame climbing the crown in tongues, not a band
  for i = 0, 5 do
    local y = AY0 + 2 + i * 2
    local half = 7 - math.abs(i - 1) * 2
    local wob = math.sin(t * 2 * math.pi * 2 / 5 + i * 1.3) * 2
    if half > 1 then
      for x = -half, half do
        local d = 1 - math.abs(x) / half
        dth(MX + 1 + wob + x, y, d * 9, C.white)
      end
    end
  end

  -- the lip of the arch: hot iron, two rows, no wide halo
  for y = AY0 - 2, AY1 + 1 do
    local i0 = arch_inset(y)
    dth(AX0 + i0 - 1, y, 14, C.dkred)
    dth(AX0 + i0 - 2, y, 6, C.dkred)
    dth(AX1 - i0 + 1, y, 14, C.dkred)
    dth(AX1 - i0 + 2, y, 6, C.dkred)
  end
  hln(AY0 - 2, AX0 + 8, AX1 - 8, C.dkred)
  hln(AY1 + 1, AX0 - 1, AX1 + 1, C.dkred)
  for x = AX0, AX1 do
    if math.sin(t * 2 * math.pi * 3 / 5 + x * 0.7) > 0.55 then
      dth(x, AY1 + 2, 7, C.dkred)
    end
  end
end

-- ---------------- embers ----------------
-- periodic by construction: each ember's phase is fixed, so the last frame
-- of the loop is the first. nothing random, nothing to seam.

local function draw_embers(t)
  for i = 1, 13 do
    local u = (t / 5.0 + i / 13) % 1
    local a = i * 2.399
    local x = MX + math.sin(a) * (6 + u * 16) + u * 34
    local y = MY - 18 - u * 42
    local c
    if u < 0.22 then c = C.white
    elseif u < 0.55 then c = C.orange
    elseif u < 0.82 then c = C.coral
    else c = C.dkred end
    if y > 12 then
      pxx(x, y, c)
      if u < 0.4 then pxx(x, y + 1, c) end
    end
  end
end

-- ---------------- frame ----------------

function TIC()
  local t = time() / 60.0

  cls(C.void)

  for i = 1, #BX do pix(BX[i], BY[i], BC[i]) end

  -- beam across the top: rows 0..5 stay a clean flat band, nothing else
  -- may touch them or the crop detector reads the wrong scale
  bxr(0, 0, 240, 6, C.dslate)
  hln(6, 0, 239, C.slate)

  draw_fire(t)
  draw_pipe()
  draw_man(t)
  draw_embers(t)

  -- the beam's underside catches a little of the fire, at its near end only
  for x = 0, 60 do
    local d = 1 - x / 60
    dth(x, 6, d * d * 5, C.dkred)
  end
end
