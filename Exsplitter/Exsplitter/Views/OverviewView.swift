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
            VStack(spacing: 20) {
                // Trip detail link when viewing a trip
                if let event = event {
                    NavigationLink {
                        EventDetailView(event: event)
                            .environmentObject(dataStore)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "map.fill")
                                .font(.title3)
                                .foregroundColor(.appAccent)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(L10n.string("events.tripDetails", language: languageStore.language))
                                    .font(AppFonts.cardTitle)
                                    .foregroundColor(.appPrimary)
                                Text(event.name)
                                    .font(.subheadline)
                                    .foregroundColor(.appSecondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.appSecondary)
                        }
                        .padding(16)
                        .background(Color.appCard)
                        .cornerRadius(14)
                    }
                    .buttonStyle(.plain)
                }

                // Stats
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "chart.bar.doc.horizontal.fill")
                            .font(.title3)
                            .foregroundColor(.appAccent)
                        Text(L10n.string("overview.title", language: languageStore.language))
                            .font(AppFonts.sectionHeader)
                            .foregroundColor(.appPrimary)
                    }
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        StatCard(
                            title: L10n.string("overview.totalExpenses", language: languageStore.language),
                            value: "\(contextExpenses.count)",
                            subtitle: L10n.string("overview.recorded", language: languageStore.language),
                            color: .appAccent
                        )
                        StatCard(
                            title: L10n.string("overview.totalSpent", language: languageStore.language),
                            value: formatMoney(grandTotal, .JPY),
                            subtitle: L10n.string("overview.allMembers", language: languageStore.language),
                            color: Color.green
                        )
                        StatCard(
                            title: L10n.string("overview.perPerson", language: languageStore.language),
                            value: formatMoney(averagePerPerson, .JPY),
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
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.appCard)
                .cornerRadius(14)

                // Quick actions
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "bolt.circle.fill")
                            .font(.title3)
                            .foregroundColor(.appAccent)
                        Text(L10n.string("overview.quickActions", language: languageStore.language))
                            .font(AppFonts.sectionHeader)
                            .foregroundColor(.appPrimary)
                    }
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        QuickActionButton(icon: "plus.circle.fill", label: L10n.string("overview.addExpense", language: languageStore.language)) {
                            onShowAddExpense?()
                        }
                        QuickActionButton(icon: "chart.pie.fill", label: L10n.string("overview.summary", language: languageStore.language)) {
                            onShowSummary?()
                        }
                        QuickActionButton(icon: "arrow.left.arrow.right", label: L10n.string("tab.settleUp", language: languageStore.language)) {
                            onSelectTab?(2)
                        }
                        QuickActionButton(icon: "person.2.fill", label: L10n.string("overview.editMembers", language: languageStore.language)) {
                            onSelectTab?(3)
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.appCard)
                .cornerRadius(14)

                // Recent activity
                if !contextExpenses.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.title3)
                                .foregroundColor(.appAccent)
                            Text(L10n.string("overview.recentActivity", language: languageStore.language))
                                .font(AppFonts.sectionHeader)
                                .foregroundColor(.appPrimary)
                        }
                        VStack(spacing: 8) {
                            ForEach(contextExpenses.suffix(5).reversed()) { exp in
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(exp.description.isEmpty ? exp.category.rawValue : exp.description)
                                            .font(.subheadline)
                                            .foregroundColor(.appPrimary)
                                            .lineLimit(1)
                                        Text("\(exp.date.formatted(date: .abbreviated, time: .omitted)) · \(contextMembers.first(where: { $0.id == exp.paidByMemberId })?.name ?? "—")")
                                            .font(.caption)
                                            .foregroundColor(.appSecondary)
                                    }
                                    Spacer()
                                    Text(formatMoney(exp.amount, exp.currency))
                                        .font(.subheadline.bold())
                                        .foregroundColor(.appPrimary)
                                        .monospacedDigit()
                                }
                                .padding(12)
                                .background(Color.appTertiary)
                                .cornerRadius(10)
                            }
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.appCard)
                    .cornerRadius(14)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .background(Color.appBackground)
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                BackToTripsButton()
                    .environmentObject(dataStore)
            }
            ToolbarItem(placement: .principal) {
                Text(navigationTitle)
                    .font(AppFonts.tripTitle)
                    .foregroundColor(.primary)
            }
        }
        // Don't set dataStore.selectedEvent here — it overwrites after Home tap and flips back to trip.
        // Selection is set by RootView.onSelectTrip when opening from list, and by restore at launch.
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
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundColor(.white.opacity(0.9))
            Text(value)
                .font(.title3.bold())
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.85))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            LinearGradient(
                colors: [color, color.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(12)
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
            VStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.appAccent)
                Text(label)
                    .font(.caption.bold())
                    .foregroundColor(.appPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.appTertiary)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    OverviewView()
        .environmentObject(BudgetDataStore())
}
