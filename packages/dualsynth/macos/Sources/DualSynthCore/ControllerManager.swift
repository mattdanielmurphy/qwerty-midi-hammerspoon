import Foundation
import GameController
import CoreHaptics

public enum ControlLayer: String, CaseIterable {
    case base = "Base Play"
    case harmony = "Harmony (L1)"
    case arp = "Arp & Rhythm (R1)"
    case matrix = "Synth & FX (L1+R1)"
}

public enum ChordType: String, CaseIterable {
    case triad = "Triad"
    case seventh = "7th"
    case sus4 = "Sus4"
    case add9 = "Add9"
}

public enum ChordInversion: String, CaseIterable {
    case root = "Root"
    case first = "1st Inv"
    case second = "2nd Inv"
    case drop2 = "Drop-2"
}

public enum ArpPattern: String, CaseIterable {
    case up = "Up"
    case down = "Down"
    case upDown = "Up/Down"
    case random = "Random"
}

public enum ArpRate: String, CaseIterable {
    case quarter = "1/4"
    case eighth = "1/8"
    case sixteenth = "1/16"
    case thirtySecond = "1/32"

    public var multiplier: Double {
        switch self {
        case .quarter: return 1.0
        case .eighth: return 0.5
        case .sixteenth: return 0.25
        case .thirtySecond: return 0.125
        }
    }
}

public struct ControllerTelemetry {
    public var leftStickX: Float = 0.0
    public var leftStickY: Float = 0.0
    public var rightStickX: Float = 0.0
    public var rightStickY: Float = 0.0

    public var leftTrigger: Float = 0.0
    public var rightTrigger: Float = 0.0

    public var dpadUp: Bool = false
    public var dpadDown: Bool = false
    public var dpadLeft: Bool = false
    public var dpadRight: Bool = false

    public var cross: Bool = false
    public var square: Bool = false
    public var circle: Bool = false
    public var triangle: Bool = false

    public var l1: Bool = false
    public var r1: Bool = false
    public var l3: Bool = false
    public var r3: Bool = false

    public var options: Bool = false
    public var create: Bool = false
    public var home: Bool = false
    public var micMuted: Bool = false
    public var touchpad: Bool = false

    // Motion & Haptics
    public var pitchAngle: Float = 0.0
    public var modWheel: UInt8 = 0
    public var hapticIntensity: Float = 0.0

    // Musical Engine States
    public var chordMode: Bool = true
    public var chordType: ChordType = .triad
    public var chordInversion: ChordInversion = .root
    public var scaleName: String = "Major"
    public var latchMode: Bool = true
    public var isArpActive: Bool = false
    public var arpPattern: ArpPattern = .up
    public var arpRate: ArpRate = .eighth
    public var bpm: Double = 120.0
    public var currentArpStep: Int = 0
    public var activeChordNotes: [UInt8] = []
    public var activeChordName: String = "None"
    public var isHoldingChord: Bool = false

    public init() {}
}

public protocol DualSynthDelegate: AnyObject {
    func controllerDidConnect(_ name: String, isDualSense: Bool)
    func controllerDidDisconnect()
    func layerDidChange(_ layer: ControlLayer)
    func notesTriggered(pitches: [UInt8], velocity: UInt8, name: String)
    func notesReleased(pitches: [UInt8], name: String)
    func continuousParamChanged(cc: UInt8, value: UInt8, name: String)
    func telemetryUpdated(_ telemetry: ControllerTelemetry)
    func panicTriggered()
}

public final class ControllerManager: ObservableObject {
    public weak var delegate: DualSynthDelegate?
    public private(set) var activeController: GCController?

    @Published public var isConnected: Bool = false
    @Published public var controllerName: String = "Searching for controller..."
    @Published public var isDualSense: Bool = false
    @Published public var currentLayer: ControlLayer = .base
    @Published public var telemetry = ControllerTelemetry()

    @Published public var rootKey: UInt8 = 60 // C4 default
    @Published public var octaveShift: Int = 0
    @Published public var lastEventDescription: String = "Ready"

    // Musical Engine State
    @Published public var chordMode: Bool = true
    @Published public var chordType: ChordType = .triad
    @Published public var chordInversion: ChordInversion = .root
    @Published public var scaleName: String = "Major"
    @Published public var latchMode: Bool = true
    @Published public var isArpActive: Bool = false
    @Published public var arpPattern: ArpPattern = .up
    @Published public var arpRate: ArpRate = .eighth
    @Published public var bpm: Double = 120.0

    // Held-Chord Alteration & Morphing State
    @Published public var heldFaceButtonIndex: Int? = nil
    private var heldChordTemporaryTranspose: Int = 0
    private var heldChordAddSubBass: Bool = false
    private var heldChordAddHighOctave: Bool = false

    // Stick gesture tracking
    private var l3PressTime: Date?
    private var l3Moved: Bool = false
    private var r3PressTime: Date?
    private var r3Moved: Bool = false

    // Internal active note sets
    private var latchedPitches: [UInt8] = []
    private var currentlySoundingPitches: [UInt8] = []
    private var lastFaceDegree: Int = 0

    // Arpeggiator timer
    private var arpTimer: DispatchSourceTimer?
    private var arpStepIndex: Int = 0
    private var lastArpPitch: UInt8? = nil

    // Modifier states
    public var isL1Held: Bool = false
    public var isR1Held: Bool = false

    // CoreHaptics
    private var hapticEngine: CHHapticEngine?
    private var lastHapticPulseTime: Date = Date.distantPast

    public init() {
        GCController.shouldMonitorBackgroundEvents = true

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleControllerDidConnect),
            name: .GCControllerDidConnect,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleControllerDidDisconnect),
            name: .GCControllerDidDisconnect,
            object: nil
        )

        GCController.startWirelessControllerDiscovery { }

        for controller in GCController.controllers() {
            attachController(controller)
            break
        }

        syncTelemetryEngineState()
    }

    deinit {
        stopArpeggiator()
        hapticEngine?.stop()
    }

    private func syncTelemetryEngineState() {
        telemetry.chordMode = chordMode
        telemetry.chordType = chordType
        telemetry.chordInversion = chordInversion
        telemetry.scaleName = scaleName
        telemetry.latchMode = latchMode
        telemetry.isArpActive = isArpActive
        telemetry.arpPattern = arpPattern
        telemetry.arpRate = arpRate
        telemetry.bpm = bpm
    }

    @objc private func handleControllerDidConnect(notification: Notification) {
        guard let controller = notification.object as? GCController else { return }
        attachController(controller)
    }

    @objc private func handleControllerDidDisconnect(notification: Notification) {
        guard let controller = notification.object as? GCController,
              controller == activeController else { return }
        hapticEngine?.stop()
        self.activeController = nil
        self.isConnected = false
        self.controllerName = "Disconnected"
        delegate?.controllerDidDisconnect()
    }

    private func attachController(_ controller: GCController) {
        self.activeController = controller
        controller.handlerQueue = .main

        let isDS = controller.extendedGamepad is GCDualSenseGamepad
        let name = controller.vendorName ?? (isDS ? "Sony PS5 DualSense" : "Wireless Gamepad")

        self.isConnected = true
        self.controllerName = name
        self.isDualSense = isDS

        setupControllerBindings(controller)
        setupMotionSensors(controller)
        setupAdaptiveTriggers(controller)
        setupHaptics(controller)

        delegate?.controllerDidConnect(name, isDualSense: isDS)
        setLightbarColor(red: 0.06, green: 0.72, blue: 0.51) // Green Base

        // Send default Expression (127) so instrument makes sound out of the box!
        delegate?.continuousParamChanged(cc: 11, value: 127, name: "Expression Default")
    }

    private func setupControllerBindings(_ controller: GCController) {
        guard let gamepad = controller.extendedGamepad else { return }

        // 1. Shoulder Modifiers (L1 / R1)
        gamepad.leftShoulder.valueChangedHandler = { [weak self] (_, _, pressed) in
            guard let self = self else { return }
            self.isL1Held = pressed
            self.telemetry.l1 = pressed
            self.evaluateLayerState()
            self.notifyTelemetry()
        }

        gamepad.rightShoulder.valueChangedHandler = { [weak self] (_, _, pressed) in
            guard let self = self else { return }
            self.isR1Held = pressed
            self.telemetry.r1 = pressed
            self.evaluateLayerState()
            self.notifyTelemetry()
        }

        // 2. Face Buttons
        gamepad.buttonA.valueChangedHandler = { [weak self] (_, _, pressed) in
            guard let self = self else { return }
            self.telemetry.cross = pressed
            self.handleFaceAction(buttonIndex: 0, pressed: pressed)
        }
        gamepad.buttonX.valueChangedHandler = { [weak self] (_, _, pressed) in
            guard let self = self else { return }
            self.telemetry.square = pressed
            self.handleFaceAction(buttonIndex: 1, pressed: pressed)
        }
        gamepad.buttonB.valueChangedHandler = { [weak self] (_, _, pressed) in
            guard let self = self else { return }
            self.telemetry.circle = pressed
            self.handleFaceAction(buttonIndex: 2, pressed: pressed)
        }
        gamepad.buttonY.valueChangedHandler = { [weak self] (_, _, pressed) in
            guard let self = self else { return }
            self.telemetry.triangle = pressed
            self.handleFaceAction(buttonIndex: 3, pressed: pressed)
        }

        // 3. D-Pad Actions
        gamepad.dpad.up.valueChangedHandler = { [weak self] (_, _, pressed) in
            guard let self = self else { return }
            self.telemetry.dpadUp = pressed
            if pressed { self.handleDpadAction(direction: .up) }
            self.notifyTelemetry()
        }
        gamepad.dpad.down.valueChangedHandler = { [weak self] (_, _, pressed) in
            guard let self = self else { return }
            self.telemetry.dpadDown = pressed
            if pressed { self.handleDpadAction(direction: .down) }
            self.notifyTelemetry()
        }
        gamepad.dpad.left.valueChangedHandler = { [weak self] (_, _, pressed) in
            guard let self = self else { return }
            self.telemetry.dpadLeft = pressed
            if pressed { self.handleDpadAction(direction: .left) }
            self.notifyTelemetry()
        }
        gamepad.dpad.right.valueChangedHandler = { [weak self] (_, _, pressed) in
            guard let self = self else { return }
            self.telemetry.dpadRight = pressed
            if pressed { self.handleDpadAction(direction: .right) }
            self.notifyTelemetry()
        }

        // 4. Triggers (L2 / R2)
        gamepad.leftTrigger.valueChangedHandler = { [weak self] (_, value, _) in
            guard let self = self else { return }
            self.telemetry.leftTrigger = value
            let ccVal = UInt8(value * 127)
            self.delegate?.continuousParamChanged(cc: 74, value: ccVal, name: "L2 Brightness (CC74)")
            self.delegate?.continuousParamChanged(cc: 2, value: ccVal, name: "L2 Filter/Breath (CC2)")
            self.notifyTelemetry()
        }

        gamepad.rightTrigger.valueChangedHandler = { [weak self] (_, value, _) in
            guard let self = self else { return }
            self.telemetry.rightTrigger = value
            let exprVal: UInt8 = UInt8(90 + value * 37) // 90 to 127, never 0!
            let resVal = UInt8(value * 127)
            self.delegate?.continuousParamChanged(cc: 11, value: exprVal, name: "R2 Expr (CC11)")
            if value > 0.05 {
                self.delegate?.continuousParamChanged(cc: 71, value: resVal, name: "R2 Res (CC71)")
            }
            self.notifyTelemetry()
        }

        // 5. Left Thumbstick
        gamepad.leftThumbstick.valueChangedHandler = { [weak self] (_, xVal, yVal) in
            guard let self = self else { return }
            self.telemetry.leftStickX = xVal
            self.telemetry.leftStickY = yVal

            if self.telemetry.l3 {
                if abs(xVal) > 0.6 {
                    self.l3Moved = true
                    if xVal > 0 {
                        self.rootKey = min(84, self.rootKey + 1)
                        self.lastEventDescription = "L3+Stick: Transpose +1 (\(self.noteNameForPitch(self.rootKey)))"
                    } else {
                        self.rootKey = max(36, self.rootKey - 1)
                        self.lastEventDescription = "L3+Stick: Transpose -1 (\(self.noteNameForPitch(self.rootKey)))"
                    }
                    self.revoiceActiveChord()
                }
            } else {
                if abs(yVal) > 0.05 {
                    let modVal = UInt8(max(0, yVal) * 127)
                    self.delegate?.continuousParamChanged(cc: 1, value: modVal, name: "Left Stick Y (Mod)")
                }
            }
            self.notifyTelemetry()
        }

        // 6. Right Thumbstick
        gamepad.rightThumbstick.valueChangedHandler = { [weak self] (_, xVal, yVal) in
            guard let self = self else { return }
            self.telemetry.rightStickX = xVal
            self.telemetry.rightStickY = yVal

            if self.telemetry.r3 {
                if abs(xVal) > 0.6 {
                    self.r3Moved = true
                    if xVal > 0 {
                        self.bpm = min(240.0, self.bpm + 5.0)
                    } else {
                        self.bpm = max(40.0, self.bpm - 5.0)
                    }
                    self.telemetry.bpm = self.bpm
                    self.lastEventDescription = String(format: "R3+Stick: BPM %.0f", self.bpm)
                    if self.isArpActive { self.restartArpeggiator() }
                }
            } else {
                if abs(xVal) > 0.08 {
                    let panVal = UInt8(clamp((xVal + 1.0) / 2.0 * 127, min: 0, max: 127))
                    self.delegate?.continuousParamChanged(cc: 10, value: panVal, name: "Right Stick X (Pan)")
                }
                if abs(yVal) > 0.08 {
                    let resVal = UInt8(max(0, yVal) * 127)
                    self.delegate?.continuousParamChanged(cc: 71, value: resVal, name: "Right Stick Y (Res)")
                }
            }
            self.notifyTelemetry()
        }

        // 7. Stick Clicks (L3 & R3)
        if let l3Btn = gamepad.leftThumbstickButton {
            l3Btn.valueChangedHandler = { [weak self] (_, _, pressed) in
                guard let self = self else { return }
                self.telemetry.l3 = pressed
                if pressed {
                    self.l3PressTime = Date()
                    self.l3Moved = false
                } else {
                    if !self.l3Moved {
                        let duration = Date().timeIntervalSince(self.l3PressTime ?? Date())
                        if duration < 0.35 {
                            self.toggleChordMode()
                        } else {
                            self.delegate?.continuousParamChanged(cc: 64, value: 0, name: "Sustain Off")
                        }
                    }
                    self.l3PressTime = nil
                }
                self.notifyTelemetry()
            }
        }

        if let r3Btn = gamepad.rightThumbstickButton {
            r3Btn.valueChangedHandler = { [weak self] (_, _, pressed) in
                guard let self = self else { return }
                self.telemetry.r3 = pressed
                if pressed {
                    self.r3PressTime = Date()
                    self.r3Moved = false
                } else {
                    if !self.r3Moved {
                        let duration = Date().timeIntervalSince(self.r3PressTime ?? Date())
                        if duration < 0.35 {
                            self.toggleArpeggiator()
                        }
                    }
                    self.r3PressTime = nil
                }
                self.notifyTelemetry()
            }
        }

        // 8. Create Button (|||) -> Cycles Chord Types
        if let createBtn = gamepad.buttonOptions {
            createBtn.valueChangedHandler = { [weak self] (_, _, pressed) in
                guard let self = self else { return }
                self.telemetry.create = pressed
                if pressed {
                    self.cycleChordType()
                }
                self.notifyTelemetry()
            }
        }

        // 9. Options Button (☰) -> Cycles Scale
        gamepad.buttonMenu.valueChangedHandler = { [weak self] (_, _, pressed) in
            guard let self = self else { return }
            self.telemetry.options = pressed
            if pressed {
                self.cycleScale()
            }
            self.notifyTelemetry()
        }

        // 10. PS Home Button -> Toggle Latch Mode
        if let home = gamepad.buttonHome {
            home.valueChangedHandler = { [weak self] (_, _, pressed) in
                guard let self = self else { return }
                self.telemetry.home = pressed
                if pressed {
                    self.toggleLatchMode()
                }
                self.notifyTelemetry()
            }
        }

        // 11. DualSense Touchpad Button -> Panic / Mute
        if let ds = gamepad as? GCDualSenseGamepad {
            ds.touchpadButton.valueChangedHandler = { [weak self] (_, _, pressed) in
                guard let self = self else { return }
                self.telemetry.touchpad = pressed
                if pressed {
                    self.triggerPanic()
                }
                self.notifyTelemetry()
            }
        }
    }

    // MARK: - Motion Sensors (Corrected Tilt Direction: Flat = 0, Ceiling = 127)
    private func setupMotionSensors(_ controller: GCController) {
        guard let motion = controller.motion else { return }
        motion.sensorsActive = true

        motion.valueChangedHandler = { [weak self] m in
            guard let self = self else { return }
            let ay = Double(m.acceleration.y)
            let az = Double(m.acceleration.z)

            // Resting flat on table: ay ≈ 0.174, az ≈ -0.985
            // Tilting back (top/jack to ceiling): ay decreases from +0.174 down to -1.0
            // delta = restAy - ay goes from 0.0 (flat) up to ~1.17 (ceiling)
            let restAy = 0.174
            let delta = restAy - ay
            let angleRad = atan2(delta, max(0.01, -az))
            let tiltDeg = Float(max(0.0, min(80.0, angleRad * 180.0 / .pi)))

            let normalized = min(1.0, max(0.0, tiltDeg / 75.0))
            let mwVal = UInt8(normalized * 127.0)

            if mwVal != self.telemetry.modWheel || abs(tiltDeg - self.telemetry.pitchAngle) > 0.5 {
                self.telemetry.pitchAngle = tiltDeg
                self.telemetry.modWheel = mwVal
                self.delegate?.continuousParamChanged(cc: 1, value: mwVal, name: "Gyro Mod Wheel (CC1)")

                // Vibration scaling:
                // MW = 0 -> 0.0
                // MW = 50 -> 0.20 (20%)
                // MW = 127 -> 0.40 (40%)
                let intensity: Float
                if mwVal == 0 {
                    intensity = 0.0
                } else if mwVal <= 50 {
                    intensity = (Float(mwVal) / 50.0) * 0.20
                } else {
                    intensity = 0.20 + ((Float(mwVal) - 50.0) / 77.0) * 0.20
                }

                self.telemetry.hapticIntensity = intensity
                self.triggerHapticPulse(intensity: intensity)
                self.notifyTelemetry()
            }
        }
    }

    // MARK: - CoreHaptics Engine (Fixed: Grain Pulses with No -4810 Errors)
    private func setupHaptics(_ controller: GCController) {
        guard let haptics = controller.haptics else { return }
        do {
            hapticEngine = haptics.createEngine(withLocality: .default)
            try hapticEngine?.start()
            hapticEngine?.resetHandler = { [weak self] in
                try? self?.hapticEngine?.start()
            }
        } catch {
            print("⚠️ CoreHaptics init error: \(error)")
        }
    }

    private func triggerHapticPulse(intensity: Float) {
        guard intensity > 0.02, let engine = hapticEngine else { return }

        // Throttle pulses to every 0.12 seconds to prevent player flooding
        let now = Date()
        guard now.timeIntervalSince(lastHapticPulseTime) >= 0.12 else { return }
        lastHapticPulseTime = now

        let intParam = CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity)
        let shParam = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
        let event = CHHapticEvent(eventType: .hapticContinuous, parameters: [intParam, shParam], relativeTime: 0, duration: 0.12)

        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            // Engine might need restart
            try? engine.start()
        }
    }

    // MARK: - Adaptive Triggers
    private func setupAdaptiveTriggers(_ controller: GCController) {
        guard let ds = controller.extendedGamepad as? GCDualSenseGamepad else { return }
        ds.leftTrigger.setModeSlopeFeedback(startPosition: 0.05, endPosition: 0.95, startStrength: 0.15, endStrength: 0.8)
        ds.rightTrigger.setModeWeaponWithStartPosition(0.1, endPosition: 0.8, resistiveStrength: 0.6)
    }

    // MARK: - Shift Actions & Held-Chord Morphing
    private func handleFaceAction(buttonIndex: Int, pressed: Bool) {
        if isL1Held {
            // L1 Harmony Layer: Face buttons select Inversion
            if pressed {
                let inversions: [ChordInversion] = [.root, .first, .second, .drop2]
                chordInversion = inversions[buttonIndex % inversions.count]
                telemetry.chordInversion = chordInversion
                lastEventDescription = "Voicing: \(chordInversion.rawValue)"
                revoiceActiveChord()
            }
        } else if isR1Held {
            // R1 Arp Layer: Face buttons select Arp Pattern
            if pressed {
                let patterns: [ArpPattern] = [.up, .down, .upDown, .random]
                arpPattern = patterns[buttonIndex % patterns.count]
                telemetry.arpPattern = arpPattern
                lastEventDescription = "Arp Pattern: \(arpPattern.rawValue)"
                if isArpActive { restartArpeggiator() }
            }
        } else {
            // Base Layer: Press and Hold Morph Mode
            let degreeMap = [0, 1, 3, 5]
            let degree = degreeMap[buttonIndex % degreeMap.count]

            if pressed {
                if heldFaceButtonIndex == nil {
                    // First button pressed: enter held chord state!
                    heldFaceButtonIndex = buttonIndex
                    heldChordTemporaryTranspose = 0
                    heldChordAddSubBass = false
                    heldChordAddHighOctave = false
                    telemetry.isHoldingChord = true
                    handleFaceButton(degreeIndex: degree, buttonName: faceButtonName(buttonIndex), pressed: true)
                } else if heldFaceButtonIndex != buttonIndex {
                    // SECOND button pressed while holding first: add extension!
                    heldChordAddHighOctave.toggle()
                    revoiceActiveChord()
                    lastEventDescription = "Chord Extension Added!"
                }
            } else {
                if heldFaceButtonIndex == buttonIndex {
                    // Released the primary held chord button!
                    heldFaceButtonIndex = nil
                    heldChordTemporaryTranspose = 0
                    heldChordAddSubBass = false
                    heldChordAddHighOctave = false
                    telemetry.isHoldingChord = false

                    if !latchMode {
                        releaseCurrentlySoundingNotes()
                        lastEventDescription = "Released: \(faceButtonName(buttonIndex))"
                    } else {
                        // Re-voice back to default un-morphed chord in latch mode
                        revoiceActiveChord()
                    }
                }
            }
        }
        notifyTelemetry()
    }

    private func handleDpadAction(direction: DpadDir) {
        if let _ = heldFaceButtonIndex {
            // HELD-CHORD MORPH MODE: Alter, add on to, or transpose the active chord!
            switch direction {
            case .up:
                heldChordAddHighOctave.toggle()
                lastEventDescription = heldChordAddHighOctave ? "Morph: +High Octave" : "Morph: High Octave Off"
            case .down:
                heldChordAddSubBass.toggle()
                lastEventDescription = heldChordAddSubBass ? "Morph: +Sub-Bass" : "Morph: Sub-Bass Off"
            case .left:
                heldChordTemporaryTranspose -= 1
                lastEventDescription = "Morph: Transpose \(heldChordTemporaryTranspose)"
            case .right:
                heldChordTemporaryTranspose += 1
                lastEventDescription = "Morph: Transpose +\(heldChordTemporaryTranspose)"
            }
            revoiceActiveChord()
            return
        }

        if isL1Held {
            // L1 Layer: D-Pad changes Scale
            switch direction {
            case .up: scaleName = "Major"
            case .down: scaleName = "Minor"
            case .left: scaleName = "Dorian"
            case .right: scaleName = "Mixolydian"
            }
            telemetry.scaleName = scaleName
            lastEventDescription = "Scale: \(scaleName)"
            revoiceActiveChord()
        } else if isR1Held {
            // R1 Layer: D-Pad changes Arp Rate & BPM
            switch direction {
            case .up: cycleArpRate(forward: true)
            case .down: cycleArpRate(forward: false)
            case .left:
                bpm = max(40.0, bpm - 5.0)
                telemetry.bpm = bpm
                lastEventDescription = String(format: "BPM: %.0f", bpm)
                if isArpActive { restartArpeggiator() }
            case .right:
                bpm = min(240.0, bpm + 5.0)
                telemetry.bpm = bpm
                lastEventDescription = String(format: "BPM: %.0f", bpm)
                if isArpActive { restartArpeggiator() }
            }
        } else {
            // Base Layer: D-Pad changes Octave & Root
            switch direction {
            case .up:
                octaveShift = min(36, octaveShift + 12)
                lastEventDescription = "Octave: \(octaveShift / 12 > 0 ? "+" : "")\(octaveShift / 12)"
                revoiceActiveChord()
            case .down:
                octaveShift = max(-36, octaveShift - 12)
                lastEventDescription = "Octave: \(octaveShift / 12 > 0 ? "+" : "")\(octaveShift / 12)"
                revoiceActiveChord()
            case .left:
                rootKey = max(36, rootKey - 1)
                lastEventDescription = "Root: \(noteNameForPitch(rootKey))"
                revoiceActiveChord()
            case .right:
                rootKey = min(84, rootKey + 1)
                lastEventDescription = "Root: \(noteNameForPitch(rootKey))"
                revoiceActiveChord()
            }
        }
    }

    private enum DpadDir { case up, down, left, right }

    private func faceButtonName(_ index: Int) -> String {
        switch index {
        case 0: return "✕ Cross (I)"
        case 1: return "□ Square (II)"
        case 2: return "○ Circle (IV)"
        case 3: return "△ Triangle (VI)"
        default: return "Face Button"
        }
    }

    public func toggleChordMode() {
        chordMode.toggle()
        telemetry.chordMode = chordMode
        lastEventDescription = "Chord Mode: \(chordMode ? "ON" : "OFF")"
        revoiceActiveChord()
        notifyTelemetry()
    }

    public func toggleLatchMode() {
        latchMode.toggle()
        telemetry.latchMode = latchMode
        lastEventDescription = "Latch Mode: \(latchMode ? "ON" : "OFF")"
        if !latchMode {
            releaseCurrentlySoundingNotes()
        }
        notifyTelemetry()
    }

    public func cycleChordType() {
        let all = ChordType.allCases
        if let idx = all.firstIndex(of: chordType) {
            chordType = all[(idx + 1) % all.count]
            telemetry.chordType = chordType
            lastEventDescription = "Chord Type: \(chordType.rawValue)"
            revoiceActiveChord()
            notifyTelemetry()
        }
    }

    public func cycleScale() {
        let scales = ["Major", "Minor", "Dorian", "Mixolydian"]
        if let idx = scales.firstIndex(of: scaleName) {
            scaleName = scales[(idx + 1) % scales.count]
            telemetry.scaleName = scaleName
            lastEventDescription = "Scale: \(scaleName)"
            revoiceActiveChord()
            notifyTelemetry()
        }
    }

    public func toggleArpeggiator() {
        isArpActive.toggle()
        telemetry.isArpActive = isArpActive
        lastEventDescription = "Arpeggiator: \(isArpActive ? "ON" : "OFF")"

        if isArpActive {
            startArpeggiator()
        } else {
            stopArpeggiator()
            if latchMode && !latchedPitches.isEmpty {
                playBlockChord(pitches: latchedPitches, name: telemetry.activeChordName)
            }
        }
        notifyTelemetry()
    }

    public func cycleArpRate(forward: Bool = true) {
        let all = ArpRate.allCases
        if let idx = all.firstIndex(of: arpRate) {
            let nextIdx = forward ? (idx + 1) % all.count : (idx - 1 + all.count) % all.count
            arpRate = all[nextIdx]
            telemetry.arpRate = arpRate
            lastEventDescription = "Arp Rate: \(arpRate.rawValue)"
            if isArpActive { restartArpeggiator() }
            notifyTelemetry()
        }
    }

    public func triggerPanic() {
        stopArpeggiator()
        releaseCurrentlySoundingNotes()
        latchedPitches.removeAll()
        heldFaceButtonIndex = nil
        heldChordTemporaryTranspose = 0
        heldChordAddSubBass = false
        heldChordAddHighOctave = false
        telemetry.isHoldingChord = false
        telemetry.activeChordNotes.removeAll()
        telemetry.activeChordName = "Muted"
        telemetry.micMuted = true
        lastEventDescription = "PANIC / ALL NOTES OFF"
        delegate?.panicTriggered()
        notifyTelemetry()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.telemetry.micMuted = false
            self.notifyTelemetry()
        }
    }

    private func handleFaceButton(degreeIndex: Int, buttonName: String, pressed: Bool) {
        if pressed {
            lastFaceDegree = degreeIndex
            let pitches = computePitches(forDegree: degreeIndex)
            let chordLabel = chordNameForDegree(degreeIndex)

            telemetry.activeChordNotes = pitches
            telemetry.activeChordName = chordLabel

            let triggerVal = telemetry.rightTrigger
            let velocity: UInt8 = triggerVal > 0.05 ? UInt8(60 + triggerVal * 67) : 100

            if latchMode {
                latchedPitches = pitches
                if isArpActive {
                    restartArpeggiator()
                } else {
                    releaseCurrentlySoundingNotes()
                    playBlockChord(pitches: pitches, name: chordLabel, velocity: velocity)
                }
            } else {
                playBlockChord(pitches: pitches, name: chordLabel, velocity: velocity)
            }
            lastEventDescription = "\(chordLabel) (\(pitches.map { noteNameForPitch($0) }.joined(separator: "-")))"
        }
        notifyTelemetry()
    }

    private func computePitches(forDegree degree: Int) -> [UInt8] {
        let basePitch = Int(rootKey) + octaveShift + heldChordTemporaryTranspose
        if !chordMode {
            let diatonicOffsets = [0, 2, 4, 5, 7, 9, 11]
            let offset = diatonicOffsets[degree % diatonicOffsets.count]
            return [UInt8(clamp(basePitch + offset, min: 0, max: 127))]
        }

        var rootOffset: Int
        var isMinor: Bool
        switch degree {
        case 0: rootOffset = 0; isMinor = (scaleName == "Minor")
        case 1: rootOffset = 2; isMinor = true
        case 3: rootOffset = 5; isMinor = false
        case 5: rootOffset = 9; isMinor = (scaleName == "Major")
        default: rootOffset = 0; isMinor = false
        }

        var chordOffsets: [Int]
        switch chordType {
        case .triad:
            chordOffsets = isMinor ? [0, 3, 7] : [0, 4, 7]
        case .seventh:
            chordOffsets = isMinor ? [0, 3, 7, 10] : [0, 4, 7, 11]
        case .sus4:
            chordOffsets = [0, 5, 7]
        case .add9:
            chordOffsets = isMinor ? [0, 3, 7, 14] : [0, 4, 7, 14]
        }

        // Apply Inversion / Voicing
        switch chordInversion {
        case .root:
            break
        case .first:
            if chordOffsets.count > 1 {
                chordOffsets[0] += 12
                chordOffsets.sort()
            }
        case .second:
            if chordOffsets.count > 2 {
                chordOffsets[0] += 12
                chordOffsets[1] += 12
                chordOffsets.sort()
            }
        case .drop2:
            if chordOffsets.count >= 4 {
                chordOffsets[chordOffsets.count - 2] -= 12
                chordOffsets.sort()
            }
        }

        // Apply Held-Chord Add-ons
        if heldChordAddSubBass {
            chordOffsets.insert(-12, at: 0)
        }
        if heldChordAddHighOctave {
            let top = chordOffsets.last ?? 12
            chordOffsets.append(top + 12)
        }

        return chordOffsets.map { offset in
            UInt8(clamp(basePitch + rootOffset + offset, min: 0, max: 127))
        }
    }

    private func chordNameForDegree(_ degree: Int) -> String {
        let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let diatonicOffsets = [0, 2, 4, 5, 7, 9, 11]
        let rootOffset = diatonicOffsets[degree % diatonicOffsets.count]
        let pitch = Int(rootKey) + rootOffset + heldChordTemporaryTranspose
        let rootNote = noteNames[pitch % 12]

        if !chordMode { return rootNote }

        let isMinor = (degree == 1 || (degree == 5 && scaleName == "Major") || (degree == 0 && scaleName == "Minor"))
        let suffix: String
        switch chordType {
        case .triad: suffix = isMinor ? "m" : "Maj"
        case .seventh: suffix = isMinor ? "m7" : "Maj7"
        case .sus4: suffix = "sus"
        case .add9: suffix = isMinor ? "m9" : "add9"
        }

        var name = "\(rootNote)\(suffix)"
        if heldChordAddSubBass { name += " /Bass" }
        if heldChordAddHighOctave { name += " +8va" }
        return name
    }

    private func revoiceActiveChord() {
        guard !latchedPitches.isEmpty else { return }
        let newPitches = computePitches(forDegree: lastFaceDegree)
        latchedPitches = newPitches
        telemetry.activeChordNotes = newPitches
        telemetry.activeChordName = chordNameForDegree(lastFaceDegree)

        if isArpActive {
            restartArpeggiator()
        } else {
            releaseCurrentlySoundingNotes()
            playBlockChord(pitches: newPitches, name: telemetry.activeChordName)
        }
    }

    private func playBlockChord(pitches: [UInt8], name: String, velocity: UInt8 = 100) {
        releaseCurrentlySoundingNotes()
        currentlySoundingPitches = pitches
        delegate?.notesTriggered(pitches: pitches, velocity: velocity, name: name)
    }

    private func releaseCurrentlySoundingNotes() {
        if !currentlySoundingPitches.isEmpty {
            delegate?.notesReleased(pitches: currentlySoundingPitches, name: "Block Release")
            currentlySoundingPitches.removeAll()
        }
    }

    // MARK: - Arpeggiator Engine
    private func startArpeggiator() {
        releaseCurrentlySoundingNotes()
        guard !latchedPitches.isEmpty else { return }

        arpTimer?.cancel()
        arpStepIndex = 0

        let timer = DispatchSource.makeTimerSource(queue: .main)
        let secondsPerQuarter = 60.0 / bpm
        let stepInterval = secondsPerQuarter * arpRate.multiplier
        let intervalNs = Int(stepInterval * 1_000_000_000)

        timer.schedule(deadline: .now(), repeating: .nanoseconds(intervalNs))
        timer.setEventHandler { [weak self] in
            self?.arpeggiatorTick()
        }
        timer.resume()
        self.arpTimer = timer
    }

    private func stopArpeggiator() {
        arpTimer?.cancel()
        arpTimer = nil
        if let last = lastArpPitch {
            delegate?.notesReleased(pitches: [last], name: "Arp Release")
            lastArpPitch = nil
        }
        telemetry.currentArpStep = 0
    }

    private func restartArpeggiator() {
        if isArpActive {
            stopArpeggiator()
            startArpeggiator()
        }
    }

    private func arpeggiatorTick() {
        guard !latchedPitches.isEmpty else { return }

        if let last = lastArpPitch {
            delegate?.notesReleased(pitches: [last], name: "Arp Step Off")
            lastArpPitch = nil
        }

        let sorted = latchedPitches.sorted()
        let count = sorted.count
        guard count > 0 else { return }
        let pitch: UInt8

        switch arpPattern {
        case .up:
            pitch = sorted[arpStepIndex % count]
            arpStepIndex = (arpStepIndex + 1) % count
        case .down:
            pitch = sorted[(count - 1 - (arpStepIndex % count))]
            arpStepIndex = (arpStepIndex + 1) % count
        case .upDown:
            let cycle = (count > 1) ? (count * 2 - 2) : 1
            let pos = arpStepIndex % cycle
            let idx = pos < count ? pos : (cycle - pos)
            pitch = sorted[idx]
            arpStepIndex = (arpStepIndex + 1) % cycle
        case .random:
            pitch = sorted.randomElement() ?? sorted[0]
            arpStepIndex = (arpStepIndex + 1) % count
        }

        let triggerVal = telemetry.rightTrigger
        let velocity: UInt8 = triggerVal > 0.05 ? UInt8(50 + triggerVal * 77) : 95

        lastArpPitch = pitch
        telemetry.currentArpStep = arpStepIndex
        delegate?.notesTriggered(pitches: [pitch], velocity: velocity, name: "Arp: \(noteNameForPitch(pitch))")
        notifyTelemetry()

        let stepInterval = (60.0 / bpm) * arpRate.multiplier
        let gateTime = stepInterval * 0.75
        DispatchQueue.main.asyncAfter(deadline: .now() + gateTime) { [weak self] in
            guard let self = self, let current = self.lastArpPitch, current == pitch else { return }
            self.delegate?.notesReleased(pitches: [pitch], name: "Arp Gate Off")
            self.lastArpPitch = nil
        }
    }

    private func evaluateLayerState() {
        let prevLayer = currentLayer
        if isL1Held && isR1Held {
            currentLayer = .matrix
            setLightbarColor(red: 0.92, green: 0.28, blue: 0.60) // Magenta
        } else if isL1Held {
            currentLayer = .harmony
            setLightbarColor(red: 0.23, green: 0.51, blue: 0.96) // Blue
        } else if isR1Held {
            currentLayer = .arp
            setLightbarColor(red: 0.96, green: 0.62, blue: 0.04) // Amber
        } else {
            currentLayer = .base
            setLightbarColor(red: 0.06, green: 0.72, blue: 0.51) // Green
        }

        if prevLayer != currentLayer {
            delegate?.layerDidChange(currentLayer)
        }
    }

    private func notifyTelemetry() {
        delegate?.telemetryUpdated(telemetry)
    }

    public func setLightbarColor(red: Float, green: Float, blue: Float) {
        guard let light = activeController?.light else { return }
        light.color = GCColor(red: red, green: green, blue: blue)
    }

    public func noteNameForPitch(_ pitch: UInt8) -> String {
        let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let octave = Int(pitch) / 12 - 1
        let note = noteNames[Int(pitch) % 12]
        return "\(note)\(octave)"
    }
}

private func clamp<T: Comparable>(_ val: T, min minVal: T, max maxVal: T) -> T {
    return max(minVal, min(maxVal, val))
}
