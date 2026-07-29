# Step 02: Drag & Drop Key Customization Interface & Action Library Drawer

## Goal
Implement an interactive Edit Mode in the Web UI modal/view with a slide-out key/action Library Drawer, HTML5/Pointer Event drag-and-drop mechanics, key slot swap/reassign targets, and real-time visualization.

## Target Files
- `src/web/index.html`: Add Edit Mode toggle button, Action Library panel, drag handles/sources for action cards, drop target zones on HUD keyboard slots, and modal editor styling/JS controller logic.

## Requirements & Detailed Specifications
1. **Edit Mode UI & Modal Drawer**:
   - Add an "Edit Keys" button in the HUD settings header.
   - When toggled active, render a sleek slide-out "Action & Key Library" drawer featuring categories (e.g., Arp Controls, Scale/Root Controls, Octave/Transpose, MIDI/Volume, Unassigned/Notes).
2. **Drag and Drop Interface**:
   - Make items in the Library Drawer draggable (`draggable="true"` or HTML Pointer Event handlers).
   - Make keyboard slots on all 4 HUD rows (Number, Upper, Home, Lower) active drop targets.
   - Support dragging library items onto key slots to assign/reassign actions or note roles.
   - Support dragging between existing key slots to easily swap two key bindings.
3. **Visual Feedback & Controls**:
   - Display drop highlight glows, ghost drag elements, invalid drop warnings, and undo/reset buttons.
   - Show instant key assignment previews directly on HUD key tiles.
   - Provide "Save Layout", "Reset to Default", and "Cancel" action controls.

## Verification Criteria
- Test UI interaction via browser / dev server (`http://localhost:5173`) and inside Hammerspoon webview.
- Ensure dragging library items onto HUD keys accurately updates key bindings.
