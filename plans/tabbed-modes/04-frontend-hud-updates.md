# Step 4: Frontend HUD Updates

## Feature Overview
We need the web interface to visually represent the state of the "Tabbed Modes". When the user switches to `ArpAdvanced` mode, the keyboard keys should automatically change their labels to show the new mappings (e.g. `Rate 1/4`, `Dir UP`). Additionally, we need to show a visual indicator when the mode selector (backtick) is held.

## Objective
Update `hud.lua` to send the current mode and active layout maps, and update `index.html` (Javascript & CSS) to parse and display these modes dynamically.

## Instructions
1. **Update `src/hud.lua` Payload**:
   In `updateWebviewHud()`, ensure `state.currentMode` and `state.modeSelectHeld` are included in the payload. Also ensure that the `keys` map sent to the webview reflects the currently active control and note maps.
   ```lua
   local payload = {
     -- ... existing state ...
     currentMode = state.currentMode,
     modeSelectHeld = state.modeSelectHeld,
     keys = {},
   }
   
   -- Populate payload.keys based on the CURRENT active map
   local activeControlMap = config.getActiveControlKeysMap()
   for code, data in pairs(activeControlMap) do
     payload.keys[tostring(code)] = data
   end
   ```

2. **Update `src/web/index.html` (Javascript)**:
   In the `window.addEventListener('message', (event) => {` block:
   ```javascript
   if (data.modeSelectHeld !== undefined) {
     if (data.modeSelectHeld) {
       document.body.classList.add('mode-select-active');
     } else {
       document.body.classList.remove('mode-select-active');
     }
   }
   
   if (data.currentMode !== undefined) {
     const modeIndicator = document.getElementById('mode-indicator');
     if (modeIndicator) {
       modeIndicator.textContent = data.currentMode === "Home" ? "" : "MODE: " + data.currentMode;
     }
   }
   
   if (data.keys) {
     for (const [code, binding] of Object.entries(data.keys)) {
       const pad = document.getElementById('key-' + code);
       if (pad) {
         // Dynamically update labels based on the binding provided
         const halfTop = pad.querySelector('.key-half-top .key-note');
         if (halfTop) halfTop.textContent = binding.shiftName || binding.shiftAction || '';
         const halfBottom = pad.querySelector('.key-half-bottom .key-note');
         if (halfBottom) halfBottom.textContent = binding.name || binding.action || '';
       }
     }
   }
   ```

3. **Update `src/web/index.html` (CSS & HTML)**:
   Add an HTML element for the mode indicator (e.g., in the header):
   ```html
   <div id="mode-indicator" style="color: #ffcc00; font-weight: bold; margin-left: 10px;"></div>
   ```
   Add a CSS class for `mode-select-active` to visually dim or highlight the UI during selection:
   ```css
   body.mode-select-active #hud-container {
     opacity: 0.7;
     filter: blur(1px);
     transition: all 0.2s;
   }
   ```

## Verification
- Holding backtick dims the screen slightly (or shows some effect).
- Switching to `ArpAdvanced` changes the labels on the physical keys in the web view.
