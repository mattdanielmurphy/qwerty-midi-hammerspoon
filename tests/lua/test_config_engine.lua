-- tests/lua/test_config_engine.lua
-- Pure-Lua verification of real src/config.lua against hs_mock settings

local T = dofile("tests/harness/test_assert.lua")
local mock = dofile("tests/harness/hs_mock.lua")

T.suite("src/config.lua Engine & Persistence Tests")

T.test("config loads default state when hs.settings store is empty", function()
  mock.reset()
  local config = loadfile("src/config.lua")()

  T.assertEqual(config.state.currentRoot, 0, "Default root pitch should be 0 (C)")
  T.assertEqual(config.state.currentScaleIdx, 1, "Default scale should be 1 (Major)")
  T.assertEqual(config.state.octaveShift, 0, "Default octave shift should be 0")
  T.assertEqual(config.state.zoomLevel, 1.0, "Default zoom level should be 1.0")
  T.assertEqual(config.state.arpLatchActive, false, "Default arp latch should be false")
  T.assertEqual(type(config.SCALES), "table", "SCALES table must be exported")
  T.assertEqual(#config.NOTE_NAMES, 12, "NOTE_NAMES table must have 12 semitones")
end)

T.test("config restores state from hs.settings using qwertyMidi_ prefix", function()
  mock.reset()
  -- Pre-populate persisted settings
  hs.settings.set("qwertyMidi_currentRoot", 7) -- G
  hs.settings.set("qwertyMidi_currentScaleIdx", 3)
  hs.settings.set("qwertyMidi_octaveShift", 12)
  hs.settings.set("qwertyMidi_zoomLevel", 1.5)
  hs.settings.set("qwertyMidi_arpLatchActive", true)

  local config = loadfile("src/config.lua")()

  T.assertEqual(config.state.currentRoot, 7, "Root should be restored from settings")
  T.assertEqual(config.state.currentScaleIdx, 3, "Scale should be restored from settings")
  T.assertEqual(config.state.octaveShift, 12, "Octave shift should be restored from settings")
  T.assertEqual(config.state.zoomLevel, 1.5, "Zoom level should be restored from settings")
  T.assertEqual(config.state.arpLatchActive, true, "Arp latch should be restored from settings")
end)

T.test("saveSettings persists active parameters into hs.settings", function()
  mock.reset()
  local config = loadfile("src/config.lua")()

  config.state.currentRoot = 4 -- E
  config.state.zoomLevel = 1.2
  config.saveSettings()

  T.assertEqual(hs.settings.get("qwertyMidi_currentRoot"), 4, "saveSettings must persist currentRoot")
  T.assertEqual(hs.settings.get("qwertyMidi_zoomLevel"), 1.2, "saveSettings must persist zoomLevel")
end)

T.summary()
