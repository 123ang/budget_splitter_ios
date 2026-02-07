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
    @State private var showEditEventSheet = false
    
    /// Use live event from store when this is the selected event so edits update the view.
    private var currentEvent: Event {
        (dataStore.selectedEvent?.id == event.id ? dataStore.selectedEvent : nil) ?? event
    }
    
    private var eventExpenses: [Expense] {
        dataStore.filteredExpenses(for: currentEvent)
    }
    
    private var totalSpentInMain: Double {
        dataStore.totalSpentInMainCurrency(for: currentEvent)
    }
    
    private var isSettled: Bool {
        dataStore.isEventSettled(eventId: currentEvent.id)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Purpose + status
                HStack(spacing: 8) {
                    Text(OverviewView.purposeLabel(for: currentEvent, language: languageStore.language))
                        .font(.caption.bold())
                        .foregroundColor(.appAccent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.appAccent.opacity(0.12))
                        .cornerRadius(6)
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
                
                // Total for this session
                if !eventExpenses.isEmpty {
                    HStack {
                        Text(L10n.string("overview.totalSpent", language: languageStore.language))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(formatMoney(totalSpentInMain, currentEvent.mainCurrency))
                            .font(.title2.bold())
                            .foregroundColor(.appPrimary)
                    }
                    .padding()
                    .background(Color.appCard)
                    .cornerRadius(14)
                }
                
                // End session button (only for ongoing)
                if event.isOngoing {
                    Button {
                        MemberGroupHistoryStore.shared.saveCurrentGroup(
                            members: dataStore.members(for: currentEvent.id),
                            expenses: eventExpenses,
                            label: currentEvent.name
                        )
                        dataStore.endEvent(id: currentEvent.id)
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
                        Text(L10n.string("events.removeSession", language: languageStore.language))
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
                                    Text("\(exp.date.formatted(date: .abbreviated, time: .omitted)) • \(dataStore.members(for: currentEvent.id).first(where: { $0.id == exp.paidByMemberId })?.name ?? "—")")
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
        .navigationTitle(currentEvent.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                BackToTripsButton()
                    .environmentObject(dataStore)
            }
            ToolbarItem(placement: .principal) {
                Text(currentEvent.name)
                    .font(AppFonts.tripTitle)
                    .foregroundColor(.primary)
            }
            ToolbarItem(placement: .primaryAction) {
                Button(L10n.string("events.editEvent", language: languageStore.language)) {
                    showEditEventSheet = true
                }
            }
        }
        .sheet(isPresented: $showEditEventSheet) {
            EditEventSheet(event: currentEvent) {
                showEditEventSheet = false
            }
            .environmentObject(dataStore)
        }
        .confirmationDialog(L10n.string("events.removeSession", language: languageStore.language), isPresented: $showRemoveConfirm, titleVisibility: .visible) {
            Button(L10n.string("events.removeSession", language: languageStore.language), role: .destructive) {
                dataStore.removeEvent(id: currentEvent.id)
                dismiss()
            }
            Button(L10n.string("common.cancel", language: languageStore.language), role: .cancel) {}
        } message: {
            Text(L10n.string("events.removeSessionConfirm", language: languageStore.language))
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

// MARK: - Edit Event Sheet
struct EditEventSheet: View {
    let event: Event
    var onDismiss: () -> Void
    @EnvironmentObject var dataStore: BudgetDataStore
    @ObservedObject private var languageStore = LanguageStore.shared
    @State private var name: String = ""
    @State private var sessionType: SessionType = .trip
    @State private var customSessionTypeText: String = ""
    @State private var mainCurrency: Currency = .JPY
    @State private var subCurrency: Currency? = nil
    @State private var subCurrencyRateText: String = ""
    @State private var errorMessage: String? = nil
    @Environment(\.dismiss) private var dismiss
    
    private func sessionTypeLabel(_ type: SessionType) -> String {
        switch type {
        case .meal: return L10n.string("session.type.meal", language: languageStore.language)
        case .event: return L10n.string("session.type.event", language: languageStore.language)
        case .trip: return L10n.string("session.type.trip", language: languageStore.language)
        case .party: return L10n.string("session.type.party", language: languageStore.language)
        case .other: return L10n.string("session.type.other", language: languageStore.language)
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let err = errorMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text(err)
                                .font(.subheadline)
                                .foregroundColor(.orange)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.orange.opacity(0.12))
                        .cornerRadius(8)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.string("events.purpose", language: languageStore.language))
                            .font(.subheadline.bold())
                            .foregroundColor(.appPrimary)
                        Picker("", selection: $sessionType) {
                            ForEach(SessionType.allCases, id: \.self) { type in
                                Text(sessionTypeLabel(type)).tag(type)
                            }
                        }
                        .pickerStyle(.menu)
                        if sessionType == .other {
                            TextField(L10n.string("session.typeOtherPlaceholder", language: languageStore.language), text: $customSessionTypeText)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L10n.string("events.eventName", language: languageStore.language))
                            .font(.subheadline.bold())
                            .foregroundColor(.appPrimary)
                        TextField(L10n.string("events.eventName", language: languageStore.language), text: $name)
                            .textFieldStyle(.roundedBorder)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.string("events.mainCurrency", language: languageStore.language))
                            .font(.subheadline.bold())
                            .foregroundColor(.appPrimary)
                        Picker("", selection: $mainCurrency) {
                            ForEach(Currency.allCases, id: \.self) { curr in
                                Text("\(curr.symbol) \(curr.rawValue)").tag(curr)
                            }
                        }
                        .pickerStyle(.menu)
                        .onChange(of: mainCurrency) { _, newMain in
                            if subCurrency == newMain {
                                subCurrency = nil
                                subCurrencyRateText = ""
                            }
                        }
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.string("events.subCurrency", language: languageStore.language))
                            .font(.subheadline.bold())
                            .foregroundColor(.appPrimary)
                        Picker("", selection: Binding(
                            get: { subCurrency },
                            set: { subCurrency = $0; if $0 == nil { subCurrencyRateText = "" } }
                        )) {
                            Text(L10n.string("events.subCurrencyNone", language: languageStore.language)).tag(Optional<Currency>.none)
                            ForEach(Currency.allCases.filter { $0 != mainCurrency }, id: \.self) { curr in
                                Text("\(curr.symbol) \(curr.rawValue)").tag(Optional(curr))
                            }
                        }
                        .pickerStyle(.menu)
                        if let sub = subCurrency {
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Text(String(format: L10n.string("events.exchangeRateLabel", language: languageStore.language), sub.rawValue, mainCurrency.rawValue))
                                    .font(.subheadline)
                                    .foregroundColor(.appSecondary)
                                TextField("", text: $subCurrencyRateText)
                                    .keyboardType(.decimalPad)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 100)
                                Text(mainCurrency.rawValue)
                                    .font(.subheadline)
                                    .foregroundColor(.appSecondary)
                            }
                        }
                    }
                }
                .padding()
            }
            .background(Color.appBackground)
            .navigationTitle(L10n.string("events.editEvent", language: languageStore.language))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.string("common.cancel", language: languageStore.language)) {
                        dismiss()
                        onDismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.string("common.save", language: languageStore.language)) {
                        save()
                    }
                }
            }
            .onAppear {
                name = event.name
                sessionType = event.sessionType
                customSessionTypeText = event.sessionTypeCustom ?? ""
                mainCurrency = event.mainCurrency
                subCurrency = event.subCurrency
                if let rate = event.subCurrencyRate {
                    subCurrencyRateText = rate == Double(Int(rate)) ? "\(Int(rate))" : String(format: "%.4f", rate)
                } else {
                    subCurrencyRateText = ""
                }
            }
        }
    }
    
    private func save() {
        errorMessage = nil
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty {
            errorMessage = L10n.string("events.errorNameRequired", language: languageStore.language)
            return
        }
        if sessionType == .other, customSessionTypeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errorMessage = L10n.string("events.errorSessionTypeRequired", language: languageStore.language)
            return
        }
        if subCurrency != nil {
            guard let rate = Double(subCurrencyRateText.replacingOccurrences(of: ",", with: "")), rate > 0 else {
                errorMessage = L10n.string("events.errorExchangeRateRequired", language: languageStore.language)
                return
            }
        }
        let rate: Double? = subCurrency.flatMap { _ in Double(subCurrencyRateText.replacingOccurrences(of: ",", with: "")) }
        let custom = sessionType == .other ? (customSessionTypeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : customSessionTypeText.trimmingCharacters(in: .whitespacesAndNewlines)) : nil
        dataStore.updateEvent(id: event.id, name: trimmedName, sessionType: sessionType, sessionTypeCustom: custom, mainCurrency: mainCurrency, subCurrency: subCurrency, subCurrencyRate: rate)
        dismiss()
        onDismiss()
    }
}

#Preview {
    NavigationStack {
        EventDetailView(event: Event(name: "Japan Trip"))
            .environmentObject(BudgetDataStore())
    }
}
