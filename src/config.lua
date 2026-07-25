local state = {
  midiActive = false,
  currentRoot = 0,            -- 0 = C (0..11)
  currentScaleIdx = 1,        -- 1 = Major / Ionian
  octaveShift = 0,            -- Global Octave offset in semitones (-36 to +36)
  topRowOctaveOffset = 0,     -- Independent Top Row Octave Offset
  transposeShift = 0,         -- Transpose offset in semitones (-12 to +12)
  sustainActive = false,      -- Sustain toggle state (CC64)
  sustainKeyDownTime = 0,     -- Timestamp when sustain key was pressed down
  sustainWasActiveOnPress = false,
  arpLatchActive = false,     -- Arpeggiator Latch mode (part of arp cycle: Off→On→Latch)
  shiftHeld = false,          -- Shift key active state
  zoomLevel = hs.settings.get("qwertyMidi_zoomLevel") or 1.0,
  BASE_HUD_SCALE = 1.4,

  -- Arpeggiator State
  arpEnabled = false,
  arpDirectionIdx = 1,        -- 1: UP, 2: DOWN, 3: UP-DOWN, 4: DOWN-UP, 5: CONVERGE, 6: DIVERGE, 7: RANDOM
  ARP_DIRECTIONS = { "UP", "DOWN", "UP-DOWN", "DOWN-UP", "CONVERGE", "DIVERGE", "RANDOM" },
  arpRateIdx = 5,
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
  arpGatePercent = 80.0,
  arpBpm = 120.0,
  arpTimer = nil,
  arpGateTimer = nil,
  arpHeldNotes = {},          -- [code] = pitch
  arpKeysCurrentlyHeld = {},  -- [code] = true
  arpCurrentPitch = nil,
  arpStepIndex = 1,
  arpStepDirection = 1,
  lastArpMode = 1,
  arpTopEnabled = false,
  arpBottomEnabled = true,

  -- BPM Input Mode & Sync State
  bpmInputMode = false,
  bpmInputBuffer = "",
  bpmBeforeEdit = 120.0,
  bpmStepSize = hs.settings.get("qwertyMidi_bpmStepSize") or 10,
  logicSyncEnabled = (hs.settings.get("qwertyMidi_logicSyncEnabled") == nil) and true or hs.settings.get("qwertyMidi_logicSyncEnabled"),
  logicSyncTimer = nil,

  -- Scroll / Trackpad
  scrollSensitivity    = hs.settings.get("qwertyMidi_scrollSensitivity")    or 0.15,
  scrollMomentumScale  = hs.settings.get("qwertyMidi_scrollMomentumScale")   or 0.3,

  DIGIT_KEYCODES = {
    [50] = "`", [29] = "0", [18] = "1", [19] = "2", [20] = "3", [21] = "4",
    [23] = "5", [22] = "6", [26] = "7", [28] = "8", [25] = "9"
  },

  topRowVolume = 100,
  bottomRowVolume = 100,
  splitArpTopBoost = 20,

  ccStates = {
    [1] = 0,
    [7] = 100
  },

  pressedKeys = {},
  sustainedPitches = {},
  spotlightInfo = nil
}

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

local numberRowControls = {
  [50] = { key = "`", name = "Arp",      action = "arpToggle",      shiftAction = "panic",        shiftName = "Panic!" },
  [18] = { key = "1", name = "Top Arp",  action = "arpTopToggle",   shiftAction = "trnspDown",    shiftName = "Trnsp -" },
  [19] = { key = "2", name = "Bot Arp",  action = "arpBottomToggle",shiftAction = "trnspUp",      shiftName = "Trnsp +" },
  [20] = { key = "3", name = "Dir -",    action = "arpDirDown",     shiftAction = "topOctDown",   shiftName = "TopOct -" },
  [21] = { key = "4", name = "Dir +",    action = "arpDirUp",       shiftAction = "topOctUp",     shiftName = "TopOct +" },
  [23] = { key = "5", name = "Rate -",   action = "arpRateDown",    shiftAction = "octaveDown",   shiftName = "Oct -" },
  [22] = { key = "6", name = "Rate +",   action = "arpRateUp",      shiftAction = "octaveUp",     shiftName = "Oct +" },
  [26] = { key = "7", name = "Gate -",   action = "arpGateDown",    shiftAction = "modeDown",     shiftName = "Mode -" },
  [28] = { key = "8", name = "Gate +",   action = "arpGateUp",      shiftAction = "modeUp",       shiftName = "Mode +" },
  [25] = { key = "9", name = "BPM Set",  action = "bpmEdit",        shiftAction = "resetAll",     shiftName = "Reset" },
  [29] = { key = "0", name = "BPM Set",  action = "bpmEdit",        shiftAction = "resetAll",     shiftName = "Reset" },
  [27] = { key = "-", name = "BPM -",    action = "bpmDown",        shiftAction = "zoomOut",      shiftName = "Zoom -" },
  [24] = { key = "=", name = "BPM +",    action = "bpmUp",          shiftAction = "zoomIn",       shiftName = "Zoom +" }
}

local lowerRowKeys = {
  [6]  = { key = "Z", baseNote = 60 },
  [7]  = { key = "X", baseNote = 62 },
  [8]  = { key = "C", baseNote = 64 },
  [9]  = { key = "V", baseNote = 65 },
  [11] = { key = "B", baseNote = 67 },
  [45] = { key = "N", baseNote = 69 },
  [46] = { key = "M", baseNote = 71 },
  [43] = { key = ",", baseNote = 72 },
  [47] = { key = ".", baseNote = 74 },
  [44] = { key = "/", baseNote = 76 }
}

local upperRowKeys = {
  [12] = { key = "Q", baseNote = 72 },
  [13] = { key = "W", baseNote = 74 },
  [14] = { key = "E", baseNote = 76 },
  [15] = { key = "R", baseNote = 77 },
  [17] = { key = "T", baseNote = 79 },
  [16] = { key = "Y", baseNote = 81 },
  [32] = { key = "U", baseNote = 83 },
  [34] = { key = "I", baseNote = 84 },
  [31] = { key = "O", baseNote = 86 },
  [35] = { key = "P", baseNote = 88 }
}

local homeRowControls = {
  [48] = { key = "Tab", name = "Sustain", action = "sustain",     shiftAction = "resetAll",   shiftName = "Reset" },
  [0]  = { key = "A",   name = "Arp",     action = "arpToggle",   shiftAction = "resetAll",   shiftName = "Reset" },
  [1]  = { key = "S",   name = "Random",  action = "randomScale", shiftAction = "panic",      shiftName = "Panic!" },
  [2]  = { key = "D",   name = "Oct -",   action = "octaveDown",  shiftAction = "topOctDown", shiftName = "TopOct -" },
  [3]  = { key = "F",   name = "Oct +",   action = "octaveUp",    shiftAction = "topOctUp",   shiftName = "TopOct +" },
  [5]  = { key = "G",   name = "Trnsp -", action = "trnspDown",   shiftAction = "volDown",    shiftName = "Vol -" },
  [4]  = { key = "H",   name = "Root -",  action = "rootDown",    shiftAction = "topOctDown", shiftName = "TopOct -" },
  [38] = { key = "J",   name = "Mode -",  action = "modeDown",    shiftAction = "modWheelDown", shiftName = "Mod -" },
  [40] = { key = "K",   name = "Mode +",  action = "modeUp",      shiftAction = "modWheelUp",   shiftName = "Mod +" },
  [37] = { key = "L",   name = "Root +",  action = "rootUp",      shiftAction = "topOctUp",   shiftName = "TopOct +" },
  [41] = { key = ";",   name = "Trnsp +", action = "trnspUp",     shiftAction = "volUp",      shiftName = "Vol +" }
}

return {
  state = state,
  SCALES = SCALES,
  NOTE_NAMES = NOTE_NAMES,
  WHITE_KEY_INDEX = WHITE_KEY_INDEX,
  numberRowControls = numberRowControls,
  lowerRowKeys = lowerRowKeys,
  upperRowKeys = upperRowKeys,
  homeRowControls = homeRowControls
}
