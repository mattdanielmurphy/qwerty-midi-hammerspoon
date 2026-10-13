-- tests/lua/test_quantizer_engine.lua
-- Pure-Lua verification of real packages/music-engine/quantizer.lua

local T = dofile("tests/harness/test_assert.lua")
local mock = dofile("tests/harness/hs_mock.lua")

T.suite("packages/music-engine/quantizer.lua Engine Tests")

local quantizer = loadfile("packages/music-engine/quantizer.lua")()

T.test("quantizer exports core functions and valid factors", function()
  T.assertEqual(type(quantizer.calculateDelay), "function", "calculateDelay must be a function")
  T.assertEqual(type(quantizer.getQuantizeFactors), "function", "getQuantizeFactors must be a function")
  T.assertEqual(type(quantizer.resetGrid), "function", "resetGrid must be a function")

  local factors = quantizer.getQuantizeFactors()
  T.assertEqual(factors["1/16"], 0.25, "1/16 step factor must be 0.25")
  T.assertEqual(factors["1/8"], 0.5, "1/8 step factor must be 0.5")
  T.assertEqual(factors["1/4"], 1.0, "1/4 step factor must be 1.0")
  T.assertEqual(factors["1/2"], 2.0, "1/2 step factor must be 2.0")
  T.assertEqual(factors["1/1"], 4.0, "1/1 step factor must be 4.0")
  T.assertEqual(factors["Off"], nil, "Off must have nil factor")
end)

T.test("calculateDelay returns 0 for disabled or unmapped modes", function()
  mock.reset()
  quantizer.resetGrid()
  
  T.assertEqual(quantizer.calculateDelay(120, "Off"), 0, "Off mode must return 0 delay")
  T.assertEqual(quantizer.calculateDelay(120, "None"), 0, "None mode must return 0 delay")
  T.assertEqual(quantizer.calculateDelay(120, nil), 0, "nil mode must return 0 delay")
  T.assertEqual(quantizer.calculateDelay(120, "invalid_mode"), 0, "Unknown mode must return 0 delay")
end)

T.test("calculateDelay calculates proper delay and applies tolerance windows", function()
  mock.reset()
  quantizer.resetGrid() -- gridReferenceTime = 1000.0

  -- At 120 BPM: quarter note is 0.5s (mode "1/4")
  -- Advance clock 0.1s -> elapsed = 0.1s. timeToNext = 0.4s.
  mock.setTime(1000.1)
  local delay100 = quantizer.calculateDelay(120, "1/4", 100)
  T.assertClose(delay100, 0.4, 1e-3, "Full strength delay should be ~0.4s")
  local delayDefault = quantizer.calculateDelay(120, "1/4")
  T.assertClose(delayDefault, 0.36, 1e-3, "Default 90% strength delay should be ~0.36s")

  -- Anticipation tolerance test: within 12ms before the beat
  -- timeToNext <= 0.012 -> returns 0
  mock.setTime(1000.490) -- 10ms before next beat at 1000.5
  local delayAnticipated = quantizer.calculateDelay(120, "1/4")
  T.assertEqual(delayAnticipated, 0, "Anticipation <= 12ms must return 0 delay")

  -- Catchup tolerance test: within 20ms after the beat
  -- elapsed <= 0.020 -> returns 0
  mock.setTime(1000.510) -- 10ms after beat at 1000.5
  local delayCatchup = quantizer.calculateDelay(120, "1/4")
  T.assertEqual(delayCatchup, 0, "Catchup <= 20ms must return 0 delay")
end)

T.test("calculateDelay clamps BPM within [20, 999]", function()
  mock.reset()
  quantizer.resetGrid()
  mock.setTime(1000.1)

  -- BPM below 20 clamps to 20 BPM -> quarter note is 3.0s
  local delayLow = quantizer.calculateDelay(5, "1/4")
  T.assert(delayLow > 0 and delayLow <= 3.0, "Low BPM must be clamped to 20")

  -- BPM above 999 clamps to 999 BPM
  local delayHigh = quantizer.calculateDelay(5000, "1/4")
  T.assert(delayHigh >= 0 and delayHigh <= 0.1, "High BPM must be clamped to 999")
end)

T.summary()
