//
//  AppModeStore.swift
//  BudgetSplitter
//
//  Runtime mode switching. Cloud mode requires subscription.
//

import Combine
import Foundation
import SwiftUI

enum StorageMode {
    case local
    case cloud
}

final class AppModeStore: ObservableObject {
    static let shared = AppModeStore()

    private let modeKey = "BudgetSplitter_useRemoteAPI"

    /// true = Cloud (VPS), false = Local
    @Published var useRemoteAPI: Bool {
        didSet {
            UserDefaults.standard.set(useRemoteAPI, forKey: modeKey)
        }
    }

    private init() {
        useRemoteAPI = UserDefaults.standard.bool(forKey: modeKey)
    }

    /// Switch to cloud mode. (Subscription check hidden for now.)
    func switchToCloudMode() {
        useRemoteAPI = true
    }

    /// Switch to local mode. Always allowed (free).
    func switchToLocalMode() {
        useRemoteAPI = false
        AuthService.shared.logout()
    }
}
