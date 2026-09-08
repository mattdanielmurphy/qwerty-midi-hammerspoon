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
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(theme.textPrimary)
                .lineLimit(1)

            ZStack {
                // Outer bezel
                Circle()
                    .fill(theme.wellBg)
                    .frame(width: 96, height: 96)
                    .overlay(
                        Circle()
                            .stroke(isClicked ? Color.cyan : theme.wellBorder, lineWidth: isClicked ? 2.5 : 1.2)
                    )

                // Concentric guide ring
                Circle()
                    .stroke(theme.crosshair.opacity(0.4), lineWidth: 1)
                    .frame(width: 50, height: 50)

                // Crosshairs
                Path { path in
                    path.move(to: CGPoint(x: 48, y: 8))
                    path.addLine(to: CGPoint(x: 48, y: 88))
                    path.move(to: CGPoint(x: 8, y: 48))
                    path.addLine(to: CGPoint(x: 88, y: 48))
                }
                .stroke(theme.crosshair, lineWidth: 1)

                // Stick puck
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [isClicked ? .cyan : .blue, theme.wellBorder]),
                            center: .center,
                            startRadius: 2,
                            endRadius: 16
                        )
                    )
                    .frame(width: 28, height: 28)
                    .shadow(color: isClicked ? .cyan : .blue.opacity(0.5), radius: 5)
                    .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 1))
                    .offset(x: CGFloat(x) * 32, y: CGFloat(-y) * 32)
            }
            .frame(width: 96, height: 96)

            HStack(spacing: 6) {
                Text(String(format: "X:%+.2f", x))
                Text(String(format: "Y:%+.2f", y))
            }
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundColor(theme.textSecondary)
            .lineLimit(1)

            Text(subtitle)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(theme.textTertiary)
                .lineLimit(1)
        }
        .frame(width: 128, height: 172)
        .padding(6)
        .background(RoundedRectangle(cornerRadius: 12).fill(theme.cardBg))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(theme.cardBorder, lineWidth: 1))
        .fixedSize()
    }
}

struct TriggerGaugeView: View {
    let title: String
    let value: Float
    let subtitle: String
    let activeColor: Color
    let theme: ThemeColors

    var body: some View {
        VStack(spacing: 3) {
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(theme.textPrimary)
                .lineLimit(1)

            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 5)
                    .fill(theme.wellBg)
                    .frame(width: 32, height: 80)

                RoundedRectangle(cornerRadius: 5)
                    .fill(
                        LinearGradient(
                            colors: [activeColor, activeColor.opacity(0.6)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 32, height: max(5, CGFloat(value) * 80))
                    .shadow(color: activeColor.opacity(value > 0.05 ? 0.6 : 0.0), radius: 4)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(theme.wellBorder, lineWidth: 1)
            )

            Text(String(format: "%3.0f%%", value * 100))
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundColor(value > 0.05 ? activeColor : theme.textSecondary)
                .lineLimit(1)

            Text(subtitle)
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(theme.textTertiary)
                .lineLimit(1)
        }
        .frame(width: 72)
        .fixedSize()
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
                // Top Header Bar (With fixed non-wrapping elements)
                headerBar

                // Centered DualSense Controller Chassis
                HStack {
                    Spacer(minLength: 0)
                    controllerChassisView
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
        .frame(minWidth: 780, minHeight: 580)
        .background(theme.bgCanvas)
    }

    // MARK: - Header Bar
    private var headerBar: some View {
        HStack(spacing: 10) {
            // Connection status
            HStack(spacing: 6) {
                Circle()
                    .fill(controller.isConnected ? Color.green : Color.red)
                    .frame(width: 9, height: 9)
                    .shadow(color: controller.isConnected ? .green : .red, radius: 4)

                Text(controller.controllerName)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(theme.textPrimary)
                    .lineLimit(1)
            }
            .fixedSize()

            Spacer()

            // Active Layer Badge
            HStack(spacing: 5) {
                Circle()
                    .fill(layerColor)
                    .frame(width: 7, height: 7)
                Text(controller.currentLayer.rawValue.uppercased())
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundColor(layerColor)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(layerColor.opacity(0.18))
            .overlay(Capsule().stroke(layerColor, lineWidth: 1.2))
            .clipShape(Capsule())
            .fixedSize()

            // Musical Mode Badges (Fixed horizontal size so text NEVER wraps)
            HStack(spacing: 6) {
                Button(action: { controller.toggleChordMode() }) {
                    Text("CHORDS: \(controller.chordMode ? "ON" : "OFF")")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .lineLimit(1)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(controller.chordMode ? Color.green.opacity(0.2) : theme.buttonBg)
                        .foregroundColor(controller.chordMode ? .green : theme.textSecondary)
                        .cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(controller.chordMode ? Color.green : theme.buttonBorder, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .fixedSize()

                Button(action: { controller.toggleLatchMode() }) {
                    Text("LATCH: \(controller.latchMode ? "ON 🔒" : "OFF")")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .lineLimit(1)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(controller.latchMode ? Color.cyan.opacity(0.2) : theme.buttonBg)
                        .foregroundColor(controller.latchMode ? .cyan : theme.textSecondary)
                        .cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(controller.latchMode ? Color.cyan : theme.buttonBorder, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .fixedSize()

                Button(action: { controller.toggleArpeggiator() }) {
                    Text("ARP: \(controller.isArpActive ? "ON ⚡" : "OFF")")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .lineLimit(1)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(controller.isArpActive ? Color.orange.opacity(0.2) : theme.buttonBg)
                        .foregroundColor(controller.isArpActive ? .orange : theme.textSecondary)
                        .cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(controller.isArpActive ? Color.orange : theme.buttonBorder, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .fixedSize()
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
            .fixedSize()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(theme.cardBg)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(theme.cardBorder, lineWidth: 1))
    }

    // MARK: - DualSense Controller Chassis View (Rigid Static Dimensions)
    private var controllerChassisView: some View {
        VStack(spacing: 10) {
            // Upper Triggers & Shoulders
            HStack(spacing: 16) {
                // L2 Trigger & L1 Bumper
                HStack(spacing: 10) {
                    TriggerGaugeView(
                        title: "L2 TRIGGER",
                        value: controller.telemetry.leftTrigger,
                        subtitle: "CC74 Cutoff",
                        activeColor: .purple,
                        theme: theme
                    )

                    VStack(spacing: 4) {
                        Text("L1 BUMPER")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(theme.textPrimary)
                            .lineLimit(1)

                        RoundedRectangle(cornerRadius: 8)
                            .fill(controller.telemetry.l1 ? Color.blue : theme.buttonBg)
                            .frame(width: 76, height: 34)
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
                    .frame(width: 76)
                    .fixedSize()
                }

                Spacer()

                // Center Touchpad with Glowing Lightbar Contour & Create/Options Buttons
                HStack(spacing: 12) {
                    createButtonView
                    touchpadView
                    optionsButtonView
                }
                .fixedSize()

                Spacer()

                // R1 Bumper & R2 Trigger
                HStack(spacing: 10) {
                    VStack(spacing: 4) {
                        Text("R1 BUMPER")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(theme.textPrimary)
                            .lineLimit(1)

                        RoundedRectangle(cornerRadius: 8)
                            .fill(controller.telemetry.r1 ? Color.orange : theme.buttonBg)
                            .frame(width: 76, height: 34)
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
                    .frame(width: 76)
                    .fixedSize()

                    TriggerGaugeView(
                        title: "R2 TRIGGER",
                        value: controller.telemetry.rightTrigger,
                        subtitle: "Expr / Vel",
                        activeColor: .green,
                        theme: theme
                    )
                }
            }
            .padding(.horizontal, 14)

            // Dynamic RGB Lightbar Arc
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

            // Main Face Area: Static Width Columns (Never shrinks or reflows)
            HStack(alignment: .center, spacing: 14) {
                // 1. D-Pad Column (Static Width 128)
                VStack(spacing: 6) {
                    Text(dpadHeaderTitle)
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundColor(controller.isL1Held ? .blue : (controller.isR1Held ? .orange : theme.textSecondary))
                        .lineLimit(1)

                    ZStack {
                        Circle()
                            .fill(theme.chassisInner)
                            .frame(width: 108, height: 108)
                            .overlay(Circle().stroke(theme.wellBorder, lineWidth: 1.2))

                        dpadButton(label: dpadLabel(for: .up), active: controller.telemetry.dpadUp, offset: CGSize(width: 0, height: -32))
                        dpadButton(label: dpadLabel(for: .down), active: controller.telemetry.dpadDown, offset: CGSize(width: 0, height: 32))
                        dpadButton(label: dpadLabel(for: .left), active: controller.telemetry.dpadLeft, offset: CGSize(width: -32, height: 0))
                        dpadButton(label: dpadLabel(for: .right), active: controller.telemetry.dpadRight, offset: CGSize(width: 32, height: 0))
                    }
                    .frame(width: 108, height: 108)
                }
                .frame(width: 128, height: 172)
                .fixedSize()

                // 2. Left Stick (Static Width 128)
                StickRadarView(
                    title: "LEFT STICK",
                    x: controller.telemetry.leftStickX,
                    y: controller.telemetry.leftStickY,
                    isClicked: controller.telemetry.l3,
                    subtitle: controller.isL1Held ? "Pitch Bend" : "Pitch Bend / Mod",
                    theme: theme
                )

                // 3. Center Column: PS Button + Mic Button (Static Width 50)
                VStack(spacing: 10) {
                    psButtonView
                    micMuteButtonView
                }
                .frame(width: 50, height: 172)
                .fixedSize()

                // 4. Right Stick (Static Width 128, NEVER Collapses)
                StickRadarView(
                    title: "RIGHT STICK",
                    x: controller.telemetry.rightStickX,
                    y: controller.telemetry.rightStickY,
                    isClicked: controller.telemetry.r3,
                    subtitle: controller.isL1Held ? "Width / Chorus" : "Pan / Res (CC71)",
                    theme: theme
                )

                // 5. Face Buttons Diamond (Static Width 128)
                VStack(spacing: 6) {
                    Text(faceHeaderTitle)
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundColor(controller.isL1Held ? .blue : (controller.isR1Held ? .orange : theme.textSecondary))
                        .lineLimit(1)

                    ZStack {
                        Circle()
                            .fill(theme.chassisInner)
                            .frame(width: 108, height: 108)
                            .overlay(Circle().stroke(theme.wellBorder, lineWidth: 1.2))

                        faceButton(symbol: "△", actionText: faceActionText(index: 3), active: controller.telemetry.triangle, color: .green, offset: CGSize(width: 0, height: -32))
                        faceButton(symbol: "○", actionText: faceActionText(index: 2), active: controller.telemetry.circle, color: .red, offset: CGSize(width: 32, height: 0))
                        faceButton(symbol: "✕", actionText: faceActionText(index: 0), active: controller.telemetry.cross, color: .blue, offset: CGSize(width: 0, height: 32))
                        faceButton(symbol: "□", actionText: faceActionText(index: 1), active: controller.telemetry.square, color: .pink, offset: CGSize(width: -32, height: 0))
                    }
                    .frame(width: 108, height: 108)
                }
                .frame(width: 128, height: 172)
                .fixedSize()
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 6)
        }
        .frame(width: 760)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(theme.chassisOuter)
                .shadow(color: isDarkMode ? Color.black.opacity(0.4) : Color.black.opacity(0.06), radius: 10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(theme.chassisBorder, lineWidth: 1.5)
        )
        .fixedSize()
    }

    // MARK: - Center Touchpad View
    private var touchpadView: some View {
        Button(action: { controller.triggerPanic() }) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(theme.chassisInner)
                    .frame(width: 130, height: 56)

                VStack(spacing: 2) {
                    Text("DUALSENSE")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(theme.textSecondary)
                    Text(controller.telemetry.touchpad ? "PANIC" : "CLICK = PANIC")
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .foregroundColor(controller.telemetry.touchpad ? .red : .green)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(controller.telemetry.touchpad ? Color.red : layerColor.opacity(0.8), lineWidth: 1.5)
            )
            .shadow(color: layerColor.opacity(0.3), radius: 6)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Create Button (Pure Iconic ||| Glyph, No Tiny Text)
    private var createButtonView: some View {
        Button(action: { controller.cycleChordType() }) {
            HStack(spacing: 2.5) {
                ForEach(0..<3) { _ in
                    Capsule()
                        .fill(controller.telemetry.create ? Color.cyan : theme.textSecondary)
                        .frame(width: 2, height: 12)
                }
            }
            .frame(width: 34, height: 28)
            .background(controller.telemetry.create ? Color.cyan.opacity(0.25) : theme.buttonBg)
            .overlay(Capsule().stroke(controller.telemetry.create ? Color.cyan : theme.buttonBorder, lineWidth: 1.2))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .help("Create: Cycle Chord Types")
    }

    // MARK: - Options Button (Pure Iconic ☰ Glyph, No Tiny Text)
    private var optionsButtonView: some View {
        Button(action: { controller.cycleScale() }) {
            VStack(spacing: 2.5) {
                ForEach(0..<3) { _ in
                    Capsule()
                        .fill(controller.telemetry.options ? Color.orange : theme.textSecondary)
                        .frame(width: 12, height: 2)
                }
            }
            .frame(width: 34, height: 28)
            .background(controller.telemetry.options ? Color.orange.opacity(0.25) : theme.buttonBg)
            .overlay(Capsule().stroke(controller.telemetry.options ? Color.orange : theme.buttonBorder, lineWidth: 1.2))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .help("Options: Cycle Scale")
    }

    // MARK: - PS Button
    private var psButtonView: some View {
        Button(action: { controller.toggleLatchMode() }) {
            ZStack {
                Circle()
                    .fill(controller.telemetry.home ? Color.blue : theme.buttonBg)
                    .frame(width: 34, height: 34)
                    .overlay(Circle().stroke(controller.telemetry.home ? Color.blue : theme.buttonBorder, lineWidth: 1.5))
                    .shadow(color: controller.telemetry.home ? .blue : .clear, radius: 6)

                Text("PS")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundColor(controller.telemetry.home ? .white : theme.textPrimary)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Mic Mute Button
    private var micMuteButtonView: some View {
        Button(action: { controller.triggerPanic() }) {
            VStack(spacing: 1) {
                ZStack {
                    Capsule()
                        .fill(controller.telemetry.micMuted ? Color.orange.opacity(0.4) : theme.buttonBg)
                        .frame(width: 30, height: 12)
                        .overlay(Capsule().stroke(controller.telemetry.micMuted ? Color.orange : theme.buttonBorder, lineWidth: 1))

                    Circle()
                        .fill(controller.telemetry.micMuted ? Color.orange : Color.orange.opacity(0.4))
                        .frame(width: 4, height: 4)
                        .shadow(color: controller.telemetry.micMuted ? .orange : .clear, radius: 4)
                }

                Text("MUTE")
                    .font(.system(size: 7, weight: .black, design: .monospaced))
                    .foregroundColor(controller.telemetry.micMuted ? .orange : theme.textTertiary)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Performance & Telemetry Deck
    private var performanceDeckView: some View {
        HStack(alignment: .top, spacing: 12) {
            // Gyroscope & Haptic Feedback Card
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "gyroscope")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.cyan)
                    Text("6-AXIS GYRO & HAPTICS")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(theme.textPrimary)
                    Spacer()
                    Text(String(format: "TILT: %3.0f°", controller.telemetry.pitchAngle))
                        .font(.system(size: 12, weight: .black, design: .monospaced))
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
                        .frame(width: max(6, CGFloat(controller.telemetry.pitchAngle / 75.0) * 180), height: 14)
                }
                .frame(maxWidth: .infinity)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(theme.wellBorder, lineWidth: 1))

                HStack {
                    Text("MOD WHEEL (CC #1):")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(theme.textSecondary)
                    Text("\(controller.telemetry.modWheel) / 127")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundColor(.cyan)

                    Spacer()

                    Text("VIBRATION:")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(theme.textSecondary)
                    Text(String(format: "%.0f%%", controller.telemetry.hapticIntensity * 100))
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundColor(controller.telemetry.hapticIntensity > 0.05 ? .orange : theme.textTertiary)
                    if controller.telemetry.hapticIntensity > 0.05 {
                        Image(systemName: "waveform.path")
                            .font(.system(size: 12, weight: .bold))
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
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.orange)
                    Text("ARPEGGIATOR & CHORDS")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(theme.textPrimary)
                    Spacer()
                    Text("BPM: \(Int(controller.bpm))")
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .foregroundColor(.orange)
                }

                // Live Active Chord & Notes
                HStack(spacing: 6) {
                    Text("ACTIVE:")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(theme.textSecondary)

                    Text(controller.telemetry.activeChordName)
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .foregroundColor(.green)

                    Spacer()

                    Text(controller.telemetry.activeChordNotes.map { controller.noteNameForPitch($0) }.joined(separator: " "))
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
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
                        .font(.system(size: 10, weight: .black, design: .monospaced))
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
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(.cyan)

            Spacer()

            Text("ROOT: \(controller.noteNameForPitch(controller.rootKey)) | OCT: \(controller.octaveShift / 12 > 0 ? "+" : "")\(controller.octaveShift / 12) | \(controller.scaleName.uppercased())")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(theme.textSecondary)

            Text("• COREMIDI ACTIVE")
                .font(.system(size: 9, weight: .black))
                .foregroundColor(.green)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(theme.consoleBg)
        .cornerRadius(8)
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
        if controller.heldFaceButtonIndex != nil { return "MORPH (HELD)" }
        if controller.isL1Held { return "SCALES (L1)" }
        if controller.isR1Held { return "RATE/BPM (R1)" }
        return "D-PAD (OCT/ROOT)"
    }

    private var faceHeaderTitle: String {
        if controller.heldFaceButtonIndex != nil { return "ALTER / EXTEND" }
        if controller.isL1Held { return "VOICING (L1)" }
        if controller.isR1Held { return "PATTERN (R1)" }
        return "FACE CHORDS"
    }

    private enum DpadPos { case up, down, left, right }

    private func dpadLabel(for pos: DpadPos) -> String {
        if controller.heldFaceButtonIndex != nil {
            switch pos {
            case .up: return "+8va"
            case .down: return "+Sub"
            case .left: return "Semi-"
            case .right: return "Semi+"
            }
        } else if controller.isL1Held {
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
        case .add9: suffix = isMinor ? "m9" : "9"
        }
        return "\(rootNote)\(suffix)"
    }

    private func dpadButton(label: String, active: Bool, offset: CGSize) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(active ? Color.cyan : theme.buttonBg)
                .frame(width: 28, height: 28)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(active ? Color.cyan : theme.buttonBorder, lineWidth: 1)
                )
                .shadow(color: active ? .cyan : .clear, radius: 6)

            Text(label)
                .font(.system(size: label.count > 2 ? 8.5 : 12, weight: .black))
                .foregroundColor(active ? .black : theme.textPrimary)
                .lineLimit(1)
        }
        .offset(offset)
        .fixedSize()
    }

    private func faceButton(symbol: String, actionText: String, active: Bool, color: Color, offset: CGSize) -> some View {
        ZStack {
            Circle()
                .fill(active ? color : theme.buttonBg)
                .frame(width: 32, height: 32)
                .overlay(
                    Circle().stroke(active ? color : theme.buttonBorder, lineWidth: 1.2)
                )
                .shadow(color: active ? color : .clear, radius: 8)

            VStack(spacing: 0) {
                Text(symbol)
                    .font(.system(size: 11, weight: .black))
                    .foregroundColor(active ? .white : color)
                    .lineLimit(1)
                Text(actionText)
                    .font(.system(size: actionText.count > 4 ? 7.5 : 9, weight: .black, design: .monospaced))
                    .foregroundColor(active ? .white : theme.textPrimary)
                    .lineLimit(1)
            }
        }
        .offset(offset)
        .fixedSize()
    }
}
