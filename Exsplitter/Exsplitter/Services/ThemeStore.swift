//
//  ThemeStore.swift
//  Xsplitter
//
//  App theme: Light, Dark, System, Cream, Beige, Palette.
//

import Combine
import SwiftUI

enum AppTheme: String, CaseIterable {
    case light
    case dark
    case system
    case cream
    case beige
    case palette
    case sage
    case sky
    case rose
    case slate

    var displayName: String {
        switch self {
        case .light: return "Light"
        case .dark: return "Dark"
        case .system: return "System"
        case .cream: return "Cream"
        case .beige: return "Beige"
        case .palette: return "Palette"
        case .sage: return "Sage"
        case .sky: return "Sky"
        case .rose: return "Rose"
        case .slate: return "Slate"
        }
    }

    var icon: String {
        switch self {
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        case .system: return "circle.lefthalf.filled"
        case .cream: return "paintpalette.fill"
        case .beige: return "square.fill"
        case .palette: return "paintbrush.pointed.fill"
        case .sage: return "leaf.fill"
        case .sky: return "cloud.sun.fill"
        case .rose: return "heart.fill"
        case .slate: return "square.2.layers.3d"
        }
    }

    /// For custom themes we use .light so status bar/keyboard stay light; colors come from AppThemeColors.
    var colorScheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        case .cream, .beige, .palette, .sage, .sky, .rose, .slate: return .light
        }
    }
}

final class ThemeStore: ObservableObject {
    static let shared = ThemeStore()

    private let themeKey = "BudgetSplitter_appTheme"

    @Published var theme: AppTheme {
        didSet {
            UserDefaults.standard.set(theme.rawValue, forKey: themeKey)
        }
    }

    /// Resolved color scheme for .preferredColorScheme(). nil = follow system.
    var resolvedColorScheme: ColorScheme? {
        theme.colorScheme
    }

    private init() {
        let raw = UserDefaults.standard.string(forKey: "BudgetSplitter_appTheme")
        self.theme = AppTheme(rawValue: raw ?? "") ?? .light
    }

    func setTheme(_ newTheme: AppTheme) {
        theme = newTheme
    }
}
