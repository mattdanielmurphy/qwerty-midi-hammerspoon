import Foundation
import DualSynthCore

setbuf(stdout, nil)

final class DualSynthCoordinator: DualSynthDelegate {
    let midi = MIDIEngine(clientName: "DualSynth Daemon", endpointName: "DualSynth Virtual Out")
    let controller = ControllerManager()

    init() {
        controller.delegate = self
        print("🎮 DualSynth Phase 0 Daemon Started.")
        print("📡 Listening for Sony DualSense connection via Bluetooth/USB...")
        print("🎹 Virtual CoreMIDI Destination: 'DualSynth Virtual Out'")
        print("Press Ctrl+C to stop.\n")
    }

    func controllerDidConnect(_ name: String) {
        print("🟢 Controller Connected: \(name)")
    }

    func controllerDidDisconnect() {
        print("🔴 Controller Disconnected.")
    }

    func layerDidChange(_ layer: ControlLayer) {
        print("🔀 Layer Switched: [\(layer.rawValue)]")
    }

    func noteTriggered(pitch: UInt8, velocity: UInt8) {
        print("🎵 Note ON  -> Pitch: \(pitch), Vel: \(velocity)")
        midi.sendNoteOn(pitch: pitch, velocity: velocity)
    }

    func noteReleased(pitch: UInt8) {
        print("🔇 Note OFF -> Pitch: \(pitch)")
        midi.sendNoteOff(pitch: pitch)
    }

    func continuousParamChanged(cc: UInt8, value: UInt8) {
        print("🎛️ CC #\(cc) -> \(value)")
        midi.sendCC(controller: cc, value: value)
    }
}

let coordinator = DualSynthCoordinator()
RunLoop.main.run()
