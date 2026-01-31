//
//  AppModeStore.swift
//  BudgetSplitter
//
//  Runtime mode switching. Cloud mode requires subscription.
//

import Foundation
import Combine
import SwiftUI

final class AppModeStore: ObservableObject {
    static let shared = AppModeStore()

    private let modeKey = "BudgetSplitter_useRemoteAPI"

    /// true = Cloud (VPS), false = Local
    @Published var useRemoteAPI: Bool

    private init() {
        self.useRemoteAPI = UserDefaults.standard.bool(forKey: modeKey)
    }
    
    /// Save the mode to UserDefaults whenever it changes
    private func saveMode() {
        UserDefaults.standard.set(useRemoteAPI, forKey: modeKey)
    }

    /// Switch to cloud mode. (Subscription check hidden for now.)
    func switchToCloudMode() {
        useRemoteAPI = true
        saveMode()
    }

    /// Switch to local mode. Always allowed (free).
    func switchToLocalMode() {
        useRemoteAPI = false
        saveMode()
        AuthService.shared.logout()
    }
}
