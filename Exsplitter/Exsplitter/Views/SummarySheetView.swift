//
//  SummarySheetView.swift
//  BudgetSplitter
//

import SwiftUI
import Charts

struct SummarySheetView: View {
    @EnvironmentObject var dataStore: BudgetDataStore
    @Environment(\.dismiss) private var dismiss
    @State private var selectedMemberIds: Set<String> = []
    @State private var showMemberPicker = false

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

    private var selectionLabel: String {
        if selectedMemberIds.isEmpty { return "Select members" }
        if selectedMemberIds.count == dataStore.members.count { return "Everyone" }
        return "\(selectedMemberIds.count) selected"
    }

    private var totalSpent: Double {
        dataStore.totalSpent(memberIds: selectedMemberIds, currency: .JPY)
    }

    private var categoryData: [CategoryChartItem] {
        dataStore.categoryTotals(memberIds: selectedMemberIds, currency: .JPY)
            .sorted { $0.value > $1.value }
            .map { CategoryChartItem(name: $0.key.rawValue, amount: $0.value, category: $0.key) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    if dataStore.members.isEmpty {
                        Text("Add members first.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 40)
                    } else {
                        // Select members
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Select members to view")
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
                                    selectedMemberIds = Set(dataStore.members.map(\.id))
                                }
                            }
                            .onChange(of: dataStore.members.count) { _, _ in
                                let allIds = Set(dataStore.members.map(\.id))
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
                                dataStore: dataStore,
                                selectedMemberIds: $selectedMemberIds,
                                memberName: memberName,
                                onDismiss: { showMemberPicker = false }
                            )
                        }

                        // Total spent (for selected members)
                        VStack(alignment: .leading, spacing: 10) {
                            Text("JPY — Total spent")
                                .font(.headline.bold())
                                .foregroundColor(.appPrimary)
                            Text(formatMoney(totalSpent, .JPY))
                                .font(.title2.bold())
                                .foregroundColor(.green)
                                .monospacedDigit()
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.appCard)
                        .cornerRadius(12)

                        // By category — pie chart
                        if categoryData.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("By category")
                                    .font(.headline.bold())
                                    .foregroundColor(.appPrimary)
                                Text("No spending in categories yet.")
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
                                Text("By category")
                                    .font(.headline.bold())
                                    .foregroundColor(.appPrimary)
                                Chart(categoryData) { item in
                                    SectorMark(
                                        angle: .value("Amount", item.amount),
                                        innerRadius: .ratio(0.0),
                                        angularInset: 1.2
                                    )
                                    .foregroundStyle(by: .value("Category", item.name))
                                    .cornerRadius(3)
                                }
                                .chartForegroundStyleScale(range: [
                                    Color.orange, Color.blue, Color.purple,
                                    Color.pink, Color.cyan, Color.gray
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
                                Text("Breakdown")
                                    .font(.headline.bold())
                                    .foregroundColor(.appPrimary)
                                ForEach(categoryData, id: \.name) { item in
                                    HStack {
                                        Image(systemName: item.category.icon)
                                        Text(item.name)
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.appPrimary)
                                        Spacer()
                                        Text(formatMoney(item.amount, .JPY))
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
            .navigationTitle("Summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
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
    @ObservedObject var dataStore: BudgetDataStore
    @Binding var selectedMemberIds: Set<String>
    let memberName: (String) -> String
    let onDismiss: () -> Void

    private var allSelected: Bool {
        selectedMemberIds.count == dataStore.members.count
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle(isOn: Binding(
                        get: { allSelected },
                        set: { on in
                            if on {
                                selectedMemberIds = Set(dataStore.members.map(\.id))
                            } else {
                                selectedMemberIds = []
                            }
                        }
                    )) {
                        Text("Everyone")
                            .font(.headline)
                            .foregroundColor(.appPrimary)
                    }
                } header: {
                    Text("Select members to include")
                }

                Section {
                    ForEach(dataStore.members) { member in
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
                    Text("Members")
                }
            }
            .navigationTitle("Select members")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        onDismiss()
                    }
                    .foregroundColor(Color(red: 10/255, green: 132/255, blue: 1))
                }
            }
        }
    }
}

private struct CategoryChartItem: Identifiable {
    let id = UUID()
    let name: String
    let amount: Double
    let category: ExpenseCategory
}

#Preview {
    SummarySheetView()
        .environmentObject(BudgetDataStore())
}
