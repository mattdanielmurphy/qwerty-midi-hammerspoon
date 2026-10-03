-- packages/music-engine/harmony.lua
-- Musical theory, scales, modes, chords, and pitch transposition.

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

local CHORDS = {
  { name = "Triad", offsets = { 0, 2, 4 } },
  { name = "7th", offsets = { 0, 2, 4, 6 } },
  { name = "9th", offsets = { 0, 2, 4, 6, 8 } },
  { name = "Power (1-5)", offsets = { 0, 4 } },
  { name = "Octaves", offsets = { 0, 7 } }
}

local function noteNumToName(noteNum)
  local octave = math.floor(noteNum / 12) - 1
  local noteName = NOTE_NAMES[(noteNum % 12) + 1]
  return noteName .. octave
end

local function getIntervalInfo(noteNum, root, scaleIdx)
  local noteInOctave = noteNum % 12
  local semitonesFromRoot = (noteInOctave - root + 12) % 12
  local intervals = SCALES[scaleIdx or 1].intervals

  for idx, interval in ipairs(intervals) do
    if interval == semitonesFromRoot then
      return idx, semitonesFromRoot
    end
  end
  return nil, semitonesFromRoot
end

local function getTransposedPitch(basePitch, isTopRow, state)
  local topOffset = state.topRowOctaveOffset or 12
  local botOffset = state.bottomRowOctaveOffset or 0
  local effectivePitch = basePitch + (isTopRow and topOffset or botOffset)
  local octave = math.floor(effectivePitch / 12) - 1
  local noteInOctave = effectivePitch % 12
  local scaleIndex = WHITE_KEY_INDEX[noteInOctave]

  local root = state.currentRoot or 0
  local octaveShift = state.octaveShift or 0
  local transposeShift = state.transposeShift or 0
  local scaleIdx = state.currentScaleIdx or 1

  if scaleIndex and scaleIndex ~= -1 then
    local intervals = SCALES[scaleIdx].intervals
    local numIntervals = #intervals
    local transposedIndex = scaleIndex + transposeShift
    local octaveOffset = math.floor(transposedIndex / numIntervals)
    local idxInScale = (((transposedIndex % numIntervals) + numIntervals) % numIntervals) + 1

    local targetInterval = intervals[idxInScale]
    local newPitch = ((octave + 1 + octaveOffset) * 12) + root + targetInterval + octaveShift
    return newPitch
  end
  local fallbackPitch = effectivePitch + root + octaveShift + transposeShift
  return fallbackPitch
end

local function getTransposedChordPitches(basePitch, isTopRow, forceChord, state)
  local rootPitch = getTransposedPitch(basePitch, isTopRow, state)
  local isChordEnabled = false
  local activeChordIdx = state and state.chordIdx or 1
  if type(forceChord) == "table" then
    isChordEnabled = (forceChord.enabled ~= false)
    if forceChord.chordIdx then activeChordIdx = forceChord.chordIdx end
  elseif forceChord == true then
    isChordEnabled = true
  elseif forceChord == false then
    isChordEnabled = false
  else
    isChordEnabled = state and (state.quoteHeld or state.chordModeActive)
  end

  if not isChordEnabled then
    return { rootPitch }
  end
  local chordList = (state and state.CHORDS) or CHORDS
  local chordDef = chordList[activeChordIdx] or chordList[1]
  local offsets = chordDef.offsets or { 0 }
  
  local topOffset = state.topRowOctaveOffset or 12
  local botOffset = state.bottomRowOctaveOffset or 0
  local effectivePitch = basePitch + (isTopRow and topOffset or botOffset)
  local noteInOctave = effectivePitch % 12
  local scaleIndex = WHITE_KEY_INDEX[noteInOctave]
  if not scaleIndex or scaleIndex == -1 then
    return { rootPitch }
  end
  
  local scaleIdx = state.currentScaleIdx or 1
  local intervals = SCALES[scaleIdx].intervals
  local numIntervals = #intervals
  local transposeShift = state.transposeShift or 0
  local baseTransposedIndex = scaleIndex + transposeShift
  local octave = math.floor(effectivePitch / 12) - 1
  local root = state.currentRoot or 0
  local octaveShift = state.octaveShift or 0
  
  local pitches = {}
  for _, off in ipairs(offsets) do
    local transposedIndex = baseTransposedIndex + off
    local octaveOffset = math.floor(transposedIndex / numIntervals)
    local idxInScale = (((transposedIndex % numIntervals) + numIntervals) % numIntervals) + 1
    local targetInterval = intervals[idxInScale]
    local newPitch = ((octave + 1 + octaveOffset) * 12) + root + targetInterval + octaveShift
    table.insert(pitches, newPitch)
  end
  return pitches
end

--- Compute diatonic chord pitches and name for nanoKEY Studio pads (1..8)
-- @param padIdx number (1..8)
-- @param state table controller state
-- @return table { pitches = {...}, name = string, roman = string }
local function getDiatonicPadChord(padIdx, state)
  state = state or {}
  padIdx = math.max(1, math.min(8, padIdx or 1))

  local scaleIdx = state.currentScaleIdx or 1
  local scale = SCALES[scaleIdx] or SCALES[1]
  local intervals = scale.intervals
  local numIntervals = #intervals
  local root = state.currentRoot or 0
  local octaveShift = state.octaveShift or 0

  local chordList = state.CHORDS or CHORDS
  local chordDef = chordList[state.chordIdx or 1] or chordList[1]
  local offsets = chordDef.offsets or { 0, 2, 4 }

  local degree = padIdx - 1
  local baseOctave = 48 -- C3 foundation

  local pitches = {}
  local degreeRootPitch = nil

  for i, off in ipairs(offsets) do
    local step = degree + off
    local octOffset = math.floor(step / numIntervals)
    local idxInScale = (step % numIntervals) + 1
    local targetInterval = intervals[idxInScale]
    local pitch = baseOctave + (octOffset * 12) + root + targetInterval + octaveShift
    table.insert(pitches, pitch)
    if i == 1 then degreeRootPitch = pitch end
  end

  -- Determine chord name and quality
  local rootName = NOTE_NAMES[((degreeRootPitch or baseOctave) % 12) + 1]
  local quality = ""
  if #pitches >= 3 then
    local thirdInterval = (pitches[2] - pitches[1]) % 12
    local fifthInterval = (pitches[3] - pitches[1]) % 12
    if thirdInterval == 3 and fifthInterval == 7 then
      quality = "m"
    elseif thirdInterval == 4 and fifthInterval == 7 then
      quality = ""
    elseif thirdInterval == 3 and fifthInterval == 6 then
      quality = "dim"
    elseif thirdInterval == 4 and fifthInterval == 8 then
      quality = "aug"
    end
  end

  local ROMAN_NUMERALS = { "I", "ii", "iii", "IV", "V", "vi", "vii°", "I" }
  local roman = ROMAN_NUMERALS[padIdx] or tostring(padIdx)
  local fullName = rootName .. quality .. (padIdx == 8 and " (8va)" or "")

  return {
    pitches = pitches,
    name = fullName,
    roman = roman,
    rootPitch = degreeRootPitch
  }
end

--- Get scale guide information for a range of MIDI pitches (default 48..72 for nanoKEY Studio)
-- @param root number 0..11
-- @param scaleIdx number 1..9
-- @param minPitch number (default 48)
-- @param maxPitch number (default 72)
-- @return table { pitches = { [pitch] = { inScale = bool, isRoot = bool, degree = number, roman = string, noteName = string } }, scaleName = string, rootName = string }
local function getScaleGuideInfo(root, scaleIdx, minPitch, maxPitch)
  root = root or 0
  scaleIdx = scaleIdx or 1
  minPitch = minPitch or 48
  maxPitch = maxPitch or 72

  local scale = SCALES[scaleIdx] or SCALES[1]
  local intervals = scale.intervals
  local rootName = NOTE_NAMES[(root % 12) + 1]
  local ROMAN_NUMERALS = { "I", "ii", "iii", "IV", "V", "vi", "vii°" }

  local intervalToDegree = {}
  for deg, intv in ipairs(intervals) do
    intervalToDegree[intv] = deg
  end

  local pitches = {}
  for p = minPitch, maxPitch do
    local noteInOctave = p % 12
    local semitonesFromRoot = (noteInOctave - root + 12) % 12
    local isRoot = (semitonesFromRoot == 0)
    local deg = intervalToDegree[semitonesFromRoot]
    local inScale = (deg ~= nil)
    local roman = deg and ROMAN_NUMERALS[deg] or ""
    local noteName = noteNumToName(p)

    pitches[tostring(p)] = {
      pitch = p,
      inScale = inScale,
      isRoot = isRoot,
      degree = deg or 0,
      roman = roman,
      noteName = noteName
    }
  end

  return {
    root = root,
    rootName = rootName,
    scaleIdx = scaleIdx,
    scaleName = scale.name,
    pitches = pitches
  }
end

local FLAT_NOTE_NAMES = { "C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B" }
local SHARP_NOTE_NAMES = { "C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B" }

local function prefersFlats(root, scaleIdx)
  local r = (root or 0) % 12
  local s = scaleIdx or 1
  -- Keys using flats in major: F (5), Bb (10), Eb (3), Ab (8), Db (1), Gb (6)
  if s == 1 or s == 2 or s == 3 then -- Lydian, Major, Mixolydian
    if r == 5 or r == 10 or r == 3 or r == 8 or r == 1 or r == 6 then return true end
  else -- Minor / Dorian / Phrygian / etc.
    if r == 0 or r == 2 or r == 5 or r == 7 or r == 10 or r == 3 or r == 8 or r == 1 then return true end
  end
  return false
end

local function getContextualNoteName(pitchClass, root, scaleIdx)
  local useFlats = prefersFlats(root, scaleIdx)
  local names = useFlats and FLAT_NOTE_NAMES or SHARP_NOTE_NAMES
  return names[(pitchClass % 12) + 1]
end

local CHORD_FORMULAS = {
  -- Triads
  ["0,4,7"] = { quality = "", name = "Major", score = 100 },
  ["0,3,7"] = { quality = "m", name = "Minor", score = 100 },
  ["0,3,6"] = { quality = "dim", name = "Diminished", score = 95 },
  ["0,4,8"] = { quality = "aug", name = "Augmented", score = 95 },
  ["0,5,7"] = { quality = "sus4", name = "Sus4", score = 90 },
  ["0,2,7"] = { quality = "sus2", name = "Sus2", score = 90 },

  -- 7ths
  ["0,4,7,11"] = { quality = "maj7", name = "Major 7th", score = 110 },
  ["0,4,7,10"] = { quality = "7", name = "Dominant 7th", score = 110 },
  ["0,3,7,10"] = { quality = "m7", name = "Minor 7th", score = 110 },
  ["0,3,6,10"] = { quality = "m7b5", name = "Half Diminished", score = 105 },
  ["0,3,6,9"]  = { quality = "dim7", name = "Diminished 7th", score = 105 },
  ["0,3,7,11"] = { quality = "m(maj7)", name = "Minor Major 7th", score = 100 },
  ["0,4,8,10"] = { quality = "7#5", name = "Augmented 7th", score = 100 },
  ["0,4,8,11"] = { quality = "maj7#5", name = "Major 7th #5", score = 100 },
  ["0,4,7,9"]  = { quality = "6", name = "Major 6th", score = 100 },
  ["0,3,7,9"]  = { quality = "m6", name = "Minor 6th", score = 100 },
  ["0,2,4,7"]  = { quality = "add9", name = "Add 9", score = 100 },
  ["0,2,3,7"]  = { quality = "m(add9)", name = "Minor Add 9", score = 100 },
  ["0,5,7,10"] = { quality = "7sus4", name = "7 Sus4", score = 100 },
  ["0,2,7,10"] = { quality = "7sus2", name = "7 Sus2", score = 100 },

  -- 9ths
  ["0,2,4,7,11"] = { quality = "maj9", name = "Major 9th", score = 120 },
  ["0,2,4,7,10"] = { quality = "9", name = "Dominant 9th", score = 120 },
  ["0,2,3,7,10"] = { quality = "m9", name = "Minor 9th", score = 120 },
  ["0,2,4,7,9"]  = { quality = "6/9", name = "6/9", score = 115 },
  ["0,2,3,7,9"]  = { quality = "m6/9", name = "Minor 6/9", score = 115 },
  ["0,1,4,7,10"] = { quality = "7b9", name = "7b9", score = 115 },
  ["0,3,4,7,10"] = { quality = "7#9", name = "7#9", score = 115 },

  -- Incomplete 7ths (no 5th)
  ["0,4,10"] = { quality = "7(no5)", name = "7 (no 5)", score = 80 },
  ["0,4,11"] = { quality = "maj7(no5)", name = "maj7 (no 5)", score = 80 },
  ["0,3,10"] = { quality = "m7(no5)", name = "m7 (no 5)", score = 80 },

  -- Dyads / 2-note
  ["0,7"] = { quality = "5", name = "Power 5th", score = 70 },
  ["0,4"] = { quality = "(no5)", name = "Major 3rd", score = 60 },
  ["0,3"] = { quality = "m(no5)", name = "Minor 3rd", score = 60 },
  ["0,5"] = { quality = "sus4(no5)", name = "4th", score = 55 },
  ["0,2"] = { quality = "sus2(no5)", name = "2nd", score = 55 },
  ["0,10"] = { quality = "7(no5)", name = "b7", score = 60 },
  ["0,11"] = { quality = "maj7(no5)", name = "7", score = 60 }
}

local function detectChord(pitches, root, scaleIdx)
  if not pitches or #pitches == 0 then return "" end

  root = root or 0
  scaleIdx = scaleIdx or 1
  local scale = SCALES[scaleIdx] or SCALES[1]
  local inScaleMap = {}
  for _, intv in ipairs(scale.intervals) do
    inScaleMap[(root + intv) % 12] = true
  end

  local sortedPitches = {}
  for _, p in ipairs(pitches) do
    if type(p) == "number" then table.insert(sortedPitches, p) end
  end
  if #sortedPitches == 0 then return "" end
  table.sort(sortedPitches)

  local bassPitch = sortedPitches[1]
  local bassPC = bassPitch % 12
  local bassName = getContextualNoteName(bassPC, root, scaleIdx)

  local uniquePCs = {}
  local pcPresent = {}
  for _, p in ipairs(sortedPitches) do
    local pc = p % 12
    if not pcPresent[pc] then
      pcPresent[pc] = true
      table.insert(uniquePCs, pc)
    end
  end

  if #uniquePCs == 1 then
    return bassName
  end

  local bestScore = -9999
  local bestChord = nil

  for _, candidateRoot in ipairs(uniquePCs) do
    local intervals = {}
    for _, pc in ipairs(uniquePCs) do
      table.insert(intervals, (pc - candidateRoot + 12) % 12)
    end
    table.sort(intervals)
    local key = table.concat(intervals, ",")

    local formula = CHORD_FORMULAS[key]
    if formula then
      local score = formula.score or 50

      -- Bonus: Root is in the bass
      if candidateRoot == bassPC then
        score = score + 30
      end

      -- Bonus: Root is in the active musical scale
      if inScaleMap[candidateRoot] then
        score = score + 20
      end

      -- Bonus: Root matches active key root
      if candidateRoot == root then
        score = score + 15
      end

      if score > bestScore then
        bestScore = score
        bestChord = {
          root = candidateRoot,
          quality = formula.quality,
          name = formula.name,
          bass = bassPC
        }
      end
    end
  end

  if not bestChord then
    -- Fallback: return bass note or interval
    if #uniquePCs == 2 then
      local intv = (uniquePCs[2] - uniquePCs[1] + 12) % 12
      return bassName .. " (+" .. intv .. ")"
    end
    return bassName
  end

  local chordRootName = getContextualNoteName(bestChord.root, root, scaleIdx)
  local chordStr = chordRootName .. bestChord.quality
  if bestChord.bass ~= bestChord.root then
    chordStr = chordStr .. "/" .. bassName
  end

  return chordStr
end

return {
  SCALES = SCALES,
  NOTE_NAMES = NOTE_NAMES,
  FLAT_NOTE_NAMES = FLAT_NOTE_NAMES,
  SHARP_NOTE_NAMES = SHARP_NOTE_NAMES,
  WHITE_KEY_INDEX = WHITE_KEY_INDEX,
  CHORDS = CHORDS,
  noteNumToName = noteNumToName,
  getIntervalInfo = getIntervalInfo,
  getTransposedPitch = getTransposedPitch,
  getTransposedChordPitches = getTransposedChordPitches,
  getChordPitches = getTransposedChordPitches,
  getDiatonicPadChord = getDiatonicPadChord,
  getScaleGuideInfo = getScaleGuideInfo,
  detectChord = detectChord,
  getContextualNoteName = getContextualNoteName,
  prefersFlats = prefersFlats
}

