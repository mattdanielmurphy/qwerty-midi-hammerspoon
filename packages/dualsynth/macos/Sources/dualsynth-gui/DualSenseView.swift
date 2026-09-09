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

public struct UIScale {
    public let factor: CGFloat

    public init(_ factor: CGFloat = 1.0) {
        self.factor = factor
    }

    public func d(_ val: CGFloat) -> CGFloat {
        return round(val * factor)
    }

    public func f(_ val: CGFloat) -> CGFloat {
        return max(7.0, round(val * factor))
    }
}

struct StickRadarView: View {
    let title: String
    let x: Float
    let y: Float
    let isClicked: Bool
    let subtitle: String
    let theme: ThemeColors
    let s: UIScale

    var body: some View {
        VStack(spacing: s.d(4)) {
            Text(title)
                .font(.system(size: s.f(12), weight: .bold, design: .monospaced))
                .foregroundColor(theme.textPrimary)
                .lineLimit(1)

            ZStack {
                // Outer bezel
                Circle()
                    .fill(theme.wellBg)
                    .frame(width: s.d(96), height: s.d(96))
                    .overlay(
                        Circle()
                            .stroke(isClicked ? Color.cyan : theme.wellBorder, lineWidth: isClicked ? s.d(2.5) : s.d(1.2))
                    )

                // Concentric guide ring
                Circle()
                    .stroke(theme.crosshair.opacity(0.4), lineWidth: 1)
                    .frame(width: s.d(50), height: s.d(50))

                // Crosshairs
                Path { path in
                    path.move(to: CGPoint(x: s.d(48), y: s.d(8)))
                    path.addLine(to: CGPoint(x: s.d(48), y: s.d(88)))
                    path.move(to: CGPoint(x: s.d(8), y: s.d(48)))
                    path.addLine(to: CGPoint(x: s.d(88), y: s.d(48)))
                }
                .stroke(theme.crosshair, lineWidth: 1)

                // Stick puck
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [isClicked ? .cyan : .blue, theme.wellBorder]),
                            center: .center,
                            startRadius: s.d(2),
                            endRadius: s.d(16)
                        )
                    )
                    .frame(width: s.d(28), height: s.d(28))
                    .shadow(color: isClicked ? .cyan : .blue.opacity(0.5), radius: s.d(5))
                    .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 1))
                    .offset(x: CGFloat(x) * s.d(32), y: CGFloat(-y) * s.d(32))
            }
            .frame(width: s.d(96), height: s.d(96))

            HStack(spacing: s.d(6)) {
                Text(String(format: "X:%+.2f", x))
                Text(String(format: "Y:%+.2f", y))
            }
            .font(.system(size: s.f(10), weight: .bold, design: .monospaced))
            .foregroundColor(theme.textSecondary)
            .lineLimit(1)

            Text(subtitle)
                .font(.system(size: s.f(9), weight: .semibold))
                .foregroundColor(theme.textTertiary)
                .lineLimit(1)
        }
        .frame(width: s.d(128), height: s.d(172))
        .padding(s.d(6))
        .background(RoundedRectangle(cornerRadius: s.d(12)).fill(theme.cardBg))
        .overlay(RoundedRectangle(cornerRadius: s.d(12)).stroke(theme.cardBorder, lineWidth: 1))
        .fixedSize()
    }
}

struct TriggerGaugeView: View {
    let title: String
    let value: Float
    let subtitle: String
    let activeColor: Color
    let theme: ThemeColors
    let s: UIScale

    var body: some View {
        VStack(spacing: s.d(3)) {
            Text(title)
                .font(.system(size: s.f(11), weight: .bold, design: .monospaced))
                .foregroundColor(theme.textPrimary)
                .lineLimit(1)

            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: s.d(5))
                    .fill(theme.wellBg)
                    .frame(width: s.d(32), height: s.d(80))

                RoundedRectangle(cornerRadius: s.d(5))
                    .fill(
                        LinearGradient(
                            colors: [activeColor, activeColor.opacity(0.6)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: s.d(32), height: max(s.d(5), CGFloat(value) * s.d(80)))
                    .shadow(color: activeColor.opacity(value > 0.05 ? 0.6 : 0.0), radius: s.d(4))
            }
            .overlay(
                RoundedRectangle(cornerRadius: s.d(5))
                    .stroke(theme.wellBorder, lineWidth: 1)
            )

            Text(String(format: "%3.0f%%", value * 100))
                .font(.system(size: s.f(10), weight: .black, design: .monospaced))
                .foregroundColor(value > 0.05 ? activeColor : theme.textSecondary)
                .lineLimit(1)

            Text(subtitle)
                .font(.system(size: s.f(8), weight: .bold))
                .foregroundColor(theme.textTertiary)
                .lineLimit(1)
        }
        .frame(width: s.d(72))
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
        GeometryReader { geometry in
            let baseWidth: CGFloat = 760
            let baseHeight: CGFloat = 650
            let margin: CGFloat = 16
            let scaleX = (geometry.size.width - margin * 2) / baseWidth
            let scaleY = (geometry.size.height - margin * 2) / baseHeight
            let scaleFactor = max(0.65, min(scaleX, scaleY))
            let s = UIScale(scaleFactor)

            ZStack {
                theme.bgCanvas
                    .ignoresSafeArea()

                VStack(spacing: s.d(8)) {
                    headerBar(s: s)
                    controllerChassisView(s: s)
                    performanceDeckView(s: s)
                    keyboardView(s: s)
                    statusConsoleView(s: s)
                }
                .frame(width: s.d(baseWidth))
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .background(theme.bgCanvas)
    }

    // MARK: - Header Bar
    private func headerBar(s: UIScale) -> some View {
        HStack(spacing: s.d(10)) {
            // Connection status
            HStack(spacing: s.d(6)) {
                Circle()
                    .fill(controller.isConnected ? Color.green : Color.red)
                    .frame(width: s.d(9), height: s.d(9))
                    .shadow(color: controller.isConnected ? .green : .red, radius: s.d(4))

                Text(controller.controllerName)
                    .font(.system(size: s.f(13), weight: .bold))
                    .foregroundColor(theme.textPrimary)
                    .lineLimit(1)
            }
            .fixedSize()

            Spacer()

            // Active Layer Badge
            HStack(spacing: s.d(5)) {
                Circle()
                    .fill(layerColor)
                    .frame(width: s.d(7), height: s.d(7))
                Text(controller.currentLayer.rawValue.uppercased())
                    .font(.system(size: s.f(11), weight: .black, design: .monospaced))
                    .foregroundColor(layerColor)
                    .lineLimit(1)
            }
            .padding(.horizontal, s.d(12))
            .padding(.vertical, s.d(5))
            .background(layerColor.opacity(0.18))
            .overlay(Capsule().stroke(layerColor, lineWidth: 1.2))
            .clipShape(Capsule())
            .fixedSize()

            // Musical Mode Badges (Fixed horizontal size so text NEVER wraps)
            HStack(spacing: s.d(6)) {
                Button(action: { controller.toggleChordMode() }) {
                    Text("CHORDS: \(controller.chordMode ? "ON" : "OFF")")
                        .font(.system(size: s.f(10), weight: .bold, design: .monospaced))
                        .lineLimit(1)
                        .padding(.horizontal, s.d(8))
                        .padding(.vertical, s.d(4))
                        .background(controller.chordMode ? Color.green.opacity(0.2) : theme.buttonBg)
                        .foregroundColor(controller.chordMode ? .green : theme.textSecondary)
                        .cornerRadius(s.d(6))
                        .overlay(RoundedRectangle(cornerRadius: s.d(6)).stroke(controller.chordMode ? Color.green : theme.buttonBorder, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .fixedSize()

                Button(action: { controller.toggleLatchMode() }) {
                    Text("LATCH: \(controller.latchMode ? "ON 🔒" : "OFF")")
                        .font(.system(size: s.f(10), weight: .bold, design: .monospaced))
                        .lineLimit(1)
                        .padding(.horizontal, s.d(8))
                        .padding(.vertical, s.d(4))
                        .background(controller.latchMode ? Color.cyan.opacity(0.2) : theme.buttonBg)
                        .foregroundColor(controller.latchMode ? .cyan : theme.textSecondary)
                        .cornerRadius(s.d(6))
                        .overlay(RoundedRectangle(cornerRadius: s.d(6)).stroke(controller.latchMode ? Color.cyan : theme.buttonBorder, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .fixedSize()

                Button(action: { controller.toggleArpeggiator() }) {
                    Text("ARP: \(controller.isArpActive ? "ON ⚡" : "OFF")")
                        .font(.system(size: s.f(10), weight: .bold, design: .monospaced))
                        .lineLimit(1)
                        .padding(.horizontal, s.d(8))
                        .padding(.vertical, s.d(4))
                        .background(controller.isArpActive ? Color.orange.opacity(0.2) : theme.buttonBg)
                        .foregroundColor(controller.isArpActive ? .orange : theme.textSecondary)
                        .cornerRadius(s.d(6))
                        .overlay(RoundedRectangle(cornerRadius: s.d(6)).stroke(controller.isArpActive ? Color.orange : theme.buttonBorder, lineWidth: 1))
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
                HStack(spacing: s.d(5)) {
                    Image(systemName: isDarkMode ? "moon.fill" : "sun.max.fill")
                        .foregroundColor(isDarkMode ? .yellow : .orange)
                    Text(themeSelection.rawValue)
                        .font(.system(size: s.f(11), weight: .bold))
                        .foregroundColor(theme.textPrimary)
                }
                .padding(.horizontal, s.d(8))
                .padding(.vertical, s.d(5))
                .background(theme.buttonBg)
                .overlay(RoundedRectangle(cornerRadius: s.d(6)).stroke(theme.buttonBorder, lineWidth: 1))
                .cornerRadius(s.d(6))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .padding(.horizontal, s.d(12))
        .padding(.vertical, s.d(6))
        .background(theme.cardBg)
        .cornerRadius(s.d(10))
        .overlay(RoundedRectangle(cornerRadius: s.d(10)).stroke(theme.cardBorder, lineWidth: 1))
    }

    // MARK: - DualSense Controller Chassis View (Rigid Static Dimensions)
    private func controllerChassisView(s: UIScale) -> some View {
        VStack(spacing: s.d(10)) {
            // Upper Triggers & Shoulders
            HStack(spacing: s.d(16)) {
                // L2 Trigger & L1 Bumper
                HStack(spacing: s.d(10)) {
                    TriggerGaugeView(
                        title: "L2 TRIGGER",
                        value: controller.telemetry.leftTrigger,
                        subtitle: "CC74 Cutoff",
                        activeColor: .purple,
                        theme: theme,
                        s: s
                    )

                    VStack(spacing: s.d(4)) {
                        Text("L1 BUMPER")
                            .font(.system(size: s.f(10), weight: .bold, design: .monospaced))
                            .foregroundColor(theme.textPrimary)
                            .lineLimit(1)

                        RoundedRectangle(cornerRadius: s.d(8))
                            .fill(controller.telemetry.l1 ? Color.blue : theme.buttonBg)
                            .frame(width: s.d(76), height: s.d(34))
                            .overlay(
                                Text("HARMONY")
                                    .font(.system(size: s.f(9), weight: .black))
                                    .foregroundColor(controller.telemetry.l1 ? .white : theme.textSecondary)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: s.d(8))
                                    .stroke(controller.telemetry.l1 ? Color.blue : theme.buttonBorder, lineWidth: 1.5)
                            )
                            .shadow(color: controller.telemetry.l1 ? .blue : .clear, radius: s.d(6))
                    }
                    .frame(width: s.d(76))
                    .fixedSize()
                }

                Spacer()

                // Center Touchpad with Glowing Lightbar Contour & Create/Options Buttons
                HStack(spacing: s.d(12)) {
                    createButtonView(s: s)
                    touchpadView(s: s)
                    optionsButtonView(s: s)
                }
                .fixedSize()

                Spacer()

                // R1 Bumper & R2 Trigger
                HStack(spacing: s.d(10)) {
                    VStack(spacing: s.d(4)) {
                        Text("R1 BUMPER")
                            .font(.system(size: s.f(10), weight: .bold, design: .monospaced))
                            .foregroundColor(theme.textPrimary)
                            .lineLimit(1)

                        RoundedRectangle(cornerRadius: s.d(8))
                            .fill(controller.telemetry.r1 ? Color.orange : theme.buttonBg)
                            .frame(width: s.d(76), height: s.d(34))
                            .overlay(
                                Text("ARP / RHYTHM")
                                    .font(.system(size: s.f(8), weight: .black))
                                    .foregroundColor(controller.telemetry.r1 ? .white : theme.textSecondary)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: s.d(8))
                                    .stroke(controller.telemetry.r1 ? Color.orange : theme.buttonBorder, lineWidth: 1.5)
                            )
                            .shadow(color: controller.telemetry.r1 ? .orange : .clear, radius: s.d(6))
                    }
                    .frame(width: s.d(76))
                    .fixedSize()

                    TriggerGaugeView(
                        title: "R2 TRIGGER",
                        value: controller.telemetry.rightTrigger,
                        subtitle: "Expr / Vel",
                        activeColor: .green,
                        theme: theme,
                        s: s
                    )
                }
            }
            .padding(.horizontal, s.d(14))

            // Dynamic RGB Lightbar Arc
            RoundedRectangle(cornerRadius: s.d(4))
                .fill(
                    LinearGradient(
                        colors: [layerColor.opacity(0.1), layerColor, layerColor.opacity(0.1)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: s.d(5))
                .shadow(color: layerColor, radius: s.d(8))
                .padding(.horizontal, s.d(32))

            // Main Face Area: Static Width Columns (Never shrinks or reflows)
            HStack(alignment: .center, spacing: s.d(14)) {
                // 1. D-Pad Column (Static Width 128)
                VStack(spacing: s.d(6)) {
                    Text(dpadHeaderTitle)
                        .font(.system(size: s.f(11), weight: .black, design: .monospaced))
                        .foregroundColor(controller.isL1Held ? .blue : (controller.isR1Held ? .orange : theme.textSecondary))
                        .lineLimit(1)

                    ZStack {
                        Circle()
                            .fill(theme.chassisInner)
                            .frame(width: s.d(108), height: s.d(108))
                            .overlay(Circle().stroke(theme.wellBorder, lineWidth: 1.2))

                        dpadButton(label: dpadLabel(for: .up), active: controller.telemetry.dpadUp, offset: CGSize(width: 0, height: -s.d(32)), s: s)
                        dpadButton(label: dpadLabel(for: .down), active: controller.telemetry.dpadDown, offset: CGSize(width: 0, height: s.d(32)), s: s)
                        dpadButton(label: dpadLabel(for: .left), active: controller.telemetry.dpadLeft, offset: CGSize(width: -s.d(32), height: 0), s: s)
                        dpadButton(label: dpadLabel(for: .right), active: controller.telemetry.dpadRight, offset: CGSize(width: s.d(32), height: 0), s: s)
                    }
                    .frame(width: s.d(108), height: s.d(108))
                }
                .frame(width: s.d(128), height: s.d(172))
                .fixedSize()

                // 2. Left Stick (Static Width 128)
                StickRadarView(
                    title: "LEFT STICK",
                    x: controller.telemetry.leftStickX,
                    y: controller.telemetry.leftStickY,
                    isClicked: controller.telemetry.l3,
                    subtitle: controller.isL1Held ? "Pitch Bend" : "X:Bend | Y:Mod/Cut",
                    theme: theme,
                    s: s
                )

                // 3. Center Column: PS Button + Mic Button (Static Width 50)
                VStack(spacing: s.d(10)) {
                    psButtonView(s: s)
                    micMuteButtonView(s: s)
                }
                .frame(width: s.d(50), height: s.d(172))
                .fixedSize()

                // 4. Right Stick (Static Width 128, NEVER Collapses)
                StickRadarView(
                    title: "RIGHT STICK",
                    x: controller.telemetry.rightStickX,
                    y: controller.telemetry.rightStickY,
                    isClicked: controller.telemetry.r3,
                    subtitle: controller.isL1Held ? "Width / Chorus" : "X:Pan | Y:Dyn/Res",
                    theme: theme,
                    s: s
                )

                // 5. Face Buttons Diamond (Static Width 128)
                VStack(spacing: s.d(6)) {
                    Text(faceHeaderTitle)
                        .font(.system(size: s.f(11), weight: .black, design: .monospaced))
                        .foregroundColor(controller.isL1Held ? .blue : (controller.isR1Held ? .orange : theme.textSecondary))
                        .lineLimit(1)

                    ZStack {
                        Circle()
                            .fill(theme.chassisInner)
                            .frame(width: s.d(108), height: s.d(108))
                            .overlay(Circle().stroke(theme.wellBorder, lineWidth: 1.2))

                        faceButton(symbol: "△", actionText: faceActionText(index: 3), active: controller.telemetry.triangle, isHeld: controller.heldFaceButtonIndex == 3, color: .green, offset: CGSize(width: 0, height: -s.d(32)), s: s)
                        faceButton(symbol: "○", actionText: faceActionText(index: 2), active: controller.telemetry.circle, isHeld: controller.heldFaceButtonIndex == 2, color: .red, offset: CGSize(width: s.d(32), height: 0), s: s)
                        faceButton(symbol: "✕", actionText: faceActionText(index: 0), active: controller.telemetry.cross, isHeld: controller.heldFaceButtonIndex == 0, color: .blue, offset: CGSize(width: 0, height: s.d(32)), s: s)
                        faceButton(symbol: "□", actionText: faceActionText(index: 1), active: controller.telemetry.square, isHeld: controller.heldFaceButtonIndex == 1, color: .pink, offset: CGSize(width: -s.d(32), height: 0), s: s)
                    }
                    .frame(width: s.d(108), height: s.d(108))
                }
                .frame(width: s.d(128), height: s.d(172))
                .fixedSize()
            }
            .padding(.horizontal, s.d(10))
            .padding(.bottom, s.d(6))
        }
        .frame(width: s.d(760))
        .padding(s.d(14))
        .background(
            RoundedRectangle(cornerRadius: s.d(20))
                .fill(theme.chassisOuter)
                .shadow(color: isDarkMode ? Color.black.opacity(0.4) : Color.black.opacity(0.06), radius: s.d(10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: s.d(20))
                .stroke(theme.chassisBorder, lineWidth: 1.5)
        )
        .fixedSize()
    }

    // MARK: - Center Touchpad View
    private func touchpadView(s: UIScale) -> some View {
        Button(action: { controller.triggerPanic() }) {
            ZStack {
                RoundedRectangle(cornerRadius: s.d(10))
                    .fill(theme.chassisInner)
                    .frame(width: s.d(130), height: s.d(56))

                VStack(spacing: s.d(2)) {
                    Text("DUALSENSE")
                        .font(.system(size: s.f(9), weight: .bold, design: .monospaced))
                        .foregroundColor(theme.textSecondary)
                    Text(controller.telemetry.touchpad ? "PANIC" : "CLICK = PANIC")
                        .font(.system(size: s.f(8), weight: .black, design: .monospaced))
                        .foregroundColor(controller.telemetry.touchpad ? .red : .green)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: s.d(10))
                    .stroke(controller.telemetry.touchpad ? Color.red : layerColor.opacity(0.8), lineWidth: 1.5)
            )
            .shadow(color: layerColor.opacity(0.3), radius: s.d(6))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Create Button (Shows ||| Glyph & Live Chord Type)
    private func createButtonView(s: UIScale) -> some View {
        Button(action: { controller.cycleChordType() }) {
            VStack(spacing: s.d(2)) {
                HStack(spacing: s.d(3)) {
                    ForEach(0..<3) { _ in
                        Capsule()
                            .fill(controller.telemetry.create ? Color.cyan : theme.textSecondary)
                            .frame(width: s.d(2), height: s.d(8))
                    }
                    Text("CHORD")
                        .font(.system(size: s.f(8), weight: .black, design: .monospaced))
                        .foregroundColor(controller.telemetry.create ? .cyan : theme.textSecondary)
                }
                Text(controller.chordType.rawValue.uppercased())
                    .font(.system(size: s.f(9), weight: .black, design: .monospaced))
                    .foregroundColor(controller.telemetry.create ? .white : .cyan)
                    .lineLimit(1)
            }
            .frame(width: s.d(64), height: s.d(32))
            .background(controller.telemetry.create ? Color.cyan.opacity(0.3) : theme.buttonBg)
            .overlay(RoundedRectangle(cornerRadius: s.d(6)).stroke(controller.telemetry.create ? Color.cyan : theme.buttonBorder, lineWidth: 1.2))
            .cornerRadius(s.d(6))
        }
        .buttonStyle(.plain)
        .help("Create: Cycle Chord Types (Triad, 7th, 9th, Sus4, Power)")
        .fixedSize()
    }

    // MARK: - Options Button (Shows ☰ Glyph & Live Scale Name)
    private func optionsButtonView(s: UIScale) -> some View {
        Button(action: { controller.cycleScale() }) {
            VStack(spacing: s.d(2)) {
                HStack(spacing: s.d(3)) {
                    VStack(spacing: s.d(1.5)) {
                        ForEach(0..<3) { _ in
                            Capsule()
                                .fill(controller.telemetry.options ? Color.orange : theme.textSecondary)
                                .frame(width: s.d(8), height: max(1, s.d(1.5)))
                        }
                    }
                    Text("SCALE")
                        .font(.system(size: s.f(8), weight: .black, design: .monospaced))
                        .foregroundColor(controller.telemetry.options ? .orange : theme.textSecondary)
                }
                Text(controller.scaleName.uppercased())
                    .font(.system(size: s.f(9), weight: .black, design: .monospaced))
                    .foregroundColor(controller.telemetry.options ? .white : .orange)
                    .lineLimit(1)
            }
            .frame(width: s.d(64), height: s.d(32))
            .background(controller.telemetry.options ? Color.orange.opacity(0.3) : theme.buttonBg)
            .overlay(RoundedRectangle(cornerRadius: s.d(6)).stroke(controller.telemetry.options ? Color.orange : theme.buttonBorder, lineWidth: 1.2))
            .cornerRadius(s.d(6))
        }
        .buttonStyle(.plain)
        .help("Options: Cycle Musical Scale (Major, Minor, Dorian, etc.)")
        .fixedSize()
    }

    // MARK: - PS Button (Shows PS & Live Latch State)
    private func psButtonView(s: UIScale) -> some View {
        Button(action: { controller.toggleLatchMode() }) {
            VStack(spacing: s.d(2)) {
                ZStack {
                    Circle()
                        .fill(controller.telemetry.home ? Color.blue : theme.buttonBg)
                        .frame(width: s.d(32), height: s.d(32))
                        .overlay(Circle().stroke(controller.telemetry.home ? Color.blue : (controller.latchMode ? Color.cyan : theme.buttonBorder), lineWidth: 1.5))
                        .shadow(color: controller.telemetry.home ? .blue : (controller.latchMode ? Color.cyan.opacity(0.4) : .clear), radius: s.d(5))

                    Text("PS")
                        .font(.system(size: s.f(11), weight: .black, design: .rounded))
                        .foregroundColor(controller.telemetry.home ? .white : (controller.latchMode ? .cyan : theme.textPrimary))
                }

                Text(controller.latchMode ? "LATCH 🔒" : "MOMENT")
                    .font(.system(size: s.f(7), weight: .bold, design: .monospaced))
                    .foregroundColor(controller.latchMode ? .cyan : theme.textTertiary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
        .help("PS Button: Toggle Latch Mode")
        .fixedSize()
    }

    // MARK: - Mic Mute Button (Shows Panic & Mute State)
    private func micMuteButtonView(s: UIScale) -> some View {
        Button(action: { controller.triggerPanic() }) {
            VStack(spacing: s.d(2)) {
                ZStack {
                    Capsule()
                        .fill(controller.telemetry.micMuted ? Color.red.opacity(0.4) : theme.buttonBg)
                        .frame(width: s.d(32), height: s.d(14))
                        .overlay(Capsule().stroke(controller.telemetry.micMuted ? Color.red : theme.buttonBorder, lineWidth: 1))

                    Circle()
                        .fill(controller.telemetry.micMuted ? Color.red : Color.orange.opacity(0.5))
                        .frame(width: s.d(5), height: s.d(5))
                        .shadow(color: controller.telemetry.micMuted ? .red : .clear, radius: s.d(4))
                }

                Text("PANIC")
                    .font(.system(size: s.f(7), weight: .black, design: .monospaced))
                    .foregroundColor(controller.telemetry.micMuted ? .red : theme.textTertiary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
        .help("Mute Button: MIDI Panic (All Notes Off)")
        .fixedSize()
    }

    // MARK: - Performance & Telemetry Deck
    private func performanceDeckView(s: UIScale) -> some View {
        HStack(alignment: .top, spacing: s.d(12)) {
            // Gyroscope & Haptic Feedback Card
            VStack(alignment: .leading, spacing: s.d(8)) {
                HStack {
                    Image(systemName: "gyroscope")
                        .font(.system(size: s.f(13), weight: .bold))
                        .foregroundColor(.cyan)
                    Text("6-AXIS GYRO & HAPTICS")
                        .font(.system(size: s.f(11), weight: .bold, design: .monospaced))
                        .foregroundColor(theme.textPrimary)
                    Spacer()
                    Text(String(format: "TILT: %3.0f°", controller.telemetry.pitchAngle))
                        .font(.system(size: s.f(12), weight: .black, design: .monospaced))
                        .foregroundColor(.cyan)
                }

                // Tilt Angle Horizon Meter
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: s.d(6))
                        .fill(theme.wellBg)
                        .frame(height: s.d(14))

                    RoundedRectangle(cornerRadius: s.d(6))
                        .fill(
                            LinearGradient(
                                colors: [.cyan, .blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(s.d(6), CGFloat(controller.telemetry.pitchAngle / 75.0) * s.d(180)), height: s.d(14))
                }
                .frame(maxWidth: .infinity)
                .overlay(RoundedRectangle(cornerRadius: s.d(6)).stroke(theme.wellBorder, lineWidth: 1))

                HStack {
                    Text("MOD WHEEL (CC #1):")
                        .font(.system(size: s.f(10), weight: .bold, design: .monospaced))
                        .foregroundColor(theme.textSecondary)
                    Text("\(controller.telemetry.modWheel) / 127")
                        .font(.system(size: s.f(11), weight: .black, design: .monospaced))
                        .foregroundColor(.cyan)

                    Spacer()

                    Text("HAPTIC PULSE:")
                        .font(.system(size: s.f(10), weight: .bold, design: .monospaced))
                        .foregroundColor(theme.textSecondary)
                    let stage = Int(round(controller.telemetry.hapticIntensity * 5.0))
                    Text(stage == 0 ? "OFF" : "STAGE \(stage)/5")
                        .font(.system(size: s.f(11), weight: .black, design: .monospaced))
                        .foregroundColor(stage > 0 ? .orange : theme.textTertiary)
                    if stage > 0 {
                        Image(systemName: "waveform.path")
                            .font(.system(size: s.f(12), weight: .bold))
                            .foregroundColor(.orange)
                    }
                }
            }
            .padding(s.d(12))
            .background(theme.cardBg)
            .cornerRadius(s.d(12))
            .overlay(RoundedRectangle(cornerRadius: s.d(12)).stroke(theme.cardBorder, lineWidth: 1))

            // Arpeggiator & Musical Chord Card
            VStack(alignment: .leading, spacing: s.d(8)) {
                HStack {
                    Image(systemName: "metronome.fill")
                        .font(.system(size: s.f(13), weight: .bold))
                        .foregroundColor(.orange)
                    Text("ARPEGGIATOR & CHORDS")
                        .font(.system(size: s.f(11), weight: .bold, design: .monospaced))
                        .foregroundColor(theme.textPrimary)
                    Spacer()
                    Text("BPM: \(Int(controller.bpm))")
                        .font(.system(size: s.f(12), weight: .black, design: .monospaced))
                        .foregroundColor(.orange)
                }

                // Live Active Chord & Notes
                HStack(spacing: s.d(6)) {
                    Text("ACTIVE:")
                        .font(.system(size: s.f(10), weight: .bold, design: .monospaced))
                        .foregroundColor(theme.textSecondary)

                    Text(controller.telemetry.activeChordName)
                        .font(.system(size: s.f(12), weight: .black, design: .monospaced))
                        .foregroundColor(.green)

                    Spacer()

                    Text(controller.telemetry.activeChordNotes.map { controller.noteNameForPitch($0) }.joined(separator: " "))
                        .font(.system(size: s.f(11), weight: .bold, design: .monospaced))
                        .foregroundColor(theme.textPrimary)
                }

                // 8-Step LED Sequencer indicator
                HStack(spacing: s.d(5)) {
                    ForEach(0..<8) { step in
                        Circle()
                            .fill(controller.isArpActive && (controller.telemetry.currentArpStep % 8 == step) ? Color.orange : theme.wellBorder)
                            .frame(width: s.d(8), height: s.d(8))
                            .shadow(color: controller.isArpActive && (controller.telemetry.currentArpStep % 8 == step) ? .orange : .clear, radius: s.d(4))
                    }
                    Spacer()
                    Text("RATE: \(controller.arpRate.rawValue)")
                        .font(.system(size: s.f(10), weight: .black, design: .monospaced))
                        .foregroundColor(theme.textSecondary)
                }
            }
            .padding(s.d(12))
            .background(theme.cardBg)
            .cornerRadius(s.d(12))
            .overlay(RoundedRectangle(cornerRadius: s.d(12)).stroke(theme.cardBorder, lineWidth: 1))
        }
    }

    // MARK: - Live Piano Keyboard Monitor
    private func keyboardView(s: UIScale) -> some View {
        let center = Int(controller.rootKey) + controller.octaveShift
        let octaveNum = center / 12
        let startOctave = max(2, min(6, octaveNum - 1))
        let startPitch = UInt8(startOctave * 12)

        let totalWhiteKeys = 22
        let cardPadding = s.d(10)
        let totalWidth = s.d(760) - (cardPadding * 2)
        let wkw = totalWidth / CGFloat(totalWhiteKeys)
        let wkh = s.d(52)
        let bkw = wkw * 0.62
        let bkh = s.d(32)

        return VStack(spacing: s.d(6)) {
            // Header with Title & Legend
            HStack {
                HStack(spacing: s.d(5)) {
                    Image(systemName: "pianokeys")
                        .font(.system(size: s.f(11), weight: .bold))
                        .foregroundColor(.cyan)
                    Text("LIVE KEYBOARD MONITOR")
                        .font(.system(size: s.f(10), weight: .bold, design: .monospaced))
                        .foregroundColor(theme.textPrimary)
                }

                Spacer()

                HStack(spacing: s.d(6)) {
                    keyboardLegendBadge(label: "ROOT", color: .blue, s: s)
                    keyboardLegendBadge(label: "CHORD", color: .cyan, s: s)
                    keyboardLegendBadge(label: "ARP ⚡", color: .orange, s: s)
                }
            }

            // Keyboard Surface
            ZStack(alignment: .topLeading) {
                // White Keys
                HStack(spacing: 0) {
                    ForEach(0..<totalWhiteKeys, id: \.self) { i in
                        let oct = i / 7
                        let noteIdx = i % 7
                        let whiteOffsets: [UInt8] = [0, 2, 4, 5, 7, 9, 11]
                        let pitch = startPitch + UInt8(oct * 12) + whiteOffsets[noteIdx]
                        let isC = (noteIdx == 0)
                        let octaveLabel = "C\(startOctave - 1 + oct)"
                        whiteKeyView(pitch: pitch, isC: isC, octaveLabel: octaveLabel, width: wkw, height: wkh, s: s)
                    }
                }

                // Black Keys
                ForEach(0..<3, id: \.self) { oct in
                    let blackOffsets: [(offset: UInt8, whiteBoundary: Int)] = [
                        (1, 1),
                        (3, 2),
                        (6, 4),
                        (8, 5),
                        (10, 6)
                    ]
                    ForEach(0..<blackOffsets.count, id: \.self) { bIdx in
                        let item = blackOffsets[bIdx]
                        let pitch = startPitch + UInt8(oct * 12) + item.offset
                        let whiteIdx = oct * 7 + item.whiteBoundary
                        let xPos = CGFloat(whiteIdx) * wkw - (bkw / 2)
                        blackKeyView(pitch: pitch, width: bkw, height: bkh, s: s)
                            .offset(x: xPos, y: 0)
                    }
                }
            }
            .frame(width: totalWidth, height: wkh)
        }
        .padding(cardPadding)
        .background(theme.cardBg)
        .cornerRadius(s.d(12))
        .overlay(RoundedRectangle(cornerRadius: s.d(12)).stroke(theme.cardBorder, lineWidth: 1))
    }

    private func whiteKeyView(pitch: UInt8, isC: Bool, octaveLabel: String, width: CGFloat, height: CGFloat, s: UIScale) -> some View {
        let isArp = (controller.telemetry.activeArpPitch == pitch)
        let isRoot = controller.telemetry.playedRootPitches.contains(pitch)
        let isChord = controller.telemetry.activeChordNotes.contains(pitch)

        return ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: s.d(3.5))
                .fill(
                    isArp ? Color.orange :
                    (isRoot ? Color.blue :
                    (isChord ? Color.cyan.opacity(0.35) :
                    (theme.isDark ? Color(white: 0.17) : Color.white)))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: s.d(3.5))
                        .stroke(
                            isArp ? Color.orange :
                            (isRoot ? Color.cyan :
                            (isChord ? Color.cyan : theme.wellBorder)),
                            lineWidth: (isArp || isRoot || isChord) ? 1.5 : 1
                        )
                )
                .shadow(
                    color: isArp ? .orange : (isRoot ? .blue.opacity(0.6) : .clear),
                    radius: isArp ? s.d(6) : (isRoot ? s.d(4) : 0)
                )

            VStack(spacing: s.d(1)) {
                if isArp {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: s.f(7), weight: .black))
                        .foregroundColor(.white)
                    Text(controller.noteNameForPitch(pitch))
                        .font(.system(size: s.f(7), weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                } else if isRoot {
                    Text("ROOT")
                        .font(.system(size: s.f(6), weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(.horizontal, s.d(2))
                        .background(Color.blue.opacity(0.9))
                        .cornerRadius(s.d(2))
                    Text(controller.noteNameForPitch(pitch))
                        .font(.system(size: s.f(7.5), weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                } else if isChord {
                    Circle()
                        .fill(Color.cyan)
                        .frame(width: s.d(4), height: s.d(4))
                    Text(controller.noteNameForPitch(pitch))
                        .font(.system(size: s.f(7), weight: .bold, design: .monospaced))
                        .foregroundColor(.cyan)
                } else if isC {
                    Text(octaveLabel)
                        .font(.system(size: s.f(7.5), weight: .bold, design: .monospaced))
                        .foregroundColor(theme.textTertiary)
                }
            }
            .padding(.bottom, s.d(3))
        }
        .frame(width: width, height: height)
    }

    private func blackKeyView(pitch: UInt8, width: CGFloat, height: CGFloat, s: UIScale) -> some View {
        let isArp = (controller.telemetry.activeArpPitch == pitch)
        let isRoot = controller.telemetry.playedRootPitches.contains(pitch)
        let isChord = controller.telemetry.activeChordNotes.contains(pitch)

        return ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: s.d(2.5))
                .fill(
                    isArp ? Color.orange :
                    (isRoot ? Color.blue :
                    (isChord ? Color.cyan.opacity(0.85) :
                    (theme.isDark ? Color(white: 0.07) : Color(white: 0.22))))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: s.d(2.5))
                        .stroke(
                            isArp ? Color.orange :
                            (isRoot ? Color.white :
                            (isChord ? Color.white.opacity(0.7) :
                            (theme.isDark ? Color(white: 0.16) : Color(white: 0.35)))),
                            lineWidth: (isArp || isRoot || isChord) ? 1.5 : 1
                        )
                )
                .shadow(
                    color: isArp ? .orange : (isRoot ? .blue.opacity(0.7) : .clear),
                    radius: isArp ? s.d(5) : (isRoot ? s.d(4) : 0)
                )

            VStack(spacing: s.d(1)) {
                if isArp {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: s.f(6), weight: .black))
                        .foregroundColor(.white)
                } else if isRoot {
                    Text("★")
                        .font(.system(size: s.f(7), weight: .black))
                        .foregroundColor(.white)
                } else if isChord {
                    Circle()
                        .fill(Color.white)
                        .frame(width: s.d(3.5), height: s.d(3.5))
                }
            }
            .padding(.bottom, s.d(3))
        }
        .frame(width: width, height: height)
    }

    private func keyboardLegendBadge(label: String, color: Color, s: UIScale) -> some View {
        HStack(spacing: s.d(4)) {
            Circle()
                .fill(color)
                .frame(width: s.d(6), height: s.d(6))
                .shadow(color: color.opacity(0.5), radius: s.d(2))
            Text(label)
                .font(.system(size: s.f(8), weight: .black, design: .monospaced))
                .foregroundColor(color)
        }
        .padding(.horizontal, s.d(6))
        .padding(.vertical, s.d(2.5))
        .background(color.opacity(0.15))
        .cornerRadius(s.d(4))
        .overlay(RoundedRectangle(cornerRadius: s.d(4)).stroke(color.opacity(0.3), lineWidth: 1))
    }

    // MARK: - Status Console View
    private func statusConsoleView(s: UIScale) -> some View {
        HStack {
            Text("EVENT:")
                .font(.system(size: s.f(10), weight: .bold, design: .monospaced))
                .foregroundColor(theme.textSecondary)

            Text(controller.lastEventDescription)
                .font(.system(size: s.f(12), weight: .bold, design: .monospaced))
                .foregroundColor(.cyan)

            Spacer()

            Text("ROOT: \(controller.noteNameForPitch(controller.rootKey)) | OCT: \(controller.octaveShift / 12 > 0 ? "+" : "")\(controller.octaveShift / 12) | \(controller.scaleName.uppercased())")
                .font(.system(size: s.f(10), weight: .bold, design: .monospaced))
                .foregroundColor(theme.textSecondary)

            Text("• COREMIDI ACTIVE")
                .font(.system(size: s.f(9), weight: .black))
                .foregroundColor(.green)
        }
        .padding(.horizontal, s.d(14))
        .padding(.vertical, s.d(8))
        .background(theme.consoleBg)
        .cornerRadius(s.d(8))
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
        if controller.heldFaceButtonIndex != nil { return "HELD MORPH" }
        if controller.isL1Held { return "OCT / TONIC (L1)" }
        if controller.isR1Held { return "TEMPO / RATE (R1)" }
        return "DEGREE: \(controller.degreeName(controller.scaleDegreeShift))"
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
            case .up: return "+1 St"
            case .down: return "-1 St"
            case .left: return "+Sub"
            case .right: return "+8va"
            }
        } else if controller.isL1Held {
            switch pos {
            case .up: return "Oct+"
            case .down: return "Oct-"
            case .left: return "Tonic"
            case .right: return "Semi+"
            }
        } else if controller.isR1Held {
            switch pos {
            case .up: return "+5 BPM"
            case .down: return "-5 BPM"
            case .left: return "Rate-"
            case .right: return "Rate+"
            }
        } else {
            switch pos {
            case .up: return "+1 St"
            case .down: return "-1 St"
            case .left: return "-3 St"
            case .right: return "+3 St"
            }
        }
    }

    private func faceActionText(index: Int) -> String {
        if controller.heldFaceButtonIndex != nil {
            if controller.heldFaceButtonIndex == index {
                return "HELD 🔒"
            }
            switch index {
            case 1: // Square
                return controller.heldChordAdd7th ? "+7th ON" : "+7th"
            case 2: // Circle
                return controller.heldChordAdd9th ? "+9th ON" : "+9th"
            case 3: // Triangle
                return "Inv+"
            default: // Cross (0)
                return controller.heldChordAddSubBass ? "+Bass ON" : "+Bass"
            }
        } else if controller.isL1Held {
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
            let degree = controller.scaleDegreeForButton(index: index)
            let numeral = controller.romanNumeral(forDegree: degree)
            let chord = controller.chordNameForDegree(degree)
            return "\(numeral):\(chord)"
        }
    }

    private func dpadButton(label: String, active: Bool, offset: CGSize, s: UIScale) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: s.d(6))
                .fill(active ? Color.cyan : theme.buttonBg)
                .frame(width: s.d(32), height: s.d(26))
                .overlay(
                    RoundedRectangle(cornerRadius: s.d(6))
                        .stroke(active ? Color.cyan : theme.buttonBorder, lineWidth: 1)
                )
                .shadow(color: active ? .cyan : .clear, radius: s.d(6))

            let rawFontSize: CGFloat = label.count > 4 ? 7 : (label.count > 2 ? 8 : 11)
            Text(label)
                .font(.system(size: s.f(rawFontSize), weight: .black, design: .monospaced))
                .foregroundColor(active ? .black : theme.textPrimary)
                .lineLimit(1)
        }
        .offset(offset)
        .fixedSize()
    }

    private func faceButton(symbol: String, actionText: String, active: Bool, isHeld: Bool, color: Color, offset: CGSize, s: UIScale) -> some View {
        ZStack {
            Circle()
                .fill(active ? color : (isHeld ? color.opacity(0.35) : theme.buttonBg))
                .frame(width: s.d(36), height: s.d(36))
                .overlay(
                    Circle().stroke(active || isHeld ? color : theme.buttonBorder, lineWidth: active || isHeld ? 2 : 1.2)
                )
                .shadow(color: active || isHeld ? color.opacity(0.6) : .clear, radius: s.d(8))

            VStack(spacing: 0) {
                Text(symbol)
                    .font(.system(size: s.f(10), weight: .black))
                    .foregroundColor(active ? .white : color)
                    .lineLimit(1)
                let rawFontSize: CGFloat = actionText.count > 6 ? 7 : (actionText.count > 4 ? 7.5 : 8.5)
                Text(actionText)
                    .font(.system(size: s.f(rawFontSize), weight: .black, design: .monospaced))
                    .foregroundColor(active ? .white : theme.textPrimary)
                    .lineLimit(1)
            }
        }
        .offset(offset)
        .fixedSize()
    }
}
