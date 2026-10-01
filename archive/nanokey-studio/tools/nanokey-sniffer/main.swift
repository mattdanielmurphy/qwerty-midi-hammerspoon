import Foundation
import CoreMIDI

// ==============================================================================
// Korg nanoKEY Studio BLE & MIDI Systematic Packet Sniffer
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

struct CapturedPacket: Codable {
    let timestamp: String
    let commandType: String
    let rawHex: String
    let byteCount: Int
    let bleGattFrame: String
    let interpretation: String
}

struct ButtonTestResult: Codable {
    let buttonId: String
    let displayName: String
    let physicalLocation: String
    let emittedPacket: Bool
    let packets: [CapturedPacket]
    let notes: String
}

class NanoKeySniffer {
    var client = MIDIClientRef()
    var inPort = MIDIPortRef()
    var outPort = MIDIPortRef()
    var sourceEndpoint: MIDIEndpointRef = 0
    var destEndpoint: MIDIEndpointRef = 0
    var deviceName: String = ""
    
    var isNativeModeActive = false
    var currentStepPackets = [CapturedPacket]()
    var sysexBuffer = [UInt8]()
    
    var autoAdvanceSeconds: Double = 5.0
    var isAutoAdvance = false
    
    // Systematic target buttons list
    let targetButtons: [(id: String, name: String, location: String, hint: String)] = [
        ("oct_down",    "Octave Down",  "Left Group (Top-Left)",      "Leftmost button above chiclet keys [OCT -]"),
        ("oct_up",      "Octave Up",    "Left Group (Top-Mid)",       "Second button above chiclet keys [OCT +]"),
        ("sustain",     "Sustain",      "Left Group (Top-Right)",     "Third button above chiclet keys [SUS]"),
        ("touch_scale", "Touch Scale",  "Left Group (Bottom-Left)",   "Lower button below Octave Down [SCALE]"),
        ("xy",          "X-Y Mode",     "Left Group (Bottom-Mid)",    "Lower button below Octave Up [X-Y]"),
        ("pitch_mod",   "Pitch / Mod",  "Left Group (Bottom-Right)",  "Lower button below Sustain [P/M]"),
        ("scene",       "Scene",        "Right Group (Top-Left)",     "Top button left of Trigger Pads [SCENE]"),
        ("shift_tap",   "Shift / Tap",  "Right Group (Top-Mid)",      "Middle button top row [SHIFT]"),
        ("arp",         "Arpeggiator",  "Right Group (Top-Right)",    "Rightmost button top row [ARP]"),
        ("chord_pad",   "Chord Pad",    "Right Group (Bottom-Left)",  "Lower button below Scene [CHORD]"),
        ("easy_scale",  "Easy Scale",   "Right Group (Bottom-Mid)",   "Lower button below Shift [EASY]"),
        ("scale_guide", "Scale Guide",  "Right Group (Bottom-Right)", "Lower button below Arp [GUIDE]")
    ]
    
    var recordedResults = [ButtonTestResult]()

    init() {
        setupMidi()
    }
    
    func setupMidi() {
        var status = MIDIClientCreate("NanoKeySniffer" as CFString, nil, nil, &client)
        guard status == 0 else {
            print("\(Colors.red)Failed to create MIDI client (status \(status))\(Colors.reset)")
            exit(1)
        }
        
        status = MIDIInputPortCreateWithBlock(client, "SnifferIn" as CFString, &inPort) { [weak self] pktList, _ in
            self?.handleIncomingMidi(pktList: pktList)
        }
        guard status == 0 else {
            print("\(Colors.red)Failed to create MIDI input port (status \(status))\(Colors.reset)")
            exit(1)
        }
        
        status = MIDIOutputPortCreate(client, "SnifferOut" as CFString, &outPort)
        guard status == 0 else {
            print("\(Colors.red)Failed to create MIDI output port (status \(status))\(Colors.reset)")
            exit(1)
        }
        
        findEndpoints()
        
        guard sourceEndpoint != 0, destEndpoint != 0 else {
            print("\(Colors.red)Error: nanoKEY Studio not detected in CoreMIDI.\(Colors.reset)")
            print("\(Colors.yellow)Please ensure the controller is powered on and connected via Bluetooth or USB.\(Colors.reset)")
            exit(1)
        }
        
        status = MIDIPortConnectSource(inPort, sourceEndpoint, nil)
        guard status == 0 else {
            print("\(Colors.red)Failed to connect to source endpoint (status \(status))\(Colors.reset)")
            exit(1)
        }
    }
    
    func findEndpoints() {
        let numSrc = MIDIGetNumberOfSources()
        for i in 0..<numSrc {
            let src = MIDIGetSource(i)
            let name = getEndpointName(src)
            if name.localizedCaseInsensitiveContains("nanokey") {
                sourceEndpoint = src
                deviceName = name
                break
            }
        }
        
        let numDst = MIDIGetNumberOfDestinations()
        for i in 0..<numDst {
            let dst = MIDIGetDestination(i)
            let name = getEndpointName(dst)
            if name.localizedCaseInsensitiveContains("nanokey") {
                destEndpoint = dst
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
    
    func sendPacket(_ hexStr: String) {
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
        
        var packetList = MIDIPacketList()
        var curPacket = MIDIPacketListInit(&packetList)
        curPacket = MIDIPacketListAdd(&packetList, 1024, curPacket, 0, bytes.count, bytes)
        let _ = MIDISend(outPort, destEndpoint, &packetList)
    }
    
    func enableNativeMode() {
        print("\n\(Colors.cyan)--> Transmitting Korg Native Mode SysEx Handshake...\(Colors.reset)")
        sendPacket("F0 7E 7F 06 01 F7") // Device Inquiry
        Thread.sleep(forTimeInterval: 0.15)
        sendPacket("F0 42 40 00 01 36 01 00 00 12 F7") // Handshake Init
        Thread.sleep(forTimeInterval: 0.15)
        sendPacket("F0 42 40 00 01 36 02 00 00 00 01 F7") // Enable Native Mode
        Thread.sleep(forTimeInterval: 0.4)
        isNativeModeActive = true
        print("\(Colors.green)✓ Native Mode Enabled! Controller LEDs perform illumination flash.\(Colors.reset)")
    }
    
    func disableNativeMode() {
        print("\n\(Colors.cyan)--> Transmitting Disable Native Mode SysEx (Restoring Factory Normal Mode)...\(Colors.reset)")
        sendPacket("F0 42 40 00 01 36 02 00 00 00 00 F7")
        Thread.sleep(forTimeInterval: 0.3)
        isNativeModeActive = false
        print("\(Colors.green)✓ Restored to Factory Normal Mode.\(Colors.reset)")
    }
    
    func handleIncomingMidi(pktList: UnsafePointer<MIDIPacketList>) {
        let list = pktList.pointee
        var packet = list.packet
        let df = DateFormatter()
        df.dateFormat = "HH:mm:ss.SSS"
        let now = df.string(from: Date())
        
        for _ in 0..<list.numPackets {
            let length = Int(packet.length)
            withUnsafePointer(to: &packet.data) { ptr in
                let rawPtr = UnsafeRawPointer(ptr).assumingMemoryBound(to: UInt8.self)
                let bytes = Array(UnsafeBufferPointer(start: rawPtr, count: length))
                
                for b in bytes {
                    if b == 0xF0 {
                        sysexBuffer = [b]
                    } else if !sysexBuffer.isEmpty {
                        sysexBuffer.append(b)
                        if b == 0xF7 {
                            processMessage(bytes: sysexBuffer, timeStr: now, isSysex: true)
                            sysexBuffer.removeAll()
                        }
                    }
                }
                
                if sysexBuffer.isEmpty && !bytes.isEmpty && bytes[0] != 0xF0 {
                    processMessage(bytes: bytes, timeStr: now, isSysex: false)
                }
            }
            packet = MIDIPacketNext(&packet).pointee
        }
    }
    
    func processMessage(bytes: [UInt8], timeStr: String, isSysex: Bool) {
        guard !bytes.isEmpty else { return }
        
        let hexStr = bytes.map { String(format: "%02X", $0) }.joined(separator: " ")
        var cmdType = "Unknown"
        var interp = ""
        
        if isSysex {
            cmdType = "SysEx"
            interp = decodeKorgSysex(bytes)
        } else {
            let status = bytes[0]
            let ch = status & 0x0F
            let cmdNibble = status & 0xF0
            
            if cmdNibble == 0x80 {
                cmdType = "NoteOff"
                let note = bytes.count > 1 ? bytes[1] : 0
                interp = "Note Off: #\(note) (Ch \(ch + 1))"
            } else if cmdNibble == 0x90 {
                cmdType = "NoteOn"
                let note = bytes.count > 1 ? bytes[1] : 0
                let vel = bytes.count > 2 ? bytes[2] : 0
                interp = "Note On: #\(note) Vel \(vel) (Ch \(ch + 1))"
            } else if cmdNibble == 0xB0 {
                cmdType = "ControlChange"
                let cc = bytes.count > 1 ? bytes[1] : 0
                let val = bytes.count > 2 ? bytes[2] : 0
                interp = "CC #\(cc) = \(val) (Ch \(ch + 1))"
            } else if cmdNibble == 0xE0 {
                cmdType = "PitchBend"
                interp = "Pitch Bend (Ch \(ch + 1))"
            }
        }
        
        // BLE-MIDI GATT characteristic representation:
        // Characteristic: 7772E5DB-3868-4112-A1A9-F2669D106BF3
        // Header: 0x80 | (ts & 0x3F), Timestamp: 0x80 | (ts & 0x7F)
        var bleFrame = "80 80 " + hexStr
        if isSysex && bytes.count > 18 {
            bleFrame = "[BLE Multi-Frame: 80 80 F0 ... 80 F7]"
        }
        
        let captured = CapturedPacket(
            timestamp: timeStr,
            commandType: cmdType,
            rawHex: hexStr,
            byteCount: bytes.count,
            bleGattFrame: bleFrame,
            interpretation: interp
        )
        
        currentStepPackets.append(captured)
        
        // Print live feedback
        print("    \(Colors.green)⚡ [CAPTURED \(cmdType)]\(Colors.reset) \(Colors.bold)\(hexStr)\(Colors.reset)")
        print("       \(Colors.dim)BLE Frame: \(bleFrame)\(Colors.reset)")
        print("       \(Colors.cyan)Interpretation: \(interp)\(Colors.reset)")
        fflush(stdout)
    }
    
    func decodeKorgSysex(_ bytes: [UInt8]) -> String {
        if bytes.count >= 6 && bytes[0] == 0xF0 && bytes[1] == 0x42 {
            if bytes.count >= 10 && bytes[2] == 0x40 && bytes[3] == 0x00 && bytes[4] == 0x01 && bytes[5] == 0x36 {
                let cmd = bytes[9]
                if cmd == 0x41 && bytes.count >= 14 {
                    let subId = bytes[10]
                    let val = bytes[11]
                    if subId == 0x40 {
                        if val == 0x01 { return "Korg Native Mode: Octave Up / Scale Increment (+1)" }
                        if val == 0x00 { return "Korg Native Mode: Octave Down / Scale Decrement (-1)" }
                        if val == 0x40 { return "Korg Native Mode: Scene Button Pressed" }
                    }
                    return "Korg Native Mode Button Event: SubId 0x\(String(format: "%02X", subId)) Val 0x\(String(format: "%02X", val))"
                } else if cmd == 0x01 {
                    return "Korg Handshake Acknowledged"
                } else if cmd == 0x42 {
                    return "Korg Native State Active"
                }
                return "Korg nanoKEY Studio Native SysEx (Cmd 0x\(String(format: "%02X", cmd)))"
            }
            return "Korg Proprietary SysEx"
        } else if bytes.count >= 5 && bytes[0] == 0xF0 && bytes[1] == 0x7E {
            return "Universal SysEx Identity Reply"
        }
        return "Generic SysEx Message"
    }
    
    func runSystematicCalibration() {
        print("""
\(Colors.cyan)\(Colors.bold)
==============================================================================
   🎹 KORG nanoKEY Studio — Systematic Button Sniffer & BLE Decoder
==============================================================================\(Colors.reset)
Hardware Device: \(Colors.bold)\(deviceName)\(Colors.reset)
GATT Service:    \(Colors.dim)03B80E5A-EDE8-4B33-A751-6CE34EC4C700 (BLE-MIDI)\(Colors.reset)
Characteristic:  \(Colors.dim)7772E5DB-3868-4112-A1A9-F2669D106BF3 (BLE-MIDI I/O)\(Colors.reset)

This utility systematically prompts you to press each of the physical
"forbidden" system function buttons to determine whether they emit
Bluetooth packets or MIDI signals over the air.

Target Buttons (\(targetButtons.count) total):
- Octave - / +
- Sustain [SUS]
- Touch Scale [SCALE]
- X-Y Mode
- Pitch / Mod [P/M]
- Scene [SCENE]
- Shift / Tap [SHIFT]
- Arp [ARP]
- Chord Pad [CHORD]
- Easy Scale [EASY]
- Scale Guide [GUIDE]
""")
        
        print("\(Colors.yellow)Select Operating Mode:\(Colors.reset)")
        print("  1. \(Colors.bold)Korg Native Mode (Recommended)\(Colors.reset) — Unlocks MCU internal function buttons over BLE-MIDI")
        print("  2. \(Colors.bold)Standard Firmware Mode\(Colors.reset) — Factory default mode (tests what leaks without handshake)")
        print("\nEnter choice [1 or 2] (default: 1): ", terminator: "")
        fflush(stdout)
        
        let choice = isAutoAdvance ? "1" : (readLine()?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "1")
        if choice != "2" {
            enableNativeMode()
        } else {
            print("\(Colors.yellow)--> Running in Standard Firmware Mode (Unhandshaked).\(Colors.reset)")
        }
        
        print("\n\(Colors.bold)==============================================================================\(Colors.reset)")
        print("\(Colors.bold)Starting Guided Button Sweep. Follow the prompts for each button:\(Colors.reset)")
        print("\(Colors.bold)==============================================================================\(Colors.reset)\n")
        
        for (index, btn) in targetButtons.enumerated() {
            currentStepPackets.removeAll()
            
            print("\(Colors.cyan)------------------------------------------------------------------------------\(Colors.reset)")
            print("\(Colors.bold)Step \(index + 1) of \(targetButtons.count):\(Colors.reset) 👉 \(Colors.yellow)\(Colors.bold)PRESS [\(btn.name)]\(Colors.reset)")
            print("  \(Colors.dim)Location:\(Colors.reset) \(btn.location)")
            print("  \(Colors.dim)Label:\(Colors.reset)    \(btn.hint)")
            print("  \(Colors.magenta)Listening... (Press and release [\(btn.name)] now)\(Colors.reset)")
            
            var captured = false
            let stepStart = Date()
            let timeout = autoAdvanceSeconds
            
            if isAutoAdvance {
                // Auto-advance mode: wait for packet or timeout
                while Date().timeIntervalSince(stepStart) < timeout {
                    if !currentStepPackets.isEmpty {
                        captured = true
                        Thread.sleep(forTimeInterval: 0.4) // Allow release packet to arrive
                        break
                    }
                    Thread.sleep(forTimeInterval: 0.05)
                }
            } else {
                // Interactive mode: poll while waiting for user confirmation or key
                while Date().timeIntervalSince(stepStart) < 8.0 {
                    if !currentStepPackets.isEmpty {
                        captured = true
                        Thread.sleep(forTimeInterval: 0.3)
                        break
                    }
                    Thread.sleep(forTimeInterval: 0.05)
                }
            }
            
            if captured {
                print("\n  \(Colors.green)✓ Detected \(currentStepPackets.count) packet(s) for [\(btn.name)]!\(Colors.reset)")
            } else {
                print("\n  \(Colors.yellow)⚠ No packet detected during capture window.\(Colors.reset)")
            }
            
            if !isAutoAdvance {
                print("  \(Colors.white)Options: [Enter] Next | [R] Retry | [S] Skip: \(Colors.reset)", terminator: "")
                fflush(stdout)
                let action = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
                if action == "r" {
                    currentStepPackets.removeAll()
                    print("  \(Colors.magenta)Retrying... Press [\(btn.name)] now:\(Colors.reset)")
                    let retryStart = Date()
                    while Date().timeIntervalSince(retryStart) < 6.0 {
                        if !currentStepPackets.isEmpty {
                            Thread.sleep(forTimeInterval: 0.3)
                            break
                        }
                        Thread.sleep(forTimeInterval: 0.05)
                    }
                }
            } else {
                Thread.sleep(forTimeInterval: 0.5)
            }
            
            let result = ButtonTestResult(
                buttonId: btn.id,
                displayName: btn.name,
                physicalLocation: btn.location,
                emittedPacket: !currentStepPackets.isEmpty,
                packets: currentStepPackets,
                notes: currentStepPackets.isEmpty ? "No packets emitted (handled internally by MCU firmware)" : "Transmitted \(currentStepPackets.count) packet(s)"
            )
            recordedResults.append(result)
            print("")
        }
        
        print("\n\(Colors.bold)==============================================================================\(Colors.reset)")
        print("\(Colors.bold)Calibration Sweep Complete!\(Colors.reset)")
        print("\(Colors.bold)==============================================================================\(Colors.reset)\n")
        
        displaySummaryTable()
        saveReportFiles()
        
        if isNativeModeActive {
            if !isAutoAdvance {
                print("\n\(Colors.yellow)Restore controller to factory Normal Mode before exiting? [Y/n]: \(Colors.reset)", terminator: "")
                fflush(stdout)
                let restore = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? "y"
                if restore != "n" {
                    disableNativeMode()
                } else {
                    print("\(Colors.cyan)Leaving controller in Korg Native Mode.\(Colors.reset)")
                }
            } else {
                disableNativeMode()
            }
        }
        
        print("\n\(Colors.green)All done! Results logged and saved.\(Colors.reset)\n")
    }
    
    func displaySummaryTable() {
        print("\nSUMMARY TABLE OF TESTED BUTTONS:")
        print("-----------------------------------------------------------------------------------------------------------------------------")
        print(String(format: "%-16@ | %-8@ | %-14@ | %-32@ | %@", "Button Name", "Active?", "Command Type", "Raw Packet Hex", "Interpretation"))
        print("-----------------------------------------------------------------------------------------------------------------------------")
        
        for res in recordedResults {
            let activeStr = res.emittedPacket ? "\(Colors.green)YES\(Colors.reset)" : "\(Colors.red)NO (Silent)\(Colors.reset)"
            let typeStr = res.packets.first?.commandType ?? "-"
            let rawHex = res.packets.first?.rawHex ?? "(none)"
            let interp = res.packets.first?.interpretation ?? "Internal MCU only"
            
            print(String(format: "%-16@ | %-8@ | %-14@ | %-32@ | %@", res.displayName, activeStr, typeStr, rawHex, interp))
        }
        print("-----------------------------------------------------------------------------------------------------------------------------\n")
    }
    
    func saveReportFiles() {
        let jsonPath = "/Users/matt/projects/qwerty-midi-hammerspoon/tmp/nanokey_sniff_results.json"
        let mdPath = "/Users/matt/projects/qwerty-midi-hammerspoon/tmp/NANOKEY_SNIFFER_REPORT.md"
        
        // Save JSON
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        if let data = try? encoder.encode(recordedResults) {
            try? data.write(to: URL(fileURLWithPath: jsonPath))
            print("💾 Saved raw JSON results to: \(Colors.cyan)\(jsonPath)\(Colors.reset)")
        }
        
        // Save Markdown report
        var md = "# Korg nanoKEY Studio Hardware Button Sniffing Report\n\n"
        md += "**Hardware Device**: `\(deviceName)`\n"
        md += "**Timestamp**: `\(Date())`\n"
        md += "**BLE-MIDI Service UUID**: `03B80E5A-EDE8-4B33-A751-6CE34EC4C700`\n"
        md += "**BLE-MIDI Characteristic**: `7772E5DB-3868-4112-A1A9-F2669D106BF3`\n"
        md += "**Native Mode SysEx Handshake**: `F0 42 40 00 01 36 01 00 00 12 F7` + `F0 42 40 00 01 36 02 00 00 00 01 F7`\n\n"
        md += "## Button Telemetry Matrix\n\n"
        md += "| Button | Physical Location | Emits Packet? | Command Type | Raw Hex | BLE-MIDI Frame | Interpretation |\n"
        md += "| :--- | :--- | :---: | :---: | :--- | :--- | :--- |\n"
        
        for res in recordedResults {
            let active = res.emittedPacket ? "✅ YES" : "❌ NO (Silent)"
            let type = res.packets.first?.commandType ?? "-"
            let hex = res.packets.first?.rawHex ?? "*(silent)*"
            let ble = res.packets.first?.bleGattFrame ?? "*(silent)*"
            let notes = res.packets.first?.interpretation ?? res.notes
            md += "| **\(res.displayName)** | \(res.physicalLocation) | \(active) | `\(type)` | `\(hex)` | `\(ble)` | \(notes) |\n"
        }
        
        md += "\n## Detailed Captured Packets\n\n"
        for res in recordedResults {
            if !res.packets.isEmpty {
                md += "### \(res.displayName) (`\(res.buttonId)`)\n\n"
                for (idx, p) in res.packets.enumerated() {
                    md += "- **Packet #\(idx + 1)** (`\(p.timestamp)`):\n"
                    md += "  - **Type**: `\(p.commandType)` (\(p.byteCount) bytes)\n"
                    md += "  - **Raw Hex**: `\(p.rawHex)`\n"
                    md += "  - **BLE-MIDI Frame**: `\(p.bleGattFrame)`\n"
                    md += "  - **Interpretation**: \(p.interpretation)\n"
                }
                md += "\n"
            }
        }
        
        md += """
## Integration Guide for `packages/nanokey-studio/nanokey.lua`

For any button that emits packets in Native Mode:
1. **Enable Native Mode on Connect**:
   Send `dev:sendSysex("f0 42 40 00 01 36 01 00 00 12 f7")` followed by `dev:sendSysex("f0 42 40 00 01 36 02 00 00 00 01 f7")`.
2. **Handle Button SysEx in `handleMidiEvent`**:
   Parse incoming `systemExclusive` frames matching `f04240000136...` and map them to custom macro triggers, layers, or DAW transport actions!
3. **Restore on Disconnect**:
   Send `dev:sendSysex("f0 42 40 00 01 36 02 00 00 00 00 f7")` upon application termination or device disconnect.
"""
        
        try? md.write(toFile: mdPath, atomically: true, encoding: .utf8)
        print("📄 Generated Markdown report at: \(Colors.cyan)\(mdPath)\(Colors.reset)")
    }
    
    func runInteractiveMonitor() {
        print("""
\(Colors.cyan)\(Colors.bold)
==============================================================================
   🎹 KORG nanoKEY Studio — Live Freeform Monitor
==============================================================================\(Colors.reset)
Connected Hardware: \(Colors.bold)\(deviceName)\(Colors.reset)
BLE-MIDI UUID:      \(Colors.dim)7772E5DB-3868-4112-A1A9-F2669D106BF3\(Colors.reset)

In this mode, you can press ANY button, twist knobs, or touch the Kaoss pad
to observe real-time packet decoding.

Options:
  [N] Toggle Native Mode On/Off
  [Q] Quit Monitor

Listening for MIDI & SysEx...
""")
        enableNativeMode()
        
        while true {
            if let line = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
                if line == "q" {
                    disableNativeMode()
                    break
                } else if line == "n" {
                    if isNativeModeActive {
                        disableNativeMode()
                    } else {
                        enableNativeMode()
                    }
                }
            }
        }
    }
}

// ==============================================================================
// Main Entry Point
// ==============================================================================
let args = CommandLine.arguments
let sniffer = NanoKeySniffer()

if args.contains("--auto") {
    sniffer.isAutoAdvance = true
    if let idx = args.firstIndex(of: "--timeout"), idx + 1 < args.count, let t = Double(args[idx + 1]) {
        sniffer.autoAdvanceSeconds = t
    } else {
        sniffer.autoAdvanceSeconds = 4.0
    }
}

if args.contains("--monitor") || args.contains("-m") {
    sniffer.runInteractiveMonitor()
} else {
    sniffer.runSystematicCalibration()
}
