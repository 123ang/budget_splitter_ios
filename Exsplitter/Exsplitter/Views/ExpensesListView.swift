//
//  ExpensesListView.swift
//  BudgetSplitter
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
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    // Expense list header (title + filter + add button)
                    let sortedExpenses = filteredExpenses.sorted(by: { $0.date > $1.date })
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text(L10n.string("tab.expenses", language: languageStore.language))
                                    .font(.headline.bold())
                                    .foregroundColor(.appPrimary)
                                if let trip = dataStore.selectedEvent {
                                    Text("•")
                                        .foregroundColor(.secondary)
                                    Text(trip.name)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                            Text(String(format: L10n.string("expenses.recordedCount", language: languageStore.language), sortedExpenses.count, contextExpenses.count))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Button {
                            showFilterSheet = true
                        } label: {
                            ZStack(alignment: .topTrailing) {
                                Image(systemName: "line.3.horizontal.decrease.circle")
                                    .font(.title2)
                                    .foregroundColor(hasActiveFilters ? Color(red: 10/255, green: 132/255, blue: 1) : .secondary)
                                if hasActiveFilters {
                                    Circle()
                                        .fill(Color(red: 10/255, green: 132/255, blue: 1))
                                        .frame(width: 8, height: 8)
                                        .offset(x: 4, y: -4)
                                }
                            }
                        }
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
            .navigationTitle(dataStore.selectedEvent?.name ?? "💰 \(L10n.string("members.navTitle", language: languageStore.language))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if dataStore.selectedEvent != nil {
                    ToolbarItem(placement: .cancellationAction) {
                        BackToTripsButton()
                            .environmentObject(dataStore)
                    }
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
                                .foregroundColor(Color(red: 10/255, green: 132/255, blue: 1))
                            }
                        }
                }
            }
            .sheet(isPresented: $showFilterSheet) {
                expenseFilterSheet
            }
        }
    }
    
    private var expenseFilterSheet: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Category", selection: $filterCategory) {
                        Text("All categories").tag(nil as ExpenseCategory?)
                        ForEach(ExpenseCategory.allCases, id: \.self) { cat in
                            HStack {
                                Image(systemName: cat.icon)
                                Text(cat.rawValue)
                            }
                            .tag(cat as ExpenseCategory?)
                        }
                    }
                    .pickerStyle(.navigationLink)
                } header: {
                    Text("Category")
                }
                Section {
                    Toggle("From date", isOn: Binding(
                        get: { filterDateFrom != nil },
                        set: { if $0 { filterDateFrom = filterDateFrom ?? Date() } else { filterDateFrom = nil } }
                    ))
                    if filterDateFrom != nil {
                        DatePicker("From", selection: Binding(
                            get: { filterDateFrom ?? Date() },
                            set: { filterDateFrom = $0 }
                        ), displayedComponents: .date)
                    }
                    Toggle("To date", isOn: Binding(
                        get: { filterDateTo != nil },
                        set: { if $0 { filterDateTo = filterDateTo ?? Date() } else { filterDateTo = nil } }
                    ))
                    if filterDateTo != nil {
                        DatePicker("To", selection: Binding(
                            get: { filterDateTo ?? Date() },
                            set: { filterDateTo = $0 }
                        ), displayedComponents: .date)
                    }
                } header: {
                    Text("Date range")
                } footer: {
                    Text("Leave off for no date filter.")
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
                                        .foregroundColor(Color(red: 10/255, green: 132/255, blue: 1))
                                }
                            }
                        }
                    }
                } header: {
                    Text("People")
                } footer: {
                    Text("Show expenses paid by or split with selected people. Leave none selected for all.")
                }
                if hasActiveFilters {
                    Section {
                        Button("Clear all filters") {
                            filterCategory = nil
                            filterDateFrom = nil
                            filterDateTo = nil
                            filterMemberIds = []
                        }
                        .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Filter expenses")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showFilterSheet = false
                    }
                    .foregroundColor(.secondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showFilterSheet = false
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(Color(red: 10/255, green: 132/255, blue: 1))
                }
            }
        }
    }
}

#Preview {
    ExpensesListView()
        .environmentObject(BudgetDataStore())
}
