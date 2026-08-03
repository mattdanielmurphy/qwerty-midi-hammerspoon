local function getSetting(key, default)
  local val = hs.settings.get("qwertyMidi_" .. key)
  if val == nil then return default end
  if type(default) == "number" then
    local num = tonumber(val)
    return num ~= nil and num or default
  elseif type(default) == "boolean" then
    if type(val) == "boolean" then return val end
    if type(val) == "number" then return val ~= 0 end
    if type(val) == "string" then return val == "true" or val == "1" end
  end
  return val
end

local state = {
  midiActive = false,
  currentMode = "Home",
  modeSelectHeld = false,
  modeWasSelectedDuringHold = false,
  currentRoot = getSetting("currentRoot", 0),            -- 0 = C (0..11)
  currentScaleIdx = getSetting("currentScaleIdx", 1),    -- 1 = Major / Ionian
  octaveShift = getSetting("octaveShift", 0),            -- Global Octave offset in semitones (-36 to +36)
  topRowOctaveOffset = getSetting("topRowOctaveOffset", 12), -- Independent Top Row Octave Offset
  bottomRowOctaveOffset = getSetting("bottomRowOctaveOffset", 0), -- Independent Bottom Row Octave Offset
  transposeShift = getSetting("transposeShift", 0),     -- Transpose offset in scale degrees (-12 to +12)
  sustainActive = false,      -- Sustain toggle state (CC64)
  sustainKeyDownTime = 0,     -- Timestamp when sustain key was pressed down
  sustainWasActiveOnPress = false,
  arpLatchActive = getSetting("arpLatchActive", false),  -- Arpeggiator Latch mode
  shiftHeld = false,          -- Shift key active state
  zoomLevel = getSetting("zoomLevel", 1.0),
  BASE_HUD_SCALE = 1.4,

  -- UI Styling
  uiActionKeyHue = getSetting("uiActionKeyHue", 30),
  uiActionKeySat = getSetting("uiActionKeySat", 20),
  uiActionKeyLight = getSetting("uiActionKeyLight", 75),
  uiActionKeyOpacity = getSetting("uiActionKeyOpacity", 0.08),
  uiActionKeyBorderOpacity = getSetting("uiActionKeyBorderOpacity", 0.6),

  -- Chord Trigger State
  chordIdx = getSetting("chordIdx", 1),
  quoteHeld = false,
  CHORDS = {
    { name = "Triad", offsets = { 0, 2, 4 } },
    { name = "7th", offsets = { 0, 2, 4, 6 } },
    { name = "9th", offsets = { 0, 2, 4, 6, 8 } },
    { name = "Power (1-5)", offsets = { 0, 4 } },
    { name = "Octaves", offsets = { 0, 7 } }
  },

  -- Arpeggiator State
  arpEnabled = getSetting("arpEnabled", false),
  arpDirectionIdx = getSetting("arpDirectionIdx", 1),    -- 1: UP, 2: DOWN, 3: UP-DOWN, 4: DOWN-UP, 5: CONVERGE, 6: DIVERGE, 7: RANDOM
  ARP_DIRECTIONS = { "UP", "DOWN", "UP-DOWN", "DOWN-UP", "CONVERGE", "DIVERGE", "RANDOM" },
  arpRateIdx = getSetting("arpRateIdx", 5),
  ARP_RATES = {
    -- Straight rates (slow → fast)
    { label = "4",     factor = 16.0 },
    { label = "2",     factor = 8.0 },
    { label = "1",     factor = 4.0 },
    { label = "1/2",   factor = 2.0 },
    { label = "1/4",   factor = 1.0 },
    { label = "1/8",   factor = 0.5 },
    { label = "1/16",  factor = 0.25 },
    { label = "1/32",  factor = 0.125 },
    { label = "1/64",  factor = 0.0625 },
    -- Triplet rates (slow → fast)
    { label = "4T",    factor = 16.0 / 1.5 },
    { label = "2T",    factor = 8.0  / 1.5 },
    { label = "1T",    factor = 4.0  / 1.5 },
    { label = "1/2T",  factor = 2.0  / 1.5 },
    { label = "1/4T",  factor = 1.0  / 1.5 },
    { label = "1/8T",  factor = 0.5  / 1.5 },
    { label = "1/16T", factor = 0.25 / 1.5 },
    { label = "1/32T", factor = 0.125 / 1.5 },
    { label = "1/64T", factor = 0.0625 / 1.5 }
  },
  arpGatePercent = getSetting("arpGatePercent", 80.0),
  arpQuantizeMode = getSetting("arpQuantizeMode", "None"),
  arpBpm = getSetting("arpBpm", 120.0),
  arpTimer = nil,
  arpGateTimer = nil,
  arpHeldNotes = {},          -- [code] = pitch
  arpKeysCurrentlyHeld = {},  -- [code] = true
  arpCurrentPitch = nil,
  arpStepIndex = 1,
  arpStepDirection = 1,
  lastArpMode = 1,
  arpTopEnabled = getSetting("arpTopEnabled", true),
  arpBottomEnabled = getSetting("arpBottomEnabled", true),

  -- BPM Input Mode & Sync State
  bpmInputMode = false,
  bpmInputBuffer = "",
  bpmBeforeEdit = 120.0,
  bpmStepSize = getSetting("bpmStepSize", 10),
  logicSyncEnabled = (hs.settings.get("qwertyMidi_logicSyncEnabled") == nil) and true or hs.settings.get("qwertyMidi_logicSyncEnabled"),
  logicSyncTimer = nil,

  -- Scroll / Trackpad
  scrollSensitivity     = getSetting("scrollSensitivity", 0.15),
  scrollAcceleration    = getSetting("scrollAcceleration", 1.0),
  scrollInertiaInitial  = getSetting("scrollInertiaInitial", 1.0),
  scrollInertiaDecay    = getSetting("scrollInertiaDecay", 0.85),
  scrollCurveExponent   = getSetting("scrollCurveExponent", 1.0),
  scrollMaxInertiaMs    = getSetting("scrollMaxInertiaMs", 250),
  scrollInertiaCutoff   = getSetting("scrollInertiaCutoff", 0.5),

  DIGIT_KEYCODES = {
    [50] = "`", [29] = "0", [18] = "1", [19] = "2", [20] = "3", [21] = "4",
    [23] = "5", [22] = "6", [26] = "7", [28] = "8", [25] = "9"
  },

  topRowVolume = getSetting("topRowVolume", 100),
  bottomRowVolume = getSetting("bottomRowVolume", 100),
  topRowChannel = getSetting("topRowChannel", 0),       -- MIDI Channel 0 (Ch 1 in 1-based indexing)
  bottomRowChannel = getSetting("bottomRowChannel", 1),    -- MIDI Channel 1 (Ch 2 in 1-based indexing)
  arpChannel = getSetting("arpChannel", 2),            -- Dedicated Arp MIDI Channel 2 (Ch 3 in 1-based indexing)
  splitArpTopBoost = 20,

  ccStates = {
    [1] = 0,
    [7] = 100,
    [72] = 64
  },

  chordIdx = getSetting("chordIdx", 1),
  quoteHeld = false,
  CHORDS = { { name = "Triad", offsets = { 0, 2, 4 } }, { name = "7th", offsets = { 0, 2, 4, 6 } }, { name = "9th", offsets = { 0, 2, 4, 6, 8 } }, { name = "Power (1-5)", offsets = { 0, 4 } }, { name = "Octaves", offsets = { 0, 7 } } },
  pressedKeys = {},
  sustainedPitches = {},
  spotlightInfo = nil,
  stackedKeyLabelsInPerformanceMode = getSetting("stackedKeyLabelsInPerformanceMode", false)
}

local function saveSettings()
  state.currentRoot = tonumber(state.currentRoot) or 0
  state.currentScaleIdx = tonumber(state.currentScaleIdx) or 1
  state.octaveShift = tonumber(state.octaveShift) or 0
  state.topRowOctaveOffset = tonumber(state.topRowOctaveOffset) or 0
  state.bottomRowOctaveOffset = tonumber(state.bottomRowOctaveOffset) or 0
  state.transposeShift = tonumber(state.transposeShift) or 0
  state.arpDirectionIdx = tonumber(state.arpDirectionIdx) or 1
  state.arpRateIdx = tonumber(state.arpRateIdx) or 5
  state.arpGatePercent = tonumber(state.arpGatePercent) or 80.0
  state.arpBpm = tonumber(state.arpBpm) or 120.0
  state.bpmStepSize = tonumber(state.bpmStepSize) or 10
  state.scrollSensitivity = tonumber(state.scrollSensitivity) or 0.15
  state.scrollAcceleration = tonumber(state.scrollAcceleration) or 1.0
  state.scrollInertiaInitial = tonumber(state.scrollInertiaInitial) or 1.0
  state.scrollInertiaDecay = tonumber(state.scrollInertiaDecay) or 0.85
  state.scrollCurveExponent = tonumber(state.scrollCurveExponent) or 1.0
  state.scrollMaxInertiaMs = tonumber(state.scrollMaxInertiaMs) or 250
  state.scrollInertiaCutoff = tonumber(state.scrollInertiaCutoff) or 0.5
  state.topRowVolume = tonumber(state.topRowVolume) or 100
  state.bottomRowVolume = tonumber(state.bottomRowVolume) or 100
  state.zoomLevel = tonumber(state.zoomLevel) or 1.0

  hs.settings.set("qwertyMidi_currentRoot", state.currentRoot)
  hs.settings.set("qwertyMidi_currentScaleIdx", state.currentScaleIdx)
  hs.settings.set("qwertyMidi_octaveShift", state.octaveShift)
  hs.settings.set("qwertyMidi_topRowOctaveOffset", state.topRowOctaveOffset)
  hs.settings.set("qwertyMidi_bottomRowOctaveOffset", state.bottomRowOctaveOffset)
  hs.settings.set("qwertyMidi_transposeShift", state.transposeShift)
  hs.settings.set("qwertyMidi_arpEnabled", state.arpEnabled == true)
  hs.settings.set("qwertyMidi_chordModeActive", state.chordModeActive == true)
  hs.settings.set("qwertyMidi_chordIdx", state.chordIdx)
  hs.settings.set("qwertyMidi_arpLatchActive", state.arpLatchActive == true)
  hs.settings.set("qwertyMidi_arpDirectionIdx", state.arpDirectionIdx)
  hs.settings.set("qwertyMidi_arpRateIdx", state.arpRateIdx)
  hs.settings.set("qwertyMidi_arpQuantizeMode", state.arpQuantizeMode)
  hs.settings.set("qwertyMidi_arpGatePercent", state.arpGatePercent)
  hs.settings.set("qwertyMidi_arpBpm", state.arpBpm)
  hs.settings.set("qwertyMidi_arpTopEnabled", state.arpTopEnabled == true)
  hs.settings.set("qwertyMidi_arpBottomEnabled", state.arpBottomEnabled == true)
  hs.settings.set("qwertyMidi_bpmStepSize", state.bpmStepSize)
  hs.settings.set("qwertyMidi_logicSyncEnabled", state.logicSyncEnabled == true)
  hs.settings.set("qwertyMidi_scrollSensitivity", state.scrollSensitivity)
  hs.settings.set("qwertyMidi_scrollAcceleration", state.scrollAcceleration)
  hs.settings.set("qwertyMidi_scrollInertiaInitial", state.scrollInertiaInitial)
  hs.settings.set("qwertyMidi_scrollInertiaDecay", state.scrollInertiaDecay)
  hs.settings.set("qwertyMidi_scrollCurveExponent", state.scrollCurveExponent)
  hs.settings.set("qwertyMidi_scrollMaxInertiaMs", state.scrollMaxInertiaMs)
  hs.settings.set("qwertyMidi_scrollInertiaCutoff", state.scrollInertiaCutoff)
  hs.settings.set("qwertyMidi_topRowVolume", state.topRowVolume)
  hs.settings.set("qwertyMidi_bottomRowVolume", state.bottomRowVolume)
  hs.settings.set("qwertyMidi_zoomLevel", state.zoomLevel)
  hs.settings.set("qwertyMidi_stackedKeyLabelsInPerformanceMode", state.stackedKeyLabelsInPerformanceMode == true)
end

local SCALES = {
  { name = "Lydian",                  intervals = { 0, 2, 4, 6, 7, 9, 11 }, brightness = 6, brightTag = "BRIGHTEST ☀️" },
  { name = "Major / Ionian",          intervals = { 0, 2, 4, 5, 7, 9, 11 }, brightness = 5, brightTag = "BRIGHT 🌤" },
  { name = "Mixolydian",              intervals = { 0, 2, 4, 5, 7, 9, 10 }, brightness = 4, brightTag = "WARM ⛅" },
  { name = "Dorian",                  intervals = { 0, 2, 3, 5, 7, 9, 10 }, brightness = 3, brightTag = "NEUTRAL ☁️" },
  { name = "Natural Minor / Aeolian", intervals = { 0, 2, 3, 5, 7, 8, 10 }, brightness = 2, brightTag = "DARK 🌧" },
  { name = "Phrygian",                intervals = { 0, 1, 3, 5, 7, 8, 10 }, brightness = 1, brightTag = "DARKER 🌩" },
  { name = "Locrian",                 intervals = { 0, 1, 3, 5, 6, 8, 10 }, brightness = 0, brightTag = "DARKEST 🌑" },
  { name = "Harmonic Minor",          intervals = { 0, 2, 3, 5, 7, 8, 11 }, brightness = 2, brightTag = "EXOTIC 🔮" },
  { name = "Melodic Minor",           intervals = { 0, 2, 3, 5, 7, 9, 11 }, brightness = 3, brightTag = "JAZZY 🎷" }
}

local NOTE_NAMES = { "C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B" }

local WHITE_KEY_INDEX = {
  [0] = 0, [1] = -1, [2] = 1, [3] = -1, [4] = 2, [5] = 3,
  [6] = -1, [7] = 4, [8] = -1, [9] = 5, [10] = -1, [11] = 6
}

local defaultNumberRowControls = {
  [18] = { key = "1", name = "Top Arp",  action = "arpTopToggle",   shiftAction = "trnspDown",    shiftName = "Trnsp -" },
  [19] = { key = "2", name = "Bot Arp",  action = "arpBottomToggle",shiftAction = "trnspUp",      shiftName = "Trnsp +" },
  [20] = { key = "3", name = "Dir -",    action = "arpDirDown",     shiftAction = "topOctDown",   shiftName = "TopOct -" },
  [21] = { key = "4", name = "Dir +",    action = "arpDirUp",       shiftAction = "topOctUp",     shiftName = "TopOct +" },
  [23] = { key = "5", name = "Rate -",   action = "arpRateDown",    shiftAction = "botOctDown",   shiftName = "BotOct -" },
  [22] = { key = "6", name = "Rate +",   action = "arpRateUp",      shiftAction = "botOctUp",     shiftName = "BotOct +" },
  [26] = { key = "7", name = "Gate -",   action = "arpGateDown",    shiftAction = "modeDown",     shiftName = "Mode -" },
  [28] = { key = "8", name = "Gate +",   action = "arpGateUp",      shiftAction = "modeUp",       shiftName = "Mode +" },
  [25] = { key = "9", name = "Rel -",    action = "relDown",        shiftAction = "relDown",      shiftName = "Rel -" },
  [29] = { key = "0", name = "Rel +",    action = "relUp",          shiftAction = "relUp",        shiftName = "Rel +" },
  [27] = { key = "-", name = "BPM -",    action = "bpmDown",        shiftAction = "zoomOut",      shiftName = "Zoom -" },
  [24] = { key = "=", name = "BPM +",    action = "bpmUp",          shiftAction = "zoomIn",       shiftName = "Zoom +" }
}

local defaultUpperRowKeys = {
  [12] = { key = "Q", baseNote = 72, isTop = true }, [13] = { key = "W", baseNote = 74, isTop = true }, [14] = { key = "E", baseNote = 76, isTop = true },
  [15] = { key = "R", baseNote = 77, isTop = true }, [17] = { key = "T", baseNote = 79, isTop = true }, [16] = { key = "Y", baseNote = 81, isTop = true },
  [32] = { key = "U", baseNote = 83, isTop = true }, [34] = { key = "I", baseNote = 84, isTop = true }, [31] = { key = "O", baseNote = 86, isTop = true },
  [35] = { key = "P", baseNote = 88, isTop = true }, [33] = { key = "[", baseNote = 89, isTop = true }, [30] = { key = "]", baseNote = 91, isTop = true }
}

local defaultLowerRowKeys = {
  [6]  = { key = "Z", baseNote = 60, isTop = false }, [7]  = { key = "X", baseNote = 62, isTop = false }, [8]  = { key = "C", baseNote = 64, isTop = false },
  [9]  = { key = "V", baseNote = 65, isTop = false }, [11] = { key = "B", baseNote = 67, isTop = false }, [45] = { key = "N", baseNote = 69, isTop = false },
  [46] = { key = "M", baseNote = 71, isTop = false }, [43] = { key = ",", baseNote = 72, isTop = false }, [47] = { key = ".", baseNote = 74, isTop = false },
  [44] = { key = "/", baseNote = 76, isTop = false }
}

local defaultHomeRowControls = {
  [48] = { key = "Tab", name = "Sustain", action = "sustain",     shiftAction = "sustain",    shiftName = "Sustain" },
  [0]  = { key = "A",   name = "Arp",     action = "arpToggle",   shiftAction = "resetAll",   shiftName = "Reset" },
  [1]  = { key = "S",   name = "Random",  action = "randomScale", shiftAction = "panic",      shiftName = "Panic!" },
  [2]  = { key = "D",   name = "Oct -",   action = "octaveDown",  shiftAction = "topVolDown", shiftName = "TopVol -" },
  [3]  = { key = "F",   name = "Oct +",   action = "octaveUp",    shiftAction = "topVolUp",   shiftName = "TopVol +" },
  [5]  = { key = "G",   name = "Mode -",  action = "modeDown",    shiftAction = "modWheelDown", shiftName = "Mod -" },
  [4]  = { key = "H",   name = "Root -",  action = "rootDown",    shiftAction = "rootDown",   shiftName = "Root -" },
  [38] = { key = "J",   name = "Trnsp -", action = "trnspDown",   shiftAction = "volDown",    shiftName = "Vol -" },
  [40] = { key = "K",   name = "Trnsp +", action = "trnspUp",     shiftAction = "volUp",      shiftName = "Vol +" },
  [37] = { key = "L",   name = "Root +",  action = "rootUp",      shiftAction = "rootUp",     shiftName = "Root +" },
  [41] = { key = ";",   name = "Mode +",  action = "modeUp",      shiftAction = "modWheelUp",   shiftName = "Mod +" },
  [39] = { key = "'",   name = "Chord",   action = "chordToggle",    shiftAction = "chordUp",      shiftName = "Chord +" }
}

local ACTION_CATALOG = {
  {
    category = "Arpeggiator",
    actions = {
      { id = "arpToggle", name = "Arp On/Off", typeClass = "ctrl-arp", description = "Toggle arpeggiator engine" },
      { id = "arpTopToggle", name = "Top Arp", typeClass = "ctrl-arptop", description = "Toggle top row arpeggiator" },
      { id = "arpBottomToggle", name = "Bot Arp", typeClass = "ctrl-arpbot", description = "Toggle bottom row arpeggiator" },
      { id = "arpDirUp", name = "Arp Dir +", typeClass = "ctrl-arpdir", description = "Cycle arpeggiator direction up" },
      { id = "arpDirDown", name = "Arp Dir -", typeClass = "ctrl-arpdir", description = "Cycle arpeggiator direction down" },
      { id = "arpRateUp", name = "Arp Rate +", typeClass = "ctrl-arprate", description = "Increase arpeggiator speed" },
      { id = "arpRateDown", name = "Arp Rate -", typeClass = "ctrl-arprate", description = "Decrease arpeggiator speed" },
      { id = "arpGateUp", name = "Arp Gate +", typeClass = "ctrl-arpgate", description = "Lengthen arpeggiator gate" },
      { id = "arpGateDown", name = "Arp Gate -", typeClass = "ctrl-arpgate", description = "Shorten arpeggiator gate" }
    }
  },
  {
    category = "Scale & Pitch",
    actions = {
      { id = "rootUp", name = "Root +", typeClass = "ctrl-root", description = "Shift root note up" },
      { id = "rootDown", name = "Root -", typeClass = "ctrl-root", description = "Shift root note down" },
      { id = "modeUp", name = "Mode +", typeClass = "ctrl-mode", description = "Cycle scale/mode forward" },
      { id = "modeDown", name = "Mode -", typeClass = "ctrl-mode", description = "Cycle scale/mode backward" },
      { id = "trnspUp", name = "Trnsp +", typeClass = "ctrl-trnsp", description = "Transpose semitone up" },
      { id = "trnspDown", name = "Trnsp -", typeClass = "ctrl-trnsp", description = "Transpose semitone down" },
      { id = "octaveUp", name = "Main Oct +", typeClass = "ctrl-oct", description = "Shift main octave up" },
      { id = "octaveDown", name = "Main Oct -", typeClass = "ctrl-oct", description = "Shift main octave down" },
      { id = "botOctUp", name = "Bot Oct +", typeClass = "ctrl-oct", description = "Shift bottom octave up" },
      { id = "botOctDown", name = "Bot Oct -", typeClass = "ctrl-oct", description = "Shift bottom octave down" },
      { id = "topOctUp", name = "Top Oct +", typeClass = "ctrl-topoct", description = "Shift top row octave up" },
      { id = "topOctDown", name = "Top Oct -", typeClass = "ctrl-topoct", description = "Shift top row octave down" },
      { id = "chordMod", name = "Chord Mod", typeClass = "ctrl-mode", description = "Hold for chord trigger mode" },
      { id = "chordUp", name = "Chord +", typeClass = "ctrl-mode", description = "Cycle chord pattern forward" },
      { id = "chordDown", name = "Chord -", typeClass = "ctrl-mode", description = "Cycle chord pattern backward" },
      { id = "randomScale", name = "Random Scale", typeClass = "ctrl-rand", description = "Pick random scale & root" }
    }
  },
  {
    category = "Volume & CC",
    actions = {
      { id = "sustain", name = "Sustain", typeClass = "latch-active", description = "Sustain pedal CC64 toggle/hold" },
      { id = "volUp", name = "Vol +", typeClass = "ctrl-vol", description = "Increase bottom row velocity" },
      { id = "volDown", name = "Vol -", typeClass = "ctrl-vol", description = "Decrease bottom row velocity" },
      { id = "topVolUp", name = "Top Vol +", typeClass = "ctrl-vol", description = "Increase top row velocity" },
      { id = "topVolDown", name = "Top Vol -", typeClass = "ctrl-vol", description = "Decrease top row velocity" },
      { id = "modWheelUp", name = "Mod +", typeClass = "ctrl-modw", description = "Increase modulation wheel CC1" },
      { id = "modWheelDown", name = "Mod -", typeClass = "ctrl-modw", description = "Decrease modulation wheel CC1" },
      { id = "panic", name = "Panic!", typeClass = "ctrl-panic", description = "Send all-notes-off MIDI panic" }
    }
  },
  {
    category = "Tempo & View",
    actions = {
      { id = "undoState", name = "Undo", typeClass = "ctrl-reset", description = "Undo last controller state change (scale, pitch, octave, etc.)" },
      { id = "redoState", name = "Redo State", typeClass = "ctrl-reset", description = "Redo previous controller state change" },
      { id = "bpmUp", name = "BPM +", typeClass = "ctrl-bpm", description = "Increase tempo" },
      { id = "bpmDown", name = "BPM -", typeClass = "ctrl-bpm", description = "Decrease tempo" },
      { id = "relUp", name = "Release +", typeClass = "ctrl-rel", description = "Increase release length" },
      { id = "relDown", name = "Release -", typeClass = "ctrl-rel", description = "Decrease release length" },
      { id = "zoomIn", name = "Zoom +", typeClass = "ctrl-zoom", description = "Zoom in HUD size" },
      { id = "zoomOut", name = "Zoom -", typeClass = "ctrl-zoom", description = "Zoom out HUD size" },
      { id = "resetAll", name = "Reset All", typeClass = "ctrl-reset", description = "Reset settings to defaults" },
      { id = "none", name = "None", typeClass = "", description = "Unassigned key" }
    }
  }
}

local function deepCopy(orig)
  if type(orig) ~= "table" then return orig end
  local copy = {}
  for k, v in pairs(orig) do
    copy[k] = deepCopy(v)
  end
  return copy
end

local numberRowControls = deepCopy(defaultNumberRowControls)
local upperRowKeys = deepCopy(defaultUpperRowKeys)
local lowerRowKeys = deepCopy(defaultLowerRowKeys)
local homeRowControls = deepCopy(defaultHomeRowControls)

local function getActionIndex()
  local idx = {}
  for _, cat in ipairs(ACTION_CATALOG) do
    for _, act in ipairs(cat.actions) do
      idx[act.id] = act
    end
  end
  return idx
end

local function applyCustomLayout(customData)
  for k in pairs(numberRowControls) do numberRowControls[k] = nil end
  for k, v in pairs(deepCopy(defaultNumberRowControls)) do numberRowControls[k] = v end

  for k in pairs(upperRowKeys) do upperRowKeys[k] = nil end
  for k, v in pairs(deepCopy(defaultUpperRowKeys)) do upperRowKeys[k] = v end

  for k in pairs(homeRowControls) do homeRowControls[k] = nil end
  for k, v in pairs(deepCopy(defaultHomeRowControls)) do homeRowControls[k] = v end

  for k in pairs(lowerRowKeys) do lowerRowKeys[k] = nil end
  for k, v in pairs(deepCopy(defaultLowerRowKeys)) do lowerRowKeys[k] = v end

  _cachedActiveNoteKeysMap = nil
  _cachedActiveControlKeysMap = nil

  if not customData or type(customData) ~= "table" then return end

  local actionIdx = getActionIndex()

  for codeStr, binding in pairs(customData) do
    local code = tonumber(codeStr)
    if code and type(binding) == "table" then
      if binding.action == "none" or binding.isNote == true or (binding.action == nil and binding.shiftAction == nil and binding.baseNote == nil) then
        -- Revert to default note or control for this keycode
        local defaultDef = defaultUpperRowKeys[code] or defaultLowerRowKeys[code] or defaultHomeRowControls[code] or defaultNumberRowControls[code]
        if defaultDef then
          if defaultUpperRowKeys[code] then upperRowKeys[code] = deepCopy(defaultDef)
          elseif defaultLowerRowKeys[code] then lowerRowKeys[code] = deepCopy(defaultDef)
          elseif defaultHomeRowControls[code] then homeRowControls[code] = deepCopy(defaultDef)
          elseif defaultNumberRowControls[code] then numberRowControls[code] = deepCopy(defaultDef)
          end
        end
      elseif binding.action ~= nil or binding.shiftAction ~= nil then
        local targetTable = nil
        if defaultNumberRowControls[code] then targetTable = numberRowControls
        elseif defaultHomeRowControls[code] then targetTable = homeRowControls
        elseif defaultUpperRowKeys[code] then targetTable = upperRowKeys
        elseif defaultLowerRowKeys[code] then targetTable = lowerRowKeys
        end

        if targetTable then
          local defaultDef = defaultNumberRowControls[code] or defaultHomeRowControls[code] or defaultUpperRowKeys[code] or defaultLowerRowKeys[code]
          local actObj = binding.action and actionIdx[binding.action]
          local shiftActObj = binding.shiftAction and actionIdx[binding.shiftAction]

          local actionVal, nameVal
          if binding.action ~= nil then
            actionVal = binding.action
            nameVal = binding.name
            if not nameVal or nameVal == "Ctrl" or nameVal == "" then
              nameVal = (actObj and actObj.name) or (defaultDef and defaultDef.name) or "Action"
            end
          else
            actionVal = defaultDef and defaultDef.action
            nameVal = defaultDef and defaultDef.name
          end

          local shiftActionVal, shiftNameVal
          if binding.shiftAction ~= nil then
            shiftActionVal = binding.shiftAction
            shiftNameVal = binding.shiftName
            if not shiftNameVal or shiftNameVal == "" then
              shiftNameVal = (shiftActObj and shiftActObj.name) or (defaultDef and defaultDef.shiftName)
            end
          else
            shiftActionVal = defaultDef and defaultDef.shiftAction
            shiftNameVal = defaultDef and defaultDef.shiftName
          end

          targetTable[code] = {
            key = binding.key or (defaultDef and defaultDef.key),
            name = nameVal,
            action = actionVal,
            shiftAction = shiftActionVal,
            shiftName = shiftNameVal,
            baseNote = defaultDef and defaultDef.baseNote,
            isTop = defaultDef and defaultDef.isTop
          }
        end
      elseif binding.baseNote ~= nil then
        local targetTable = nil
        if defaultUpperRowKeys[code] then targetTable = upperRowKeys
        elseif defaultLowerRowKeys[code] then targetTable = lowerRowKeys
        elseif defaultNumberRowControls[code] then targetTable = numberRowControls
        elseif defaultHomeRowControls[code] then targetTable = homeRowControls
        end

        if targetTable then
          targetTable[code] = {
            key = binding.key or (defaultUpperRowKeys[code] or defaultLowerRowKeys[code] or defaultNumberRowControls[code] or defaultHomeRowControls[code]).key,
            baseNote = binding.baseNote,
            isTop = (binding.isTop ~= nil) and binding.isTop or (defaultUpperRowKeys[code] ~= nil)
          }
        end
      end
    end
  end
end

local function getPresetsMap()
  local presets = hs.settings.get("qwertyMidi_layoutPresets")
  if not presets or type(presets) ~= "table" or next(presets) == nil then
    local legacyData = hs.settings.get("qwertyMidi_customKeyLayout") or {}
    presets = {
      ["default"] = { id = "default", name = "Default Layout", isBuiltin = true, data = legacyData }
    }
    hs.settings.set("qwertyMidi_layoutPresets", presets)
  end
  return presets
end

local function getActivePresetId()
  return hs.settings.get("qwertyMidi_activePresetId") or "default"
end

local function getPresetsList()
  local map = getPresetsMap()
  local list = {}
  for id, p in pairs(map) do
    table.insert(list, {
      id = p.id or id,
      name = p.name or "Untitled Preset",
      isBuiltin = (p.isBuiltin == true or id == "default"),
      data = p.data or {}
    })
  end
  table.sort(list, function(a, b)
    if a.isBuiltin ~= b.isBuiltin then return a.isBuiltin end
    return a.name < b.name
  end)
  return list
end

local function getActivePresetData()
  local map = getPresetsMap()
  local activeId = getActivePresetId()
  local p = map[activeId] or map["default"]
  return (p and p.data) or {}
end

local function selectPreset(presetId)
  local map = getPresetsMap()
  if not map[presetId] then
    presetId = "default"
  end
  hs.settings.set("qwertyMidi_activePresetId", presetId)
  local data = (map[presetId] and map[presetId].data) or {}
  hs.settings.set("qwertyMidi_customKeyLayout", data)
  applyCustomLayout(data)
  saveSettings()
end

local function saveCustomLayout(newLayoutData)
  local activeId = getActivePresetId()
  local map = getPresetsMap()

  if not map[activeId] then
    activeId = "default"
  end

  local presetObj = map[activeId]
  if presetObj and not (presetObj.isBuiltin or activeId == "default") then
    presetObj.data = newLayoutData or {}
    hs.settings.set("qwertyMidi_layoutPresets", map)
    hs.settings.set("qwertyMidi_customKeyLayout", newLayoutData or {})
  end

  applyCustomLayout(newLayoutData)
  saveSettings()
end

local function savePreset(presetId, name, layoutData)
  local map = getPresetsMap()
  if not presetId or presetId == "" or presetId == "new" then
    presetId = "preset_" .. tostring(os.time()) .. "_" .. tostring(math.random(100, 999))
  end

  local isBuiltin = false
  if map[presetId] then
    isBuiltin = (map[presetId].isBuiltin == true or presetId == "default")
  end

  map[presetId] = {
    id = presetId,
    name = name or (map[presetId] and map[presetId].name) or "New Preset",
    isBuiltin = isBuiltin,
    data = layoutData or (map[presetId] and map[presetId].data) or {}
  }

  hs.settings.set("qwertyMidi_layoutPresets", map)
  hs.settings.set("qwertyMidi_activePresetId", presetId)
  selectPreset(presetId)
  return presetId
end

local function renamePreset(presetId, newName)
  if not newName or newName:match("^%s*$") then return false end
  local map = getPresetsMap()
  if map[presetId] then
    map[presetId].name = newName
    hs.settings.set("qwertyMidi_layoutPresets", map)
    saveSettings()
    return true
  end
  return false
end

local function deletePreset(presetId)
  local map = getPresetsMap()
  if map[presetId] and not map[presetId].isBuiltin and presetId ~= "default" then
    map[presetId] = nil
    hs.settings.set("qwertyMidi_layoutPresets", map)
    if getActivePresetId() == presetId then
      selectPreset("default")
    else
      saveSettings()
    end
    return true
  end
  return false
end

local function duplicatePreset(presetId, newName)
  local map = getPresetsMap()
  local src = map[presetId] or map["default"]
  if not src then return nil end

  local newId = "preset_" .. tostring(os.time()) .. "_" .. tostring(math.random(100, 999))
  local name = newName or (src.name .. " Copy")

  local copyData = {}
  if src.data then
    for k, v in pairs(src.data) do
      if type(v) == "table" then
        local sub = {}
        for sk, sv in pairs(v) do sub[sk] = sv end
        copyData[k] = sub
      else
        copyData[k] = v
      end
    end
  end

  map[newId] = {
    id = newId,
    name = name,
    isBuiltin = false,
    data = copyData
  }

  hs.settings.set("qwertyMidi_layoutPresets", map)
  hs.settings.set("qwertyMidi_activePresetId", newId)
  selectPreset(newId)
  return newId
end

local function resetLayout()
  local activeId = getActivePresetId()
  local map = getPresetsMap()
  if map[activeId] then
    map[activeId].data = {}
    hs.settings.set("qwertyMidi_layoutPresets", map)
  end
  hs.settings.set("qwertyMidi_customKeyLayout", nil)
  applyCustomLayout(nil)
  saveSettings()
end

local function updateKeyMapping(code, newBinding)
  local customData = getActivePresetData()
  customData[tostring(code)] = newBinding
  saveCustomLayout(customData)
end

local function getLayoutConfig()
  local presetsList = getPresetsList()
  local activePresetId = getActivePresetId()
  local activeData = getActivePresetData()

  return {
    customized = (activeData ~= nil and next(activeData) ~= nil),
    actionCatalog = ACTION_CATALOG,
    presets = presetsList,
    activePresetId = activePresetId,
    defaults = {
      numberRow = defaultNumberRowControls,
      upperRow = defaultUpperRowKeys,
      homeRow = defaultHomeRowControls,
      lowerRow = defaultLowerRowKeys
    },
    active = {
      numberRow = numberRowControls,
      upperRow = upperRowKeys,
      homeRow = homeRowControls,
      lowerRow = lowerRowKeys
    },
    customLayout = activeData or {}
  }
end

applyCustomLayout(getActivePresetData())

local arpAdvancedControlKeysMap = {
  -- Arp Rate
  [18] = { key = "1", name = "Rate 1/4",   action = "setArpRate_5" },
  [19] = { key = "2", name = "Rate 1/8",   action = "setArpRate_6" },
  [20] = { key = "3", name = "Rate 1/16",  action = "setArpRate_7" },
  [21] = { key = "4", name = "Rate 1/32",  action = "setArpRate_8" },

  -- Arp Direction
  [12] = { key = "q", name = "Dir UP",     action = "setArpDir_1" },
  [13] = { key = "w", name = "Dir DOWN",   action = "setArpDir_2" },
  [14] = { key = "e", name = "Dir UP/DN",  action = "setArpDir_3" },
  [15] = { key = "r", name = "Dir DN/UP",  action = "setArpDir_4" },
  [17] = { key = "t", name = "Dir RAND",   action = "setArpDir_7" },

  -- Arp Quantize
  [6] = { key = "z", name = "Sync OFF",    action = "setArpQuantize_None" },
  [7] = { key = "x", name = "Sync BEAT",   action = "setArpQuantize_Beat" },
  [8] = { key = "c", name = "Sync BAR",    action = "setArpQuantize_Bar" },

  -- Arp Latch
  [49] = { key = "Space", name = "Arp Latch", action = "arpLatchToggle" },
}
local arpAdvancedNoteKeysMap = {}

local function getNoteKey(code)
  if state.currentMode == "ArpAdvanced" then
    return arpAdvancedNoteKeysMap[code]
  end
  local k = upperRowKeys[code] or lowerRowKeys[code] or homeRowControls[code] or numberRowControls[code]
  if k and k.baseNote ~= nil then return k end
  return nil
end

local function getControlKey(code)
  if state.currentMode == "ArpAdvanced" then
    return arpAdvancedControlKeysMap[code]
  end
  local k = homeRowControls[code] or upperRowKeys[code] or lowerRowKeys[code]
  if k and (k.action ~= nil or k.shiftAction ~= nil) then return k end
  return nil
end

local function getNumberControlKey(code)
  if state.currentMode == "ArpAdvanced" then
    return arpAdvancedControlKeysMap[code]
  end
  local k = numberRowControls[code]
  if k and (k.action ~= nil or k.shiftAction ~= nil) then return k end
  return nil
end


local _cachedActiveNoteKeysMap = nil
local _cachedActiveControlKeysMap = nil

local function getActiveNoteKeysMap()
  if state.currentMode == "ArpAdvanced" then
    return arpAdvancedNoteKeysMap
  end
  if _cachedActiveNoteKeysMap then return _cachedActiveNoteKeysMap end
  local map = {}
  for code, k in pairs(upperRowKeys) do if k.baseNote ~= nil then map[code] = k end end
  for code, k in pairs(lowerRowKeys) do if k.baseNote ~= nil then map[code] = k end end
  for code, k in pairs(homeRowControls) do if k.baseNote ~= nil then map[code] = k end end
  for code, k in pairs(numberRowControls) do if k.baseNote ~= nil then map[code] = k end end
  _cachedActiveNoteKeysMap = map
  return map
end

local function getActiveControlKeysMap()
  if state.currentMode == "ArpAdvanced" then
    return arpAdvancedControlKeysMap
  end
  if _cachedActiveControlKeysMap then return _cachedActiveControlKeysMap end
  local map = {}
  for code, k in pairs(homeRowControls) do if k.action ~= nil or k.shiftAction ~= nil then map[code] = k end end
  for code, k in pairs(upperRowKeys) do if k.action ~= nil or k.shiftAction ~= nil then map[code] = k end end
  for code, k in pairs(lowerRowKeys) do if k.action ~= nil or k.shiftAction ~= nil then map[code] = k end end
  for code, k in pairs(numberRowControls) do if k.action ~= nil or k.shiftAction ~= nil then map[code] = k end end
  _cachedActiveControlKeysMap = map
  return map
end


return {
  state = state,
  saveSettings = saveSettings,
  SCALES = SCALES,
  NOTE_NAMES = NOTE_NAMES,
  WHITE_KEY_INDEX = WHITE_KEY_INDEX,
  ACTION_CATALOG = ACTION_CATALOG,
  defaultNumberRowControls = defaultNumberRowControls,
  defaultUpperRowKeys = defaultUpperRowKeys,
  defaultLowerRowKeys = defaultLowerRowKeys,
  defaultHomeRowControls = defaultHomeRowControls,
  numberRowControls = numberRowControls,
  upperRowKeys = upperRowKeys,
  lowerRowKeys = lowerRowKeys,
  homeRowControls = homeRowControls,
  applyCustomLayout = applyCustomLayout,
  saveCustomLayout = saveCustomLayout,
  selectPreset = selectPreset,
  savePreset = savePreset,
  renamePreset = renamePreset,
  deletePreset = deletePreset,
  duplicatePreset = duplicatePreset,
  getPresetsList = getPresetsList,
  resetLayout = resetLayout,
  updateKeyMapping = updateKeyMapping,
  getLayoutConfig = getLayoutConfig,
  getNoteKey = getNoteKey,
  getControlKey = getControlKey,
  getNumberControlKey = getNumberControlKey,
  getActiveNoteKeysMap = getActiveNoteKeysMap,
  getActiveControlKeysMap = getActiveControlKeysMap
}
