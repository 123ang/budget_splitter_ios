//
//  BudgetDataStore.swift
//  BudgetSplitter
//

import Foundation
import Combine
import SwiftUI

final class BudgetDataStore: ObservableObject {

    // MARK: - Published state
    @Published var members: [Member] = []
    @Published var expenses: [Expense] = []

    // MARK: - Init
    init() {
        // Optional: seed default members for testing
        // members = [Member(name: "You"), Member(name: "Wife")]
    }

    // MARK: - Member CRUD
    func addMember(name: String) {
        let m = Member(id: UUID().uuidString, name: name)
        members.append(m)
    }

    func removeMember(memberId: String) {
        members.removeAll { $0.id == memberId }
        // also clean expenses that reference removed member (optional)
        expenses.removeAll { $0.paidByMemberId == memberId }
    }

    // MARK: - Expense CRUD
    func addExpense(_ expense: Expense) {
        expenses.append(expense)
    }

    func removeExpense(expenseId: String) {
        expenses.removeAll { $0.id == expenseId }
    }

    /// Remove all members and expenses.
    func resetAll() {
        members.removeAll()
        expenses.removeAll()
    }

    // MARK: - Calculations
    func totalAmount(in currency: Currency? = nil) -> Double {
        let filtered = currency == nil ? expenses : expenses.filter { $0.currency == currency }
        return filtered.reduce(0) { $0 + $1.amount }
    }

    /// Total number of expenses.
    var totalExpenseCount: Int { expenses.count }

    /// Total amount spent per currency.
    var totalSpentByCurrency: [Currency: Double] {
        Dictionary(grouping: expenses, by: { $0.currency })
            .mapValues { $0.reduce(0) { $0 + $1.amount } }
    }

    /// Total amount per category for a given currency.
    func categoryTotals(currency: Currency) -> [ExpenseCategory: Double] {
        let filtered = expenses.filter { $0.currency == currency }
        return Dictionary(grouping: filtered, by: { $0.category })
            .mapValues { $0.reduce(0) { $0 + $1.amount } }
    }

    /// Total amount paid by a specific member in a given currency.
    func memberTotal(memberId: String, currency: Currency) -> Double {
        expenses
            .filter { $0.paidByMemberId == memberId && $0.currency == currency }
            .reduce(0) { $0 + $1.amount }
    }
}
