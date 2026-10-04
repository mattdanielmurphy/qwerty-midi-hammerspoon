-- packages/music-engine/quantizer.lua
-- Real-time input quantization engine for MIDI keys, pads, and chords.
-- Features legato sustaining during grid anticipation delays to eliminate awkward silent gaps.

local quantizer = {}

local QUANTIZE_FACTORS = {
  ["Off"]  = nil,
  ["None"] = nil,
  ["1/1"]  = 4.0,     -- Whole note
  ["1/2"]  = 2.0,     -- Half note
  ["1/4"]  = 1.0,     -- Quarter note
  ["1/8"]  = 0.5,     -- Eighth note
  ["1/16"] = 0.25,    -- Sixteenth note
  ["1/32"] = 0.125    -- Thirty-second note
}

local gridReferenceTime = hs.timer.absoluteTime() / 1e9
local pendingEvents = {} -- [eventId] = { pitches = {}, channel = 0, vel = 100, onFired = false, released = false, timer = ... }
local activePlayingNotes = {} -- [pitch_ch] = count of held instances
local soundingNotes = {} -- [eventId] = { eventId = ..., pitches = ..., channel = ..., onRelease = ..., keyReleased = ..., graceTimer = ..., heldForPending = ... }
local panicGeneration = 0

function quantizer.resetGrid()
  gridReferenceTime = hs.timer.absoluteTime() / 1e9
end

function quantizer.getQuantizeFactors()
  return QUANTIZE_FACTORS
end

--- Calculate delay in seconds until the next quantized grid tick.
-- @param bpm number
-- @param mode string (e.g. "1/4", "1/8", "1/16", "Off")
-- @return number delay in seconds (0 if Off or on-beat)
function quantizer.calculateDelay(bpm, mode)
  if not mode or mode == "Off" or mode == "None" then
    return 0
  end
  local factor = QUANTIZE_FACTORS[mode]
  if not factor then
    return 0
  end

  local clampedBpm = math.max(20.0, math.min(999.0, bpm or 120.0))
  local quarterSec = 60.0 / clampedBpm
  local stepDuration = quarterSec * factor

  local now = hs.timer.absoluteTime() / 1e9
  local elapsed = (now - gridReferenceTime) % stepDuration
  local timeToNext = stepDuration - elapsed

  -- Tolerance window:
  -- If struck within 12ms before the beat, consider it on the beat now
  if timeToNext <= 0.012 then
    return 0
  end
  -- If struck within 20ms after the beat, catch up immediately (prevent full step lag)
  if elapsed <= 0.020 then
    return 0
  end

  return timeToNext
end

--- Schedule or immediately execute a Note On / Chord event through quantization.
-- When delayed by quantization, sustains currently sounding or just-released notes on the channel
-- until the new note sounds on the grid, producing a seamless legato transition without silent gaps.
-- @param eventId string unique identifier (e.g. "pad_1" or "key_48")
-- @param pitches table list of MIDI note numbers e.g. {48, 52, 55}
-- @param vel number velocity (1..127)
-- @param ch number MIDI channel (0..15)
-- @param bpm number active BPM
-- @param mode string quantize mode ("Off", "1/4", "1/8", etc.)
-- @param onTrigger function(pitches, vel, ch) callback executed when note fires
function quantizer.queueNoteOn(eventId, pitches, vel, ch, bpm, mode, onTrigger)
  if type(pitches) == "number" then
    pitches = { pitches }
  end
  ch = ch or 0
  vel = vel or 100

  -- Cancel any previous pending event for this ID
  if pendingEvents[eventId] then
    if pendingEvents[eventId].timer then pcall(function() pendingEvents[eventId].timer:stop() end) end
    if pendingEvents[eventId].gateTimer then pcall(function() pendingEvents[eventId].gateTimer:stop() end) end
    pendingEvents[eventId] = nil
  end

  local delay = quantizer.calculateDelay(bpm, mode)

  if delay <= 0 then
    -- Immediate playback (No quantization or landed on grid)
    -- Release any notes on this channel that were waiting in release grace
    for sId, sEntry in pairs(soundingNotes) do
      if sEntry.channel == ch and sId ~= eventId then
        if sEntry.graceTimer then
          pcall(function() sEntry.graceTimer:stop() end)
          sEntry.graceTimer = nil
        end
        if sEntry.keyReleased and sEntry.onRelease then
          sEntry.onRelease(sEntry.pitches, sEntry.channel)
          for _, p in ipairs(sEntry.pitches) do
            local key = p .. "_" .. sEntry.channel
            if activePlayingNotes[key] then activePlayingNotes[key] = math.max(0, activePlayingNotes[key] - 1) end
          end
          soundingNotes[sId] = nil
          pendingEvents[sId] = nil
        end
      end
    end

    pendingEvents[eventId] = {
      eventId = eventId,
      pitches = pitches,
      channel = ch,
      vel = vel,
      onFired = true,
      released = false,
      bpm = bpm,
      mode = mode
    }
    soundingNotes[eventId] = {
      eventId = eventId,
      pitches = pitches,
      channel = ch,
      bpm = bpm,
      quantMode = mode,
      onRelease = nil,
      keyReleased = false,
      generation = panicGeneration
    }
    for _, p in ipairs(pitches) do
      local key = p .. "_" .. ch
      activePlayingNotes[key] = (activePlayingNotes[key] or 0) + 1
    end
    if onTrigger then onTrigger(pitches, vel, ch) end
    return 0
  else
    -- Quantized schedule: note is delayed to the grid.
    -- LEGATO SUSTAIN: Any currently sounding note on this channel (whether still physically held
    -- or just released in grace) must be sustained until this new note sounds on the grid!
    for sId, sEntry in pairs(soundingNotes) do
      if sEntry.channel == ch and sId ~= eventId then
        if sEntry.graceTimer then
          pcall(function() sEntry.graceTimer:stop() end)
          sEntry.graceTimer = nil
        end
        sEntry.heldForPending = eventId
      end
    end

    local ev = {
      eventId = eventId,
      pitches = pitches,
      channel = ch,
      vel = vel,
      onFired = false,
      released = false,
      bpm = bpm,
      mode = mode,
      generation = panicGeneration
    }
    pendingEvents[eventId] = ev

    ev.timer = hs.timer.doAfter(delay, function()
      if ev.generation ~= panicGeneration then return end
      ev.timer = nil
      ev.onFired = true

      -- Collect all notes that were sustained on this channel for this event
      local notesToRelease = {}
      for sId, sEntry in pairs(soundingNotes) do
        if sEntry.heldForPending == eventId then
          table.insert(notesToRelease, sEntry)
          sEntry.heldForPending = nil
        end
      end

      -- If any sustained note shares pitch(es) with the new note, release the shared pitch
      -- before triggering the new note so the synth voice re-attacks cleanly.
      local newPitchSet = {}
      for _, p in ipairs(pitches) do newPitchSet[p] = true end

      for _, sEntry in ipairs(notesToRelease) do
        local hasShared = false
        for _, p in ipairs(sEntry.pitches) do
          if newPitchSet[p] then hasShared = true; break end
        end
        if hasShared and sEntry.onRelease then
          sEntry.onRelease(sEntry.pitches, sEntry.channel)
          sEntry.releasedDone = true
        end
      end

      -- Sound the new note on the grid tick!
      for _, p in ipairs(pitches) do
        local key = p .. "_" .. ch
        activePlayingNotes[key] = (activePlayingNotes[key] or 0) + 1
      end

      if onTrigger then onTrigger(pitches, vel, ch) end

      -- Release the remaining sustained notes whose pitches are different (seamless legato transition)
      for _, sEntry in ipairs(notesToRelease) do
        if not sEntry.releasedDone then
          if sEntry.onRelease then
            sEntry.onRelease(sEntry.pitches, sEntry.channel)
          end
        end
        for _, p in ipairs(sEntry.pitches) do
          local key = p .. "_" .. sEntry.channel
          if activePlayingNotes[key] then
            activePlayingNotes[key] = math.max(0, activePlayingNotes[key] - 1)
          end
        end
        soundingNotes[sEntry.eventId] = nil
        pendingEvents[sEntry.eventId] = nil
      end

      -- Register this new note as actively sounding
      soundingNotes[eventId] = {
        eventId = eventId,
        pitches = pitches,
        channel = ch,
        bpm = bpm,
        quantMode = mode,
        onRelease = ev.onRelease,
        keyReleased = ev.released,
        generation = panicGeneration
      }

      -- If the user already released this key/pad before the grid arrived (staccato tap),
      -- hold for minimum musical gate duration, then trigger release.
      if ev.released then
        local factor = QUANTIZE_FACTORS[mode] or 1.0
        local clampedBpm = math.max(20.0, math.min(999.0, bpm or 120.0))
        local stepSec = (60.0 / clampedBpm) * factor
        local gateTime = math.max(0.060, stepSec * 0.6) -- 60% of step or min 60ms

        ev.gateTimer = hs.timer.doAfter(gateTime, function()
          if ev.generation ~= panicGeneration then return end
          ev.gateTimer = nil
          if ev.onRelease then ev.onRelease(pitches, ch) end
          for _, p in ipairs(pitches) do
            local key = p .. "_" .. ch
            if activePlayingNotes[key] then
              activePlayingNotes[key] = math.max(0, activePlayingNotes[key] - 1)
            end
          end
          soundingNotes[eventId] = nil
          pendingEvents[eventId] = nil
        end)
      end
    end)

    return delay
  end
end

--- Handle Note Off for a quantized event.
-- If the note is held for a pending quantized note, defers Note-Off until the new note triggers.
-- If no pending note is yet scheduled, provides a musical grace period so a subsequent note press
-- can sustain it seamlessly without gaps.
-- @param eventId string unique identifier
-- @param onRelease function(pitches, ch) callback executed to send noteOff
function quantizer.queueNoteOff(eventId, onRelease)
  local ev = pendingEvents[eventId]
  local snd = soundingNotes[eventId]

  if ev and not ev.onFired then
    -- Note hasn't fired yet! When timer fires, the staccato gate logic in queueNoteOn will release it.
    ev.released = true
    ev.onRelease = onRelease
    return
  end

  if snd then
    snd.keyReleased = true
    snd.onRelease = onRelease

    -- If this sounding note is already bound to sustain for a pending event, do not turn it off now!
    if snd.heldForPending and pendingEvents[snd.heldForPending] then
      return
    end

    -- Check if there is already a pending event scheduled on this channel
    local pendingOnChannel = nil
    for pId, pEv in pairs(pendingEvents) do
      if pEv.channel == snd.channel and not pEv.onFired then
        pendingOnChannel = pId
        break
      end
    end

    if pendingOnChannel then
      snd.heldForPending = pendingOnChannel
      return
    end

    -- No pending event yet on this channel. Check if quantize mode is active:
    local isQuantized = (snd.quantMode and snd.quantMode ~= "Off" and snd.quantMode ~= "None")
    if isQuantized then
      -- Start a release grace timer. If a new note is pressed on this channel within this window,
      -- this note is sustained until the new note fires on the grid!
      local factor = QUANTIZE_FACTORS[snd.quantMode] or 1.0
      local clampedBpm = math.max(20.0, math.min(999.0, snd.bpm or 120.0))
      local stepSec = (60.0 / clampedBpm) * factor
      local graceDuration = math.min(0.120, math.max(0.050, stepSec * 0.75))

      local gen = panicGeneration
      snd.graceTimer = hs.timer.doAfter(graceDuration, function()
        if gen ~= panicGeneration then return end
        snd.graceTimer = nil
        if snd.onRelease then
          snd.onRelease(snd.pitches, snd.channel)
        end
        for _, p in ipairs(snd.pitches) do
          local key = p .. "_" .. snd.channel
          if activePlayingNotes[key] then
            activePlayingNotes[key] = math.max(0, activePlayingNotes[key] - 1)
          end
        end
        soundingNotes[eventId] = nil
        pendingEvents[eventId] = nil
      end)
    else
      -- Quantization is Off: release immediately
      if onRelease then onRelease(snd.pitches, snd.channel) end
      for _, p in ipairs(snd.pitches) do
        local key = p .. "_" .. snd.channel
        if activePlayingNotes[key] then
          activePlayingNotes[key] = math.max(0, activePlayingNotes[key] - 1)
        end
      end
      soundingNotes[eventId] = nil
      pendingEvents[eventId] = nil
    end
  else
    -- Fallback if not tracked in soundingNotes
    if onRelease and ev then
      onRelease(ev.pitches, ev.channel)
      for _, p in ipairs(ev.pitches) do
        local key = p .. "_" .. ev.channel
        if activePlayingNotes[key] then
          activePlayingNotes[key] = math.max(0, activePlayingNotes[key] - 1)
        end
      end
      pendingEvents[eventId] = nil
    end
  end
end

--- Panic / clean all pending quantized events
function quantizer.panic(onReleaseAll)
  panicGeneration = panicGeneration + 1
  for eventId, ev in pairs(pendingEvents) do
    if ev.timer then
      pcall(function() ev.timer:stop() end)
    end
    if ev.gateTimer then
      pcall(function() ev.gateTimer:stop() end)
    end
    if ev.onFired and onReleaseAll then
      pcall(function() onReleaseAll(ev.pitches, ev.channel) end)
    end
  end
  for eventId, snd in pairs(soundingNotes) do
    if snd.graceTimer then
      pcall(function() snd.graceTimer:stop() end)
    end
    if snd.onRelease then
      pcall(function() snd.onRelease(snd.pitches, snd.channel) end)
    elseif onReleaseAll then
      pcall(function() onReleaseAll(snd.pitches, snd.channel) end)
    end
  end
  pendingEvents = {}
  soundingNotes = {}
  activePlayingNotes = {}
end

return quantizer
