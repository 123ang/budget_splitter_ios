//
//  L10n.swift
//  Exsplitter
//
//  Localized strings for Settings and key UI. Uses LanguageStore for in-app language.
//

import SwiftUI

enum L10n {
    private static let strings: [String: [AppLanguage: String]] = [
        "settings.title": [.en: "Settings", .zh: "设置", .ja: "設定"],
        "settings.language": [.en: "Language", .zh: "语言", .ja: "言語"],
        "settings.language.footer": [.en: "English, 中文, 日本語 available.", .zh: "可选：English、中文、日本語。", .ja: "English、中文、日本語から選択できます。"],
        "settings.theme": [.en: "Theme", .zh: "主题", .ja: "テーマ"],
        "settings.appearance": [.en: "Appearance", .zh: "外观", .ja: "外観"],
        "settings.theme.footer": [.en: "Light is the default. System follows your device setting.", .zh: "默认为浅色。系统跟随设备设置。", .ja: "デフォルトはライト。システムはデバイスに従います。"],
        "settings.localMode": [.en: "Local Mode", .zh: "本地模式", .ja: "ローカルモード"],
        "settings.localMode.desc": [.en: "Data stored on this device. No login required.", .zh: "数据存储在此设备，无需登录。", .ja: "データはこのデバイスに保存。ログイン不要。"],
        "settings.switchToCloud": [.en: "Switch to Cloud Sync", .zh: "切换到云端同步", .ja: "クラウド同期に切り替え"],
        "settings.switchToCloud.desc": [.en: "Sync data across devices", .zh: "跨设备同步数据", .ja: "デバイス間でデータを同期"],
        "settings.cloudMode": [.en: "Cloud Mode", .zh: "云端模式", .ja: "クラウドモード"],
        "settings.switchToLocal": [.en: "Switch to Local Mode", .zh: "切换到本地模式", .ja: "ローカルモードに切り替え"],
        "settings.switchToLocal.desc": [.en: "Use device storage. Free.", .zh: "使用设备存储，免费。", .ja: "デバイス保存を使用。無料。"],
        "settings.logOut": [.en: "Log Out", .zh: "退出登录", .ja: "ログアウト"],
        "settings.currency": [.en: "Currency", .zh: "货币", .ja: "通貨"],
        "settings.currency.footer": [.en: "New expenses use this currency. Rates auto-update when online.", .zh: "新支出使用此货币。联网时汇率自动更新。", .ja: "新規支出はこの通貨です。オンライン時にレートを自動更新。"],
        "settings.currency.offline": [.en: "When offline, set custom rates below.", .zh: "离线时可在下方设置自定义汇率。", .ja: "オフライン時は下でレートを設定できます。"],
        "settings.currency.customRate": [.en: "Custom rate (1 JPY = )", .zh: "自定义汇率（1 JPY = ）", .ja: "カスタムレート（1 JPY = ）"],
    ]

    static func string(_ key: String, language: AppLanguage = LanguageStore.shared.language) -> String {
        strings[key]?[language] ?? strings[key]?[.en] ?? key
    }
}
