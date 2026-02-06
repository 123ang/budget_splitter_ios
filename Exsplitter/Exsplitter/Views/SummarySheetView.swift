//
//  SummarySheetView.swift
//  BudgetSplitter
//

import SwiftUI
import Charts

enum SummaryChartMode: String, CaseIterable {
    case byCategory = "By category"
    case byMember = "By member"
    case byDate = "By date"
}

struct SummarySheetView: View {
    @EnvironmentObject var dataStore: BudgetDataStore
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var currencyStore = CurrencyStore.shared
    @ObservedObject private var languageStore = LanguageStore.shared
    @State private var selectedMemberIds: Set<String> = []
    @State private var showMemberPicker = false
    @State private var chartMode: SummaryChartMode = .byCategory

    private var displayCurrency: Currency {
        currencyStore.preferredCurrency
    }
    
    /// Members for the current trip (or global when no trip). Summary member picker uses this list only.
    private var summaryMembers: [Member] { dataStore.members(for: dataStore.selectedEvent?.id) }

    private func formatMoney(_ amount: Double, _ currency: Currency) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = currency.decimals
        formatter.minimumFractionDigits = currency.decimals
        let str = formatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
        return "\(currency.symbol)\(str)"
    }

    private func memberName(id: String) -> String {
        summaryMembers.first(where: { $0.id == id })?.name ?? "—"
    }

    private var selectionLabel: String {
        if selectedMemberIds.isEmpty { return "Select members" }
        if selectedMemberIds.count == summaryMembers.count { return "Everyone" }
        return "\(selectedMemberIds.count) selected"
    }

    /// Total spent by selected members, converted to display (preferred) currency.
    private var totalSpent: Double {
        Currency.allCases.reduce(0) { sum, c in
            sum + dataStore.totalSpent(memberIds: selectedMemberIds, currency: c) * currencyStore.rate(from: c, to: displayCurrency)
        }
    }

    /// Category totals in display currency (all expense currencies converted).
    private var categoryData: [PieChartItem] {
        var combined: [ExpenseCategory: Double] = [:]
        for c in Currency.allCases {
            let cats = dataStore.categoryTotals(memberIds: selectedMemberIds, currency: c)
            let rate = currencyStore.rate(from: c, to: displayCurrency)
            for (cat, amount) in cats {
                combined[cat, default: 0] += amount * rate
            }
        }
        return combined
            .sorted { $0.value > $1.value }
            .map { PieChartItem(name: $0.key.rawValue, amount: $0.value) }
    }

    /// Per-member totals in display currency (for pie "By member").
    private var memberChartData: [PieChartItem] {
        selectedMemberIds.compactMap { id in
            let amount = Currency.allCases.reduce(0.0) { sum, c in
                sum + dataStore.memberTotal(memberId: id, currency: c) * currencyStore.rate(from: c, to: displayCurrency)
            }
            guard amount > 0 else { return nil }
            return PieChartItem(name: memberName(id: id), amount: amount)
        }
        .sorted { $0.amount > $1.amount }
    }

    /// Spending per calendar day in display currency (for "By date" and pie).
    private var spendingByDate: [(date: Date, amount: Double)] {
        var byDate: [Date: Double] = [:]
        let cal = Calendar.current
        for exp in dataStore.expenses {
            var amountForSelected: Double = 0
            for id in selectedMemberIds {
                amountForSelected += exp.splits[id] ?? 0
            }
            guard amountForSelected > 0 else { continue }
            let day = cal.startOfDay(for: exp.date)
            let converted = amountForSelected * currencyStore.rate(from: exp.currency, to: displayCurrency)
            byDate[day, default: 0] += converted
        }
        return byDate.sorted { $0.value > $1.value }.map { (date: $0.key, amount: $0.value) }
    }

    /// Top dates for pie (e.g. top 10) + "Other" if many.
    private var dateChartData: [PieChartItem] {
        let maxSlices = 10
        let sorted = spendingByDate
        if sorted.isEmpty { return [] }
        if sorted.count <= maxSlices {
            return sorted.map { PieChartItem(name: shortDate($0.date), amount: $0.amount) }
        }
        let top = sorted.prefix(maxSlices)
        let otherSum = sorted.dropFirst(maxSlices).reduce(0) { $0 + $1.amount }
        return top.map { PieChartItem(name: shortDate($0.date), amount: $0.amount) }
            + [PieChartItem(name: "Other dates", amount: otherSum)]
    }

    private func shortDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f.string(from: date)
    }

    private var currentChartData: [PieChartItem] {
        switch chartMode {
        case .byCategory: return categoryData
        case .byMember: return memberChartData
        case .byDate: return dateChartData
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    if summaryMembers.isEmpty {
                        Text(L10n.string("summary.addMembersFirst", language: languageStore.language))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 40)
                    } else {
                        // Select members
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L10n.string("summary.selectMembersToView", language: languageStore.language))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Button {
                                showMemberPicker = true
                            } label: {
                                HStack {
                                    Text(selectionLabel)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundColor(.appPrimary)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.semibold))
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 10)
                                .padding(.horizontal, 12)
                                .background(Color.appTertiary)
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                            .onAppear {
                                if selectedMemberIds.isEmpty {
                                    selectedMemberIds = Set(summaryMembers.map(\.id))
                                }
                            }
                            .onChange(of: summaryMembers.count) { _, _ in
                                let allIds = Set(summaryMembers.map(\.id))
                                if selectedMemberIds.isEmpty { selectedMemberIds = allIds }
                                else { selectedMemberIds = selectedMemberIds.filter { allIds.contains($0) } }
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.appCard)
                        .cornerRadius(12)
                        .sheet(isPresented: $showMemberPicker) {
                            SummaryMemberPickerSheet(
                                members: summaryMembers,
                                selectedMemberIds: $selectedMemberIds,
                                memberName: memberName,
                                onDismiss: { showMemberPicker = false }
                            )
                        }

                        // Total spent (for selected members) — always in preferred currency from Settings
                        VStack(alignment: .leading, spacing: 10) {
                            Text(String(format: L10n.string("summary.totalSpent", language: languageStore.language), displayCurrency.rawValue))
                                .font(.headline.bold())
                                .foregroundColor(.appPrimary)
                            Text(formatMoney(totalSpent, displayCurrency))
                                .font(.title2.bold())
                                .foregroundColor(.green)
                                .monospacedDigit()
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.appCard)
                        .cornerRadius(12)

                        // By date — most / least spent
                        if !spendingByDate.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(L10n.string("summary.byDate", language: languageStore.language))
                                    .font(.headline.bold())
                                    .foregroundColor(.appPrimary)
                                if let most = spendingByDate.first {
                                    HStack {
                                        Image(systemName: "arrow.up.circle.fill")
                                            .foregroundColor(.green)
                                        Text("Most spent: \(shortDate(most.date))")
                                            .font(.subheadline)
                                            .foregroundColor(.appPrimary)
                                        Spacer()
                                        Text(formatMoney(most.amount, displayCurrency))
                                            .font(.subheadline.bold())
                                            .foregroundColor(.green)
                                            .monospacedDigit()
                                    }
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 12)
                                    .background(Color.appTertiary)
                                    .cornerRadius(8)
                                }
                                if let least = spendingByDate.last, spendingByDate.count > 1 {
                                    HStack {
                                        Image(systemName: "arrow.down.circle.fill")
                                            .foregroundColor(.orange)
                                        Text(String(format: L10n.string("summary.leastSpent", language: languageStore.language), shortDate(least.date)))
                                            .font(.subheadline)
                                            .foregroundColor(.appPrimary)
                                        Spacer()
                                        Text(formatMoney(least.amount, displayCurrency))
                                            .font(.subheadline.bold())
                                            .foregroundColor(.orange)
                                            .monospacedDigit()
                                    }
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 12)
                                    .background(Color.appTertiary)
                                    .cornerRadius(8)
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.appCard)
                            .cornerRadius(12)
                        }

                        // Pie chart — by category / member / date
                        if currentChartData.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Picker("Chart", selection: $chartMode) {
                                    ForEach(SummaryChartMode.allCases, id: \.self) { mode in
                                        Text(mode.rawValue).tag(mode)
                                    }
                                }
                                .pickerStyle(.segmented)
                                Text(L10n.string("summary.noSpendingForView", language: languageStore.language))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .padding(.vertical, 8)
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.appCard)
                            .cornerRadius(12)
                        } else {
                            VStack(alignment: .leading, spacing: 10) {
                                Picker("Chart", selection: $chartMode) {
                                    ForEach(SummaryChartMode.allCases, id: \.self) { mode in
                                        Text(mode.rawValue).tag(mode)
                                    }
                                }
                                .pickerStyle(.segmented)
                                Chart(currentChartData) { item in
                                    SectorMark(
                                        angle: .value("Amount", item.amount),
                                        innerRadius: .ratio(0.0),
                                        angularInset: 1.2
                                    )
                                    .foregroundStyle(by: .value("Name", item.name))
                                    .cornerRadius(3)
                                }
                                .chartForegroundStyleScale(range: [
                                    Color.orange, Color.blue, Color.purple,
                                    Color.pink, Color.cyan, Color.gray, Color.green, Color.red
                                ])
                                .chartLegend(position: .bottom, spacing: 8)
                                .frame(height: 220)
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.appCard)
                            .cornerRadius(12)

                            // Breakdown list
                            VStack(alignment: .leading, spacing: 10) {
                                Text(L10n.string("summary.breakdown", language: languageStore.language))
                                    .font(.headline.bold())
                                    .foregroundColor(.appPrimary)
                                ForEach(currentChartData) { item in
                                    HStack {
                                        Text(item.name)
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.appPrimary)
                                            .lineLimit(1)
                                        Spacer()
                                        Text(formatMoney(item.amount, displayCurrency))
                                            .font(.subheadline.bold())
                                            .foregroundColor(.green)
                                            .monospacedDigit()
                                    }
                                    .padding(.vertical, 8)
                                    .overlay(
                                        Rectangle()
                                            .frame(height: 0.5)
                                            .foregroundColor(Color.appSeparator),
                                        alignment: .bottom
                                    )
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.appCard)
                            .cornerRadius(12)
                        }
                    }
                }
                .padding()
            }
            .background(Color.appBackground)
            .navigationTitle(L10n.string("summary.title", language: languageStore.language))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.string("common.done", language: languageStore.language)) {
                        dismiss()
                    }
                    .foregroundColor(Color(red: 10/255, green: 132/255, blue: 1))
                }
            }
        }
    }
}

// MARK: - Member picker sheet (multi-select + Everyone)
struct SummaryMemberPickerSheet: View {
    let members: [Member]
    @Binding var selectedMemberIds: Set<String>
    let memberName: (String) -> String
    let onDismiss: () -> Void

    private var allSelected: Bool {
        !members.isEmpty && selectedMemberIds.count == members.count
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle(isOn: Binding(
                        get: { allSelected },
                        set: { on in
                            if on {
                                selectedMemberIds = Set(members.map(\.id))
                            } else {
                                selectedMemberIds = []
                            }
                        }
                    )) {
                        Text(L10n.string("summary.everyone", language: LanguageStore.shared.language))
                            .font(.headline)
                            .foregroundColor(.appPrimary)
                    }
                } header: {
                    Text(L10n.string("summary.selectMembersToInclude", language: LanguageStore.shared.language))
                }

                Section {
                    ForEach(members) { member in
                        Toggle(isOn: Binding(
                            get: { selectedMemberIds.contains(member.id) },
                            set: { on in
                                if on {
                                    selectedMemberIds.insert(member.id)
                                } else {
                                    selectedMemberIds.remove(member.id)
                                }
                            }
                        )) {
                            Text(member.name)
                                .font(.subheadline)
                                .foregroundColor(.appPrimary)
                        }
                    }
                } header: {
                    Text(L10n.string("tab.members", language: LanguageStore.shared.language))
                }
            }
            .navigationTitle(L10n.string("summary.selectMembers", language: LanguageStore.shared.language))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.string("common.done", language: LanguageStore.shared.language)) {
                        onDismiss()
                    }
                    .foregroundColor(Color(red: 10/255, green: 132/255, blue: 1))
                }
            }
        }
    }
}

private struct PieChartItem: Identifiable {
    let id = UUID()
    let name: String
    let amount: Double
}

#Preview {
    SummarySheetView()
        .environmentObject(BudgetDataStore())
}
