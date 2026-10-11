-- tests/lua/runner.lua
-- Standalone test runner for all pure-Lua test suites in tests/lua/

local suites = {
  "tests/lua/test_hs_mock.lua",
  "tests/lua/test_quantizer_engine.lua",
  "tests/lua/test_midi_engine.lua",
  "tests/lua/test_config_engine.lua"
}

print("==================================================")
print("Running Pure-Lua Test Suites via Headless Runner")
print("==================================================")

local totalFailed = 0

for _, suitePath in ipairs(suites) do
  print("\n>>> Executing suite: " .. suitePath)
  local ok, err = pcall(dofile, suitePath)
  if not ok then
    print("❌ Suite failed: " .. suitePath)
    print("   " .. tostring(err))
    totalFailed = totalFailed + 1
  else
    print("✓ Suite completed: " .. suitePath)
  end
end

print("\n==================================================")
if totalFailed > 0 then
  print(string.format("RUNNER RESULT: %d suite(s) failed!", totalFailed))
  os.exit(1)
else
  print(string.format("RUNNER RESULT: All %d suites passed successfully!", #suites))
  print("ALL LUA SUITES PASSED")
  os.exit(0)
end
