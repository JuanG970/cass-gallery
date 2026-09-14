-- title: Fireworks Over the Harbor
-- author: Juan Gonzalez
-- desc: Fireworks launching and exploding over a dark harbor with city silhouette
-- script: lua

local C = {
  black = 0,
  dMagenta = 1,
  dRed = 2,
  redOrange = 3,
  orange = 4,
  yellowGreen = 5,
  green = 6,
  dTeal = 7,
  dBlue = 8,
  blue = 9,
  lBlue = 10,
  paleCyan = 11,
  white = 12,
  lGray = 13,
  mGray = 14,
  dSlate = 15,
}

local function hlin(x, y, w, color)
  for i = 0, w - 1 do
    local px = x + i
    if px >= 0 and px < 240 and y >= 0 and y < 136 then
      pix(px, y, color)
    end
  end
end

local function rect(x, y, w, h, color)
  for j = 0, h - 1 do
    hlin(x, y + j, w, color)
  end
end

local function llin(x0, y0, x1, y1, color)
  local dx = math.abs(x1 - x0)
  local dy = math.abs(y1 - y0)
  local sx = x0 < x1 and 1 or -1
  local sy = y0 < y1 and 1 or -1
  local err = dx - dy
  local x, y = x0, y0
  while true do
    if x >= 0 and x < 240 and y >= 0 and y < 136 then
      pix(x, y, color)
    end
    if x == x1 and y == y1 then break end
    local e2 = 2 * err
    if e2 > -dy then err = err - dy; x = x + sx end
    if e2 < dx then err = err + dx; y = y + sy end
  end
end

-- Draw a bright cross pixel (2x2 with center)
local function bpix(x, y, color)
  if x >= 0 and x < 240 and y >= 0 and y < 136 then
    pix(x, y, color)
  end
  if x+1 >= 0 and x+1 < 240 and y >= 0 and y < 136 then
    pix(x+1, y, color)
  end
  if x >= 0 and x < 240 and y+1 >= 0 and y+1 < 136 then
    pix(x, y+1, color)
  end
  if x-1 >= 0 and x-1 < 240 and y >= 0 and y < 136 then
    pix(x-1, y, color)
  end
  if x >= 0 and x < 240 and y-1 >= 0 and y-1 < 136 then
    pix(x, y-1, color)
  end
end

-- Star field
local stars = {}
local function init_stars()
  stars = {}
  for i = 1, 35 do
    table.insert(stars, {
      x = math.random(0, 239),
      y = math.random(0, 75),
      bright = math.random() < 0.25,
      phase = math.random() * 60,
      period = 80 + math.random() * 60,
    })
  end
end

-- City silhouette
local city_skyline = {}
local function init_city()
  city_skyline = {}
  local x = 0
  while x < 240 do
    local w = 6 + math.random(12)
    local h = 8 + math.random(24)
    local bld = {x = x, w = w, h = h}
    bld.windows = {}
    for wy = 2, h - 3, 3 do
      for wx = 2, w - 3, 4 do
        if math.random() < 0.30 then
          table.insert(bld.windows, {x = wx, y = wy})
        end
      end
    end
    table.insert(city_skyline, bld)
    x = x + w + math.random(1, 3)
  end
end

-- Firework state
local fireworks = {}
local particles = {}
local flashes = {}  -- bright initial flash at explosion center

local function spawn_firework()
  local fx = 30 + math.random(180)
  local fy = 108
  local tx = fx + (math.random() - 0.5) * 25
  local ty = 12 + math.random(35)
  local palettes = {
    {C.redOrange, C.orange, C.white, C.yellowGreen},
    {C.dMagenta, C.redOrange, C.paleCyan, C.white},
    {C.paleCyan, C.lBlue, C.white, C.lGray},
    {C.green, C.lBlue, C.white, C.paleCyan},
    {C.dRed, C.orange, C.yellowGreen, C.white},
    {C.dMagenta, C.paleCyan, C.white, C.lGray},
    {C.orange, C.white, C.redOrange, C.yellowGreen},
  }
  local pal = palettes[math.random(#palettes)]
  table.insert(fireworks, {
    x = fx, y = fy,
    tx = tx, ty = ty,
    pal = pal,
    age = 0,
    phase = "ascending",
    trail = {},
  })
end

local function explode(fw)
  local cx, cy = fw.tx, fw.ty
  local pal = fw.pal
  
  -- Initial bright flash
  table.insert(flashes, {x = cx, y = cy, life = 1.0, decay = 0.06})
  
  -- Main explosion: 50-70 particles in a ring
  local n = 50 + math.random(20)
  for i = 1, n do
    local angle = (i / n) * math.pi * 2 + math.random() * 0.1
    local speed = 0.5 + math.random() * 1.0
    local color_idx = (i % 4) + 1
    table.insert(particles, {
      x = cx, y = cy,
      vx = math.cos(angle) * speed,
      vy = math.sin(angle) * speed,
      color = pal[color_idx],
      life = 1.0,
      decay = 0.005 + math.random() * 0.003,
      gravity = 0.012,
      drag = 0.975,
      bright = true,
    })
  end
  
  -- Inner sparks: slower, shorter-lived
  for i = 1, 12 do
    local angle = math.random() * math.pi * 2
    local speed = 0.15 + math.random() * 0.35
    table.insert(particles, {
      x = cx, y = cy,
      vx = math.cos(angle) * speed,
      vy = math.sin(angle) * speed,
      color = C.white,
      life = 1.0,
      decay = 0.015,
      gravity = 0.008,
      drag = 0.96,
      bright = true,
    })
  end
end

local water_y = 110
local t = 0
local launch_timer = 0
local launch_interval = 30

function TIC()
  t = t + 1
  cls(C.black)

  -- === SKY ===
  for y = 0, water_y - 1 do
    if y >= water_y - 6 then
      hlin(0, y, 240, C.dSlate)
    elseif y >= water_y - 14 then
      hlin(0, y, 240, C.dBlue)
    end
  end

  -- Stars
  for _, s in ipairs(stars) do
    local twinkle = math.sin((t + s.phase) / s.period * math.pi * 2)
    if s.bright then
      if twinkle > 0.2 then
        pix(s.x, s.y, C.white)
      end
    else
      if twinkle > 0.4 then
        pix(s.x, s.y, C.lGray)
      end
    end
  end

  -- === FIREWORKS ===
  launch_timer = launch_timer + 1
  if launch_timer >= launch_interval then
    spawn_firework()
    launch_timer = 0
    launch_interval = 20 + math.random(25)
  end

  -- Ascending rockets
  for i = #fireworks, 1, -1 do
    local fw = fireworks[i]
    if fw.phase == "ascending" then
      fw.age = fw.age + 1
      local dx = fw.tx - fw.x
      local dy = fw.ty - fw.y
      local dist = math.sqrt(dx * dx + dy * dy)
      local speed = 2.0
      if dist < speed then
        fw.x = fw.tx
        fw.y = fw.ty
        fw.phase = "exploding"
        explode(fw)
        table.remove(fireworks, i)
      else
        fw.x = fw.x + (dx / dist) * speed
        fw.y = fw.y + (dy / dist) * speed
        table.insert(fw.trail, {x = fw.x, y = fw.y})
        if #fw.trail > 10 then table.remove(fw.trail, 1) end
      end
      -- Draw trail
      for j, tr in ipairs(fw.trail) do
        local c = j > #fw.trail - 4 and C.white or C.lGray
        pix(math.floor(tr.x), math.floor(tr.y), c)
      end
      -- Bright head
      pix(math.floor(fw.x), math.floor(fw.y), C.white)
      pix(math.floor(fw.x), math.floor(fw.y) + 1, C.lGray)
    end
  end

  -- Flashes (bright initial burst)
  for i = #flashes, 1, -1 do
    local fl = flashes[i]
    fl.life = fl.life - fl.decay
    if fl.life <= 0 then
      table.remove(flashes, i)
    else
      local r = math.floor(fl.life * 6) + 1
      local c = fl.life > 0.5 and C.white or C.lGray
      -- Draw a small filled disc
      for dy = -r, r do
        local w = math.floor(math.sqrt(math.max(0, r * r - dy * dy)) + 0.5)
        hlin(fl.x - w, fl.y + dy, 2 * w + 1, c)
      end
    end
  end

  -- Explosion particles
  for i = #particles, 1, -1 do
    local p = particles[i]
    p.x = p.x + p.vx
    p.y = p.y + p.vy
    p.vx = p.vx * p.drag
    p.vy = p.vy * p.drag + p.gravity
    p.life = p.life - p.decay

    if p.life <= 0 then
      table.remove(particles, i)
    else
      local px = math.floor(p.x)
      local py = math.floor(p.y)
      if px >= 0 and px < 240 and py >= 0 and py < water_y then
        if p.life > 0.7 then
          -- Bright phase: draw cross pixel
          if p.bright then
            bpix(px, py, p.color)
          else
            pix(px, py, p.color)
          end
        elseif p.life > 0.4 then
          pix(px, py, p.color)
        elseif p.life > 0.2 then
          -- Dim phase
          local dim = C.mGray
          if p.color == C.white or p.color == C.lGray then
            dim = C.mGray
          elseif p.color == C.orange or p.color == C.redOrange then
            dim = C.dRed
          elseif p.color == C.paleCyan or p.color == C.lBlue then
            dim = C.dBlue
          else
            dim = C.dSlate
          end
          pix(px, py, dim)
        else
          if p.life > 0.1 and math.random() < 0.5 then
            pix(px, py, C.dSlate)
          end
        end
      end
    end
  end

  -- === CITY SILHOUETTE ===
  for _, bld in ipairs(city_skyline) do
    rect(bld.x, water_y - bld.h, bld.w, bld.h, C.black)
    hlin(bld.x, water_y - bld.h, bld.w, C.dBlue)
    for _, w in ipairs(bld.windows) do
      local flicker = (t + w.x * 7 + w.y * 13) % 200
      if flicker > 15 then
        pix(bld.x + w.x, water_y - bld.h + w.y, C.orange)
      end
    end
  end

  -- === WATER ===
  for y = water_y, 135 do
    if y < water_y + 3 then
      hlin(0, y, 240, C.dSlate)
    elseif y < water_y + 10 then
      hlin(0, y, 240, C.dBlue)
    else
      hlin(0, y, 240, C.black)
    end
  end

  -- Water reflections of fireworks
  for _, p in ipairs(particles) do
    if p.life > 0.3 then
      local px = math.floor(p.x)
      local reflect_y = water_y + (water_y - math.floor(p.y))
      if reflect_y >= water_y and reflect_y < 136 and px >= 0 and px < 240 then
        local wobble = math.sin(t * 0.08 + px * 0.3) * 1
        local rx = px + math.floor(wobble)
        if rx >= 0 and rx < 240 then
          if p.life > 0.6 then
            pix(rx, reflect_y, C.dBlue)
          else
            pix(rx, reflect_y, C.dSlate)
          end
        end
      end
    end
  end

  -- Water reflections of windows
  for _, bld in ipairs(city_skyline) do
    for _, w in ipairs(bld.windows) do
      local flicker = (t + w.x * 7 + w.y * 13) % 200
      if flicker > 15 then
        local wx = bld.x + w.x
        local wy = water_y - bld.h + w.y
        local reflect_y = water_y + (water_y - wy)
        if reflect_y < 136 then
          local wobble = math.sin(t * 0.06 + wx * 0.4) * 1
          local rx = wx + math.floor(wobble)
          if rx >= 0 and rx < 240 then
            pix(rx, reflect_y, C.dRed)
          end
        end
      end
    end
  end

  -- Horizon glow
  hlin(0, water_y - 1, 240, C.dBlue)
  hlin(0, water_y, 240, C.dSlate)
end

init_stars()
init_city()
