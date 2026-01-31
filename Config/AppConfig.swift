//
//  AppConfig.swift
//  BudgetSplitter
//
//  Toggle between Local (SQLite/UserDefaults) and VPS (API + auth) modes.
//  Set USE_REMOTE_API=1 in build settings or change default for VPS build.
//

import Foundation

enum AppConfig {
    /// Local mode: No login, data stored on device (UserDefaults/SQLite).
    /// VPS mode: Login required, data synced with server.
    static var useRemoteAPI: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.environment["USE_REMOTE_API"] == "1"
        #else
        return ProcessInfo.processInfo.environment["USE_REMOTE_API"] == "1"
        #endif
    }

    /// API base URL for VPS mode. Set in build config or Info.plist.
    static var apiBaseURL: String {
        (Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String)
            ?? ProcessInfo.processInfo.environment["API_BASE_URL"]
            ?? "https://your-vps.com/budget-api"
    }

    /// For local server mode (MODE=local): connect to dev machine.
    /// e.g. "http://192.168.1.100:3012" or "http://localhost:3012"
    static var localServerURL: String {
        (Bundle.main.object(forInfoDictionaryKey: "LOCAL_SERVER_URL") as? String)
            ?? "http://localhost:3012"
    }
}
