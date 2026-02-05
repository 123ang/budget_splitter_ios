//
//  CloudStateStore.swift
//  Exsplitter
//
//  Persists current cloud group ID so we know which group to load after login.
//

import Foundation
import SwiftUI

final class CloudStateStore: ObservableObject {
    static let shared = CloudStateStore()
    private let key = "BudgetSplitter_currentGroupId"

    @Published var currentGroupId: String? {
        didSet {
            UserDefaults.standard.set(currentGroupId, forKey: key)
        }
    }

    private init() {
        currentGroupId = UserDefaults.standard.string(forKey: key)
    }

    func clear() {
        currentGroupId = nil
    }
}
