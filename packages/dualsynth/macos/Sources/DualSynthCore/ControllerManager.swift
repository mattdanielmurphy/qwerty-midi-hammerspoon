import Foundation
import GameController
import CoreHaptics

public enum ControlLayer: String, CaseIterable {
    case base = "Base Play"
    case harmony = "Harmony (L1)"
    case looper = "Arp & Rhythm (R1)"
    case parameters = "Synth & FX (L1+R1)"
}

public enum ChordType: String, CaseIterable {
    case triad = "Triad"
    case seventh = "7th"
    case sus4 = "Sus4"
    case add9 = "Add9"
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

    public var options: Bool = false   // Options / Menu button
    public var create: Bool = false    // Create / Share button
    public var home: Bool = false      // PS Home button
    public var micMuted: Bool = false  // Mic button
    public var touchpad: Bool = false

    // Motion & Haptics
    public var pitchAngle: Float = 0.0       // 0° (parallel) to ~75° (ceiling)
    public var modWheel: UInt8 = 0            // MIDI CC #1 (0 - 127)
    public var hapticIntensity: Float = 0.0   // 0.0 to 0.40 (40% max)

    // Musical Engine States
    public var chordMode: Bool = true
    public var chordType: ChordType = .triad
    public var latchMode: Bool = true
    public var isArpActive: Bool = false
    public var arpPattern: ArpPattern = .up
    public var arpRate: ArpRate = .eighth
    public var bpm: Double = 120.0
    public var currentArpStep: Int = 0
    public var activeChordNotes: [UInt8] = []
    public var activeChordName: String = "None"

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

    // Musical Engine State (defaults: Chord Mode ON, Latch Mode ON)
    @Published public var chordMode: Bool = true
    @Published public var chordType: ChordType = .triad
    @Published public var latchMode: Bool = true
    @Published public var isArpActive: Bool = false
    @Published public var arpPattern: ArpPattern = .up
    @Published public var arpRate: ArpRate = .eighth
    @Published public var bpm: Double = 120.0

    // Internal active note sets
    private var latchedPitches: [UInt8] = []
    private var currentlySoundingPitches: [UInt8] = []
    private var lastFaceDegree: Int = 0

    // Arpeggiator timer
    private var arpTimer: DispatchSourceTimer?
    private var arpStepIndex: Int = 0
    private var lastArpPitch: UInt8? = nil

    // Modifier states
    private var l1Held: Bool = false
    private var r1Held: Bool = false

    // CoreHaptics
    private var hapticEngine: CHHapticEngine?
    private var continuousHapticPlayer: CHHapticAdvancedPatternPlayer?
    private var isHapticRunning: Bool = false

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
        stopHaptics()
    }

    private func syncTelemetryEngineState() {
        telemetry.chordMode = chordMode
        telemetry.chordType = chordType
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
        stopHaptics()
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
    }

    private func setupControllerBindings(_ controller: GCController) {
        guard let gamepad = controller.extendedGamepad else { return }

        // 1. Shoulder Modifiers (L1 / R1)
        gamepad.leftShoulder.valueChangedHandler = { [weak self] (_, _, pressed) in
            guard let self = self else { return }
            self.l1Held = pressed
            self.telemetry.l1 = pressed
            self.evaluateLayerState()
            self.notifyTelemetry()
        }

        gamepad.rightShoulder.valueChangedHandler = { [weak self] (_, _, pressed) in
            guard let self = self else { return }
            self.r1Held = pressed
            self.telemetry.r1 = pressed
            self.evaluateLayerState()
            self.notifyTelemetry()
        }

        // 2. Face Buttons (Cross=I, Square=II, Circle=IV, Triangle=VI)
        gamepad.buttonA.valueChangedHandler = { [weak self] (_, _, pressed) in
            self?.telemetry.cross = pressed
            self?.handleFaceButton(degreeIndex: 0, name: "✕ Cross (I)", pressed: pressed)
        }
        gamepad.buttonX.valueChangedHandler = { [weak self] (_, _, pressed) in
            self?.telemetry.square = pressed
            self?.handleFaceButton(degreeIndex: 1, name: "□ Square (II)", pressed: pressed)
        }
        gamepad.buttonB.valueChangedHandler = { [weak self] (_, _, pressed) in
            self?.telemetry.circle = pressed
            self?.handleFaceButton(degreeIndex: 3, name: "○ Circle (IV)", pressed: pressed)
        }
        gamepad.buttonY.valueChangedHandler = { [weak self] (_, _, pressed) in
            self?.telemetry.triangle = pressed
            self?.handleFaceButton(degreeIndex: 5, name: "△ Triangle (VI)", pressed: pressed)
        }

        // 3. D-Pad
        gamepad.dpad.up.valueChangedHandler = { [weak self] (_, _, pressed) in
            guard let self = self else { return }
            self.telemetry.dpadUp = pressed
            if pressed {
                if self.r1Held {
                    self.cycleArpRate(forward: true)
                } else {
                    self.octaveShift = min(36, self.octaveShift + 12)
                    self.lastEventDescription = "Octave: \(self.octaveShift / 12 > 0 ? "+" : "")\(self.octaveShift / 12)"
                    self.revoiceActiveChord()
                }
            }
            self.notifyTelemetry()
        }
        gamepad.dpad.down.valueChangedHandler = { [weak self] (_, _, pressed) in
            guard let self = self else { return }
            self.telemetry.dpadDown = pressed
            if pressed {
                if self.r1Held {
                    self.cycleArpRate(forward: false)
                } else {
                    self.octaveShift = max(-36, self.octaveShift - 12)
                    self.lastEventDescription = "Octave: \(self.octaveShift / 12 > 0 ? "+" : "")\(self.octaveShift / 12)"
                    self.revoiceActiveChord()
                }
            }
            self.notifyTelemetry()
        }
        gamepad.dpad.left.valueChangedHandler = { [weak self] (_, _, pressed) in
            guard let self = self else { return }
            self.telemetry.dpadLeft = pressed
            if pressed {
                if self.r1Held {
                    self.bpm = max(40.0, self.bpm - 5.0)
                    self.telemetry.bpm = self.bpm
                    self.lastEventDescription = String(format: "BPM: %.0f", self.bpm)
                    if self.isArpActive { self.restartArpeggiator() }
                } else {
                    self.rootKey = max(36, self.rootKey - 1)
                    self.lastEventDescription = "Root: \(self.noteNameForPitch(self.rootKey))"
                    self.revoiceActiveChord()
                }
            }
            self.notifyTelemetry()
        }
        gamepad.dpad.right.valueChangedHandler = { [weak self] (_, _, pressed) in
            guard let self = self else { return }
            self.telemetry.dpadRight = pressed
            if pressed {
                if self.r1Held {
                    self.bpm = min(240.0, self.bpm + 5.0)
                    self.telemetry.bpm = self.bpm
                    self.lastEventDescription = String(format: "BPM: %.0f", self.bpm)
                    if self.isArpActive { self.restartArpeggiator() }
                } else {
                    self.rootKey = min(84, self.rootKey + 1)
                    self.lastEventDescription = "Root: \(self.noteNameForPitch(self.rootKey))"
                    self.revoiceActiveChord()
                }
            }
            self.notifyTelemetry()
        }

        // 4. Triggers (L2 / R2)
        gamepad.leftTrigger.valueChangedHandler = { [weak self] (_, value, _) in
            guard let self = self else { return }
            self.telemetry.leftTrigger = value
            let ccVal = UInt8(value * 127)
            self.delegate?.continuousParamChanged(cc: 74, value: ccVal, name: "L2 Filter Cutoff")
            self.notifyTelemetry()
        }
        gamepad.rightTrigger.valueChangedHandler = { [weak self] (_, value, _) in
            guard let self = self else { return }
            self.telemetry.rightTrigger = value
            let ccVal = UInt8(value * 127)
            self.delegate?.continuousParamChanged(cc: 11, value: ccVal, name: "R2 Expression")
            self.notifyTelemetry()
        }

        // 5. Left Thumbstick (Pitch Bend X, Modulation Wheel Y)
        gamepad.leftThumbstick.valueChangedHandler = { [weak self] (_, xVal, yVal) in
            guard let self = self else { return }
            self.telemetry.leftStickX = xVal
            self.telemetry.leftStickY = yVal

            if abs(yVal) > 0.05 {
                let modVal = UInt8(max(0, yVal) * 127)
                self.delegate?.continuousParamChanged(cc: 1, value: modVal, name: "Left Stick Y (Mod)")
            }
            self.notifyTelemetry()
        }

        // 6. Right Thumbstick (Pan CC #10 X, Resonance CC #71 Y)
        gamepad.rightThumbstick.valueChangedHandler = { [weak self] (_, xVal, yVal) in
            guard let self = self else { return }
            self.telemetry.rightStickX = xVal
            self.telemetry.rightStickY = yVal

            if abs(xVal) > 0.08 {
                let panVal = UInt8(clamp((xVal + 1.0) / 2.0 * 127, min: 0, max: 127))
                self.delegate?.continuousParamChanged(cc: 10, value: panVal, name: "Right Stick X (Pan)")
            }
            if abs(yVal) > 0.08 {
                let resVal = UInt8(max(0, yVal) * 127)
                self.delegate?.continuousParamChanged(cc: 71, value: resVal, name: "Right Stick Y (Res)")
            }
            self.notifyTelemetry()
        }

        // 7. Stick Clicks (L3 / R3)
        if let l3Btn = gamepad.leftThumbstickButton {
            l3Btn.valueChangedHandler = { [weak self] (_, _, pressed) in
                guard let self = self else { return }
                self.telemetry.l3 = pressed
                if pressed {
                    self.toggleChordMode()
                }
                self.notifyTelemetry()
            }
        }
        if let r3Btn = gamepad.rightThumbstickButton {
            r3Btn.valueChangedHandler = { [weak self] (_, _, pressed) in
                guard let self = self else { return }
                self.telemetry.r3 = pressed
                if pressed {
                    self.toggleArpeggiator()
                }
                self.notifyTelemetry()
            }
        }

        // 8. Create / Share Button (buttonOptions) -> Cycle Chord Type
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

        // 9. Options / Menu Button (buttonMenu) -> Toggle Arpeggiator
        gamepad.buttonMenu.valueChangedHandler = { [weak self] (_, _, pressed) in
            guard let self = self else { return }
            self.telemetry.options = pressed
            if pressed {
                self.toggleArpeggiator()
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

    // MARK: - Motion Sensors (Gyroscope Tilt to Mod Wheel)
    private func setupMotionSensors(_ controller: GCController) {
        guard let motion = controller.motion else { return }
        motion.sensorsActive = true

        motion.valueChangedHandler = { [weak self] m in
            guard let self = self else { return }
            let gy = m.gravity.y
            let gz = m.gravity.z
            // Compute tilt angle relative to horizontal plane
            let pitchRad = atan2(-gy, abs(gz) + 0.001)
            var pitchDeg = Float(pitchRad * 180.0 / .pi)
            pitchDeg = max(0.0, min(80.0, pitchDeg))

            // Map 0° -> 75° to Mod Wheel CC #1 (0 to 127)
            let normalized = min(1.0, pitchDeg / 75.0)
            let mwVal = UInt8(normalized * 127.0)

            if mwVal != self.telemetry.modWheel {
                self.telemetry.pitchAngle = pitchDeg
                self.telemetry.modWheel = mwVal
                self.delegate?.continuousParamChanged(cc: 1, value: mwVal, name: "Gyro Mod Wheel")

                // Modulate haptic vibration according to requested curve:
                // MW = 0 -> 0.0 intensity
                // MW = 50 -> 0.20 (20%) intensity
                // MW = 127 -> 0.40 (40% max) intensity
                let intensity: Float
                if mwVal == 0 {
                    intensity = 0.0
                } else if mwVal <= 50 {
                    intensity = (Float(mwVal) / 50.0) * 0.20
                } else {
                    intensity = 0.20 + ((Float(mwVal) - 50.0) / 77.0) * 0.20
                }

                self.telemetry.hapticIntensity = intensity
                self.updateHapticIntensity(intensity)
                self.notifyTelemetry()
            }
        }
    }

    // MARK: - DualSense Adaptive Triggers
    private func setupAdaptiveTriggers(_ controller: GCController) {
        guard let ds = controller.extendedGamepad as? GCDualSenseGamepad else { return }

        // L2: Slope resistance mimicking progressive synth filter resistance
        ds.leftTrigger.setModeSlopeFeedback(startPosition: 0.05, endPosition: 0.95, startStrength: 0.15, endStrength: 0.8)

        // R2: Weapon tactile click/detent at 80% pull for velocity crest
        ds.rightTrigger.setModeWeaponWithStartPosition(0.1, endPosition: 0.8, resistiveStrength: 0.6)
    }

    // MARK: - CoreHaptics Engine
    private func setupHaptics(_ controller: GCController) {
        guard let haptics = controller.haptics else { return }
        do {
            hapticEngine = haptics.createEngine(withLocality: .default)
            try hapticEngine?.start()
            hapticEngine?.stoppedHandler = { [weak self] reason in
                self?.isHapticRunning = false
            }
            hapticEngine?.resetHandler = { [weak self] in
                try? self?.hapticEngine?.start()
            }
        } catch {
            print("⚠️ CoreHaptics initialization error: \(error)")
        }
    }

    private func updateHapticIntensity(_ intensity: Float) {
        guard let engine = hapticEngine else { return }

        if intensity <= 0.01 {
            stopHaptics()
            return
        }

        if !isHapticRunning {
            do {
                let intensityParam = CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity)
                let sharpnessParam = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.4)
                let event = CHHapticEvent(eventType: .hapticContinuous, parameters: [intensityParam, sharpnessParam], relativeTime: 0, duration: 100)
                let pattern = try CHHapticPattern(events: [event], parameters: [])
                continuousHapticPlayer = try engine.makeAdvancedPlayer(with: pattern)
                try continuousHapticPlayer?.start(atTime: CHHapticTimeImmediate)
                isHapticRunning = true
            } catch {
                print("⚠️ Haptic start error: \(error)")
            }
        } else {
            let dynamicParam = CHHapticDynamicParameter(parameterID: .hapticIntensityControl, value: intensity, relativeTime: 0)
            try? continuousHapticPlayer?.sendParameters([dynamicParam], atTime: 0)
        }
    }

    private func stopHaptics() {
        if isHapticRunning {
            try? continuousHapticPlayer?.stop(atTime: CHHapticTimeImmediate)
            isHapticRunning = false
        }
    }

    // MARK: - Musical Actions & Triggers
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
            lastEventDescription = "Chord: \(chordType.rawValue)"
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

    private func handleFaceButton(degreeIndex: Int, name: String, pressed: Bool) {
        if pressed {
            lastFaceDegree = degreeIndex
            let pitches = computePitches(forDegree: degreeIndex)
            let chordLabel = chordNameForDegree(degreeIndex)

            telemetry.activeChordNotes = pitches
            telemetry.activeChordName = chordLabel

            let triggerVal = telemetry.rightTrigger
            let velocity: UInt8 = triggerVal > 0.05 ? UInt8(30 + triggerVal * 97) : 100

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
        } else {
            if !latchMode {
                releaseCurrentlySoundingNotes()
                lastEventDescription = "Released: \(name)"
            }
        }
        notifyTelemetry()
    }

    private func computePitches(forDegree degree: Int) -> [UInt8] {
        let basePitch = Int(rootKey) + octaveShift
        if !chordMode {
            let diatonicOffsets = [0, 2, 4, 5, 7, 9, 11]
            let offset = diatonicOffsets[degree % diatonicOffsets.count]
            return [UInt8(clamp(basePitch + offset, min: 0, max: 127))]
        }

        var rootOffset: Int
        var isMinor: Bool
        switch degree {
        case 0: rootOffset = 0; isMinor = false // I
        case 1: rootOffset = 2; isMinor = true  // ii
        case 3: rootOffset = 5; isMinor = false // IV
        case 5: rootOffset = 9; isMinor = true  // vi
        default: rootOffset = 0; isMinor = false
        }

        let chordOffsets: [Int]
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

        return chordOffsets.map { offset in
            UInt8(clamp(basePitch + rootOffset + offset, min: 0, max: 127))
        }
    }

    private func chordNameForDegree(_ degree: Int) -> String {
        let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let diatonicOffsets = [0, 2, 4, 5, 7, 9, 11]
        let rootOffset = diatonicOffsets[degree % diatonicOffsets.count]
        let pitch = Int(rootKey) + rootOffset
        let rootNote = noteNames[pitch % 12]

        if !chordMode { return rootNote }

        let isMinor = (degree == 1 || degree == 5)
        let suffix: String
        switch chordType {
        case .triad: suffix = isMinor ? "m" : "Maj"
        case .seventh: suffix = isMinor ? "m7" : "Maj7"
        case .sus4: suffix = "sus4"
        case .add9: suffix = isMinor ? "m(add9)" : "add9"
        }
        return "\(rootNote)\(suffix)"
    }

    private func revoiceActiveChord() {
        guard !latchedPitches.isEmpty else { return }
        let newPitches = computePitches(forDegree: lastFaceDegree)
        latchedPitches = newPitches
        telemetry.activeChordNotes = newPitches
        telemetry.activeChordName = chordNameForDegree(lastFaceDegree)

        if isArpActive {
            restartArpeggiator()
        } else if latchMode {
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
        let velocity: UInt8 = triggerVal > 0.05 ? UInt8(40 + triggerVal * 87) : 95

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
        if l1Held && r1Held {
            currentLayer = .parameters
            setLightbarColor(red: 0.92, green: 0.28, blue: 0.60) // Magenta
        } else if l1Held {
            currentLayer = .harmony
            setLightbarColor(red: 0.23, green: 0.51, blue: 0.96) // Blue
        } else if r1Held {
            currentLayer = .looper
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
