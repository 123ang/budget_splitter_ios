//
//  SavedGroupDetailView.swift
//  Exsplitter
//
//  Detail view for a saved group: members, overview, and expenses snapshot.
//

import SwiftUI

struct SavedGroupDetailView: View {
    let group: SavedMemberGroup

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
                    Text("Members")
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
                        Text("Overview")
                            .font(.headline.bold())
                            .foregroundColor(.appPrimary)
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            StatCard(
                                title: "Total Expenses",
                                value: "\(expensesSnapshot.count)",
                                subtitle: "recorded",
                                color: .blue
                            )
                            StatCard(
                                title: "Total Spent",
                                value: formatTotal(grandTotal),
                                subtitle: "all members",
                                color: .green
                            )
                            StatCard(
                                title: "Per Person",
                                value: formatTotal(averagePerPerson),
                                subtitle: "average",
                                color: .orange
                            )
                            StatCard(
                                title: "Members",
                                value: "\(memberCount)",
                                subtitle: "in group",
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
                            Text("Spending by Category")
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
                        Text("Expenses")
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
                    Text("No expense snapshot saved for this group.")
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
