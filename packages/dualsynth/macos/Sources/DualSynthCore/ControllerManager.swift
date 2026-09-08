import Foundation
import GameController

public enum ControlLayer: String {
    case base = "Base"
    case harmony = "Harmony (L1)"
    case looper = "Looper (R1)"
    case parameters = "FX / Synth (L1+R1)"
}

public protocol DualSynthDelegate: AnyObject {
    func controllerDidConnect(_ name: String, isDualSense: Bool)
    func controllerDidDisconnect()
    func layerDidChange(_ layer: ControlLayer)
    func noteTriggered(pitch: UInt8, velocity: UInt8, name: String)
    func noteReleased(pitch: UInt8, name: String)
    func continuousParamChanged(cc: UInt8, value: UInt8, name: String)
    func rawInputEvent(name: String, value: Float)
}

public final class ControllerManager {
    public weak var delegate: DualSynthDelegate?
    public private(set) var activeController: GCController?
    public private(set) var currentLayer: ControlLayer = .base
    public var rootKey: UInt8 = 60 // C4 default
    public var octaveShift: Int = 0

    // Modifier states
    private var l1Held: Bool = false
    private var r1Held: Bool = false

    public init() {
        // MANDATORY: Enable background event monitoring so CLI & non-GUI processes receive gamepad inputs!
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

        // Check if controller is already connected at initialization time
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
        delegate?.controllerDidDisconnect()
    }

    private func attachController(_ controller: GCController) {
        self.activeController = controller
        controller.handlerQueue = .main

        let isDualSense = controller.extendedGamepad is GCDualSenseGamepad
        let name = controller.vendorName ?? (isDualSense ? "Sony DualSense" : "Gamepad")

        setupControllerBindings(controller)
        delegate?.controllerDidConnect(name, isDualSense: isDualSense)

        // Set initial lightbar color to Green (Base Mode)
        setLightbarColor(red: 0.06, green: 0.72, blue: 0.51)
    }

    private func setupControllerBindings(_ controller: GCController) {
        guard let gamepad = controller.extendedGamepad else { return }

        // 1. Momentary Shoulder Modifiers (L1 / R1)
        gamepad.leftShoulder.valueChangedHandler = { [weak self] (_, value, pressed) in
            self?.l1Held = pressed
            self?.evaluateLayerState()
            self?.delegate?.rawInputEvent(name: "L1 (Shoulder)", value: value)
        }

        gamepad.rightShoulder.valueChangedHandler = { [weak self] (_, value, pressed) in
            self?.r1Held = pressed
            self?.evaluateLayerState()
            self?.delegate?.rawInputEvent(name: "R1 (Shoulder)", value: value)
        }

        // 2. Face Buttons: Diatonic scale degrees (Cross=I, Square=II, Circle=III, Triangle=IV)
        gamepad.buttonA.valueChangedHandler = { [weak self] (_, value, pressed) in
            self?.handleFaceButton(degree: 0, name: "✕ (Cross / Degree I)", pressed: pressed)
        }
        gamepad.buttonX.valueChangedHandler = { [weak self] (_, value, pressed) in
            self?.handleFaceButton(degree: 2, name: "□ (Square / Degree II)", pressed: pressed)
        }
        gamepad.buttonB.valueChangedHandler = { [weak self] (_, value, pressed) in
            self?.handleFaceButton(degree: 4, name: "○ (Circle / Degree III)", pressed: pressed)
        }
        gamepad.buttonY.valueChangedHandler = { [weak self] (_, value, pressed) in
            self?.handleFaceButton(degree: 5, name: "△ (Triangle / Degree IV)", pressed: pressed)
        }

        // 3. D-Pad: Octave and Root Transposition
        gamepad.dpad.up.valueChangedHandler = { [weak self] (_, _, pressed) in
            guard let self = self, pressed else { return }
            self.octaveShift = min(36, self.octaveShift + 12)
            self.delegate?.rawInputEvent(name: "D-Pad Up (Octave +1)", value: Float(self.octaveShift))
        }
        gamepad.dpad.down.valueChangedHandler = { [weak self] (_, _, pressed) in
            guard let self = self, pressed else { return }
            self.octaveShift = max(-36, self.octaveShift - 12)
            self.delegate?.rawInputEvent(name: "D-Pad Down (Octave -1)", value: Float(self.octaveShift))
        }
        gamepad.dpad.left.valueChangedHandler = { [weak self] (_, _, pressed) in
            guard let self = self, pressed else { return }
            self.rootKey = max(36, self.rootKey - 1)
            self.delegate?.rawInputEvent(name: "D-Pad Left (Root -1)", value: Float(self.rootKey))
        }
        gamepad.dpad.right.valueChangedHandler = { [weak self] (_, _, pressed) in
            guard let self = self, pressed else { return }
            self.rootKey = min(84, self.rootKey + 1)
            self.delegate?.rawInputEvent(name: "D-Pad Right (Root +1)", value: Float(self.rootKey))
        }

        // 4. Analog Triggers
        // L2: Continuous Filter Cutoff (MIDI CC #74)
        gamepad.leftTrigger.valueChangedHandler = { [weak self] (_, value, _) in
            let ccVal = UInt8(value * 127)
            self?.delegate?.continuousParamChanged(cc: 74, value: ccVal, name: "L2 Trigger -> Filter Cutoff")
        }

        // R2: Monitored for dynamic velocity gating
        gamepad.rightTrigger.valueChangedHandler = { [weak self] (_, value, _) in
            if value > 0.05 {
                self?.delegate?.rawInputEvent(name: "R2 Trigger (Velocity Gate)", value: value)
            }
        }

        // 5. Thumbsticks
        // Left Stick: Pitch Bend (X) & Modulation (Y)
        gamepad.leftThumbstick.valueChangedHandler = { [weak self] (_, xVal, yVal) in
            if abs(yVal) > 0.05 {
                let modVal = UInt8(max(0, yVal) * 127)
                self?.delegate?.continuousParamChanged(cc: 1, value: modVal, name: "Left Stick Y -> Modulation")
            }
        }

        // 6. Thumbstick Clicks (L3 & R3)
        if let leftThumbstickButton = gamepad.leftThumbstickButton {
            leftThumbstickButton.valueChangedHandler = { [weak self] (_, _, pressed) in
                if pressed { self?.delegate?.rawInputEvent(name: "L3 Click (Arp Latch Toggle)", value: 1.0) }
            }
        }
        if let rightThumbstickButton = gamepad.rightThumbstickButton {
            rightThumbstickButton.valueChangedHandler = { [weak self] (_, _, pressed) in
                if pressed { self?.delegate?.rawInputEvent(name: "R3 Click (Tap Tempo)", value: 1.0) }
            }
        }

        // 7. Universal Physical Input Profile Fallback
        // Ensures that ANY button or touch event generates telemetry
        controller.physicalInputProfile.valueDidChangeHandler = { [weak self] (_, element) in
            if let button = element as? GCControllerButtonInput, button.isPressed {
                let elemName = element.sfSymbolsName ?? element.aliases.first ?? "Button"
                self?.delegate?.rawInputEvent(name: elemName, value: button.value)
            }
        }
    }

    private func evaluateLayerState() {
        let prevLayer = currentLayer
        if l1Held && r1Held {
            currentLayer = .parameters
            setLightbarColor(red: 0.92, green: 0.28, blue: 0.60) // Magenta/Pink
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
            // Read R2 analog trigger for dynamic velocity (default to 100 if trigger not depressed)
            let triggerVal = activeController?.extendedGamepad?.rightTrigger.value ?? 0.0
            let velocity: UInt8 = triggerVal > 0.05 ? UInt8(triggerVal * 127) : 100
            delegate?.noteTriggered(pitch: pitch, velocity: velocity, name: name)
        } else {
            delegate?.noteReleased(pitch: pitch, name: name)
        }
    }

    public func setLightbarColor(red: Float, green: Float, blue: Float) {
        guard let light = activeController?.light else { return }
        light.color = GCColor(red: red, green: green, blue: blue)
    }

    private func clamp<T: Comparable>(_ val: T, min minVal: T, max maxVal: T) -> T {
        return max(minVal, min(maxVal, val))
    }
}
