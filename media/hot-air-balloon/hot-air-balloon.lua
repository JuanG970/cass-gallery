-- title: Hot Air Balloon at Night
-- author: Cass
-- desc: A hot air balloon drifting across a starry night sky with a pulsing burner
-- script: lua

local C = {
  bg = 0, bg2 = 8,
  balloon = 1, stripe = 4,
  glow = 3, flame = 12,
  basket = 15, rope = 14,
  s1 = 12, s2 = 13, s3 = 14,
}

-- star field (deterministic)
local stars = {}
math.randomseed(42)
for i = 1, 28 do
  stars[i] = {
    x = math.random(0, 239),
    y = math.random(0, 80),
    tier = math.random() < 0.2 and 3 or (math.random() < 0.5 and 2 or 1),
    phase = math.random() * 60,
    period = 80 + math.random() * 60,
  }
end

function TIC()
  local t = time() / 60.0
  cls(C.bg)

  -- horizon glow band (3 rows of dark blue)
  line(0, 112, 239, 112, C.bg2)
  line(0, 113, 239, 113, C.bg2)
  line(0, 114, 239, 114, C.bg2)

  -- stars with slow twinkle
  for _, s in ipairs(stars) do
    local b = 0.5 + 0.5 * math.sin((t + s.phase) * 6.283 / s.period)
    local col
    if s.tier == 3 then col = b > 0.25 and C.s1 or C.s2
    elseif s.tier == 2 then col = b > 0.3 and C.s2 or C.s3
    else col = b > 0.5 and C.s3 or nil end
    if col then pix(s.x, s.y, col) end
  end

  -- balloon position: gentle horizontal drift + subtle vertical bob
  local bx = 120 + math.sin(t * 0.12) * 22
  local by = 50 + math.sin(t * 0.18) * 3
  local r = 38

  -- envelope (filled circle)
  circ(bx, by, r, C.balloon)

  -- neck (narrowed bottom — triangle from envelope base to burner)
  tri(bx - 8, by + r, bx + 8, by + r, bx, by + r + 5, C.balloon)

  -- vertical orange stripes (panels)
  for i = -r + 4, r - 4, 8 do
    local h = math.floor(math.sqrt(math.max(0, r * r - i * i)) + 0.5)
    line(bx + i, by - h + 3, bx + i, by + h - 3, C.stripe)
  end

  -- burner flame (pulsing warm glow)
  local fy = by + r + 8
  local pulse = 0.7 + 0.3 * math.sin(t * 2.5)
  circ(bx, fy, math.floor(4 * pulse), C.glow)
  circ(bx, fy, 2, C.flame)

  -- basket
  rect(bx - 6, fy + 7, 12, 5, C.basket)

  -- suspension ropes
  line(bx - 6, fy + 7, bx - 5, by + r + 5, C.rope)
  line(bx + 6, fy + 7, bx + 5, by + r + 5, C.rope)
end
