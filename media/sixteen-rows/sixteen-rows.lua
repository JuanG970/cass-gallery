-- title: Sixteen Rows
-- author: Cass
-- desc: one whole pattern on one screen: four channels, sixteen rows, the playhead walking it.
-- script: lua

-- A tracker screen at 240x136. No scrolling: all sixteen rows of the pattern
-- are visible at once, so the loop is legible as a whole and the playhead is
-- the only moving part that matters.
--
-- The sound is real tracker data, not the empty-slot oscillator: five samples
-- with per-step volume envelopes, a chord column that arpeggiates the triad,
-- a vibrato track on the lead, and a pseudo-random waveform for the drums.

local NOTE_NAMES={"C-","C#","D-","D#","E-","F-","F#","G-","G#","A-","A#","B-"}

local ROWS=16
local TPR=150               -- ms per row: 16 rows x 150 ms = 2.4 s
local GRID_Y=16
local PITCH=7

-- palette slots (Sweetie16)
local BG, BAND, RULE = 0, 15, 8
local C_NOTE, C_HEX, C_DIM, C_EMPTY = 10, 7, 14, 8
local C_PLAY, C_PLAYHEX, C_PLAYROW = 4, 3, 12
local C_LABEL, C_ACCENT, C_METER, C_PEAK = 13, 3, 7, 4

-- ---------------------------------------------------------------- the pattern
-- P[ch][row] = { note, sample, volume }
local P={{},{},{},{}}
local function put(ch,row,note,smp,vol) P[ch][row]={note,smp,vol} end

-- four bars of four rows each: Am / F / C / G
-- TIC-80 note 45 is A-4 (440 Hz), so the bass sits on 17..24
-- the triangle wavetable holds one cycle over 32 values, so it sounds an
-- octave below its note number: note 33 on this instrument is A-2.
for _,b in ipairs({{1,33},{5,29},{9,36},{13,31}}) do put(1,b[1],b[2],1,14) end

-- the arpeggio channel: root, plus a sample whose chord column holds the triad
local ARP={{45,2},{41,6},{48,6},{43,6}}
for bar=1,4 do
  for r=1,2 do
    local row=(bar-1)*4+(r-1)*2+1
    put(2,row,ARP[bar][1],ARP[bar][2],r==1 and 15 or 13)
  end
end

-- lead: one note per bar, chord tones only
for _,m in ipairs({{3,52},{7,48},{11,55},{15,50}}) do put(3,m[1],m[2],3,14) end

-- drums: hats on the off-beats, snare on the backbeat
for r=2,16,2 do put(4,r,72,4,4) end
put(4,5,43,5,9)
put(4,13,43,5,9)

-- ---------------------------------------------------------------- sequencer
local lastRow=-1

local function trigger(row)
  for ch=1,4 do
    local e=P[ch][row]
    if e then
      local dur=-1
      if ch==4 then dur = (e[2]==5) and 12 or 6 end
      sfx(e[2],e[1],dur,ch-1,e[3],0)
    end
  end
end

-- ---------------------------------------------------------------- drawing
local DISP={-12,0,0,0}   -- channel 1's instrument sounds an octave down

local function name(ch,n)
  n=n+DISP[ch]
  return NOTE_NAMES[n%12+1]..(math.floor(n/12)+1)
end

-- how long ago a channel last sounded, as 0..1
local function level(ch,row,frac)
  for k=0,ROWS-1 do
    local r=(row-1-k)%ROWS+1
    if P[ch][r] then
      local lv=1-(k+frac)/2.4
      if lv<0 then lv=0 end
      return lv*P[ch][r][3]/15
    end
  end
  return 0
end

function TIC()
  local t=time()
  local row=math.floor(t/TPR)%ROWS+1
  local frac=(t%TPR)/TPR

  if row~=lastRow then
    lastRow=row
    trigger(row)
  end

  cls(BG)

  -- the flat band the capture harness measures; nothing is drawn on rows 0-6
  rect(0,0,240,7,BAND)

  -- channel strip: four labels, each with its own meter
  for ch=1,4 do
    local x=18+(ch-1)*53
    print("CH"..ch,x,7,C_LABEL)
    line(x+22,10,x+48,10,RULE)
    local lv=level(ch,row,frac)
    local w=math.floor(26*lv+0.5)
    if w>0 then line(x+22,10,x+21+w,10,C_METER) end
    if lv>0.6 then pix(x+22+w,10,C_PEAK) end
  end
  line(0,15,240,15,RULE)

  -- column rules, drawn under the playhead
  for _,x in ipairs({60,113,166}) do line(x,GRID_Y,x,127,RULE) end

  for r=1,ROWS do
    local y=GRID_Y+(r-1)*PITCH
    local playing=(r==row)
    if playing then
      rect(0,y-1,240,PITCH,9)
      tri(0,y-1,4,y+2,0,y+5,C_ACCENT)
    end
    local beat=(r-1)%4==0
    print(string.format("%02d",r-1),4,y,
          playing and C_PLAYROW or (beat and C_LABEL or C_DIM))
    for ch=1,4 do
      local x=18+(ch-1)*53
      local e=P[ch][r]
      if e then
        print(name(ch,e[1]),x,y,playing and C_PLAY or C_NOTE)
        print(string.format("%X%X",e[2],e[3]),x+20,y,playing and C_PLAYHEX or C_HEX)
      else
        pix(x,y+3,C_EMPTY)
      end
    end
  end

  line(0,128,240,128,RULE)
  print("PATTERN 00",5,130,C_DIM)
  print("100 BPM",193,130,C_HEX)
end
