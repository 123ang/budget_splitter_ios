//
//  AppConfig.swift
//  BudgetSplitter
//
//  App is local-only (SQLite). apiBaseURL kept for AuthService/build; not used in local mode.
//

import Foundation

enum AppConfig {
    /// API base URL (for AuthService). Empty when app is local-only.
    static let apiBaseURL: String = ""
}
