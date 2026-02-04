//
//  AppThemeColors.swift
//  Exsplitter
//
//  Adaptive colors so the app respects Light/Dark/System theme.
//

import SwiftUI
import UIKit

extension Color {
    /// Main screen background (adapts to light/dark).
    static var appBackground: Color { Color(uiColor: .systemBackground) }
    /// Card and secondary panels (adapts to light/dark).
    static var appCard: Color { Color(uiColor: .secondarySystemBackground) }
    /// Tertiary fill (e.g. input fields, tags) (adapts to light/dark).
    static var appTertiary: Color { Color(uiColor: .tertiarySystemFill) }
    /// Separator lines (adapts to light/dark).
    static var appSeparator: Color { Color(uiColor: .separator) }
    /// Primary text on cards (adapts: black in light, white in dark).
    static var appPrimary: Color { Color(uiColor: .label) }
}
