# Handoff Report — Build Pipeline & Bundler Hardening (Milestone M1)

**Agent**: M1 Explorer 3 (Build Pipeline & Bundler Hardening)  
**Date**: 2026-10-11  
**Working Directory**: `/Users/matt/projects/qwerty-midi-hammerspoon/.agents/teamwork/teamwork_preview_explorer_m1_3`  
**Handoff Type**: Hard (Investigation & Architecture Complete)

---

## 1. Observation

1. **`bin/bundle_and_reload.sh` Lacks Pre-Reload Validation and Exit Status**:
   - Lines 9–21 of `bin/bundle_and_reload.sh`:
     ```bash
     echo "📦 Bundling Hammerspoon modules..."
     python3 "$PROJECT_DIR/bin/hs-bundler" --target qwerty-midi

     if [ $? -eq 0 ]; then
       echo "⚡ Reloading Hammerspoon..."
       if command -v hs >/dev/null 2>&1; then
         hs -c "hs.reload()" >/dev/null 2>&1 &
       else
         osascript -e 'tell application "Hammerspoon" to execute lua code "hs.reload()"' >/dev/null 2>&1 &
       fi
     else
       echo "❌ Bundling failed!"
     fi
     ```
   - No `luac -p qwerty_midi.lua` is run before reloading Hammerspoon.
   - If `hs-bundler` fails, the script printed `"❌ Bundling failed!"` but exited with code 0 (falling off the end without `exit 1`).
   - If a source file has syntax errors, `hs-bundler` concatenates strings without parsing, producing an invalid `qwerty_midi.lua` that Hammerspoon rejects at runtime.

2. **`bin/hs-bundler` Non-Deterministic Module Traversal and Massive Churn**:
   - Lines 91–92:
     ```python
     for root, _, files in os.walk(abs_src_dir):
         for file in files:
     ```
   - Line 142:
     ```python
     for mod_name, code in modules.items():
     ```
   - Running `python3 bin/hs-bundler --target qwerty-midi` on clean git HEAD produced a 9,813-line diff (`+6204 / -3609` lines) with 0 source modifications, purely due to arbitrary directory iteration order swapping module definitions (e.g. `hud` vs `init`).

3. **`sync_ui_html` Unsafe String Fencing**:
   - Line 61:
     ```python
     lua_module_content = f'local HTML_UI_CONTENT = [[\n{html_content}\n]]\n\nreturn HTML_UI_CONTENT\n'
     ```
   - Wrapping HTML in raw `[[ ... ]]` breaks if `html_content` contains `]]`.
   - In reproduction testing, embedding nested brackets `const check = arr[indices[0]];` caused `luac -p` to abort with:
     ```
     luac: tmp/test_fence_fail.lua:7: syntax error near 'check' (exit code 1)
     ```
   - Enclosing the same string in `[===[ ... ]===]` compiled with exit code 0.

4. **Missing `"test"` Script in `package.json`**:
   - `package.json` lacked a `"test"` script in its `"scripts"` block.
   - Executing `bun run test` exited with code 1 (`note: a package.json script 'test' was not found`).
   - Running `bun test` directly succeeded (77 pass, 0 fail, 665 expect calls in 180ms).

5. **Local Environment Binary Verification**:
   - `which luac` resolved to `/opt/homebrew/bin/luac` (Lua 5.4.8).
   - Running `luac -p qwerty_midi.lua` succeeded cleanly with exit code 0.

---

## 2. Logic Chain

1. **Pre-Reload Validation Safety**:
   - Based on (1) and (5), adding mandatory `luac -p qwerty_midi.lua` immediately after bundling guarantees that Hammerspoon is NEVER reloaded with a broken bundle.
   - Adding explicit exit 1 on both bundler failure and `luac` syntax validation failure ensures automated build pipelines and LaunchAgents detect regressions immediately.
   - Resolving `LUAC_BIN` with fallbacks (`command -v luac`, `/opt/homebrew/bin/luac`, `/usr/local/bin/luac`) prevents false failures when run under stripped `$PATH` environments.

2. **Bundle Determinism**:
   - Based on (2), sorting directory walks via `dirs.sort()` and `sorted(files)`, and sorting dictionary keys via `for mod_name in sorted(modules.keys()):`, produces completely deterministic output.
   - Because `__modules` functions are only executed upon `return __require("{entry_mod}")` at EOF, alphabetical definition order has zero impact on runtime logic.
   - Empirical proof: 5 consecutive bundler runs on the hardened bundler produced identical SHA-256 hashes (`cde450954efc78db6890eae27422edf3ed48bf8d7b88ed3ebcd27f794e7653b6`).

3. **Multiline Literal Resiliency**:
   - Based on (3), dynamic multiline fence scanning starting at level 3 (`[===[ ... ]===]`) ensures JavaScript array syntax (`arr[sub[0]]`) and CDATA in `index.html` cannot prematurely close the Lua string literal.
   - Lua strip-first-newline behavior is identical between `[[` and `[===[`.

4. **Workspace Test Ergonomics**:
   - Based on (4), adding `"test": "bun test"` into `package.json` allows both `bun test` and `bun run test` to function as first-class citizens.

---

## 3. Caveats

1. **Live Hammerspoon Running Instance**:
   - `bin/bundle_and_reload.sh` uses `hs -c "hs.reload()"` (or osascript fallback) to signal Hammerspoon. If Hammerspoon is not running on the macOS desktop, `hs -c` safely fails to connect, but the bundled file is still generated and validated with exit 0.
2. **Git Working Tree Baseline**:
   - In git HEAD, `qwerty_midi.lua` was previously committed with an unsorted module order. When the hardened bundler is applied, committing `qwerty_midi.lua` once will normalize the repository to sorted order; subsequent runs will yield 0 diff churn.

---

## 4. Conclusion

The build pipeline and bundler hardening is fully specified and validated.
- Patch file `.agents/teamwork/teamwork_preview_explorer_m1_3/build_pipeline_hardening.patch` has been generated and validated with `git apply --check` (exited 0).
- `bin/bundle_and_reload.sh` halts reload on any bundling error or syntax error (`luac -p`).
- `bin/hs-bundler` guarantees 100% deterministic builds and immune multiline HTML syncing.
- `package.json` provides first-class `"test": "bun test"`.
- All 77 Bun tests pass across 19 files.

---

## 5. Verification Method

To independently verify all findings and patches:

1. **Verify Patch Cleanliness**:
   ```bash
   git apply --check .agents/teamwork/teamwork_preview_explorer_m1_3/build_pipeline_hardening.patch
   ```
   Must exit with code 0.

2. **Verify Bundled Lua Syntax**:
   ```bash
   luac -p qwerty_midi.lua
   ```
   Must exit with code 0.

3. **Verify Existing Bun Tests**:
   ```bash
   bun test
   ```
   Must pass 77/77 tests across 19 test files.

4. **Verify Determinism**:
   Run the bundler multiple times and compare checksums:
   ```bash
   python3 bin/hs-bundler --target qwerty-midi
   shasum -a 256 qwerty_midi.lua
   ```
   The checksum must remain invariant.

5. **Verify `bin/bundle_and_reload.sh` Error Abort**:
   Introduce a syntax error to a temporary file, bundle, and confirm that `bin/bundle_and_reload.sh` prints:
   `❌ Lua syntax validation failed on qwerty_midi.lua! Aborting reload.`
   and exits with non-zero exit code.
