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
  altHeld = false,            -- Option (Alt) key active state
  ctrlHeld = false,           -- Control key active state
  zoomLevel = getSetting("zoomLevel", 1.0),
  BASE_HUD_SCALE = 1.4,

  -- UI Styling (Clean Dark Studio Grayscale)
  uiActionKeyHue = getSetting("uiActionKeyHue", 0),
  uiActionKeySat = getSetting("uiActionKeySat", 0),
  uiActionKeyLight = getSetting("uiActionKeyLight", 70),
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
  inputQuantizeMode = getSetting("inputQuantizeMode", "Off"), -- "Off", "1/1", "1/2", "1/4", "1/8", "1/16", "1/32"
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
  arpLinked = getSetting("arpLinked", true),

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

  tracks = {
    [1] = {
      id = 1, name = "Bass", channel = 0, color = "#00e5ff", volume = 100,
      muted = false, soloed = false, armed = true, locked = false,
      sustainMode = "off", sustainedPitches = {}, chordStartTime = 0, chordModeActive = false, chordIdx = 1,
      arpEnabled = false, arpLatchActive = false, arpDirectionIdx = 1, arpRateIdx = 5, arpGatePercent = 80.0,
      heldNotes = {}, targetHeldNotes = {}, keysCurrentlyHeld = {}, physicalKeysHeld = {}, stepIndex = 1, stepDirection = 1, pos = 0,
      currentPitch = nil, beatPosition = 0, activeGateTimers = {}, latchClearedForNewChord = false, activeNotesCount = 0, arpIsPlaying = false
    },
    [2] = {
      id = 2, name = "Chords", channel = 1, color = "#ff9100", volume = 100,
      muted = false, soloed = false, armed = false, locked = false,
      sustainMode = "off", sustainedPitches = {}, chordStartTime = 0, chordModeActive = false, chordIdx = 1,
      arpEnabled = false, arpLatchActive = false, arpDirectionIdx = 1, arpRateIdx = 5, arpGatePercent = 80.0,
      heldNotes = {}, targetHeldNotes = {}, keysCurrentlyHeld = {}, physicalKeysHeld = {}, stepIndex = 1, stepDirection = 1, pos = 0,
      currentPitch = nil, beatPosition = 0, activeGateTimers = {}, latchClearedForNewChord = false, activeNotesCount = 0, arpIsPlaying = false
    },
    [3] = {
      id = 3, name = "Lead", channel = 2, color = "#00e676", volume = 100,
      muted = false, soloed = false, armed = false, locked = false,
      sustainMode = "off", sustainedPitches = {}, chordStartTime = 0, chordModeActive = false, chordIdx = 1,
      arpEnabled = false, arpLatchActive = false, arpDirectionIdx = 1, arpRateIdx = 5, arpGatePercent = 80.0,
      heldNotes = {}, targetHeldNotes = {}, keysCurrentlyHeld = {}, physicalKeysHeld = {}, stepIndex = 1, stepDirection = 1, pos = 0,
      currentPitch = nil, beatPosition = 0, activeGateTimers = {}, latchClearedForNewChord = false, activeNotesCount = 0, arpIsPlaying = false
    },
    [4] = {
      id = 4, name = "Arp", channel = 3, color = "#d500f9", volume = 100,
      muted = false, soloed = false, armed = false, locked = false,
      sustainMode = "off", sustainedPitches = {}, chordStartTime = 0, chordModeActive = false, chordIdx = 1,
      arpEnabled = false, arpLatchActive = false, arpDirectionIdx = 1, arpRateIdx = 5, arpGatePercent = 80.0,
      heldNotes = {}, targetHeldNotes = {}, keysCurrentlyHeld = {}, physicalKeysHeld = {}, stepIndex = 1, stepDirection = 1, pos = 0,
      currentPitch = nil, beatPosition = 0, activeGateTimers = {}, latchClearedForNewChord = false, activeNotesCount = 0, arpIsPlaying = false
    },
  },
  bottomRowTrack = 1,
  topRowTrack = 3,
  activeTrack = 1,

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
  stackedKeyLabelsInPerformanceMode = getSetting("stackedKeyLabelsInPerformanceMode", false),
  scaleGuideEnabled = getSetting("scaleGuideEnabled", true)
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
  hs.settings.set("qwertyMidi_scaleGuideEnabled", state.scaleGuideEnabled == true)
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
  hs.settings.set("qwertyMidi_inputQuantizeMode", state.inputQuantizeMode)
  hs.settings.set("qwertyMidi_arpGatePercent", state.arpGatePercent)
  hs.settings.set("qwertyMidi_arpBpm", state.arpBpm)
  hs.settings.set("qwertyMidi_arpTopEnabled", state.arpTopEnabled == true)
  hs.settings.set("qwertyMidi_arpBottomEnabled", state.arpBottomEnabled == true)
  hs.settings.set("qwertyMidi_arpLinked", state.arpLinked == true)
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

  if _G.activeWatchers and _G.activeWatchers.sync and _G.activeWatchers.sync.broadcastState then
    _G.activeWatchers.sync.broadcastState(state)
  end
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
  [18] = { key = "1", name = "Trk 1: Bass",   action = "trkSelect1", shiftAction = "trkMute1", shiftName = "Trk 1 Mute" },
  [19] = { key = "2", name = "Trk 2: Chords", action = "trkSelect2", shiftAction = "trkMute2", shiftName = "Trk 2 Mute" },
  [20] = { key = "3", name = "Trk 3: Lead",   action = "trkSelect3", shiftAction = "trkMute3", shiftName = "Trk 3 Mute" },
  [21] = { key = "4", name = "Trk 4: Arp",    action = "trkSelect4", shiftAction = "trkMute4", shiftName = "Trk 4 Mute" },
  [23] = { key = "5", name = "Rate -",   action = "arpRateDown",    shiftAction = "botOctDown",   shiftName = "BotOct -" },
  [22] = { key = "6", name = "Rate +",   action = "arpRateUp",      shiftAction = "botOctUp",     shiftName = "BotOct +" },
  [26] = { key = "7", name = "Gate -",   action = "arpGateDown",    shiftAction = "arpLinkToggle", shiftName = "Arp Link" },
  [28] = { key = "8", name = "Gate +",   action = "arpGateUp",      shiftAction = "botVolDown",   shiftName = "BotVol -" },
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
  [48] = { key = "Tab", name = "Sustain", action = "sustain",     shiftAction = "classicSustain", shiftName = "Classic Sus" },
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
      { id = "arpGateDown", name = "Arp Gate -", typeClass = "ctrl-arpgate", description = "Shorten arpeggiator gate" },
      { id = "arpLinkToggle", name = "Arp Link", typeClass = "ctrl-arplink", description = "Toggle linked/split arp mode" }
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
      { id = "sustain", name = "Smart Sus", typeClass = "latch-active", description = "Smart sustain (auto-reset chord latch)" },
      { id = "classicSustain", name = "Classic Sus", typeClass = "latch-mode-active", description = "Classic cumulative sustain" },
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

local function getActionCatalog()
  local path = os.getenv("HOME") .. "/projects/qwerty-midi-hammerspoon/actions/actions.json"
  local f = io.open(path, "r")
  if f then
    local content = f:read("*a")
    f:close()
    local ok, res = pcall(function() return hs.json.decode(content) end)
    if ok and res then return res end
  end
  return {}
end

local function getAvailableLayouts()
  local dir = os.getenv("HOME") .. "/projects/qwerty-midi-hammerspoon/layouts"
  local list = {}
  local ok, iter_fn, dir_obj = pcall(hs.fs.dir, dir)
  if ok and iter_fn and dir_obj then
    for file in iter_fn, dir_obj do
      if file and file:match("%.json$") then
        local fullPath = dir .. "/" .. file
        local f = io.open(fullPath, "r")
        if f then
          local content = f:read("*a")
          f:close()
          local sok, res = pcall(function() return hs.json.decode(content) end)
          if sok and res and res.id then
            table.insert(list, {
              id = res.id,
              name = res.name or res.id,
              description = res.description or "",
              filename = file,
              data = res
            })
          end
        end
      end
    end
  end
  table.sort(list, function(a, b) return a.name < b.name end)
  return list
end

local function getPresetsMap()
  local layouts = getAvailableLayouts()
  local map = {}
  for _, l in ipairs(layouts) do
    map[l.id] = l
  end
  if not map["default"] then
    map["default"] = { id = "default", name = "Default Layout", data = {} }
  end
  return map
end

local function getActivePresetId()
  return hs.settings.get("qwertyMidi_activePresetId") or "default"
end

local function getPresetsList()
  return getAvailableLayouts()
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
  applyCustomLayout(data)
  saveSettings()
end

local function saveCustomLayout(newLayoutData)
  applyCustomLayout(newLayoutData)
  saveSettings()
end

local function savePreset(presetId, name, layoutData)
  return presetId
end

local function renamePreset(presetId, newName)
  return false
end

local function deletePreset(presetId)
  return false
end

local function duplicatePreset(presetId, newName)
  return presetId
end

local function resetLayout()
  applyCustomLayout(nil)
  saveSettings()
end

local function updateKeyMapping(code, newBinding)
  -- Key mappings are managed via JSON layout files
end

local function getLayoutConfig()
  local presetsList = getPresetsList()
  local activePresetId = getActivePresetId()
  local activeData = getActivePresetData()

  return {
    customized = false,
    actionCatalog = getActionCatalog(),
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
