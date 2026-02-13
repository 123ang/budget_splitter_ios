//
//  AppThemeColors.swift
//  Xsplitter
//
//  Clean, comfortable palettes: system Light/Dark/System or custom Cream/Beige/Palette.
//

import SwiftUI
import UIKit

extension Color {
    private static var currentTheme: AppTheme { ThemeStore.shared.theme }

    /// Main screen background — soft and easy on the eyes.
    static var appBackground: Color {
        switch currentTheme {
        case .light, .dark, .system:
            return Color(uiColor: .systemBackground)
        case .cream:
            return Color(red: 253/255, green: 252/255, blue: 232/255)   // #FDFCE8 cream
        case .beige:
            return Color(red: 232/255, green: 218/255, blue: 198/255)   // brown beige
        case .palette:
            return Color(red: 250/255, green: 248/255, blue: 253/255)   // soft lavender tint
        case .sage:
            return Color(red: 238/255, green: 245/255, blue: 238/255)   // soft sage green
        case .sky:
            return Color(red: 238/255, green: 246/255, blue: 252/255)   // soft sky blue
        case .rose:
            return Color(red: 253/255, green: 242/255, blue: 244/255)   // soft rose pink
        case .slate:
            return Color(red: 242/255, green: 243/255, blue: 245/255)   // soft cool gray
        }
    }

    /// Card and secondary panels — subtle elevation.
    static var appCard: Color {
        switch currentTheme {
        case .light, .dark, .system:
            return Color(uiColor: .secondarySystemBackground)
        case .cream:
            return Color(red: 250/255, green: 248/255, blue: 224/255)   // slightly darker than #FDFCE8 for cards
        case .beige:
            return Color(red: 222/255, green: 205/255, blue: 182/255)   // brown beige card
        case .palette:
            return Color(red: 246/255, green: 242/255, blue: 252/255)
        case .sage:
            return Color(red: 228/255, green: 238/255, blue: 228/255)
        case .sky:
            return Color(red: 228/255, green: 240/255, blue: 248/255)
        case .rose:
            return Color(red: 252/255, green: 235/255, blue: 238/255)
        case .slate:
            return Color(red: 235/255, green: 236/255, blue: 240/255)
        }
    }

    /// Tertiary fill (input fields, tags, chips) — gentle contrast.
    static var appTertiary: Color {
        switch currentTheme {
        case .light, .dark, .system:
            return Color(uiColor: .tertiarySystemFill)
        case .cream:
            return Color(red: 245/255, green: 242/255, blue: 218/255)   // tertiary on cream
        case .beige:
            return Color(red: 212/255, green: 195/255, blue: 170/255)   // brown beige tertiary
        case .palette:
            return Color(red: 240/255, green: 232/255, blue: 248/255)
        case .sage:
            return Color(red: 218/255, green: 230/255, blue: 218/255)
        case .sky:
            return Color(red: 218/255, green: 232/255, blue: 242/255)
        case .rose:
            return Color(red: 248/255, green: 228/255, blue: 232/255)
        case .slate:
            return Color(red: 228/255, green: 230/255, blue: 234/255)
        }
    }

    /// Separator lines — low emphasis.
    static var appSeparator: Color {
        switch currentTheme {
        case .light, .dark, .system:
            return Color(uiColor: .separator)
        case .cream:
            return Color(red: 228/255, green: 224/255, blue: 200/255).opacity(0.8)   // separator on #FDFCE8
        case .beige:
            return Color(red: 188/255, green: 168/255, blue: 145/255).opacity(0.8)   // brown beige separator
        case .palette:
            return Color(red: 224/255, green: 214/255, blue: 238/255).opacity(0.8)
        case .sage:
            return Color(red: 195/255, green: 212/255, blue: 195/255).opacity(0.8)
        case .sky:
            return Color(red: 195/255, green: 218/255, blue: 232/255).opacity(0.8)
        case .rose:
            return Color(red: 228/255, green: 198/255, blue: 205/255).opacity(0.8)
        case .slate:
            return Color(red: 200/255, green: 202/255, blue: 210/255).opacity(0.8)
        }
    }

    /// Primary text — clear and readable.
    static var appPrimary: Color {
        switch currentTheme {
        case .light, .dark, .system:
            return Color(uiColor: .label)
        case .cream:
            return Color(red: 52/255, green: 48/255, blue: 44/255)
        case .beige:
            return Color(red: 55/255, green: 45/255, blue: 38/255)   // dark brown text on brown beige
        case .palette:
            return Color(red: 50/255, green: 46/255, blue: 62/255)
        case .sage:
            return Color(red: 42/255, green: 58/255, blue: 48/255)
        case .sky:
            return Color(red: 38/255, green: 52/255, blue: 68/255)
        case .rose:
            return Color(red: 68/255, green: 48/255, blue: 54/255)
        case .slate:
            return Color(red: 48/255, green: 52/255, blue: 58/255)
        }
    }

    /// Secondary / muted text — comfortable hierarchy.
    static var appSecondary: Color {
        switch currentTheme {
        case .light, .dark, .system:
            return Color(uiColor: .secondaryLabel)
        case .cream:
            return Color(red: 100/255, green: 92/255, blue: 84/255)
        case .beige:
            return Color(red: 95/255, green: 78/255, blue: 65/255)   // muted brown secondary
        case .palette:
            return Color(red: 92/255, green: 86/255, blue: 108/255)
        case .sage:
            return Color(red: 78/255, green: 98/255, blue: 84/255)
        case .sky:
            return Color(red: 72/255, green: 92/255, blue: 112/255)
        case .rose:
            return Color(red: 112/255, green: 82/255, blue: 92/255)
        case .slate:
            return Color(red: 88/255, green: 92/255, blue: 102/255)
        }
    }

    /// Accent (icons, buttons, links) — tuned per theme for contrast and fit.
    static var appAccent: Color {
        switch currentTheme {
        case .light:
            return Color(red: 10/255, green: 132/255, blue: 1)           // system blue on white
        case .dark:
            return Color(red: 100/255, green: 180/255, blue: 1)         // brighter blue on dark
        case .system:
            return Color(red: 10/255, green: 132/255, blue: 1)          // system blue
        case .cream:
            return Color(red: 148/255, green: 118/255, blue: 72/255)     // warm amber/gold (fits cream)
        case .beige:
            return Color(red: 60/255, green: 108/255, blue: 105/255)     // muted teal (fits brown beige)
        case .palette:
            return Color(red: 100/255, green: 80/255, blue: 140/255)     // soft violet (fits lavender)
        case .sage:
            return Color(red: 48/255, green: 128/255, blue: 96/255)     // sage green (fits green tint)
        case .sky:
            return Color(red: 42/255, green: 112/255, blue: 168/255)     // sky blue (fits blue tint)
        case .rose:
            return Color(red: 168/255, green: 72/255, blue: 88/255)      // dusty rose (fits pink tint)
        case .slate:
            return Color(red: 62/255, green: 82/255, blue: 118/255)     // slate blue (fits gray tint)
        }
    }
}
