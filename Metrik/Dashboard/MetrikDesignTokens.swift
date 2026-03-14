import SwiftUI

// Design tokens matching metrik-activity.pen variables
extension Color {
    static let mkBgPage       = Color(red: 28/255,  green: 28/255,  blue: 30/255)           // #1C1C1E
    static let mkBgCard       = Color(red: 44/255,  green: 44/255,  blue: 46/255)           // #2C2C2E
    static let mkBgInset      = Color(red: 58/255,  green: 58/255,  blue: 60/255)           // #3A3A3C
    static let mkBorderLight  = Color.white.opacity(0.078)                                  // #FFFFFF14
    static let mkSeparator    = Color(red: 56/255,  green: 56/255,  blue: 58/255)           // #38383A
    static let mkAccent       = Color(red: 10/255,  green: 132/255, blue: 255/255)          // #0A84FF
    static let mkPositive     = Color(red: 48/255,  green: 209/255, blue: 88/255)           // #30D158
    static let mkNegative     = Color(red: 255/255, green: 69/255,  blue: 58/255)           // #FF453A
    static let mkTextPrimary  = Color.white                                                 // #FFFFFF
    static let mkTextSecondary = Color(red: 152/255, green: 152/255, blue: 157/255)         // #98989D
    static let mkTextTertiary  = Color(red: 142/255, green: 142/255, blue: 147/255)          // #8E8E93
    static let mkTextMuted     = Color(red: 122/255, green: 122/255, blue: 127/255)         // #7A7A7F
}
