import SwiftUI
import AppKit
import DualSynthCore

final class AppDelegate: NSObject, NSApplicationDelegate, DualSynthDelegate {
    var window: NSWindow!
    let midi = MIDIEngine(clientName: "DualSynth GUI", endpointName: "DualSynth Virtual Out")
    let controller = ControllerManager()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        controller.delegate = self

        setupMainMenu()

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
        window.level = .normal // Normal window level (does NOT float over other apps)
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)

        NSApp.activate(ignoringOtherApps: true)
    }

    private func setupMainMenu() {
        let mainMenu = NSMenu()

        // Application Menu
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu(title: "DualSynth")
        appMenu.addItem(withTitle: "About DualSynth", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Hide DualSynth", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        let hideOthersItem = NSMenuItem(title: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthersItem.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(hideOthersItem)
        appMenu.addItem(withTitle: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Quit DualSynth", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        // Window Menu
        let windowMenuItem = NSMenuItem()
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Close Window", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Zoom", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        windowMenu.addItem(NSMenuItem.separator())
        windowMenu.addItem(withTitle: "Bring All to Front", action: #selector(NSApplication.arrangeInFront(_:)), keyEquivalent: "")
        windowMenuItem.submenu = windowMenu
        mainMenu.addItem(windowMenuItem)

        NSApp.mainMenu = mainMenu
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

    func pitchBendChanged(value: UInt16) {
        midi.sendPitchBend(value: value)
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
