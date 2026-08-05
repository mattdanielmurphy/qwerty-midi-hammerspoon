# Agent Log: Add Icons to Arp Notifications

Updated the Arpeggiator notifications for top row and bottom row to utilize the existing `stacked-rows-icon` HTML for clearer visual feedback.

- `src/ui_html.lua`:
  - Modified `.spotlight-title` CSS to use `display: flex`, `align-items: center`, and `gap: 6px` to align the inline HTML icon cleanly with the title text.
  - Updated `showSpotlight` to use `titleEl.innerHTML` instead of `titleEl.textContent` for the title to allow rendering inline HTML icons in spotlight notifications.
- `src/hud.lua` & `src/controls.lua`:
  - Updated the spotlight `title` strings for `TOP ROW ARP` and `BOTTOM ROW ARP` toggles to embed the corresponding `<div class="stacked-rows-icon ...">...</div>` HTML structure natively.

This makes it visually unambiguous whether the top row or bottom row arpeggiator is being toggled.
