-- tests/harness/test_assert.lua
-- Minimal, zero-dependency assertion and test suite library for pure-Lua tests

local T = {
  passed = 0,
  failed = 0,
  currentSuite = ""
}

function T.suite(name)
  T.currentSuite = name
  print("\n--- Suite: " .. name .. " ---")
end

function T.test(name, fn)
  local ok, err = pcall(fn)
  if ok then
    T.passed = T.passed + 1
    print("  ✓ " .. name)
  else
    T.failed = T.failed + 1
    print("  ✗ " .. name)
    print("    Error: " .. tostring(err))
    error("Test failed: " .. name .. " (" .. tostring(err) .. ")")
  end
end

function T.assert(cond, msg)
  if not cond then
    error(msg or "assertion failed", 2)
  end
end

function T.assertEqual(actual, expected, msg)
  if actual ~= expected then
    error(string.format("%s: expected %s, got %s", msg or "assertEqual", tostring(expected), tostring(actual)), 2)
  end
end

function T.assertClose(actual, expected, tolerance, msg)
  local tol = tolerance or 1e-4
  if math.abs(actual - expected) > tol then
    error(string.format("%s: expected %f ± %f, got %f", msg or "assertClose", expected, tol, actual), 2)
  end
end

function T.summary()
  print(string.format("\nResult: %d passed, %d failed", T.passed, T.failed))
  if T.failed > 0 then
    os.exit(1)
  end
  print("PASSED")
end

return T
