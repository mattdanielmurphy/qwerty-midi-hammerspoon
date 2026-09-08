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
  if not forceChord and not (state.quoteHeld or state.chordModeActive) then
    return { rootPitch }
  end
  local chordList = state.CHORDS or CHORDS
  local chordDef = chordList[state.chordIdx or 1] or chordList[1]
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

return {
  SCALES = SCALES,
  NOTE_NAMES = NOTE_NAMES,
  WHITE_KEY_INDEX = WHITE_KEY_INDEX,
  CHORDS = CHORDS,
  noteNumToName = noteNumToName,
  getIntervalInfo = getIntervalInfo,
  getTransposedPitch = getTransposedPitch,
  getTransposedChordPitches = getTransposedChordPitches,
  getChordPitches = getTransposedChordPitches
}
