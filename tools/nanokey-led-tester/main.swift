import Foundation
import CoreMIDI

// ==============================================================================
// Korg nanoKEY Studio — Hardware Key LED Verification & Scale Guide Tester
// ==============================================================================

struct Colors {
    static let reset   = "\u{001B}[0m"
    static let bold    = "\u{001B}[1m"
    static let dim     = "\u{001B}[2m"
    static let red     = "\u{001B}[31m"
    static let green   = "\u{001B}[32m"
    static let yellow  = "\u{001B}[33m"
    static let blue    = "\u{001B}[34m"
    static let magenta = "\u{001B}[35m"
    static let cyan    = "\u{001B}[36m"
    static let white   = "\u{001B}[37m"
}

class NanoKeyLedTest {
    var client = MIDIClientRef()
    var outPort = MIDIPortRef()
    var inPort = MIDIPortRef()
    var destEndpoint: MIDIEndpointRef = 0
    var sourceEndpoint: MIDIEndpointRef = 0
    var deviceName: String = ""

    init() {
        setupMidi()
    }

    func setupMidi() {
        var status = MIDIClientCreate("NanoKeyLedTest" as CFString, nil, nil, &client)
        guard status == 0 else {
            print("\(Colors.red)Failed to create MIDI client (status \(status))\(Colors.reset)")
            exit(1)
        }

        status = MIDIOutputPortCreate(client, "LedTestOut" as CFString, &outPort)
        guard status == 0 else {
            print("\(Colors.red)Failed to create MIDI output port (status \(status))\(Colors.reset)")
            exit(1)
        }

        findEndpoints()

        guard destEndpoint != 0 else {
            print("\(Colors.red)Error: nanoKEY Studio destination not detected in CoreMIDI.\(Colors.reset)")
            print("\(Colors.yellow)Please ensure the controller is powered on and paired/connected via Bluetooth or USB.\(Colors.reset)")
            print("\(Colors.dim)Available destinations:\(Colors.reset)")
            let numDst = MIDIGetNumberOfDestinations()
            for i in 0..<numDst {
                let dst = MIDIGetDestination(i)
                print("  - \(getEndpointName(dst))")
            }
            exit(1)
        }

        print("\(Colors.green)✓ Connected to destination: \(Colors.bold)\(deviceName)\(Colors.reset)")
    }

    func findEndpoints() {
        let numDst = MIDIGetNumberOfDestinations()
        for i in 0..<numDst {
            let dst = MIDIGetDestination(i)
            let name = getEndpointName(dst)
            if name.localizedCaseInsensitiveContains("nanokey") {
                destEndpoint = dst
                deviceName = name
                break
            }
        }
    }

    func getEndpointName(_ endpoint: MIDIEndpointRef) -> String {
        var name: Unmanaged<CFString>?
        MIDIObjectGetStringProperty(endpoint, kMIDIPropertyDisplayName, &name)
        if name == nil {
            MIDIObjectGetStringProperty(endpoint, kMIDIPropertyName, &name)
        }
        return (name?.takeRetainedValue() as String?) ?? "Unknown"
    }

    func sendBytes(_ bytes: [UInt8]) {
        var packetList = MIDIPacketList()
        var curPacket = MIDIPacketListInit(&packetList)
        curPacket = MIDIPacketListAdd(&packetList, 1024, curPacket, 0, bytes.count, bytes)
        let _ = MIDISend(outPort, destEndpoint, &packetList)
    }

    func sendNoteOn(note: UInt8, velocity: UInt8 = 127, channel: UInt8 = 0) {
        sendBytes([0x90 | (channel & 0x0F), note & 0x7F, velocity & 0x7F])
    }

    func sendNoteOff(note: UInt8, channel: UInt8 = 0) {
        sendBytes([0x80 | (channel & 0x0F), note & 0x7F, 0])
    }

    func sendSysex(_ hexStr: String) {
        let clean = hexStr.replacingOccurrences(of: " ", with: "")
        var bytes = [UInt8]()
        var idx = clean.startIndex
        while idx < clean.endIndex {
            let nextIdx = clean.index(idx, offsetBy: 2)
            if let b = UInt8(clean[idx..<nextIdx], radix: 16) {
                bytes.append(b)
            }
            idx = nextIdx
        }
        sendBytes(bytes)
    }

    func allNotesOff() {
        for n: UInt8 in 48...72 {
            sendNoteOff(note: n)
        }
    }

    // Pattern 1: Chromatic sweep
    func runChromaticSweep() {
        print("\n\(Colors.cyan)--> Running Chromatic LED Sweep (Notes 48 to 72)...\(Colors.reset)")
        allNotesOff()
        for n: UInt8 in 48...72 {
            print("  Illuminating Note #\(n)...", terminator: "\r")
            fflush(stdout)
            sendNoteOn(note: n, velocity: 127)
            Thread.sleep(forTimeInterval: 0.12)
            sendNoteOff(note: n)
        }
        print("\n\(Colors.green)✓ Chromatic sweep complete.\(Colors.reset)")
    }

    // Pattern 2: Scale Guide Simulation
    func runScaleGuideSimulation(root: UInt8 = 0, scaleName: String = "Major") {
        print("\n\(Colors.cyan)--> Simulating Scale Guide (\(scaleName), Root = \(root))...\(Colors.reset)")
        allNotesOff()

        let intervals: Set<UInt8> = [0, 2, 4, 5, 7, 9, 11]
        var lit = [UInt8]()

        for n: UInt8 in 48...72 {
            let semitone = (n - root) % 12
            if intervals.contains(semitone) {
                sendNoteOn(note: n, velocity: 127)
                lit.append(n)
            }
        }
        print("\(Colors.green)✓ Sent Note-On to in-scale pitches: \(lit)\(Colors.reset)")
        print("\(Colors.yellow)Press Enter to turn off LEDs and return to menu: \(Colors.reset)", terminator: "")
        fflush(stdout)
        let _ = readLine()
        allNotesOff()
    }

    // Pattern 3: All 25 Keys ON / OFF
    func runAllOn() {
        print("\n\(Colors.cyan)--> Turning ON all 25 keyboard keys (Notes 48..72)...\(Colors.reset)")
        for n: UInt8 in 48...72 {
            sendNoteOn(note: n, velocity: 127)
        }
        print("\(Colors.green)✓ All 25 Note-On packets dispatched.\(Colors.reset)")
        print("\(Colors.yellow)Press Enter to turn OFF: \(Colors.reset)", terminator: "")
        fflush(stdout)
        let _ = readLine()
        allNotesOff()
        print("\(Colors.green)✓ All 25 Note-Off packets dispatched.\(Colors.reset)")
    }

    // Pattern 4: SysEx Native Handshake & Flash
    func runNativeSysExFlash() {
        print("\n\(Colors.cyan)--> Sending Korg Native Mode SysEx Enable...\(Colors.reset)")
        sendSysex("F0 7E 7F 06 01 F7")
        Thread.sleep(forTimeInterval: 0.1)
        sendSysex("F0 42 40 00 01 36 01 00 00 12 F7")
        Thread.sleep(forTimeInterval: 0.15)
        sendSysex("F0 42 40 00 01 36 02 00 00 00 01 F7")
        Thread.sleep(forTimeInterval: 0.4)
        print("\(Colors.green)✓ Native Mode SysEx Dispatched. Observe controller hardware LED flash.\(Colors.reset)")
        print("\(Colors.yellow)Restore Normal Mode? [Y/n]: \(Colors.reset)", terminator: "")
        fflush(stdout)
        let restore = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? "y"
        if restore != "n" {
            sendSysex("F0 42 40 00 01 36 02 00 00 00 00 F7")
            print("\(Colors.green)✓ Factory normal mode restored.\(Colors.reset)")
        }
    }

    func runInteractiveMenu() {
        while true {
            print("""

\(Colors.cyan)\(Colors.bold)==============================================================================
   🎹 KORG nanoKEY Studio — Hardware Key LED & Scale Guide Probe
==============================================================================\(Colors.reset)
Target Destination: \(Colors.bold)\(deviceName)\(Colors.reset)

Select an action:
  1. \(Colors.bold)Scale Guide Illumination\(Colors.reset) (C Major: C, D, E, F, G, A, B)
  2. \(Colors.bold)Scale Guide Illumination\(Colors.reset) (D Dorian: D, E, F, G, A, B, C)
  3. \(Colors.bold)Chromatic Sweep\(Colors.reset) (Keys 48 through 72 step-by-step)
  4. \(Colors.bold)All 25 Keys ON / OFF\(Colors.reset)
  5. \(Colors.bold)Native Mode SysEx LED Flash\(Colors.reset)
  6. \(Colors.bold)All LEDs OFF (Panic)\(Colors.reset)
  Q. \(Colors.bold)Quit\(Colors.reset)

Enter choice: 
""", terminator: "")
            fflush(stdout)

            guard let line = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() else { break }

            if line == "q" {
                allNotesOff()
                print("\nGoodbye!\n")
                break
            } else if line == "1" {
                runScaleGuideSimulation(root: 0, scaleName: "C Major")
            } else if line == "2" {
                runScaleGuideSimulation(root: 2, scaleName: "D Dorian")
            } else if line == "3" {
                runChromaticSweep()
            } else if line == "4" {
                runAllOn()
            } else if line == "5" {
                runNativeSysExFlash()
            } else if line == "6" {
                allNotesOff()
                print("\(Colors.green)✓ All Note-Off messages dispatched.\(Colors.reset)")
            }
        }
    }
}

let tester = NanoKeyLedTest()
tester.runInteractiveMenu()
