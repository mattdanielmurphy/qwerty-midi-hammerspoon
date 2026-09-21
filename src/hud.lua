local hsWebview = require("hs.webview")
local hsUsercontent = require("hs.webview.usercontent")

local config = require("config")
local midi = require("midi")
local transposer = require("transposer")
local arpeggiator = require("arpeggiator")

local state = config.state
local SCALES = config.SCALES
local NOTE_NAMES = config.NOTE_NAMES
local numberRowControls = config.numberRowControls
local ARP_DIRECTIONS = state.ARP_DIRECTIONS
local ARP_RATES = state.ARP_RATES
local ARP_GATES = state.ARP_GATES

local HTML_UI_CONTENT = require("ui_html")
local webviewGeneration = 0
local lastHeartbeat = 0
local evalFailCount = 0
local lastPongTime = 0
local lastLatencyMs = 0
local pendingPingTime = 0

local function hudLog(msg)
  local line = os.date("%H:%M:%S") .. " [HUD]: " .. tostring(msg) .. "\n"
  print("QWERTY MIDI HUD: " .. msg)
  local f1 = io.open("/tmp/midi_startup.log", "a")
  if f1 then f1:write(line); f1:close() end
  local f2 = io.open("/Users/matt/projects/qwerty-midi-hammerspoon/tmp/qwerty_midi_debug.log", "a")
  if f2 then f2:write(line); f2:close() end
end

_G.activeWatchers = _G.activeWatchers or {}


local controlsModule = nil

local function setControlsModule(m)
  controlsModule = m
end

state.textInputActive = false

local pendingSpotlightInfo = nil
local pendingActiveArpPitch = nil
local hudUpdateScheduled = false
local lastFrameScale = nil
local _savedNormalHeight = nil
local updateWebviewHud = nil

state.activeSurface = state.activeSurface or hs.settings.get("qwertyMidi_activeSurface") or "qwerty"

local function safeEvaluateJS(js)
  if not _G.activeWatchers.midiWebview then return end
  local ok, err = pcall(function()
    _G.activeWatchers.midiWebview:evaluateJavaScript(js)
  end)
  if not ok then
    hudLog("evaluateJavaScript error: " .. tostring(err))
  end
  return ok
end

local function updateSingleKeyState(code, pressed, latched)
  if not _G.activeWatchers.midiWebview or not _G.activeWatchers.domIsReady then return end
  safeEvaluateJS(string.format("if (window.updateKeyState) window.updateKeyState(%d, %s, %s);",
    tonumber(code) or 0, pressed and "true" or "false", latched and "true" or "false"))
end

local function updateNanoKeyControl(controlId, value, pressed, layer, extra)
  if not _G.activeWatchers.midiWebview or not _G.activeWatchers.domIsReady then return end
  local extraJson = "null"
  if type(extra) == "table" then
    local ok, res = pcall(hs.json.encode, extra)
    if ok and res then extraJson = res end
  end
  local js = string.format("if (window.updateNanoKeyState) window.updateNanoKeyState(%q, %s, %s, %q, %s);",
    tostring(controlId or ""),
    value and tostring(value) or "null",
    pressed and "true" or "false",
    tostring(layer or "base"),
    extraJson)
  safeEvaluateJS(js)
end

local function isNanokeyConnected()
  if state.nanokeyConnected ~= nil then
    return state.nanokeyConnected == true
  end
  if _G.activeWatchers and _G.activeWatchers.nanokey and _G.activeWatchers.nanokey.isConnected then
    return _G.activeWatchers.nanokey.isConnected() == true
  end
  return false
end

local function getDesiredBaseHeight()
  return isNanokeyConnected() and 600 or 280
end

local function updateConnectionStatus(connected)
  state.nanokeyConnected = (connected == true)
  if _G.activeWatchers.midiWebview then
    local effectiveScale = state.zoomLevel * state.BASE_HUD_SCALE
    local NOTIF_BAND = math.floor(50 * effectiveScale)
    local baseH = (connected == true) and 600 or 280
    local targetH = math.floor(baseH * effectiveScale) + NOTIF_BAND
    local curFrame = _G.activeWatchers.midiWebview:frame()
    if curFrame.h ~= targetH then
      local diffH = targetH - curFrame.h
      local screen = hs.screen.mainScreen():frame()
      local newY = math.max(screen.y, math.min(screen.y + screen.h - targetH, curFrame.y - diffH))
      _G.activeWatchers.midiWebview:frame({ x = curFrame.x, y = newY, w = curFrame.w, h = targetH })
      _G.activeWatchers.hudY = newY
      hs.settings.set("qwertyMidi_hudY", newY)
    end
    safeEvaluateJS(string.format("if (window.setNanokeyConnected) window.setNanokeyConnected(%s);", connected and "true" or "false"))
  end
  updateWebviewHud()
end

local function setSurfaceView(surface)
  surface = surface or "qwerty"
  state.activeSurface = surface
  hs.settings.set("qwertyMidi_activeSurface", surface)

  if _G.activeWatchers.midiWebview then
    local wv = _G.activeWatchers.midiWebview
    local curFrame = wv:frame()
    local effectiveScale = state.zoomLevel * state.BASE_HUD_SCALE
    local NOTIF_BAND = math.floor(50 * effectiveScale)
    local baseH = getDesiredBaseHeight()
    local targetH = math.floor(baseH * effectiveScale) + NOTIF_BAND
    
    local diffH = targetH - curFrame.h
    local screen = hs.screen.mainScreen():frame()
    local newY = math.max(screen.y, math.min(screen.y + screen.h - targetH, curFrame.y - diffH))
    wv:frame({ x = curFrame.x, y = newY, w = curFrame.w, h = targetH })
    _G.activeWatchers.hudY = newY
    hs.settings.set("qwertyMidi_hudY", newY)
  end

  safeEvaluateJS(string.format("if (window.onSurfaceChanged) window.onSurfaceChanged(%q);", tostring(surface)))
end

local PROPOSED_LAYOUT_MAP = {
  -- HOME ROW CONTROLS:
  [48] = { -- Tab
    base            = { name = "Smart Sus",   class = "ctrl-sus",          action = "sustain" },
    shift           = { name = "Classic Sus", class = "ctrl-sus",          action = "classicSustain" },
    opt             = { name = "Classic Sus", class = "ctrl-sus",          action = "classicSustain" },
    shift_opt       = { name = "Classic Sus", class = "ctrl-sus",          action = "classicSustain" },
    ctrl            = { name = "Panic!",      class = "ctrl-panic",        action = "panic" },
    shift_ctrl      = { name = "Panic!",      class = "ctrl-panic",        action = "panic" },
    ctrl_opt        = { name = "Panic!",      class = "ctrl-panic",        action = "panic" },
    ctrl_opt_shift  = { name = "Hard Reset",  class = "ctrl-panic",        action = "resetAll" },
  },
  [0] = { -- A
    base            = { name = "Arp",         class = "ctrl-arp",     action = "arpToggle" },
    shift           = { name = "Latch",       class = "ctrl-arp",     action = "arpLatchToggle" },
    opt             = { name = "Arp Link",    class = "ctrl-arptop",  action = "arpLinkToggle" },
    shift_opt       = { name = "Split Arp",   class = "ctrl-arpbot",  action = "splitArpToggle" },
    ctrl            = { name = "Bypass",      class = "ctrl-arp",     action = "arpBypassToggle" },
    shift_ctrl      = { name = "Bypass",      class = "ctrl-arp",     action = "arpBypassToggle" },
    ctrl_opt        = { name = "Pattern +",   class = "ctrl-arpdir",  action = "arpDirUp" },
    ctrl_opt_shift  = { name = "Pattern -",   class = "ctrl-arpdir",  action = "arpDirDown" },
  },
  [1] = { -- S
    base            = { name = "Random",      class = "ctrl-rand",    action = "randomScale" },
    shift           = { name = "Panic!",      class = "ctrl-panic",   action = "panic" },
    opt             = { name = "Rand Root",   class = "ctrl-root",    action = "randomRoot" },
    shift_opt       = { name = "Rand Mode",   class = "ctrl-mode",    action = "randomMode" },
    ctrl            = { name = "Reset All",   class = "ctrl-reset",   action = "resetAll" },
    shift_ctrl      = { name = "Panic!",      class = "ctrl-panic",   action = "panic" },
    ctrl_opt        = { name = "Rand Rhy",    class = "ctrl-rand",    action = "randomRhythm" },
    ctrl_opt_shift  = { name = "Rand All",    class = "ctrl-rand",    action = "randomAll" },
  },
  [2] = { -- D (Consolidated Octave)
    base            = { name = "Oct +",       class = "ctrl-oct",     action = "octaveUp" },
    shift           = { name = "Oct -",       class = "ctrl-oct",     action = "octaveDown" },
    opt             = { name = "TopOct +",    class = "ctrl-topoct",  action = "topOctUp" },
    shift_opt       = { name = "TopOct -",    class = "ctrl-topoct",  action = "topOctDown" },
    ctrl            = { name = "BotOct +",    class = "ctrl-oct",     action = "botOctUp" },
    shift_ctrl      = { name = "BotOct -",    class = "ctrl-oct",     action = "botOctDown" },
    ctrl_opt        = { name = "Oct Reset",   class = "ctrl-oct",     action = "octReset" },
    ctrl_opt_shift  = { name = "Oct Reset",   class = "ctrl-oct",     action = "octReset" },
  },
  [3] = { -- F (NEW FREED KEY: Master Arp & Track Loop Lock)
    base            = { name = "Arp Latch",   class = "ctrl-lock",    action = "arpLatchToggle" },
    shift           = { name = "Lock Loop",   class = "ctrl-lock",    action = "lockLoop" },
    opt             = { name = "Lock & Swap", class = "ctrl-lock",    action = "lockAndSwap" },
    shift_opt       = { name = "Lock 4 Trk",  class = "ctrl-lock",    action = "lockAllTracks" },
    ctrl            = { name = "Stop Loops",  class = "ctrl-mute",    action = "stopLoops" },
    shift_ctrl      = { name = "Stop All",    class = "ctrl-mute",    action = "panic" },
    ctrl_opt        = { name = "Freeze All",  class = "ctrl-lock",    action = "freezeAll" },
    ctrl_opt_shift  = { name = "Clear All",   class = "ctrl-mute",    action = "resetAll" },
  },
  [5] = { -- G (Consolidated Mode)
    base            = { name = "Mode +",      class = "ctrl-mode",    action = "modeUp" },
    shift           = { name = "Mode -",      class = "ctrl-mode",    action = "modeDown" },
    opt             = { name = "Mode +2",     class = "ctrl-mode",    action = "modeStep2Up" },
    shift_opt       = { name = "Mode -2",     class = "ctrl-mode",    action = "modeStep2Down" },
    ctrl            = { name = "Major",       class = "ctrl-mode",    action = "modeSetMajor" },
    shift_ctrl      = { name = "Aeolian",     class = "ctrl-mode",    action = "modeSetAeolian" },
    ctrl_opt        = { name = "Lydian ☀️",   class = "ctrl-mode",    action = "modeSetLydian" },
    ctrl_opt_shift  = { name = "Locrian 🌑",  class = "ctrl-mode",    action = "modeSetLocrian" },
  },
  [4] = { -- H (Consolidated Root)
    base            = { name = "Root +",      class = "ctrl-root",    action = "rootUp" },
    shift           = { name = "Root -",      class = "ctrl-root",    action = "rootDown" },
    opt             = { name = "Root +5th",   class = "ctrl-root",    action = "rootFifthUp" },
    shift_opt       = { name = "Root -5th",   class = "ctrl-root",    action = "rootFifthDown" },
    ctrl            = { name = "Root = C",    class = "ctrl-root",    action = "rootSetC" },
    shift_ctrl      = { name = "Root = A",    class = "ctrl-root",    action = "rootSetA" },
    ctrl_opt        = { name = "Root +Oct",   class = "ctrl-root",    action = "rootOctaveUp" },
    ctrl_opt_shift  = { name = "Root -Oct",   class = "ctrl-root",    action = "rootOctaveDown" },
  },
  [38] = { -- J (Consolidated Transpose)
    base            = { name = "Trnsp +1",    class = "ctrl-trnsp",   action = "trnspStep1Up" },
    shift           = { name = "Trnsp -1",    class = "ctrl-trnsp",   action = "trnspStep1Down" },
    opt             = { name = "Trnsp +2",    class = "ctrl-trnsp",   action = "trnspStep2Up" },
    shift_opt       = { name = "Trnsp -2",    class = "ctrl-trnsp",   action = "trnspStep2Down" },
    ctrl_opt        = { name = "Trnsp +3",    class = "ctrl-trnsp",   action = "trnspStep3Up" },
    ctrl_opt_shift  = { name = "Trnsp -3",    class = "ctrl-trnsp",   action = "trnspStep3Down" },
    ctrl            = { name = "Near Root ↑", class = "ctrl-trnsp",   action = "trnspNearRootUp" },
    shift_ctrl      = { name = "Near Sub ↓",  class = "ctrl-trnsp",   action = "trnspNearSubDown" },
  },
  [40] = { -- K (NEW FREED KEY: Bottom Row Track Focus & Mute - Tracks 1 & 2)
    base            = { name = "Bot 1⇄2",     class = "ctrl-track",   action = "botTrackToggle" },
    shift           = { name = "Bot Lock",    class = "ctrl-lock",    action = "botTrackLock" },
    opt             = { name = "Trk 1 Mute",  class = "ctrl-mute",    action = "trkMute1" },
    shift_opt       = { name = "Trk 2 Mute",  class = "ctrl-mute",    action = "trkMute2" },
    ctrl            = { name = "Trk 1 Solo",  class = "ctrl-solo",    action = "trkSolo1" },
    shift_ctrl      = { name = "Trk 2 Solo",  class = "ctrl-solo",    action = "trkSolo2" },
    ctrl_opt        = { name = "Trk 1 Rec",   class = "ctrl-track",   action = "trkRec1" },
    ctrl_opt_shift  = { name = "Trk 2 Rec",   class = "ctrl-track",   action = "trkRec2" },
  },
  [37] = { -- L (NEW FREED KEY: Top Row Track Focus & Mute - Tracks 3 & 4)
    base            = { name = "Top 3⇄4",     class = "ctrl-track",   action = "topTrackToggle" },
    shift           = { name = "Top Lock",    class = "ctrl-lock",    action = "topTrackLock" },
    opt             = { name = "Trk 3 Mute",  class = "ctrl-mute",    action = "trkMute3" },
    shift_opt       = { name = "Trk 4 Mute",  class = "ctrl-mute",    action = "trkMute4" },
    ctrl            = { name = "Trk 3 Solo",  class = "ctrl-solo",    action = "trkSolo3" },
    shift_ctrl      = { name = "Trk 4 Solo",  class = "ctrl-solo",    action = "trkSolo4" },
    ctrl_opt        = { name = "Trk 3 Rec",   class = "ctrl-track",   action = "trkRec3" },
    ctrl_opt_shift  = { name = "Trk 4 Rec",   class = "ctrl-track",   action = "trkRec4" },
  },
  [41] = { -- ; (NEW FREED KEY: Master Track Selector & Performance Mix)
    base            = { name = "Trk Focus",   class = "ctrl-track",   action = "trackFocusCycle" },
    shift           = { name = "All Mute",    class = "ctrl-mute",    action = "allMuteToggle" },
    opt             = { name = "Top Vol +",   class = "ctrl-vol",     action = "topVolUp" },
    shift_opt       = { name = "Top Vol -",   class = "ctrl-vol",     action = "topVolDown" },
    ctrl            = { name = "Bot Vol +",   class = "ctrl-vol",     action = "botVolUp" },
    shift_ctrl      = { name = "Bot Vol -",   class = "ctrl-vol",     action = "botVolDown" },
    ctrl_opt        = { name = "Mix Reset",   class = "ctrl-vol",     action = "mixReset" },
    ctrl_opt_shift  = { name = "Master Mute", class = "ctrl-mute",    action = "allMuteToggle" },
  },
  [39] = { -- ' (Chord)
    base            = { name = "Chord",       class = "ctrl-mode",    action = "chordToggle" },
    shift           = { name = "Chord +",     class = "ctrl-mode",    action = "chordUp" },
    opt             = { name = "Voicing +",   class = "ctrl-mode",    action = "voicingUp" },
    shift_opt       = { name = "Voicing -",   class = "ctrl-mode",    action = "voicingDown" },
    ctrl            = { name = "Inversion +", class = "ctrl-mode",    action = "inversionUp" },
    shift_ctrl      = { name = "Inversion -", class = "ctrl-mode",    action = "inversionDown" },
    ctrl_opt        = { name = "Power 1-5",   class = "ctrl-mode",    action = "chordPower" },
    ctrl_opt_shift  = { name = "Triad",       class = "ctrl-mode",    action = "chordTriad" },
  },

  -- NUMBER ROW CONTROLS:
  [18] = { -- 1
    base            = { name = "Trk 1: Bass", class = "ctrl-track",   action = "trkSelect1" },
    shift           = { name = "Trk 1 Mute",  class = "ctrl-mute",    action = "trkMute1" },
    opt             = { name = "Trk 1 Solo",  class = "ctrl-solo",    action = "trkSolo1" },
    shift_opt       = { name = "Trk 1 Lock",  class = "ctrl-lock",    action = "trkLock1" },
    ctrl            = { name = "Trk 1 Rec",   class = "ctrl-track",   action = "trkRec1" },
    shift_ctrl      = { name = "Trk 1 Clear", class = "ctrl-mute",    action = "trkClear1" },
    ctrl_opt        = { name = "Trk 1 Focus", class = "ctrl-track",   action = "trkFocus1" },
    ctrl_opt_shift  = { name = "Trk 1 Panic", class = "ctrl-panic",   action = "panic" },
  },
  [19] = { -- 2
    base            = { name = "Trk 2: Chords", class = "ctrl-track", action = "trkSelect2" },
    shift           = { name = "Trk 2 Mute",  class = "ctrl-mute",    action = "trkMute2" },
    opt             = { name = "Trk 2 Solo",  class = "ctrl-solo",    action = "trkSolo2" },
    shift_opt       = { name = "Trk 2 Lock",  class = "ctrl-lock",    action = "trkLock2" },
    ctrl            = { name = "Trk 2 Rec",   class = "ctrl-track",   action = "trkRec2" },
    shift_ctrl      = { name = "Trk 2 Clear", class = "ctrl-mute",    action = "trkClear2" },
    ctrl_opt        = { name = "Trk 2 Focus", class = "ctrl-track",   action = "trkFocus2" },
    ctrl_opt_shift  = { name = "Trk 2 Panic", class = "ctrl-panic",   action = "panic" },
  },
  [20] = { -- 3
    base            = { name = "Trk 3: Lead", class = "ctrl-track",   action = "trkSelect3" },
    shift           = { name = "Trk 3 Mute",  class = "ctrl-mute",    action = "trkMute3" },
    opt             = { name = "Trk 3 Solo",  class = "ctrl-solo",    action = "trkSolo3" },
    shift_opt       = { name = "Trk 3 Lock",  class = "ctrl-lock",    action = "trkLock3" },
    ctrl            = { name = "Trk 3 Rec",   class = "ctrl-track",   action = "trkRec3" },
    shift_ctrl      = { name = "Trk 3 Clear", class = "ctrl-mute",    action = "trkClear3" },
    ctrl_opt        = { name = "Trk 3 Focus", class = "ctrl-track",   action = "trkFocus3" },
    ctrl_opt_shift  = { name = "Trk 3 Panic", class = "ctrl-panic",   action = "panic" },
  },
  [21] = { -- 4
    base            = { name = "Trk 4: Arp",  class = "ctrl-track",   action = "trkSelect4" },
    shift           = { name = "Trk 4 Mute",  class = "ctrl-mute",    action = "trkMute4" },
    opt             = { name = "Trk 4 Solo",  class = "ctrl-solo",    action = "trkSolo4" },
    shift_opt       = { name = "Trk 4 Lock",  class = "ctrl-lock",    action = "trkLock4" },
    ctrl            = { name = "Trk 4 Rec",   class = "ctrl-track",   action = "trkRec4" },
    shift_ctrl      = { name = "Trk 4 Clear", class = "ctrl-mute",    action = "trkClear4" },
    ctrl_opt        = { name = "Trk 4 Focus", class = "ctrl-track",   action = "trkFocus4" },
    ctrl_opt_shift  = { name = "Trk 4 Panic", class = "ctrl-panic",   action = "panic" },
  },
  [23] = { -- 5
    base            = { name = "Dir +",       class = "ctrl-arpdir",  action = "arpDirUp" },
    shift           = { name = "Dir -",       class = "ctrl-arpdir",  action = "arpDirDown" },
    opt             = { name = "Random Dir",  class = "ctrl-arpdir",  action = "arpDirRandom" },
    shift_opt       = { name = "Converge",    class = "ctrl-arpdir",  action = "arpDirConverge" },
    ctrl            = { name = "Up / Down",   class = "ctrl-arpdir",  action = "arpDirUpDown" },
    shift_ctrl      = { name = "Down / Up",   class = "ctrl-arpdir",  action = "arpDirDownUp" },
    ctrl_opt        = { name = "Diverge",     class = "ctrl-arpdir",  action = "arpDirDiverge" },
    ctrl_opt_shift  = { name = "Dir Reset",   class = "ctrl-arpdir",  action = "arpDirReset" },
  },
  [22] = { -- 6
    base            = { name = "Rate +",      class = "ctrl-arprate", action = "arpRateUp" },
    shift           = { name = "Rate -",      class = "ctrl-arprate", action = "arpRateDown" },
    opt             = { name = "Triplet Rate", class = "ctrl-arprate", action = "arpRateTriplet" },
    shift_opt       = { name = "Straight Rate", class = "ctrl-arprate", action = "arpRateStraight" },
    ctrl            = { name = "1/16th",      class = "ctrl-arprate", action = "arpRate16th" },
    shift_ctrl      = { name = "1/8th",       class = "ctrl-arprate", action = "arpRate8th" },
    ctrl_opt        = { name = "1/32nd",      class = "ctrl-arprate", action = "arpRate32nd" },
    ctrl_opt_shift  = { name = "1/4th",       class = "ctrl-arprate", action = "arpRate4th" },
  },
  [26] = { -- 7
    base            = { name = "Gate +",      class = "ctrl-arpgate", action = "arpGateUp" },
    shift           = { name = "Gate -",      class = "ctrl-arpgate", action = "arpGateDown" },
    opt             = { name = "Staccato 25%", class = "ctrl-arpgate", action = "arpGateStaccato" },
    shift_opt       = { name = "Legato 100%", class = "ctrl-arpgate", action = "arpGateLegato" },
    ctrl            = { name = "Overlap 120%", class = "ctrl-arpgate", action = "arpGateOverlap" },
    shift_ctrl      = { name = "Gate 80%",    class = "ctrl-arpgate", action = "arpGate80" },
    ctrl_opt        = { name = "Gate 50%",    class = "ctrl-arpgate", action = "arpGate50" },
    ctrl_opt_shift  = { name = "Gate Reset",  class = "ctrl-arpgate", action = "arpGateReset" },
  },
  [28] = { -- 8
    base            = { name = "Arp Link",    class = "ctrl-arptop",  action = "arpLinkToggle" },
    shift           = { name = "Split Arp",   class = "ctrl-arpbot",  action = "splitArpToggle" },
    opt             = { name = "Sync BPM",    class = "ctrl-bpm",     action = "syncBpmToggle" },
    shift_opt       = { name = "Free Clock",  class = "ctrl-bpm",     action = "freeClockToggle" },
    ctrl            = { name = "Top Boost +", class = "ctrl-vol",     action = "topBoostUp" },
    shift_ctrl      = { name = "Top Boost -", class = "ctrl-vol",     action = "topBoostDown" },
    ctrl_opt        = { name = "Clock /2",    class = "ctrl-bpm",     action = "clockDiv2" },
    ctrl_opt_shift  = { name = "Clock x2",    class = "ctrl-bpm",     action = "clockMul2" },
  },
  [25] = { -- 9
    base            = { name = "Rel +",       class = "ctrl-rel",     action = "relUp" },
    shift           = { name = "Rel -",       class = "ctrl-rel",     action = "relDown" },
    opt             = { name = "Rel Max",     class = "ctrl-rel",     action = "relMax" },
    shift_opt       = { name = "Rel Min",     class = "ctrl-rel",     action = "relMin" },
    ctrl            = { name = "Rel Default", class = "ctrl-rel",     action = "relDefault" },
    shift_ctrl      = { name = "Rel 50%",     class = "ctrl-rel",     action = "rel50" },
    ctrl_opt        = { name = "Rel 75%",     class = "ctrl-rel",     action = "rel75" },
    ctrl_opt_shift  = { name = "Rel 25%",     class = "ctrl-rel",     action = "rel25" },
  },
  [29] = { -- 0
    base            = { name = "Vol +",       class = "ctrl-vol",     action = "volUp" },
    shift           = { name = "Vol -",       class = "ctrl-vol",     action = "volDown" },
    opt             = { name = "Mod CC1 +",   class = "ctrl-modw",    action = "modWheelUp" },
    shift_opt       = { name = "Mod CC1 -",   class = "ctrl-modw",    action = "modWheelDown" },
    ctrl            = { name = "Vol 100%",    class = "ctrl-vol",     action = "vol100" },
    shift_ctrl      = { name = "Vol 75%",     class = "ctrl-vol",     action = "vol75" },
    ctrl_opt        = { name = "Mod Max",     class = "ctrl-modw",    action = "modMax" },
    ctrl_opt_shift  = { name = "Mod 0",       class = "ctrl-modw",    action = "mod0" },
  },
  [27] = { -- -
    base            = { name = "BPM -",       class = "ctrl-bpm",     action = "bpmDown" },
    shift           = { name = "Zoom -",      class = "ctrl-zoom",    action = "zoomDown" },
    opt             = { name = "BPM -10",     class = "ctrl-bpm",     action = "bpmDown10" },
    shift_opt       = { name = "BPM -20",     class = "ctrl-bpm",     action = "bpmDown20" },
    ctrl            = { name = "BPM = 120",   class = "ctrl-bpm",     action = "bpm120" },
    shift_ctrl      = { name = "BPM = 90",    class = "ctrl-bpm",     action = "bpm90" },
    ctrl_opt        = { name = "BPM = 70",    class = "ctrl-bpm",     action = "bpm70" },
    ctrl_opt_shift  = { name = "BPM Min",     class = "ctrl-bpm",     action = "bpmMin" },
  },
  [24] = { -- =
    base            = { name = "BPM +",       class = "ctrl-bpm",     action = "bpmUp" },
    shift           = { name = "Zoom +",      class = "ctrl-zoom",    action = "zoomUp" },
    opt             = { name = "BPM +10",     class = "ctrl-bpm",     action = "bpmUp10" },
    shift_opt       = { name = "BPM +20",     class = "ctrl-bpm",     action = "bpmUp20" },
    ctrl            = { name = "Tap Tempo",   class = "ctrl-bpm",     action = "tapTempo" },
    shift_ctrl      = { name = "BPM = 140",   class = "ctrl-bpm",     action = "bpm140" },
    ctrl_opt        = { name = "BPM = 160",   class = "ctrl-bpm",     action = "bpm160" },
    ctrl_opt_shift  = { name = "BPM Max",     class = "ctrl-bpm",     action = "bpmMax" },
  }
}

local function getProposedActionDef(code)
  local s = state.shiftHeld == true
  local a = state.altHeld == true
  local c = state.ctrlHeld == true
  local activeLayer = "base"
  if c and a and s then activeLayer = "ctrl_opt_shift"
  elseif c and a then activeLayer = "ctrl_opt"
  elseif c and s then activeLayer = "shift_ctrl"
  elseif a and s then activeLayer = "shift_opt"
  elseif c then activeLayer = "ctrl"
  elseif a then activeLayer = "opt"
  elseif s then activeLayer = "shift"
  end

  local layerTable = PROPOSED_LAYOUT_MAP[code]
  if layerTable then
    return layerTable[activeLayer] or layerTable.base
  end
  return nil
end

local function getProposedActionSpotlight(code)
  local s = state.shiftHeld == true
  local a = state.altHeld == true
  local c = state.ctrlHeld == true
  local activeLayer = "base"
  if c and a and s then activeLayer = "ctrl_opt_shift"
  elseif c and a then activeLayer = "ctrl_opt"
  elseif c and s then activeLayer = "shift_ctrl"
  elseif a and s then activeLayer = "shift_opt"
  elseif c then activeLayer = "ctrl"
  elseif a then activeLayer = "opt"
  elseif s then activeLayer = "shift"
  end

  local layerTable = PROPOSED_LAYOUT_MAP[code]
  if layerTable then
    local layerDef = layerTable[activeLayer] or layerTable.base
    if layerDef then
      local layerDisplayNames = {
        base = "BASE", shift = "SHIFT", opt = "OPTION", shift_opt = "SHIFT+OPT",
        ctrl = "CONTROL", shift_ctrl = "CTRL+SHIFT", ctrl_opt = "CTRL+OPT", ctrl_opt_shift = "CTRL+OPT+SHIFT"
      }
      return {
        title = "PROPOSED ACTION",
        value = layerDef.name,
        subtext = "Modifier Layer: " .. (layerDisplayNames[activeLayer] or "BASE"),
        targetId = "key-" .. code,
        color = "#64d8f0"
      }
    end
  end
  return nil
end


local function performWebviewHudUpdate(spotlightInfo, activeArpPitch)
  if not _G.activeWatchers.midiWebview or not _G.activeWatchers.domIsReady then return end

  local baseW = 980
  local baseH = getDesiredBaseHeight()
  local effectiveScale = state.zoomLevel * state.BASE_HUD_SCALE
  local NOTIF_BAND = math.floor(50 * effectiveScale)
  local newW = math.floor(baseW * effectiveScale)
  local newH = math.floor(baseH * effectiveScale) + NOTIF_BAND

  local curFrame = _G.activeWatchers.midiWebview:frame()
  if curFrame.w ~= newW or curFrame.h ~= newH then
    local screen = hs.screen.mainScreen():frame()
    local cx = curFrame.x + (curFrame.w / 2)
    local diffH = newH - curFrame.h
    local nx = math.max(screen.x, math.min(screen.x + screen.w - newW, math.floor(cx - (newW / 2))))
    local ny = math.max(screen.y, math.min(screen.y + screen.h - newH, curFrame.y - diffH))
    _G.activeWatchers.midiWebview:frame({ x = nx, y = ny, w = newW, h = newH })
    _G.activeWatchers.hudX = nx
    _G.activeWatchers.hudY = ny
    hs.settings.set("qwertyMidi_hudX", nx)
    hs.settings.set("qwertyMidi_hudY", ny)
    lastFrameScale = effectiveScale
  end

  hs.settings.set("qwertyMidi_zoomLevel", state.zoomLevel)
  
  local currentScaleIdx = tonumber(state.currentScaleIdx) or 1
  local modeFrac = (currentScaleIdx - 0.5) / #SCALES
  local modeName = SCALES[currentScaleIdx].name
  
  local octVal = tonumber(state.octaveShift) or 0
  local topOctVal = tonumber(state.topRowOctaveOffset) or 0
  local trnspVal = tonumber(state.transposeShift) or 0
  local trnspStr = (trnspVal ~= 0) and ("Trnsp: " .. (trnspVal >= 0 and "+" or "") .. trnspVal .. "st") or ""
  local susStr = state.sustainActive and "SUS: ON" or ""
  local shiftStr = state.shiftHeld and "[SHIFT]" or ""

  local s = state.shiftHeld == true
  local a = state.altHeld == true
  local c = state.ctrlHeld == true
  local activeLayer = "base"
  if c and a and s then activeLayer = "ctrl_opt_shift"
  elseif c and a then activeLayer = "ctrl_opt"
  elseif c and s then activeLayer = "shift_ctrl"
  elseif a and s then activeLayer = "shift_opt"
  elseif c then activeLayer = "ctrl"
  elseif a then activeLayer = "opt"
  elseif s then activeLayer = "shift"
  end

  local layerDisplayNames = {
    base = "BASE", shift = "SHIFT", opt = "OPTION", shift_opt = "SHIFT+OPT",
    ctrl = "CONTROL", shift_ctrl = "CTRL+SHIFT", ctrl_opt = "CTRL+OPT", ctrl_opt_shift = "CTRL+OPT+SHIFT"
  }

  local statusParts = {}
  table.insert(statusParts, "LAYER: [" .. (layerDisplayNames[activeLayer] or "BASE") .. "]")
  if trnspStr ~= "" then table.insert(statusParts, trnspStr) end
  if susStr ~= "" then table.insert(statusParts, susStr) end
  if state.arpEnabled then table.insert(statusParts, state.arpLatchActive and "ARP: LATCH" or "ARP: ON") end
  local statusStr = table.concat(statusParts, "  •  ")

  local botOctNum = math.floor((octVal + (tonumber(state.bottomRowOctaveOffset) or 0)) / 12)
  local topOctNum = math.floor((octVal + (tonumber(state.topRowOctaveOffset) or 0) + 12) / 12)
  local topOctaveStr = (topOctNum >= 0 and "+" or "") .. topOctNum
  local bottomOctaveStr = (botOctNum >= 0 and "+" or "") .. botOctNum

  local keyUpdates = {}

  local actionTypeClass = {
    -- Home row pairs
    trnspDown = "ctrl-trnsp", trnspUp = "ctrl-trnsp",
    rootDown = "ctrl-root", rootUp = "ctrl-root",
    modeDown = "ctrl-mode", modeUp = "ctrl-mode",
    octaveDown = "ctrl-oct", octaveUp = "ctrl-oct",
    topOctDown = "ctrl-topoct", topOctUp = "ctrl-topoct",
    topVolDown = "ctrl-vol", topVolUp = "ctrl-vol",
    modWheelDown = "ctrl-modw", modWheelUp = "ctrl-modw",
    volDown = "ctrl-vol", volUp = "ctrl-vol",
    
    -- Number row pairs
    arpDirDown = "ctrl-arpdir", arpDirUp = "ctrl-arpdir",
    arpRateDown = "ctrl-arprate", arpRateUp = "ctrl-arprate",
    arpGateDown = "ctrl-arpgate", arpGateUp = "ctrl-arpgate",
    relDown = "ctrl-rel", relUp = "ctrl-rel", releaseDown = "ctrl-rel", releaseUp = "ctrl-rel",
    bpmDown = "ctrl-bpm", bpmUp = "ctrl-bpm",
    zoomOut = "ctrl-zoom", zoomIn = "ctrl-zoom",
    
    -- Singletons / Toggles
    arpToggle = "ctrl-arp", arpTopToggle = "ctrl-arptop", arpBottomToggle = "ctrl-arpbot",
    bpmEdit = "ctrl-bpmedit", randomScale = "ctrl-rand", panic = "ctrl-panic", resetAll = "ctrl-reset",
    undoState = "ctrl-reset", redoState = "ctrl-reset",
    chordToggle = "ctrl-mode", chordMod = "ctrl-mode", chordUp = "ctrl-mode", chordDown = "ctrl-mode"
  }

  for code, cData in pairs(numberRowControls) do
    local activeAct = state.shiftHeld and (cData.shiftAction or cData.action) or cData.action
    local isMainArp = (activeAct == "arpToggle")
    local isTopArp = (activeAct == "arpTopToggle")
    local isBotArp = (activeAct == "arpBottomToggle")
    local isActiveToggle = (isMainArp and state.arpEnabled) or (isTopArp and state.arpTopEnabled) or (isBotArp and state.arpBottomEnabled)
    local pairedClass = actionTypeClass[activeAct] or actionTypeClass[cData.action] or ""
    keyUpdates[tostring(code)] = {
      note = cData.name,
      action = cData.action,
      shiftNote = cData.shiftName or cData.name,
      shiftAction = cData.shiftAction,
      isControl = true,
      typeClass = isActiveToggle and "latch-active" or pairedClass,
      pressed = (state.pressedKeys[code] ~= nil),
      sustainActive = isActiveToggle
    }
  end

  -- Pre-compute set of all pitches in the arp pool (values of heldNotes)
  -- and the currently active arp pitch, for per-key dot indicators across all tracks.
  local arpHeldPitches = { [1] = {}, [2] = {}, [3] = {}, [4] = {} }
  local currentArpPitches = { [1] = {}, [2] = {}, [3] = {}, [4] = {} }
  
  if state.tracks then
    for trkId = 1, 4 do
      local trk = state.tracks[trkId]
      if trk and trk.arpEnabled then
        for _, pitch in pairs(trk.heldNotes or {}) do
          if type(pitch) == "number" then arpHeldPitches[trkId][pitch] = true end
        end
        local p = type(trk.currentPitch) == "table" and trk.currentPitch.pitch or trk.currentPitch
        if p then currentArpPitches[trkId][p] = true end
      end
    end
  end

  for code, kData in pairs(config.getActiveNoteKeysMap()) do
    local noteNum = transposer.getTransposedPitch(kData.baseNote, kData.isTop)
    local intervalIdx = transposer.getIntervalInfo(noteNum)
    local noteName = transposer.noteNumToName(noteNum)
    local typeClass = ""

    if intervalIdx == 1 then
      typeClass = "root-key"
    elseif intervalIdx == 3 then
      typeClass = "third-key"
    elseif intervalIdx == 5 then
      typeClass = "fifth-key"
    end

    local trkId = kData.isTop and (state.topRowTrack or 3) or (state.bottomRowTrack or 1)
    local noteTrk = state.tracks and state.tracks[trkId]
    local arpActive = noteTrk and noteTrk.arpEnabled or false

    local isPressed = (state.pressedKeys[code] ~= nil)
    if arpActive and currentArpPitches[trkId][noteNum] then
      isPressed = true
    end

    local isLatched = false
    if arpActive and noteTrk.arpLatchActive then
      local codeStr = tostring(code)
      for heldCode, _ in pairs(noteTrk.heldNotes or {}) do
        if tostring(heldCode):match("^(%d+)") == codeStr then isLatched = true; break end
      end
    end

    keyUpdates[tostring(code)] = {
      note = noteName,
      action = kData.action,
      shiftNote = kData.shiftName or noteName,
      shiftAction = kData.shiftAction,
      typeClass = typeClass,
      pressed = isPressed,
      latched = isLatched,
      arpHeld = arpActive and (arpHeldPitches[trkId][noteNum] == true),
      arpPlaying = arpActive and (currentArpPitches[trkId][noteNum] == true),
      outOfBounds = (noteNum < 0 or noteNum > 127)
    }
  end

  for code, cData in pairs(config.getActiveControlKeysMap()) do
    local activeAct = (state.shiftHeld or state.altHeld) and (cData.shiftAction or cData.action) or cData.action
    local isSustain = (activeAct == "sustain" or activeAct == "classicSustain" or cData.action == "sustain" or cData.action == "classicSustain")
    local isChordToggle = (activeAct == "chordToggle" or cData.action == "chordToggle")
    local isMainArp = (activeAct == "arpToggle")
    local isTopArp = (activeAct == "arpTopToggle")
    local isBotArp = (activeAct == "arpBottomToggle")
    local pairedClass = actionTypeClass[activeAct] or actionTypeClass[cData.action] or ""
    
    local activeTrk = state.tracks and state.tracks[state.activeTrack or 1]
    local isActiveToggle = false
    if isSustain then
      local sMode = activeTrk and activeTrk.sustainMode or (state.sustainActive and "smart" or "off")
      isActiveToggle = (sMode ~= "off")
    elseif isChordToggle then
      isActiveToggle = (activeTrk and activeTrk.chordModeActive == true) or (state.chordModeActive == true)
    elseif (isMainArp and state.arpEnabled) or (isTopArp and state.arpTopEnabled) or (isBotArp and state.arpBottomEnabled) then
      isActiveToggle = true
    end

    local noteLabel = cData.name
    local typeClass = pairedClass
    if isSustain then
      local sMode = activeTrk and activeTrk.sustainMode or (state.sustainActive and "smart" or "off")
      if sMode == "smart" then
        noteLabel = "Smart Sus"
        typeClass = "latch-active"
      elseif sMode == "classic" then
        noteLabel = "Classic Sus"
        typeClass = "latch-mode-active"
      else
        noteLabel = (state.shiftHeld or state.altHeld) and "Classic Sus" or "Smart Sus"
        typeClass = "ctrl-sus"
      end
    elseif isChordToggle then
      local isChOn = (activeTrk and activeTrk.chordModeActive == true) or (state.chordModeActive == true)
      local cIdx = (activeTrk and activeTrk.chordIdx) or state.chordIdx or 1
      local cName = state.CHORDS and state.CHORDS[cIdx] and state.CHORDS[cIdx].name or "Chord"
      if isChOn then
        noteLabel = "Chord [" .. cName .. "]"
        typeClass = "latch-active"
      else
        noteLabel = "Chord"
        typeClass = pairedClass
      end
    elseif isMainArp then
      if state.arpEnabled and state.arpLatchActive then
        noteLabel = "Arp 🔒"
        typeClass = "latch-mode-active"
      elseif state.arpEnabled then
        noteLabel = "Arp"
        typeClass = "latch-active"
      else
        noteLabel = "Arp"
      end
    elseif isTopArp then
      noteLabel = "Top Arp"
      typeClass = state.arpTopEnabled and "latch-active" or pairedClass
    elseif isBotArp then
      noteLabel = "Bottom Arp"
      typeClass = state.arpBottomEnabled and "latch-active" or pairedClass
    elseif isActiveToggle then
      typeClass = "latch-active"
    end

    keyUpdates[tostring(code)] = {
      note = noteLabel,
      action = cData.action,
      shiftNote = cData.shiftName or cData.name,
      shiftAction = cData.shiftAction,
      isControl = true,
      typeClass = typeClass,
      pressed = (state.pressedKeys[code] ~= nil),
      sustainActive = isActiveToggle
    }
  end

  -- Overlay Proposed Layout actions and names based on active modifier layer
  for propCode, layerTable in pairs(PROPOSED_LAYOUT_MAP) do
    local strCode = tostring(propCode)
    local layerDef = layerTable[activeLayer] or layerTable.base
    if layerDef then
      keyUpdates[strCode] = keyUpdates[strCode] or { isControl = true, pressed = false }
      keyUpdates[strCode].displayNote = layerDef.name
      keyUpdates[strCode].note = layerDef.name
      keyUpdates[strCode].action = layerDef.action
      keyUpdates[strCode].shiftAction = layerDef.action
      if layerDef.class then
        keyUpdates[strCode].typeClass = layerDef.class
      end

      local act = layerDef.action
      if act then
        if act == "topOctUp" or act == "topOctDown" or act == "topVolUp" or act == "topVolDown" or
           act == "arpTopToggle" or act == "topTrackToggle" or act == "topTrackLock" or
           act == "topBoostUp" or act == "topBoostDown" or string.match(act, "^trk.*[34]$") then
          keyUpdates[strCode].rowActive = "top"
        elseif act == "botOctUp" or act == "botOctDown" or act == "botVolUp" or act == "botVolDown" or
               act == "arpBottomToggle" or act == "botTrackToggle" or act == "botTrackLock" or
               string.match(act, "^trk.*[12]$") then
          keyUpdates[strCode].rowActive = "bottom"
        elseif act == "octaveUp" or act == "octaveDown" or act == "octReset" or
               act == "volUp" or act == "volDown" or act == "mixReset" or
               act == "arpLinkToggle" or act == "splitArpToggle" then
          keyUpdates[strCode].rowActive = "both"
        end
      end

      -- Special dynamic overlays for Arp / Latch controls (3-state arp button on A, latch on F)
      local trk = state.tracks and state.tracks[state.activeTrack or 1]
      local isArpOn = (trk and trk.arpEnabled) or (state.arpEnabled == true)
      local isArpLatch = (trk and trk.arpLatchActive) or (state.arpLatchActive == true)

      if propCode == 0 then -- Key A
        if activeLayer == "base" then
          if isArpOn and isArpLatch then
            keyUpdates[strCode].displayNote = "Arp 🔒"
            keyUpdates[strCode].note = "Arp 🔒"
            keyUpdates[strCode].typeClass = "latch-mode-active"
            keyUpdates[strCode].sustainActive = true
          elseif isArpOn then
            keyUpdates[strCode].displayNote = "Arp"
            keyUpdates[strCode].note = "Arp"
            keyUpdates[strCode].typeClass = "latch-active"
            keyUpdates[strCode].sustainActive = true
          else
            keyUpdates[strCode].displayNote = "Arp"
            keyUpdates[strCode].note = "Arp"
            keyUpdates[strCode].typeClass = "ctrl-arp"
            keyUpdates[strCode].sustainActive = false
          end
        elseif activeLayer == "shift" then
          if isArpLatch then
            keyUpdates[strCode].displayNote = "Latch 🔒"
            keyUpdates[strCode].note = "Latch 🔒"
            keyUpdates[strCode].typeClass = "latch-mode-active"
            keyUpdates[strCode].sustainActive = true
          else
            keyUpdates[strCode].displayNote = "Latch"
            keyUpdates[strCode].note = "Latch"
            keyUpdates[strCode].typeClass = "ctrl-arp"
            keyUpdates[strCode].sustainActive = false
          end
        end
      elseif propCode == 3 then -- Key F
        if activeLayer == "base" then
          if isArpLatch then
            keyUpdates[strCode].displayNote = "Latch 🔒"
            keyUpdates[strCode].note = "Latch 🔒"
            keyUpdates[strCode].typeClass = "latch-mode-active"
            keyUpdates[strCode].sustainActive = true
          end
        end
      elseif propCode == 48 then -- Key 48 (Tab: Sustain)
        local sMode = trk and trk.sustainMode or (state.sustainActive and "smart" or "off")
        if sMode == "smart" then
          keyUpdates[strCode].displayNote = "Smart Sus"
          keyUpdates[strCode].note = "Smart Sus"
          keyUpdates[strCode].typeClass = "latch-active"
          keyUpdates[strCode].sustainActive = true
        elseif sMode == "classic" then
          keyUpdates[strCode].displayNote = "Classic Sus"
          keyUpdates[strCode].note = "Classic Sus"
          keyUpdates[strCode].typeClass = "latch-mode-active"
          keyUpdates[strCode].sustainActive = true
        else
          local isShiftOrOpt = (activeLayer == "shift" or activeLayer == "opt" or activeLayer == "shift_opt")
          keyUpdates[strCode].displayNote = isShiftOrOpt and "Classic Sus" or "Smart Sus"
          keyUpdates[strCode].note = keyUpdates[strCode].displayNote
          keyUpdates[strCode].typeClass = "ctrl-sus"
          keyUpdates[strCode].sustainActive = false
        end
      end
    end
  end

  -- Track buttons (keys 18, 19, 20, 21): apply accurate dual-selection, mute, solo, color, audio states, human keypress, and arp step
  local trkKeyMap = { [18] = 1, [19] = 2, [20] = 3, [21] = 4 }
  for kCode, trkId in pairs(trkKeyMap) do
    local strCode = tostring(kCode)
    if keyUpdates[strCode] then
      keyUpdates[strCode].sustainActive = false -- strictly prevent legacy toggle selection glow
      keyUpdates[strCode].trkSelected = (trkId <= 2 and state.bottomRowTrack == trkId) or (trkId >= 3 and state.topRowTrack == trkId)
      keyUpdates[strCode].rowActive = (trkId <= 2) and "bottom" or "top"
      local t = state.tracks and state.tracks[trkId]
      if t then
        local isAudible = arpeggiator.isTrackAudible(trkId)
        local hasKeys = false
        if t.physicalKeysHeld then
          for _ in pairs(t.physicalKeysHeld) do
            hasKeys = true
            break
          end
        end
        keyUpdates[strCode].trkMuted = (t.muted == true)
        keyUpdates[strCode].trkSoloed = (t.soloed == true)
        keyUpdates[strCode].trkColor = t.color
        keyUpdates[strCode].trkAudioActive = false
        keyUpdates[strCode].trkHumanActive = hasKeys
        keyUpdates[strCode].trkArpStep = (t.arpIsPlaying == true)
        keyUpdates[strCode].trkSustainMode = t.sustainMode or "off"
        keyUpdates[strCode].trkChordMode = (t.chordModeActive == true)
      end
    end
  end

  local modVal = state.ccStates[1] or 0

  local bpmDisplayStr
  if state.bpmInputMode then
    bpmDisplayStr = state.bpmInputBuffer .. "\226\150\140"
  else
    bpmDisplayStr = arpeggiator.formatBpm(state.arpBpm) .. " BPM"
  end

  if _G.activeWatchers and _G.activeWatchers.nanokey and _G.activeWatchers.nanokey.syncScaleGuideLeds then
    if state.currentRoot ~= lastSyncedRoot or state.currentScaleIdx ~= lastSyncedScaleIdx or state.scaleGuideEnabled ~= lastSyncedScaleGuideEnabled then
      lastSyncedRoot = state.currentRoot
      lastSyncedScaleIdx = state.currentScaleIdx
      lastSyncedScaleGuideEnabled = state.scaleGuideEnabled
      pcall(function() _G.activeWatchers.nanokey.syncScaleGuideLeds(state) end)
    end
  end

  local topTrk = state.tracks and state.tracks[state.topRowTrack or 3]
  local botTrk = state.tracks and state.tracks[state.bottomRowTrack or 1]

  local payload = {
    nanokeyConnected = isNanokeyConnected(),
    activeSurface = state.activeSurface or "qwerty",
    currentMode = state.currentMode or "Home",
    modeSelectHeld = state.modeSelectHeld == true,
    activeTrack = state.activeTrack or 1,
    activeTrackColor = (activeTrk and activeTrk.color) or "#00e5ff",
    topRowTrack = state.topRowTrack or 3,
    bottomRowTrack = state.bottomRowTrack or 1,
    topTrackColor = (topTrk and topTrk.color) or "#00e676",
    bottomTrackColor = (botTrk and botTrk.color) or "#00e5ff",
    tracks = {
      [1] = {
        id = 1, name = "Bass", channel = 0, color = "#00e5ff",
        selected = (state.bottomRowTrack == 1),
        muted = state.tracks and state.tracks[1] and state.tracks[1].muted == true or false,
        soloed = state.tracks and state.tracks[1] and state.tracks[1].soloed == true or false,
        activeAudio = false,
        humanActive = state.tracks and state.tracks[1] and state.tracks[1].physicalKeysHeld and next(state.tracks[1].physicalKeysHeld) ~= nil or false,
        arpStep = state.tracks and state.tracks[1] and state.tracks[1].arpIsPlaying == true or false
      },
      [2] = {
        id = 2, name = "Chords", channel = 1, color = "#ff9100",
        selected = (state.bottomRowTrack == 2),
        muted = state.tracks and state.tracks[2] and state.tracks[2].muted == true or false,
        soloed = state.tracks and state.tracks[2] and state.tracks[2].soloed == true or false,
        activeAudio = false,
        humanActive = state.tracks and state.tracks[2] and state.tracks[2].physicalKeysHeld and next(state.tracks[2].physicalKeysHeld) ~= nil or false,
        arpStep = state.tracks and state.tracks[2] and state.tracks[2].arpIsPlaying == true or false
      },
      [3] = {
        id = 3, name = "Lead", channel = 2, color = "#00e676",
        selected = (state.topRowTrack == 3),
        muted = state.tracks and state.tracks[3] and state.tracks[3].muted == true or false,
        soloed = state.tracks and state.tracks[3] and state.tracks[3].soloed == true or false,
        activeAudio = false,
        humanActive = state.tracks and state.tracks[3] and state.tracks[3].physicalKeysHeld and next(state.tracks[3].physicalKeysHeld) ~= nil or false,
        arpStep = state.tracks and state.tracks[3] and state.tracks[3].arpIsPlaying == true or false
      },
      [4] = {
        id = 4, name = "Arp", channel = 3, color = "#d500f9",
        selected = (state.topRowTrack == 4),
        muted = state.tracks and state.tracks[4] and state.tracks[4].muted == true or false,
        soloed = state.tracks and state.tracks[4] and state.tracks[4].soloed == true or false,
        activeAudio = false,
        humanActive = state.tracks and state.tracks[4] and state.tracks[4].physicalKeysHeld and next(state.tracks[4].physicalKeysHeld) ~= nil or false,
        arpStep = state.tracks and state.tracks[4] and state.tracks[4].arpIsPlaying == true or false
      }
    },
    keys = keyUpdates,
    shiftHeld = state.shiftHeld,
    altHeld = state.altHeld == true,
    ctrlHeld = state.ctrlHeld == true,
    activeLayer = activeLayer,
    uiActionKeyHue = state.uiActionKeyHue,
    uiActionKeySat = state.uiActionKeySat,
    uiActionKeyLight = state.uiActionKeyLight,
    uiActionKeyOpacity = state.uiActionKeyOpacity,
    uiActionKeyBorderOpacity = state.uiActionKeyBorderOpacity,
    arpEnabled = state.arpEnabled,
    modeName = modeName,
    arpLatchActive = state.arpLatchActive,
    arpDirectionIdx = state.arpDirectionIdx,
    arpRateIdx = state.arpRateIdx,
    arpQuantizeMode = state.arpQuantizeMode or "None",
    inputQuantizeMode = state.inputQuantizeMode or "Off",
    padChords = {
      transposer.getDiatonicPadChord(1).name,
      transposer.getDiatonicPadChord(2).name,
      transposer.getDiatonicPadChord(3).name,
      transposer.getDiatonicPadChord(4).name,
      transposer.getDiatonicPadChord(5).name,
      transposer.getDiatonicPadChord(6).name,
      transposer.getDiatonicPadChord(7).name,
      transposer.getDiatonicPadChord(8).name
    },
    stackedKeyLabelsInPerformanceMode = state.stackedKeyLabelsInPerformanceMode == true,
    rootIdx = state.currentRoot,
    arpGatePercent = math.floor((state.arpGatePercent or 80.0) + 0.5),
    bpmDisplay = bpmDisplayStr,
    bpmEditing = state.bpmInputMode,
    logicSyncEnabled = state.logicSyncEnabled,
    arpTopEnabled = state.arpTopEnabled,
    arpBottomEnabled = state.arpBottomEnabled,
    arpLinked = state.arpLinked,
    statusText = statusStr,
    topOctaveStr = topOctaveStr,
    bottomOctaveStr = bottomOctaveStr,
    topVolPercent = math.floor((state.topRowVolume / 127) * 100),
    bottomVolPercent = math.floor((state.bottomRowVolume / 127) * 100),
    effectiveTopVolPercent = math.floor((transposer.getEffectiveRowVelocity(true) / 127) * 100),
    modeFrac = modeFrac,
    modWheel = modVal,
    zoomLevel = effectiveScale,
    spotlight = spotlightInfo,
    scaleGuide = transposer.getScaleGuideInfo and transposer.getScaleGuideInfo(48, 72) or nil,
    scaleGuideEnabled = state.scaleGuideEnabled ~= false,
    keys = keyUpdates
  }

  local jsonStr = hs.json.encode(payload)
  local ok, err = pcall(function()
    _G.activeWatchers.midiWebview:evaluateJavaScript("renderHud(" .. jsonStr .. ")")
  end)
  if ok then
    evalFailCount = 0
  else
    evalFailCount = evalFailCount + 1
    if evalFailCount >= 3 then
      hudLog("webview appears dead (" .. evalFailCount .. " consecutive evaluateJS failures) — recreating")
      evalFailCount = 0
      hs.timer.doAfter(0.1, function()
        if state.midiActive then
          local rok, rerr = pcall(function()
            local h = createMidiWebview()
            h:show()
          end)
          if not rok then
            hudLog("webview recreate failed: " .. tostring(rerr))
          end
        end
      end)
    end
  end
end


local lastFullRenderTime = 0
local renderScheduled = false
local arpHudUpdateScheduled = false

updateWebviewHud = function(spotlightInfo, activeArpPitch, forceImmediate)
  if spotlightInfo ~= nil then pendingSpotlightInfo = spotlightInfo end
  if activeArpPitch ~= nil then pendingActiveArpPitch = activeArpPitch end

  if forceImmediate then
    performWebviewHudUpdate(pendingSpotlightInfo, pendingActiveArpPitch)
    pendingSpotlightInfo = nil
    return
  end

  if renderScheduled then return end

  local now = hs.timer.absoluteTime()
  local elapsedMs = (now - lastFullRenderTime) / 1000000
  if elapsedMs >= 33 then
    lastFullRenderTime = now
    performWebviewHudUpdate(pendingSpotlightInfo, pendingActiveArpPitch)
    pendingSpotlightInfo = nil
  else
    renderScheduled = true
    local delaySec = math.max(0.005, (33 - elapsedMs) / 1000)
    hs.timer.doAfter(delaySec, function()
      renderScheduled = false
      lastFullRenderTime = hs.timer.absoluteTime()
      local s = pendingSpotlightInfo
      local a = pendingActiveArpPitch
      pendingSpotlightInfo = nil
      performWebviewHudUpdate(s, a)
    end)
  end
end

local function createMidiWebview()
  hudLog("createMidiWebview")
  webviewGeneration = webviewGeneration + 1
  lastHeartbeat = os.time()
  evalFailCount = 0
  _G.activeWatchers.domIsReady = false
  local myGen = webviewGeneration
  if _G.activeWatchers.midiWebview then
    -- Clear callback BEFORE delete to prevent async race nuking new webview ref
    _G.activeWatchers.midiWebview:windowCallback(nil)
    _G.activeWatchers.midiWebview:delete()
    _G.activeWatchers.midiWebview = nil
  end

  local screen = hs.screen.mainScreen():frame()
  local effectiveScale = state.zoomLevel * state.BASE_HUD_SCALE
  local NOTIF_BAND = math.floor(50 * effectiveScale)
  local width = math.floor(980 * effectiveScale)
  local baseH = getDesiredBaseHeight()
  local height = math.floor(baseH * effectiveScale) + NOTIF_BAND
  local savedX = hs.settings.get("qwertyMidi_hudX")
  local savedY = hs.settings.get("qwertyMidi_hudY")
  local hudX = savedX or _G.activeWatchers.hudX or math.floor(screen.x + (screen.w - width) / 2)
  local hudY = savedY or _G.activeWatchers.hudY or math.floor(screen.y + screen.h - height - 60)

  local uc = hsUsercontent.new("midiControllerUC")
  uc:setCallback(function(msg)
    if not msg or not msg.body then return end
    local body = msg.body
    if body.type == "domReady" then
      hudLog("domReady")
      _G.activeWatchers.domIsReady = true
      lastHeartbeat = os.time()
      evalFailCount = 0
      updateWebviewHud()
    elseif body.type == "pong" then
      lastPongTime = os.time()
      lastHeartbeat = os.time()
      if pendingPingTime > 0 then
        lastLatencyMs = math.max(0, math.floor((hs.timer.absoluteTime() - pendingPingTime) / 1000000))
        pendingPingTime = 0
      end
    elseif body.type == "ping" then
      safeEvaluateJS("if (window.pingHudController) window.pingHudController();")
    elseif body.type == "heartbeat" then
      lastHeartbeat = os.time()
    elseif body.type == "keyDown" and body.code then
      if controlsModule then controlsModule.handleKeyDown(body.code) end
    elseif body.type == "keyUp" and body.code then
      if controlsModule then controlsModule.handleKeyUp(body.code) end
    elseif body.type == "trkMute" and body.trackId then
      local tId = math.floor(tonumber(body.trackId) or 0)
      if controlsModule and controlsModule.executeControlAction and tId >= 1 and tId <= 4 then
        controlsModule.executeControlAction(string.format("trkMute%d", tId))
      end
    elseif body.type == "trkSolo" and body.trackId then
      local tId = math.floor(tonumber(body.trackId) or 0)
      if controlsModule and controlsModule.executeControlAction and tId >= 1 and tId <= 4 then
        controlsModule.executeControlAction(string.format("trkSolo%d", tId))
      end
    elseif body.type == "selectTrack" and body.trackId then
      local tId = math.floor(tonumber(body.trackId) or 0)
      if controlsModule and controlsModule.selectTrack and tId >= 1 and tId <= 4 then
        controlsModule.selectTrack(tId)
      end
    elseif body.type == "setRoot" and body.root ~= nil then
      state.currentRoot = math.max(0, math.min(11, body.root))
      arpeggiator.updateLatchedArpNotes()
      if _G.activeWatchers.nanokey and _G.activeWatchers.nanokey.syncScaleGuideLeds then
        _G.activeWatchers.nanokey.syncScaleGuideLeds(state)
      end
      local rootName = NOTE_NAMES[state.currentRoot + 1]
      local spot = {
        title = "ROOT NOTE",
        value = rootName,
        subtext = rootName .. " " .. SCALES[state.currentScaleIdx].name,
        targetId = "root-select",
        color = "#d4a359"
      }
      updateWebviewHud(spot)
    elseif body.type == "setModeIdx" and body.modeIdx ~= nil then
      state.currentScaleIdx = math.max(1, math.min(#SCALES, body.modeIdx))
      arpeggiator.updateLatchedArpNotes()
      if _G.activeWatchers.nanokey and _G.activeWatchers.nanokey.syncScaleGuideLeds then
        _G.activeWatchers.nanokey.syncScaleGuideLeds(state)
      end
      local scaleInfo = SCALES[state.currentScaleIdx]
      local spot = {
        title = "SCALE / MODE",
        value = scaleInfo.name,
        subtext = scaleInfo.brightTag,
        targetId = "mode-thumb",
        color = "#d4a359"
      }
      updateWebviewHud(spot)
    elseif body.type == "toggleArpPower" then
      arpeggiator.toggleArpPower()
    elseif body.type == "setArpDirection" and body.directionIdx ~= nil then
      state.arpDirectionIdx = math.max(1, math.min(#ARP_DIRECTIONS, body.directionIdx))
      local spot = {
        title = "ARP DIRECTION",
        value = ARP_DIRECTIONS[state.arpDirectionIdx],
        subtext = state.arpEnabled and "Active Pattern" or "Arp Disabled",
        targetId = "arp-dir-select",
        color = "#d4a359"
      }
      updateWebviewHud(spot)
    elseif body.type == "setArpQuantize" and body.value ~= nil then
      state.arpQuantizeMode = body.value
      hs.settings.set("qwertyMidi_arpQuantizeMode", state.arpQuantizeMode)
      local spot = {
        title = "QUANTIZE",
        value = string.upper(body.value),
        subtext = "Note Change Quantization",
        targetId = "arp-quantize-select",
        color = "#d4a359"
      }
      updateWebviewHud(spot)
    elseif body.type == "setInputQuantize" and body.value ~= nil then
      state.inputQuantizeMode = body.value
      hs.settings.set("qwertyMidi_inputQuantizeMode", state.inputQuantizeMode)
      local spot = {
        title = "INPUT QUANTIZE",
        value = string.upper(body.value),
        subtext = "Live Input Quantization Grid",
        targetId = "input-quantize-select",
        color = "#d4a359"
      }
      updateWebviewHud(spot)
    elseif body.type == "setArpRate" and body.rateIdx ~= nil then
      state.arpRateIdx = math.max(1, math.min(#ARP_RATES, body.rateIdx))
      arpeggiator.applyBpmChange()
      local spot = {
        title = "ARP RATE",
        value = ARP_RATES[state.arpRateIdx].label,
        subtext = "Note Division",
        targetId = "arp-rate-select",
        color = "#d4a359"
      }
      updateWebviewHud(spot)
    elseif body.type == "dragGate" and body.delta ~= nil then
      state.arpGatePercent = math.max(5.0, math.min(150.0, (state.arpGatePercent or 80.0) + body.delta))
      arpeggiator.applyGatePercentChange()
      local spot = {
        title = "ARP NOTE LENGTH",
        value = math.floor(state.arpGatePercent + 0.5) .. "%",
        subtext = "Gate Duration",
        targetId = "gate-value",
        color = "#d4a359"
      }
      updateWebviewHud(spot)
    elseif body.type == "gateUp" then
      state.arpGatePercent = math.min(150.0, (state.arpGatePercent or 80.0) + 5.0)
      arpeggiator.applyGatePercentChange()
      local spot = {
        title = "ARP NOTE LENGTH",
        value = math.floor(state.arpGatePercent + 0.5) .. "%",
        subtext = "Gate Duration",
        targetId = "gate-value",
        color = "#d4a359"
      }
      updateWebviewHud(spot)
    elseif body.type == "gateDown" then
      state.arpGatePercent = math.max(5.0, (state.arpGatePercent or 80.0) - 5.0)
      arpeggiator.applyGatePercentChange()
      local spot = {
        title = "ARP NOTE LENGTH",
        value = math.floor(state.arpGatePercent + 0.5) .. "%",
        subtext = "Gate Duration",
        targetId = "gate-value",
        color = "#d4a359"
      }
      updateWebviewHud(spot)
    elseif body.type == "enterBpmEdit" then
      state.bpmInputMode = true
      state.bpmBeforeEdit = state.arpBpm
      state.bpmInputBuffer = ""
      local spot = {
        title = "EDIT BPM",
        value = "TYPE TEMPO",
        subtext = "Type digits & press Enter",
        targetId = "bpm-value",
        color = "#d4a359"
      }
      updateWebviewHud(spot)
    elseif body.type == "bpmUp" then
      local step = state.bpmStepSize or 10
      state.arpBpm = math.min(300, state.arpBpm + step)
      arpeggiator.applyBpmChange()
      arpeggiator.stepLogicBpm(step)
      updateWebviewHud()
    elseif body.type == "bpmDown" then
      local step = state.bpmStepSize or 10
      state.arpBpm = math.max(20, state.arpBpm - step)
      arpeggiator.applyBpmChange()
      arpeggiator.stepLogicBpm(-step)
      updateWebviewHud()
    elseif body.type == "toggleLogicSync" then
      arpeggiator.toggleLogicSync()
    elseif body.type == "dragBpm" and body.delta ~= nil then
      state.arpBpm = math.max(20.0, math.min(300.0, state.arpBpm + body.delta))
      arpeggiator.applyBpmChange()
      if arpeggiator.setLogicBpmTarget then arpeggiator.setLogicBpmTarget(state.arpBpm) end
      updateWebviewHud()
    elseif body.type == "toggleArpTop" then
      if controlsModule and controlsModule.executeControlAction then
        controlsModule.executeControlAction("arpTopToggle")
      end
    elseif body.type == "toggleArpBottom" then
      if controlsModule and controlsModule.executeControlAction then
        controlsModule.executeControlAction("arpBottomToggle")
      end
    elseif body.type == "dragOctave" and body.row and body.direction then
      if body.row == "top" then
        state.topRowOctaveOffset = math.max(-48, math.min(36, state.topRowOctaveOffset + (body.direction * 12)))
        hs.settings.set("qwertyMidi_topRowOctaveOffset", state.topRowOctaveOffset)
      else
        state.bottomRowOctaveOffset = math.max(-48, math.min(36, state.bottomRowOctaveOffset + (body.direction * 12)))
        hs.settings.set("qwertyMidi_bottomRowOctaveOffset", state.bottomRowOctaveOffset)
      end
      updateWebviewHud()
    elseif body.type == "dragWindow" and body.dx and body.dy then
      if _G.activeWatchers.midiWebview then
        local frame = _G.activeWatchers.midiWebview:frame()
        local newX = math.floor(frame.x + body.dx)
        local newY = math.floor(frame.y + body.dy)
        _G.activeWatchers.midiWebview:frame({ x = newX, y = newY, w = frame.w, h = frame.h })
        _G.activeWatchers.hudX = newX
        _G.activeWatchers.hudY = newY
        hs.settings.set("qwertyMidi_hudX", newX)
        hs.settings.set("qwertyMidi_hudY", newY)
      end
    elseif body.type == "toggleEditMode" then
      if _G.activeWatchers.midiWebview then
        local wv = _G.activeWatchers.midiWebview
        local frame = wv:frame()
        local effectiveScale = state.zoomLevel * state.BASE_HUD_SCALE
        local editH = math.floor(580 * effectiveScale)
        if body.active then
          _savedNormalHeight = frame.h
          local diffH = editH - frame.h
          wv:frame({ x = frame.x, y = frame.y - diffH, w = frame.w, h = editH })
        else
          local restoreH = _savedNormalHeight or math.floor(330 * effectiveScale)
          local diffH = frame.h - restoreH
          _savedNormalHeight = nil
          wv:frame({ x = frame.x, y = frame.y + diffH, w = frame.w, h = restoreH })
        end
      end
    elseif body.type == "getLayoutConfig" then
      if _G.activeWatchers.midiWebview then
        local cfgJson = hs.json.encode(config.getLayoutConfig())
        safeEvaluateJS("if (window.onLayoutConfigLoaded) window.onLayoutConfigLoaded(" .. cfgJson .. ");")
      end
    elseif body.type == "saveCustomLayout" then
      config.saveCustomLayout(body.layout or body.data)
      updateWebviewHud(nil, nil, true)
      if _G.activeWatchers.midiWebview then
        local cfgJson = hs.json.encode(config.getLayoutConfig())
        safeEvaluateJS("if (window.onLayoutConfigLoaded) window.onLayoutConfigLoaded(" .. cfgJson .. ");")
      end
    elseif body.type == "selectPreset" then
      config.selectPreset(body.id)
      updateWebviewHud(nil, nil, true)
      if _G.activeWatchers.midiWebview then
        local cfgJson = hs.json.encode(config.getLayoutConfig())
        safeEvaluateJS("if (window.onLayoutConfigLoaded) window.onLayoutConfigLoaded(" .. cfgJson .. ");")
      end
    elseif body.type == "savePreset" then
      config.savePreset(body.id, body.name, body.layout or body.data)
      updateWebviewHud(nil, nil, true)
      if _G.activeWatchers.midiWebview then
        local cfgJson = hs.json.encode(config.getLayoutConfig())
        safeEvaluateJS("if (window.onLayoutConfigLoaded) window.onLayoutConfigLoaded(" .. cfgJson .. ");")
      end
    elseif body.type == "renamePreset" then
      config.renamePreset(body.id, body.newName)
      if _G.activeWatchers.midiWebview then
        local cfgJson = hs.json.encode(config.getLayoutConfig())
        safeEvaluateJS("if (window.onLayoutConfigLoaded) window.onLayoutConfigLoaded(" .. cfgJson .. ");")
      end
    elseif body.type == "deletePreset" then
      config.deletePreset(body.id)
      updateWebviewHud(nil, nil, true)
      if _G.activeWatchers.midiWebview then
        local cfgJson = hs.json.encode(config.getLayoutConfig())
        safeEvaluateJS("if (window.onLayoutConfigLoaded) window.onLayoutConfigLoaded(" .. cfgJson .. ");")
      end
    elseif body.type == "duplicatePreset" then
      config.duplicatePreset(body.id, body.newName)
      updateWebviewHud(nil, nil, true)
      if _G.activeWatchers.midiWebview then
        local cfgJson = hs.json.encode(config.getLayoutConfig())
        safeEvaluateJS("if (window.onLayoutConfigLoaded) window.onLayoutConfigLoaded(" .. cfgJson .. ");")
      end
    elseif body.type == "resetLayout" then
      config.resetLayout()
      updateWebviewHud(nil, nil, true)
      if _G.activeWatchers.midiWebview then
        local cfgJson = hs.json.encode(config.getLayoutConfig())
        safeEvaluateJS("if (window.onLayoutConfigLoaded) window.onLayoutConfigLoaded(" .. cfgJson .. ");")
      end
    elseif body.type == "updateKeyMapping" then
      if body.code and body.binding then
        config.updateKeyMapping(body.code, body.binding)
        updateWebviewHud(nil, nil, true)
      end
    elseif body.type == "textInputFocus" then
      state.textInputActive = (body.focused == true)
    elseif body.type == "log" then
      if body.message then
        local line = os.date("%H:%M:%S") .. " [JS]: " .. tostring(body.message) .. "\n"
        local f1 = io.open("/tmp/wv_js.log", "a")
        if f1 then f1:write(line); f1:close() end
        local f2 = io.open("/Users/matt/projects/qwerty-midi-hammerspoon/tmp/qwerty_midi_debug.log", "a")
        if f2 then f2:write(line); f2:close() end
      end
    elseif body.type == "hoverScrollable" then
      _G.activeWatchers.isHoveringScrollable = body.state
      if body.message then
        local f = io.open("/tmp/wv_js.log", "a")
        if f then
          f:write(tostring(body.message) .. "\n")
          f:close()
        end
      end
    elseif body.type == "switchSurface" then
      setSurfaceView(body.surface)
    elseif body.type == "nanokeyKey" then
      if _G.activeWatchers.nanokey and _G.activeWatchers.nanokey.handleGuiAction then
        _G.activeWatchers.nanokey.handleGuiAction("key", body)
      end
    elseif body.type == "nanokeyPad" then
      if _G.activeWatchers.nanokey and _G.activeWatchers.nanokey.handleGuiAction then
        _G.activeWatchers.nanokey.handleGuiAction("pad", body)
      end
    elseif body.type == "nanokeySustain" then
      if _G.activeWatchers.nanokey and _G.activeWatchers.nanokey.handleGuiAction then
        _G.activeWatchers.nanokey.handleGuiAction("sustain", body)
      end
    elseif body.type == "nanokeyScene" then
      if _G.activeWatchers.nanokey and _G.activeWatchers.nanokey.handleGuiAction then
        _G.activeWatchers.nanokey.handleGuiAction("scene", body)
      end
    elseif body.type == "nanokeyGuide" or body.type == "toggleScaleGuide" then
      if _G.activeWatchers.nanokey and _G.activeWatchers.nanokey.handleGuiAction then
        _G.activeWatchers.nanokey.handleGuiAction("guide", body)
      else
        state.scaleGuideEnabled = not state.scaleGuideEnabled
        if config.saveSettings then config.saveSettings() end
      end
      updateWebviewHud()
    end
    config.saveSettings()
  end)

  local rect = { x = hudX, y = hudY, w = width, h = height }
  local wv = hsWebview.new(rect, { developerExtrasEnabled = true }, uc)
  wv:windowTitle("MIDI Controller HUD")
  wv:windowStyle({ "borderless", "utility" })
  wv:transparent(true)

  wv:html(HTML_UI_CONTENT)
  wv:level(hs.canvas.windowLevels.floating)
  wv:behavior(hs.canvas.windowBehaviors.canJoinAllSpaces)
  wv:show()

  wv:windowCallback(function(action, webview)
    if action == "closing" then
      hudLog("webview teardown (generation " .. myGen .. ")")
      -- Ignore stale callbacks from old webview generations
      if myGen ~= webviewGeneration then return end
      _G.activeWatchers.midiWebview = nil
      -- If midiActive is still true, the webview crashed unexpectedly — auto-respawn
      if state.midiActive then
        hudLog("webview closed unexpectedly — respawning in 0.5s")
        hs.timer.doAfter(0.5, function()
          if state.midiActive and myGen == webviewGeneration then
            local ok, err = pcall(function()
              local h = createMidiWebview()
              h:show()
            end)
            if not ok then
              hudLog("webview respawn failed: " .. tostring(err))
            end
          end
        end)
      end
    end
  end)

  _G.activeWatchers.midiWebview = wv

  hs.timer.doAfter(0.05, function()
    if _G.activeWatchers.midiWebview then
      updateWebviewHud()
    end
  end)
  hs.timer.doAfter(0.25, function()
    if _G.activeWatchers.midiWebview then
      updateWebviewHud()
    end
  end)
  hs.timer.doAfter(1.0, function()
    if _G.activeWatchers.midiWebview and myGen == webviewGeneration then
      updateWebviewHud()
    end
  end)

  return wv
end

local function pingWebview()
  if not _G.activeWatchers.midiWebview then return false end
  hudLog("ping")
  pendingPingTime = hs.timer.absoluteTime()
  safeEvaluateJS("if (window.pingHudController) window.pingHudController();")
  return true
end

local function pongWebview()
    hudLog("pong")
end

local function processLogFile(path, label, output)
  table.insert(output, "\n--- " .. label .. " ---")
  table.insert(output, "Full log filepath: " .. path)
  local f = io.open(path, "r")
  if not f then
    table.insert(output, "(File not found)")
    return
  end

  local allLines = {}
  for line in f:lines() do
    table.insert(allLines, line)
  end
  f:close()

  if #allLines == 0 then
    table.insert(output, "(Log is empty)")
    return
  end

  local seen = {}
  local errorLines = {}
  for _, line in ipairs(allLines) do
    local lower = line:lower()
    if lower:find("error") or lower:find("fail") or lower:find("exception") or lower:find("crash") or lower:find("warn") or lower:find("err") then
      if not seen[line] then
        seen[line] = true
        table.insert(errorLines, line)
      end
    end
  end

  if #errorLines > 0 then
    table.insert(output, "[Detected Errors/Warnings (" .. #errorLines .. " lines)]:")
    for _, line in ipairs(errorLines) do
      table.insert(output, "  " .. line)
    end
  end

  table.insert(output, "[Recent Activity (last 20 lines)]:")
  local startIndex = math.max(1, #allLines - 19)
  local recentCount = 0
  for i = startIndex, #allLines do
    local line = allLines[i]
    if not seen[line] then
      table.insert(output, "  " .. line)
      recentCount = recentCount + 1
    end
  end
  if recentCount == 0 and #errorLines > 0 then
    table.insert(output, "  (All recent lines were already listed under errors)")
  end
end

local function dumpMidiLogs()
  local output = {}
  table.insert(output, "=== QWERTY MIDI DIAGNOSTICS & LOGS ===")
  table.insert(output, "Time: " .. os.date("%Y-%m-%d %H:%M:%S"))
  table.insert(output, "Webview Gen: " .. tostring(webviewGeneration))
  table.insert(output, "Last Heartbeat: " .. tostring(os.time() - lastHeartbeat) .. "s ago")
  table.insert(output, "Last Pong: " .. tostring(os.time() - lastPongTime) .. "s ago (Latency: " .. lastLatencyMs .. "ms)")
  table.insert(output, "Eval Failures: " .. tostring(evalFailCount))
  
  processLogFile("/tmp/midi_startup.log", "Startup Log", output)
  processLogFile("/tmp/wv_js.log", "Webview JS Log", output)

  local res = table.concat(output, "\n")
  print(res)
  hs.pasteboard.setContents(res)
  hs.alert.show("Diagnostics Log Copied to Clipboard", 2)
  return res
end

local function pingController()
  pingWebview()
  hs.timer.doAfter(0.15, function()
    local now = os.time()
    if (now - lastPongTime) < 2 then
      hs.alert.show(string.format("🟢 QWERTY MIDI UI Responsive (Latency: %dms)", lastLatencyMs), 2)
    else
      hs.alert.show("🔴 QWERTY MIDI UI Unresponsive", 2)
    end
  end)
  return (os.time() - lastPongTime) < 2
end

local function reloadMidiWebview()
  lastFrameScale = nil
  if _G.activeWatchers.midiWebview then
    pcall(function()
      _G.activeWatchers.midiWebview:windowCallback(nil)
      _G.activeWatchers.midiWebview:delete()
    end)
    _G.activeWatchers.midiWebview = nil
  end
  _G.activeWatchers.domIsReady = false
  return createMidiWebview()
end

local function fastUpdateArpNow()
  if not _G.activeWatchers.midiWebview or not _G.activeWatchers.domIsReady then return end

  local activeCodes = {}
  local heldCodes = {}

  local arpHeldPitches = { [1] = {}, [2] = {}, [3] = {}, [4] = {} }
  local currentArpPitches = { [1] = {}, [2] = {}, [3] = {}, [4] = {} }

  if state.tracks then
    for trkId = 1, 4 do
      local trk = state.tracks[trkId]
      if trk and trk.arpEnabled then
        for _, pitch in pairs(trk.heldNotes or {}) do
          if type(pitch) == "number" then arpHeldPitches[trkId][pitch] = true end
        end
        local p = type(trk.currentPitch) == "table" and trk.currentPitch.pitch or trk.currentPitch
        if p then currentArpPitches[trkId][p] = true end
      end
    end
  end

  for code, kData in pairs(config.getActiveNoteKeysMap()) do
    local trkId = kData.isTop and (state.topRowTrack or 3) or (state.bottomRowTrack or 1)
    local trk = state.tracks and state.tracks[trkId]
    if trk and trk.arpEnabled then
      local noteNum = transposer.getTransposedPitch(kData.baseNote, kData.isTop)
      if currentArpPitches[trkId][noteNum] then
        table.insert(activeCodes, tostring(code))
      end
      if arpHeldPitches[trkId][noteNum] then
        table.insert(heldCodes, tostring(code))
      end
    end
  end

  local js = string.format("if (window.updateArpPitches) window.updateArpPitches(%s, %s);",
    hs.json.encode(activeCodes),
    hs.json.encode(heldCodes))
  safeEvaluateJS(js)
end

local function queueArpHudUpdate()
  if arpHudUpdateScheduled then return end
  arpHudUpdateScheduled = true
  hs.timer.doAfter(0, function()
    arpHudUpdateScheduled = false
    fastUpdateArpNow()
  end)
end

return {
  setControlsModule = setControlsModule,
  fastUpdateArp = queueArpHudUpdate,
  updateSingleKeyState = updateSingleKeyState,
  updateWebviewHud = updateWebviewHud,
  createMidiWebview = createMidiWebview,
  reloadMidiWebview = reloadMidiWebview,
  getLastHeartbeat = function() return lastHeartbeat end,
  pingWebview = pingWebview,
  pingController = pingController,
  getLastPongTime = function() return lastPongTime end,
  getLastLatencyMs = function() return lastLatencyMs end,
  dumpMidiLogs = dumpMidiLogs,
  setSurfaceView = setSurfaceView,
  updateNanoKeyControl = updateNanoKeyControl,
  isNanokeyConnected = isNanokeyConnected,
  getDesiredBaseHeight = getDesiredBaseHeight,
  updateConnectionStatus = updateConnectionStatus,
  getProposedActionSpotlight = getProposedActionSpotlight,
  getProposedActionDef = getProposedActionDef,
  PROPOSED_LAYOUT_MAP = PROPOSED_LAYOUT_MAP
}
