import SwiftUI

// Cool Morandi colors from the user's reference. Dark ink keeps small text readable.
enum AppPalette {
    static let background = Color(.sRGB, red: 243.0/255, green: 246.0/255, blue: 247.0/255, opacity: 1)
    static let ink = Color(.sRGB, red: 52.0/255, green: 73.0/255, blue: 84.0/255, opacity: 1)
    static let secondary = Color(.sRGB, red: 100.0/255, green: 118.0/255, blue: 132.0/255, opacity: 1)
    static let accent = Color(.sRGB, red: 117.0/255, green: 150.0/255, blue: 157.0/255, opacity: 1)
    static let powderBlue = Color(.sRGB, red: 190.0/255, green: 207.0/255, blue: 217.0/255, opacity: 1)
    static let blue = Color(.sRGB, red: 143.0/255, green: 164.0/255, blue: 181.0/255, opacity: 1)
    static let line = Color(.sRGB, red: 216.0/255, green: 225.0/255, blue: 230.0/255, opacity: 1)
    static let card = Color(.sRGB, red: 251.0/255, green: 252.0/255, blue: 253.0/255, opacity: 1)
    static let glacierBlue = Color(.sRGB, red: 213.0/255, green: 223.0/255, blue: 232.0/255, opacity: 1)
    static let frostBlue = Color(.sRGB, red: 196.0/255, green: 209.0/255, blue: 217.0/255, opacity: 1)
    static let seaGlass = Color(.sRGB, red: 140.0/255, green: 180.0/255, blue: 189.0/255, opacity: 1)
    static let lavender = Color(.sRGB, red: 196.0/255, green: 187.0/255, blue: 214.0/255, opacity: 1)
    static let dustyPink = Color(.sRGB, red: 220.0/255, green: 186.0/255, blue: 198.0/255, opacity: 1)
    static let purpleInk = Color(.sRGB, red: 111.0/255, green: 92.0/255, blue: 139.0/255, opacity: 1)
    static let pinkInk = Color(.sRGB, red: 146.0/255, green: 91.0/255, blue: 115.0/255, opacity: 1)

    static var heroGradient: LinearGradient {
        return LinearGradient(colors: [Color(.sRGB, red: 226.0/255, green: 231.0/255, blue: 234.0/255, opacity: 1),
                                       Color(.sRGB, red: 196.0/255, green: 213.0/255, blue: 221.0/255, opacity: 1), powderBlue],
                              startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    static var backgroundGradient: LinearGradient {
        return LinearGradient(colors: [background, glacierBlue.opacity(0.45)], startPoint: .top, endPoint: .bottom)
    }
}
