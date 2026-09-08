import SwiftUI
import DualSynthCore

public enum ThemeMode: String, CaseIterable {
    case auto = "Auto"
    case light = "Light"
    case dark = "Dark"
}

public struct ThemeColors {
    public let isDark: Bool

    public var bgCanvas: Color { isDark ? Color(white: 0.05) : Color(white: 0.94) }
    public var chassisBg: Color { isDark ? Color(white: 0.09) : Color.white }
    public var chassisBorder: Color { isDark ? Color(white: 0.18) : Color(white: 0.84) }
    public var innerBridge: Color { isDark ? Color(white: 0.06) : Color(white: 0.93) }

    public var cardBg: Color { isDark ? Color(white: 0.11) : Color(white: 0.98) }
    public var cardBorder: Color { isDark ? Color(white: 0.20) : Color(white: 0.86) }

    public var wellBg: Color { isDark ? Color(white: 0.13) : Color(white: 0.91) }
    public var wellBorder: Color { isDark ? Color(white: 0.25) : Color(white: 0.78) }
    public var crosshair: Color { isDark ? Color(white: 0.22) : Color(white: 0.75) }

    public var textPrimary: Color { isDark ? Color.white : Color(white: 0.10) }
    public var textSecondary: Color { isDark ? Color.gray : Color(white: 0.40) }
    public var textTertiary: Color { isDark ? Color(white: 0.45) : Color(white: 0.55) }

    public var buttonBg: Color { isDark ? Color(white: 0.16) : Color(white: 0.92) }
    public var buttonBorder: Color { isDark ? Color(white: 0.30) : Color(white: 0.78) }

    public var consoleBg: Color { isDark ? Color(white: 0.07) : Color(white: 0.91) }
}

struct StickRadarView: View {
    let title: String
    let x: Float
    let y: Float
    let isClicked: Bool
    let subtitle: String
    let theme: ThemeColors

    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(theme.textPrimary)

            ZStack {
                // Background radar circle
                Circle()
                    .fill(theme.wellBg)
                    .frame(width: 96, height: 96)
                    .overlay(
                        Circle()
                            .stroke(isClicked ? Color.cyan : theme.wellBorder, lineWidth: isClicked ? 2.5 : 1.2)
                    )

                // Crosshairs
                Path { path in
                    path.move(to: CGPoint(x: 48, y: 8))
                    path.addLine(to: CGPoint(x: 48, y: 88))
                    path.move(to: CGPoint(x: 8, y: 48))
                    path.addLine(to: CGPoint(x: 88, y: 48))
                }
                .stroke(theme.crosshair, lineWidth: 1)

                // Inner reference ring
                Circle()
                    .stroke(theme.crosshair.opacity(0.5), lineWidth: 0.8)
                    .frame(width: 50, height: 50)

                // Stick puck
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [isClicked ? .cyan : .blue, theme.wellBorder]),
                            center: .center,
                            startRadius: 2,
                            endRadius: 15
                        )
                    )
                    .frame(width: 28, height: 28)
                    .shadow(color: isClicked ? .cyan : .blue.opacity(0.5), radius: 6)
                    .offset(x: CGFloat(x) * 32, y: CGFloat(-y) * 32)
            }
            .frame(width: 96, height: 96)

            HStack(spacing: 8) {
                Text(String(format: "X:%+.2f", x))
                Text(String(format: "Y:%+.2f", y))
            }
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundColor(theme.textSecondary)

            Text(subtitle)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(theme.textTertiary)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12).fill(theme.cardBg))
        .overlay(
            RoundedRectangle(cornerRadius: 12).stroke(theme.cardBorder, lineWidth: 1)
        )
    }
}

struct TriggerGaugeView: View {
    let title: String
    let value: Float
    let subtitle: String
    let activeColor: Color
    let theme: ThemeColors

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(theme.textPrimary)

            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(theme.wellBg)
                    .frame(width: 32, height: 84)

                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        LinearGradient(
                            colors: [activeColor, activeColor.opacity(0.6)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 32, height: max(4, CGFloat(value) * 84))
                    .shadow(color: activeColor.opacity(value > 0.05 ? 0.6 : 0.0), radius: 4)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(theme.wellBorder, lineWidth: 1)
            )

            Text(String(format: "%3.0f%%", value * 100))
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(value > 0.05 ? activeColor : theme.textSecondary)

            Text(subtitle)
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(theme.textTertiary)
                .multilineTextAlignment(.center)
        }
    }
}

public struct DualSenseHUDView: View {
    @ObservedObject public var controller: ControllerManager
    public let midi: MIDIEngine

    @Environment(\.colorScheme) private var systemColorScheme
    @State private var themeSelection: ThemeMode = .auto

    private var isDarkMode: Bool {
        switch themeSelection {
        case .auto: return systemColorScheme == .dark
        case .dark: return true
        case .light: return false
        }
    }

    private var theme: ThemeColors {
        ThemeColors(isDark: isDarkMode)
    }

    public init(controller: ControllerManager, midi: MIDIEngine) {
        self.controller = controller
        self.midi = midi
    }

    public var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 12) {
                // Header Bar with Title, Layer, Mode Indicators, and Theme Switcher
                headerBar

                // Centered PS5 DualSense Silhouette Container
                HStack {
                    Spacer(minLength: 0)
                    controllerChassisView
                        .frame(maxWidth: 820)
                    Spacer(minLength: 0)
                }

                // Lower Performance & Telemetry Deck
                performanceDeckView
                    .frame(maxWidth: 820)

                // Bottom Status Console
                statusConsoleView
                    .frame(maxWidth: 820)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(minWidth: 760, minHeight: 560)
        .background(theme.bgCanvas)
    }

    // MARK: - Header Bar
    private var headerBar: some View {
        HStack(spacing: 12) {
            // Connection status
            HStack(spacing: 8) {
                Circle()
                    .fill(controller.isConnected ? Color.green : Color.red)
                    .frame(width: 9, height: 9)
                    .shadow(color: controller.isConnected ? .green : .red, radius: 4)

                Text(controller.controllerName)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(theme.textPrimary)
            }

            Spacer()

            // Active Layer Badge
            Text(controller.currentLayer.rawValue.uppercased())
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(layerColor.opacity(0.18))
                .foregroundColor(layerColor)
                .overlay(
                    Capsule().stroke(layerColor, lineWidth: 1.5)
                )
                .clipShape(Capsule())

            // Musical Mode Badges
            HStack(spacing: 6) {
                Button(action: { controller.toggleChordMode() }) {
                    Text("CHORDS: \(controller.chordMode ? "ON" : "OFF")")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(controller.chordMode ? Color.green.opacity(0.2) : theme.buttonBg)
                        .foregroundColor(controller.chordMode ? .green : theme.textSecondary)
                        .cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(controller.chordMode ? Color.green : theme.buttonBorder, lineWidth: 1))
                }
                .buttonStyle(.plain)

                Button(action: { controller.toggleLatchMode() }) {
                    Text("LATCH: \(controller.latchMode ? "ON 🔒" : "OFF")")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(controller.latchMode ? Color.cyan.opacity(0.2) : theme.buttonBg)
                        .foregroundColor(controller.latchMode ? .cyan : theme.textSecondary)
                        .cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(controller.latchMode ? Color.cyan : theme.buttonBorder, lineWidth: 1))
                }
                .buttonStyle(.plain)

                Button(action: { controller.toggleArpeggiator() }) {
                    Text("ARP: \(controller.isArpActive ? "ON ⚡" : "OFF")")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(controller.isArpActive ? Color.orange.opacity(0.2) : theme.buttonBg)
                        .foregroundColor(controller.isArpActive ? .orange : theme.textSecondary)
                        .cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(controller.isArpActive ? Color.orange : theme.buttonBorder, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }

            Spacer()

            // Theme Selector Toggle Button (Auto / Light / Dark)
            Menu {
                ForEach(ThemeMode.allCases, id: \.self) { mode in
                    Button(action: { themeSelection = mode }) {
                        HStack {
                            Text(mode.rawValue)
                            if themeSelection == mode {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: isDarkMode ? "moon.fill" : "sun.max.fill")
                        .foregroundColor(isDarkMode ? .yellow : .orange)
                    Text(themeSelection.rawValue)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(theme.textPrimary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(theme.buttonBg)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(theme.buttonBorder, lineWidth: 1))
                .cornerRadius(6)
            }
            .menuStyle(.borderlessButton)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(theme.cardBg)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(theme.cardBorder, lineWidth: 1))
    }

    // MARK: - DualSense Controller Chassis View
    private var controllerChassisView: some View {
        VStack(spacing: 12) {
            // Shoulder & Triggers Row
            HStack(spacing: 24) {
                // L2 Trigger & L1 Bumper
                HStack(spacing: 12) {
                    TriggerGaugeView(
                        title: "L2 TRIGGER",
                        value: controller.telemetry.leftTrigger,
                        subtitle: "CC #74 Cutoff",
                        activeColor: .purple,
                        theme: theme
                    )

                    VStack(spacing: 4) {
                        Text("L1 BUMPER")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(theme.textPrimary)

                        RoundedRectangle(cornerRadius: 8)
                            .fill(controller.telemetry.l1 ? Color.blue : theme.buttonBg)
                            .frame(width: 72, height: 32)
                            .overlay(
                                Text("HARMONY")
                                    .font(.system(size: 9, weight: .black))
                                    .foregroundColor(controller.telemetry.l1 ? .white : theme.textSecondary)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(controller.telemetry.l1 ? Color.blue : theme.buttonBorder, lineWidth: 1.5)
                            )
                            .shadow(color: controller.telemetry.l1 ? .blue : .clear, radius: 6)
                    }
                }

                Spacer()

                // Center Top Touchpad with Lightbar Contour & Create/Options Buttons
                HStack(spacing: 10) {
                    // Create Button (Share)
                    createButtonView

                    // Touchpad with lightbar
                    touchpadView

                    // Options Button (Menu)
                    optionsButtonView
                }

                Spacer()

                // R1 Bumper & R2 Trigger
                HStack(spacing: 12) {
                    VStack(spacing: 4) {
                        Text("R1 BUMPER")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(theme.textPrimary)

                        RoundedRectangle(cornerRadius: 8)
                            .fill(controller.telemetry.r1 ? Color.orange : theme.buttonBg)
                            .frame(width: 72, height: 32)
                            .overlay(
                                Text("ARP / RHYTHM")
                                    .font(.system(size: 8, weight: .black))
                                    .foregroundColor(controller.telemetry.r1 ? .white : theme.textSecondary)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(controller.telemetry.r1 ? Color.orange : theme.buttonBorder, lineWidth: 1.5)
                            )
                            .shadow(color: controller.telemetry.r1 ? .orange : .clear, radius: 6)
                    }

                    TriggerGaugeView(
                        title: "R2 TRIGGER",
                        value: controller.telemetry.rightTrigger,
                        subtitle: "CC #11 Expr",
                        activeColor: .green,
                        theme: theme
                    )
                }
            }
            .padding(.horizontal, 16)

            // Dynamic RGB Lightbar Strip
            RoundedRectangle(cornerRadius: 4)
                .fill(
                    LinearGradient(
                        colors: [layerColor.opacity(0.1), layerColor, layerColor.opacity(0.1)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 5)
                .shadow(color: layerColor, radius: 8)
                .padding(.horizontal, 32)

            // Main Face Area: D-Pad (Left), Center Bridge (PS + Mic + Thumbsticks), Face Buttons (Right)
            HStack(alignment: .center, spacing: 18) {
                // Left Wing: D-Pad
                VStack(spacing: 4) {
                    Text("D-PAD")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(theme.textSecondary)

                    ZStack {
                        Circle()
                            .fill(theme.wellBg)
                            .frame(width: 104, height: 104)
                            .overlay(Circle().stroke(theme.wellBorder, lineWidth: 1))

                        // Up
                        dpadButton(label: "▲", active: controller.telemetry.dpadUp, offset: CGSize(width: 0, height: -30), desc: "Oct+")
                        // Down
                        dpadButton(label: "▼", active: controller.telemetry.dpadDown, offset: CGSize(width: 0, height: 30), desc: "Oct-")
                        // Left
                        dpadButton(label: "◀", active: controller.telemetry.dpadLeft, offset: CGSize(width: -30, height: 0), desc: "Root-")
                        // Right
                        dpadButton(label: "▶", active: controller.telemetry.dpadRight, offset: CGSize(width: 30, height: 0), desc: "Root+")
                    }
                    .frame(width: 104, height: 104)
                }
                .frame(width: 120)

                Spacer(minLength: 0)

                // Center Column: Left Stick, PS + Mic, Right Stick
                HStack(spacing: 16) {
                    StickRadarView(
                        title: "LEFT STICK",
                        x: controller.telemetry.leftStickX,
                        y: controller.telemetry.leftStickY,
                        isClicked: controller.telemetry.l3,
                        subtitle: "Pitch Bend / Mod",
                        theme: theme
                    )

                    // PS Home and Mic Mute Column
                    VStack(spacing: 10) {
                        psButtonView
                        micMuteButtonView
                    }
                    .frame(width: 54)

                    StickRadarView(
                        title: "RIGHT STICK",
                        x: controller.telemetry.rightStickX,
                        y: controller.telemetry.rightStickY,
                        isClicked: controller.telemetry.r3,
                        subtitle: "Pan (CC10) / Res (CC71)",
                        theme: theme
                    )
                }

                Spacer(minLength: 0)

                // Right Wing: Face Buttons Diamond
                VStack(spacing: 4) {
                    Text("FACE CHORDS")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(theme.textSecondary)

                    ZStack {
                        Circle()
                            .fill(theme.wellBg)
                            .frame(width: 104, height: 104)
                            .overlay(Circle().stroke(theme.wellBorder, lineWidth: 1))

                        // Triangle (VI)
                        faceButton(symbol: "△", chord: chordLabel(degree: 5), active: controller.telemetry.triangle, color: .green, offset: CGSize(width: 0, height: -32))
                        // Circle (IV)
                        faceButton(symbol: "○", chord: chordLabel(degree: 3), active: controller.telemetry.circle, color: .red, offset: CGSize(width: 32, height: 0))
                        // Cross (I)
                        faceButton(symbol: "✕", chord: chordLabel(degree: 0), active: controller.telemetry.cross, color: .blue, offset: CGSize(width: 0, height: 32))
                        // Square (II)
                        faceButton(symbol: "□", chord: chordLabel(degree: 1), active: controller.telemetry.square, color: .pink, offset: CGSize(width: -32, height: 0))
                    }
                    .frame(width: 104, height: 104)
                }
                .frame(width: 120)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 6)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(theme.chassisBg)
                .shadow(color: isDarkMode ? Color.black.opacity(0.4) : Color.black.opacity(0.06), radius: 10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(theme.chassisBorder, lineWidth: 1.5)
        )
    }

    // MARK: - Center Touchpad View
    private var touchpadView: some View {
        Button(action: { controller.triggerPanic() }) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(theme.innerBridge)
                    .frame(width: 130, height: 56)

                VStack(spacing: 2) {
                    Text("DUALSENSE")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundColor(theme.textSecondary)
                    Text("TOUCHPAD")
                        .font(.system(size: 7, weight: .medium, design: .monospaced))
                        .foregroundColor(theme.textTertiary)
                    Text(controller.telemetry.touchpad ? "PANIC" : "CLICK = PANIC")
                        .font(.system(size: 7, weight: .heavy))
                        .foregroundColor(controller.telemetry.touchpad ? .red : .green)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(controller.telemetry.touchpad ? Color.red : layerColor.opacity(0.7), lineWidth: 1.5)
            )
            .shadow(color: layerColor.opacity(0.3), radius: 6)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Create Button
    private var createButtonView: some View {
        Button(action: { controller.cycleChordType() }) {
            VStack(spacing: 2) {
                HStack(spacing: 2) {
                    ForEach(0..<3) { _ in
                        Rectangle()
                            .fill(controller.telemetry.create ? Color.cyan : theme.textSecondary)
                            .frame(width: 1.5, height: 6)
                    }
                }
                Text("CREATE")
                    .font(.system(size: 7, weight: .black, design: .monospaced))
                    .foregroundColor(controller.telemetry.create ? .cyan : theme.textSecondary)
                Text(controller.chordType.rawValue)
                    .font(.system(size: 6, weight: .bold))
                    .foregroundColor(.cyan)
            }
            .frame(width: 48, height: 32)
            .background(controller.telemetry.create ? Color.cyan.opacity(0.2) : theme.buttonBg)
            .overlay(Capsule().stroke(controller.telemetry.create ? Color.cyan : theme.buttonBorder, lineWidth: 1.2))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Options Button
    private var optionsButtonView: some View {
        Button(action: { controller.toggleArpeggiator() }) {
            VStack(spacing: 2) {
                VStack(spacing: 1.5) {
                    ForEach(0..<3) { _ in
                        Rectangle()
                            .fill(controller.telemetry.options ? Color.orange : theme.textSecondary)
                            .frame(width: 9, height: 1.5)
                    }
                }
                Text("OPTIONS")
                    .font(.system(size: 7, weight: .black, design: .monospaced))
                    .foregroundColor(controller.telemetry.options ? .orange : theme.textSecondary)
                Text(controller.isArpActive ? "ARP ON" : "ARP OFF")
                    .font(.system(size: 6, weight: .bold))
                    .foregroundColor(controller.isArpActive ? .orange : theme.textTertiary)
            }
            .frame(width: 48, height: 32)
            .background(controller.telemetry.options ? Color.orange.opacity(0.2) : theme.buttonBg)
            .overlay(Capsule().stroke(controller.telemetry.options ? Color.orange : theme.buttonBorder, lineWidth: 1.2))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - PS Button
    private var psButtonView: some View {
        Button(action: { controller.toggleLatchMode() }) {
            ZStack {
                Circle()
                    .fill(controller.telemetry.home ? Color.blue : theme.buttonBg)
                    .frame(width: 32, height: 32)
                    .overlay(Circle().stroke(controller.telemetry.home ? Color.blue : theme.buttonBorder, lineWidth: 1.5))
                    .shadow(color: controller.telemetry.home ? .blue : .clear, radius: 6)

                Text("PS")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundColor(controller.telemetry.home ? .white : theme.textPrimary)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Mic Mute Button
    private var micMuteButtonView: some View {
        Button(action: { controller.triggerPanic() }) {
            VStack(spacing: 2) {
                ZStack {
                    Capsule()
                        .fill(controller.telemetry.micMuted ? Color.orange.opacity(0.3) : theme.buttonBg)
                        .frame(width: 30, height: 12)
                        .overlay(Capsule().stroke(controller.telemetry.micMuted ? Color.orange : theme.buttonBorder, lineWidth: 1))

                    Circle()
                        .fill(controller.telemetry.micMuted ? Color.orange : Color.orange.opacity(0.4))
                        .frame(width: 3.5, height: 3.5)
                        .shadow(color: controller.telemetry.micMuted ? .orange : .clear, radius: 4)
                }

                Text("MUTE")
                    .font(.system(size: 6, weight: .heavy, design: .monospaced))
                    .foregroundColor(controller.telemetry.micMuted ? .orange : theme.textTertiary)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Performance & Telemetry Deck
    private var performanceDeckView: some View {
        HStack(alignment: .top, spacing: 14) {
            // Gyroscope & Haptic Feedback Card
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "gyroscope")
                        .foregroundColor(.cyan)
                    Text("6-AXIS GYRO & HAPTICS")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(theme.textPrimary)
                    Spacer()
                    Text(String(format: "TILT: %3.0f°", controller.telemetry.pitchAngle))
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundColor(.cyan)
                }

                // Tilt Angle Horizon Meter
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(theme.wellBg)
                        .frame(height: 14)

                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: [.cyan, .blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(8, CGFloat(controller.telemetry.pitchAngle / 75.0) * 180), height: 14)
                }
                .frame(maxWidth: .infinity)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(theme.wellBorder, lineWidth: 1))

                HStack {
                    Text("MOD WHEEL (CC #1):")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(theme.textSecondary)
                    Text("\(controller.telemetry.modWheel) / 127")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.cyan)

                    Spacer()

                    Text("VIBRATION:")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(theme.textSecondary)
                    Text(String(format: "%.0f%%", controller.telemetry.hapticIntensity * 100))
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(controller.telemetry.hapticIntensity > 0.05 ? .orange : theme.textTertiary)
                    if controller.telemetry.hapticIntensity > 0.05 {
                        Image(systemName: "waveform.path")
                            .foregroundColor(.orange)
                    }
                }
            }
            .padding(12)
            .background(theme.cardBg)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(theme.cardBorder, lineWidth: 1))

            // Arpeggiator & Musical Chord Card
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "metronome.fill")
                        .foregroundColor(.orange)
                    Text("ARPEGGIATOR & CHORDS")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(theme.textPrimary)
                    Spacer()
                    Text("BPM: \(Int(controller.bpm))")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundColor(.orange)
                }

                // Live Active Chord & Notes
                HStack(spacing: 8) {
                    Text("ACTIVE:")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(theme.textSecondary)

                    Text(controller.telemetry.activeChordName)
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundColor(.green)

                    Spacer()

                    Text(controller.telemetry.activeChordNotes.map { controller.noteNameForPitch($0) }.joined(separator: " "))
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(theme.textPrimary)
                }

                // 8-Step LED Sequencer indicator
                HStack(spacing: 5) {
                    ForEach(0..<8) { step in
                        Circle()
                            .fill(controller.isArpActive && (controller.telemetry.currentArpStep % 8 == step) ? Color.orange : theme.wellBorder)
                            .frame(width: 8, height: 8)
                            .shadow(color: controller.isArpActive && (controller.telemetry.currentArpStep % 8 == step) ? .orange : .clear, radius: 4)
                    }
                    Spacer()
                    Text("RATE: \(controller.arpRate.rawValue)")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(theme.textSecondary)
                }
            }
            .padding(12)
            .background(theme.cardBg)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(theme.cardBorder, lineWidth: 1))
        }
    }

    // MARK: - Status Console View
    private var statusConsoleView: some View {
        HStack {
            Text("EVENT:")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(theme.textSecondary)

            Text(controller.lastEventDescription)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(.cyan)

            Spacer()

            Text("ROOT: \(controller.noteNameForPitch(controller.rootKey)) | OCT: \(controller.octaveShift / 12 > 0 ? "+" : "")\(controller.octaveShift / 12)")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(theme.textSecondary)

            Text("• COREMIDI ACTIVE")
                .font(.system(size: 9, weight: .heavy))
                .foregroundColor(.green)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(theme.consoleBg)
        .cornerRadius(8)
    }

    // MARK: - Helpers
    private var layerColor: Color {
        switch controller.currentLayer {
        case .base: return .green
        case .harmony: return .blue
        case .looper: return .orange
        case .parameters: return .purple
        }
    }

    private func chordLabel(degree: Int) -> String {
        let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let diatonicOffsets = [0, 2, 4, 5, 7, 9, 11]
        let rootOffset = diatonicOffsets[degree % diatonicOffsets.count]
        let pitch = Int(controller.rootKey) + rootOffset
        let rootNote = noteNames[pitch % 12]

        if !controller.chordMode { return rootNote }

        let isMinor = (degree == 1 || degree == 5)
        let suffix: String
        switch controller.chordType {
        case .triad: suffix = isMinor ? "m" : "M"
        case .seventh: suffix = isMinor ? "m7" : "M7"
        case .sus4: suffix = "sus"
        case .add9: suffix = isMinor ? "m9" : "9"
        }
        return "\(rootNote)\(suffix)"
    }

    private func dpadButton(label: String, active: Bool, offset: CGSize, desc: String) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(active ? Color.cyan : theme.buttonBg)
                .frame(width: 26, height: 26)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(active ? Color.cyan : theme.buttonBorder, lineWidth: 1)
                )
                .shadow(color: active ? .cyan : .clear, radius: 6)

            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(active ? .black : theme.textPrimary)
        }
        .offset(offset)
    }

    private func faceButton(symbol: String, chord: String, active: Bool, color: Color, offset: CGSize) -> some View {
        ZStack {
            Circle()
                .fill(active ? color : theme.buttonBg)
                .frame(width: 30, height: 30)
                .overlay(
                    Circle().stroke(active ? color : theme.buttonBorder, lineWidth: 1.5)
                )
                .shadow(color: active ? color : .clear, radius: 8)

            VStack(spacing: 0) {
                Text(symbol)
                    .font(.system(size: 11, weight: .black))
                    .foregroundColor(active ? .white : color)
                Text(chord)
                    .font(.system(size: 6.5, weight: .heavy, design: .monospaced))
                    .foregroundColor(active ? .white : theme.textSecondary)
            }
        }
        .offset(offset)
    }
}
