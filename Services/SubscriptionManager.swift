//
//  SubscriptionManager.swift
//  BudgetSplitter
//
//  Cloud mode requires an active subscription.
//  Replace with StoreKit 2 or RevenueCat when ready.
//

import Foundation

final class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    /// Set to true for testing without payment. Set to false to enforce paywall.
    static let debugBypassPaywall = true

    @Published private(set) var hasActiveSubscription: Bool

    private let subscriptionKey = "BudgetSplitter_hasSubscription"

    private init() {
        if Self.debugBypassPaywall {
            hasActiveSubscription = true
        } else {
            hasActiveSubscription = UserDefaults.standard.bool(forKey: subscriptionKey)
        }
    }

    /// Check if user can use cloud mode. Call before switching to cloud.
    func canUseCloudMode() -> Bool {
        if Self.debugBypassPaywall {
            return true
        }
        return hasActiveSubscription
    }

    /// Call after successful purchase / subscription restoration.
    func grantSubscription() {
        hasActiveSubscription = true
        UserDefaults.standard.set(true, forKey: subscriptionKey)
    }

    /// Call when subscription expires or is revoked.
    func revokeSubscription() {
        hasActiveSubscription = false
        UserDefaults.standard.set(false, forKey: subscriptionKey)
    }

    // TODO: Integrate StoreKit 2
    // func purchase() async throws { ... }
    // func restorePurchases() async { ... }
}
