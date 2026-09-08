-- packages/music-engine/clock.lua
-- Tempo, BPM conversion, rates, and timing calculations.

local ARP_DIRECTIONS = { "UP", "DOWN", "UP-DOWN", "DOWN-UP", "CONVERGE", "DIVERGE", "RANDOM" }

local ARP_RATES = {
  -- Straight rates (slow → fast)
  { label = "4",     factor = 16.0 },
  { label = "2",     factor = 8.0 },
  { label = "1",     factor = 4.0 },
  { label = "1/2",   factor = 2.0 },
  { label = "1/4",   factor = 1.0 },
  { label = "1/8",   factor = 0.5 },
  { label = "1/16",  factor = 0.25 },
  { label = "1/32",  factor = 0.125 },
  { label = "1/64",  factor = 0.0625 },
  -- Triplet rates (slow → fast)
  { label = "4T",    factor = 16.0 / 1.5 },
  { label = "2T",    factor = 8.0  / 1.5 },
  { label = "1T",    factor = 4.0  / 1.5 },
  { label = "1/2T",  factor = 2.0  / 1.5 },
  { label = "1/4T",  factor = 1.0  / 1.5 },
  { label = "1/8T",  factor = 0.5  / 1.5 },
  { label = "1/16T", factor = 0.25 / 1.5 },
  { label = "1/32T", factor = 0.125 / 1.5 },
  { label = "1/64T", factor = 0.0625 / 1.5 }
}

local function getRateFactor(rateIdx)
  local rate = ARP_RATES[rateIdx] or ARP_RATES[5]
  return rate.factor
end

local function bpmToIntervalSeconds(bpm, rateIdx)
  local clampedBpm = math.max(20.0, math.min(999.0, bpm or 120.0))
  local quarterNoteDuration = 60.0 / clampedBpm
  local factor = getRateFactor(rateIdx)
  return quarterNoteDuration * factor
end

local function getGateDurationSeconds(intervalSeconds, gatePercent)
  local clampedGate = math.max(5.0, math.min(100.0, gatePercent or 80.0)) / 100.0
  return math.max(0.010, intervalSeconds * clampedGate)
end

return {
  ARP_DIRECTIONS = ARP_DIRECTIONS,
  ARP_RATES = ARP_RATES,
  getRateFactor = getRateFactor,
  bpmToIntervalSeconds = bpmToIntervalSeconds,
  getGateDurationSeconds = getGateDurationSeconds
}
