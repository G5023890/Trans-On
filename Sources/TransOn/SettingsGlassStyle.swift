import SwiftUI

struct SettingsGlassPalette {
    let colorScheme: ColorScheme

    var isDark: Bool { colorScheme == .dark }

    var pageBackground: some View {
        ZStack {
            LinearGradient(
                colors: isDark
                    ? [Color(red: 0.05, green: 0.09, blue: 0.13), Color(red: 0.11, green: 0.07, blue: 0.19)]
                    : [Color(red: 0.78, green: 0.84, blue: 0.94), Color(red: 0.88, green: 0.81, blue: 0.96)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill((isDark ? Color(red: 0.10, green: 0.17, blue: 0.12) : Color(red: 0.94, green: 0.91, blue: 0.80)).opacity(isDark ? 0.46 : 0.92))
                .frame(width: 420, height: 420)
                .blur(radius: 70)
                .offset(x: 180, y: 120)

            Circle()
                .fill((isDark ? Color(red: 0.18, green: 0.10, blue: 0.28) : Color(red: 0.79, green: 0.85, blue: 0.95)).opacity(isDark ? 0.56 : 0.9))
                .frame(width: 360, height: 360)
                .blur(radius: 80)
                .offset(x: -180, y: -120)
        }
    }

    var panelFill: Color {
        isDark ? Color.white.opacity(0.08) : Color.white.opacity(0.42)
    }

    var panelStroke: Color {
        isDark ? Color.white.opacity(0.10) : Color.white.opacity(0.72)
    }

    var panelShadow: Color {
        isDark ? Color.black.opacity(0.42) : Color(red: 0.31, green: 0.39, blue: 0.56).opacity(0.18)
    }

    var sidebarFill: Color {
        isDark ? Color.white.opacity(0.05) : Color.white.opacity(0.24)
    }

    var sidebarStroke: Color {
        isDark ? Color.white.opacity(0.08) : Color.white.opacity(0.52)
    }

    var rowFill: Color {
        isDark ? Color.white.opacity(0.06) : Color.white.opacity(0.34)
    }

    var rowStroke: Color {
        isDark ? Color.white.opacity(0.08) : Color.white.opacity(0.48)
    }

    var rowHover: Color {
        isDark ? Color.white.opacity(0.08) : Color.white.opacity(0.48)
    }

    var separator: Color {
        isDark ? Color.white.opacity(0.08) : Color(red: 0.79, green: 0.82, blue: 0.90).opacity(0.7)
    }

    var primaryText: Color {
        isDark ? Color.white.opacity(0.88) : Color.black.opacity(0.82)
    }

    var secondaryText: Color {
        isDark ? Color.white.opacity(0.44) : Color.black.opacity(0.45)
    }

    var sectionText: Color {
        isDark ? Color.white.opacity(0.30) : Color.black.opacity(0.34)
    }

    var activeSidebarText: Color {
        isDark ? Color.white.opacity(0.92) : Color.black.opacity(0.86)
    }

    var inactiveSidebarText: Color {
        isDark ? Color.white.opacity(0.42) : Color.black.opacity(0.52)
    }

    var activeSidebarFill: Color {
        isDark ? Color.white.opacity(0.12) : Color.white.opacity(0.54)
    }

    var hoverSidebarFill: Color {
        isDark ? Color.white.opacity(0.07) : Color.white.opacity(0.30)
    }

    var keyCapFill: Color {
        isDark ? Color.white.opacity(0.08) : Color.white.opacity(0.55)
    }

    var keyCapStroke: Color {
        isDark ? Color.white.opacity(0.14) : Color(red: 0.72, green: 0.76, blue: 0.84).opacity(0.8)
    }

    var controlFill: Color {
        isDark ? Color.white.opacity(0.08) : Color.white.opacity(0.44)
    }

    var controlStroke: Color {
        isDark ? Color.white.opacity(0.12) : Color.white.opacity(0.74)
    }

    var inputFill: Color {
        isDark ? Color.white.opacity(0.07) : Color.white.opacity(0.46)
    }

    var inputStroke: Color {
        isDark ? Color.white.opacity(0.10) : Color.white.opacity(0.70)
    }

    var apiCardFill: Color {
        isDark ? Color.accentColor.opacity(0.10) : Color.accentColor.opacity(0.07)
    }

    var apiCardStroke: Color {
        isDark ? Color.accentColor.opacity(0.24) : Color.accentColor.opacity(0.22)
    }

    var toggleOff: Color {
        isDark ? Color.white.opacity(0.18) : Color(red: 0.73, green: 0.76, blue: 0.84).opacity(0.7)
    }
}

struct GlassSectionTitle: View {
    let text: String
    let palette: SettingsGlassPalette

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .kerning(0.8)
            .foregroundStyle(palette.sectionText)
            .textCase(.uppercase)
            .padding(.leading, 3)
    }
}

struct GlassGroup<Content: View>: View {
    let palette: SettingsGlassPalette
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .background(palette.rowFill)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(palette.rowStroke, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(palette.isDark ? 0.16 : 0.05), radius: 10, y: 4)
    }
}

struct GlassDivider: View {
    let palette: SettingsGlassPalette

    var body: some View {
        Rectangle()
            .fill(palette.separator)
            .frame(height: 1)
    }
}

struct GlassButtonStyle: ButtonStyle {
    let palette: SettingsGlassPalette
    var prominent: Bool = false
    var tint: Color = .accentColor

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12.5, weight: .medium))
            .foregroundStyle(prominent ? tint : palette.secondaryText)
            .padding(.horizontal, 12)
            .frame(height: 30)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(prominent ? tint.opacity(palette.isDark ? 0.18 : 0.12) : palette.controlFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(prominent ? tint.opacity(0.30) : palette.controlStroke, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct GlassToggleStyle: ToggleStyle {
    let palette: SettingsGlassPalette

    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
            Spacer(minLength: 12)
            ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(configuration.isOn ? Color(red: 0.20, green: 0.78, blue: 0.35) : palette.toggleOff)
                    .frame(width: 40, height: 24)

                Circle()
                    .fill(.white)
                    .frame(width: 20, height: 20)
                    .padding(2)
                    .shadow(color: Color.black.opacity(0.18), radius: 3, y: 1)
            }
            .onTapGesture {
                withAnimation(.spring(response: 0.24, dampingFraction: 0.75)) {
                    configuration.isOn.toggle()
                }
            }
        }
    }
}
