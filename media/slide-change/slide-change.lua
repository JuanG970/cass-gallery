-- title:  Slide Change
-- author: Cass
-- desc:   a 35mm projector clicking through slides in a dark room
-- script: lua

local C = {
  black=0, dPurple=1, dred=2, salmon=3, orange=4, yGreen=5, green=6,
  teal=7, dBlue=8, blue=9, lBlue=10, pCyan=11, white=12, lGray=13,
  gray=14, slate=15
}

-- ---- helpers: the 5-arg pix(x,y,w,h,col) rect form is broken in 1.1.2837 ----
local function hlin(x, y, w, col)
  for i = 0, w - 1 do
    local px = x + i
    if px >= 0 and px < 240 and y >= 0 and y < 136 then pix(px, y, col) end
  end
end

local function vlin(x, y, h, col)
  for j = 0, h - 1 do
    local py = y + j
    if py >= 0 and py < 136 and x >= 0 and x < 240 then pix(x, py, col) end
  end
end

local function rect(x, y, w, h, col)
  for j = 0, h - 1 do hlin(x, y + j, w, col) end
end

local function llin(x0, y0, x1, y1, col)
  local dx = math.abs(x1 - x0)
  local dy = math.abs(y1 - y0)
  local sx = x0 < x1 and 1 or -1
  local sy = y0 < y1 and 1 or -1
  local err = dx - dy
  local x, y = x0, y0
  while true do
    if x >= 0 and x < 240 and y >= 0 and y < 136 then pix(x, y, col) end
    if x == x1 and y == y1 then break end
    local e2 = 2 * err
    if e2 > -dy then err = err - dy; x = x + sx end
    if e2 < dx then err = err + dx; y = y + sy end
  end
end

local function disc(cx, cy, r, col)
  for j = -r, r do
    local w = math.floor(math.sqrt(r * r - j * j) + 0.5)
    hlin(cx - w, cy + j, 2 * w + 1, col)
  end
end

local function bpix(x, y, col)
  if x < 2 or x > 237 or y < 2 or y > 133 then return end
  pix(x, y, col)
  pix(x + 1, y, col)
  pix(x - 1, y, col)
  pix(x, y + 1, col)
  pix(x, y - 1, col)
end

-- ---- geometry ----------------------------------------------------------
local BX, BY, BW, BH = 8, 74, 54, 40      -- projector body
local MX, MY, MW, MH = 62, 88, 12, 12     -- lens barrel
local SX, SY, SW, SH = 134, 32, 92, 60    -- projected image on the wall
local CYCLE, SHUT = 360, 12               -- 6s per slide, 12-frame wipe each way
local TRAY_N = 7

-- ---- precomputed light: beam haze and wall halo ------------------------
local BEAM = {}
local HALO = {}
local MOTES = {}

local function build_beam()
  local x0 = MX + MW + 1
  for x = x0, SX - 2, 2 do
    local t = (x - x0) / (SX - x0)
    local yt = (MY + 3) + (SY - (MY + 3)) * t
    local yb = (MY + MH - 4) + (SY + SH - (MY + MH - 4)) * t
    local mid = (yt + yb) / 2
    local half = (yb - yt) / 2
    for y = math.floor(yt), math.ceil(yb), 2 do
      local off = math.abs(y - mid) / half
      local hh = (x * 37 + y * 91) % 100
      local lim = 0
      if off < 0.45 then lim = 92 elseif off < 0.78 then lim = 44 else lim = 15 end
      if hh < lim then
        BEAM[#BEAM + 1] = {x, y, (hh < 8) and C.dBlue or C.slate}
      end
    end
  end
end

local function build_halo()
  for x = SX - 5, SX + SW + 4 do
    for y = SY - 5, SY + SH + 4 do
      local inside = (x >= SX and x < SX + SW and y >= SY and y < SY + SH)
      if not inside then
        local dx = math.max(SX - x, x - (SX + SW - 1), 0)
        local dy = math.max(SY - y, y - (SY + SH - 1), 0)
        local d = math.max(dx, dy)
        local hh = (x * 29 + y * 53) % 100
        local lim = 0
        if d == 1 then lim = 62 elseif d == 2 then lim = 26 elseif d == 3 then lim = 12 else lim = 6 end
        if hh < lim then HALO[#HALO + 1] = {x, y, d} end
      end
    end
  end
end

local function build_motes()
  for i = 1, 30 do
    MOTES[i] = {
      x = MX + MW + 4 + math.random() * (SX - MX - MW - 8),
      v = 0.08 + math.random() * 0.30,
      ph = math.random() * 6.283,
      amp = 1.0 + math.random() * 3.0,
      off = math.random(),
    }
  end
end

local function span_at(x)
  local x0 = MX + MW + 1
  local t = (x - x0) / (SX - x0)
  if t < 0 then t = 0 elseif t > 1 then t = 1 end
  local yt = (MY + 3) + (SY - (MY + 3)) * t
  local yb = (MY + MH - 4) + (SY + SH - (MY + MH - 4)) * t
  return yt, yb
end

-- ---- the four slides ---------------------------------------------------
local function slide_dunes(x, y)
  rect(x, y, SW, 20, C.dPurple)
  rect(x, y + 20, SW, 12, C.salmon)
  rect(x, y + 32, SW, 9, C.orange)
  disc(x + 62, y + 31, 9, C.orange)
  disc(x + 62, y + 31, 6, C.white)
  for i = 0, SW - 1 do
    local d1 = 40 + math.floor(5 * math.sin((i + 3) * 0.055))
    vlin(x + i, y + d1, SH - d1, C.dred)
  end
  for i = 0, SW - 1 do
    local d2 = 50 + math.floor(4 * math.sin((i + 20) * 0.08))
    vlin(x + i, y + d2, SH - d2, C.black)
  end
end

local function slide_pines(x, y)
  rect(x, y, SW, 10, C.pCyan)
  rect(x, y + 10, SW, 12, C.lGray)
  rect(x, y + 22, SW, 12, C.gray)
  rect(x, y + 34, SW, SH - 34, C.white)
  hlin(x, y + 30, SW, C.lGray)
  hlin(x, y + 33, SW, C.lGray)
  local px = {8, 20, 31, 44, 57, 70, 83}
  local ph = {18, 27, 22, 33, 25, 29, 16}
  for i = 1, #px do
    local cx = x + px[i]
    local top = y + 34 - ph[i]
    for r = 0, ph[i] do
      local w = math.floor(r * 0.24)
      hlin(cx - w, top + r, 2 * w + 1, C.slate)
    end
    vlin(cx, top + ph[i], 5, C.slate)
  end
end

local function slide_moon(x, y)
  rect(x, y, SW, 32, C.dBlue)
  rect(x, y + 32, SW, 3, C.teal)
  for i = 1, 24 do
    local sx = (i * 37 + 11) % SW
    local sy = (i * 23 + 5) % 30
    pix(x + sx, y + sy, (i % 3 == 0) and C.white or C.lGray)
  end
  disc(x + 66, y + 15, 8, C.lGray)
  disc(x + 66, y + 15, 6, C.white)
  rect(x, y + 35, SW, SH - 35, C.blue)
  for r = 0, 22 do
    local w = math.max(1, math.floor(6 - r * 0.2))
    local wob = math.floor(1.4 * math.sin(r * 0.26))
    if (r % 5) ~= 0 then
      hlin(x + 66 - w + wob, y + 36 + r, w * 2, C.lGray)
    end
  end
end

local function slide_field(x, y)
  rect(x, y, SW, 26, C.salmon)
  rect(x, y + 26, SW, 12, C.orange)
  disc(x + 78, y + 31, 5, C.white)
  rect(x, y + 36, SW, SH - 36, C.green)
  for i = 0, SW - 1 do
    local g = 36 + math.floor(3 * math.sin((i + 9) * 0.09))
    vlin(x + i, y + g, 2, C.yGreen)
  end
  local tx = x + 26
  vlin(tx, y + 18, 26, C.black)
  vlin(tx + 1, y + 22, 22, C.black)
  llin(tx, y + 26, tx - 10, y + 16, C.black)
  llin(tx + 1, y + 24, tx + 11, y + 13, C.black)
  llin(tx, y + 30, tx - 8, y + 22, C.black)
  llin(tx + 1, y + 21, tx + 7, y + 20, C.black)
end

local SLIDES = { slide_dunes, slide_pines, slide_moon, slide_field }

-- ---- the machine -------------------------------------------------------
local function draw_projector(idx, t)
  hlin(BX + 5, BY + BH, 10, C.dBlue)
  hlin(BX + 34, BY + BH, 10, C.dBlue)

  rect(BX, BY, BW, BH, C.slate)
  hlin(BX, BY, BW, C.lGray)
  vlin(BX, BY, BH, C.gray)
  rect(BX + 2, BY + BH - 3, BW - 4, 2, C.black)

  for i = 0, 4 do
    hlin(BX + 5, BY + 26 + i * 3, 22, C.black)
    hlin(BX + 5, BY + 27 + i * 3, 22, C.dBlue)
  end

  rect(BX + 34, BY + 8, 16, 14, C.dBlue)
  disc(BX + 42, BY + 15, 4, C.gray)
  disc(BX + 42, BY + 15, 2, C.black)

  local pulse = 0.5 + 0.5 * math.sin(t * 0.9)
  disc(BX + 34, BY + 29, 1, pulse > 0.55 and C.salmon or C.dred)

  -- lens bracket and the table the machine sits on
  rect(MX - 4, MY - 2, 6, MH + 4, C.slate)
  hlin(MX - 4, MY - 2, 6, C.gray)
  hlin(0, BY + BH + 4, BX + BW + 22, C.slate)

  -- lens barrel
  rect(MX, MY, MW, MH, C.gray)
  rect(MX + 1, MY + 1, MW - 2, MH - 2, C.black)
  hlin(MX, MY, MW, C.lGray)
  rect(MX + MW - 5, MY + 1, 5, MH - 2, C.salmon)
  rect(MX + MW - 4, MY + 2, 3, MH - 4, C.orange)
  vlin(MX + MW - 2, MY + 3, MH - 6, C.white)

  for i = 0, 12 do
    local ang = i * 0.524
    local gx = MX + MW + 2 + math.floor(4 * math.cos(ang))
    local gy = MY + 6 + math.floor(6 * math.sin(ang))
    pix(gx, gy, C.salmon)
  end

  -- slide tray on top
  rect(BX + 3, BY - 10, 46, 9, C.black)
  hlin(BX + 3, BY - 10, 46, C.gray)
  vlin(BX + 3, BY - 10, 9, C.gray)
  vlin(BX + 48, BY - 10, 9, C.gray)
  local active = (idx - 1) % TRAY_N
  for i = 0, TRAY_N - 1 do
    local sx = BX + 5 + i * 6
    if i == active then
      rect(sx, BY - 9, 5, 7, C.orange)
      rect(sx + 1, BY - 8, 3, 5, C.white)
    else
      rect(sx, BY - 9, 5, 7, C.dBlue)
      hlin(sx, BY - 6, 5, C.slate)
    end
  end
end

-- ---- main loop ---------------------------------------------------------
local frame = 0

build_beam()
build_halo()
build_motes()

function TIC()
  local t = time() / 60.0
  cls(C.black)

  for i = 1, #BEAM do
    local b = BEAM[i]
    hlin(b[1], b[2], 2, b[3])
  end

  for i = 1, #HALO do
    local h = HALO[i]
    pix(h[1], h[2], h[3] == 1 and C.gray or C.slate)
  end

  local ph = frame % CYCLE
  local idx = math.floor((frame + SHUT) / CYCLE) % #SLIDES + 1

  clip(SX, SY, SW, SH)
  SLIDES[idx](SX, SY)

  local cover = 0
  local c0 = CYCLE - 2 * SHUT
  if ph >= c0 and ph < CYCLE - SHUT then
    cover = math.floor((ph - c0) * SH / SHUT + 0.5)
  elseif ph >= CYCLE - SHUT then
    cover = SH - math.floor((ph - (CYCLE - SHUT)) * SH / SHUT + 0.5)
  end
  if cover > 0 then
    rect(SX, SY, SW, cover, C.black)
    if cover < SH then hlin(SX, SY + cover, SW, C.lGray) end
  end
  clip()

  for i = 1, #MOTES do
    local m = MOTES[i]
    m.x = m.x + m.v
    if m.x > SX - 3 then m.x = MX + MW + 4 + math.random() * 12 end
    local yt, yb = span_at(m.x)
    local y = yt + m.off * (yb - yt) + math.sin(t * 1.3 + m.ph) * m.amp
    y = math.floor(y + 0.5)
    if m.x < 102 then
      bpix(math.floor(m.x), y, C.lGray)
    else
      pix(math.floor(m.x), y, C.gray)
    end
  end

  draw_projector(idx, t)
  frame = frame + 1
end
