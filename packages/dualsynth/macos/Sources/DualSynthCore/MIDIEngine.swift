import Foundation
import CoreMIDI

public final class MIDIEngine {
    private var client = MIDIClientRef()
    private var sourceEndpoint = MIDIEndpointRef()
    public private(set) var isConnected: Bool = false

    public init(clientName: String = "DualSynth Host", endpointName: String = "DualSynth Virtual Out") {
        var status = MIDIClientCreate(clientName as CFString, nil, nil, &client)
        if status != noErr {
            print("❌ Failed to create CoreMIDI client: \(status)")
            return
        }

        status = MIDISourceCreate(client, endpointName as CFString, &sourceEndpoint)
        if status != noErr {
            print("❌ Failed to create CoreMIDI virtual source endpoint: \(status)")
            return
        }

        isConnected = true
        print("✅ CoreMIDI Virtual Endpoint '\(endpointName)' active and ready.")
    }

    deinit {
        if sourceEndpoint != 0 {
            MIDIEndpointDispose(sourceEndpoint)
        }
        if client != 0 {
            MIDIClientDispose(client)
        }
    }

    public func sendNoteOn(pitch: UInt8, velocity: UInt8, channel: UInt8 = 0) {
        guard isConnected else { return }
        let packet: [UInt8] = [0x90 | (channel & 0x0F), pitch & 0x7F, velocity & 0x7F]
        sendPacket(packet)
    }

    public func sendNoteOff(pitch: UInt8, velocity: UInt8 = 0, channel: UInt8 = 0) {
        guard isConnected else { return }
        let packet: [UInt8] = [0x80 | (channel & 0x0F), pitch & 0x7F, velocity & 0x7F]
        sendPacket(packet)
    }

    public func sendCC(controller: UInt8, value: UInt8, channel: UInt8 = 0) {
        guard isConnected else { return }
        let packet: [UInt8] = [0xB0 | (channel & 0x0F), controller & 0x7F, value & 0x7F]
        sendPacket(packet)
    }

    public func sendPitchBend(value: UInt16, channel: UInt8 = 0) {
        guard isConnected else { return }
        let lsb = UInt8(value & 0x7F)
        let msb = UInt8((value >> 7) & 0x7F)
        let packet: [UInt8] = [0xE0 | (channel & 0x0F), lsb, msb]
        sendPacket(packet)
    }

    private func sendPacket(_ bytes: [UInt8]) {
        guard isConnected else { return }
        var packetList = MIDIPacketList()
        var curPacket = MIDIPacketListInit(&packetList)
        curPacket = MIDIPacketListAdd(&packetList, MemoryLayout<MIDIPacketList>.size, curPacket, 0, bytes.count, bytes)
        let status = MIDIReceived(sourceEndpoint, &packetList)
        if status != noErr {
            print("❌ CoreMIDI MIDIReceived failed: \(status)")
        }
    }
}
