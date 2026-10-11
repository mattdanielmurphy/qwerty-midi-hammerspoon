# Analysis: Build Pipeline & Bundler Hardening (Milestone M1)

**Subagent**: M1 Explorer 3 (Build Pipeline & Bundler Hardening)  
**Date**: 2026-10-11  
**Project**: qwerty-midi-hammerspoon  
**Working Directory**: `/Users/matt/projects/qwerty-midi-hammerspoon/.agents/teamwork/teamwork_preview_explorer_m1_3`

---

## 1. Executive Summary

This investigation analyzed the build, bundling, and reload pipeline of `qwerty-midi-hammerspoon`. We identified three critical points of fragility:
1. **Missing Pre-Reload Lua Syntax Validation in `bin/bundle_and_reload.sh`**: The reload script blindly dispatched `hs -c "hs.reload()"` without validating whether the newly bundled `qwerty_midi.lua` was syntactically valid Lua. If a syntax error exists in any source module, Hammerspoon crashes or rejects the module at runtime without failing the bundle script.
2. **Non-Deterministic Bundle Generation in `bin/hs-bundler`**: Directory traversal via `os.walk` and module dictionary iteration via `modules.items()` relied on non-deterministic filesystem order. An empirical test revealed that simply running the bundler on clean HEAD produced a **9,813-line diff** (`+6204 / -3609`) with zero functional changes, causing massive git churn and unstable artifacts.
3. **Unsafe Multiline String Fences in `sync_ui_html`**: `sync_ui_html` wrapped `src/web/index.html` inside raw Lua literal brackets `[[ ... ]]`. Any JavaScript array access with nested brackets (e.g. `arr[idx[0]]`), CDATA, or regex containing `]]` prematurely terminates the literal, throwing fatal syntax errors during Lua compilation.
4. **Missing `"test"` Script in `package.json`**: While `bun test` ran in the workspace, `bun run test` failed with `"note: a package.json script 'test' was not found"`.

All four issues have been resolved in design with validated, machine-applicable patches and proven deterministic outcomes.

---

## 2. Deep-Dive Investigation & Findings

### 2.1. `bin/bundle_and_reload.sh` — Missing Pre-Reload Validation

#### Root Cause
In `bin/bundle_and_reload.sh` lines 9–21:
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
**Defects Observed**:
- If `hs-bundler` completes with exit 0, Hammerspoon is reloaded immediately.
- There is **no syntax validation** (`luac -p`) before the reload.
- If a syntax error is introduced into any Lua file in `src/` or `packages/`, `hs-bundler` still concatenates the text successfully and exits with code 0! Hammerspoon then loads a broken file, throwing unhandled exceptions and dropping MIDI tap interception.
- If bundling fails (exit code != 0), the script printed `"❌ Bundling failed!"` but exited with code 0 because it fell through without an explicit `exit 1`!

#### Hardening Design
1. Check exit status immediately after `python3 "$PROJECT_DIR/bin/hs-bundler"`. If non-zero, exit with code 1.
2. Robust `luac` binary resolution: Check `command -v luac`, with fallbacks to `/opt/homebrew/bin/luac` (Apple Silicon Homebrew) and `/usr/local/bin/luac` (Intel Homebrew) so launchd and background daemons running under minimal `$PATH` do not fail false-negatively.
3. Mandatory validation gate: Run `"$LUAC_BIN" -p qwerty_midi.lua`.
4. If `luac` fails, print `❌ Lua syntax validation failed on qwerty_midi.lua! Aborting reload.` to `stderr` and abort immediately with `exit 1`. Hammerspoon reload is never triggered.
5. Only if syntax validation passes does the script trigger `hs.reload()` and exit 0.

---

### 2.2. `bin/hs-bundler` — Deterministic Module Ordering

#### Root Cause
In `bin/hs-bundler`:
```python
# Lines 91-92: Unsorted directory walk and file list
for root, _, files in os.walk(abs_src_dir):
    for file in files:
...
# Line 142: Iteration over unsorted dict keys
for mod_name, code in modules.items():
```
- `os.walk` yields directories and files in filesystem inode order, which is non-deterministic across macOS APFS/HFS+ file creations, OS versions, and git clones.
- Iterating `modules.items()` outputs module definitions into `bundle_parts` in traversal order.

#### Empirical Proof of Churn
When running `python3 bin/hs-bundler --target qwerty-midi` on clean git HEAD:
```
qwerty_midi.lua | 9813 +++++++++++++++++++++++++++++++++++--------------------
1 file changed, 6204 insertions(+), 3609 deletions(-)
```
In git HEAD, `__modules["hud"]` happened to be first. On the new run, `__modules["init"]` was placed first. The entire file was scrambled even though not a single line of source code had changed!

#### Hardening Design
1. In `os.walk(abs_src_dir)`:
   - Sort subdirectories in-place: `dirs.sort()`.
   - Sort files: `for file in sorted(files):`.
2. In `bundle_lua`:
   - Iterate over sorted module keys: `for mod_name in sorted(modules.keys()):`.
3. In Lua runtime, all module definitions are wrapper functions (`__modules[mod_name] = function() ... end`). Defining them in alphabetical order has zero runtime side effects because code execution only begins when `return __require("{entry_mod}")` executes at the end of the file.

#### Verification of Determinism
We tested running the hardened bundler across 5 consecutive executions. The resulting SHA-256 hash was bit-for-bit identical:
```
cde450954efc78db6890eae27422edf3ed48bf8d7b88ed3ebcd27f794e7653b6  qwerty_midi.lua
cde450954efc78db6890eae27422edf3ed48bf8d7b88ed3ebcd27f794e7653b6  qwerty_midi.lua
cde450954efc78db6890eae27422edf3ed48bf8d7b88ed3ebcd27f794e7653b6  qwerty_midi.lua
cde450954efc78db6890eae27422edf3ed48bf8d7b88ed3ebcd27f794e7653b6  qwerty_midi.lua
cde450954efc78db6890eae27422edf3ed48bf8d7b88ed3ebcd27f794e7653b6  qwerty_midi.lua
```

---

### 2.3. `bin/hs-bundler` — Safe Multiline Literal Fences in `sync_ui_html`

#### Root Cause
In `bin/hs-bundler` line 61:
```python
lua_module_content = f'local HTML_UI_CONTENT = [[\n{html_content}\n]]\n\nreturn HTML_UI_CONTENT\n'
```
In Lua, `[[ ... ]]` is a level-0 multiline string literal. Any occurrence of `]]` within `html_content` closes the literal.
In Web UI code (`src/web/index.html`), JavaScript frequently uses array indexing or nested expressions:
```javascript
const val = matrix[row[i]]; // contains ']]'
```
When enclosed in `[[ ... ]]`, `luac -p` fails immediately with:
`syntax error near '<next identifier>'` (exit code 1).

#### Hardening Design
Lua supports long brackets with `=` delimiters: `[` + $N$ `=` + `[` and `]` + $N$ `=` + `]`.
We implement a dynamic fence scanner:
```python
def sync_ui_html(web_index, ui_html_lua):
    if web_index and ui_html_lua and os.path.exists(web_index):
        with open(web_index, "r", encoding="utf-8") as f:
            html_content = f.read()

        # Find safe Lua multiline fence level (at least 3: [===[ ... ]===])
        eq_count = 3
        while f']{"=" * eq_count}]' in html_content:
            eq_count += 1
        fence = "=" * eq_count

        lua_module_content = f'local HTML_UI_CONTENT = [{fence}[\n{html_content}\n]{fence}]\n\nreturn HTML_UI_CONTENT\n'
        os.makedirs(os.path.dirname(os.path.abspath(ui_html_lua)), exist_ok=True)
        with open(ui_html_lua, "w", encoding="utf-8") as f:
            f.write(lua_module_content)
        print(f"🎨 Synced web UI into {ui_html_lua}")
```
This guarantees:
1. Base level is `[===[ ... ]===]`, safely escaping any standard `]]` or `]=]` or `]==]`.
2. If the HTML content ever includes `]===]`, it automatically increments the `=` count until collision-free.
3. Lua strip-first-newline semantics remain preserved.

---

### 2.4. `package.json` — First-Class `"test"` Script

#### Root Cause
Currently `package.json` contains:
```json
  "scripts": {
    "bundle": "bash bin/bundle_and_reload.sh",
    "dev:hud": "bun --cwd packages/surface-hud run dev",
    "dualsynth:gui": "cd packages/dualsynth/macos && swift run dualsynth-gui",
    "dualsynth:cli": "cd packages/dualsynth/macos && swift run dualsynth-cli",
    "dualsynth:app": "bash bin/build_app.sh"
  }
```
Running `bun run test` produced:
```
error: "/bin/test" exited with code 1
note: a package.json script "test" was not found
```

#### Hardening Design
Add `"test": "bun test"` as the first script in `package.json`.
Both `bun test` and `bun run test` execute the 77-test suite across 19 test files in <200ms.

---

## 3. Exact Line Diffs

### Diff 1: `bin/bundle_and_reload.sh`
```diff
--- a/bin/bundle_and_reload.sh
+++ b/bin/bundle_and_reload.sh
@@ -8,14 +8,30 @@ cd "$PROJECT_DIR" || exit 1
 
 echo "📦 Bundling Hammerspoon modules..."
 python3 "$PROJECT_DIR/bin/hs-bundler" --target qwerty-midi
+if [ $? -ne 0 ]; then
+  echo "❌ Bundling failed!" >&2
+  exit 1
+fi
 
-if [ $? -eq 0 ]; then
-  echo "⚡ Reloading Hammerspoon..."
-  if command -v hs >/dev/null 2>&1; then
-    hs -c "hs.reload()" >/dev/null 2>&1 &
-  else
-    osascript -e 'tell application "Hammerspoon" to execute lua code "hs.reload()"' >/dev/null 2>&1 &
+echo "🔍 Validating bundled Lua syntax..."
+LUAC_BIN="luac"
+if ! command -v "$LUAC_BIN" >/dev/null 2>&1; then
+  if [ -x "/opt/homebrew/bin/luac" ]; then
+    LUAC_BIN="/opt/homebrew/bin/luac"
+  elif [ -x "/usr/local/bin/luac" ]; then
+    LUAC_BIN="/usr/local/bin/luac"
   fi
+fi
+
+if ! "$LUAC_BIN" -p qwerty_midi.lua; then
+  echo "❌ Lua syntax validation failed on qwerty_midi.lua! Aborting reload." >&2
+  exit 1
+fi
+echo "✅ Syntax validation passed."
+
+echo "⚡ Reloading Hammerspoon..."
+if command -v hs >/dev/null 2>&1; then
+  hs -c "hs.reload()" >/dev/null 2>&1 &
 else
-  echo "❌ Bundling failed!"
+  osascript -e 'tell application "Hammerspoon" to execute lua code "hs.reload()"' >/dev/null 2>&1 &
 fi
```

### Diff 2: `bin/hs-bundler`
```diff
--- a/bin/hs-bundler
+++ b/bin/hs-bundler
@@ -58,7 +58,14 @@ def sync_ui_html(web_index, ui_html_lua):
     if web_index and ui_html_lua and os.path.exists(web_index):
         with open(web_index, "r", encoding="utf-8") as f:
             html_content = f.read()
-        lua_module_content = f'local HTML_UI_CONTENT = [[\n{html_content}\n]]\n\nreturn HTML_UI_CONTENT\n'
+
+        # Find safe Lua multiline fence level (at least 3: [===[ ... ]===])
+        eq_count = 3
+        while f']{"=" * eq_count}]' in html_content:
+            eq_count += 1
+        fence = "=" * eq_count
+
+        lua_module_content = f'local HTML_UI_CONTENT = [{fence}[\n{html_content}\n]{fence}]\n\nreturn HTML_UI_CONTENT\n'
         os.makedirs(os.path.dirname(os.path.abspath(ui_html_lua)), exist_ok=True)
         with open(ui_html_lua, "w", encoding="utf-8") as f:
             f.write(lua_module_content)
@@ -88,8 +95,9 @@ def bundle_lua(src_dirs, entry_file, output_file, web_index=None, ui_lua=None):
             if os.path.exists(candidate_web):
                 sync_ui_html(candidate_web, candidate_ui)
 
-        for root, _, files in os.walk(abs_src_dir):
-            for file in files:
+        for root, dirs, files in os.walk(abs_src_dir):
+            dirs.sort()
+            for file in sorted(files):
                 if file.endswith(".lua"):
                     full_path = os.path.join(root, file)
                     rel_path = os.path.relpath(full_path, abs_src_dir)
@@ -139,7 +147,9 @@ def bundle_lua(src_dirs, entry_file, output_file, web_index=None, ui_lua=None):
         "end\n"
     ]
 
-    for mod_name, code in modules.items():
+    for mod_name in sorted(modules.keys()):
+        code = modules[mod_name]
+
         def req_replacer(match):
             req_name = match.group(1)
             if req_name in modules:
```

### Diff 3: `package.json`
```diff
--- a/package.json
+++ b/package.json
@@ -7,6 +7,7 @@
     "packages/*"
   ],
   "scripts": {
+    "test": "bun test",
     "bundle": "bash bin/bundle_and_reload.sh",
     "dev:hud": "bun --cwd packages/surface-hud run dev",
     "dualsynth:gui": "cd packages/dualsynth/macos && swift run dualsynth-gui",
```

---

## 4. Verification & Validation Summary

| Target / Command | Input Condition | Expected Output | Actual Observed Result |
|---|---|---|---|
| `python3 bin/hs-bundler --target qwerty-midi` | Multiple repeated runs | Identical SHA-256 hash | `cde450...` (100% deterministic across 5 runs) |
| `luac -p qwerty_midi.lua` | Generated bundle | Exit code 0, no syntax errors | Passed with exit code 0 |
| `luac -p` on HTML containing `arr[idx[0]]` | Level-0 `[[ ... ]]` fence | Exit code 1 (syntax error) | Failed: `syntax error near 'check'` |
| `luac -p` on HTML containing `arr[idx[0]]` | Level-3 `[===[ ... ]===]` fence | Exit code 0 (valid Lua string) | Passed cleanly |
| `bin/bundle_and_reload.sh` | Simulated syntax error in bundle | Reload aborted, exit 1 | Aborted immediately with exit code 1 |
| `bin/bundle_and_reload.sh` | Valid bundle | Reload triggered, exit 0 | Passed with exit code 0 |
| `bun test` | Entire workspace | 100% test pass | 77 pass, 0 fail (180ms) |
| `bun run test` | `package.json` with `"test": "bun test"` | Executes test runner | Runs and passes identically |

---

## 5. Machine-Applicable Patch Artifact

The complete, unified diff is written in:
`/.agents/teamwork/teamwork_preview_explorer_m1_3/build_pipeline_hardening.patch`
Applying it via:
```bash
git apply .agents/teamwork/teamwork_preview_explorer_m1_3/build_pipeline_hardening.patch
```
applies cleanly across `bin/bundle_and_reload.sh`, `bin/hs-bundler`, and `package.json`.
