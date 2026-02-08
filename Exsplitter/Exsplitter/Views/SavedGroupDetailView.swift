//
//  SavedGroupDetailView.swift
//  Xsplitter
//
//  Detail view for a saved group: members, overview, and expenses snapshot.
//

import SwiftUI

struct SavedGroupDetailView: View {
    let group: SavedMemberGroup
    @ObservedObject private var languageStore = LanguageStore.shared

    private var memberCount: Int { group.displayMemberNames.count }
    private var expensesSnapshot: [Expense] { group.expenses ?? [] }
    private var hasExpenses: Bool { !expensesSnapshot.isEmpty }

    private var totalSpentByCurrency: [Currency: Double] {
        var result: [Currency: Double] = [:]
        for exp in expensesSnapshot {
            result[exp.currency, default: 0] += exp.amount
        }
        return result
    }

    private var grandTotal: Double {
        totalSpentByCurrency.values.reduce(0, +)
    }

    private var averagePerPerson: Double {
        guard memberCount > 0 else { return 0 }
        return grandTotal / Double(memberCount)
    }

    private var categoryTotals: [ExpenseCategory: Double] {
        var result: [ExpenseCategory: Double] = [:]
        for exp in expensesSnapshot {
            result[exp.category, default: 0] += exp.amount
        }
        return result
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Members
                VStack(alignment: .leading, spacing: 10) {
                    Text(L10n.string("tab.members", language: languageStore.language))
                        .font(.headline.bold())
                        .foregroundColor(.appPrimary)
                    FlowLayoutForNames(names: group.displayMemberNames)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.appCard)
                .cornerRadius(14)

                if hasExpenses {
                    // Overview
                    VStack(alignment: .leading, spacing: 10) {
                        Text(L10n.string("savedGroup.overview", language: languageStore.language))
                            .font(.headline.bold())
                            .foregroundColor(.appPrimary)
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            StatCard(
                                title: L10n.string("savedGroup.totalExpenses", language: languageStore.language),
                                value: "\(expensesSnapshot.count)",
                                subtitle: L10n.string("savedGroup.recorded", language: languageStore.language),
                                color: .blue
                            )
                            StatCard(
                                title: L10n.string("savedGroup.totalSpent", language: languageStore.language),
                                value: formatTotal(grandTotal),
                                subtitle: L10n.string("savedGroup.allMembers", language: languageStore.language),
                                color: .green
                            )
                            StatCard(
                                title: L10n.string("savedGroup.perPerson", language: languageStore.language),
                                value: formatTotal(averagePerPerson),
                                subtitle: L10n.string("savedGroup.average", language: languageStore.language),
                                color: .orange
                            )
                            StatCard(
                                title: L10n.string("tab.members", language: languageStore.language),
                                value: "\(memberCount)",
                                subtitle: L10n.string("savedGroup.inGroup", language: languageStore.language),
                                color: .purple
                            )
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.appCard)
                    .cornerRadius(14)

                    // By category (JPY or first currency)
                    if !categoryTotals.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(L10n.string("savedGroup.spendingByCategory", language: languageStore.language))
                                .font(.headline.bold())
                                .foregroundColor(.appPrimary)
                            ForEach(Array(categoryTotals.sorted(by: { $0.value > $1.value })), id: \.key) { category, amount in
                                HStack {
                                    Image(systemName: category.icon)
                                        .foregroundColor(.orange)
                                    Text(category.rawValue)
                                        .font(.subheadline)
                                        .foregroundColor(.appPrimary)
                                    Spacer()
                                    Text(formatMoney(amount, .JPY))
                                        .font(.subheadline.bold())
                                        .foregroundColor(.appPrimary)
                                        .monospacedDigit()
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.appCard)
                        .cornerRadius(14)
                    }

                    // Expenses list
                    VStack(alignment: .leading, spacing: 10) {
                        Text(L10n.string("tab.expenses", language: languageStore.language))
                            .font(.headline.bold())
                            .foregroundColor(.appPrimary)
                        ForEach(expensesSnapshot.sorted(by: { $0.date > $1.date })) { exp in
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(exp.description.isEmpty ? exp.category.rawValue : exp.description)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.appPrimary)
                                        .lineLimit(1)
                                    Text("\(exp.date.formatted(date: .abbreviated, time: .omitted)) • \(group.memberName(id: exp.paidByMemberId))")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Text(formatMoney(exp.amount, exp.currency))
                                    .font(.subheadline.bold())
                                    .foregroundColor(.green)
                                    .monospacedDigit()
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(Color.appTertiary)
                            .cornerRadius(10)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.appCard)
                    .cornerRadius(14)
                } else {
                    Text(L10n.string("savedGroup.noExpenseSnapshot", language: languageStore.language))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.appCard)
                        .cornerRadius(14)
                }
            }
            .padding()
        }
        .background(Color.appBackground)
        .navigationTitle(group.label)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func formatTotal(_ value: Double) -> String {
        "¥\(Int(value).formatted())"
    }

    private func formatMoney(_ amount: Double, _ currency: Currency) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = currency.decimals
        formatter.minimumFractionDigits = currency.decimals
        let str = formatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
        return "\(currency.symbol)\(str)"
    }
}

/// Simple horizontal flow of name pills for the detail view.
private struct FlowLayoutForNames: View {
    let names: [String]

    var body: some View {
        FlowLayout(spacing: 6) {
            ForEach(names, id: \.self) { name in
                Text(name)
                    .font(.caption)
                    .foregroundColor(.appPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.appTertiary)
                    .cornerRadius(14)
            }
        }
    }
}
