-- Loopback test for piano_lock: listen on IAC, feed simulated piano notes, see what arrives.
-- Velocity-1 notes on channel 16, released at once.
_G.__plSeen = {}
if _G.__plListen then _G.__plListen:callback(nil) end
_G.__plListen = hs.midi.new("IAC Driver")
_G.__plListen:callback(function(_, _, cmd, _, d)
  if cmd == "noteOn" or cmd == "noteOff" then
    table.insert(_G.__plSeen, string.format("%s %d v%d ch%d", cmd, d.note, d.velocity or 0, (d.channel or 0) + 1))
  end
end)
local P = _G.pianoLock
local lock = require("scale_lock")
local t0 = hs.timer.absoluteTime()
P.simulate("noteOn", 60, 1); P.simulate("noteOff", 60, 0)   -- C: pass
P.simulate("noteOn", 61, 1); P.simulate("noteOff", 61, 0)   -- C#: drop on, pass off
P.simulate("noteOn", 64, 1)                                  -- E held across a scale change
P.setScale("Eb major")
P.simulate("noteOff", 64, 0)                                 -- off still passes: nothing sticks
P.simulate("noteOn", 63, 1); P.simulate("noteOff", 63, 0)   -- Eb: now passes
local simMs = (hs.timer.absoluteTime() - t0) / 1e6
local afterSet = P.getState()
P.setScale("weekly")
hs.timer.doAfter(0.5, function()
  _G.__plResult = string.format("routing cost for 9 events: %.2f ms\nset->%s mode=%s dropped=%d passed=%d\nback to: %s\nIAC saw:\n  %s",
    simMs, afterSet.current, afterSet.mode, afterSet.dropped, afterSet.passed, P.getState().current,
    table.concat(_G.__plSeen, "\n  "))
  _G.__plListen:callback(nil)
end)
