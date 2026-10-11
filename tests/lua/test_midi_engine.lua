-- tests/lua/test_midi_engine.lua
-- Pure-Lua verification of real src/midi.lua against hs_mock

local T = dofile("tests/harness/test_assert.lua")
local mock = dofile("tests/harness/hs_mock.lua")

T.suite("src/midi.lua Engine Tests")

local midi = loadfile("src/midi.lua")()

T.test("midi module exports required interface functions", function()
  T.assertEqual(type(midi.getMidiDevice), "function", "getMidiDevice must be a function")
  T.assertEqual(type(midi.sendMidiNote), "function", "sendMidiNote must be a function")
  T.assertEqual(type(midi.sendMidiCC), "function", "sendMidiCC must be a function")
  T.assertEqual(type(midi.getActiveNoteLedger), "function", "getActiveNoteLedger must be a function")
  T.assertEqual(type(midi.panicAllChannels), "function", "panicAllChannels must be a function")
  T.assertEqual(type(midi.clearActiveNotes), "function", "clearActiveNotes must be a function")
end)

T.test("sendMidiNote tracks active notes in ledger and emits noteOn/noteOff", function()
  mock.reset()
  midi.clearActiveNotes()

  -- Note On note 60, channel 0, velocity 100
  midi.sendMidiNote("noteOn", 60, 100, 0)
  
  local sent = mock.getSentMidi()
  T.assertEqual(#sent, 1, "Must have transmitted 1 MIDI message")
  T.assertEqual(sent[1].command, "noteOn", "Command must be noteOn")
  T.assertEqual(sent[1].note, 60, "Pitch must be 60")
  T.assertEqual(sent[1].velocity, 100, "Velocity must be 100")
  T.assertEqual(sent[1].channel, 0, "Channel must be 0")

  local ledger = midi.getActiveNoteLedger()
  T.assert(ledger["60"] ~= nil, "Pitch 60 must be in active voice ledger")
  T.assertEqual(ledger["60"].note, 60, "Ledger entry note must be 60")
  T.assertEqual(ledger["60"].channel, 0, "Ledger entry channel must be 0")

  -- Note Off note 60, channel 0
  mock.clearSentMidi()
  midi.sendMidiNote("noteOff", 60, 0, 0)
  
  local sentOff = mock.getSentMidi()
  T.assert(#sentOff >= 1, "Must transmit noteOff message")
  T.assertEqual(sentOff[1].command, "noteOff", "Command must be noteOff")
  T.assertEqual(sentOff[1].note, 60, "Pitch must be 60")

  local ledgerAfter = midi.getActiveNoteLedger()
  T.assertEqual(ledgerAfter["60"], nil, "Pitch 60 must be cleared from ledger on noteOff")
end)

T.test("sendMidiCC transmits control change events", function()
  mock.reset()
  midi.sendMidiCC(7, 110, 1) -- CC 7 (Volume), Value 110, Channel 1

  local sent = mock.getSentMidi()
  T.assertEqual(#sent, 1, "Must transmit 1 MIDI message")
  T.assertEqual(sent[1].command, "controlChange", "Command must be controlChange")
  T.assertEqual(sent[1].controllerNumber, 7, "Controller must be CC 7")
  T.assertEqual(sent[1].controllerValue, 110, "Value must be 110")
  T.assertEqual(sent[1].channel, 1, "Channel must be 1")
end)

T.test("panicAllChannels sends sweep across all 16 channels and clears ledger", function()
  mock.reset()
  midi.clearActiveNotes()

  -- Play two active notes on different channels
  midi.sendMidiNote("noteOn", 48, 90, 0)
  midi.sendMidiNote("noteOn", 52, 95, 1)
  
  local ledgerBefore = midi.getActiveNoteLedger()
  T.assert(ledgerBefore["48"] ~= nil and ledgerBefore["52"] ~= nil, "Ledger should have 2 active notes")

  mock.clearSentMidi()
  midi.panicAllChannels()

  -- Verifies ledger is completely cleared
  local ledgerAfter = midi.getActiveNoteLedger()
  T.assertEqual(next(ledgerAfter), nil, "Ledger must be completely empty after panicAllChannels")

  -- Verifies 16 channels receive CC 64, noteOffs, CC 123, CC 120, CC 121, pitchWheel
  local sent = mock.getSentMidi()
  T.assert(#sent > 2000, "panicAllChannels must transmit extensive sweep across all 16 channels")

  -- Check channel 0 and channel 15 specifically
  local ch0Msgs = {}
  local ch15Msgs = {}
  for _, m in ipairs(sent) do
    if m.channel == 0 then table.insert(ch0Msgs, m) end
    if m.channel == 15 then table.insert(ch15Msgs, m) end
  end
  T.assert(#ch0Msgs > 100, "Channel 0 must receive panic sweep")
  T.assert(#ch15Msgs > 100, "Channel 15 must receive panic sweep")
end)

T.summary()
