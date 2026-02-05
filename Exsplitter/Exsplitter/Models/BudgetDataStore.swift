//
//  BudgetDataStore.swift
//  BudgetSplitter
//

import Combine
import Foundation
import SwiftUI

/// Marks that a debtor has paid their share of this expense to the creditor (checkbox).
struct PaidExpenseMark: Codable, Hashable {
    let debtorId: String
    let creditorId: String
    let expenseId: String
}

/// A recorded payment from a debtor to a creditor (partial or full).
struct SettlementPayment: Identifiable, Codable, Hashable {
    var id: String
    var debtorId: String
    var creditorId: String
    var amount: Double
    var note: String?
    var date: Date
    
    init(id: String = UUID().uuidString, debtorId: String, creditorId: String, amount: Double, note: String? = nil, date: Date = Date()) {
        self.id = id
        self.debtorId = debtorId
        self.creditorId = creditorId
        self.amount = amount
        self.note = note
        self.date = date
    }
}

final class BudgetDataStore: ObservableObject {
    @Published var members: [Member] = []
    @Published var expenses: [Expense] = []
    @Published var selectedMemberIds: Set<String> = []
    @Published var settledMemberIds: Set<String> = []
    @Published var settlementPayments: [SettlementPayment] = []
    @Published var paidExpenseMarks: [PaidExpenseMark] = []
    
    private let membersKey = "BudgetSplitter_members"
    private let expensesKey = "BudgetSplitter_expenses"
    private let selectedKey = "BudgetSplitter_selected"
    private let settledKey = "BudgetSplitter_settled"
    private let settlementPaymentsKey = "BudgetSplitter_settlementPayments"
    private let paidExpenseMarksKey = "BudgetSplitter_paidExpenseMarks"
    
    /// Used only when adding from history; new users start with one member from "Who is the host?" flow.
    static let defaultMemberNames = [
        "Soon Zheng Dong", "Soon Cheng Wai", "Soon Xin Yi", "See Siew Pheng",
        "Ang Shin Nee", "See Siew Tin", "See Siew Kim", "See Eng Kim",
        "See Yi Joe", "Koay Jun Ming"
    ]
    
    init() {
        load()
        if members.isEmpty {
            // New user: leave members empty so app shows "Who is the host?" first.
        } else if selectedMemberIds.isEmpty {
            // Sync selected to all members if empty (e.g. fresh upgrade)
            selectedMemberIds = Set(members.map(\.id))
            save()
        }
    }
    
    func addMember(_ name: String) {
        let member = Member(name: name.trimmingCharacters(in: .whitespacesAndNewlines))
        members.append(member)
        selectedMemberIds.insert(member.id)
        save()
    }
    
    func removeMember(id: String) {
        guard members.count > 1 else { return } // Keep at least one member
        members.removeAll { $0.id == id }
        selectedMemberIds.remove(id)
        let remainingFirstId = members.first?.id
        expenses = expenses.compactMap { exp -> Expense? in
            var e = exp
            e.splits.removeValue(forKey: id)
            e.splitMemberIds.removeAll { $0 == id }
            if e.paidByMemberId == id {
                guard let first = remainingFirstId else { return nil }
                e.paidByMemberId = first
            }
            if e.splitMemberIds.isEmpty { return nil }
            return e
        }
        settlementPayments.removeAll { $0.debtorId == id || $0.creditorId == id }
        paidExpenseMarks.removeAll { $0.debtorId == id || $0.creditorId == id }
        save()
    }
    
    func addExpense(_ expense: Expense) {
        expenses.append(expense)
        save()
    }
    
    func deleteExpense(id: String) {
        expenses.removeAll { $0.id == id }
        save()
    }
    
    /// Clears all expenses and resets members to a single member (the host/first member). User must supply the name via UI.
    func resetAll(firstMemberName: String) {
        let name = firstMemberName.trimmingCharacters(in: .whitespacesAndNewlines)
        let first = Member(name: name.isEmpty ? "Member 1" : name)
        members = [first]
        expenses = []
        selectedMemberIds = [first.id]
        settledMemberIds = []
        settlementPayments = []
        paidExpenseMarks = []
        save()
    }

    /// Adds all names as new members (e.g. from a saved group in history). If current list is only the placeholder "Member 1", replaces it.
    func addMembersFromHistory(names: [String]) {
        let trimmedNames = names.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard !trimmedNames.isEmpty else { return }
        // If we only have one member, clear first so "Add group" gives exactly that group
        if members.count == 1 {
            members = []
            selectedMemberIds = []
        }
        for name in trimmedNames {
            addMember(name)
        }
    }
    
    func toggleSelected(memberId: String) {
        if selectedMemberIds.contains(memberId) {
            selectedMemberIds.remove(memberId)
        } else {
            selectedMemberIds.insert(memberId)
        }
        save()
    }
    
    func toggleSettled(memberId: String) {
        if settledMemberIds.contains(memberId) {
            settledMemberIds.remove(memberId)
        } else {
            settledMemberIds.insert(memberId)
        }
        save()
    }
    
    // MARK: - Settle up
    
    /// Total this member paid (as payer) in the given currency. Uses amount - payerEarned when set.
    func totalPaidBy(memberId: String, currency: Currency) -> Double {
        expenses
            .filter { $0.currency == currency && $0.paidByMemberId == memberId }
            .reduce(0) { $0 + ($1.amount - ($1.payerEarned ?? 0)) }
    }
    
    /// Total share for this member in the given currency (from splits).
    func totalShare(memberId: String, currency: Currency) -> Double {
        expenses
            .filter { $0.currency == currency }
            .compactMap { $0.splits[memberId] }
            .reduce(0, +)
    }
    
    /// Net balance: positive = owed money, negative = owes money.
    func netBalance(memberId: String, currency: Currency) -> Double {
        totalPaidBy(memberId: memberId, currency: currency) - totalShare(memberId: memberId, currency: currency)
    }
    
    /// Minimal transfers to settle up: (debtorId, creditorId, amount).
    func settlementTransfers(currency: Currency) -> [(from: String, to: String, amount: Double)] {
        var balances: [String: Double] = [:]
        for m in members {
            let b = netBalance(memberId: m.id, currency: currency)
            if abs(b) > 0.001 { balances[m.id] = b }
        }
        var result: [(from: String, to: String, amount: Double)] = []
        var debtors = balances.filter { $0.value < -0.001 }.map { ($0.key, -$0.value) }.sorted { $0.1 > $1.1 }
        var creditors = balances.filter { $0.value > 0.001 }.map { ($0.key, $0.value) }.sorted { $0.1 > $1.1 }
        var i = 0, j = 0
        while i < debtors.count, j < creditors.count {
            let (debtor, dAmt) = debtors[i]
            let (creditor, cAmt) = creditors[j]
            let transfer = min(dAmt, cAmt)
            if transfer > 0.001 {
                result.append((from: debtor, to: creditor, amount: transfer))
            }
            if dAmt - transfer < 0.001 { i += 1 } else { debtors[i] = (debtor, dAmt - transfer) }
            if cAmt - transfer < 0.001 { j += 1 } else { creditors[j] = (creditor, cAmt - transfer) }
        }
        return result
    }
    
    /// Amount debtor owes creditor (from settlement transfers, JPY only for UI).
    func amountOwed(from debtorId: String, to creditorId: String, currency: Currency = .JPY) -> Double {
        settlementTransfers(currency: currency)
            .filter { $0.from == debtorId && $0.to == creditorId }
            .reduce(0) { $0 + $1.amount }
    }
    
    /// Total amount recorded as paid from debtor to creditor.
    func totalPaidFromTo(debtorId: String, creditorId: String) -> Double {
        settlementPayments
            .filter { $0.debtorId == debtorId && $0.creditorId == creditorId }
            .reduce(0) { $0 + $1.amount }
    }
    
    /// All payment records from debtor to creditor.
    func paymentsFromTo(debtorId: String, creditorId: String) -> [SettlementPayment] {
        settlementPayments
            .filter { $0.debtorId == debtorId && $0.creditorId == creditorId }
            .sorted { $0.date < $1.date }
    }
    
    func addSettlementPayment(debtorId: String, creditorId: String, amount: Double, note: String? = nil) {
        settlementPayments.append(SettlementPayment(debtorId: debtorId, creditorId: creditorId, amount: amount, note: note))
        save()
    }
    
    /// Expenses where creditor paid and debtor had a share (contributes to debtor owing creditor).
    func expensesContributingToDebt(creditorId: String, debtorId: String, currency: Currency = .JPY) -> [(expense: Expense, share: Double)] {
        expenses
            .filter { $0.currency == currency && $0.paidByMemberId == creditorId }
            .compactMap { exp -> (Expense, Double)? in
                guard let share = exp.splits[debtorId], share > 0 else { return nil }
                return (exp, share)
            }
    }
    
    /// Whether this expense is marked as paid (checkbox) by debtor to creditor.
    func isExpensePaid(debtorId: String, creditorId: String, expenseId: String) -> Bool {
        paidExpenseMarks.contains { $0.debtorId == debtorId && $0.creditorId == creditorId && $0.expenseId == expenseId }
    }
    
    /// Toggle expense paid checkbox for (debtor, creditor).
    func toggleExpensePaid(debtorId: String, creditorId: String, expenseId: String) {
        if isExpensePaid(debtorId: debtorId, creditorId: creditorId, expenseId: expenseId) {
            paidExpenseMarks.removeAll { $0.debtorId == debtorId && $0.creditorId == creditorId && $0.expenseId == expenseId }
        } else {
            paidExpenseMarks.append(PaidExpenseMark(debtorId: debtorId, creditorId: creditorId, expenseId: expenseId))
        }
        save()
    }
    
    /// Total amount counted as paid via expense checkboxes for this (debtor, creditor).
    func totalPaidViaExpenseCheckboxes(debtorId: String, creditorId: String, currency: Currency = .JPY) -> Double {
        let breakdown = expensesContributingToDebt(creditorId: creditorId, debtorId: debtorId, currency: currency)
        return breakdown
            .filter { isExpensePaid(debtorId: debtorId, creditorId: creditorId, expenseId: $0.expense.id) }
            .reduce(0) { $0 + $1.share }
    }
    
    // MARK: - Computed
    
    var totalSpentByCurrency: [Currency: Double] {
        var result: [Currency: Double] = [:]
        for exp in expenses {
            let selectedShare = exp.splits
                .filter { selectedMemberIds.contains($0.key) }
                .values
                .reduce(0, +)
            if selectedShare > 0 {
                result[exp.currency, default: 0] += selectedShare
            }
        }
        return result
    }
    
    var totalExpenseCount: Int { expenses.count }
    
    func totalSpent(currency: Currency) -> Double {
        totalSpentByCurrency[currency] ?? 0
    }
    
    func memberTotal(memberId: String, currency: Currency) -> Double {
        expenses
            .filter { $0.currency == currency }
            .compactMap { $0.splits[memberId] }
            .reduce(0, +)
    }
    
    func categoryTotals(currency: Currency) -> [ExpenseCategory: Double] {
        var result: [ExpenseCategory: Double] = [:]
        for exp in expenses where exp.currency == currency {
            let selectedShare = exp.splits
                .filter { selectedMemberIds.contains($0.key) }
                .values
                .reduce(0, +)
            if selectedShare > 0 {
                result[exp.category, default: 0] += selectedShare
            }
        }
        return result
    }
    
    /// Category totals for a single member (their share per category).
    func categoryTotals(memberId: String, currency: Currency) -> [ExpenseCategory: Double] {
        var result: [ExpenseCategory: Double] = [:]
        for exp in expenses where exp.currency == currency {
            if let share = exp.splits[memberId], share > 0 {
                result[exp.category, default: 0] += share
            }
        }
        return result
    }

    /// Category totals for multiple members combined.
    func categoryTotals(memberIds: Set<String>, currency: Currency) -> [ExpenseCategory: Double] {
        var result: [ExpenseCategory: Double] = [:]
        for id in memberIds {
            let cat = categoryTotals(memberId: id, currency: currency)
            for (k, v) in cat {
                result[k, default: 0] += v
            }
        }
        return result
    }

    /// Total spent by the given members combined.
    func totalSpent(memberIds: Set<String>, currency: Currency) -> Double {
        memberIds.reduce(0) { $0 + memberTotal(memberId: $1, currency: currency) }
    }
    
    // MARK: - Persistence
    
    private func load() {
        let decoder = JSONDecoder()
        if let data = UserDefaults.standard.data(forKey: membersKey),
           let decoded = try? decoder.decode([Member].self, from: data) {
            members = decoded
        }
        if let data = UserDefaults.standard.data(forKey: expensesKey),
           let decoded = try? decoder.decode([Expense].self, from: data) {
            expenses = decoded
        }
        if let ids = UserDefaults.standard.stringArray(forKey: selectedKey), !ids.isEmpty {
            let memberIds = Set(members.map(\.id))
            selectedMemberIds = Set(ids.filter { memberIds.contains($0) })
            if selectedMemberIds.isEmpty && !members.isEmpty {
                selectedMemberIds = memberIds
            }
        }
        if let ids = UserDefaults.standard.stringArray(forKey: settledKey) {
            let memberIds = Set(members.map(\.id))
            settledMemberIds = Set(ids.filter { memberIds.contains($0) })
        }
        if let data = UserDefaults.standard.data(forKey: settlementPaymentsKey),
           let decoded = try? JSONDecoder().decode([SettlementPayment].self, from: data) {
            settlementPayments = decoded
        }
        if let data = UserDefaults.standard.data(forKey: paidExpenseMarksKey),
           let decoded = try? JSONDecoder().decode([PaidExpenseMark].self, from: data) {
            paidExpenseMarks = decoded
        }
    }
    
    private func save() {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(members) {
            UserDefaults.standard.set(data, forKey: membersKey)
        }
        if let data = try? encoder.encode(expenses) {
            UserDefaults.standard.set(data, forKey: expensesKey)
        }
        UserDefaults.standard.set(Array(selectedMemberIds), forKey: selectedKey)
        UserDefaults.standard.set(Array(settledMemberIds), forKey: settledKey)
        if let data = try? JSONEncoder().encode(settlementPayments) {
            UserDefaults.standard.set(data, forKey: settlementPaymentsKey)
        }
        if let data = try? JSONEncoder().encode(paidExpenseMarks) {
            UserDefaults.standard.set(data, forKey: paidExpenseMarksKey)
        }
    }
}
