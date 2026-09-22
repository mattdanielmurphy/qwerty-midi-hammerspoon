import Foundation
import GameController
import CoreHaptics

public enum ControlLayer: String, CaseIterable {
    case base = "Base Play"
    case harmony = "Harmony (L1)"
    case arp = "Arp & Rhythm (R1)"
    case matrix = "Synth & FX (L1+R1)"
}

public enum OperatingMode: String, CaseIterable {
    case melodic = "Melodic (8-Note Scale)"
    case chords = "Chord Groovebox"
    case companion = "Sound & Tracks"
    case drums = "Drum & Percussion"

    public var icon: String {
        switch self {
        case .melodic: return "music.note"
        case .chords: return "pianokeys"
        case .companion: return "slider.horizontal.3"
        case .drums: return "circle.grid.2x2.fill"
        }
    }

    public var shortBadge: String {
        switch self {
        case .melodic: return "MELODIC (8-NOTE)"
        case .chords: return "CHORDS"
        case .companion: return "SOUND + TRACKS"
        case .drums: return "DRUMS"
        }
    }

    public var description: String {
        switch self {
        case .melodic: return "8 diatonic scale degrees across D-Pad & Face buttons with L1/R1 octave paging"
        case .chords: return "Diatonic chord generator with real-time morphing, inversions & arpeggiator"
        case .companion: return "Sound-control surface for QWERTY Tracks 1–4; notes stay on the keyboard"
        case .drums: return "8 velocity-sensitive GM drum pads across D-Pad and Face buttons"
        }
    }
}

public enum ChordType: String, CaseIterable {
    case triad = "Triad"
    case seventh = "7th"
    case ninth = "9th"
    case sus4 = "Sus4"
    case power = "Power"

    public var offsets: [Int] {
        switch self {
        case .triad: return [0, 2, 4]
        case .seventh: return [0, 2, 4, 6]
        case .ninth: return [0, 2, 4, 6, 8]
        case .sus4: return [0, 3, 4]
        case .power: return [0, 4]
        }
    }
}

public struct MusicalScale: Identifiable, Equatable {
    public var id: String { name }
    public let name: String
    public let shortName: String
    public let intervals: [Int]

    public init(name: String, shortName: String, intervals: [Int]) {
        self.name = name
        self.shortName = shortName
        self.intervals = intervals
    }
}

public let availableScales: [MusicalScale] = [
    MusicalScale(name: "Major", shortName: "Maj", intervals: [0, 2, 4, 5, 7, 9, 11]),
    MusicalScale(name: "Minor", shortName: "Min", intervals: [0, 2, 3, 5, 7, 8, 10]),
    MusicalScale(name: "Dorian", shortName: "Dor", intervals: [0, 2, 3, 5, 7, 9, 10]),
    MusicalScale(name: "Mixolydian", shortName: "Mixo", intervals: [0, 2, 4, 5, 7, 9, 10]),
    MusicalScale(name: "Lydian", shortName: "Lyd", intervals: [0, 2, 4, 6, 7, 9, 11]),
    MusicalScale(name: "Phrygian", shortName: "Phryg", intervals: [0, 1, 3, 5, 7, 8, 10]),
    MusicalScale(name: "Harmonic Min", shortName: "HarMin", intervals: [0, 2, 3, 5, 7, 8, 11])
]

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
    public var scaleDegreeShift: Int = 0
    public var latchMode: Bool = true
    public var isArpActive: Bool = false
    public var arpPattern: ArpPattern = .up
    public var arpRate: ArpRate = .eighth
    public var bpm: Double = 120.0
    public var currentArpStep: Int = 0
    public var activeArpPitch: UInt8? = nil
    public var activeChordNotes: [UInt8] = []
    public var playedRootPitches: [UInt8] = []
    public var activeChordName: String = "None"
    public var isHoldingChord: Bool = false
    public var heldFaceButtonIndex: Int? = nil
    public var heldChordAdd7th: Bool = false
    public var heldChordAdd9th: Bool = false
    public var heldChordAddSubBass: Bool = false
    public var heldChordAddHighOctave: Bool = false
    public var heldChordTemporaryStepShift: Int = 0

    // Operating Mode, Held Menus & QWERTY Track Target
    public var operatingMode: OperatingMode = .companion
    public var isModeMenuHeld: Bool = false
    public var isTrackSelectorHeld: Bool = false
    public var qwertyTrackId: Int = 1
    public var isSyncedWithQwerty: Bool = false
    public var melodicOctaveOffset: Int = 0
    public var currentVelocityVal: UInt8 = 100

    public init() {}
}

public protocol DualSynthDelegate: AnyObject {
    func controllerDidConnect(_ name: String, isDualSense: Bool)
    func controllerDidDisconnect()
    func layerDidChange(_ layer: ControlLayer)
    func notesTriggered(pitches: [UInt8], velocity: UInt8, name: String)
    func notesReleased(pitches: [UInt8], name: String)
    func continuousParamChanged(cc: UInt8, value: UInt8, name: String)
    func pitchBendChanged(value: UInt16)
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

    // Operating Mode, Held Menus & QWERTY Track Target
    @Published public var operatingMode: OperatingMode = .companion
    @Published public var isModeMenuHeld: Bool = false
    @Published public var isTrackSelectorHeld: Bool = false
    @Published public var qwertyTrackId: Int = 1
    @Published public var isSyncedWithQwerty: Bool = false
    @Published public var melodicOctaveOffset: Int = 0

    @Published public var rootKey: UInt8 = 60 // C4 default
    @Published public var octaveShift: Int = 0
    @Published public var lastEventDescription: String = "Ready"

    // Musical Engine State
    @Published public var chordMode: Bool = true
    @Published public var chordType: ChordType = .triad
    @Published public var chordInversion: ChordInversion = .root
    @Published public var scaleIndex: Int = 0
    @Published public var scaleName: String = "Major"
    @Published public var scaleDegreeShift: Int = 0 // Diatonic scale steps

    public var currentScale: MusicalScale {
        if scaleIndex >= 0 && scaleIndex < availableScales.count {
            return availableScales[scaleIndex]
        }
        if let found = availableScales.first(where: { $0.name == scaleName }) {
            return found
        }
        return availableScales[0]
    }
    @Published public var latchMode: Bool = true
    @Published public var isArpActive: Bool = false
    @Published public var arpPattern: ArpPattern = .up
    @Published public var arpRate: ArpRate = .eighth
    @Published public var bpm: Double = 120.0

    // Held-Chord Alteration & Morphing State
    @Published public var heldFaceButtonIndex: Int? = nil
    @Published public var heldChordTemporaryStepShift: Int = 0
    @Published public var heldChordAdd7th: Bool = false
    @Published public var heldChordAdd9th: Bool = false
    @Published public var heldChordAddSubBass: Bool = false
    @Published public var heldChordAddHighOctave: Bool = false

    // Stick gesture tracking
    private var l3PressTime: Date?
    private var l3Moved: Bool = false
    private var r3PressTime: Date?
    private var r3Moved: Bool = false

    // Internal active note sets & multi-button arpeggiation
    private var activeFaceButtons = Set<Int>()
    private var activeFacePitches: [Int: [UInt8]] = [:]
    private var activeFaceRoots: [Int: UInt8] = [:]
    private var activeMelodicPitches: [Int: UInt8] = [:]
    private var activeDrumPitches: [Int: UInt8] = [:]
    private var isInternalSyncing: Bool = false
    private var latchedPitches: [UInt8] = []
    private var latchedRoots: [UInt8] = []
    private var currentlySoundingPitches: [UInt8] = []
    private var lastFaceDegree: Int = 0

    // Arpeggiator timer
    private var arpTimer: DispatchSourceTimer?
    private var arpStepIndex: Int = 0
    private var lastArpPitch: UInt8? = nil

    // Modifier states
    public var isL1Held: Bool = false
    public var isR1Held: Bool = false
    private var modeMenuDidSelect: Bool = false
    private var trackSelectorDidSelect: Bool = false

    // CoreHaptics & Motion Smoothing
    private var hapticEngine: CHHapticEngine?
    private var smoothedTiltDeg: Float = 0.0
    private var currentHapticStage: Int = 0
    private var lastHapticStageTime: Date = Date.distantPast

    // Stick state tracking
    private var lastPitchBendValue: UInt16 = 8192
    private var lastLeftStickYActive: Bool = false
    private var lastRightStickActive: Bool = false

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

        setupHammerspoonSync()
        syncTelemetryEngineState()
    }

    deinit {
        stopArpeggiator()
        hapticEngine?.stop()
        DistributedNotificationCenter.default().removeObserver(self)
    }

    private func syncTelemetryEngineState() {
        telemetry.operatingMode = operatingMode
        telemetry.isModeMenuHeld = isModeMenuHeld
        telemetry.isTrackSelectorHeld = isTrackSelectorHeld
        telemetry.qwertyTrackId = qwertyTrackId
        telemetry.isSyncedWithQwerty = isSyncedWithQwerty
        telemetry.melodicOctaveOffset = melodicOctaveOffset
        telemetry.currentVelocityVal = currentVelocity()
        telemetry.chordMode = chordMode
        telemetry.chordType = chordType
        telemetry.chordInversion = chordInversion
        telemetry.scaleName = availableScales[scaleIndex % availableScales.count].name
        telemetry.scaleDegreeShift = scaleDegreeShift
        telemetry.latchMode = latchMode
        telemetry.isArpActive = isArpActive
        telemetry.arpPattern = arpPattern
        telemetry.arpRate = arpRate
        telemetry.bpm = bpm
        telemetry.heldFaceButtonIndex = heldFaceButtonIndex
        telemetry.heldChordTemporaryStepShift = heldChordTemporaryStepShift
        telemetry.heldChordAdd7th = heldChordAdd7th
        telemetry.heldChordAdd9th = heldChordAdd9th
        telemetry.heldChordAddSubBass = heldChordAddSubBass
        telemetry.heldChordAddHighOctave = heldChordAddHighOctave
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
            self.handleDpadAction(direction: .up, pressed: pressed)
            self.notifyTelemetry()
        }
        gamepad.dpad.down.valueChangedHandler = { [weak self] (_, _, pressed) in
            guard let self = self else { return }
            self.telemetry.dpadDown = pressed
            self.handleDpadAction(direction: .down, pressed: pressed)
            self.notifyTelemetry()
        }
        gamepad.dpad.left.valueChangedHandler = { [weak self] (_, _, pressed) in
            guard let self = self else { return }
            self.telemetry.dpadLeft = pressed
            self.handleDpadAction(direction: .left, pressed: pressed)
            self.notifyTelemetry()
        }
        gamepad.dpad.right.valueChangedHandler = { [weak self] (_, _, pressed) in
            guard let self = self else { return }
            self.telemetry.dpadRight = pressed
            self.handleDpadAction(direction: .right, pressed: pressed)
            self.notifyTelemetry()
        }

        // 4. Triggers (L2 / R2)
        // L2 Trigger: Dynamic Note Velocity & Continuous Expression / Filter Pressure
        gamepad.leftTrigger.valueChangedHandler = { [weak self] (_, value, _) in
            guard let self = self else { return }
            self.telemetry.leftTrigger = value
            self.telemetry.currentVelocityVal = self.currentVelocity()

            // Continuous Expression (CC #11) and Cutoff (CC #74)
            let exprVal: UInt8 = value > 0.05 ? UInt8(clamp(50.0 + Double(value) * 77.0, min: 50, max: 127)) : 127
            self.delegate?.continuousParamChanged(cc: 11, value: exprVal, name: "L2 Expr (CC11)")
            if value > 0.05 {
                let cutoffVal = UInt8(clamp(60.0 + Double(value) * 67.0, min: 60, max: 127))
                self.delegate?.continuousParamChanged(cc: 74, value: cutoffVal, name: "L2 Cutoff (CC74)")
            }
            self.notifyTelemetry()
        }

        // R2 Trigger: continuous FX / reverb send (CC #91)
        gamepad.rightTrigger.valueChangedHandler = { [weak self] (_, value, _) in
            guard let self = self else { return }
            self.telemetry.rightTrigger = value
            let fxSend = UInt8(clamp(Double(value) * 127.0, min: 0, max: 127))
            self.delegate?.continuousParamChanged(cc: 91, value: fxSend, name: "R2 FX Send (CC91)")
            self.notifyTelemetry()
        }

        // 5. Left Thumbstick: X = Pitch Bend (0..16383, 8192 center), Y = Mod (>0) / Filter Cutoff (<0)
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
                // Pitch Bend on Left Stick X (Center = 8192, Range = 0..16383)
                if abs(xVal) >= 0.04 {
                    let norm = (Double(xVal) + 1.0) / 2.0
                    let bendVal = UInt16(clamp(norm * 16383.0, min: 0, max: 16383))
                    self.lastPitchBendValue = bendVal
                    self.delegate?.pitchBendChanged(value: bendVal)
                } else if self.lastPitchBendValue != 8192 {
                    self.lastPitchBendValue = 8192
                    self.delegate?.pitchBendChanged(value: 8192)
                }

                // Left Stick Y:
                // Push UP (> 0.05): Modulation (CC #1) 0 -> 127
                // Pull DOWN (< -0.05): Filter Cutoff (CC #74) sweep 127 -> 0 & Filter Breath (CC #2)
                if yVal > 0.05 {
                    self.lastLeftStickYActive = true
                    let modVal = UInt8(yVal * 127)
                    self.delegate?.continuousParamChanged(cc: 1, value: modVal, name: "LS Up (Mod CC1)")
                } else if yVal < -0.05 {
                    self.lastLeftStickYActive = true
                    let filterVal = UInt8(clamp(127.0 - (Double(abs(yVal)) * 127.0), min: 0, max: 127))
                    self.delegate?.continuousParamChanged(cc: 74, value: filterVal, name: "LS Down (Cutoff CC74)")
                    self.delegate?.continuousParamChanged(cc: 2, value: filterVal, name: "LS Down (Filter CC2)")
                } else if self.lastLeftStickYActive {
                    self.lastLeftStickYActive = false
                    self.delegate?.continuousParamChanged(cc: 1, value: 0, name: "LS Mod Reset")
                    self.delegate?.continuousParamChanged(cc: 74, value: 127, name: "LS Filter Reset")
                    self.delegate?.continuousParamChanged(cc: 2, value: 127, name: "LS Filter Reset")
                }
            }
            self.notifyTelemetry()
        }

        // 6. Right Thumbstick: X = Stereo Pan (CC10), Y = Dynamics (CC11) / Resonance (CC71) / Brightness (CC74)
        gamepad.rightThumbstick.valueChangedHandler = { [weak self] (_, xVal, yVal) in
            guard let self = self else { return }
            self.telemetry.rightStickX = xVal
            self.telemetry.rightStickY = yVal

            // Right Stick X: Stereo Pan (CC #10, Center = 64)
            if abs(xVal) >= 0.05 {
                self.lastRightStickActive = true
                let panVal = UInt8(clamp((Double(xVal) + 1.0) / 2.0 * 127.0, min: 0, max: 127))
                self.delegate?.continuousParamChanged(cc: 10, value: panVal, name: "RS Pan (CC10)")
            } else if self.lastRightStickActive && abs(yVal) < 0.05 {
                self.delegate?.continuousParamChanged(cc: 10, value: 64, name: "RS Pan Center")
            }

            // Right Stick Y:
            // Push UP (> 0.05): Resonance (CC71) + Expression Boost (CC11) + Brightness (CC74)
            // Pull DOWN (< -0.05): Dynamics Dip (CC11) 127 -> 20 + Cutoff Dip (CC74)
            if yVal > 0.05 {
                self.lastRightStickActive = true
                let resVal = UInt8(yVal * 127)
                let brightVal = UInt8(clamp(64 + Double(yVal) * 63.0, min: 64, max: 127))
                self.delegate?.continuousParamChanged(cc: 71, value: resVal, name: "RS Res (CC71)")
                self.delegate?.continuousParamChanged(cc: 74, value: brightVal, name: "RS Brightness (CC74)")
            } else if yVal < -0.05 {
                self.lastRightStickActive = true
                let dipVal = UInt8(clamp(127.0 - (Double(abs(yVal)) * 107.0), min: 20, max: 127))
                let cutoffVal = UInt8(clamp(127.0 - (Double(abs(yVal)) * 110.0), min: 10, max: 127))
                self.delegate?.continuousParamChanged(cc: 11, value: dipVal, name: "RS Expr Dip (CC11)")
                self.delegate?.continuousParamChanged(cc: 74, value: cutoffVal, name: "RS Cutoff Dip (CC74)")
            } else if self.lastRightStickActive && abs(xVal) < 0.05 {
                self.lastRightStickActive = false
                self.delegate?.continuousParamChanged(cc: 71, value: 0, name: "RS Res Reset")
                self.delegate?.continuousParamChanged(cc: 74, value: 127, name: "RS Cutoff Reset")
                self.delegate?.continuousParamChanged(cc: 11, value: 127, name: "RS Expr Reset")
                self.delegate?.continuousParamChanged(cc: 10, value: 64, name: "RS Pan Center")
            }
            self.notifyTelemetry()
        }

        // 7. Stick Clicks (L3 & R3) - Direct Toggles
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

        // 8. Create Button (|||): hold with D-Pad to select QWERTY Track 1–4.
        if let createBtn = gamepad.buttonOptions {
            createBtn.valueChangedHandler = { [weak self] (_, _, pressed) in
                guard let self = self else { return }
                self.telemetry.create = pressed
                if pressed {
                    self.trackSelectorDidSelect = false
                    self.isTrackSelectorHeld = true
                    self.telemetry.isTrackSelectorHeld = true
                    self.lastEventDescription = "Hold Create + D-Pad: Select QWERTY Track"
                } else {
                    self.isTrackSelectorHeld = false
                    self.telemetry.isTrackSelectorHeld = false
                }
                self.notifyTelemetry()
            }
        }

        // 9. Options Button (☰): hold with D-Pad to select an operating mode.
        // A tap still cycles scale, so the former shortcut remains available.
        gamepad.buttonMenu.valueChangedHandler = { [weak self] (_, _, pressed) in
            guard let self = self else { return }
            self.telemetry.options = pressed
            if pressed {
                self.modeMenuDidSelect = false
                self.isModeMenuHeld = true
                self.telemetry.isModeMenuHeld = true
                self.lastEventDescription = "Hold Options + D-Pad: Select Operating Mode"
            } else {
                self.isModeMenuHeld = false
                self.telemetry.isModeMenuHeld = false
                if !self.modeMenuDidSelect {
                    self.cycleScale()
                }
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

    // MARK: - Motion Sensors (Heavy EMA Smoothing, Rest Deadband & 5-Stage Haptic Pulses)
    private func setupMotionSensors(_ controller: GCController) {
        guard let motion = controller.motion else { return }
        motion.sensorsActive = true

        motion.valueChangedHandler = { [weak self] m in
            guard let self = self else { return }
            let ay = Double(m.acceleration.y)
            let az = Double(m.acceleration.z)

            // Resting flat on table: ay ≈ 0.174, az ≈ -0.985
            // Tilting back (top/jack to ceiling): ay decreases from +0.174 down towards -1.0
            let restAy = 0.174
            let delta = restAy - ay
            let rawAngleRad = atan2(max(0.0, delta), max(0.01, -az))
            let rawTiltDeg = Float(rawAngleRad * 180.0 / .pi)

            // 1. Heavy Low-Pass / Exponential Moving Average Filter (alpha = 0.08)
            let alpha: Float = 0.08
            self.smoothedTiltDeg = (alpha * rawTiltDeg) + ((1.0 - alpha) * self.smoothedTiltDeg)

            // 2. Solid Table-Rest Deadband: Any tilt under 4.5° is locked strictly to 0.0°
            let filteredDeg: Float
            if self.smoothedTiltDeg < 4.5 {
                filteredDeg = 0.0
            } else {
                let scaled = (self.smoothedTiltDeg - 4.5) / (72.0 - 4.5)
                filteredDeg = max(0.0, min(80.0, scaled * 80.0))
            }

            let normalized = min(1.0, max(0.0, filteredDeg / 75.0))
            let mwVal = UInt8(normalized * 127.0)

            if mwVal != self.telemetry.modWheel || abs(filteredDeg - self.telemetry.pitchAngle) > 0.5 {
                self.telemetry.pitchAngle = filteredDeg
                self.telemetry.modWheel = mwVal
                self.delegate?.continuousParamChanged(cc: 1, value: mwVal, name: "Gyro Mod Wheel (CC1)")

                // 3. Discrete 5-Stage Haptic Feedback (NO constant vibration!)
                // Stage 0: 0 (Resting flat, silent)
                // Stage 1: 1 ... 25   -> 1 subtle pulse
                // Stage 2: 26 ... 50  -> 1 solid pulse
                // Stage 3: 51 ... 75  -> 2 pulses
                // Stage 4: 76 ... 101 -> 2 strong pulses
                // Stage 5: 102 ... 127 -> 3 maximum strength pulses!
                let newStage: Int
                switch mwVal {
                case 0: newStage = 0
                case 1...25: newStage = 1
                case 26...50: newStage = 2
                case 51...75: newStage = 3
                case 76...101: newStage = 4
                default: newStage = 5
                }

                if newStage != self.currentHapticStage {
                    let oldStage = self.currentHapticStage
                    self.currentHapticStage = newStage
                    self.telemetry.hapticIntensity = Float(newStage) / 5.0

                    // Trigger pulse burst when entering higher stages or coming out of rest
                    if newStage > oldStage || (newStage > 0 && oldStage == 0) {
                        self.triggerStageHapticBurst(stage: newStage)
                    }
                }

                self.notifyTelemetry()
            }
        }
    }

    // MARK: - CoreHaptics Engine (5-Stage Discrete Pulse Bursts)
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

    private func triggerStageHapticBurst(stage: Int) {
        guard stage > 0, let engine = hapticEngine else { return }

        let now = Date()
        guard now.timeIntervalSince(lastHapticStageTime) >= 0.15 else { return }
        lastHapticStageTime = now

        let count: Int
        let intensity: Float
        let sharpness: Float

        switch stage {
        case 1:
            count = 1; intensity = 0.25; sharpness = 0.3
        case 2:
            count = 1; intensity = 0.40; sharpness = 0.5
        case 3:
            count = 2; intensity = 0.55; sharpness = 0.6
        case 4:
            count = 2; intensity = 0.70; sharpness = 0.75
        case 5:
            count = 3; intensity = 0.85; sharpness = 0.9
        default:
            return
        }

        var events: [CHHapticEvent] = []
        for i in 0..<count {
            let relativeTime = Double(i) * 0.08
            let intParam = CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity)
            let shParam = CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
            events.append(CHHapticEvent(eventType: .hapticTransient, parameters: [intParam, shParam], relativeTime: relativeTime))
        }

        do {
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            try? engine.start()
        }
    }

    // MARK: - Adaptive Triggers
    private func setupAdaptiveTriggers(_ controller: GCController) {
        guard let ds = controller.extendedGamepad as? GCDualSenseGamepad else { return }
        ds.leftTrigger.setModeSlopeFeedback(startPosition: 0.05, endPosition: 0.95, startStrength: 0.15, endStrength: 0.8)
        ds.rightTrigger.setModeSlopeFeedback(startPosition: 0.05, endPosition: 0.95, startStrength: 0.1, endStrength: 0.65)
    }

    public func currentVelocity() -> UInt8 {
        let val = telemetry.leftTrigger
        if val > 0.05 {
            return UInt8(clamp(36.0 + Double(val) * 91.0, min: 36, max: 127))
        }
        return 100 // comfortable default strike velocity
    }

    public func setOperatingMode(_ mode: OperatingMode) {
        guard operatingMode != mode else { return }
        releaseCurrentlySoundingNotes()
        for (_, pitch) in activeMelodicPitches {
            delegate?.notesReleased(pitches: [pitch], name: "Mode Switch")
        }
        activeMelodicPitches.removeAll()
        for (_, pitch) in activeDrumPitches {
            delegate?.notesReleased(pitches: [pitch], name: "Mode Switch")
        }
        activeDrumPitches.removeAll()

        operatingMode = mode
        telemetry.operatingMode = mode
        lastEventDescription = "Mode: \(mode.shortBadge)"
        evaluateLayerState()
        broadcastStateToHammerspoon()
        notifyTelemetry()
    }

    public var selectedTrackMIDIChannel: UInt8 {
        UInt8(qwertyTrackId - 1)
    }

    public var selectedQwertyTrackName: String {
        switch qwertyTrackId {
        case 1: return "Bass"
        case 2: return "Chords"
        case 3: return "Lead"
        case 4: return "Arp"
        default: return "Track"
        }
    }

    public func selectQwertyTrack(_ id: Int) {
        let targetId = Int(clamp(id, min: 1, max: 4))
        guard targetId != qwertyTrackId else { return }

        releaseInputForTrackChange()
        qwertyTrackId = targetId
        telemetry.qwertyTrackId = targetId
        telemetry.isSyncedWithQwerty = true
        isSyncedWithQwerty = true
        lastEventDescription = String(format: "QWERTY Track %d: %@ (MIDI Ch %d)", targetId, selectedQwertyTrackName, targetId)
        triggerStageHapticBurst(stage: 2)
        broadcastStateToHammerspoon()
        notifyTelemetry()
    }

    private func releaseInputForTrackChange() {
        stopArpeggiator()
        let pitches = Set(currentlySoundingPitches)
            .union(activeMelodicPitches.values)
            .union(activeDrumPitches.values)
            .union(activeFacePitches.values.flatMap { $0 })
        if !pitches.isEmpty {
            delegate?.notesReleased(pitches: pitches.sorted(), name: "QWERTY Track Change")
        }
        currentlySoundingPitches.removeAll()
        activeMelodicPitches.removeAll()
        activeDrumPitches.removeAll()
        activeFaceButtons.removeAll()
        activeFacePitches.removeAll()
        activeFaceRoots.removeAll()
        latchedPitches.removeAll()
        latchedRoots.removeAll()
        heldFaceButtonIndex = nil
        telemetry.isHoldingChord = false
        telemetry.activeChordNotes.removeAll()
        telemetry.playedRootPitches.removeAll()
        telemetry.activeChordName = "None"
    }

    public func scaleDegreeForButton(index: Int) -> Int {
        // 0: Cross -> I, 1: Square -> ii, 2: Circle -> IV, 3: Triangle -> V
        let baseDegrees = [0, 1, 3, 4]
        return baseDegrees[index % baseDegrees.count]
    }

    public func degreeName(_ step: Int) -> String {
        let numerals = ["I", "ii", "iii", "IV", "V", "vi", "vii°", "VIII"]
        let count = numerals.count
        let idx = ((step % count) + count) % count
        return numerals[idx]
    }

    public func computeMelodicPitch(degree: Int) -> UInt8 {
        let totalDegree = degree + scaleDegreeShift
        let intervals = currentScale.intervals
        let numIntervals = intervals.count
        let octaveOffset = Int(floor(Double(totalDegree) / Double(numIntervals)))
        let idxInScale = ((totalDegree % numIntervals) + numIntervals) % numIntervals
        let bumperShift = (isR1Held ? 12 : 0) - (isL1Held ? 12 : 0)
        let pitch = Int(rootKey) + octaveShift + bumperShift + (octaveOffset * 12) + intervals[idxInScale]
        return UInt8(clamp(pitch, min: 0, max: 127))
    }

    private func handleMelodicButton(index: Int, degree: Int, pressed: Bool) {
        if pressed {
            let pitch = computeMelodicPitch(degree: degree)
            activeMelodicPitches[index] = pitch
            let vel = currentVelocity()
            delegate?.notesTriggered(pitches: [pitch], velocity: vel, name: noteNameForPitch(pitch))

            let allPitches = Array(activeMelodicPitches.values).sorted()
            telemetry.playedRootPitches = allPitches
            telemetry.activeChordNotes = allPitches
            lastEventDescription = "Melodic (\(degreeName(degree))): \(noteNameForPitch(pitch)) (Vel: \(vel))"
        } else {
            if let pitch = activeMelodicPitches.removeValue(forKey: index) {
                delegate?.notesReleased(pitches: [pitch], name: noteNameForPitch(pitch))
            }
            let allPitches = Array(activeMelodicPitches.values).sorted()
            telemetry.playedRootPitches = allPitches
            telemetry.activeChordNotes = allPitches
            lastEventDescription = "Released: \(degreeName(degree))"
        }
        notifyTelemetry()
    }

    private func handleDrumButton(index: Int, pitch: UInt8, name: String, pressed: Bool) {
        if pressed {
            activeDrumPitches[index] = pitch
            let vel = currentVelocity()
            delegate?.notesTriggered(pitches: [pitch], velocity: vel, name: name)
            telemetry.playedRootPitches = [pitch]
            telemetry.activeChordNotes = [pitch]
            lastEventDescription = "Drum: \(name) (Vel: \(vel))"
        } else {
            if let p = activeDrumPitches.removeValue(forKey: index) {
                delegate?.notesReleased(pitches: [p], name: name)
            }
            telemetry.playedRootPitches.removeAll()
            telemetry.activeChordNotes.removeAll()
        }
        notifyTelemetry()
    }

    public func cycleChordInversion(forward: Bool = true) {
        let all = ChordInversion.allCases
        if let idx = all.firstIndex(of: chordInversion) {
            let nextIdx = forward ? (idx + 1) % all.count : (idx - 1 + all.count) % all.count
            chordInversion = all[nextIdx]
            telemetry.chordInversion = chordInversion
            lastEventDescription = "Inversion: \(chordInversion.rawValue)"
            revoiceActiveChord()
            notifyTelemetry()
        }
    }

    // MARK: - Face Actions (Modes & Shift Layers)
    private func handleFaceAction(buttonIndex: Int, pressed: Bool) {
        if isModeMenuHeld || isTrackSelectorHeld {
            return
        }

        switch operatingMode {
        case .melodic:
            // Face Buttons: Upper Tetrachord (Scale Degrees 4, 5, 6, 7)
            // 1: Square -> Degree 4 (5th)
            // 3: Triangle -> Degree 5 (6th)
            // 2: Circle -> Degree 6 (7th)
            // 0: Cross -> Degree 7 (8th / Octave)
            let degreeMap = [0: 7, 1: 4, 2: 6, 3: 5]
            let deg = degreeMap[buttonIndex] ?? (buttonIndex + 4)
            handleMelodicButton(index: buttonIndex + 4, degree: deg, pressed: pressed)

        case .drums:
            let drums: [Int: (UInt8, String)] = [
                0: (45, "Low Tom"),
                1: (39, "Clap"),
                2: (49, "Crash Cymbal"),
                3: (50, "High Tom")
            ]
            if let (pitch, name) = drums[buttonIndex] {
                handleDrumButton(index: buttonIndex + 4, pitch: pitch, name: name, pressed: pressed)
            }

        case .companion:
            if pressed {
                switch buttonIndex {
                case 0: toggleLatchMode()
                case 1: toggleChordMode()
                case 2: toggleArpeggiator()
                case 3: triggerPanic()
                default: break
                }
            }

        case .chords:
            if isL1Held {
                if pressed {
                    let inversions: [ChordInversion] = [.root, .first, .second, .drop2]
                    chordInversion = inversions[buttonIndex % inversions.count]
                    telemetry.chordInversion = chordInversion
                    lastEventDescription = "Voicing: \(chordInversion.rawValue)"
                    revoiceActiveChord()
                }
            } else if isR1Held {
                if pressed {
                    let patterns: [ArpPattern] = [.up, .down, .upDown, .random]
                    arpPattern = patterns[buttonIndex % patterns.count]
                    telemetry.arpPattern = arpPattern
                    lastEventDescription = "Arp Pattern: \(arpPattern.rawValue)"
                    if isArpActive { restartArpeggiator() }
                }
            } else {
                let degree = scaleDegreeForButton(index: buttonIndex)

                if pressed {
                    if let heldIdx = heldFaceButtonIndex, heldIdx != buttonIndex, !isArpActive {
                        switch buttonIndex {
                        case 1:
                            heldChordAdd7th.toggle()
                            lastEventDescription = heldChordAdd7th ? "Morph: +7th Extension" : "Morph: 7th Off"
                        case 2:
                            heldChordAdd9th.toggle()
                            lastEventDescription = heldChordAdd9th ? "Morph: +9th Extension" : "Morph: 9th Off"
                        case 3:
                            cycleChordInversion()
                        default:
                            heldChordAddSubBass.toggle()
                            lastEventDescription = heldChordAddSubBass ? "Morph: +Sub-Bass" : "Morph: Sub Off"
                        }
                        revoiceActiveChord()
                        notifyTelemetry()
                        return
                    }

                    if activeFaceButtons.isEmpty {
                        heldChordTemporaryStepShift = 0
                        heldChordAdd7th = false
                        heldChordAdd9th = false
                        heldChordAddSubBass = false
                        heldChordAddHighOctave = false
                    }
                    activeFaceButtons.insert(buttonIndex)
                    heldFaceButtonIndex = buttonIndex
                    telemetry.isHoldingChord = true
                    lastFaceDegree = degree

                    let rootPitch = computeRootPitch(forDegree: degree)
                    activeFaceRoots[buttonIndex] = rootPitch
                    let pitches = computePitches(forDegree: degree)
                    activeFacePitches[buttonIndex] = pitches

                    let combinedRoots = Array(Set(activeFaceRoots.values)).sorted()
                    latchedRoots = combinedRoots
                    telemetry.playedRootPitches = combinedRoots

                    let combinedPitches = Array(Set(activeFacePitches.values.flatMap { $0 })).sorted()
                    latchedPitches = combinedPitches
                    telemetry.activeChordNotes = combinedPitches

                    let chordLabel = chordNameForDegree(degree)
                    telemetry.activeChordName = activeFaceButtons.count > 1 ? "\(chordLabel)+ (\(combinedPitches.count) notes)" : chordLabel

                    let velocity = currentVelocity()

                    if isArpActive {
                        restartArpeggiator()
                        lastEventDescription = "Arp (\(combinedPitches.count) notes): \(combinedPitches.map { noteNameForPitch($0) }.joined(separator: " "))"
                    } else {
                        releaseCurrentlySoundingNotes()
                        playBlockChord(pitches: combinedPitches, name: telemetry.activeChordName, velocity: velocity)
                        lastEventDescription = "\(telemetry.activeChordName) (\(combinedPitches.map { noteNameForPitch($0) }.joined(separator: "-")))"
                    }
                } else {
                    activeFaceButtons.remove(buttonIndex)
                    activeFacePitches.removeValue(forKey: buttonIndex)
                    activeFaceRoots.removeValue(forKey: buttonIndex)

                    if !activeFaceButtons.isEmpty {
                        heldFaceButtonIndex = activeFaceButtons.first
                        let remainingRoots = Array(Set(activeFaceRoots.values)).sorted()
                        latchedRoots = remainingRoots
                        telemetry.playedRootPitches = remainingRoots

                        let remaining = Array(Set(activeFacePitches.values.flatMap { $0 })).sorted()
                        latchedPitches = remaining
                        telemetry.activeChordNotes = remaining

                        if isArpActive {
                            restartArpeggiator()
                            lastEventDescription = "Arp: \(remaining.map { noteNameForPitch($0) }.joined(separator: " "))"
                        } else {
                            releaseCurrentlySoundingNotes()
                            let velocity = currentVelocity()
                            playBlockChord(pitches: remaining, name: "Held Harmony", velocity: velocity)
                        }
                    } else {
                        heldFaceButtonIndex = nil
                        heldChordTemporaryStepShift = 0
                        heldChordAdd7th = false
                        heldChordAdd9th = false
                        heldChordAddSubBass = false
                        heldChordAddHighOctave = false
                        telemetry.isHoldingChord = false

                        if !latchMode {
                            if isArpActive {
                                stopArpeggiator()
                            } else {
                                releaseCurrentlySoundingNotes()
                            }
                            latchedPitches.removeAll()
                            latchedRoots.removeAll()
                            telemetry.activeChordNotes.removeAll()
                            telemetry.playedRootPitches.removeAll()
                            lastEventDescription = "Released: \(faceButtonName(buttonIndex))"
                        } else {
                            lastEventDescription = "Latched: \(telemetry.activeChordName)"
                        }
                    }
                }
            }
        }
        notifyTelemetry()
    }

    // MARK: - D-Pad Actions (Operating Modes & Navigation)
    private func handleDpadAction(direction: DpadDir, pressed: Bool) {
        guard pressed else { return }

        if isModeMenuHeld {
            let mode: OperatingMode
            switch direction {
            case .left: mode = .companion
            case .up: mode = .chords
            case .right: mode = .melodic
            case .down: mode = .drums
            }
            modeMenuDidSelect = true
            setOperatingMode(mode)
            return
        }

        if isTrackSelectorHeld {
            let trackId: Int
            switch direction {
            case .left: trackId = 1
            case .up: trackId = 2
            case .right: trackId = 3
            case .down: trackId = 4
            }
            trackSelectorDidSelect = true
            selectQwertyTrack(trackId)
            return
        }

        switch operatingMode {
        case .melodic:
            // D-Pad: Lower Tetrachord (Scale Degrees 0, 1, 2, 3)
            // Left: Degree 0 (Tonic / 1)
            // Up: Degree 1 (2nd)
            // Right: Degree 2 (3rd)
            // Down: Degree 3 (4th)
            let degreeMap: [DpadDir: (Int, Int)] = [
                .left: (0, 0),
                .up: (1, 1),
                .right: (2, 2),
                .down: (3, 3)
            ]
            if let (idx, deg) = degreeMap[direction] {
                handleMelodicButton(index: idx, degree: deg, pressed: pressed)
            }

        case .drums:
            let drums: [DpadDir: (Int, UInt8, String)] = [
                .left: (0, 36, "Bass Drum (Kick)"),
                .down: (1, 38, "Acoustic Snare"),
                .up: (2, 42, "Closed Hi-Hat"),
                .right: (3, 46, "Open Hi-Hat")
            ]
            if let (idx, pitch, name) = drums[direction] {
                handleDrumButton(index: idx, pitch: pitch, name: name, pressed: pressed)
            }

        case .companion:
            guard pressed else { return }
            switch direction {
            case .up:
                octaveShift = min(36, octaveShift + 12)
                lastEventDescription = "Octave: \(octaveShift / 12 > 0 ? "+" : "")\(octaveShift / 12)"
                broadcastStateToHammerspoon()
            case .down:
                octaveShift = max(-36, octaveShift - 12)
                lastEventDescription = "Octave: \(octaveShift / 12 > 0 ? "+" : "")\(octaveShift / 12)"
                broadcastStateToHammerspoon()
            case .left:
                scaleDegreeShift -= 1
                lastEventDescription = "Scale Transpose: -1 Step"
                broadcastStateToHammerspoon()
            case .right:
                scaleDegreeShift += 1
                lastEventDescription = "Scale Transpose: +1 Step"
                broadcastStateToHammerspoon()
            }
            revoiceActiveChord()
            notifyTelemetry()

        case .chords:
            guard pressed else { return }
            if heldFaceButtonIndex != nil {
                switch direction {
                case .up:
                    heldChordTemporaryStepShift += 1
                    lastEventDescription = "Held Chord: Step +\(heldChordTemporaryStepShift)"
                case .down:
                    heldChordTemporaryStepShift -= 1
                    lastEventDescription = "Held Chord: Step \(heldChordTemporaryStepShift)"
                case .left:
                    heldChordAddSubBass.toggle()
                    lastEventDescription = heldChordAddSubBass ? "Held: +Sub-Bass" : "Held: Sub-Bass Off"
                case .right:
                    heldChordAddHighOctave.toggle()
                    lastEventDescription = heldChordAddHighOctave ? "Held: +8va High" : "Held: 8va Off"
                }
                revoiceActiveChord()
                notifyTelemetry()
                return
            }

            if isL1Held {
                switch direction {
                case .up:
                    octaveShift = min(36, octaveShift + 12)
                    lastEventDescription = "Octave: \(octaveShift / 12 > 0 ? "+" : "")\(octaveShift / 12)"
                    broadcastStateToHammerspoon()
                case .down:
                    octaveShift = max(-36, octaveShift - 12)
                    lastEventDescription = "Octave: \(octaveShift / 12 > 0 ? "+" : "")\(octaveShift / 12)"
                    broadcastStateToHammerspoon()
                case .left:
                    scaleDegreeShift = 0
                    lastEventDescription = "Diatonic: Reset to Tonic (0)"
                    broadcastStateToHammerspoon()
                case .right:
                    rootKey = (rootKey >= 84) ? 48 : rootKey + 1
                    lastEventDescription = "Root Key: \(noteNameForPitch(rootKey))"
                    broadcastStateToHammerspoon()
                }
                revoiceActiveChord()
                notifyTelemetry()
                return
            }

            if isR1Held {
                switch direction {
                case .up:
                    bpm = min(240.0, bpm + 5.0)
                    telemetry.bpm = bpm
                    lastEventDescription = String(format: "Tempo: %.0f BPM", bpm)
                    if isArpActive { restartArpeggiator() }
                    broadcastStateToHammerspoon()
                case .down:
                    bpm = max(40.0, bpm - 5.0)
                    telemetry.bpm = bpm
                    lastEventDescription = String(format: "Tempo: %.0f BPM", bpm)
                    if isArpActive { restartArpeggiator() }
                    broadcastStateToHammerspoon()
                case .left:
                    cycleArpRate(forward: false)
                case .right:
                    cycleArpRate(forward: true)
                }
                notifyTelemetry()
                return
            }

            // Base Layer: Diatonic Scale Degree Transposition!
            switch direction {
            case .up:
                scaleDegreeShift += 1
                lastEventDescription = "Scale Transpose: +1 Step (Degree \(degreeName(scaleDegreeShift)))"
            case .down:
                scaleDegreeShift -= 1
                lastEventDescription = "Scale Transpose: -1 Step (Degree \(degreeName(scaleDegreeShift)))"
            case .left:
                scaleDegreeShift -= 3
                lastEventDescription = "Scale Transpose: -3 Steps (Degree \(degreeName(scaleDegreeShift)))"
            case .right:
                scaleDegreeShift += 3
                lastEventDescription = "Scale Transpose: +3 Steps (Degree \(degreeName(scaleDegreeShift)))"
            }
            revoiceActiveChord()
            broadcastStateToHammerspoon()
            notifyTelemetry()
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
        scaleIndex = (scaleIndex + 1) % availableScales.count
        scaleName = availableScales[scaleIndex].name
        telemetry.scaleName = scaleName
        lastEventDescription = "Scale: \(scaleName)"
        revoiceActiveChord()
        notifyTelemetry()
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
        latchedRoots.removeAll()
        activeFaceButtons.removeAll()
        activeFacePitches.removeAll()
        activeFaceRoots.removeAll()
        heldFaceButtonIndex = nil
        heldChordTemporaryStepShift = 0
        heldChordAdd7th = false
        heldChordAdd9th = false
        heldChordAddSubBass = false
        heldChordAddHighOctave = false
        telemetry.isHoldingChord = false
        telemetry.activeChordNotes.removeAll()
        telemetry.playedRootPitches.removeAll()
        telemetry.activeArpPitch = nil
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

    public func computeRootPitch(forDegree degree: Int) -> UInt8 {
        let totalDegree = degree + scaleDegreeShift + heldChordTemporaryStepShift
        let intervals = currentScale.intervals
        let numIntervals = intervals.count
        let octaveOffset = Int(floor(Double(totalDegree) / Double(numIntervals)))
        let idxInScale = ((totalDegree % numIntervals) + numIntervals) % numIntervals
        let pitch = Int(rootKey) + octaveShift + (octaveOffset * 12) + intervals[idxInScale]
        return UInt8(clamp(pitch, min: 0, max: 127))
    }

    public func computePitches(forDegree degree: Int) -> [UInt8] {
        let totalDegree = degree + scaleDegreeShift + heldChordTemporaryStepShift
        let intervals = currentScale.intervals
        let numIntervals = intervals.count

        if !chordMode {
            let octaveOffset = Int(floor(Double(totalDegree) / Double(numIntervals)))
            let idxInScale = ((totalDegree % numIntervals) + numIntervals) % numIntervals
            let pitch = Int(rootKey) + octaveShift + (octaveOffset * 12) + intervals[idxInScale]
            return [UInt8(clamp(pitch, min: 0, max: 127))]
        }

        var chordOffsets = chordType.offsets
        if heldChordAdd7th && !chordOffsets.contains(6) {
            chordOffsets.append(6)
        }
        if heldChordAdd9th && !chordOffsets.contains(8) {
            chordOffsets.append(8)
        }
        chordOffsets.sort()

        var notePitches: [Int] = chordOffsets.map { off in
            let stepIndex = totalDegree + off
            let octaveOffset = Int(floor(Double(stepIndex) / Double(numIntervals)))
            let idxInScale = ((stepIndex % numIntervals) + numIntervals) % numIntervals
            return Int(rootKey) + octaveShift + (octaveOffset * 12) + intervals[idxInScale]
        }

        // Apply Inversion / Voicing
        switch chordInversion {
        case .root:
            break
        case .first:
            if notePitches.count > 1 {
                notePitches[0] += 12
                notePitches.sort()
            }
        case .second:
            if notePitches.count > 2 {
                notePitches[0] += 12
                notePitches[1] += 12
                notePitches.sort()
            }
        case .drop2:
            if notePitches.count >= 4 {
                notePitches[notePitches.count - 2] -= 12
                notePitches.sort()
            }
        }

        // Apply Held-Chord Add-ons
        if heldChordAddSubBass {
            let lowest = notePitches.first ?? (Int(rootKey) + octaveShift)
            notePitches.insert(lowest - 12, at: 0)
        }
        if heldChordAddHighOctave {
            let highest = notePitches.last ?? (Int(rootKey) + octaveShift + 12)
            notePitches.append(highest + 12)
        }

        return notePitches.map { UInt8(clamp($0, min: 0, max: 127)) }
    }

    public func chordNameForDegree(_ degree: Int) -> String {
        let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let totalDegree = degree + scaleDegreeShift + heldChordTemporaryStepShift
        let intervals = currentScale.intervals
        let numIntervals = intervals.count

        let rootStep = totalDegree
        let rootOctaveOffset = Int(floor(Double(rootStep) / Double(numIntervals)))
        let rootIdx = ((rootStep % numIntervals) + numIntervals) % numIntervals
        let rootPitch = Int(rootKey) + (rootOctaveOffset * 12) + intervals[rootIdx]
        let rootNote = noteNames[((rootPitch % 12) + 12) % 12]

        if !chordMode { return rootNote }

        let thirdStep = totalDegree + 2
        let thirdOctaveOffset = Int(floor(Double(thirdStep) / Double(numIntervals)))
        let thirdIdx = ((thirdStep % numIntervals) + numIntervals) % numIntervals
        let thirdPitch = Int(rootKey) + (thirdOctaveOffset * 12) + intervals[thirdIdx]
        let thirdDiff = thirdPitch - rootPitch

        let fifthStep = totalDegree + 4
        let fifthOctaveOffset = Int(floor(Double(fifthStep) / Double(numIntervals)))
        let fifthIdx = ((fifthStep % numIntervals) + numIntervals) % numIntervals
        let fifthPitch = Int(rootKey) + (fifthOctaveOffset * 12) + intervals[fifthIdx]
        let fifthDiff = fifthPitch - rootPitch

        let seventhStep = totalDegree + 6
        let seventhOctaveOffset = Int(floor(Double(seventhStep) / Double(numIntervals)))
        let seventhIdx = ((seventhStep % numIntervals) + numIntervals) % numIntervals
        let seventhPitch = Int(rootKey) + (seventhOctaveOffset * 12) + intervals[seventhIdx]
        let seventhDiff = seventhPitch - rootPitch

        let suffix: String
        switch chordType {
        case .triad:
            if thirdDiff == 3 && fifthDiff == 6 {
                suffix = "dim"
            } else if thirdDiff == 3 {
                suffix = "m"
            } else if thirdDiff == 4 && fifthDiff == 8 {
                suffix = "aug"
            } else {
                suffix = "Maj"
            }
        case .seventh:
            if thirdDiff == 4 && seventhDiff == 11 {
                suffix = "Maj7"
            } else if thirdDiff == 4 && seventhDiff == 10 {
                suffix = "7"
            } else if thirdDiff == 3 && seventhDiff == 10 && fifthDiff == 6 {
                suffix = "m7♭5"
            } else if thirdDiff == 3 && seventhDiff == 10 {
                suffix = "m7"
            } else if thirdDiff == 3 && seventhDiff == 9 && fifthDiff == 6 {
                suffix = "dim7"
            } else {
                suffix = "7"
            }
        case .ninth:
            if thirdDiff == 4 && seventhDiff == 11 {
                suffix = "Maj9"
            } else if thirdDiff == 4 {
                suffix = "9"
            } else if thirdDiff == 3 {
                suffix = "m9"
            } else {
                suffix = "9"
            }
        case .sus4:
            suffix = "sus4"
        case .power:
            suffix = "5"
        }

        var name = "\(rootNote)\(suffix)"
        if heldChordAdd7th && chordType == .triad { name += " (+7)" }
        if heldChordAdd9th && (chordType == .triad || chordType == .seventh) { name += " (+9)" }
        if heldChordAddSubBass { name += " /Bass" }
        if heldChordAddHighOctave { name += " +8va" }
        return name
    }

    public func romanNumeral(forDegree degree: Int) -> String {
        let totalDegree = degree + scaleDegreeShift + heldChordTemporaryStepShift
        let intervals = currentScale.intervals
        let numIntervals = intervals.count

        let rootStep = totalDegree
        let rootOctaveOffset = Int(floor(Double(rootStep) / Double(numIntervals)))
        let rootIdx = ((rootStep % numIntervals) + numIntervals) % numIntervals
        let rootPitch = Int(rootKey) + (rootOctaveOffset * 12) + intervals[rootIdx]

        let thirdStep = totalDegree + 2
        let thirdOctaveOffset = Int(floor(Double(thirdStep) / Double(numIntervals)))
        let thirdIdx = ((thirdStep % numIntervals) + numIntervals) % numIntervals
        let thirdPitch = Int(rootKey) + (thirdOctaveOffset * 12) + intervals[thirdIdx]
        let thirdDiff = thirdPitch - rootPitch

        let fifthStep = totalDegree + 4
        let fifthOctaveOffset = Int(floor(Double(fifthStep) / Double(numIntervals)))
        let fifthIdx = ((fifthStep % numIntervals) + numIntervals) % numIntervals
        let fifthPitch = Int(rootKey) + (fifthOctaveOffset * 12) + intervals[fifthIdx]
        let fifthDiff = fifthPitch - rootPitch

        let degInScale = ((totalDegree % numIntervals) + numIntervals) % numIntervals
        let majorNumerals = ["I", "II", "III", "IV", "V", "VI", "VII"]
        let minorNumerals = ["i", "ii", "iii", "iv", "v", "vi", "vii"]

        if thirdDiff == 3 && fifthDiff == 6 {
            return "\(minorNumerals[degInScale])°"
        } else if thirdDiff == 3 {
            return minorNumerals[degInScale]
        } else if thirdDiff == 4 && fifthDiff == 8 {
            return "\(majorNumerals[degInScale])+"
        } else {
            return majorNumerals[degInScale]
        }
    }

    private func revoiceActiveChord() {
        if !activeFaceButtons.isEmpty {
            for btn in activeFaceButtons {
                let deg = scaleDegreeForButton(index: btn)
                activeFacePitches[btn] = computePitches(forDegree: deg)
                activeFaceRoots[btn] = computeRootPitch(forDegree: deg)
            }
            let combinedRoots = Array(Set(activeFaceRoots.values)).sorted()
            latchedRoots = combinedRoots
            telemetry.playedRootPitches = combinedRoots

            let combined = Array(Set(activeFacePitches.values.flatMap { $0 })).sorted()
            latchedPitches = combined
            telemetry.activeChordNotes = combined
            let chordLabel = chordNameForDegree(lastFaceDegree)
            telemetry.activeChordName = activeFaceButtons.count > 1 ? "\(chordLabel)+ (\(combined.count) notes)" : chordLabel
        } else if !latchedPitches.isEmpty {
            let root = computeRootPitch(forDegree: lastFaceDegree)
            latchedRoots = [root]
            telemetry.playedRootPitches = [root]

            let newPitches = computePitches(forDegree: lastFaceDegree)
            latchedPitches = newPitches
            telemetry.activeChordNotes = newPitches
            telemetry.activeChordName = chordNameForDegree(lastFaceDegree)
        }

        if isArpActive {
            restartArpeggiator()
        } else if !currentlySoundingPitches.isEmpty || latchMode {
            releaseCurrentlySoundingNotes()
            playBlockChord(pitches: latchedPitches, name: telemetry.activeChordName)
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
        telemetry.activeArpPitch = nil
        notifyTelemetry()
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

        let velocity = currentVelocity()

        lastArpPitch = pitch
        telemetry.currentArpStep = arpStepIndex
        telemetry.activeArpPitch = pitch
        delegate?.notesTriggered(pitches: [pitch], velocity: velocity, name: "Arp: \(noteNameForPitch(pitch))")
        notifyTelemetry()

        let stepInterval = (60.0 / bpm) * arpRate.multiplier
        let gateTime = stepInterval * 0.75
        DispatchQueue.main.asyncAfter(deadline: .now() + gateTime) { [weak self] in
            guard let self = self, let current = self.lastArpPitch, current == pitch else { return }
            self.delegate?.notesReleased(pitches: [pitch], name: "Arp Gate Off")
            self.lastArpPitch = nil
            self.telemetry.activeArpPitch = nil
            self.notifyTelemetry()
        }
    }

    private func evaluateLayerState() {
        let prevLayer = currentLayer

        switch operatingMode {
        case .melodic:
            melodicOctaveOffset = (isR1Held ? 12 : 0) - (isL1Held ? 12 : 0)
            telemetry.melodicOctaveOffset = melodicOctaveOffset
            currentLayer = .base
            setLightbarColor(red: 0.0, green: 0.85, blue: 0.95) // Cyan
        case .companion:
            currentLayer = .base
            setLightbarColor(red: 0.58, green: 0.35, blue: 0.95) // Purple
        case .drums:
            currentLayer = .base
            setLightbarColor(red: 0.95, green: 0.45, blue: 0.20) // Coral
        case .chords:
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
        }

        if prevLayer != currentLayer {
            delegate?.layerDidChange(currentLayer)
        }
    }

    // MARK: - Hammerspoon Bidirectional Synchronization
    private func setupHammerspoonSync() {
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleQwertyStateBroadcast(_:)),
            name: NSNotification.Name("QwertyMidiStateBroadcast"),
            object: nil
        )
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleQwertyNoteBroadcast(_:)),
            name: NSNotification.Name("QwertyMidiNoteBroadcast"),
            object: nil
        )
    }

    @objc private func handleQwertyStateBroadcast(_ notification: Notification) {
        guard !isInternalSyncing, let userInfo = notification.userInfo else { return }
        isInternalSyncing = true
        defer { isInternalSyncing = false }

        var stateChanged = false

        if let root = (userInfo["root"] as? NSNumber)?.intValue ?? (userInfo["root"] as? Int) {
            let targetKey = UInt8(clamp(root + 60, min: 24, max: 96))
            if self.rootKey != targetKey {
                self.rootKey = targetKey
                stateChanged = true
            }
        }
        if let scaleIdx = (userInfo["scaleIdx"] as? NSNumber)?.intValue ?? (userInfo["scaleIdx"] as? Int) {
            let validIdx = scaleIdx % availableScales.count
            if self.scaleIndex != validIdx {
                self.scaleIndex = validIdx
                self.scaleName = availableScales[validIdx].name
                stateChanged = true
            }
        }
        if let bpmVal = (userInfo["bpm"] as? NSNumber)?.doubleValue ?? (userInfo["bpm"] as? Double) {
            if abs(self.bpm - bpmVal) > 0.5 {
                self.bpm = bpmVal
                stateChanged = true
            }
        }
        if let oct = (userInfo["octaveShift"] as? NSNumber)?.intValue ?? (userInfo["octaveShift"] as? Int) {
            if self.octaveShift != oct {
                self.octaveShift = oct
                stateChanged = true
            }
        }
        if let chord = (userInfo["chordIdx"] as? NSNumber)?.intValue ?? (userInfo["chordIdx"] as? Int) {
            let allChords = ChordType.allCases
            if chord >= 0 && chord < allChords.count && self.chordType != allChords[chord] {
                self.chordType = allChords[chord]
                stateChanged = true
            }
        }
        if let track = (userInfo["activeTrack"] as? NSNumber)?.intValue ?? (userInfo["activeTrack"] as? Int) {
            let validTrack = Int(clamp(track, min: 1, max: 4))
            if self.qwertyTrackId != validTrack {
                self.qwertyTrackId = validTrack
                self.telemetry.qwertyTrackId = validTrack
                stateChanged = true
            }
        }

        self.telemetry.isSyncedWithQwerty = true
        self.isSyncedWithQwerty = true
        if stateChanged {
            self.lastEventDescription = "🔗 Synced: \(self.noteNameForPitch(self.rootKey)) \(self.scaleName)"
            self.syncTelemetryEngineState()
            self.revoiceActiveChord()
        }
        self.notifyTelemetry()
    }

    @objc private func handleQwertyNoteBroadcast(_ notification: Notification) {
        guard let userInfo = notification.userInfo else { return }
        let isNoteOn = (userInfo["isNoteOn"] as? Bool) ?? false
        var notes: [UInt8] = []

        if let rawArray = userInfo["pitches"] as? [Any] {
            notes = rawArray.compactMap { item in
                if let num = item as? NSNumber { return num.uint8Value }
                if let intVal = item as? Int { return UInt8(clamping: intVal) }
                return nil
            }
        } else if let singleNum = (userInfo["pitches"] as? NSNumber)?.uint8Value {
            notes = [singleNum]
        } else if let singleInt = userInfo["pitches"] as? Int {
            notes = [UInt8(clamping: singleInt)]
        }

        if !notes.isEmpty {
            if isNoteOn {
                self.telemetry.playedRootPitches = notes
                self.telemetry.activeChordNotes = notes
            } else {
                if !self.latchMode && self.operatingMode != .melodic {
                    self.telemetry.playedRootPitches.removeAll()
                    self.telemetry.activeChordNotes.removeAll()
                }
            }
            self.telemetry.isSyncedWithQwerty = true
            self.isSyncedWithQwerty = true
            self.notifyTelemetry()
        }
    }

    public func broadcastStateToHammerspoon() {
        guard !isInternalSyncing else { return }
        let rootOffset = (Int(rootKey) - 60) % 12
        let rootNormalized = (rootOffset + 12) % 12
        let payload: [String: Any] = [
            "root": rootNormalized,
            "scaleIdx": scaleIndex,
            "scaleName": scaleName,
            "bpm": bpm,
            "octaveShift": octaveShift,
            "chordIdx": ChordType.allCases.firstIndex(of: chordType) ?? 0,
            "operatingMode": operatingMode.rawValue,
            "activeTrack": qwertyTrackId
        ]
        DistributedNotificationCenter.default().post(
            name: NSNotification.Name("DualSynthStateBroadcast"),
            object: nil,
            userInfo: payload
        )
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
