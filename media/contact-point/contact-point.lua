-- One Blow Per Second
-- A bench grinder, pressed. It never stops throwing.
-- 2026-11-17

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

local WX, WY, WR = 108, 74, 40      -- wheel centre and radius
local CONTACT_A  = 35               -- degrees below horizontal, right side
local CX, CY     = 141, 97          -- where the steel meets the wheel
local BENCH_Y    = 122

local sparks = {}

-- ---------------- helpers ----------------

local function pxx(x, y, c)
  local xi = math.floor(x)
  local yi = math.floor(y)
  if xi >= 0 and xi < 240 and yi >= 0 and yi < 136 then
    pix(xi, yi, c)
  end
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

local function vln(x, y0, y1, c)
  for y = math.floor(y0), math.floor(y1) do pxx(x, y, c) end
end

-- coords floored here so a float from cos()/sin() can never index the
-- matrix with a non-integer and blow up mid-frame
local function dth(x, y, d, c)
  if d <= 0 then return end
  local xi = math.floor(x)
  local yi = math.floor(y)
  if B4[yi % 4 + 1][xi % 4 + 1] < d then pxx(xi, yi, c) end
end

-- 5-pixel cross so a single bright particle survives the 200px downscale
local function bpx(x, y, c)
  pxx(x, y, c)
  pxx(x - 1, y, c)
  pxx(x + 1, y, c)
  pxx(x, y - 1, c)
  pxx(x, y + 1, c)
end

-- ---------------- sparks ----------------

local function emit(n)
  local base = math.rad(-CONTACT_A - 8)
  for i = 1, n do
    -- a tight dense cone; a few strays thrown wide so it is not a comb
    local wide = (math.random() < 0.18) and 1 or 0
    local a  = base + (math.random() - 0.5) * math.rad(26 + wide * 34)
    local sp = 78 + math.random() * 148
    sparks[#sparks + 1] = {
      x    = CX + (math.random() - 0.5) * 3,
      y    = CY + (math.random() - 0.5) * 3,
      vx   = math.cos(a) * sp,
      vy   = math.sin(a) * sp,
      life = 0.28 + math.random() * 0.52,
      age  = 0,
    }
  end
end

local function step_sparks(dt)
  local keep = {}
  for i = 1, #sparks do
    local s = sparks[i]
    s.age = s.age + dt
    if s.age < s.life then
      s.vy = s.vy + 340 * dt
      s.x  = s.x + s.vx * dt
      s.y  = s.y + s.vy * dt
      -- skitter along the bench instead of sinking through it
      if s.y > BENCH_Y and s.vy > 0 then
        s.y  = BENCH_Y
        s.vy = -s.vy * 0.34
        s.vx = s.vx * 0.64
      end
      if s.x < 245 then keep[#keep + 1] = s end
    end
  end
  sparks = keep
end

local function draw_sparks()
  for i = 1, #sparks do
    local s = sparks[i]
    local u = s.age / s.life
    local c
    if u < 0.15 then
      c = C.white
    elseif u < 0.46 then
      c = C.orange
    elseif u < 0.74 then
      c = C.coral
    else
      c = C.dkred
    end
    if u < 0.46 then
      bpx(s.x, s.y, c)
    else
      pxx(s.x, s.y, c)
      pxx(s.x - s.vx * 0.008, s.y - s.vy * 0.008, c)
    end
  end
end

-- ---------------- frame ----------------

function TIC()
  cls(C.void)

  local t = time() / 60.0               -- ticks are 1/60s, not milliseconds

  -- the pressure comes and goes; that is the only rhythm the piece has
  local press = 0.28 + 0.72 * math.abs(math.sin(t * math.pi / 1.2))

  -- ---- duct across the ceiling: full width, one colour, rows 0..8.
  -- rows 0..4 stay perfectly uniform so the crop detector has a clean run
  bxr(0, 0, 240, 9, C.dslate)
  hln(9, 0, 239, C.slate)
  for x = 14, 236, 37 do
    vln(x, 5, 9, C.slate)
    vln(x + 1, 5, 9, C.slate)
  end

  -- ---- bench
  bxr(0, BENCH_Y, 240, 14, C.dslate)
  hln(BENCH_Y, 0, 239, C.slate)

  -- ---- the grinder body, on the left, carrying the wheel
  bxr(0, 44, 69, 78, C.dslate)
  hln(44, 0, 68, C.slate)
  bxr(10, 64, 34, 11, C.void)            -- vent slot
  hln(64, 10, 43, C.slate)
  hln(74, 10, 43, C.slate)
  bxr(16, 90, 16, 10, C.void)            -- switch box
  hln(90, 16, 31, C.slate)

  -- ---- the wheel
  circ(WX, WY, WR, C.dslate)
  circb(WX, WY, WR, C.slate)
  circb(WX, WY, 33, C.slate)
  circb(WX, WY, 22, C.void)
  circ(WX, WY, 7, C.void)
  circb(WX, WY, 10, C.slate)

  -- ---- the guard: a step lighter than the wheel, with a dark gap, so it
  -- reads as a separate shroud bolted over a turning disc
  for a = 186, 352, 1 do
    local r  = math.rad(a)
    local ca = math.cos(r)
    local sa = math.sin(r)
    pxx(WX + ca * 39, WY + sa * 39, C.void)
    for rr = 40, 46 do
      pxx(WX + ca * rr, WY + sa * rr, C.slate)
    end
    pxx(WX + ca * 47, WY + sa * 47, C.silver)
    pxx(WX + ca * 48, WY + sa * 48, C.dslate)
  end

  -- ---- the work: a steel bar run into the wheel's lower right
  bxr(134, CY, 92, 10, C.slate)
  hln(CY, 134, 225, C.silver)
  hln(CY + 9, 134, 225, C.dslate)
  vln(225, CY, CY + 9, C.dslate)

  -- ---- the contact: the hottest point in the frame
  circ(CX, CY, 2, C.white)
  circb(CX, CY, 3, (press > 0.72) and C.white or C.orange)

  -- ---- the rim burns where it is being worked
  for a = 5, 68 do
    local r  = math.rad(a)
    local ca = math.cos(r)
    local sa = math.sin(r)
    local d  = 1 - math.abs(a - CONTACT_A) / 33
    if d > 0 then
      dth(WX + ca * 40, WY + sa * 40, d * d * press * 20, C.silver)
      dth(WX + ca * 41, WY + sa * 41, d * d * press * 16, C.slate)
    end
  end

  -- ---- the bench takes the light, falling off to the right
  for x = CX, 239 do
    local d = (x - CX) / 96
    local dens = (1 - d) * press * 7
    dth(x, BENCH_Y + 1, dens, C.slate)
    if (x * 7) % 11 < 3 then
      dth(x, BENCH_Y + 2, dens * 0.6, C.slate)
    end
  end

  -- ---- the bar is lit along its top edge
  for x = 134, 225 do
    local d = math.abs(x - CX) / 95
    dth(x, CY + 1, (1 - d) * press * 9, C.white)
  end

  -- ---- emission
  if #sparks < 420 then
    emit(2 + math.floor(press * 9))
  end

  draw_sparks()
  step_sparks(1 / 60)
end
