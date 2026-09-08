import SwiftUI
import AppKit
import DualSynthCore

final class AppDelegate: NSObject, NSApplicationDelegate, DualSynthDelegate {
    var window: NSWindow!
    let midi = MIDIEngine(clientName: "DualSynth GUI", endpointName: "DualSynth Virtual Out")
    let controller = ControllerManager()

    func applicationDidFinishLaunching(_ notification: Notification) {
        controller.delegate = self

        let contentView = DualSenseHUDView(controller: controller, midi: midi)

        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 860, height: 680),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.minSize = NSSize(width: 760, height: 540)
        window.title = "DualSynth Studio HUD"
        window.contentView = NSHostingView(rootView: contentView)
        window.level = .floating // Keep on top so user can see it while playing in Logic Pro!
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)

        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    // DualSynthDelegate
    func controllerDidConnect(_ name: String, isDualSense: Bool) {
        print("🟢 GUI Connected: \(name)")
    }

    func controllerDidDisconnect() {
        print("🔴 GUI Controller Disconnected")
    }

    func layerDidChange(_ layer: ControlLayer) {
        // UI automatically updates via @ObservedObject controller
    }

    func notesTriggered(pitches: [UInt8], velocity: UInt8, name: String) {
        midi.sendNotesOn(pitches: pitches, velocity: velocity)
    }

    func notesReleased(pitches: [UInt8], name: String) {
        midi.sendNotesOff(pitches: pitches)
    }

    func continuousParamChanged(cc: UInt8, value: UInt8, name: String) {
        midi.sendCC(controller: cc, value: value)
    }

    func panicTriggered() {
        midi.allNotesOff()
    }

    func telemetryUpdated(_ telemetry: ControllerTelemetry) {
        // Handled reactively by SwiftUI
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
