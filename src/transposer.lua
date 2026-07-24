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
  local effectivePitch = basePitch + (isTopRow and state.topRowOctaveOffset or 0) + state.transposeShift
  local octave = math.floor(effectivePitch / 12) - 1
  local noteInOctave = effectivePitch % 12
  local scaleIndex = WHITE_KEY_INDEX[noteInOctave]

  if scaleIndex and scaleIndex ~= -1 then
    local intervals = SCALES[state.currentScaleIdx].intervals
    local targetInterval = intervals[scaleIndex + 1]
    local newPitch = ((octave + 1) * 12) + state.currentRoot + targetInterval + state.octaveShift
    if newPitch >= 0 and newPitch <= 127 then
      return newPitch
    end
  end
  local fallbackPitch = effectivePitch + state.currentRoot + state.octaveShift
  return math.max(0, math.min(127, fallbackPitch))
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

return {
  getEffectiveRowVelocity = getEffectiveRowVelocity,
  getTransposedPitch = getTransposedPitch,
  noteNumToName = noteNumToName,
  getIntervalInfo = getIntervalInfo
}
