local startTime = hs.timer.absoluteTime()
local function logTime(msg)
  local t = hs.timer.absoluteTime()
  print("PROFILE: " .. msg .. " - " .. tostring((t - startTime) / 1000000) .. "ms")
end
return logTime
