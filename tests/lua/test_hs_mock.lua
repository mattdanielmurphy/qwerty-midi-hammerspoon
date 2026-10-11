-- tests/lua/test_hs_mock.lua
-- Pure-Lua verification of hs_mock APIs and behavior

local T = dofile("tests/harness/test_assert.lua")
local mock = dofile("tests/harness/hs_mock.lua")

T.suite("hs_mock Timer Lifecycle and Chronological Execution")

T.test("hs.timer.new creates inactive repeating timer", function()
  mock.reset()
  local fired = 0
  local t = hs.timer.new(1.0, function() fired = fired + 1 end)
  T.assert(not t:running(), "Timer should not be running before start()")
  
  t:start()
  T.assert(t:running(), "Timer should be running after start()")
  
  mock.advanceTime(0.5)
  T.assertEqual(fired, 0, "Timer should not fire at 0.5s")
  
  mock.advanceTime(0.6) -- 1.1s total
  T.assertEqual(fired, 1, "Timer should fire once at 1.0s")
  
  mock.advanceTime(2.0) -- 3.1s total -> fires at 2.0s and 3.0s
  T.assertEqual(fired, 3, "Timer should fire at 2.0s and 3.0s")
  
  t:stop()
  T.assert(not t:running(), "Timer should not be running after stop()")
  
  mock.advanceTime(5.0)
  T.assertEqual(fired, 3, "Stopped timer must not fire again")
end)

T.test("hs.timer fires timers in strict chronological order", function()
  mock.reset()
  local order = {}
  
  hs.timer.doAfter(0.5, function() table.insert(order, "B (0.5s)") end)
  hs.timer.doAfter(0.1, function() table.insert(order, "A (0.1s)") end)
  hs.timer.doAfter(0.3, function() table.insert(order, "C (0.3s)") end)
  
  mock.advanceTime(1.0)
  T.assertEqual(#order, 3, "All 3 timers must fire")
  T.assertEqual(order[1], "A (0.1s)", "Earliest timer must fire first")
  T.assertEqual(order[2], "C (0.3s)", "Middle timer must fire second")
  T.assertEqual(order[3], "B (0.5s)", "Latest timer must fire third")
end)

T.suite("hs_mock EventTap Keyboard and Event Interception")

T.test("hs.eventtap intercepts and swallows keystrokes when returning true", function()
  mock.reset()
  local capturedCode = nil
  local tapCount = 0
  
  local tap = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(ev)
    tapCount = tapCount + 1
    capturedCode = ev:getProperty(hs.eventtap.event.properties.keyboardEventKeycode)
    return true -- swallow event
  end)
  
  T.assert(not tap:isEnabled(), "EventTap must be disabled initially")
  local res1 = mock.emitKeyEvent(hs.eventtap.event.types.keyDown, 49, {})
  T.assert(not res1.swallowed, "Disabled tap must not swallow events")
  T.assertEqual(tapCount, 0, "Disabled tap must not invoke callback")
  
  tap:start()
  T.assert(tap:isEnabled(), "EventTap must be enabled after start()")
  
  local res2 = mock.emitKeyEvent(hs.eventtap.event.types.keyDown, 49, {})
  T.assert(res2.swallowed, "Enabled tap returning true must swallow event")
  T.assertEqual(tapCount, 1, "Callback must be invoked")
  T.assertEqual(capturedCode, 49, "Event keycode must be passed")
  
  -- KeyUp should not be swallowed because tap only registered keyDown
  local res3 = mock.emitKeyEvent(hs.eventtap.event.types.keyUp, 49, {})
  T.assert(not res3.swallowed, "Tap without keyUp must not swallow keyUp")
  
  tap:stop()
  T.assert(not tap:isEnabled(), "EventTap must be disabled after stop()")
end)

T.summary()
