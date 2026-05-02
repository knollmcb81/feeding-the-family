import SwiftUI

enum T {
    static let paper          = Color(hex: 0xfafaf7)
    static let paperDeep      = Color(hex: 0xf1f1ec)
    static let ink            = Color(hex: 0x0e0e0c)
    static let ink2           = Color(hex: 0x52524d)
    static let ink3           = Color(hex: 0x8f8f87)
    static let rule           = Color(hex: 0xe8e8e2)
    static let ruleSoft       = Color(hex: 0xf1f1ec)
    static let card           = Color(hex: 0xffffff)
    static let accent         = Color(hex: 0xc4f23a)
    static let accentInk      = Color(hex: 0x0e0e0c)
    static let accent2        = Color(hex: 0x2a7a3a)
    static let warn           = Color(hex: 0xff6b3d)
    static let proteinFresh   = Color(hex: 0xff6b3d)
    static let proteinFrozen  = Color(hex: 0x3b82f6)
    static let proteinPantry  = Color(hex: 0x8f8f87)
}

enum AppFont {
    // Display falls back to New York (system serif), text to SF Pro, mono to SF Mono.
    static func display(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
    static func text(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

enum Radius {
    static let card: CGFloat = 14
    static let cardSmall: CGFloat = 10
    static let pill: CGFloat = 99
    static let mini: CGFloat = 8
    static let chip: CGFloat = 6
}

enum Pad {
    static let sheetH: CGFloat = 22
    static let sheetHTight: CGFloat = 16
}

extension Color {
    init(hex: UInt32, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xff) / 255
        let g = Double((hex >> 8) & 0xff) / 255
        let b = Double(hex & 0xff) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}
