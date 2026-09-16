-- packages/music-engine/quantizer.lua
-- Real-time input quantization engine for MIDI keys, pads, and chords.

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
  if pendingEvents[eventId] and pendingEvents[eventId].timer then
    pcall(function() pendingEvents[eventId].timer:stop() end)
    pendingEvents[eventId] = nil
  end

  local delay = quantizer.calculateDelay(bpm, mode)

  if delay <= 0 then
    -- Immediate playback (No quantization or landed on grid)
    pendingEvents[eventId] = {
      pitches = pitches,
      channel = ch,
      vel = vel,
      onFired = true,
      released = false
    }
    for _, p in ipairs(pitches) do
      local key = p .. "_" .. ch
      activePlayingNotes[key] = (activePlayingNotes[key] or 0) + 1
    end
    if onTrigger then onTrigger(pitches, vel, ch) end
    return 0
  else
    -- Quantized schedule
    local ev = {
      pitches = pitches,
      channel = ch,
      vel = vel,
      onFired = false,
      released = false
    }
    pendingEvents[eventId] = ev

    ev.timer = hs.timer.doAfter(delay, function()
      ev.timer = nil
      ev.onFired = true

      for _, p in ipairs(pitches) do
        local key = p .. "_" .. ch
        activePlayingNotes[key] = (activePlayingNotes[key] or 0) + 1
      end

      if onTrigger then onTrigger(pitches, vel, ch) end

      -- If the user already released the key/pad before the grid arrived (staccato tap),
      -- hold for minimum musical gate duration, then trigger release.
      if ev.released then
        local factor = QUANTIZE_FACTORS[mode] or 1.0
        local clampedBpm = math.max(20.0, math.min(999.0, bpm or 120.0))
        local stepSec = (60.0 / clampedBpm) * factor
        local gateTime = math.max(0.060, stepSec * 0.6) -- 60% of step or min 60ms

        hs.timer.doAfter(gateTime, function()
          if ev.onRelease then ev.onRelease(pitches, ch) end
          for _, p in ipairs(pitches) do
            local key = p .. "_" .. ch
            if activePlayingNotes[key] then
              activePlayingNotes[key] = math.max(0, activePlayingNotes[key] - 1)
            end
          end
          pendingEvents[eventId] = nil
        end)
      end
    end)

    return delay
  end
end

--- Handle Note Off for a quantized event.
-- @param eventId string unique identifier
-- @param onRelease function(pitches, ch) callback executed to send noteOff
function quantizer.queueNoteOff(eventId, onRelease)
  local ev = pendingEvents[eventId]
  if not ev then return end

  ev.released = true
  ev.onRelease = onRelease

  if ev.onFired then
    -- Note has already fired on the grid, release it immediately
    if onRelease then onRelease(ev.pitches, ev.channel) end
    for _, p in ipairs(ev.pitches) do
      local key = p .. "_" .. ev.channel
      if activePlayingNotes[key] then
        activePlayingNotes[key] = math.max(0, activePlayingNotes[key] - 1)
      end
    end
    pendingEvents[eventId] = nil
  else
    -- Note hasn't fired yet! When timer fires, the staccato gate logic in queueNoteOn will release it.
  end
end

--- Panic / clean all pending quantized events
function quantizer.panic(onReleaseAll)
  for eventId, ev in pairs(pendingEvents) do
    if ev.timer then
      pcall(function() ev.timer:stop() end)
    end
    if ev.onFired and onReleaseAll then
      pcall(function() onReleaseAll(ev.pitches, ev.channel) end)
    end
  end
  pendingEvents = {}
  activePlayingNotes = {}
end

return quantizer
