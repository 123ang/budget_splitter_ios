//
//  ExpensesListView.swift
//  BudgetSplitter
//

import SwiftUI

struct ExpensesListView: View {
    @EnvironmentObject var dataStore: BudgetDataStore
    @State private var showAddSheet = false
    
    private func formatMoney(_ amount: Double, _ currency: Currency) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = currency.decimals
        formatter.minimumFractionDigits = currency.decimals
        let str = formatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
        return "\(currency.symbol)\(str)"
    }
    
    private func memberName(id: String) -> String {
        dataStore.members.first(where: { $0.id == id })?.name ?? "—"
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    // Expense list header (title + add button)
                    let sortedExpenses = dataStore.expenses.sorted(by: { $0.date > $1.date })
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Expenses")
                                .font(.headline.bold())
                                .foregroundColor(.appPrimary)
                            Text("\(dataStore.expenses.count) recorded")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Button {
                            showAddSheet = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundColor(Color(red: 10/255, green: 132/255, blue: 1))
                        }
                    }
                    .padding()
                    .background(Color.appCard)
                    .cornerRadius(12)
                    
                    VStack(spacing: 0) {
                        ForEach(Array(sortedExpenses.enumerated()), id: \.element.id) { index, exp in
                            NavigationLink {
                                ExpenseDetailView(expense: exp)
                                    .environmentObject(dataStore)
                            } label: {
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
                                            Text(memberName(id: exp.paidByMemberId))
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
                            }
                            .buttonStyle(.plain)
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
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showAddSheet) {
                NavigationStack {
                    AddExpenseView()
                        .environmentObject(dataStore)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") {
                                    showAddSheet = false
                                }
                                .fontWeight(.semibold)
                                .foregroundColor(Color(red: 10/255, green: 132/255, blue: 1))
                            }
                        }
                }
            }
        }
    }
}

#Preview {
    ExpensesListView()
        .environmentObject(BudgetDataStore())
}
