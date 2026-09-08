import SwiftUI
import DualSynthCore

public enum ThemeMode: String, CaseIterable {
    case auto = "Auto"
    case light = "Light"
    case dark = "Dark"
}

public struct ThemeColors {
    public let isDark: Bool

    public var bgCanvas: Color { isDark ? Color(white: 0.05) : Color(white: 0.93) }
    public var chassisOuter: Color { isDark ? Color(white: 0.12) : Color.white }
    public var chassisInner: Color { isDark ? Color(white: 0.07) : Color(white: 0.88) }
    public var chassisBorder: Color { isDark ? Color(white: 0.22) : Color(white: 0.80) }

    public var cardBg: Color { isDark ? Color(white: 0.10) : Color.white }
    public var cardBorder: Color { isDark ? Color(white: 0.18) : Color(white: 0.84) }

    public var wellBg: Color { isDark ? Color(white: 0.06) : Color(white: 0.92) }
    public var wellBorder: Color { isDark ? Color(white: 0.20) : Color(white: 0.78) }
    public var crosshair: Color { isDark ? Color(white: 0.18) : Color(white: 0.72) }

    public var textPrimary: Color { isDark ? Color.white : Color(white: 0.08) }
    public var textSecondary: Color { isDark ? Color(white: 0.65) : Color(white: 0.35) }
    public var textTertiary: Color { isDark ? Color(white: 0.45) : Color(white: 0.50) }

    public var buttonBg: Color { isDark ? Color(white: 0.16) : Color(white: 0.94) }
    public var buttonBorder: Color { isDark ? Color(white: 0.28) : Color(white: 0.76) }

    public var consoleBg: Color { isDark ? Color(white: 0.07) : Color(white: 0.90) }
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
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(theme.textPrimary)

            ZStack {
                // Outer bezel
                Circle()
                    .fill(theme.wellBg)
                    .frame(width: 110, height: 110)
                    .overlay(
                        Circle()
                            .stroke(isClicked ? Color.cyan : theme.wellBorder, lineWidth: isClicked ? 3 : 1.5)
                    )

                // Concentric guide ring
                Circle()
                    .stroke(theme.crosshair.opacity(0.4), lineWidth: 1)
                    .frame(width: 60, height: 60)

                // Crosshairs
                Path { path in
                    path.move(to: CGPoint(x: 55, y: 10))
                    path.addLine(to: CGPoint(x: 55, y: 100))
                    path.move(to: CGPoint(x: 10, y: 55))
                    path.addLine(to: CGPoint(x: 100, y: 55))
                }
                .stroke(theme.crosshair, lineWidth: 1.2)

                // Stick puck
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [isClicked ? .cyan : .blue, theme.wellBorder]),
                            center: .center,
                            startRadius: 3,
                            endRadius: 18
                        )
                    )
                    .frame(width: 32, height: 32)
                    .shadow(color: isClicked ? .cyan : .blue.opacity(0.5), radius: 6)
                    .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 1))
                    .offset(x: CGFloat(x) * 36, y: CGFloat(-y) * 36)
            }
            .frame(width: 110, height: 110)

            HStack(spacing: 8) {
                Text(String(format: "X:%+.2f", x))
                Text(String(format: "Y:%+.2f", y))
            }
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .foregroundColor(theme.textSecondary)

            Text(subtitle)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(theme.textTertiary)
                .lineLimit(1)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 14).fill(theme.cardBg))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(theme.cardBorder, lineWidth: 1))
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
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(theme.textPrimary)

            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(theme.wellBg)
                    .frame(width: 36, height: 90)

                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        LinearGradient(
                            colors: [activeColor, activeColor.opacity(0.6)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 36, height: max(6, CGFloat(value) * 90))
                    .shadow(color: activeColor.opacity(value > 0.05 ? 0.6 : 0.0), radius: 5)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(theme.wellBorder, lineWidth: 1.2)
            )

            Text(String(format: "%3.0f%%", value * 100))
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundColor(value > 0.05 ? activeColor : theme.textSecondary)

            Text(subtitle)
                .font(.system(size: 9, weight: .bold))
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
            VStack(spacing: 14) {
                // Top Header Bar
                headerBar

                // Centered DualSense Controller Chassis
                HStack {
                    Spacer(minLength: 0)
                    controllerChassisView
                        .frame(maxWidth: 820)
                    Spacer(minLength: 0)
                }

                // Lower Performance Deck
                performanceDeckView
                    .frame(maxWidth: 820)

                // Bottom Status Console
                statusConsoleView
                    .frame(maxWidth: 820)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(minWidth: 780, minHeight: 600)
        .background(theme.bgCanvas)
    }

    // MARK: - Header Bar
    private var headerBar: some View {
        HStack(spacing: 12) {
            // Connection status
            HStack(spacing: 8) {
                Circle()
                    .fill(controller.isConnected ? Color.green : Color.red)
                    .frame(width: 10, height: 10)
                    .shadow(color: controller.isConnected ? .green : .red, radius: 5)

                Text(controller.controllerName)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(theme.textPrimary)
            }

            Spacer()

            // Active Layer Badge
            HStack(spacing: 6) {
                Circle()
                    .fill(layerColor)
                    .frame(width: 8, height: 8)
                Text(controller.currentLayer.rawValue.uppercased())
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundColor(layerColor)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(layerColor.opacity(0.18))
            .overlay(Capsule().stroke(layerColor, lineWidth: 1.5))
            .clipShape(Capsule())

            // Musical Mode Badges
            HStack(spacing: 8) {
                Button(action: { controller.toggleChordMode() }) {
                    Text("CHORDS: \(controller.chordMode ? "ON" : "OFF")")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(controller.chordMode ? Color.green.opacity(0.2) : theme.buttonBg)
                        .foregroundColor(controller.chordMode ? .green : theme.textSecondary)
                        .cornerRadius(7)
                        .overlay(RoundedRectangle(cornerRadius: 7).stroke(controller.chordMode ? Color.green : theme.buttonBorder, lineWidth: 1.2))
                }
                .buttonStyle(.plain)

                Button(action: { controller.toggleLatchMode() }) {
                    Text("LATCH: \(controller.latchMode ? "ON 🔒" : "OFF")")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(controller.latchMode ? Color.cyan.opacity(0.2) : theme.buttonBg)
                        .foregroundColor(controller.latchMode ? .cyan : theme.textSecondary)
                        .cornerRadius(7)
                        .overlay(RoundedRectangle(cornerRadius: 7).stroke(controller.latchMode ? Color.cyan : theme.buttonBorder, lineWidth: 1.2))
                }
                .buttonStyle(.plain)

                Button(action: { controller.toggleArpeggiator() }) {
                    Text("ARP: \(controller.isArpActive ? "ON ⚡" : "OFF")")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(controller.isArpActive ? Color.orange.opacity(0.2) : theme.buttonBg)
                        .foregroundColor(controller.isArpActive ? .orange : theme.textSecondary)
                        .cornerRadius(7)
                        .overlay(RoundedRectangle(cornerRadius: 7).stroke(controller.isArpActive ? Color.orange : theme.buttonBorder, lineWidth: 1.2))
                }
                .buttonStyle(.plain)
            }

            Spacer()

            // Theme Switcher Menu
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
                HStack(spacing: 6) {
                    Image(systemName: isDarkMode ? "moon.fill" : "sun.max.fill")
                        .foregroundColor(isDarkMode ? .yellow : .orange)
                    Text(themeSelection.rawValue)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(theme.textPrimary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(theme.buttonBg)
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(theme.buttonBorder, lineWidth: 1.2))
                .cornerRadius(7)
            }
            .menuStyle(.borderlessButton)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(theme.cardBg)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(theme.cardBorder, lineWidth: 1))
    }

    // MARK: - DualSense Controller Chassis View
    private var controllerChassisView: some View {
        VStack(spacing: 12) {
            // Upper Triggers & Shoulders
            HStack(spacing: 20) {
                // L2 Trigger & L1 Bumper
                HStack(spacing: 14) {
                    TriggerGaugeView(
                        title: "L2 TRIGGER",
                        value: controller.telemetry.leftTrigger,
                        subtitle: "CC74 / CC2 Cutoff",
                        activeColor: .purple,
                        theme: theme
                    )

                    VStack(spacing: 5) {
                        Text("L1 BUMPER")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(theme.textPrimary)

                        RoundedRectangle(cornerRadius: 9)
                            .fill(controller.telemetry.l1 ? Color.blue : theme.buttonBg)
                            .frame(width: 80, height: 38)
                            .overlay(
                                Text("HARMONY")
                                    .font(.system(size: 10, weight: .black))
                                    .foregroundColor(controller.telemetry.l1 ? .white : theme.textSecondary)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 9)
                                    .stroke(controller.telemetry.l1 ? Color.blue : theme.buttonBorder, lineWidth: 1.5)
                            )
                            .shadow(color: controller.telemetry.l1 ? .blue : .clear, radius: 8)
                    }
                }

                Spacer()

                // Center Touchpad with Glowing Lightbar Contour & Create/Options Buttons
                HStack(spacing: 14) {
                    // Create Button (No text, pure iconic ||| glyph)
                    createButtonView

                    // Touchpad with lightbar
                    touchpadView

                    // Options Button (No text, pure iconic ☰ glyph)
                    optionsButtonView
                }

                Spacer()

                // R1 Bumper & R2 Trigger
                HStack(spacing: 14) {
                    VStack(spacing: 5) {
                        Text("R1 BUMPER")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(theme.textPrimary)

                        RoundedRectangle(cornerRadius: 9)
                            .fill(controller.telemetry.r1 ? Color.orange : theme.buttonBg)
                            .frame(width: 80, height: 38)
                            .overlay(
                                Text("ARP / RHYTHM")
                                    .font(.system(size: 9, weight: .black))
                                    .foregroundColor(controller.telemetry.r1 ? .white : theme.textSecondary)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 9)
                                    .stroke(controller.telemetry.r1 ? Color.orange : theme.buttonBorder, lineWidth: 1.5)
                            )
                            .shadow(color: controller.telemetry.r1 ? .orange : .clear, radius: 8)
                    }

                    TriggerGaugeView(
                        title: "R2 TRIGGER",
                        value: controller.telemetry.rightTrigger,
                        subtitle: "Expr / Velocity",
                        activeColor: .green,
                        theme: theme
                    )
                }
            }
            .padding(.horizontal, 16)

            // Dynamic RGB Lightbar Arc
            RoundedRectangle(cornerRadius: 4)
                .fill(
                    LinearGradient(
                        colors: [layerColor.opacity(0.1), layerColor, layerColor.opacity(0.1)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 6)
                .shadow(color: layerColor, radius: 10)
                .padding(.horizontal, 36)

            // Main Face Area: D-Pad (Left), Center Bridge (PS + Mic + Sticks), Face Buttons (Right)
            HStack(alignment: .center, spacing: 20) {
                // Left Wing: D-Pad
                VStack(spacing: 6) {
                    Text(dpadHeaderTitle)
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .foregroundColor(controller.isL1Held ? .blue : (controller.isR1Held ? .orange : theme.textSecondary))

                    ZStack {
                        Circle()
                            .fill(theme.chassisInner)
                            .frame(width: 120, height: 120)
                            .overlay(Circle().stroke(theme.wellBorder, lineWidth: 1.5))

                        // Up
                        dpadButton(label: dpadLabel(for: .up), active: controller.telemetry.dpadUp, offset: CGSize(width: 0, height: -35))
                        // Down
                        dpadButton(label: dpadLabel(for: .down), active: controller.telemetry.dpadDown, offset: CGSize(width: 0, height: 35))
                        // Left
                        dpadButton(label: dpadLabel(for: .left), active: controller.telemetry.dpadLeft, offset: CGSize(width: -35, height: 0))
                        // Right
                        dpadButton(label: dpadLabel(for: .right), active: controller.telemetry.dpadRight, offset: CGSize(width: 35, height: 0))
                    }
                    .frame(width: 120, height: 120)
                }
                .frame(width: 135)

                Spacer(minLength: 0)

                // Center Bridge: Left Stick, PS + Mic, Right Stick
                HStack(spacing: 16) {
                    StickRadarView(
                        title: "LEFT STICK",
                        x: controller.telemetry.leftStickX,
                        y: controller.telemetry.leftStickY,
                        isClicked: controller.telemetry.l3,
                        subtitle: controller.isL1Held ? "Pitch Bend" : "Pitch Bend / Mod",
                        theme: theme
                    )

                    // PS Home & Mic Mute Column
                    VStack(spacing: 12) {
                        psButtonView
                        micMuteButtonView
                    }
                    .frame(width: 58)

                    StickRadarView(
                        title: "RIGHT STICK",
                        x: controller.telemetry.rightStickX,
                        y: controller.telemetry.rightStickY,
                        isClicked: controller.telemetry.r3,
                        subtitle: controller.isL1Held ? "Width / Chorus" : "Pan (CC10) / Res (CC71)",
                        theme: theme
                    )
                }

                Spacer(minLength: 0)

                // Right Wing: Face Buttons Diamond with BIG BOLD CHORD LABELS
                VStack(spacing: 6) {
                    Text(faceHeaderTitle)
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .foregroundColor(controller.isL1Held ? .blue : (controller.isR1Held ? .orange : theme.textSecondary))

                    ZStack {
                        Circle()
                            .fill(theme.chassisInner)
                            .frame(width: 120, height: 120)
                            .overlay(Circle().stroke(theme.wellBorder, lineWidth: 1.5))

                        // Triangle (VI)
                        faceButton(symbol: "△", actionText: faceActionText(index: 3), active: controller.telemetry.triangle, color: .green, offset: CGSize(width: 0, height: -36))
                        // Circle (IV)
                        faceButton(symbol: "○", actionText: faceActionText(index: 2), active: controller.telemetry.circle, color: .red, offset: CGSize(width: 36, height: 0))
                        // Cross (I)
                        faceButton(symbol: "✕", actionText: faceActionText(index: 0), active: controller.telemetry.cross, color: .blue, offset: CGSize(width: 0, height: 36))
                        // Square (II)
                        faceButton(symbol: "□", actionText: faceActionText(index: 1), active: controller.telemetry.square, color: .pink, offset: CGSize(width: -36, height: 0))
                    }
                    .frame(width: 120, height: 120)
                }
                .frame(width: 135)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 8)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(theme.chassisOuter)
                .shadow(color: isDarkMode ? Color.black.opacity(0.5) : Color.black.opacity(0.08), radius: 14)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(theme.chassisBorder, lineWidth: 1.5)
        )
    }

    // MARK: - Center Touchpad View
    private var touchpadView: some View {
        Button(action: { controller.triggerPanic() }) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(theme.chassisInner)
                    .frame(width: 140, height: 62)

                VStack(spacing: 3) {
                    Text("DUALSENSE")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(theme.textSecondary)
                    Text(controller.telemetry.touchpad ? "PANIC TRIGGERED" : "CLICK = PANIC")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundColor(controller.telemetry.touchpad ? .red : .green)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(controller.telemetry.touchpad ? Color.red : layerColor.opacity(0.8), lineWidth: 1.8)
            )
            .shadow(color: layerColor.opacity(0.4), radius: 8)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Create Button (Pure Iconic ||| Glyph, No Tiny Text)
    private var createButtonView: some View {
        Button(action: { controller.cycleChordType() }) {
            HStack(spacing: 3) {
                ForEach(0..<3) { _ in
                    Capsule()
                        .fill(controller.telemetry.create ? Color.cyan : theme.textSecondary)
                        .frame(width: 2.2, height: 14)
                }
            }
            .frame(width: 38, height: 32)
            .background(controller.telemetry.create ? Color.cyan.opacity(0.25) : theme.buttonBg)
            .overlay(Capsule().stroke(controller.telemetry.create ? Color.cyan : theme.buttonBorder, lineWidth: 1.5))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .help("Create Button (Share): Cycle Chord Types")
    }

    // MARK: - Options Button (Pure Iconic ☰ Glyph, No Tiny Text)
    private var optionsButtonView: some View {
        Button(action: { controller.cycleScale() }) {
            VStack(spacing: 3) {
                ForEach(0..<3) { _ in
                    Capsule()
                        .fill(controller.telemetry.options ? Color.orange : theme.textSecondary)
                        .frame(width: 14, height: 2.2)
                }
            }
            .frame(width: 38, height: 32)
            .background(controller.telemetry.options ? Color.orange.opacity(0.25) : theme.buttonBg)
            .overlay(Capsule().stroke(controller.telemetry.options ? Color.orange : theme.buttonBorder, lineWidth: 1.5))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .help("Options Button (Menu): Cycle Scale")
    }

    // MARK: - PS Button
    private var psButtonView: some View {
        Button(action: { controller.toggleLatchMode() }) {
            ZStack {
                Circle()
                    .fill(controller.telemetry.home ? Color.blue : theme.buttonBg)
                    .frame(width: 36, height: 36)
                    .overlay(Circle().stroke(controller.telemetry.home ? Color.blue : theme.buttonBorder, lineWidth: 1.5))
                    .shadow(color: controller.telemetry.home ? .blue : .clear, radius: 8)

                Text("PS")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundColor(controller.telemetry.home ? .white : theme.textPrimary)
            }
        }
        .buttonStyle(.plain)
        .help("PS Button: Toggle Latch Mode")
    }

    // MARK: - Mic Mute Button
    private var micMuteButtonView: some View {
        Button(action: { controller.triggerPanic() }) {
            VStack(spacing: 2) {
                ZStack {
                    Capsule()
                        .fill(controller.telemetry.micMuted ? Color.orange.opacity(0.4) : theme.buttonBg)
                        .frame(width: 34, height: 14)
                        .overlay(Capsule().stroke(controller.telemetry.micMuted ? Color.orange : theme.buttonBorder, lineWidth: 1.2))

                    Circle()
                        .fill(controller.telemetry.micMuted ? Color.orange : Color.orange.opacity(0.4))
                        .frame(width: 4.5, height: 4.5)
                        .shadow(color: controller.telemetry.micMuted ? .orange : .clear, radius: 5)
                }

                Text("MUTE")
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundColor(controller.telemetry.micMuted ? .orange : theme.textTertiary)
            }
        }
        .buttonStyle(.plain)
        .help("Mic Button: Panic / Mute All Notes")
    }

    // MARK: - Performance & Telemetry Deck
    private var performanceDeckView: some View {
        HStack(alignment: .top, spacing: 14) {
            // Gyroscope & Haptic Feedback Card
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "gyroscope")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.cyan)
                    Text("6-AXIS GYRO & HAPTICS")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(theme.textPrimary)
                    Spacer()
                    Text(String(format: "TILT: %3.0f°", controller.telemetry.pitchAngle))
                        .font(.system(size: 13, weight: .black, design: .monospaced))
                        .foregroundColor(.cyan)
                }

                // Tilt Angle Horizon Meter
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(theme.wellBg)
                        .frame(height: 16)

                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: [.cyan, .blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(8, CGFloat(controller.telemetry.pitchAngle / 75.0) * 200), height: 16)
                }
                .frame(maxWidth: .infinity)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(theme.wellBorder, lineWidth: 1.2))

                HStack {
                    Text("MOD WHEEL (CC #1):")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(theme.textSecondary)
                    Text("\(controller.telemetry.modWheel) / 127")
                        .font(.system(size: 13, weight: .black, design: .monospaced))
                        .foregroundColor(.cyan)

                    Spacer()

                    Text("VIBRATION:")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(theme.textSecondary)
                    Text(String(format: "%.0f%%", controller.telemetry.hapticIntensity * 100))
                        .font(.system(size: 13, weight: .black, design: .monospaced))
                        .foregroundColor(controller.telemetry.hapticIntensity > 0.05 ? .orange : theme.textTertiary)
                    if controller.telemetry.hapticIntensity > 0.05 {
                        Image(systemName: "waveform.path")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.orange)
                    }
                }
            }
            .padding(14)
            .background(theme.cardBg)
            .cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(theme.cardBorder, lineWidth: 1))

            // Arpeggiator & Musical Chord Card
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "metronome.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.orange)
                    Text("ARPEGGIATOR & CHORDS")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(theme.textPrimary)
                    Spacer()
                    Text("BPM: \(Int(controller.bpm))")
                        .font(.system(size: 13, weight: .black, design: .monospaced))
                        .foregroundColor(.orange)
                }

                // Live Active Chord & Notes
                HStack(spacing: 8) {
                    Text("ACTIVE:")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(theme.textSecondary)

                    Text(controller.telemetry.activeChordName)
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundColor(.green)

                    Spacer()

                    Text(controller.telemetry.activeChordNotes.map { controller.noteNameForPitch($0) }.joined(separator: " "))
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(theme.textPrimary)
                }

                // 8-Step LED Sequencer indicator
                HStack(spacing: 6) {
                    ForEach(0..<8) { step in
                        Circle()
                            .fill(controller.isArpActive && (controller.telemetry.currentArpStep % 8 == step) ? Color.orange : theme.wellBorder)
                            .frame(width: 10, height: 10)
                            .shadow(color: controller.isArpActive && (controller.telemetry.currentArpStep % 8 == step) ? .orange : .clear, radius: 5)
                    }
                    Spacer()
                    Text("RATE: \(controller.arpRate.rawValue)")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundColor(theme.textSecondary)
                }
            }
            .padding(14)
            .background(theme.cardBg)
            .cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(theme.cardBorder, lineWidth: 1))
        }
    }

    // MARK: - Status Console View
    private var statusConsoleView: some View {
        HStack {
            Text("EVENT:")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(theme.textSecondary)

            Text(controller.lastEventDescription)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(.cyan)

            Spacer()

            Text("ROOT: \(controller.noteNameForPitch(controller.rootKey)) | OCT: \(controller.octaveShift / 12 > 0 ? "+" : "")\(controller.octaveShift / 12) | SCALE: \(controller.scaleName.uppercased())")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(theme.textSecondary)

            Text("• COREMIDI ACTIVE")
                .font(.system(size: 10, weight: .black))
                .foregroundColor(.green)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(theme.consoleBg)
        .cornerRadius(10)
    }

    // MARK: - Dynamic Shift Label Resolvers
    private var layerColor: Color {
        switch controller.currentLayer {
        case .base: return .green
        case .harmony: return .blue
        case .arp: return .orange
        case .matrix: return .purple
        }
    }

    private var dpadHeaderTitle: String {
        if controller.isL1Held { return "SCALES (L1)" }
        if controller.isR1Held { return "RATE/BPM (R1)" }
        return "D-PAD (OCT/ROOT)"
    }

    private var faceHeaderTitle: String {
        if controller.isL1Held { return "VOICING (L1)" }
        if controller.isR1Held { return "PATTERN (R1)" }
        return "FACE CHORDS"
    }

    private enum DpadPos { case up, down, left, right }

    private func dpadLabel(for pos: DpadPos) -> String {
        if controller.isL1Held {
            switch pos {
            case .up: return "Maj"
            case .down: return "Min"
            case .left: return "Dor"
            case .right: return "Mixo"
            }
        } else if controller.isR1Held {
            switch pos {
            case .up: return "Rate▲"
            case .down: return "Rate▼"
            case .left: return "BPM-"
            case .right: return "BPM+"
            }
        } else {
            switch pos {
            case .up: return "▲"
            case .down: return "▼"
            case .left: return "◀"
            case .right: return "▶"
            }
        }
    }

    private func faceActionText(index: Int) -> String {
        if controller.isL1Held {
            switch index {
            case 0: return "Root"
            case 1: return "1st Inv"
            case 2: return "2nd Inv"
            case 3: return "Drop-2"
            default: return ""
            }
        } else if controller.isR1Held {
            switch index {
            case 0: return "Up ▲"
            case 1: return "Down ▼"
            case 2: return "Up/Dn"
            case 3: return "Rand"
            default: return ""
            }
        } else {
            // Base Layer: BIG CHORD NAMES
            let degreeMap = [0, 1, 3, 5]
            let degree = degreeMap[index % degreeMap.count]
            return chordLabel(degree: degree)
        }
    }

    private func chordLabel(degree: Int) -> String {
        let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let diatonicOffsets = [0, 2, 4, 5, 7, 9, 11]
        let rootOffset = diatonicOffsets[degree % diatonicOffsets.count]
        let pitch = Int(controller.rootKey) + rootOffset
        let rootNote = noteNames[pitch % 12]

        if !controller.chordMode { return rootNote }

        let isMinor = (degree == 1 || (degree == 5 && controller.scaleName == "Major") || (degree == 0 && controller.scaleName == "Minor"))
        let suffix: String
        switch controller.chordType {
        case .triad: suffix = isMinor ? "m" : "Maj"
        case .seventh: suffix = isMinor ? "m7" : "M7"
        case .sus4: suffix = "sus"
        case .add9: suffix = isMinor ? "m9" : "add9"
        }
        return "\(rootNote)\(suffix)"
    }

    private func dpadButton(label: String, active: Bool, offset: CGSize) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7)
                .fill(active ? Color.cyan : theme.buttonBg)
                .frame(width: 32, height: 32)
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(active ? Color.cyan : theme.buttonBorder, lineWidth: 1.2)
                )
                .shadow(color: active ? .cyan : .clear, radius: 8)

            Text(label)
                .font(.system(size: label.count > 2 ? 9 : 14, weight: .black))
                .foregroundColor(active ? .black : theme.textPrimary)
        }
        .offset(offset)
    }

    private func faceButton(symbol: String, actionText: String, active: Bool, color: Color, offset: CGSize) -> some View {
        ZStack {
            Circle()
                .fill(active ? color : theme.buttonBg)
                .frame(width: 36, height: 36)
                .overlay(
                    Circle().stroke(active ? color : theme.buttonBorder, lineWidth: 1.5)
                )
                .shadow(color: active ? color : .clear, radius: 10)

            VStack(spacing: 0) {
                Text(symbol)
                    .font(.system(size: 13, weight: .black))
                    .foregroundColor(active ? .white : color)
                Text(actionText)
                    .font(.system(size: actionText.count > 4 ? 8 : 10, weight: .black, design: .monospaced))
                    .foregroundColor(active ? .white : theme.textPrimary)
            }
        }
        .offset(offset)
    }
}
