# DualSynth: Native macOS Application Bundle & /Applications Auto-Installer

**Date**: 2026-09-08 18:50  
**Author**: Antigravity Orchestrator  
**Components Modified / Created**:
- `packages/dualsynth/macos/Sources/dualsynth-gui/main.swift`
- `packages/dualsynth/macos/Resources/Info.plist`
- `packages/dualsynth/macos/Resources/AppIcon.icns`
- `scripts/generate_app_icon.py`
- `bin/build_app.sh`
- `package.json`

---

## 1. Features & Changes

1. **Standard Window Layering (`window.level = .normal`)**:
   - Removed `.floating` window level from `main.swift`. The window now runs at standard `.normal` level so it behaves like any regular macOS application and does NOT hover or stay on top of other windows.

2. **Native macOS App Integration (`NSApp.setActivationPolicy(.regular)`)**:
   - Set regular activation policy so DualSynth shows up properly in the macOS Dock and Cmd+Tab app switcher.
   - Built a native macOS main menu bar with standard items and hotkeys:
     - `DualSynth`: About DualSynth, Hide (`⌘H`), Hide Others (`⌥⌘H`), Show All, Quit (`⌘Q`).
     - `Window`: Close (`⌘W`), Minimize (`⌘M`), Zoom, Bring All to Front.

3. **High-Resolution Custom App Icon**:
   - Created `scripts/generate_app_icon.py` generating a full multi-resolution `AppIcon.iconset` (16x16 up to 1024x1024 Retina) compiled to `AppIcon.icns` via `iconutil`.
   - Features a dark metallic squircle canvas with glowing cyan DualSense contours, accent thumbsticks, colorful face buttons, and an audio waveform gradient.

4. **Automated `/Applications` Packaging & Installer (`bin/build_app.sh`)**:
   - Created `bin/build_app.sh` and wired it to `bun run dualsynth:app`.
   - Workflow:
     1. Compiles optimized release binary (`swift build -c release`).
     2. Assembles `./tmp/DualSynth.app` bundle containing binary, `Info.plist`, `PkgInfo`, and `AppIcon.icns`.
     3. Ad-hoc codesigns the bundle with `codesign --force --deep --sign -`.
     4. Safely replaces `/Applications/DualSynth.app`.
     5. Automatically launches `/Applications/DualSynth.app` via `open`.

---

## 2. Verification
- `bin/build_app.sh` succeeded in 12.56s.
- Verified `/Applications/DualSynth.app` bundle structure and codesignature.
- Running process confirmed: `PID 45630` (`/Applications/DualSynth.app/Contents/MacOS/DualSynth`).
- Tested window level: does not float over other apps.
