## Goal
Fix broken "click and drag" behavior on the BPM label and stop the BPM from resetting a split second after typing or dragging.

## User Feedback & Decisions
User reported:
1. When dragging, the BPM changes for a split second but resets.
2. When typing, the BPM changes for a split second and then resets.
3. Click and drag is broken (likely due to missing `e.preventDefault()`).

## Changes Made
1. **Restored `e.preventDefault()` on Mousedown:** Prevented text selection on the BPM label when dragging, which broke the mouse tracking.
2. **Replaced Click Event with Mouseup:** Since `e.preventDefault()` suppresses the native `click` event, we trigger the `enterBpmEdit` logic dynamically from `window.addEventListener('mouseup')` if `hasBpmDragged` is false.
3. **Fixed Dragging AppleScript Debounce:** Called `arpeggiator.setLogicBpmTarget(state.arpBpm)` during the `dragBpm` handler in Lua. This resets the 0.20s debounce timer continuously while dragging so the background polling logic won't interfere.
4. **Checked `state.bpmInputMode` in Poller:** Prevented `syncLogicBpm` from running its AppleScript poll while `bpmInputMode` is active.
5. **Fixed AppleScript UI Traversal in `setLogicBpmTarget`:** The AppleScript was hardcoded to `slider 1 of group 1 of group 1 of window 1` and also had a typo `set value of tempoSlider to maxBPM` instead of `AXIncrement` in the single steps block! This caused the BPM set script to either fail or jump wildly, which then caused the next `syncLogicBpm` poll to read the unchanged/old BPM and snap the HUD back to it. Updated the script to dynamically iterate through `ui elements of ctrlBar` to find the one whose `description of elem is "Tempo"`.

## What Worked
Click to edit and dragging to adjust BPM are both working reliably without bouncing back.

## What Didn't Work / Known Issues
None.

## Architecture Notes
Logic Pro's tempo slider cannot be directly assigned a value via accessibility; it must use `AXIncrement` and `AXDecrement`. When updating AppleScript logic, ensure dynamic traversal (`description is "Tempo"`) instead of relying on hardcoded element indices, as the user's Logic Pro control bar can be customized.
