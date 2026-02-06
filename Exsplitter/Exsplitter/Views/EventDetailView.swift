//
//  EventDetailView.swift
//  Exsplitter
//

import SwiftUI

struct EventDetailView: View {
    @EnvironmentObject var dataStore: BudgetDataStore
    @ObservedObject private var languageStore = LanguageStore.shared
    let event: Event
    @Environment(\.dismiss) private var dismiss
    @State private var showRemoveConfirm = false
    
    private var eventExpenses: [Expense] {
        dataStore.filteredExpenses(for: event)
    }
    
    private var totalSpentJPY: Double {
        dataStore.totalSpent(for: event.id, currency: .JPY)
    }
    
    private var isSettled: Bool {
        dataStore.isEventSettled(eventId: event.id)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Status badge
                HStack {
                    Text(event.isOngoing
                         ? L10n.string("events.ongoing", language: languageStore.language)
                         : L10n.string("events.ended", language: languageStore.language))
                        .font(.caption.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(event.isOngoing ? Color.green : Color.gray)
                        .cornerRadius(8)
                    if !eventExpenses.isEmpty {
                        Text(isSettled
                             ? L10n.string("events.allSettled", language: languageStore.language)
                             : L10n.string("events.outstanding", language: languageStore.language))
                            .font(.caption)
                            .foregroundColor(isSettled ? .green : .orange)
                    }
                    Spacer()
                }
                
                // Total for this trip
                if !eventExpenses.isEmpty {
                    HStack {
                        Text(L10n.string("overview.totalSpent", language: languageStore.language))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(formatMoney(totalSpentJPY, .JPY))
                            .font(.title2.bold())
                            .foregroundColor(.appPrimary)
                    }
                    .padding()
                    .background(Color.appCard)
                    .cornerRadius(14)
                }
                
                // End trip button (only for ongoing)
                if event.isOngoing {
                    Button {
                        MemberGroupHistoryStore.shared.saveCurrentGroup(
                            members: dataStore.members(for: event.id),
                            expenses: eventExpenses,
                            label: event.name
                        )
                        dataStore.endEvent(id: event.id)
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text(L10n.string("events.summarize", language: languageStore.language))
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(14)
                    }
                    .buttonStyle(.plain)
                }
                
                Button {
                    showRemoveConfirm = true
                } label: {
                    HStack {
                        Image(systemName: "trash")
                        Text(L10n.string("events.removeTrip", language: languageStore.language))
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .cornerRadius(14)
                }
                .buttonStyle(.plain)
                
                // Expenses list
                VStack(alignment: .leading, spacing: 8) {
                    Text(String(format: L10n.string("events.expensesCount", language: languageStore.language), eventExpenses.count))
                        .font(.headline)
                        .foregroundColor(.appPrimary)
                    
                    if eventExpenses.isEmpty {
                        Text(L10n.string("overview.noExpensesYet", language: languageStore.language))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding()
                            .frame(maxWidth: .infinity)
                    } else {
                        ForEach(eventExpenses.sorted(by: { $0.date > $1.date })) { exp in
                            HStack {
                                Image(systemName: exp.category.icon)
                                    .foregroundColor(categoryColor(exp.category))
                                    .frame(width: 28, alignment: .center)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(exp.description.isEmpty ? exp.category.rawValue : exp.description)
                                        .font(.subheadline)
                                        .foregroundColor(.appPrimary)
                                        .lineLimit(1)
                                    Text("\(exp.date.formatted(date: .abbreviated, time: .omitted)) • \(dataStore.members(for: event.id).first(where: { $0.id == exp.paidByMemberId })?.name ?? "—")")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Text(formatMoney(exp.amount, exp.currency))
                                    .font(.subheadline.bold())
                                    .foregroundColor(.green)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(Color.appTertiary)
                            .cornerRadius(10)
                        }
                    }
                }
            }
            .padding()
        }
        .background(Color.appBackground)
        .navigationTitle(event.name)
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(L10n.string("events.removeTrip", language: languageStore.language), isPresented: $showRemoveConfirm, titleVisibility: .visible) {
            Button(L10n.string("events.removeTrip", language: languageStore.language), role: .destructive) {
                dataStore.removeEvent(id: event.id)
                dismiss()
            }
            Button(L10n.string("common.cancel", language: languageStore.language), role: .cancel) {}
        } message: {
            Text(L10n.string("events.removeTripConfirm", language: languageStore.language))
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

#Preview {
    NavigationStack {
        EventDetailView(event: Event(name: "Japan Trip"))
            .environmentObject(BudgetDataStore())
    }
}
