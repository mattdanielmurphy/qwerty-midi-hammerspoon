-- packages/music-engine/init.lua
-- Unified export for shared music theory, clock, harmony, and arpeggiator.

local harmony = require("harmony")
local clock = require("clock")
local arpeggiator = require("arpeggiator")

return {
  harmony = harmony,
  clock = clock,
  arpeggiator = arpeggiator,
  SCALES = harmony.SCALES,
  NOTE_NAMES = harmony.NOTE_NAMES,
  CHORDS = harmony.CHORDS,
  WHITE_KEY_INDEX = harmony.WHITE_KEY_INDEX,
  ARP_DIRECTIONS = clock.ARP_DIRECTIONS,
  ARP_RATES = clock.ARP_RATES,
  noteNumToName = harmony.noteNumToName,
  getIntervalInfo = harmony.getIntervalInfo,
  getTransposedPitch = harmony.getTransposedPitch,
  getTransposedChordPitches = harmony.getTransposedChordPitches
}
