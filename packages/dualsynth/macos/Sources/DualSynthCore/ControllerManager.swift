import Foundation
import GameController

public enum ControlLayer: String {
    case base = "Base"
    case harmony = "Harmony (L1)"
    case looper = "Looper (R1)"
    case parameters = "FX / Synth (L1+R1)"
}

public protocol DualSynthDelegate: AnyObject {
    func controllerDidConnect(_ name: String)
    func controllerDidDisconnect()
    func layerDidChange(_ layer: ControlLayer)
    func noteTriggered(pitch: UInt8, velocity: UInt8)
    func noteReleased(pitch: UInt8)
    func continuousParamChanged(cc: UInt8, value: UInt8)
}

public final class ControllerManager {
    public weak var delegate: DualSynthDelegate?
    private var activeController: GCController?
    public private(set) var currentLayer: ControlLayer = .base
    public var rootKey: UInt8 = 60 // C4 default

    // Modifier states
    private var l1Held: Bool = false
    private var r1Held: Bool = false

    public init() {
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

        GCController.startWirelessControllerDiscovery {
            // Background discovery
        }
    }

    @objc private func handleControllerDidConnect(notification: Notification) {
        guard let controller = notification.object as? GCController else { return }
        self.activeController = controller
        setupControllerBindings(controller)
        delegate?.controllerDidConnect(controller.vendorName ?? "DualSense Controller")
        setLightbarColor(red: 0.06, green: 0.72, blue: 0.51) // Green for base
    }

    @objc private func handleControllerDidDisconnect(notification: Notification) {
        self.activeController = nil
        delegate?.controllerDidDisconnect()
    }

    private func setupControllerBindings(_ controller: GCController) {
        guard let gamepad = controller.extendedGamepad else { return }

        // Momentary Shoulder Modifiers (L1 / R1)
        gamepad.leftShoulder.valueChangedHandler = { [weak self] (_, _, pressed) in
            self?.l1Held = pressed
            self?.evaluateLayerState()
        }

        gamepad.rightShoulder.valueChangedHandler = { [weak self] (_, _, pressed) in
            self?.r1Held = pressed
            self?.evaluateLayerState()
        }

        // Face Buttons: Diatonic scale notes or chord triggers
        gamepad.buttonA.valueChangedHandler = { [weak self] (_, _, pressed) in
            self?.handleFaceButton(degree: 0, pressed: pressed) // Root / I (Cross)
        }
        gamepad.buttonX.valueChangedHandler = { [weak self] (_, _, pressed) in
            self?.handleFaceButton(degree: 2, pressed: pressed) // II (Square)
        }
        gamepad.buttonB.valueChangedHandler = { [weak self] (_, _, pressed) in
            self?.handleFaceButton(degree: 4, pressed: pressed) // III (Circle)
        }
        gamepad.buttonY.valueChangedHandler = { [weak self] (_, _, pressed) in
            self?.handleFaceButton(degree: 5, pressed: pressed) // IV (Triangle)
        }

        // Analog Triggers (L2 = CC #74 Filter, R2 = Gate/Velocity)
        gamepad.leftTrigger.valueChangedHandler = { [weak self] (_, value, _) in
            let ccVal = UInt8(value * 127)
            self?.delegate?.continuousParamChanged(cc: 74, value: ccVal)
        }

        // Left Thumbstick: Pitch Bend & Mod
        gamepad.leftThumbstick.valueChangedHandler = { [weak self] (_, xVal, yVal) in
            // Map X (-1.0 to 1.0) to Pitch Bend (0..16383), center 8192
            // Map Y to Mod Wheel CC #1
            let modVal = UInt8(max(0, yVal) * 127)
            self?.delegate?.continuousParamChanged(cc: 1, value: modVal)
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

    private func handleFaceButton(degree: UInt8, pressed: Bool) {
        let pitch = rootKey + degree
        if pressed {
            // Read R2 analog trigger for dynamic velocity (default to 100 if trigger not depressed)
            let triggerVal = activeController?.extendedGamepad?.rightTrigger.value ?? 0.0
            let velocity: UInt8 = triggerVal > 0.05 ? UInt8(triggerVal * 127) : 100
            delegate?.noteTriggered(pitch: pitch, velocity: velocity)
        } else {
            delegate?.noteReleased(pitch: pitch)
        }
    }

    public func setLightbarColor(red: Float, green: Float, blue: Float) {
        guard let light = activeController?.light else { return }
        light.color = GCColor(red: red, green: green, blue: blue)
    }
}
