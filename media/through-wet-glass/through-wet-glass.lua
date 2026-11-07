-- title:  Through Wet Glass
-- author: Cass
-- desc:   rooftops at dusk, seen through a pane the rain has got to first
-- script: lua

local C = {
  ink=0, dMagenta=1, red=2, salmon=3, amber=4,
  lime=5, green=6, teal=7, dBlue=8, blue=9,
  ltBlue=10, cyan=11, white=12, ltGray=13, slate=14, dSlate=15,
}

local W, H = 240, 136
local LOOP = 5.0

local B4 = {{0,8,2,10},{12,4,14,6},{3,11,1,9},{15,7,13,5}}
local function dith(x, y, d, c)
  if d <= 0 then return end
  local xi, yi = math.floor(x), math.floor(y)
  if B4[yi % 4 + 1][xi % 4 + 1] < d then pix(xi, yi, c) end
end

local function hline(x, y, w, c)
  for i = 0, w - 1 do pix(x + i, y, c) end
end

local function vline(x, y, h, c)
  for j = 0, h - 1 do pix(x, y + j, c) end
end

local function hash(a, b)
  local n = (a * 374761393 + b * 668265263) % 2147483647
  n = (n * 1274126177) % 2147483647
  return n % 1024
end

local ticks = 0
local function sec() return ticks / 60.0 end

local RUNNERS = {
  { x= 18, ph=0.00 }, { x= 57, ph=0.63 }, { x= 94, ph=0.27 },
  { x=129, ph=0.82 }, { x=168, ph=0.45 }, { x=208, ph=0.13 },
}
local RUN_TOP, RUN_BOT = 14, 134

local function run_x(base, y, ph)
  return base + math.floor(math.sin(y * 0.075 + ph * 6.28) * 2.0 + 0.5)
end

local function runner_y(r)
  local u = (sec() / LOOP + r.ph) % 1
  return math.floor(RUN_TOP + u * (RUN_BOT - RUN_TOP))
end

local function fill(segs, c)
  for i = 1, #segs do
    local s = segs[i]
    rect(s[1], s[3], s[2] - s[1], H - s[3], c)
  end
end

local function rim(segs, c)
  for i = 1, #segs do
    local s = segs[i]
    hline(s[1], s[3], s[2] - s[1], c)
  end
end

-- three depths, three values: haze, slate, ink
local FAR = {
  {  0, 26, 68 }, { 26, 34, 73 }, { 34, 52, 64 }, { 52, 60, 70 },
  { 60, 74, 66 }, { 74, 88, 74 }, { 88, 104, 61 }, {104, 118, 67 },
  {118, 136, 72 }, {136, 150, 65 }, {150, 164, 70 }, {164, 182, 63 },
  {182, 196, 71 }, {196, 216, 66 }, {216, 240, 70 },
}
local MID = {
  {  0, 40, 100 }, { 40, 52, 106 }, { 52, 88,  95 }, { 88, 102, 104 },
  {102, 148, 90 }, {148, 162, 102 }, {162, 200, 96 }, {200, 224, 106 },
  {224, 240, 98 },
}
local NEAR = {
  {  0, 52, 118 }, { 52, 62, 124 }, { 62, 98, 112 }, { 98, 156, 120 },
  {156, 174, 115 }, {174, 206, 122 }, {206, 240, 116 },
}

-- drops that have let go and left a bead on the way down
local BEADS = {
  { 34, 34, 5 }, { 96, 26, 4 }, { 152, 48, 6 }, { 196, 32, 4 },
  { 64, 86, 5 }, { 140, 92, 4 }, { 214, 62, 6 }, { 24, 74, 4 },
}

function TIC()
  ticks = ticks + 1
  cls(C.dBlue)

  ---------------------------------------------------------------- sky
  -- rows 0-7 stay flat: that band is how the capture finds the cart
  rect(0, 0, W, 8, C.dBlue)
  rect(0, 8, W, 10, C.dBlue)
  for y = 18, 23 do
    local d = math.floor((y - 17) * 2.7)
    for x = 0, W - 1 do dith(x, y, d, C.blue) end
  end
  rect(0, 24, W, 6, C.blue)
  for y = 30, 35 do
    local d = math.floor((y - 29) * 2.7)
    for x = 0, W - 1 do dith(x, y, d, C.ltBlue) end
  end
  rect(0, 36, W, 6, C.ltBlue)
  for y = 42, 47 do
    local d = math.floor((y - 41) * 2.7)
    for x = 0, W - 1 do dith(x, y, d, C.dMagenta) end
  end
  rect(0, 48, W, 2, C.dMagenta)
  for y = 50, 54 do
    local d = math.floor((y - 49) * 3.2)
    for x = 0, W - 1 do dith(x, y, d, C.red) end
  end
  rect(0, 55, W, 3, C.red)
  for y = 58, 60 do
    local d = math.floor((y - 57) * 5.0)
    for x = 0, W - 1 do dith(x, y, d, C.salmon) end
  end
  rect(0, 61, W, 2, C.salmon)
  -- the sun is just under the horizon: the brightest line in the picture
  rect(0, 63, W, 1, C.amber)
  for x = 0, W - 1 do
    dith(x, 62, math.floor(6 + 8 * math.sin(x * 0.021)), C.amber)
    if hash(x, 3) % 4 == 0 then pix(x, 63, C.white) end
  end

  ------------------------------------------------------- rain, far off
  for i = 1, 20 do
    local x = hash(i, 11) % W
    local y = 14 + (hash(i, 12) + math.floor(sec() * 16)) % 40
    if hash(i, 13) % 3 ~= 0 then
      pix(x, y, C.slate)
      pix(x, y + 1, C.slate)
      pix(x - 1, y + 2, C.teal)
    end
  end

  ------------------------------------------------ far rooftops, hazed
  fill(FAR, C.slate)
  rim(FAR, C.salmon)
  for _, c in ipairs({{40,56,5,12},{110,53,4,9},{170,54,5,10},{226,60,4,11}}) do
    rect(c[1], c[2], c[3], c[4], C.slate)
    hline(c[1], c[2], c[3], C.salmon)
  end
  vline(150, 55, 10, C.slate)
  hline(147, 58, 7, C.slate)
  for _, w in ipairs({{12,78},{46,82},{80,70},{93,73},{122,78},
                      {142,74},{176,72},{203,76},{228,79}}) do
    rect(w[1], w[2], 2, 2, C.amber)
  end
  rect(60, 80, 2, 1, C.salmon)

  ------------------------------------------------ middle rooftops
  fill(MID, C.dSlate)
  rim(MID, C.slate)
  -- chimney stacks are what makes a roofline a roofline: same mass, lit edge
  for _, c in ipairs({{18,90,6,12},{74,82,5,14},{118,80,6,12},
                      {158,90,5,10},{206,86,6,12}}) do
    rect(c[1], c[2], c[3], c[4], C.dSlate)
    hline(c[1], c[2], c[3], C.slate)
    vline(c[1], c[2], c[4], C.slate)
  end
  -- one sloped roof face, one column, one window still on
  for i = 0, 26 do
    rect(96 + i, 100 - i, 2, 34 + i, C.slate)
  end
  rect(186, 98, 3, 4, C.amber)
  dith(190, 99, 9, C.salmon)
  dith(191, 101, 6, C.red)

  ------------------------------------------------ the nearest roof
  fill(NEAR, C.ink)
  rim(NEAR, C.dSlate)
  -- a stair bulkhead on the near roof: the one piece of rooftop furniture
  rect(70, 104, 9, 14, C.ink)
  hline(70, 104, 9, C.slate)
  vline(70, 104, 14, C.dSlate)
  rect(73, 108, 3, 4, C.amber)
  -- wet slate catching what is left of the sky: a dozen glints, no texture
  for i = 1, 26 do
    local x = 4 + hash(i, 61) % 232
    local y = 118 + hash(i, 62) % 16
    if hash(i, 63) % 3 == 0 then pix(x, y, C.dSlate) end
  end

  ------------------------------------------------- the pane itself
  -- a top rail and one mullion: two bars are enough to say "window"
  rect(0, 8, W, 3, C.ink)
  rect(104, 11, 4, H - 11, C.ink)
  hline(104, 11, 4, C.dSlate)
  hline(0, 10, W, C.dSlate)
  rect(0, H - 3, W, 3, C.ink)
  hline(0, H - 4, W, C.dSlate)

  ------------------------------------------------- rain on this side
  -- beads, drawn as lenses: pale body, bright foot, dark edge where the
  -- glass bends the picture away from you
  for _, b in ipairs(BEADS) do
    local x, y, len = b[1], b[2], b[3]
    for j = 0, len - 3 do
      pix(x, y + j, C.ltGray)
      if j > 0 then pix(x + 1, y + j, C.slate) end
    end
    rect(x, y + len - 2, 2, 2, C.white)
    pix(x + 2, y + len - 2, C.ltGray)
    pix(x - 1, y + 1, C.ink)
    pix(x + 2, y + 2, C.ink)
    pix(x - 1, y + len - 1, C.ink)
    pix(x, y + len, C.ink)
    pix(x + 1, y + len, C.slate)
  end

  -- two that are close enough to the pane to be their own shape
  for _, b in ipairs({ { 60, 22, 10 }, { 176, 40, 9 } }) do
    local x, y, len = b[1], b[2], b[3]
    for j = 0, len - 3 do
      pix(x, y + j, C.ltGray)
      pix(x + 1, y + j, C.slate)
    end
    rect(x - 1, y + len - 3, 3, 3, C.white)
    pix(x + 2, y + len - 3, C.ltGray)
    pix(x + 1, y + len, C.ltGray)
    pix(x - 1, y + 1, C.ink)
    pix(x - 2, y + 2, C.ink)
    pix(x + 2, y + 3, C.ink)
    pix(x - 1, y + len, C.ink)
    pix(x, y + len + 1, C.ink)
  end

  for i = 1, 24 do
    local x = 4 + hash(i, 41) % (W - 8)
    local y = 16 + hash(i, 42) % 114
    local s = hash(i, 43) % 4
    if s == 0 then
      pix(x, y, C.white)
      pix(x + 1, y, C.ltGray)
      pix(x, y + 1, C.ltGray)
      pix(x, y + 2, C.ink)
    elseif s == 1 then
      pix(x, y, C.ltGray)
    end
  end

  for i = 1, #RUNNERS do
    local r = RUNNERS[i]
    local hy = runner_y(r)
    local hx = run_x(r.x, hy, r.ph)
    local trail = 34
    for k = 1, trail do
      local ty = hy - k
      if ty > 12 then
        local d = math.floor(13 * (1 - k / trail) * 1.5)
        local tx = run_x(r.x, ty, r.ph)
        dith(tx, ty, d, C.ltGray)
        dith(tx - 1, ty, math.floor(d * 0.45), C.dBlue)
        if d > 9 then dith(tx + 1, ty, d - 7, C.slate) end
      end
    end
    rect(hx, hy, 2, 2, C.white)
    pix(hx - 1, hy, C.ink)
    pix(hx + 2, hy, C.ltGray)
    pix(hx, hy + 2, C.slate)
  end
end
