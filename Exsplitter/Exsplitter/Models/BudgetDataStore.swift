//
//  BudgetDataStore.swift
//  BudgetSplitter
//

import Foundation
import SwiftUI

final class BudgetDataStore: ObservableObject {
    @Published var members: [Member] = []
    @Published var expenses: [Expense] = []
    @Published var selectedMemberIds: Set<String> = []
    
    private let membersKey = "BudgetSplitter_members"
    private let expensesKey = "BudgetSplitter_expenses"
    private let selectedKey = "BudgetSplitter_selected"
    
    static let defaultMemberNames = [
        "Soon Zheng Dong", "Soon Cheng Wai", "Soon Xin Yi", "See Siew Pheng",
        "Ang Shin Nee", "See Siew Tin", "See Siew Kim", "See Eng Kim",
        "See Yi Joe", "Koay Jun Ming"
    ]
    
    init() {
        load()
        if members.isEmpty {
            members = Self.defaultMemberNames.map { Member(name: $0) }
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
        members.removeAll { $0.id == id }
        selectedMemberIds.remove(id)
        expenses = expenses.map { exp in
            var e = exp
            e.splits.removeValue(forKey: id)
            e.splitMemberIds.removeAll { $0 == id }
            if e.paidByMemberId == id, let first = members.first?.id {
                e.paidByMemberId = first
            }
            return e
        }
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
    
    func resetAll() {
        members = Self.defaultMemberNames.map { Member(name: $0) }
        expenses = []
        selectedMemberIds = Set(members.map(\.id))
        save()
    }
    
    func toggleSelected(memberId: String) {
        if selectedMemberIds.contains(memberId) {
            selectedMemberIds.remove(memberId)
        } else {
            selectedMemberIds.insert(memberId)
        }
        save()
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
    
    // MARK: - Persistence
    
    private func load() {
        if let data = UserDefaults.standard.data(forKey: membersKey),
           let decoded = try? JSONDecoder().decode([Member].self, from: data) {
            members = decoded
        }
        if let data = UserDefaults.standard.data(forKey: expensesKey),
           let decoded = try? JSONDecoder().decode([Expense].self, from: data) {
            expenses = decoded
        }
        if let ids = UserDefaults.standard.stringArray(forKey: selectedKey) {
            selectedMemberIds = Set(ids)
        }
    }
    
    private func save() {
        if let data = try? JSONEncoder().encode(members) {
            UserDefaults.standard.set(data, forKey: membersKey)
        }
        if let data = try? JSONEncoder().encode(expenses) {
            UserDefaults.standard.set(data, forKey: expensesKey)
        }
        UserDefaults.standard.set(Array(selectedMemberIds), forKey: selectedKey)
    }
}
