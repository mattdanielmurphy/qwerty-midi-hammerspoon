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
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 500),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "DualSynth Controller HUD"
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

    func noteTriggered(pitch: UInt8, velocity: UInt8, name: String) {
        midi.sendNoteOn(pitch: pitch, velocity: velocity)
    }

    func noteReleased(pitch: UInt8, name: String) {
        midi.sendNoteOff(pitch: pitch)
    }

    func continuousParamChanged(cc: UInt8, value: UInt8, name: String) {
        midi.sendCC(controller: cc, value: value)
    }

    func telemetryUpdated(_ telemetry: ControllerTelemetry) {
        // Handled reactively by SwiftUI
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
