//
//  AppConfig.swift
//  BudgetSplitter
//
//  Local-only app.
//

import Foundation

enum AppConfig {
    /// For local server / future use.
    /// e.g. "http://192.168.1.100:3012" or "http://localhost:3012"
    static var localServerURL: String {
        (Bundle.main.object(forInfoDictionaryKey: "LOCAL_SERVER_URL") as? String)
            ?? "http://localhost:3012"
    }
}
