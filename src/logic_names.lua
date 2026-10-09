-- src/logic_names.lua
-- Real-time track name synchronization with Logic Pro
-- Extracts actual Logic Pro track names via macOS Accessibility (AXUIElement)
-- with zero MIDI port collision and falls back gracefully when Logic is inactive.

local logic_names = {}

local pollTimer = nil
local appWatcher = nil
local lastObservedNames = {}
local isPolling = false

local function parseTrackHeaderDescription(desc)
  if not desc or type(desc) ~= "string" then return nil, nil end
  local numStr = string.match(desc, "Track%s+(%d+)")
  if not numStr then return nil, nil end
  local trackNum = tonumber(numStr)

  -- Look for UTF-8 curly quotes \226\128\156 (") and \226\128\157 (")
  local qStart = string.find(desc, "\226\128\156", 1, true)
  local qEnd = string.find(desc, "\226\128\157", 1, true)
  local name = nil
  if qStart and qEnd and qEnd > qStart then
    name = string.sub(desc, qStart + 3, qEnd - 1)
  else
    name = string.match(desc, "Track%s+%d+%s+[\"“](.-)[\"”]")
  end

  if name and #name > 0 then
    -- Strip trailing spaces or formatting artifacts
    name = string.match(name, "^%s*(.-)%s*$")
  end

  return trackNum, name
end

function logic_names.scanLogicTracks()
  local app = hs.application.find("Logic Pro")
  if not app then
    return nil, "Logic Pro not running"
  end

  local tw = nil
  local focusedWin = app:focusedWindow()
  if focusedWin and string.find(tostring(focusedWin:title()), "Tracks") then
    tw = hs.axuielement.windowElement(focusedWin)
  end

  if not tw then
    local ax = hs.axuielement.applicationElement(app)
    if ax then
      for _, w in ipairs(ax.AXWindows or {}) do
        if string.find(tostring(w.AXTitle), "Tracks") then
          tw = w
          break
        end
      end
    end
  end

  if not tw then
    return nil, "Tracks window not found"
  end

  -- Fast direct path test: root/8/2/1/2/1/1
  local headerGroup = nil
  local path = { 8, 2, 1, 2, 1, 1 }
  local h = tw
  for _, idx in ipairs(path) do
    local ch = h and h.AXChildren
    h = ch and ch[idx]
  end
  if h and h.AXDescription and string.find(h.AXDescription, "Tracks header") then
    headerGroup = h
  else
    local function findHeader(el, depth)
      if depth > 8 then return nil end
      local desc = el.AXDescription
      if desc and string.find(desc, "Tracks header") then
        return el
      end
      for _, c in ipairs(el.AXChildren or {}) do
        local res = findHeader(c, depth + 1)
        if res then return res end
      end
      return nil
    end
    headerGroup = findHeader(tw, 0)
  end

  if not headerGroup then
    return nil, "Tracks header not found"
  end

  local tracks = {}
  for _, item in ipairs(headerGroup.AXChildren or {}) do
    local desc = item.AXDescription
    local num, name = parseTrackHeaderDescription(desc)
    if num and name and #name > 0 then
      tracks[num] = name
    end
  end

  return tracks, nil
end

function logic_names.updateTrackNames(force)
  if isPolling then return end
  isPolling = true

  local ok, res, err = pcall(function()
    return logic_names.scanLogicTracks()
  end)

  isPolling = false

  if not ok or not res then
    return false
  end

  local state = _G.activeWatchers and _G.activeWatchers.state
  if not state or not state.tracks then
    return false
  end

  local changed = false
  for trkId = 1, 4 do
    local trk = state.tracks[trkId]
    if trk then
      local observed = res[trkId]
      if observed and observed ~= "" then
        if trk.name ~= observed or lastObservedNames[trkId] ~= observed then
          trk.name = observed
          trk.nameSource = "logic"
          lastObservedNames[trkId] = observed
          changed = true
        end
      end
    end
  end

  if (changed or force) and _G.activeWatchers and _G.activeWatchers.hud then
    if _G.activeWatchers.hud.updateWebviewHud then
      _G.activeWatchers.hud.updateWebviewHud(nil, nil, true)
    end
  end

  return changed
end

function logic_names.init()
  _G.activeWatchers = _G.activeWatchers or {}

  if _G.activeWatchers.logicNamesTimer then
    _G.activeWatchers.logicNamesTimer:stop()
    _G.activeWatchers.logicNamesTimer = nil
  end

  if _G.activeWatchers.logicNamesAppWatcher then
    _G.activeWatchers.logicNamesAppWatcher:stop()
    _G.activeWatchers.logicNamesAppWatcher = nil
  end

  local state = _G.activeWatchers and _G.activeWatchers.state
  if state and not state.midiActive then
    return
  end

  -- Initial scan
  logic_names.updateTrackNames(true)

  -- Poll every 2.0s when Logic is running (scan takes ~80ms, non-blocking)
  pollTimer = hs.timer.new(2.0, function()
    local app = hs.application.find("Logic Pro")
    if app then
      logic_names.updateTrackNames(false)
    end
  end)
  pollTimer:start()
  _G.activeWatchers.logicNamesTimer = pollTimer

  -- App watcher to trigger immediate scan when Logic Pro activates or launches
  appWatcher = hs.application.watcher.new(function(appName, eventType, app)
    if appName == "Logic Pro" then
      if eventType == hs.application.watcher.activated or eventType == hs.application.watcher.launched then
        hs.timer.doAfter(0.3, function()
          logic_names.updateTrackNames(true)
        end)
      end
    end
  end)
  appWatcher:start()
  _G.activeWatchers.logicNamesAppWatcher = appWatcher

  print("QWERTY MIDI: Logic Pro track name synchronization active")
end

function logic_names.stop()
  if pollTimer then
    pollTimer:stop()
    pollTimer = nil
  end
  if appWatcher then
    appWatcher:stop()
    appWatcher = nil
  end
  if _G.activeWatchers then
    _G.activeWatchers.logicNamesTimer = nil
    _G.activeWatchers.logicNamesAppWatcher = nil
  end
end

logic_names.parseTrackHeaderDescription = parseTrackHeaderDescription

return logic_names
