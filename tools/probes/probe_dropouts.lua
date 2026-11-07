-- Before/after dropout probe (read-only, sends no MIDI, posts no input).
-- Simulates a key event arriving every 10 ms on the Hammerspoon main thread (where the
-- QWERTY event tap and hs.midi callbacks run) and records how late each one is handled,
-- while the Logic track-name poll runs every 3 s exactly as the controller runs it.
--   mode "old": poll body = hs.application.find("Logic Pro")        (shipped code)
--   mode "new": poll body = applicationsForBundleID + isPlaying()   (fixed code)
-- Usage: hs -c "dofile('.../probe_dropouts.lua')('old', 30)"  then read _G.__dropoutResult
return function(mode, seconds)
  if _G.__dp then for _, t in pairs(_G.__dp) do t:stop() end end
  _G.__dp = {}
  local lates = {}
  local expected = 0.010
  local last = hs.timer.absoluteTime()
  _G.__dropoutResult = "running " .. mode
  _G.__dp.tick = hs.timer.doEvery(expected, function()
    local now = hs.timer.absoluteTime()
    lates[#lates + 1] = math.max(0, (now - last) / 1e6 - expected * 1000)
    last = now
  end)
  local pollBody
  if mode == "old" then
    pollBody = function() return hs.application.find("Logic Pro") end
  else
    local ln = package.loaded["logic_names"]
    pollBody = function()
      local apps = hs.application.applicationsForBundleID("com.apple.logic10")
      local app = apps and apps[1]
      if app and ln and ln.isPlaying then ln.isPlaying() end
      return app
    end
  end
  _G.__dp.poll = hs.timer.doEvery(3.0, pollBody)
  _G.__dp.stop = hs.timer.doAfter(seconds, function()
    for _, t in pairs(_G.__dp) do t:stop() end
    table.sort(lates)
    local function pct(p) return lates[math.max(1, math.floor(#lates * p))] or 0 end
    local over30 = 0
    for _, l in ipairs(lates) do if l > 30 then over30 = over30 + 1 end end
    _G.__dropoutResult = string.format("%s: n=%d  p50=%.1fms  p99=%.1fms  max=%.1fms  stalls>30ms=%d",
      mode, #lates, pct(0.5), pct(0.99), lates[#lates] or 0, over30)
  end)
end
