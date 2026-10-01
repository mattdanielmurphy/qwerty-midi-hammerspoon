-- packages/nanokey-studio/probe.lua
-- Diagnostic probe for inspecting real-time MIDI, CC, and SysEx messages from Korg nanoKEY Studio.
-- Run in Hammerspoon console via: require("nanokey_studio.probe").start()

local probe = {}
local midiDevice = nil

local function log(msg)
  local line = os.date("%H:%M:%S") .. " [nanoKEY-PROBE]: " .. msg
  print(line)
  local f = io.open("/Users/matt/projects/qwerty-midi-hammerspoon/tmp/nanokey_probe.log", "a")
  if f then
    f:write(line .. "\n")
    f:close()
  end
end

function probe.listDevices()
  local devices = hs.midi.devices()
  print("=== Available MIDI Devices ===")
  for idx, name in ipairs(devices) do
    print(string.format("  [%d] %s", idx, name))
  end
  return devices
end

function probe.start(targetName)
  probe.stop()
  targetName = targetName or "nanoKEY Studio"

  local devices = hs.midi.devices()
  local foundName = nil
  for _, name in ipairs(devices) do
    if string.find(string.lower(name), string.lower(targetName)) then
      foundName = name
      break
    end
  end

  if not foundName then
    log("Device matching '" .. targetName .. "' not found. Available devices:")
    probe.listDevices()
    return false
  end

  log("Attaching probe to device: " .. foundName)
  midiDevice = hs.midi.new(foundName)
  if not midiDevice then
    log("Failed to create hs.midi instance for: " .. foundName)
    return false
  end

  midiDevice:callback(function(object, deviceName, commandType, description, metadata)
    local metaStr = ""
    if metadata then
      local parts = {}
      for k, v in pairs(metadata) do
        table.insert(parts, string.format("%s=%s", tostring(k), tostring(v)))
      end
      metaStr = " {" .. table.concat(parts, ", ") .. "}"
    end
    log(string.format("CMD: %-16s | DESC: %-20s | META:%s",
      tostring(commandType), tostring(description), metaStr))
  end)

  log("Probe is ACTIVE! Press buttons, turn knobs, or hold Shift/Sustain on the nanoKEY Studio.")
  return true
end

function probe.stop()
  if midiDevice then
    log("Stopping probe.")
    midiDevice = nil
  end
end

return probe
