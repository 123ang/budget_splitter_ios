//
//  CurrencyStore.swift
//  Exsplitter
//
//  Preferred currency for new expenses. Exchange rates from JPY; auto-fetch when online, manual when offline.
//

import Combine
import Foundation
import SwiftUI

final class CurrencyStore: ObservableObject {
    static let shared = CurrencyStore()

    private let preferredKey = "BudgetSplitter_preferredCurrency"
    private let lastRatesKey = "BudgetSplitter_lastFetchedRates"
    private let customRatesKey = "BudgetSplitter_customRates"

    @Published var preferredCurrency: Currency {
        didSet {
            UserDefaults.standard.set(preferredCurrency.rawValue, forKey: preferredKey)
        }
    }

    /// Rates from JPY to others: 1 JPY = value MYR (key "MYR"), etc. Used when online or as fallback.
    @Published var lastFetchedRates: [String: Double] = [:] {
        didSet {
            if let data = try? JSONEncoder().encode(lastFetchedRates) {
                UserDefaults.standard.set(data, forKey: lastRatesKey)
            }
        }
    }

    /// User-set rates when offline: 1 JPY = value (key "MYR"). Overrides lastFetched when set.
    @Published var customRates: [String: Double] = [:] {
        didSet {
            if let data = try? JSONEncoder().encode(customRates) {
                UserDefaults.standard.set(data, forKey: customRatesKey)
            }
        }
    }

    /// True after a successful fetch; false if last fetch failed (e.g. offline).
    @Published var lastFetchSucceeded: Bool = false

    private init() {
        let raw = UserDefaults.standard.string(forKey: preferredKey)
        self.preferredCurrency = Currency(rawValue: raw ?? "JPY") ?? .JPY
        if let data = UserDefaults.standard.data(forKey: lastRatesKey),
           let decoded = try? JSONDecoder().decode([String: Double].self, from: data) {
            lastFetchedRates = decoded
        }
        if let data = UserDefaults.standard.data(forKey: customRatesKey),
           let decoded = try? JSONDecoder().decode([String: Double].self, from: data) {
            customRates = decoded
        }
    }

    /// Conversion rate: 1 unit of `from` = result units of `to`.
    func rate(from: Currency, to: Currency) -> Double {
        if from == to { return 1 }
        // Use custom rate if set (when offline), else last fetched, else fallback.
        let jpyToOther: (String) -> Double = { key in
            self.customRates[key] ?? self.lastFetchedRates[key] ?? Self.fallbackRate(fromJPY: key)
        }
        switch (from, to) {
        case (.JPY, .MYR): return jpyToOther("MYR")
        case (.JPY, .SGD): return jpyToOther("SGD")
        case (.MYR, .JPY): return 1 / jpyToOther("MYR")
        case (.SGD, .JPY): return 1 / jpyToOther("SGD")
        case (.MYR, .SGD): return jpyToOther("SGD") / jpyToOther("MYR")
        case (.SGD, .MYR): return jpyToOther("MYR") / jpyToOther("SGD")
        default: return 1
        }
    }

    private static func fallbackRate(fromJPY key: String) -> Double {
        switch key {
        case "MYR": return 0.031  // approximate 1 JPY ≈ 0.031 MYR
        case "SGD": return 0.009  // approximate 1 JPY ≈ 0.009 SGD
        default: return 1
        }
    }

    /// Fetch latest rates from JPY to MYR, SGD when online. Call on appear (Settings) or app launch.
    func fetchRatesIfNeeded() {
        let from = "JPY"
        let to = "MYR,SGD"
        guard let url = URL(string: "https://api.frankfurter.app/latest?from=\(from)&to=\(to)") else { return }
        let task = URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            DispatchQueue.main.async {
                guard let self = self, let data = data, error == nil,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let rates = json["rates"] as? [String: Double] else {
                    self?.lastFetchSucceeded = false
                    return
                }
                self.lastFetchedRates = rates
                self.lastFetchSucceeded = true
            }
        }
        task.resume()
    }

    /// Set a custom rate (e.g. when offline): 1 JPY = value for the given currency.
    func setCustomRate(currency: Currency, rateFromJPY: Double) {
        guard currency != .JPY else { return }
        customRates[currency.rawValue] = rateFromJPY
    }

    /// Clear custom rate for currency (use fetched rate again).
    func clearCustomRate(currency: Currency) {
        customRates.removeValue(forKey: currency.rawValue)
    }
}
