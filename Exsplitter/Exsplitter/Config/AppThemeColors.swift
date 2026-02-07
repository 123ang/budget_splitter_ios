//
//  AppThemeColors.swift
//  Exsplitter
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
            return Color(red: 253/255, green: 251/255, blue: 245/255)   // soft cream
        case .beige:
            return Color(red: 250/255, green: 248/255, blue: 240/255)   // warm sand
        case .palette:
            return Color(red: 250/255, green: 248/255, blue: 253/255)   // soft lavender tint
        }
    }

    /// Card and secondary panels — subtle elevation.
    static var appCard: Color {
        switch currentTheme {
        case .light, .dark, .system:
            return Color(uiColor: .secondarySystemBackground)
        case .cream:
            return Color(red: 1, green: 248/255, blue: 238/255)          // slightly warmer cream
        case .beige:
            return Color(red: 245/255, green: 242/255, blue: 232/255)   // warm card
        case .palette:
            return Color(red: 246/255, green: 242/255, blue: 252/255)   // very light lavender
        }
    }

    /// Tertiary fill (input fields, tags, chips) — gentle contrast.
    static var appTertiary: Color {
        switch currentTheme {
        case .light, .dark, .system:
            return Color(uiColor: .tertiarySystemFill)
        case .cream:
            return Color(red: 243/255, green: 238/255, blue: 228/255)
        case .beige:
            return Color(red: 238/255, green: 234/255, blue: 222/255)
        case .palette:
            return Color(red: 240/255, green: 232/255, blue: 248/255)
        }
    }

    /// Separator lines — low emphasis.
    static var appSeparator: Color {
        switch currentTheme {
        case .light, .dark, .system:
            return Color(uiColor: .separator)
        case .cream:
            return Color(red: 228/255, green: 220/255, blue: 208/255).opacity(0.8)
        case .beige:
            return Color(red: 218/255, green: 212/255, blue: 198/255).opacity(0.8)
        case .palette:
            return Color(red: 224/255, green: 214/255, blue: 238/255).opacity(0.8)
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
            return Color(red: 58/255, green: 54/255, blue: 48/255)
        case .palette:
            return Color(red: 50/255, green: 46/255, blue: 62/255)
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
            return Color(red: 108/255, green: 100/255, blue: 90/255)
        case .palette:
            return Color(red: 92/255, green: 86/255, blue: 108/255)
        }
    }

    /// Accent (buttons, links) — works on all themes.
    static var appAccent: Color {
        switch currentTheme {
        case .light, .dark, .system:
            return Color(red: 10/255, green: 132/255, blue: 1)
        case .cream, .beige:
            return Color(red: 72/255, green: 120/255, blue: 118/255)   // muted teal
        case .palette:
            return Color(red: 100/255, green: 80/255, blue: 140/255)    // soft violet
        }
    }
}
