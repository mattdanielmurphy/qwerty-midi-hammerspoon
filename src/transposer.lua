-- src/transposer.lua
-- Transposition and pitch mapping adapter delegating to packages/music-engine/harmony.

local config = require("config")
local harmony = require("harmony")
local state = config.state

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
  return harmony.getTransposedPitch(basePitch, isTopRow, state)
end

local function noteNumToName(noteNum)
  return harmony.noteNumToName(noteNum)
end

local function getIntervalInfo(noteNum)
  return harmony.getIntervalInfo(noteNum, state.currentRoot, state.currentScaleIdx)
end

local function getTransposedChordPitches(basePitch, isTopRow, forceChord, chordIdx)
  local chordOpt = forceChord
  if type(forceChord) == "boolean" and chordIdx then
    chordOpt = { enabled = forceChord, chordIdx = chordIdx }
  end
  return harmony.getTransposedChordPitches(basePitch, isTopRow, chordOpt, state)
end

local function getDiatonicPadChord(padIdx)
  return harmony.getDiatonicPadChord(padIdx, state)
end

local function getScaleGuideInfo(minPitch, maxPitch)
  return harmony.getScaleGuideInfo(state.currentRoot, state.currentScaleIdx, minPitch, maxPitch)
end

return {
  getEffectiveRowVelocity = getEffectiveRowVelocity,
  getTransposedPitch = getTransposedPitch,
  noteNumToName = noteNumToName,
  getIntervalInfo = getIntervalInfo,
  getTransposedChordPitches = getTransposedChordPitches,
  getChordPitches = getTransposedChordPitches,
  getDiatonicPadChord = getDiatonicPadChord,
  getScaleGuideInfo = getScaleGuideInfo
}

