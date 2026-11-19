-- title: Test Tone
-- author: Cass
-- desc: an arpeggio you can see. four notes, drawn as density.
-- script: lua

-- The chip's pulse voice: 8 of every 32 samples high. The notes climb, so
-- the same shape fits more cycles in the same width. Pitch as density.
local NOTES={40,45,49,52}      -- E3 A3 C#4 E4
local CYC={3,4,5,6}            -- cycles across the frame
local NAMES={"E3","A3","C#4","E4"}
local DUTY=0.25

local X0,W,YHI,YLO=8,224,32,110
local HOLD=90                  -- ticks per note

local function hlin(a,b,y,c) line(a,y,b,y,c) end
local function vlin(x,a,b,c) line(x,a,x,b,c) end

local cur=0

-- one note's trace, revealed up to sx
local function trace(k,sx,c)
  local cw=W/k
  for i=0,math.ceil(k)-1 do
    local xs=X0+i*cw
    local xh=xs+cw*DUTY
    local xe=xs+cw
    local a=math.max(xs,X0)
    local b=math.min(xe,X0+W)
    if a<sx then
      local hi=math.min(b,xh)
      if a<hi then hlin(math.floor(a),math.floor(hi),YHI,c); hlin(math.floor(a),math.floor(hi),YHI+1,c) end
      local fall=math.max(a,xh)
      if fall<b then hlin(math.floor(fall),math.floor(b),YLO,c); hlin(math.floor(fall),math.floor(b),YLO+1,c) end
      if xs>=a and xs<=b then vlin(math.floor(xs),YHI,YLO+1,c) end
      if xh>=a and xh<=b then vlin(math.floor(xh),YHI,YLO+1,c) end
    end
  end
end

local drone=0
function TIC()
  local t=time()
  local i=math.floor(t/HOLD)%4+1
  if i~=cur then
    cur=i
    sfx(0,NOTES[i],-1,0,15,0)
  end
  if drone==0 then sfx(0,33,-1,1,7,0) end
  drone=(drone+1)%240

  cls(0)
  rect(0,0,240,8,15)

  for _,y in ipairs({YHI,YLO}) do
    hlin(2,7,y,15); hlin(232,237,y,15)
  end

  local ph=(t%HOLD)/HOLD
  local sx=X0+W*ph

  -- the whole note, dim; the swept part, bright
  trace(CYC[cur],X0+W,15)
  trace(CYC[cur],sx,11)

  -- the sweep, one pass per note
  vlin(math.floor(sx),YHI-6,YLO+6,4)
  circ(math.floor(sx),YHI-8,2,4)

  for i=0,CYC[cur] do vlin(math.floor(X0+i*W/CYC[cur]),116,119,15) end

  print(NAMES[cur].."  "..CYC[cur].." per frame",8,14,4)
  print("25% pulse",176,14,14)
end
