//
//  TripsHomeView.swift
//  Exsplitter
//
//  Main homepage: list of trips/events. Tapping a trip opens the budget splitter overview for that trip.
//

import SwiftUI

struct TripsHomeView: View {
    @EnvironmentObject var dataStore: BudgetDataStore
    @ObservedObject private var languageStore = LanguageStore.shared
    var onSelectTab: ((Int) -> Void)? = nil
    var onShowSummary: (() -> Void)? = nil
    var onShowAddExpense: (() -> Void)? = nil
    var onShowSettings: (() -> Void)? = nil
    /// When user taps a trip, open that trip (tab bar will appear). Set from LocalModeView.
    var onSelectTrip: ((Event) -> Void)? = nil
    
    @ObservedObject private var historyStore = MemberGroupHistoryStore.shared
    @State private var showAddEventSheet = false
    @State private var newEventName = ""
    @State private var memberSource: AddTripMemberSource = .fromPastTrip
    @State private var selectedSavedGroupId: UUID? = nil
    @State private var newMemberNames: [String] = []
    @State private var newMemberNameInput: String = ""
    @State private var selectedCurrenciesForNewEvent: Set<Currency> = Set(Currency.allCases)
    @State private var addEventError: String? = nil
    @State private var eventToRemove: Event? = nil
    
    private enum AddTripMemberSource {
        case createNew
        case fromPastTrip
    }
    
    private var sortedEvents: [Event] {
        dataStore.events.sorted { e1, e2 in
            if e1.isOngoing != e2.isOngoing { return e1.isOngoing }
            return (e1.createdAt > e2.createdAt)
        }
    }
    
    private var canAddNewEvent: Bool {
        let name = newEventName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return false }
        switch memberSource {
        case .createNew:
            return !newMemberNames.isEmpty
        case .fromPastTrip:
            return selectedSavedGroupId != nil
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header + Add trip
                    HStack {
                        Text(L10n.string("events.trips", language: languageStore.language))
                            .font(.title2.bold())
                            .foregroundColor(.appPrimary)
                        Spacer()
                        Button {
                            newEventName = ""
                            memberSource = .fromPastTrip
                            selectedSavedGroupId = nil
                            newMemberNames = []
                            newMemberNameInput = ""
                            selectedCurrenciesForNewEvent = Set(Currency.allCases)
                            addEventError = nil
                            showAddEventSheet = true
                        } label: {
                            Label(L10n.string("events.addEvent", language: languageStore.language), systemImage: "plus.circle.fill")
                                .font(.subheadline.bold())
                        }
                    }
                    .padding(.horizontal, 4)
                    
                    if sortedEvents.isEmpty {
                        // Empty state
                        VStack(spacing: 12) {
                            Image(systemName: "map.fill")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary.opacity(0.7))
                            Text(L10n.string("events.noEvents", language: languageStore.language))
                                .font(.headline)
                                .foregroundColor(.appPrimary)
                            Text(L10n.string("events.createFirst", language: languageStore.language))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                            Button {
                                newEventName = ""
                                memberSource = .fromPastTrip
                                selectedSavedGroupId = nil
                                newMemberNames = []
                                newMemberNameInput = ""
                                selectedCurrenciesForNewEvent = Set(Currency.allCases)
                                addEventError = nil
                                showAddEventSheet = true
                            } label: {
                                Label(L10n.string("events.addEvent", language: languageStore.language), systemImage: "plus.circle.fill")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Color(red: 10/255, green: 132/255, blue: 1))
                            .padding(.top, 8)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                        .padding(.horizontal, 24)
                    } else {
                        // List of trips
                        VStack(spacing: 12) {
                            ForEach(sortedEvents) { event in
                                Button {
                                    onSelectTrip?(event)
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text(event.name)
                                                .font(.headline)
                                                .foregroundColor(.appPrimary)
                                            HStack(spacing: 8) {
                                                Text(event.isOngoing
                                                     ? L10n.string("events.ongoing", language: languageStore.language)
                                                     : L10n.string("events.ended", language: languageStore.language))
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                                Text("•")
                                                    .foregroundColor(.secondary)
                                                Text(String(format: L10n.string("events.expensesCount", language: languageStore.language), dataStore.filteredExpenses(for: event).count))
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.body.bold())
                                            .foregroundColor(.secondary)
                                    }
                                    .padding()
                                    .background(Color.appCard)
                                    .cornerRadius(14)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        confirmRemoveEvent(event)
                                    } label: {
                                        Label(L10n.string("events.removeTrip", language: languageStore.language), systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .background(Color.appBackground)
            .navigationTitle("💰 \(L10n.string("members.navTitle", language: languageStore.language))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        onShowSettings?()
                    } label: {
                        Image(systemName: "gear")
                    }
                }
            }
            .sheet(isPresented: $showAddEventSheet) {
                addEventSheet
            }
            .confirmationDialog(L10n.string("events.removeTrip", language: languageStore.language), isPresented: Binding(get: { eventToRemove != nil }, set: { if !$0 { eventToRemove = nil } }), titleVisibility: .visible) {
                Button(L10n.string("events.removeTrip", language: languageStore.language), role: .destructive) {
                    if let event = eventToRemove {
                        dataStore.removeEvent(id: event.id)
                        eventToRemove = nil
                    }
                }
                Button(L10n.string("common.cancel", language: languageStore.language), role: .cancel) {
                    eventToRemove = nil
                }
            } message: {
                Text(L10n.string("events.removeTripConfirm", language: languageStore.language))
            }
        }
    }
    
    private func confirmRemoveEvent(_ event: Event) {
        eventToRemove = event
    }
    
    private var addEventSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L10n.string("events.eventName", language: languageStore.language))
                            .font(.subheadline.bold())
                            .foregroundColor(.appPrimary)
                        TextField(L10n.string("events.eventName", language: languageStore.language), text: $newEventName)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.string("events.membersForTrip", language: languageStore.language))
                            .font(.subheadline.bold())
                            .foregroundColor(.appPrimary)
                        Picker("", selection: $memberSource) {
                            Text(L10n.string("events.createNewMembers", language: languageStore.language)).tag(AddTripMemberSource.createNew)
                            Text(L10n.string("events.addFromPastTrip", language: languageStore.language)).tag(AddTripMemberSource.fromPastTrip)
                        }
                        .pickerStyle(.segmented)
                        
                        if memberSource == .createNew {
                            HStack(spacing: 8) {
                                TextField(L10n.string("events.newMemberName", language: languageStore.language), text: $newMemberNameInput)
                                    .textFieldStyle(.roundedBorder)
                                Button(L10n.string("events.addOneMember", language: languageStore.language)) {
                                    let name = newMemberNameInput.trimmingCharacters(in: .whitespacesAndNewlines)
                                    if !name.isEmpty, !newMemberNames.contains(name) {
                                        newMemberNames.append(name)
                                        newMemberNameInput = ""
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(Color(red: 10/255, green: 132/255, blue: 1))
                            }
                            ForEach(Array(newMemberNames.enumerated()), id: \.offset) { index, name in
                                HStack {
                                    Text(name)
                                        .font(.subheadline)
                                        .foregroundColor(.appPrimary)
                                    Spacer()
                                    Button {
                                        newMemberNames.remove(at: index)
                                    } label: {
                                        Image(systemName: "minus.circle.fill")
                                            .foregroundColor(.red)
                                    }
                                }
                                .padding(.vertical, 6)
                                .padding(.horizontal, 10)
                                .background(Color.appTertiary)
                                .cornerRadius(8)
                            }
                            if newMemberNames.isEmpty {
                                Text(L10n.string("events.addAtLeastOne", language: languageStore.language))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            if historyStore.groups.isEmpty {
                                Text(L10n.string("events.noSavedGroups", language: languageStore.language))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .padding(.vertical, 8)
                            } else {
                                ForEach(historyStore.groups) { group in
                                    Button {
                                        if selectedSavedGroupId == group.id {
                                            selectedSavedGroupId = nil
                                        } else {
                                            selectedSavedGroupId = group.id
                                        }
                                    } label: {
                                        HStack {
                                            Image(systemName: selectedSavedGroupId == group.id ? "checkmark.circle.fill" : "circle")
                                                .foregroundColor(selectedSavedGroupId == group.id ? Color(red: 10/255, green: 132/255, blue: 1) : .secondary)
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(group.label)
                                                    .font(.subheadline.bold())
                                                    .foregroundColor(.appPrimary)
                                                Text(String(format: L10n.string("members.membersCountDate", language: languageStore.language), group.displayMemberNames.count, group.shortDate))
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                            Spacer()
                                        }
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 10)
                                        .background(Color.appTertiary)
                                        .cornerRadius(8)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        if let err = addEventError {
                            Text(err)
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.string("events.currenciesForTrip", language: languageStore.language))
                            .font(.subheadline.bold())
                            .foregroundColor(.appPrimary)
                        Button {
                            if selectedCurrenciesForNewEvent.count == Currency.allCases.count {
                                selectedCurrenciesForNewEvent = []
                            } else {
                                selectedCurrenciesForNewEvent = Set(Currency.allCases)
                            }
                        } label: {
                            Text(L10n.string("events.selectAllCurrencies", language: languageStore.language))
                                .font(.caption)
                                .foregroundColor(Color(red: 10/255, green: 132/255, blue: 1))
                        }
                        ForEach(Currency.allCases, id: \.self) { currency in
                            Button {
                                if selectedCurrenciesForNewEvent.contains(currency) {
                                    selectedCurrenciesForNewEvent.remove(currency)
                                } else {
                                    selectedCurrenciesForNewEvent.insert(currency)
                                }
                            } label: {
                                HStack {
                                    Image(systemName: selectedCurrenciesForNewEvent.contains(currency) ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(selectedCurrenciesForNewEvent.contains(currency) ? Color(red: 10/255, green: 132/255, blue: 1) : .secondary)
                                    Text("\(currency.symbol) \(currency.rawValue)")
                                        .foregroundColor(.appPrimary)
                                    Spacer()
                                }
                                .padding(.vertical, 6)
                                .padding(.horizontal, 10)
                                .background(Color.appTertiary)
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding()
            }
            .background(Color.appBackground)
            .navigationTitle(L10n.string("events.addEvent", language: languageStore.language))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showAddEventSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let name = newEventName.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !name.isEmpty else { return }
                        addEventError = nil
                        let names: [String]
                        switch memberSource {
                        case .createNew:
                            guard !newMemberNames.isEmpty else { return }
                            names = newMemberNames
                        case .fromPastTrip:
                            guard let groupId = selectedSavedGroupId,
                                  let group = historyStore.groups.first(where: { $0.id == groupId }) else { return }
                            names = group.displayMemberNames
                        }
                        let currencyCodes: [String]? = selectedCurrenciesForNewEvent.isEmpty || selectedCurrenciesForNewEvent.count == Currency.allCases.count
                            ? nil
                            : Array(selectedCurrenciesForNewEvent).map(\.rawValue)
                        Task {
                            do {
                                let existingNames = Set(dataStore.members.map { $0.name })
                                let toAdd = names.filter { !existingNames.contains($0) }
                                if !toAdd.isEmpty {
                                    try await dataStore.addMembersFromHistory(names: toAdd)
                                }
                                await MainActor.run {
                                    let memberIds = dataStore.members.filter { names.contains($0.name) }.map(\.id)
                                    if let newEvent = dataStore.addEvent(name: name, memberIds: memberIds.isEmpty ? nil : memberIds, currencyCodes: currencyCodes) {
                                        dataStore.selectedEvent = newEvent
                                        UserDefaults.standard.set(newEvent.id, forKey: lastSelectedEventIdKey)
                                    }
                                    showAddEventSheet = false
                                }
                            } catch {
                                await MainActor.run {
                                    addEventError = (error as? LocalizedError)?.errorDescription ?? "Failed to add group"
                                }
                            }
                        }
                    }
                    .disabled(!canAddNewEvent)
                }
            }
        }
    }
}

#Preview {
    TripsHomeView()
        .environmentObject(BudgetDataStore())
}
