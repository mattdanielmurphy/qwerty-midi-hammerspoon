-- Read-only timing probe: how long do calls block the Hammerspoon main thread?
local function t(name, fn, n)
  n = n or 5
  local mx, sum = 0, 0
  for _ = 1, n do
    local a = hs.timer.absoluteTime()
    fn()
    local d = (hs.timer.absoluteTime() - a) / 1e6
    sum = sum + d
    if d > mx then mx = d end
  end
  print(string.format("%-34s avg %7.2fms max %7.2fms", name, sum / n, mx))
end
t("app.find 'Logic Pro'", function() hs.application.find("Logic Pro") end)
t("applicationsForBundleID logic", function() hs.application.applicationsForBundleID("com.apple.logic10") end)
t("frontmostApplication+bundleID", function() local a = hs.application.frontmostApplication(); if a then a:bundleID() end end, 20)
t("midi.devices", function() hs.midi.devices() end)
t("full GC", function() collectgarbage("collect") end, 2)

-- Main-thread stall monitor: a 5ms timer records how late it fires.
_G.__stallProbe = { max = 0, over50 = 0, n = 0, last = hs.timer.absoluteTime(), worst = {} }
local p = _G.__stallProbe
if _G.__stallTimer then _G.__stallTimer:stop() end
_G.__stallTimer = hs.timer.doEvery(0.005, function()
  local now = hs.timer.absoluteTime()
  local gap = (now - p.last) / 1e6
  p.last = now
  p.n = p.n + 1
  if gap > p.max then p.max = gap end
  if gap > 50 then p.over50 = p.over50 + 1; table.insert(p.worst, string.format("%.0f", gap)) end
end)
print("stall probe started")
