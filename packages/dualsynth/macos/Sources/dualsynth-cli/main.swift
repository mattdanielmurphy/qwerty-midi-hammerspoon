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

    func notesTriggered(pitches: [UInt8], velocity: UInt8, name: String) {
        print("🎵 NOTES ON  -> \(name) | Pitches: \(pitches) | Velocity: \(velocity) | Track \(controller.qwertyTrackId)")
        midi.sendNotesOn(pitches: pitches, velocity: velocity, channel: controller.selectedTrackMIDIChannel)
    }

    func notesReleased(pitches: [UInt8], name: String) {
        print("🔇 NOTES OFF -> \(name) | Pitches: \(pitches)")
        midi.sendNotesOff(pitches: pitches, channel: controller.selectedTrackMIDIChannel)
    }

    func continuousParamChanged(cc: UInt8, value: UInt8, name: String) {
        print("🎛️ CC #\(cc) [\(name)] -> \(value) | Track \(controller.qwertyTrackId)")
        midi.sendCC(controller: cc, value: value, channel: controller.selectedTrackMIDIChannel)
    }

    func pitchBendChanged(value: UInt16) {
        print("〰️ PITCH BEND -> \(value)")
        midi.sendPitchBend(value: value, channel: controller.selectedTrackMIDIChannel)
    }

    func panicTriggered() {
        print("🚨 PANIC -> All Notes Off")
        for channel: UInt8 in 0...3 {
            midi.allNotesOff(channel: channel)
        }
    }

    func telemetryUpdated(_ telemetry: ControllerTelemetry) {
        // Detailed telemetry for CLI runner
    }
}

let coordinator = DualSynthCoordinator()
RunLoop.main.run()
