local config = require("config")
local state = config.state
local SCALES = config.SCALES
local NOTE_NAMES = config.NOTE_NAMES
local WHITE_KEY_INDEX = config.WHITE_KEY_INDEX

local function getEffectiveRowVelocity(isTopRow)
  local isSplitArp = state.arpEnabled and state.arpBottomEnabled and (not state.arpTopEnabled)
  if isTopRow then
    local baseVol = state.topRowVolume
    if isSplitArp then
      baseVol = baseVol + state.splitArpTopBoost
    end
    return math.max(0, math.min(127, baseVol))
  else
    return math.max(0, math.min(127, state.bottomRowVolume))
  end
end

local function getTransposedPitch(basePitch, isTopRow)
  local effectivePitch = basePitch + (isTopRow and state.topRowOctaveOffset or state.bottomRowOctaveOffset)
  local octave = math.floor(effectivePitch / 12) - 1
  local noteInOctave = effectivePitch % 12
  local scaleIndex = WHITE_KEY_INDEX[noteInOctave]

  if scaleIndex and scaleIndex ~= -1 then
    local intervals = SCALES[state.currentScaleIdx].intervals
    local numIntervals = #intervals
    local transposedIndex = scaleIndex + state.transposeShift
    local octaveOffset = math.floor(transposedIndex / numIntervals)
    local idxInScale = (((transposedIndex % numIntervals) + numIntervals) % numIntervals) + 1

    local targetInterval = intervals[idxInScale]
    local newPitch = ((octave + 1 + octaveOffset) * 12) + state.currentRoot + targetInterval + state.octaveShift
    return newPitch
  end
  local fallbackPitch = effectivePitch + state.currentRoot + state.octaveShift + state.transposeShift
  return fallbackPitch
end

local function noteNumToName(noteNum)
  local octave = math.floor(noteNum / 12) - 1
  local noteName = NOTE_NAMES[(noteNum % 12) + 1]
  return noteName .. octave
end

local function getIntervalInfo(noteNum)
  local noteInOctave = noteNum % 12
  local semitonesFromRoot = (noteInOctave - state.currentRoot + 12) % 12
  local intervals = SCALES[state.currentScaleIdx].intervals

  for idx, interval in ipairs(intervals) do
    if interval == semitonesFromRoot then
      return idx, semitonesFromRoot
    end
  end
  return nil, semitonesFromRoot
end

local function getTransposedChordPitches(basePitch, isTopRow)
  local rootPitch = getTransposedPitch(basePitch, isTopRow)
  if not (state.quoteHeld or state.chordModeActive) then
    return { rootPitch }
  end
  local chordDef = state.CHORDS[state.chordIdx] or state.CHORDS[1]
  local offsets = chordDef.offsets or { 0 }
  
  local effectivePitch = basePitch + (isTopRow and state.topRowOctaveOffset or state.bottomRowOctaveOffset)
  local noteInOctave = effectivePitch % 12
  local scaleIndex = WHITE_KEY_INDEX[noteInOctave]
  if not scaleIndex or scaleIndex == -1 then
    return { rootPitch }
  end
  
  local intervals = SCALES[state.currentScaleIdx].intervals
  local numIntervals = #intervals
  local baseTransposedIndex = scaleIndex + state.transposeShift
  local octave = math.floor(effectivePitch / 12) - 1
  
  local pitches = {}
  for _, off in ipairs(offsets) do
    local transposedIndex = baseTransposedIndex + off
    local octaveOffset = math.floor(transposedIndex / numIntervals)
    local idxInScale = (((transposedIndex % numIntervals) + numIntervals) % numIntervals) + 1
    local targetInterval = intervals[idxInScale]
    local newPitch = ((octave + 1 + octaveOffset) * 12) + state.currentRoot + targetInterval + state.octaveShift
    table.insert(pitches, newPitch)
  end
  return pitches
end

return {
  getEffectiveRowVelocity = getEffectiveRowVelocity,
  getTransposedPitch = getTransposedPitch,
  noteNumToName = noteNumToName,
  getIntervalInfo = getIntervalInfo,
  getTransposedChordPitches = getTransposedChordPitches,
  getChordPitches = getTransposedChordPitches
}
