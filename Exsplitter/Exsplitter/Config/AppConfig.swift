//
//  AppConfig.swift
//  BudgetSplitter
//
//  Mode is now switched in Settings (AppModeStore).
//  Use AppModeStore.shared.useRemoteAPI for current mode.
//

import Foundation

enum AppConfig {

    /// API base URL for VPS mode. Set in build config or Info.plist.
    static var apiBaseURL: String {
        (Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String)
            ?? ProcessInfo.processInfo.environment["API_BASE_URL"]
            ?? "https://splitx.suntzutechnologies.com"
    }

    /// For local server mode (MODE=local): connect to dev machine.
    /// e.g. "http://192.168.1.100:3012" or "http://localhost:3012"
    static var localServerURL: String {
        (Bundle.main.object(forInfoDictionaryKey: "LOCAL_SERVER_URL") as? String)
            ?? "http://localhost:3012"
    }
}
