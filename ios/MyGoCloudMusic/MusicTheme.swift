import SwiftUI

extension Color {
    static let myGoAccent = Color(red: 0.91, green: 0.23, blue: 0.27)
}

enum MusicTheme {
    static func background(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 20 / 255, green: 20 / 255, blue: 22 / 255) : .white
    }

    static func sidebar(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 28 / 255, green: 28 / 255, blue: 31 / 255)
            : Color(red: 244 / 255, green: 244 / 255, blue: 246 / 255)
    }

    static func primary(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 245 / 255, green: 245 / 255, blue: 247 / 255)
            : Color(red: 29 / 255, green: 29 / 255, blue: 31 / 255)
    }

    static func secondary(_ scheme: ColorScheme) -> Color {
        primary(scheme).opacity(0.6)
    }

    static func faint(_ scheme: ColorScheme) -> Color {
        primary(scheme).opacity(0.32)
    }

    static func rowHover(_ scheme: ColorScheme) -> Color {
        primary(scheme).opacity(scheme == .dark ? 0.06 : 0.04)
    }

    static func selected(_ scheme: ColorScheme) -> Color {
        primary(scheme).opacity(0.09)
    }

    static func line(_ scheme: ColorScheme) -> Color {
        primary(scheme).opacity(0.07)
    }
}
