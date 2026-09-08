import SwiftUI
import DualSynthCore

struct StickRadarView: View {
    let title: String
    let x: Float
    let y: Float
    let isClicked: Bool
    let subtitle: String

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(.white)

            ZStack {
                // Background radar circle
                Circle()
                    .fill(Color(white: 0.12))
                    .frame(width: 110, height: 110)
                    .overlay(
                        Circle()
                            .stroke(isClicked ? Color.cyan : Color(white: 0.25), lineWidth: isClicked ? 3 : 1.5)
                    )

                // Crosshairs
                Path { path in
                    path.move(to: CGPoint(x: 55, y: 10))
                    path.addLine(to: CGPoint(x: 55, y: 100))
                    path.move(to: CGPoint(x: 10, y: 55))
                    path.addLine(to: CGPoint(x: 100, y: 55))
                }
                .stroke(Color(white: 0.2), lineWidth: 1)

                // Stick puck
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [isClicked ? .cyan : .blue, Color(white: 0.2)]),
                            center: .center,
                            startRadius: 2,
                            endRadius: 18
                        )
                    )
                    .frame(width: 32, height: 32)
                    .shadow(color: isClicked ? .cyan : .blue.opacity(0.6), radius: 8)
                    .offset(x: CGFloat(x) * 38, y: CGFloat(-y) * 38)
            }
            .frame(width: 110, height: 110)

            HStack(spacing: 12) {
                Text(String(format: "X: %+.2f", x))
                Text(String(format: "Y: %+.2f", y))
            }
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundColor(.gray)

            Text(subtitle)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(white: 0.08)))
    }
}

struct TriggerGaugeView: View {
    let title: String
    let value: Float
    let subtitle: String
    let activeColor: Color

    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(.white)

            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(white: 0.12))
                    .frame(width: 36, height: 100)

                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [activeColor, activeColor.opacity(0.6)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 36, height: max(6, CGFloat(value) * 100))
                    .shadow(color: activeColor.opacity(value > 0.05 ? 0.7 : 0.0), radius: 6)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(white: 0.25), lineWidth: 1)
            )

            Text(String(format: "%3.0f%%", value * 100))
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(value > 0.05 ? activeColor : .gray)

            Text(subtitle)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

struct DualSenseHUDView: View {
    @ObservedObject var controller: ControllerManager
    let midi: MIDIEngine

    @State private var recentLogs: [String] = []

    var body: some View {
        VStack(spacing: 16) {
            // Header Bar
            HStack {
                HStack(spacing: 8) {
                    Circle()
                        .fill(controller.isConnected ? Color.green : Color.red)
                        .frame(width: 10, height: 10)
                        .shadow(color: controller.isConnected ? .green : .red, radius: 4)

                    Text(controller.controllerName)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }

                Spacer()

                // Active Layer Badge
                Text(controller.currentLayer.rawValue.uppercased())
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(layerColor.opacity(0.2))
                    .foregroundColor(layerColor)
                    .overlay(
                        Capsule().stroke(layerColor, lineWidth: 1.5)
                    )
                    .clipShape(Capsule())

                Spacer()

                // Root & Octave
                HStack(spacing: 12) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("ROOT: \(controller.noteNameForPitch(controller.rootKey)) (\(controller.rootKey))")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                        Text(String(format: "OCT SHIFT: %+d", controller.octaveShift / 12))
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)

            // Dynamic RGB Lightbar Simulation
            RoundedRectangle(cornerRadius: 6)
                .fill(
                    LinearGradient(
                        colors: [layerColor.opacity(0.1), layerColor, layerColor.opacity(0.1)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 6)
                .shadow(color: layerColor, radius: 10)
                .padding(.horizontal, 24)

            // Upper Triggers & Shoulders
            HStack(spacing: 40) {
                // Left Wing: L2 & L1
                HStack(spacing: 16) {
                    TriggerGaugeView(
                        title: "L2 TRIGGER",
                        value: controller.telemetry.leftTrigger,
                        subtitle: "CC #74 Cutoff",
                        activeColor: .purple
                    )

                    VStack(spacing: 6) {
                        Text("L1 BUMPER")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)

                        RoundedRectangle(cornerRadius: 8)
                            .fill(controller.telemetry.l1 ? Color.blue : Color(white: 0.15))
                            .frame(width: 80, height: 36)
                            .overlay(
                                Text("HARMONY")
                                    .font(.system(size: 10, weight: .heavy))
                                    .foregroundColor(controller.telemetry.l1 ? .white : .gray)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(controller.telemetry.l1 ? Color.blue : Color(white: 0.25), lineWidth: 1.5)
                            )
                            .shadow(color: controller.telemetry.l1 ? .blue : .clear, radius: 8)
                    }
                }

                Spacer()

                // Center Touchpad Visual
                VStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(white: 0.12))
                        .frame(width: 140, height: 60)
                        .overlay(
                            VStack(spacing: 4) {
                                Text("DUALSENSE TOUCHPAD")
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundColor(.gray)
                                Text("VIRTUAL COREMIDI ACTIVE")
                                    .font(.system(size: 8, weight: .heavy))
                                    .foregroundColor(.green)
                            }
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(white: 0.25), lineWidth: 1)
                        )
                }

                Spacer()

                // Right Wing: R1 & R2
                HStack(spacing: 16) {
                    VStack(spacing: 6) {
                        Text("R1 BUMPER")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)

                        RoundedRectangle(cornerRadius: 8)
                            .fill(controller.telemetry.r1 ? Color.orange : Color(white: 0.15))
                            .frame(width: 80, height: 36)
                            .overlay(
                                Text("LOOPER")
                                    .font(.system(size: 10, weight: .heavy))
                                    .foregroundColor(controller.telemetry.r1 ? .white : .gray)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(controller.telemetry.r1 ? Color.orange : Color(white: 0.25), lineWidth: 1.5)
                            )
                            .shadow(color: controller.telemetry.r1 ? .orange : .clear, radius: 8)
                    }

                    TriggerGaugeView(
                        title: "R2 TRIGGER",
                        value: controller.telemetry.rightTrigger,
                        subtitle: "Velocity Gate",
                        activeColor: .green
                    )
                }
            }
            .padding(.horizontal, 24)

            // Mid Section: D-Pad & Face Diamond
            HStack(spacing: 60) {
                // D-Pad Cross
                VStack(spacing: 4) {
                    Text("D-PAD")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.gray)

                    ZStack {
                        // Up
                        dpadButton(label: "▲", active: controller.telemetry.dpadUp, offset: CGSize(width: 0, height: -32), desc: "Oct +")
                        // Down
                        dpadButton(label: "▼", active: controller.telemetry.dpadDown, offset: CGSize(width: 0, height: 32), desc: "Oct -")
                        // Left
                        dpadButton(label: "◀", active: controller.telemetry.dpadLeft, offset: CGSize(width: -32, height: 0), desc: "Root -")
                        // Right
                        dpadButton(label: "▶", active: controller.telemetry.dpadRight, offset: CGSize(width: 32, height: 0), desc: "Root +")
                    }
                    .frame(width: 110, height: 110)
                }

                // Thumbsticks in Center-Bottom
                HStack(spacing: 30) {
                    StickRadarView(
                        title: "LEFT STICK",
                        x: controller.telemetry.leftStickX,
                        y: controller.telemetry.leftStickY,
                        isClicked: controller.telemetry.l3,
                        subtitle: "Pitch Bend / Mod (CC1)"
                    )

                    StickRadarView(
                        title: "RIGHT STICK",
                        x: controller.telemetry.rightStickX,
                        y: controller.telemetry.rightStickY,
                        isClicked: controller.telemetry.r3,
                        subtitle: "Pan (CC10) / Res (CC71)"
                    )
                }

                // Face Buttons Diamond
                VStack(spacing: 4) {
                    Text("FACE BUTTONS")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.gray)

                    ZStack {
                        // Triangle (IV)
                        faceButton(symbol: "△", note: controller.noteNameForPitch(UInt8(Int(controller.rootKey) + controller.octaveShift + 5)), active: controller.telemetry.triangle, color: .green, offset: CGSize(width: 0, height: -36))
                        // Circle (III)
                        faceButton(symbol: "○", note: controller.noteNameForPitch(UInt8(Int(controller.rootKey) + controller.octaveShift + 4)), active: controller.telemetry.circle, color: .red, offset: CGSize(width: 36, height: 0))
                        // Cross (I)
                        faceButton(symbol: "✕", note: controller.noteNameForPitch(UInt8(Int(controller.rootKey) + controller.octaveShift)), active: controller.telemetry.cross, color: .blue, offset: CGSize(width: 0, height: 36))
                        // Square (II)
                        faceButton(symbol: "□", note: controller.noteNameForPitch(UInt8(Int(controller.rootKey) + controller.octaveShift + 2)), active: controller.telemetry.square, color: .pink, offset: CGSize(width: -36, height: 0))
                    }
                    .frame(width: 110, height: 110)
                }
            }
            .padding(.horizontal, 24)

            // Bottom Status Console
            HStack {
                Text("LAST EVENT:")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.gray)

                Text(controller.lastEventDescription)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.cyan)

                Spacer()

                Text("COREMIDI: 'DualSynth Virtual Out' (Listening in DAWs)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.green)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(white: 0.08))
            .cornerRadius(8)
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .frame(minWidth: 720, minHeight: 480)
        .background(Color(white: 0.05))
    }

    private var layerColor: Color {
        switch controller.currentLayer {
        case .base: return .green
        case .harmony: return .blue
        case .looper: return .orange
        case .parameters: return .purple
        }
    }

    private func dpadButton(label: String, active: Bool, offset: CGSize, desc: String) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(active ? Color.cyan : Color(white: 0.16))
                .frame(width: 28, height: 28)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(active ? Color.cyan : Color(white: 0.3), lineWidth: 1)
                )
                .shadow(color: active ? .cyan : .clear, radius: 8)

            Text(label)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(active ? .black : .white)
        }
        .offset(offset)
    }

    private func faceButton(symbol: String, note: String, active: Bool, color: Color, offset: CGSize) -> some View {
        ZStack {
            Circle()
                .fill(active ? color : Color(white: 0.16))
                .frame(width: 32, height: 32)
                .overlay(
                    Circle().stroke(active ? color : Color(white: 0.3), lineWidth: 1.5)
                )
                .shadow(color: active ? color : .clear, radius: 10)

            VStack(spacing: 0) {
                Text(symbol)
                    .font(.system(size: 12, weight: .black))
                    .foregroundColor(active ? .white : color)
                Text(note)
                    .font(.system(size: 7, weight: .heavy, design: .monospaced))
                    .foregroundColor(active ? .white : .gray)
            }
        }
        .offset(offset)
    }
}
