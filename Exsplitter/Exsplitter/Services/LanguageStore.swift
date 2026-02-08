//
//  LanguageStore.swift
//  Xsplitter
//
//  App language: English, Chinese (Simplified), Japanese.
//

import Combine
import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
    case en
    case zh
    case ja

    var id: String { rawValue }

    /// Display name in the language itself (for the picker).
    var displayName: String {
        switch self {
        case .en: return "English"
        case .zh: return "中文"
        case .ja: return "日本語"
        }
    }

    /// Locale for this language (used for formatting and future localization).
    var locale: Locale {
        switch self {
        case .en: return Locale(identifier: "en")
        case .zh: return Locale(identifier: "zh-Hans")
        case .ja: return Locale(identifier: "ja")
        }
    }

    /// Short code shown in settings (e.g. "EN", "中文", "JA").
    var shortCode: String {
        switch self {
        case .en: return "EN"
        case .zh: return "中文"
        case .ja: return "JA"
        }
    }
}

final class LanguageStore: ObservableObject {
    static let shared = LanguageStore()

    private let languageKey = "BudgetSplitter_appLanguage"

    @Published var language: AppLanguage {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: languageKey)
        }
    }

    var locale: Locale {
        language.locale
    }

    private init() {
        let raw = UserDefaults.standard.string(forKey: languageKey)
        self.language = AppLanguage(rawValue: raw ?? "en") ?? .en
    }
}
