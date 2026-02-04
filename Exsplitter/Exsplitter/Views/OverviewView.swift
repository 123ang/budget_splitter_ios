//
//  OverviewView.swift
//  BudgetSplitter
//

import SwiftUI

struct OverviewView: View {
    @EnvironmentObject var dataStore: BudgetDataStore
    var onSelectTab: ((Int) -> Void)? = nil
    var onShowSummary: (() -> Void)? = nil
    
    private var grandTotal: Double {
        dataStore.totalSpentByCurrency.values.reduce(0, +)
    }
    
    private var averagePerPerson: Double {
        guard !dataStore.members.isEmpty else { return 0 }
        return grandTotal / Double(dataStore.members.count)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Stats grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        StatCard(
                            title: "Total Expenses",
                            value: "\(dataStore.totalExpenseCount)",
                            subtitle: "recorded",
                            color: .blue
                        )
                        StatCard(
                            title: "Total Spent",
                            value: "¥\(Int(grandTotal).formatted())",
                            subtitle: "all members",
                            color: .green
                        )
                        StatCard(
                            title: "Per Person",
                            value: "¥\(Int(averagePerPerson).formatted())",
                            subtitle: "average",
                            color: .orange
                        )
                        StatCard(
                            title: "Members",
                            value: "\(dataStore.members.count)",
                            subtitle: "in group",
                            color: .purple
                        )
                    }
                    
                    // Quick actions
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Quick Actions")
                            .font(.headline)
                            .foregroundColor(.appPrimary)
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            QuickActionButton(icon: "plus.circle", label: "Add Expense") {
                                onSelectTab?(1)
                            }
                            QuickActionButton(icon: "list.bullet", label: "View All") {
                                onSelectTab?(2)
                            }
                            QuickActionButton(icon: "person.2", label: "Members") {
                                onSelectTab?(3)
                            }
                            QuickActionButton(icon: "chart.bar", label: "Summary") {
                                onShowSummary?()
                            }
                        }
                    }
                    .padding()
                    .background(Color.appCard)
                    .cornerRadius(14)
                    
                    // Category breakdown (JPY)
                    if !dataStore.categoryTotals(currency: .JPY).isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Spending by Category")
                                .font(.headline)
                                .foregroundColor(.appPrimary)
                            
                            ForEach(Array(dataStore.categoryTotals(currency: .JPY).sorted(by: { $0.value > $1.value })), id: \.key) { category, amount in
                                HStack {
                                    Image(systemName: category.icon)
                                        .foregroundColor(.orange)
                                    Text(category.rawValue)
                                        .font(.subheadline)
                                        .foregroundColor(.appPrimary)
                                    Spacer()
                                    Text("¥\(Int(amount).formatted())")
                                        .font(.subheadline.bold())
                                        .foregroundColor(.appPrimary)
                                }
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(Color.appSeparator)
                                            .frame(height: 6)
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(categoryColor(category))
                                            .frame(width: grandTotal > 0 ? geo.size.width * (amount / grandTotal) : 0, height: 6)
                                    }
                                }
                                .frame(height: 6)
                            }
                        }
                        .padding()
                        .background(Color.appCard)
                        .cornerRadius(14)
                    }
                    
                    // Recent activity
                    if !dataStore.expenses.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Recent Activity")
                                .font(.headline)
                                .foregroundColor(.appPrimary)
                            
                            ForEach(dataStore.expenses.suffix(5).reversed()) { exp in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(exp.description.isEmpty ? exp.category.rawValue : exp.description)
                                            .font(.subheadline)
                                            .foregroundColor(.appPrimary)
                                            .lineLimit(1)
                                        Text("\(exp.date.formatted(date: .abbreviated, time: .omitted)) • \(dataStore.members.first(where: { $0.id == exp.paidByMemberId })?.name ?? "—")")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Text(formatMoney(exp.amount, exp.currency))
                                        .font(.subheadline.bold())
                                        .foregroundColor(.green)
                                }
                                .padding(.vertical, 6)
                            }
                        }
                        .padding()
                        .background(Color.appCard)
                        .cornerRadius(14)
                    }
                }
                .padding()
            }
            .background(Color.appBackground)
            .navigationTitle("💰 Budget Splitter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Text("🌐 EN")
                        .foregroundColor(Color(red: 10/255, green: 132/255, blue: 1))
                }
            }
        }
    }
    
    private func categoryColor(_ category: ExpenseCategory) -> Color {
        switch category {
        case .meal: return .orange
        case .transport: return .blue
        case .tickets: return .purple
        case .shopping: return .pink
        case .hotel: return .cyan
        case .other: return .gray
        }
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

struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.white.opacity(0.9))
            Text(value)
                .font(.title2.bold())
                .foregroundColor(.white)
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.85))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            LinearGradient(
                colors: [color, color.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(14)
    }
}

struct QuickActionButton: View {
    let icon: String
    let label: String
    var action: (() -> Void)?
    
    var body: some View {
        Button {
            action?()
        } label: {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title2)
                Text(label)
                    .font(.caption2.bold())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.appTertiary)
            .foregroundColor(.appPrimary)
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    OverviewView()
        .environmentObject(BudgetDataStore())
}
