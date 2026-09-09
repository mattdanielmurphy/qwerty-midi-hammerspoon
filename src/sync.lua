-- src/sync.lua
-- Bidirectional synchronization between QWERTY MIDI (Hammerspoon) and DualSynth (DualSense macOS app)
-- Uses macOS native NSDistributedNotificationCenter via hs.distributednotifications

local sync = {}

local isSyncing = false
local configRef = nil
local hudRef = nil

local DUALSYNTH_STATE_NOTIFICATION = "DualSynthStateBroadcast"
local QWERTY_STATE_NOTIFICATION = "QwertyMidiStateBroadcast"
local QWERTY_NOTE_NOTIFICATION = "QwertyMidiNoteBroadcast"

local function log(msg)
  print("[Sync]: " .. tostring(msg))
end

function sync.init(config, hud)
  configRef = config
  hudRef = hud
  _G.activeWatchers = _G.activeWatchers or {}

  -- Stop previous watcher if reloading
  if _G.activeWatchers.dualSynthSyncWatcher then
    _G.activeWatchers.dualSynthSyncWatcher:stop()
    _G.activeWatchers.dualSynthSyncWatcher = nil
  end

  -- 1. Listen for state updates from DualSynth
  _G.activeWatchers.dualSynthSyncWatcher = hs.distributednotifications.new(function(name, object, userInfo)
    if isSyncing or not userInfo or not configRef then return end
    isSyncing = true

    local state = configRef.state
    local stateChanged = false

    if userInfo.root ~= nil then
      local rootNum = tonumber(userInfo.root)
      if rootNum and state.currentRoot ~= rootNum then
        state.currentRoot = rootNum
        hs.settings.set("qwertyMidi_currentRoot", state.currentRoot)
        stateChanged = true
      end
    end

    if userInfo.scaleIdx ~= nil then
      local scaleNum = tonumber(userInfo.scaleIdx)
      if scaleNum then
        local targetIdx = scaleNum + 1 -- Swift is 0-indexed, Lua is 1-indexed
        if state.currentScaleIdx ~= targetIdx then
          state.currentScaleIdx = targetIdx
          hs.settings.set("qwertyMidi_currentScaleIdx", state.currentScaleIdx)
          stateChanged = true
        end
      end
    end

    if userInfo.bpm ~= nil then
      local bpmNum = tonumber(userInfo.bpm)
      if bpmNum and math.abs((state.arpBpm or 120) - bpmNum) > 0.5 then
        state.arpBpm = bpmNum
        hs.settings.set("qwertyMidi_arpBpm", state.arpBpm)
        stateChanged = true
      end
    end

    if userInfo.octaveShift ~= nil then
      local octNum = tonumber(userInfo.octaveShift)
      if octNum and state.octaveShift ~= octNum then
        state.octaveShift = octNum
        hs.settings.set("qwertyMidi_octaveShift", state.octaveShift)
        stateChanged = true
      end
    end

    if userInfo.chordIdx ~= nil then
      local chordNum = tonumber(userInfo.chordIdx)
      if chordNum then
        local targetChord = chordNum + 1
        if state.chordIdx ~= targetChord then
          state.chordIdx = targetChord
          hs.settings.set("qwertyMidi_chordIdx", state.chordIdx)
          stateChanged = true
        end
      end
    end

    if stateChanged then
      log("Synced state from DualSynth: Root=" .. tostring(state.currentRoot) .. " Scale=" .. tostring(state.currentScaleIdx) .. " BPM=" .. tostring(state.arpBpm))
      if hudRef and hudRef.updateWebviewHud then
        hudRef.updateWebviewHud()
      end
    end

    isSyncing = false
  end, DUALSYNTH_STATE_NOTIFICATION)

  if _G.activeWatchers.dualSynthSyncWatcher then
    _G.activeWatchers.dualSynthSyncWatcher:start()
    log("Started DualSynth sync listener on " .. DUALSYNTH_STATE_NOTIFICATION)
  end
end

-- Broadcast QWERTY state to DualSynth
function sync.broadcastState(state)
  if isSyncing or not state then return end
  local payload = {
    root = state.currentRoot or 0,
    scaleIdx = (state.currentScaleIdx or 1) - 1, -- Swift 0-indexed
    bpm = state.arpBpm or 120,
    octaveShift = state.octaveShift or 0,
    chordIdx = (state.chordIdx or 1) - 1
  }

  hs.distributednotifications.post(QWERTY_STATE_NOTIFICATION, nil, payload)
end

-- Broadcast played notes to DualSynth visualizer
function sync.broadcastNotes(pitches, isNoteOn)
  if not pitches then return end
  if type(pitches) == "number" then
    pitches = { pitches }
  end
  hs.distributednotifications.post(QWERTY_NOTE_NOTIFICATION, nil, {
    pitches = pitches,
    isNoteOn = isNoteOn == true
  })
end

return sync
