//
//  ExpensesListView.swift
//  BudgetSplitter
//

import SwiftUI

struct ExpensesListView: View {
    @EnvironmentObject var dataStore: BudgetDataStore
    
    private func formatMoney(_ amount: Double, _ currency: Currency) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = currency.decimals
        formatter.minimumFractionDigits = currency.decimals
        let str = formatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
        return "\(currency.symbol)\(str)"
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    // Header card
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Expenses")
                            .font(.headline.bold())
                            .foregroundColor(.appPrimary)
                        Text("\(dataStore.expenses.count) expenses recorded")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.appCard)
                    .cornerRadius(12)
                    
                    // Expense list
                    let sortedExpenses = dataStore.expenses.sorted(by: { $0.date > $1.date })
                    VStack(spacing: 0) {
                        ForEach(Array(sortedExpenses.enumerated()), id: \.element.id) { index, exp in
                            HStack(alignment: .top, spacing: 12) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(exp.description.isEmpty ? exp.category.rawValue : exp.description)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.appPrimary)
                                        .lineLimit(1)
                                    HStack(spacing: 4) {
                                        Text(exp.date.formatted(date: .abbreviated, time: .omitted))
                                        Text("•")
                                        Text(dataStore.members.first(where: { $0.id == exp.paidByMemberId })?.name ?? "—")
                                        Text("•")
                                        Text(exp.category.rawValue)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.appTertiary)
                                            .cornerRadius(8)
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundColor(.secondary)
                                    }
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                }
                                Spacer()
                                Text(formatMoney(exp.amount, exp.currency))
                                    .font(.subheadline.bold())
                                    .foregroundColor(.green)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color.appCard)
                            .overlay(
                                Group {
                                    if index < sortedExpenses.count - 1 {
                                        Rectangle()
                                            .frame(height: 0.5)
                                            .foregroundColor(Color.appSeparator)
                                    }
                                },
                                alignment: .bottom
                            )
                        }
                    }
                    .background(Color.appCard)
                    .cornerRadius(12)
                }
                .padding()
            }
            .background(Color.appBackground)
            .navigationTitle("💰 Budget Splitter")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Text("🌐 EN")
                        .foregroundColor(Color(red: 10/255, green: 132/255, blue: 1))
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    ExpensesListView()
        .environmentObject(BudgetDataStore())
}
