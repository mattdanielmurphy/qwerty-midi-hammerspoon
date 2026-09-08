import Foundation
import DualSynthCore

setbuf(stdout, nil)

final class DualSynthCoordinator: DualSynthDelegate {
    let midi = MIDIEngine(clientName: "DualSynth Daemon", endpointName: "DualSynth Virtual Out")
    let controller = ControllerManager()

    init() {
        controller.delegate = self
        print("🎮 DualSynth Phase 0 Daemon Started.")
        print("📡 Listening for Sony DualSense (Background event monitoring: ENABLED)")
        print("🎹 Virtual CoreMIDI Destination: 'DualSynth Virtual Out'")
        print("💡 Lightbar confirms active layer: Green (Base), Blue (L1 Harmony), Amber (R1 Looper)")
        print("Press Ctrl+C to stop.\n")
    }

    func controllerDidConnect(_ name: String, isDualSense: Bool) {
        print("🟢 Controller Connected: \(name) [DualSense: \(isDualSense)]")
        print("   Ready for input! Press ✕, □, ○, △ or squeeze triggers.")
    }

    func controllerDidDisconnect() {
        print("🔴 Controller Disconnected.")
    }

    func layerDidChange(_ layer: ControlLayer) {
        print("🔀 Layer Switched -> [\(layer.rawValue)]")
    }

    func noteTriggered(pitch: UInt8, velocity: UInt8, name: String) {
        print("🎵 NOTE ON  -> \(name) | Pitch: \(pitch) | Velocity: \(velocity)")
        midi.sendNoteOn(pitch: pitch, velocity: velocity)
    }

    func noteReleased(pitch: UInt8, name: String) {
        print("🔇 NOTE OFF -> \(name) | Pitch: \(pitch)")
        midi.sendNoteOff(pitch: pitch)
    }

    func continuousParamChanged(cc: UInt8, value: UInt8, name: String) {
        print("🎛️ CC #\(cc) [\(name)] -> \(value)")
        midi.sendCC(controller: cc, value: value)
    }

    func telemetryUpdated(_ telemetry: ControllerTelemetry) {
        // Detailed telemetry for CLI runner
    }
}

let coordinator = DualSynthCoordinator()
RunLoop.main.run()
