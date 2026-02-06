//
//  CloudStateStore.swift
//  Exsplitter
//
//  Persists current cloud group ID so we know which group to load after login.
//

import Combine
import Foundation
import SwiftUI

final class CloudStateStore: ObservableObject {
    static let shared = CloudStateStore()
    private let key = "BudgetSplitter_currentGroupId"

    var currentGroupId: String? {
        get { _currentGroupId }
        set {
            _currentGroupId = newValue
            objectWillChange.send()
            UserDefaults.standard.set(newValue, forKey: key)
        }
    }

    private var _currentGroupId: String?

    private init() {
        _currentGroupId = UserDefaults.standard.string(forKey: key)
    }

    func clear() {
        currentGroupId = nil
    }
}
