import Foundation
import GameController

public enum ControlLayer: String, CaseIterable {
    case base = "Base Play"
    case harmony = "Harmony (L1)"
    case looper = "Looper (R1)"
    case parameters = "FX / Synth (L1+R1)"
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
    public var touchpad: Bool = false

    public init() {}
}

public protocol DualSynthDelegate: AnyObject {
    func controllerDidConnect(_ name: String, isDualSense: Bool)
    func controllerDidDisconnect()
    func layerDidChange(_ layer: ControlLayer)
    func noteTriggered(pitch: UInt8, velocity: UInt8, name: String)
    func noteReleased(pitch: UInt8, name: String)
    func continuousParamChanged(cc: UInt8, value: UInt8, name: String)
    func telemetryUpdated(_ telemetry: ControllerTelemetry)
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

    // Modifier states
    private var l1Held: Bool = false
    private var r1Held: Bool = false

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
    }

    @objc private func handleControllerDidConnect(notification: Notification) {
        guard let controller = notification.object as? GCController else { return }
        attachController(controller)
    }

    @objc private func handleControllerDidDisconnect(notification: Notification) {
        guard let controller = notification.object as? GCController,
              controller == activeController else { return }
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
        delegate?.controllerDidConnect(name, isDualSense: isDS)
        setLightbarColor(red: 0.06, green: 0.72, blue: 0.51) // Green Base
    }

    private func setupControllerBindings(_ controller: GCController) {
        guard let gamepad = controller.extendedGamepad else { return }

        // 1. Shoulder Modifiers (L1 / R1)
        gamepad.leftShoulder.valueChangedHandler = { [weak self] (_, value, pressed) in
            guard let self = self else { return }
            self.l1Held = pressed
            self.telemetry.l1 = pressed
            self.evaluateLayerState()
            self.notifyTelemetry()
        }

        gamepad.rightShoulder.valueChangedHandler = { [weak self] (_, value, pressed) in
            guard let self = self else { return }
            self.r1Held = pressed
            self.telemetry.r1 = pressed
            self.evaluateLayerState()
            self.notifyTelemetry()
        }

        // 2. Face Buttons (Cross=I, Square=II, Circle=III, Triangle=IV)
        gamepad.buttonA.valueChangedHandler = { [weak self] (_, _, pressed) in
            self?.telemetry.cross = pressed
            self?.handleFaceButton(degree: 0, name: "✕ Cross (I)", pressed: pressed)
        }
        gamepad.buttonX.valueChangedHandler = { [weak self] (_, _, pressed) in
            self?.telemetry.square = pressed
            self?.handleFaceButton(degree: 2, name: "□ Square (II)", pressed: pressed)
        }
        gamepad.buttonB.valueChangedHandler = { [weak self] (_, _, pressed) in
            self?.telemetry.circle = pressed
            self?.handleFaceButton(degree: 4, name: "○ Circle (III)", pressed: pressed)
        }
        gamepad.buttonY.valueChangedHandler = { [weak self] (_, _, pressed) in
            self?.telemetry.triangle = pressed
            self?.handleFaceButton(degree: 5, name: "△ Triangle (IV)", pressed: pressed)
        }

        // 3. D-Pad
        gamepad.dpad.up.valueChangedHandler = { [weak self] (_, _, pressed) in
            guard let self = self else { return }
            self.telemetry.dpadUp = pressed
            if pressed { self.octaveShift = min(36, self.octaveShift + 12) }
            self.notifyTelemetry()
        }
        gamepad.dpad.down.valueChangedHandler = { [weak self] (_, _, pressed) in
            guard let self = self else { return }
            self.telemetry.dpadDown = pressed
            if pressed { self.octaveShift = max(-36, self.octaveShift - 12) }
            self.notifyTelemetry()
        }
        gamepad.dpad.left.valueChangedHandler = { [weak self] (_, _, pressed) in
            guard let self = self else { return }
            self.telemetry.dpadLeft = pressed
            if pressed { self.rootKey = max(36, self.rootKey - 1) }
            self.notifyTelemetry()
        }
        gamepad.dpad.right.valueChangedHandler = { [weak self] (_, _, pressed) in
            guard let self = self else { return }
            self.telemetry.dpadRight = pressed
            if pressed { self.rootKey = min(84, self.rootKey + 1) }
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
                self?.telemetry.l3 = pressed
                self?.notifyTelemetry()
            }
        }
        if let r3Btn = gamepad.rightThumbstickButton {
            r3Btn.valueChangedHandler = { [weak self] (_, _, pressed) in
                self?.telemetry.r3 = pressed
                self?.notifyTelemetry()
            }
        }

        // 8. Options, Menu, Touchpad Buttons
        if let opt = gamepad.buttonOptions {
            opt.valueChangedHandler = { [weak self] (_, _, pressed) in
                self?.telemetry.create = pressed
                self?.notifyTelemetry()
            }
        }
        gamepad.buttonMenu.valueChangedHandler = { [weak self] (_, _, pressed) in
            self?.telemetry.options = pressed
            self?.notifyTelemetry()
        }
        if let home = gamepad.buttonHome {
            home.valueChangedHandler = { [weak self] (_, _, pressed) in
                self?.telemetry.home = pressed
                self?.notifyTelemetry()
            }
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

    private func handleFaceButton(degree: UInt8, name: String, pressed: Bool) {
        let pitch = UInt8(clamp(Int(rootKey) + octaveShift + Int(degree), min: 0, max: 127))
        if pressed {
            let triggerVal = telemetry.rightTrigger
            let velocity: UInt8 = triggerVal > 0.05 ? UInt8(triggerVal * 127) : 100
            lastEventDescription = "NOTE ON: \(name) (\(pitch)) Vel: \(velocity)"
            delegate?.noteTriggered(pitch: pitch, velocity: velocity, name: name)
        } else {
            lastEventDescription = "NOTE OFF: \(name) (\(pitch))"
            delegate?.noteReleased(pitch: pitch, name: name)
        }
        notifyTelemetry()
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
