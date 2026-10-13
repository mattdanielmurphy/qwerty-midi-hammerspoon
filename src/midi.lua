local hsMidi = require("hs.midi")

_G.activeWatchers = _G.activeWatchers or {}

local function getMidiDevice()
  if _G.activeWatchers.midiDevice then return _G.activeWatchers.midiDevice end

  local devices = hsMidi.devices() or {}
  local virtualSources = hsMidi.virtualSources() or {}

  for _, devName in ipairs(devices) do
    if string.find(devName, "IAC") or string.find(devName, "Bus") then
      _G.activeWatchers.midiDevice = hsMidi.new(devName)
      return _G.activeWatchers.midiDevice
    end
  end

  for _, devName in ipairs(virtualSources) do
    if string.find(devName, "IAC") or string.find(devName, "Bus") then
      _G.activeWatchers.midiDevice = hsMidi.newVirtualSource(devName)
      return _G.activeWatchers.midiDevice
    end
  end

  if #devices > 0 then
    _G.activeWatchers.midiDevice = hsMidi.new(devices[1])
  elseif #virtualSources > 0 then
    _G.activeWatchers.midiDevice = hsMidi.newVirtualSource(virtualSources[1])
  end

  return _G.activeWatchers.midiDevice
end

local activeNoteLedger = {} -- [noteNum] = { [channel] = { track = trackId, color = color, vel = vel } }

local function getTrackForChannel(channel)
  local state = _G.activeWatchers and _G.activeWatchers.state
  if not state then
    pcall(function()
      local config = require("config")
      state = config and config.state
    end)
  end
  if state and state.tracks then
    for trkId, trk in pairs(state.tracks) do
      if trk.channel == channel then
        return trkId, trk.color or "#00e5ff"
      end
    end
  end
  local fallbackColors = { [1] = "#00e5ff", [2] = "#ff9100", [3] = "#00e676", [4] = "#d500f9" }
  local trkId = ((channel or 0) % 4) + 1
  return trkId, fallbackColors[trkId] or "#00e5ff"
end

local function getActiveNoteLedger()
  local snapshot = {}
  for note, voices in pairs(activeNoteLedger) do
    for ch, voice in pairs(voices) do
      snapshot[tostring(note)] = {
        note = note,
        channel = ch,
        track = voice.track,
        color = voice.color,
        startTime = voice.startTime,
        vel = voice.vel
      }
      break
    end
  end
  return snapshot
end

--- Scan active notes for hung/orphaned voices exceeding maxAgeSec (default 5.0s)
--- and automatically silence them unless physically held or sustained.
--- @param currentTime number optional timestamp (seconds)
--- @param maxAgeSec number optional threshold (seconds, default 5.0)
--- @param state table optional controller state table
--- @return table list of silenced orphan note tables
local function checkOrphanedVoices(currentTime, maxAgeSec, state)
  local now = currentTime or ((hs and hs.timer and hs.timer.absoluteTime and (hs.timer.absoluteTime() / 1e9)) or os.time())
  local threshold = maxAgeSec or 5.0
  local st = state or (_G.activeWatchers and _G.activeWatchers.state) or {}

  local orphans = {}
  for note, voices in pairs(activeNoteLedger) do
    for ch, voice in pairs(voices) do
      local age = now - (voice.startTime or now)
      local isOrphan = (age > threshold)

      -- Check if note corresponds to any currently pressed physical key
      if isOrphan and st.pressedKeys then
        for code, keyInfo in pairs(st.pressedKeys) do
          if type(keyInfo) == "table" and keyInfo.pitches then
            for _, p in ipairs(keyInfo.pitches) do
              if p == note and (keyInfo.channel == nil or keyInfo.channel == ch) then
                isOrphan = false
                break
              end
            end
          end
          if not isOrphan then break end
        end
      end

      -- Check if note is sustained in any track's sustainedPitches or global state
      if isOrphan then
        if st.sustainedPitches and st.sustainedPitches[note] then
          isOrphan = false
        elseif st.tracks then
          for _, trk in pairs(st.tracks) do
            if trk.sustainedPitches then
              for _, sp in ipairs(trk.sustainedPitches) do
                local p = (type(sp) == "table" and sp.pitch) or sp
                local c = (type(sp) == "table" and sp.channel) or nil
                if p == note and (c == nil or c == ch) then
                  isOrphan = false
                  break
                end
              end
            end
            if not isOrphan then break end
          end
        end
      end

      if isOrphan then
        table.insert(orphans, { note = note, channel = ch, track = voice.track, startTime = voice.startTime })
      end
    end
  end

  for _, orphan in ipairs(orphans) do
    sendMidiNote("noteOff", orphan.note, 0, orphan.channel)
  end

  return orphans
end

local function clearActiveNotes()
  activeNoteLedger = {}
  if _G.activeWatchers and _G.activeWatchers.hud and _G.activeWatchers.hud.clearPianoNotes then
    _G.activeWatchers.hud.clearPianoNotes()
  end
end

local function sendMidiNote(cmd, noteNum, vel, channel)
  if type(noteNum) == "table" then
    channel = channel or noteNum.channel
    noteNum = noteNum.pitch
  end
  if not noteNum or type(noteNum) ~= "number" or noteNum < 0 or noteNum > 127 then return end
  local dev = getMidiDevice()
  local ch = channel or 0
  local isNoteOn = (cmd == "noteOn" and (vel or 0) > 0)
  local isNoteOff = (cmd == "noteOff" or (cmd == "noteOn" and (vel or 0) == 0))
  local trkId, trkColor = getTrackForChannel(ch)

  if dev then
    if isNoteOff then
      dev:sendCommand("noteOff", { note = noteNum, velocity = 0, channel = ch })
      dev:sendCommand("noteOn", { note = noteNum, velocity = 0, channel = ch })
    else
      dev:sendCommand("noteOn", { note = noteNum, velocity = vel, channel = ch })
    end
  end

  -- Update active note ledger & real-time piano visualizer
  if isNoteOn then
    local now = (hs and hs.timer and hs.timer.absoluteTime and (hs.timer.absoluteTime() / 1e9)) or os.time()
    activeNoteLedger[noteNum] = activeNoteLedger[noteNum] or {}
    activeNoteLedger[noteNum][ch] = { track = trkId, color = trkColor, vel = vel, startTime = now, note = noteNum, channel = ch }
    if _G.activeWatchers and _G.activeWatchers.hud and _G.activeWatchers.hud.updatePianoNote then
      _G.activeWatchers.hud.updatePianoNote(noteNum, true, trkId, trkColor)
    end
  elseif isNoteOff then
    if activeNoteLedger[noteNum] then
      activeNoteLedger[noteNum][ch] = nil
      if next(activeNoteLedger[noteNum]) == nil then
        activeNoteLedger[noteNum] = nil
      end
    end
    local stillActive = (activeNoteLedger[noteNum] ~= nil)
    local remainingTrkId = 0
    local remainingColor = ""
    if stillActive then
      for _, voice in pairs(activeNoteLedger[noteNum]) do
        remainingTrkId = voice.track
        remainingColor = voice.color
        break
      end
    end
    if _G.activeWatchers and _G.activeWatchers.hud and _G.activeWatchers.hud.updatePianoNote then
      _G.activeWatchers.hud.updatePianoNote(noteNum, stillActive, remainingTrkId, remainingColor)
    end
  end

  if _G.activeWatchers and _G.activeWatchers.sync and _G.activeWatchers.sync.broadcastNotes then
    _G.activeWatchers.sync.broadcastNotes(noteNum, isNoteOn)
  end
end

local function sendSustainCC(val)
  local dev = getMidiDevice()
  if not dev then return end
  for ch = 0, 15 do
    dev:sendCommand("controlChange", { controllerNumber = 64, controllerValue = val, channel = ch })
  end
end

local function sendMidiCC(controllerNum, val, channel)
  local dev = getMidiDevice()
  if dev then
    dev:sendCommand("controlChange", { controllerNumber = controllerNum, controllerValue = val, channel = channel or 0 })
  end
end

local function silenceChannel(channel)
  local dev = getMidiDevice()
  local ch = channel or 0
  if dev then
    dev:sendCommand("controlChange", { controllerNumber = 64, controllerValue = 0, channel = ch })
    dev:sendCommand("controlChange", { controllerNumber = 120, controllerValue = 0, channel = ch })
    dev:sendCommand("controlChange", { controllerNumber = 123, controllerValue = 0, channel = ch })
  end
  local notesToRelease = {}
  for note, voices in pairs(activeNoteLedger) do
    if voices and voices[ch] then
      table.insert(notesToRelease, note)
    end
  end
  for _, note in ipairs(notesToRelease) do
    sendMidiNote("noteOff", note, 0, ch)
  end
end

local function panicAllChannels()
  local dev = getMidiDevice()
  clearActiveNotes()
  if not dev then return end

  for ch = 0, 15 do
    -- Release sustain before explicit note-offs; send the channel-mode fallback
    -- after individual releases so synths receive both forms of note cleanup.
    dev:sendCommand("controlChange", { controllerNumber = 64, controllerValue = 0, channel = ch })
    for note = 0, 127 do
      dev:sendCommand("noteOff", { note = note, velocity = 0, channel = ch })
    end
    dev:sendCommand("controlChange", { controllerNumber = 123, controllerValue = 0, channel = ch })
    dev:sendCommand("controlChange", { controllerNumber = 120, controllerValue = 0, channel = ch })
    dev:sendCommand("controlChange", { controllerNumber = 121, controllerValue = 0, channel = ch })
    dev:sendCommand("pitchWheelChange", { pitchChange = 8192, channel = ch })
  end
end

return {
  getMidiDevice = getMidiDevice,
  sendMidiNote = sendMidiNote,
  sendMidiCC = sendMidiCC,
  sendSustainCC = sendSustainCC,
  silenceChannel = silenceChannel,
  panicAllChannels = panicAllChannels,
  getActiveNoteLedger = getActiveNoteLedger,
  clearActiveNotes = clearActiveNotes,
  getTrackForChannel = getTrackForChannel,
  checkOrphanedVoices = checkOrphanedVoices
}
