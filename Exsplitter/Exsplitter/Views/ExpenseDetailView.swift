//
//  ExpenseDetailView.swift
//  Exsplitter
//
//  Shows how an expense is split per person (equal vs custom/random).
//

import SwiftUI

struct ExpenseDetailView: View {
    let expense: Expense
    @EnvironmentObject var dataStore: BudgetDataStore
    
    /// Members for the trip this expense belongs to (or global when no trip). Used for payer/split names.
    private var detailMembers: [Member] { dataStore.members(for: expense.eventId) }
    
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
        let amounts = expense.splitMemberIds.compactMap { expense.splits[$0] }
        guard !amounts.isEmpty, let first = amounts.first else { return true }
        let tolerance = expense.currency == .JPY ? 1.0 : 0.01
        return amounts.allSatisfy { abs($0 - first) <= tolerance }
    }
    
    /// Per-person amount when equal; nil if not equal.
    private var equalAmountPerPerson: Double? {
        guard isEqualSplit else { return nil }
        let amounts = expense.splitMemberIds.compactMap { expense.splits[$0] }
        return amounts.first
    }
    
    /// When payer is not in split and remainder was randomly assigned: base amount and who has +1 (or +0.01) extra.
    private var randomExtraNote: (base: Double, extraMemberIds: [String])? {
        guard expense.paidByMemberId != "",
              !expense.splitMemberIds.contains(expense.paidByMemberId) else { return nil }
        let amounts = expense.splitMemberIds.compactMap { expense.splits[$0] }
        guard !amounts.isEmpty else { return nil }
        let minAmt = amounts.min() ?? 0
        let maxAmt = amounts.max() ?? 0
        let unit = expense.currency == .JPY ? 1.0 : 0.01
        guard maxAmt > minAmt, maxAmt - minAmt <= unit else { return nil }
        var extra: [String] = []
        for id in expense.splitMemberIds {
            guard let a = expense.splits[id], a > minAmt else { continue }
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
                    Text(expense.description.isEmpty ? expense.category.rawValue : expense.description)
                        .font(.title2.bold())
                        .foregroundColor(.appPrimary)
                    HStack(spacing: 6) {
                        Text(expense.date.formatted(date: .abbreviated, time: .omitted))
                        Text("•")
                        Text("Paid by \(memberName(id: expense.paidByMemberId))")
                        Text("•")
                        Text(expense.category.rawValue)
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    Text(formatMoney(expense.amount, expense.currency))
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
                    Text("Split")
                        .font(.headline.bold())
                        .foregroundColor(.appPrimary)
                    
                    if let random = randomExtraNote {
                        Text("Split (random extra assigned)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("Amount couldn’t be split equally; remainder assigned randomly.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        ForEach(expense.splitMemberIds, id: \.self) { id in
                            let amount = expense.splits[id] ?? 0
                            let hasExtra = random.extraMemberIds.contains(id)
                            HStack {
                                Text(memberName(id: id))
                                    .font(.subheadline)
                                    .foregroundColor(.appPrimary)
                                if hasExtra {
                                    Text("(random +\(expense.currency == .JPY ? "1" : "0.01"))")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                                Spacer()
                                Text(formatMoney(amount, expense.currency))
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
                        Text("Equally split")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("Each person pays \(formatMoney(perPerson, expense.currency))")
                            .font(.subheadline.bold())
                            .foregroundColor(.appPrimary)
                            .monospacedDigit()
                        ForEach(expense.splitMemberIds, id: \.self) { id in
                            HStack {
                                Text(memberName(id: id))
                                    .font(.subheadline)
                                    .foregroundColor(.appPrimary)
                                Spacer()
                                Text(formatMoney(perPerson, expense.currency))
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
                        Text("Custom split")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        ForEach(expense.splitMemberIds, id: \.self) { id in
                            let amount = expense.splits[id] ?? 0
                            HStack {
                                Text(memberName(id: id))
                                    .font(.subheadline)
                                    .foregroundColor(.appPrimary)
                                Spacer()
                                Text(formatMoney(amount, expense.currency))
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
                    
                    if expense.paidByMemberId != "" && !expense.splitMemberIds.contains(expense.paidByMemberId) {
                        Text("Paid by \(memberName(id: expense.paidByMemberId)) is not in the split.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                        if let earned = expense.payerEarned, earned > 0 {
                            Text("Payer earns \(formatMoney(earned, expense.currency)) (everyone paid a bit more).")
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
        .navigationTitle("Expense detail")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                BackToTripsButton()
                    .environmentObject(dataStore)
            }
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
