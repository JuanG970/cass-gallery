-- title:  Heat Off the Tarmac
-- author: Cass
-- desc:   three o'clock, two pumps, and the air above the road going wrong
-- script: lua

local C = {
  ink=0, magenta=1, red=2, salmon=3, amber=4,
  lime=5, green=6, teal=7, navy=8, blue=9,
  sky=10, haze=11, white=12, liteGray=13, gray=14, dark=15,
}

local W, H, HZ = 240, 136, 58

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

-- left edge of the concrete forecourt at row y
local function apron_edge(y)
  return 96 - math.floor((y - HZ) * 0.20)
end

-- heat only bends what is far away: strongest at the horizon, gone by the kerb
local function shim(y)
  if y < 55 or y > 95 then return 0 end
  local amp = 1.2 * (1 - (y - 55) / 40)
  if amp < 0 then amp = 0 end
  return math.floor(math.sin(y * 0.55 + sec() * 3.770) * amp + 0.5)
end

function TIC()
  ticks = ticks + 1
  cls(C.sky)

  -- sky: flat hot blue, one pale band burning at the horizon
  rect(0, 0, W, 8, C.blue)
  rect(0, 8, W, 38, C.sky)
  rect(0, 46, W, 5, C.haze)

  -- sun, high and to the right: everything below casts left
  circ(198, 20, 8, C.haze)
  circ(198, 20, 5, C.white)

  -- wires, then the two poles in front of them
  for i = 0, 2 do
    local x0 = 10 + i * 12
    local y0 = 30 + i * 2
    local sag = 14 + i * 3 + math.sin(sec() * 1.257 + i) * 1.5
    for x = x0, W - 1 do
      local u = (x - x0) / (W - 1 - x0)
      pix(x, y0 + math.floor(sag * math.sin(math.pi * u) + 0.5), C.dark)
    end
  end
  rect(20, 26, 4, 74, C.dark)
  rect(6, 30, 36, 2, C.dark)
  rect(71, 40, 2, 18, C.dark)
  rect(65, 43, 14, 1, C.dark)

  -- scrub along the far verge, then the sunlit grass itself
  rect(0, 51, W, 6, C.lime)
  rect(0, 57, W, 1, C.green)
  for x = 0, W - 1, 4 do
    local h = hash(x, 5) % 9
    if h < 3 then rect(x, 51 - h, 2, h + 2, C.green) end
  end
  for x = 0, W - 1, 37 do
    if hash(x, 9) % 3 == 0 then rect(x, 47, 5, 5, C.green) end
  end

  -- the near pole's shadow lies short and to the left
  for y = 100, H - 1 do
    local x0 = 21 - math.floor((y - 100) * 1.15)
    local cut = 0
    if x0 < 0 then cut = -x0; x0 = 0 end
    local w = 5 - cut
    if w > 0 then hline(x0, y, w, C.dark) end
  end

  -- tarmac left, concrete forecourt right, the far edge shivering
  for y = HZ, H - 1 do
    local e = apron_edge(y) + shim(y)
    if e < 4 then e = 4 end
    rect(0, y, e - 3, 1, C.gray)
    rect(e - 3, y, 2, 1, C.dark)
    rect(e - 1, y, 2, 1, C.white)
    rect(e + 1, y, W - e - 1, 1, C.liteGray)
  end

  -- the roof's shadow: under the canopy, then raking forward-left across the kerb
  for y = 94, 119 do
    hline(112, y, 124, C.dark)
  end
  for j = 1, 12 do
    local y = 119 + j
    local x0 = 112 - j * 5
    local x1 = 235 - j * 5
    if x0 < 0 then x0 = 0 end
    hline(x0, y, x1 - x0, C.dark)
  end

  for y = HZ, H - 1 do
    local e = apron_edge(y)
    for x = 0, e - 6, 3 do
      if hash(x, y) % 23 == 0 then pix(x, y, C.liteGray) end
    end
  end

  -- centre line: dashes receding, shaking in the heat
  for i = 0, 9 do
    local y = 61 + i * 8
    local cx = math.floor(apron_edge(y) / 2) + shim(y)
    local w = 1 + math.floor(i * 0.7)
    local h = 2 + math.floor(i * 0.55)
    if cx + w < apron_edge(y) - 4 then
      rect(cx, y, w, h, C.white)
    end
  end

  -- sign plate, riding above the roof
  rect(166, 48, 40, 12, C.red)
  hline(170, 52, 32, C.white)
  hline(170, 56, 22, C.white)
  vline(168, 60, 14, C.dark)
  vline(203, 60, 14, C.dark)

  -- canopy: a thin bright roof, a shallow recess, and nothing else
  rect(114, 74, 122, 4, C.white)
  hline(114, 78, 122, C.liteGray)
  hline(114, 79, 122, C.ink)
  rect(118, 80, 114, 14, C.dark)

  -- pillars drop past the recess to the concrete
  for _, px in ipairs({124, 220}) do
    rect(px, 80, 5, 32, C.liteGray)
    vline(px, 80, 32, C.white)
    rect(px - 2, 112, 9, 2, C.ink)
  end

  -- two pumps out front: lit at the base, each throwing a hard shadow left
  for _, px in ipairs({148, 176}) do
    for j = 0, 3 do
      hline(px - 3 - j * 4, 112 + j, 17, C.dark)
    end
    rect(px, 88, 14, 24, C.gray)
    rect(px + 1, 89, 12, 22, C.white)
    rect(px + 1, 91, 12, 5, C.red)
    rect(px + 3, 98, 6, 5, C.ink)
    rect(px + 1, 109, 12, 2, C.gray)
    vline(px + 14, 96, 12, C.white)
    hline(px + 14, 107, 3, C.white)
    rect(px - 1, 111, 16, 2, C.ink)
  end

  -- the horizon itself will not hold still
  for x = 0, W - 1 do
    local w = math.floor(math.sin(x * 0.33 + sec() * 2.513) * 1.2 + 0.5)
    pix(x, 57 + w, C.green)
  end
end
