//
//  ExpensesListView.swift
//  Xsplitter
//

import SwiftUI

struct ExpensesListView: View {
    @EnvironmentObject var dataStore: BudgetDataStore
    @ObservedObject private var languageStore = LanguageStore.shared
    @State private var showAddSheet = false
    @State private var showFilterSheet = false
    @State private var filterCategory: ExpenseCategory? = nil
    @State private var filterDateFrom: Date? = nil
    @State private var filterDateTo: Date? = nil
    @State private var filterMemberIds: Set<String> = []
    
    /// When a trip is selected, list shows only that trip's expenses (with member/currency filters); otherwise all expenses.
    private var contextExpenses: [Expense] {
        if let event = dataStore.selectedEvent {
            return dataStore.filteredExpenses(for: event)
        }
        return dataStore.expenses
    }
    
    private var hasActiveFilters: Bool {
        filterCategory != nil || filterDateFrom != nil || filterDateTo != nil || !filterMemberIds.isEmpty
    }
    
    private var filteredExpenses: [Expense] {
        var list = contextExpenses
        if let cat = filterCategory {
            list = list.filter { $0.category == cat }
        }
        if let from = filterDateFrom {
            let start = Calendar.current.startOfDay(for: from)
            list = list.filter { $0.date >= start }
        }
        if let to = filterDateTo {
            var end = Calendar.current.startOfDay(for: to)
            end = Calendar.current.date(byAdding: .day, value: 1, to: end) ?? end
            list = list.filter { $0.date < end }
        }
        if !filterMemberIds.isEmpty {
            list = list.filter { exp in
                filterMemberIds.contains(exp.paidByMemberId) ||
                exp.splitMemberIds.contains(where: { filterMemberIds.contains($0) })
            }
        }
        return list
    }
    
    /// Members for the current trip (or global when no trip). Used for display names and filter list.
    private var contextMembers: [Member] { dataStore.members(for: dataStore.selectedEvent?.id) }
    
    private func formatMoney(_ amount: Double, _ currency: Currency) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = currency.decimals
        formatter.minimumFractionDigits = currency.decimals
        let str = formatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
        return "\(currency.symbol)\(str)"
    }
    
    private func memberName(id: String) -> String {
        contextMembers.first(where: { $0.id == id })?.name ?? "—"
    }
    
    private func categoryLabel(_ category: ExpenseCategory) -> String {
        L10n.string("category.\(category.rawValue)", language: languageStore.language)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                let sortedExpenses = filteredExpenses.sorted(by: { $0.date > $1.date })
                // Summary card
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "list.bullet.rectangle.fill")
                            .font(.title3)
                            .foregroundColor(.appAccent)
                        Text(L10n.string("tab.expenses", language: languageStore.language))
                            .font(AppFonts.sectionHeader)
                            .foregroundColor(.appPrimary)
                        Spacer()
                        HStack(spacing: 16) {
                            Button {
                                showFilterSheet = true
                            } label: {
                                ZStack(alignment: .topTrailing) {
                                    Image(systemName: "line.3.horizontal.decrease.circle")
                                        .font(.title2)
                                        .foregroundColor(hasActiveFilters ? Color.appAccent : .secondary)
                                    if hasActiveFilters {
                                        Circle()
                                            .fill(Color.appAccent)
                                            .frame(width: 6, height: 6)
                                            .offset(x: 2, y: -2)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            Button {
                                showAddSheet = true
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(Color.appAccent)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    HStack(spacing: 6) {
                        if let trip = dataStore.selectedEvent {
                            Text(trip.name)
                                .font(.subheadline)
                                .foregroundColor(.appSecondary)
                            Text("·")
                                .foregroundColor(.appSecondary)
                        }
                        Text(String(format: L10n.string("expenses.recordedCount", language: languageStore.language), sortedExpenses.count, contextExpenses.count))
                            .font(.subheadline)
                            .foregroundColor(.appSecondary)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.appCard)
                .cornerRadius(14)

                // Expense cards
                if sortedExpenses.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "tray")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary.opacity(0.6))
                        Text(L10n.string("overview.noExpensesYet", language: languageStore.language))
                            .font(.subheadline)
                            .foregroundColor(.appSecondary)
                        Button {
                            showAddSheet = true
                        } label: {
                            Label(L10n.string("overview.addExpense", language: languageStore.language), systemImage: "plus.circle.fill")
                                .font(.subheadline.bold())
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(Color.appAccent)
                                .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(32)
                } else {
                    ForEach(sortedExpenses, id: \.id) { exp in
                        NavigationLink {
                            ExpenseDetailView(expense: exp)
                                .environmentObject(dataStore)
                        } label: {
                            HStack(alignment: .center, spacing: 14) {
                                Image(systemName: exp.category.icon)
                                    .font(.title3)
                                    .foregroundColor(.appAccent)
                                    .frame(width: 40, height: 40)
                                    .background(Color.appTertiary)
                                    .clipShape(Circle())
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(exp.description.isEmpty ? categoryLabel(exp.category) : exp.description)
                                        .font(.subheadline.bold())
                                        .foregroundColor(.appPrimary)
                                        .lineLimit(1)
                                    HStack(spacing: 4) {
                                        Text(exp.date.formatted(date: .abbreviated, time: .omitted))
                                            .font(.caption)
                                        Text("·")
                                            .font(.caption)
                                        Text(memberName(id: exp.paidByMemberId))
                                            .font(.caption)
                                        Text("·")
                                            .font(.caption)
                                        Text(categoryLabel(exp.category))
                                            .font(.caption)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.appTertiary)
                                            .cornerRadius(6)
                                    }
                                    .foregroundColor(.appSecondary)
                                }
                                Spacer(minLength: 8)
                                Text(formatMoney(exp.amount, exp.currency))
                                    .font(.subheadline.bold())
                                    .foregroundColor(.green)
                                    .monospacedDigit()
                            }
                            .padding(14)
                            .background(Color.appCard)
                            .cornerRadius(14)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .background(Color.appBackground)
            .navigationTitle(dataStore.selectedEvent?.name ?? "💰 \(L10n.string("members.navTitle", language: languageStore.language))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    BackToTripsButton()
                        .environmentObject(dataStore)
                }
                ToolbarItem(placement: .principal) {
                    Text(dataStore.selectedEvent?.name ?? "💰 \(L10n.string("members.navTitle", language: languageStore.language))")
                        .font(AppFonts.tripTitle)
                        .foregroundColor(.primary)
                }
            }
            .sheet(isPresented: $showAddSheet) {
                NavigationStack {
                    AddExpenseView()
                        .environmentObject(dataStore)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button(L10n.string("common.done", language: languageStore.language)) {
                                    showAddSheet = false
                                }
                                .fontWeight(.semibold)
                                .foregroundColor(Color.appAccent)
                            }
                        }
                }
            }
            .sheet(isPresented: $showFilterSheet) {
                expenseFilterSheet
            }
    }
    
    private var expenseFilterSheet: some View {
        NavigationStack {
            List {
                Section {
                    Picker(L10n.string("filter.category", language: languageStore.language), selection: $filterCategory) {
                        Text(L10n.string("filter.allCategories", language: languageStore.language)).tag(nil as ExpenseCategory?)
                        ForEach(ExpenseCategory.allCases, id: \.self) { cat in
                            HStack {
                                Image(systemName: cat.icon)
                                Text(L10n.string("category.\(cat.rawValue)", language: languageStore.language))
                            }
                            .tag(cat as ExpenseCategory?)
                        }
                    }
                    .pickerStyle(.navigationLink)
                } header: {
                    Text(L10n.string("filter.category", language: languageStore.language))
                }
                Section {
                    Toggle(L10n.string("filter.filterByDateRange", language: languageStore.language), isOn: Binding(
                        get: { filterDateFrom != nil || filterDateTo != nil },
                        set: { on in
                            if on {
                                let d = Date()
                                if filterDateFrom == nil && filterDateTo == nil {
                                    filterDateFrom = d
                                    filterDateTo = d
                                } else {
                                    if filterDateFrom == nil { filterDateFrom = d }
                                    if filterDateTo == nil { filterDateTo = d }
                                }
                            } else {
                                filterDateFrom = nil
                                filterDateTo = nil
                            }
                        }
                    ))
                    if filterDateFrom != nil || filterDateTo != nil {
                        DatePicker(L10n.string("filter.startDate", language: languageStore.language), selection: Binding(
                            get: { filterDateFrom ?? Date() },
                            set: { filterDateFrom = $0 }
                        ), displayedComponents: .date)
                        DatePicker(L10n.string("filter.endDate", language: languageStore.language), selection: Binding(
                            get: { filterDateTo ?? Date() },
                            set: { filterDateTo = $0 }
                        ), displayedComponents: .date)
                    }
                } header: {
                    Text(L10n.string("filter.dateRange", language: languageStore.language))
                } footer: {
                    Text(L10n.string("filter.dateRangeFooter", language: languageStore.language))
                }
                Section {
                    ForEach(contextMembers) { member in
                        Button {
                            if filterMemberIds.contains(member.id) {
                                filterMemberIds.remove(member.id)
                            } else {
                                filterMemberIds.insert(member.id)
                            }
                        } label: {
                            HStack {
                                Text(member.name)
                                    .foregroundColor(.appPrimary)
                                Spacer()
                                if filterMemberIds.contains(member.id) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(Color.appAccent)
                                }
                            }
                        }
                    }
                } header: {
                    Text(L10n.string("filter.people", language: languageStore.language))
                } footer: {
                    Text(L10n.string("filter.peopleFooter", language: languageStore.language))
                }
                if hasActiveFilters {
                    Section {
                        Button(L10n.string("filter.clearAllFilters", language: languageStore.language)) {
                            filterCategory = nil
                            filterDateFrom = nil
                            filterDateTo = nil
                            filterMemberIds = []
                        }
                        .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle(L10n.string("filter.title", language: languageStore.language))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.string("common.cancel", language: languageStore.language)) {
                        showFilterSheet = false
                    }
                    .foregroundColor(.secondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.string("common.done", language: languageStore.language)) {
                        showFilterSheet = false
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(Color.appAccent)
                }
            }
        }
    }
}

#Preview {
    ExpensesListView()
        .environmentObject(BudgetDataStore())
}
