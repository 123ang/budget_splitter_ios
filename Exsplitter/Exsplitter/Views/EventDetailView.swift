//
//  EventDetailView.swift
//  Xsplitter
//

import SwiftUI

struct EventDetailView: View {
    @EnvironmentObject var dataStore: BudgetDataStore
    @ObservedObject private var languageStore = LanguageStore.shared
    let event: Event
    @Environment(\.dismiss) private var dismiss
    @State private var showRemoveConfirm = false
    @State private var showSummarizeEndConfirm = false
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
                        showSummarizeEndConfirm = true
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
                                    Text("\(L10n.formatDate(exp.date, language: languageStore.language)) • \(dataStore.members(for: currentEvent.id).first(where: { $0.id == exp.paidByMemberId })?.name ?? "—")")
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
        .confirmationDialog(L10n.string("events.summarizeEndConfirmTitle", language: languageStore.language), isPresented: $showSummarizeEndConfirm, titleVisibility: .visible) {
            Button(L10n.string("common.confirm", language: languageStore.language)) {
                MemberGroupHistoryStore.shared.saveCurrentGroup(
                    members: dataStore.members(for: currentEvent.id),
                    expenses: eventExpenses,
                    label: currentEvent.name
                )
                dataStore.endEvent(id: currentEvent.id)
                dismiss()
            }
            Button(L10n.string("common.cancel", language: languageStore.language), role: .cancel) {}
        } message: {
            Text(L10n.string("events.summarizeEndConfirmMessage", language: languageStore.language))
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
    @ObservedObject private var currencyStore = CurrencyStore.shared
    @State private var name: String = ""
    @State private var sessionType: SessionType = .trip
    @State private var customSessionTypeText: String = ""
    @State private var mainCurrency: Currency = .JPY
    @State private var subCurrencyEntries: [SubCurrencyEntry] = []
    @State private var errorMessage: String? = nil
    @Environment(\.dismiss) private var dismiss
    
    private func sessionTypeLabel(_ type: SessionType) -> String {
        switch type {
        case .meal: return L10n.string("session.type.meal", language: languageStore.language)
        case .event: return L10n.string("session.type.event", language: languageStore.language)
        case .trip: return L10n.string("session.type.trip", language: languageStore.language)
        case .activity: return L10n.string("session.type.activity", language: languageStore.language)
        case .party: return L10n.string("session.type.party", language: languageStore.language)
        case .other: return L10n.string("session.type.other", language: languageStore.language)
        }
    }
    
    /// Name field label: "Trip name" when purpose is trip, "Event name" for meal/party/event/activity/other.
    private var nameFieldLabel: String {
        sessionType == .trip
            ? L10n.string("events.tripName", language: languageStore.language)
            : L10n.string("events.eventNameLabel", language: languageStore.language)
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
                        Text(nameFieldLabel)
                            .font(.subheadline.bold())
                            .foregroundColor(.appPrimary)
                        TextField(nameFieldLabel, text: $name)
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
                            subCurrencyEntries.removeAll { $0.currency == newMain }
                        }
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.string("events.subCurrency", language: languageStore.language))
                            .font(.subheadline.bold())
                            .foregroundColor(.appPrimary)
                        Text(L10n.string("events.subCurrenciesHint", language: languageStore.language))
                            .font(.caption)
                            .foregroundColor(.appSecondary)
                        ForEach(subCurrencyEntries) { entry in
                            SubCurrencyRowView(
                                entry: bindingForSubCurrencyEntry(entry),
                                mainCurrency: mainCurrency,
                                allSelected: subCurrencyEntries.map(\.currency),
                                onRemove: subCurrencyEntries.count > 1 ? { subCurrencyEntries.removeAll { $0.id == entry.id } } : nil
                            )
                        }
                        if subCurrencyEntries.count < 3 {
                            Button {
                                let available = Currency.allCases.filter { $0 != mainCurrency && !subCurrencyEntries.map(\.currency).contains($0) }
                                let subCur = available.first ?? .USD
                                let rate = currencyStore.rate(from: subCur, to: mainCurrency)
                                let rateStr = mainCurrency.decimals == 0 ? String(format: "%.0f", rate) : String(format: "%.4f", rate)
                                subCurrencyEntries.append(SubCurrencyEntry(currency: subCur, rateText: rateStr))
                            } label: {
                                Label(L10n.string("events.addSubCurrency", language: languageStore.language), systemImage: "plus.circle")
                                    .font(.subheadline)
                                    .foregroundColor(Color.appAccent)
                            }
                            .buttonStyle(.plain)
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
                subCurrencyEntries = event.subCurrencies.map { pair in
                    let rate = pair.rate > 0.001 ? pair.rate : currencyStore.rate(from: pair.currency, to: event.mainCurrency)
                    let rateStr = mainCurrency.decimals == 0 ? String(format: "%.0f", rate) : String(format: "%.4f", rate)
                    return SubCurrencyEntry(currency: pair.currency, rateText: rateStr)
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
        let ratesDict: [String: Double]? = {
            var d: [String: Double] = [:]
            for entry in subCurrencyEntries {
                guard let rate = Double(entry.rateText.replacingOccurrences(of: ",", with: "")), rate > 0 else {
                    errorMessage = L10n.string("events.errorExchangeRateRequired", language: languageStore.language)
                    return nil
                }
                d[entry.currency.rawValue] = rate
            }
            return d.isEmpty ? nil : d
        }()
        if errorMessage != nil { return }
        let custom = sessionType == .other ? (customSessionTypeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : customSessionTypeText.trimmingCharacters(in: .whitespacesAndNewlines)) : nil
        dataStore.updateEvent(id: event.id, name: trimmedName, sessionType: sessionType, sessionTypeCustom: custom, mainCurrency: mainCurrency, subCurrencyRatesByCode: ratesDict)
        dismiss()
        onDismiss()
    }
    
    private func bindingForSubCurrencyEntry(_ entry: SubCurrencyEntry) -> Binding<SubCurrencyEntry> {
        Binding(
            get: { subCurrencyEntries.first(where: { $0.id == entry.id }) ?? entry },
            set: { new in
                if let i = subCurrencyEntries.firstIndex(where: { $0.id == entry.id }) {
                    subCurrencyEntries[i] = new
                }
            }
        )
    }
}

#Preview {
    NavigationStack {
        EventDetailView(event: Event(name: "Japan Trip"))
            .environmentObject(BudgetDataStore())
    }
}
