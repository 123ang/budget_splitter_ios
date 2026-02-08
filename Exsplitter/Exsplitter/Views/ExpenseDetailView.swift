//
//  ExpenseDetailView.swift
//  Xsplitter
//
//  Shows how an expense is split per person (equal vs custom/random).
//

import SwiftUI

struct ExpenseDetailView: View {
    let expense: Expense
    @EnvironmentObject var dataStore: BudgetDataStore
    @ObservedObject private var languageStore = LanguageStore.shared
    @State private var showEditExpenseSheet = false
    
    /// Live expense from store so the detail updates after edit.
    private var currentExpense: Expense { dataStore.expenses.first(where: { $0.id == expense.id }) ?? expense }
    
    /// Members for the trip this expense belongs to (or global when no trip). Used for payer/split names.
    private var detailMembers: [Member] { dataStore.members(for: currentExpense.eventId) }
    
    private func categoryLabel(_ category: ExpenseCategory) -> String {
        L10n.string("category.\(category.rawValue)", language: languageStore.language)
    }
    
    private func formatMoney(_ amount: Double, _ currency: Currency) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = currency.decimals
        formatter.minimumFractionDigits = currency.decimals
        let str = formatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
        return "\(currency.symbol)\(str)"
    }
    
    private func memberName(id: String) -> String {
        detailMembers.first(where: { $0.id == id })?.name ?? "—"
    }
    
    /// All amounts the same (or within 1 for JPY) → equal split.
    private var isEqualSplit: Bool {
        let amounts = currentExpense.splitMemberIds.compactMap { currentExpense.splits[$0] }
        guard !amounts.isEmpty, let first = amounts.first else { return true }
        let tolerance = currentExpense.currency == .JPY ? 1.0 : 0.01
        return amounts.allSatisfy { abs($0 - first) <= tolerance }
    }
    
    /// Per-person amount when equal; nil if not equal.
    private var equalAmountPerPerson: Double? {
        guard isEqualSplit else { return nil }
        let amounts = currentExpense.splitMemberIds.compactMap { currentExpense.splits[$0] }
        return amounts.first
    }
    
    /// When payer is not in split and remainder was randomly assigned: base amount and who has +1 (or +0.01) extra.
    private var randomExtraNote: (base: Double, extraMemberIds: [String])? {
        guard currentExpense.paidByMemberId != "",
              !currentExpense.splitMemberIds.contains(currentExpense.paidByMemberId) else { return nil }
        let amounts = currentExpense.splitMemberIds.compactMap { currentExpense.splits[$0] }
        guard !amounts.isEmpty else { return nil }
        let minAmt = amounts.min() ?? 0
        let maxAmt = amounts.max() ?? 0
        let unit = currentExpense.currency == .JPY ? 1.0 : 0.01
        guard maxAmt > minAmt, maxAmt - minAmt <= unit else { return nil }
        var extra: [String] = []
        for id in currentExpense.splitMemberIds {
            guard let a = currentExpense.splits[id], a > minAmt else { continue }
            extra.append(id)
        }
        guard !extra.isEmpty else { return nil }
        return (minAmt, extra)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Summary
                VStack(alignment: .leading, spacing: 8) {
                    Text(currentExpense.description.isEmpty ? categoryLabel(currentExpense.category) : currentExpense.description)
                        .font(.title2.bold())
                        .foregroundColor(.appPrimary)
                    HStack(spacing: 6) {
                        Text(currentExpense.date.formatted(date: .abbreviated, time: .omitted))
                        Text("•")
                        Text(L10n.string("expenseDetail.paidBy", language: languageStore.language).replacingOccurrences(of: "%@", with: memberName(id: currentExpense.paidByMemberId)))
                        Text("•")
                        Text(categoryLabel(currentExpense.category))
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    Text(formatMoney(currentExpense.amount, currentExpense.currency))
                        .font(.title3.bold())
                        .foregroundColor(.green)
                        .monospacedDigit()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.appCard)
                .cornerRadius(12)
                
                // Split
                VStack(alignment: .leading, spacing: 10) {
                    Text(L10n.string("expenseDetail.split", language: languageStore.language))
                        .font(.headline.bold())
                        .foregroundColor(.appPrimary)
                    
                    if let random = randomExtraNote {
                        Text(L10n.string("expenseDetail.splitRandomExtra", language: languageStore.language))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text(L10n.string("expenseDetail.amountCouldntSplit", language: languageStore.language))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        let randomExtraStr = currentExpense.currency == .JPY ? "1" : "0.01"
                        ForEach(currentExpense.splitMemberIds, id: \.self) { id in
                            let amount = currentExpense.splits[id] ?? 0
                            let hasExtra = random.extraMemberIds.contains(id)
                            HStack {
                                Text(memberName(id: id))
                                    .font(.subheadline)
                                    .foregroundColor(.appPrimary)
                                if hasExtra {
                                    Text(L10n.string("expenseDetail.randomPlusOne", language: languageStore.language).replacingOccurrences(of: "%@", with: randomExtraStr))
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                                Spacer()
                                Text(formatMoney(amount, currentExpense.currency))
                                    .font(.subheadline.bold())
                                    .foregroundColor(hasExtra ? .orange : .secondary)
                                    .monospacedDigit()
                            }
                            .padding(.vertical, 4)
                            .padding(.horizontal, 12)
                            .background(Color.appTertiary)
                            .cornerRadius(8)
                        }
                    } else if isEqualSplit, let perPerson = equalAmountPerPerson {
                        Text(L10n.string("expenseDetail.equallySplit", language: languageStore.language))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text(L10n.string("expenseDetail.eachPersonPays", language: languageStore.language).replacingOccurrences(of: "%@", with: formatMoney(perPerson, currentExpense.currency)))
                            .font(.subheadline.bold())
                            .foregroundColor(.appPrimary)
                            .monospacedDigit()
                        ForEach(currentExpense.splitMemberIds, id: \.self) { id in
                            HStack {
                                Text(memberName(id: id))
                                    .font(.subheadline)
                                    .foregroundColor(.appPrimary)
                                Spacer()
                                Text(formatMoney(perPerson, currentExpense.currency))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .monospacedDigit()
                            }
                            .padding(.vertical, 4)
                            .padding(.horizontal, 12)
                            .background(Color.appTertiary)
                            .cornerRadius(8)
                        }
                    } else {
                        Text(L10n.string("expenseDetail.customSplit", language: languageStore.language))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        ForEach(currentExpense.splitMemberIds, id: \.self) { id in
                            let amount = currentExpense.splits[id] ?? 0
                            HStack {
                                Text(memberName(id: id))
                                    .font(.subheadline)
                                    .foregroundColor(.appPrimary)
                                Spacer()
                                Text(formatMoney(amount, currentExpense.currency))
                                    .font(.subheadline.bold())
                                    .foregroundColor(.green)
                                    .monospacedDigit()
                            }
                            .padding(.vertical, 4)
                            .padding(.horizontal, 12)
                            .background(Color.appTertiary)
                            .cornerRadius(8)
                        }
                    }
                    
                    if currentExpense.paidByMemberId != "" && !currentExpense.splitMemberIds.contains(currentExpense.paidByMemberId) {
                        Text(L10n.string("expenseDetail.paidByNotInSplit", language: languageStore.language).replacingOccurrences(of: "%@", with: memberName(id: currentExpense.paidByMemberId)))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                        if let earned = currentExpense.payerEarned, earned > 0 {
                            Text(L10n.string("expenseDetail.payerEarns", language: languageStore.language).replacingOccurrences(of: "%@", with: formatMoney(earned, currentExpense.currency)))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.appCard)
                .cornerRadius(12)
            }
            .padding()
        }
        .background(Color.appBackground)
        .navigationTitle(L10n.string("expenseDetail.title", language: languageStore.language))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                BackToTripsButton()
                    .environmentObject(dataStore)
            }
            ToolbarItem(placement: .primaryAction) {
                Button(L10n.string("events.editEvent", language: languageStore.language)) {
                    if let eid = currentExpense.eventId, let ev = dataStore.events.first(where: { $0.id == eid }) {
                        dataStore.selectedEvent = ev
                    }
                    showEditExpenseSheet = true
                }
            }
        }
        .sheet(isPresented: $showEditExpenseSheet) {
            AddExpenseView(existingExpense: currentExpense)
                .environmentObject(dataStore)
        }
    }
}

#Preview {
    NavigationStack {
        ExpenseDetailView(expense: Expense(
            description: "Ramen",
            amount: 1000,
            category: .meal,
            paidByMemberId: "a",
            splitMemberIds: ["a", "b", "c"],
            splits: ["a": 334, "b": 333, "c": 333]
        ))
        .environmentObject(BudgetDataStore())
    }
}
