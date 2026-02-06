//
//  OverviewView.swift
//  BudgetSplitter
//

import SwiftUI

struct OverviewView: View {
    @EnvironmentObject var dataStore: BudgetDataStore
    @ObservedObject private var languageStore = LanguageStore.shared
    /// When set, stats and recent activity are filtered to this trip. Nil = show global (e.g. when used without trip context).
    var event: Event? = nil
    var onSelectTab: ((Int) -> Void)? = nil
    var onShowSummary: (() -> Void)? = nil
    var onShowAddExpense: (() -> Void)? = nil
    
    /// Expenses for the current context (this trip or all), respecting event's member and currency filters.
    private var contextExpenses: [Expense] {
        if let event = event {
            return dataStore.filteredExpenses(for: event)
        }
        return dataStore.expenses
    }
    
    private var grandTotal: Double {
        if event != nil {
            return dataStore.totalSpent(for: event!.id, currency: .JPY)
        }
        return dataStore.totalSpentByCurrency.values.reduce(0, +)
    }
    
    /// Members for the current context (this trip or global).
    private var contextMembers: [Member] { dataStore.members(for: event?.id) }
    
    private var averagePerPerson: Double {
        guard !contextMembers.isEmpty else { return 0 }
        return grandTotal / Double(contextMembers.count)
    }
    
    private var navigationTitle: String {
        if let event = event {
            return event.name
        }
        return "💰 \(L10n.string("members.navTitle", language: languageStore.language))"
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Trip detail link when viewing a trip
                if let event = event {
                    NavigationLink {
                        EventDetailView(event: event)
                            .environmentObject(dataStore)
                    } label: {
                        HStack {
                            Image(systemName: "map.fill")
                                .foregroundColor(.blue)
                            Text(L10n.string("events.tripDetails", language: languageStore.language))
                                .font(.subheadline.bold())
                                .foregroundColor(.appPrimary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.bold())
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color.appTertiary)
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
                
                // Stats grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    StatCard(
                        title: L10n.string("overview.totalExpenses", language: languageStore.language),
                        value: "\(contextExpenses.count)",
                        subtitle: L10n.string("overview.recorded", language: languageStore.language),
                        color: .blue
                    )
                    StatCard(
                        title: L10n.string("overview.totalSpent", language: languageStore.language),
                        value: "¥\(Int(grandTotal).formatted())",
                        subtitle: L10n.string("overview.allMembers", language: languageStore.language),
                        color: .green
                    )
                    StatCard(
                        title: L10n.string("overview.perPerson", language: languageStore.language),
                        value: "¥\(Int(averagePerPerson).formatted())",
                        subtitle: L10n.string("overview.average", language: languageStore.language),
                        color: .orange
                    )
                    StatCard(
                        title: L10n.string("overview.members", language: languageStore.language),
                        value: "\(contextMembers.count)",
                        subtitle: L10n.string("overview.inGroup", language: languageStore.language),
                        color: .purple
                    )
                }
                
                // Quick actions
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.string("overview.quickActions", language: languageStore.language))
                        .font(.headline)
                        .foregroundColor(.appPrimary)
                    
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        QuickActionButton(icon: "plus.circle", label: L10n.string("overview.addExpense", language: languageStore.language)) {
                            onShowAddExpense?()
                        }
                        QuickActionButton(icon: "chart.bar", label: L10n.string("overview.summary", language: languageStore.language)) {
                            onShowSummary?()
                        }
                        QuickActionButton(icon: "arrow.left.arrow.right", label: L10n.string("tab.settleUp", language: languageStore.language)) {
                            onSelectTab?(2)
                        }
                        QuickActionButton(icon: "person.2", label: L10n.string("overview.editMembers", language: languageStore.language)) {
                            onSelectTab?(3)
                        }
                    }
                }
                .padding()
                .background(Color.appCard)
                .cornerRadius(14)
                
                // Recent activity (for this trip or all)
                if !contextExpenses.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.string("overview.recentActivity", language: languageStore.language))
                            .font(.headline)
                            .foregroundColor(.appPrimary)
                        
                        ForEach(contextExpenses.suffix(5).reversed()) { exp in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(exp.description.isEmpty ? exp.category.rawValue : exp.description)
                                        .font(.subheadline)
                                        .foregroundColor(.appPrimary)
                                        .lineLimit(1)
                                    Text("\(exp.date.formatted(date: .abbreviated, time: .omitted)) • \(contextMembers.first(where: { $0.id == exp.paidByMemberId })?.name ?? "—")")
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
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let event = event {
                dataStore.selectedEvent = event
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
