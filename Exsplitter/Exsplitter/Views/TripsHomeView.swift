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
    /// When user taps a trip, open that trip (tab bar will appear). Set from RootView.
    var onSelectTrip: ((Event) -> Void)? = nil
    
    @ObservedObject private var historyStore = MemberGroupHistoryStore.shared
    @State private var showAddEventSheet = false
    @State private var newEventName = ""
    @State private var memberSource: AddTripMemberSource = .createNew
    @State private var selectedSavedGroupId: UUID? = nil
    @State private var newMemberNames: [String] = []
    @State private var newMemberNameInput: String = ""
    @State private var selectedCurrenciesForNewEvent: Set<Currency> = []
    @State private var currencySearchText = ""
    @State private var addEventError: String? = nil
    @State private var eventToRemove: Event? = nil
    @State private var selectedSessionType: SessionType = .trip
    @State private var customSessionTypeText: String = ""
    @State private var showEndedTrips = false
    @State private var expandedPastGroupId: UUID? = nil
    @State private var showCurrencyPickerSheet = false
    @State private var showDuplicateNameAlert = false
    
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
    
    private var ongoingEvents: [Event] {
        sortedEvents.filter { $0.isOngoing }
    }
    
    private var endedEvents: [Event] {
        sortedEvents.filter { !$0.isOngoing }
    }
    
    private var canAddNewEvent: Bool {
        let name = newEventName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return false }
        if selectedSessionType == .other {
            guard !customSessionTypeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        }
        switch memberSource {
        case .createNew:
            guard !newMemberNames.isEmpty else { return false }
        case .fromPastTrip:
            guard selectedSavedGroupId != nil else { return false }
        }
        return !selectedCurrenciesForNewEvent.isEmpty
    }
    
    private func sessionTypeLabel(_ type: SessionType) -> String {
        switch type {
        case .meal: return L10n.string("session.type.meal", language: languageStore.language)
        case .event: return L10n.string("session.type.event", language: languageStore.language)
        case .trip: return L10n.string("session.type.trip", language: languageStore.language)
        case .party: return L10n.string("session.type.party", language: languageStore.language)
        case .other: return L10n.string("session.type.other", language: languageStore.language)
        }
    }
    
    private var currencySelectionSummary: String {
        let n = selectedCurrenciesForNewEvent.count
        let total = Currency.allCases.count
        if n == total { return L10n.string("events.selectAllCurrencies", language: languageStore.language) }
        if n == 0 { return L10n.string("events.noCurrenciesSelected", language: languageStore.language) }
        return String(format: L10n.string("events.currenciesSelectedCount", language: languageStore.language), n)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Page title
                    Text(L10n.string("events.trips", language: languageStore.language))
                        .font(.title.bold())
                        .foregroundColor(.appPrimary)
                    
                    // Add trip / event — under the title, full width
                    Button {
                        newEventName = ""
                        memberSource = .createNew
                        selectedSavedGroupId = nil
                        expandedPastGroupId = nil
                        newMemberNames = []
                        newMemberNameInput = ""
                        selectedCurrenciesForNewEvent = []
                        currencySearchText = ""
                        addEventError = nil
                        showAddEventSheet = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                            Text(L10n.string("events.addEvent", language: languageStore.language))
                                .font(.subheadline.weight(.semibold))
                        }
                        .foregroundColor(Color.appAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.appTertiary.opacity(0.7))
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                    
                    if ongoingEvents.isEmpty && endedEvents.isEmpty {
                        // Empty state: no trips at all
                        VStack(spacing: 16) {
                            Image(systemName: "map.fill")
                                .font(.system(size: 52))
                                .foregroundColor(.appSecondary.opacity(0.6))
                            Text(L10n.string("events.noEvents", language: languageStore.language))
                                .font(.title3.weight(.semibold))
                                .foregroundColor(.appPrimary)
                            Text(L10n.string("events.createFirst", language: languageStore.language))
                                .font(.subheadline)
                                .foregroundColor(.appSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                            Button {
                                newEventName = ""
                                memberSource = .createNew
                                selectedSavedGroupId = nil
                                expandedPastGroupId = nil
                                newMemberNames = []
                                newMemberNameInput = ""
                                selectedCurrenciesForNewEvent = []
                                currencySearchText = ""
                                addEventError = nil
                                showAddEventSheet = true
                            } label: {
                                Label(L10n.string("events.addEvent", language: languageStore.language), systemImage: "plus.circle.fill")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Color.appAccent)
                            .padding(.top, 8)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 48)
                        .padding(.horizontal, 24)
                    } else {
                        // Ongoing section label
                        Text(L10n.string("events.ongoing", language: languageStore.language))
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.appSecondary)
                        
                        // Ongoing trips — clean cards
                        VStack(spacing: 10) {
                            ForEach(ongoingEvents) { event in
                                tripRow(event)
                            }
                        }
                        
                        // Ended trips: tap to show/hide
                        if !endedEvents.isEmpty {
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showEndedTrips.toggle()
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: showEndedTrips ? "chevron.down" : "chevron.right")
                                        .font(.caption.weight(.semibold))
                                        .foregroundColor(.appSecondary)
                                    Text(showEndedTrips
                                         ? L10n.string("events.hideEndedTrips", language: languageStore.language)
                                         : String(format: L10n.string("events.showEndedTrips", language: languageStore.language), endedEvents.count))
                                        .font(.subheadline)
                                        .foregroundColor(.appSecondary)
                                    Spacer()
                                }
                                .padding(.vertical, 12)
                                .padding(.horizontal, 14)
                                .background(Color.appTertiary.opacity(0.5))
                                .cornerRadius(12)
                            }
                            .buttonStyle(.plain)
                            
                            if showEndedTrips {
                                VStack(spacing: 10) {
                                    ForEach(endedEvents) { event in
                                        tripRow(event)
                                    }
                                }
                                .padding(.top, 4)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
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
    
    @ViewBuilder
    private func tripRow(_ event: Event) -> some View {
        Button {
            onSelectTrip?(event)
        } label: {
            HStack(spacing: 14) {
                // Icon
                Image(systemName: event.isOngoing ? "map.fill" : "map")
                    .font(.title3)
                    .foregroundColor(Color.appAccent)
                    .frame(width: 40, height: 40)
                    .background(Color.appAccent.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.name)
                        .font(.headline)
                        .foregroundColor(.appPrimary)
                    Text(event.isOngoing
                         ? String(format: L10n.string("events.expensesCount", language: languageStore.language), dataStore.filteredExpenses(for: event).count)
                         : "\(L10n.string("events.ended", language: languageStore.language)) • \(String(format: L10n.string("events.expensesCount", language: languageStore.language), dataStore.filteredExpenses(for: event).count))")
                        .font(.subheadline)
                        .foregroundColor(.appSecondary)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.appSecondary)
            }
            .padding(16)
            .background(Color.appCard)
            .cornerRadius(16)
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
    
    private var addEventSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let err = addEventError {
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
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L10n.string("events.eventName", language: languageStore.language))
                            .font(.subheadline.bold())
                            .foregroundColor(.appPrimary)
                        TextField(L10n.string("events.eventName", language: languageStore.language), text: $newEventName)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.string("session.typeLabel", language: languageStore.language))
                            .font(.subheadline.bold())
                            .foregroundColor(.appPrimary)
                        Picker("", selection: $selectedSessionType) {
                            ForEach(SessionType.allCases, id: \.self) { type in
                                Text(sessionTypeLabel(type)).tag(type)
                            }
                        }
                        .pickerStyle(.menu)
                        if selectedSessionType == .other {
                            TextField(L10n.string("session.typeOtherPlaceholder", language: languageStore.language), text: $customSessionTypeText)
                                .textFieldStyle(.roundedBorder)
                        }
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
                                    if name.isEmpty { return }
                                    if newMemberNames.contains(where: { $0.lowercased() == name.lowercased() }) {
                                        showDuplicateNameAlert = true
                                        return
                                    }
                                    newMemberNames.append(name)
                                    newMemberNameInput = ""
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(Color.appAccent)
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
                                    .foregroundColor(.appSecondary)
                            }
                        } else {
                            if historyStore.groups.isEmpty {
                                Text(L10n.string("events.noSavedGroups", language: languageStore.language))
                                    .font(.subheadline)
                                    .foregroundColor(.appSecondary)
                                    .padding(.vertical, 8)
                            } else {
                                ForEach(historyStore.groups) { group in
                                    VStack(alignment: .leading, spacing: 0) {
                                        HStack(spacing: 10) {
                                            Button {
                                                if selectedSavedGroupId == group.id {
                                                    selectedSavedGroupId = nil
                                                } else {
                                                    selectedSavedGroupId = group.id
                                                }
                                            } label: {
                                                Image(systemName: selectedSavedGroupId == group.id ? "checkmark.circle.fill" : "circle")
                                                    .foregroundColor(selectedSavedGroupId == group.id ? Color.appAccent : .secondary)
                                                    .font(.body)
                                            }
                                            .buttonStyle(.plain)
                                            Button {
                                                withAnimation(.easeInOut(duration: 0.2)) {
                                                    if expandedPastGroupId == group.id {
                                                        expandedPastGroupId = nil
                                                    } else {
                                                        expandedPastGroupId = group.id
                                                    }
                                                }
                                            } label: {
                                                HStack {
                                                    VStack(alignment: .leading, spacing: 2) {
                                                        Text(group.label)
                                                            .font(.subheadline.bold())
                                                            .foregroundColor(.appPrimary)
                                                        Text(String(format: L10n.string("members.membersCountDate", language: languageStore.language), group.displayMemberNames.count, group.shortDate))
                                                            .font(.caption)
                                                            .foregroundColor(.appSecondary)
                                                    }
                                                    Spacer()
                                                    Image(systemName: expandedPastGroupId == group.id ? "chevron.up" : "chevron.down")
                                                        .font(.caption.bold())
                                                        .foregroundColor(.appSecondary)
                                                }
                                            }
                                            .buttonStyle(.plain)
                                        }
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 10)
                                        .background(Color.appTertiary)
                                        .cornerRadius(8)
                                        if expandedPastGroupId == group.id {
                                            VStack(alignment: .leading, spacing: 4) {
                                                ForEach(group.displayMemberNames, id: \.self) { name in
                                                    Text(name)
                                                        .font(.caption)
                                                        .foregroundColor(.appSecondary)
                                                }
                                            }
                                            .padding(.leading, 10)
                                            .padding(.trailing, 10)
                                            .padding(.bottom, 8)
                                            .padding(.top, 4)
                                        }
                                    }
                                    .background(Color.appTertiary)
                                        .cornerRadius(8)
                                }
                            }
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.string("events.currenciesForTrip", language: languageStore.language))
                            .font(.subheadline.bold())
                            .foregroundColor(.appPrimary)
                        Button {
                            showCurrencyPickerSheet = true
                        } label: {
                            HStack {
                                Text(currencySelectionSummary)
                                    .foregroundColor(Color.appAccent)
                                Spacer()
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.caption)
                                    .foregroundColor(Color.appAccent)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 10)
                            .background(Color.appTertiary)
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .background(Color.appBackground)
            .navigationTitle(L10n.string("events.addEvent", language: languageStore.language))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.string("common.cancel", language: languageStore.language)) { showAddEventSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.string("common.add", language: languageStore.language)) {
                        addEventError = nil
                        let name = newEventName.trimmingCharacters(in: .whitespacesAndNewlines)
                        if name.isEmpty {
                            addEventError = L10n.string("events.errorNameRequired", language: languageStore.language)
                            return
                        }
                        if selectedSessionType == .other, customSessionTypeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            addEventError = L10n.string("events.errorSessionTypeRequired", language: languageStore.language)
                            return
                        }
                        let names: [String]
                        switch memberSource {
                        case .createNew:
                            if newMemberNames.isEmpty {
                                addEventError = L10n.string("events.errorMembersRequired", language: languageStore.language)
                                return
                            }
                            names = newMemberNames
                        case .fromPastTrip:
                            guard let groupId = selectedSavedGroupId,
                                  let group = historyStore.groups.first(where: { $0.id == groupId }) else {
                                addEventError = L10n.string("events.errorMembersRequired", language: languageStore.language)
                                return
                            }
                            names = group.displayMemberNames
                        }
                        if selectedCurrenciesForNewEvent.isEmpty {
                            addEventError = L10n.string("events.errorCurrencyRequired", language: languageStore.language)
                            return
                        }
                        let currencyCodes: [String] = Array(selectedCurrenciesForNewEvent).map(\.rawValue)
                        let existingNames = Set(dataStore.members.map { $0.name })
                        let toAdd = names.filter { !existingNames.contains($0) }
                        if !toAdd.isEmpty {
                            dataStore.addMembersFromHistory(names: toAdd)
                        }
                        let memberIds = dataStore.members.filter { names.contains($0.name) }.map(\.id)
                        let customType = selectedSessionType == .other ? customSessionTypeText.trimmingCharacters(in: .whitespacesAndNewlines) : nil
                        if let newEvent = dataStore.addEvent(name: name, memberIds: memberIds.isEmpty ? nil : memberIds, currencyCodes: currencyCodes, sessionType: selectedSessionType, sessionTypeCustom: customType?.isEmpty == false ? customType : nil) {
                            dataStore.selectedEvent = newEvent
                            UserDefaults.standard.set(newEvent.id, forKey: lastSelectedEventIdKey)
                        }
                        showAddEventSheet = false
                    }
                    .disabled(!canAddNewEvent)
                }
            }
            .sheet(isPresented: $showCurrencyPickerSheet) {
                currencyPickerSheetContent
            }
            .alert(L10n.string("events.sameNameInGroup", language: languageStore.language), isPresented: $showDuplicateNameAlert) {
                Button(L10n.string("common.ok", language: languageStore.language)) { showDuplicateNameAlert = false }
            }
        }
    }
    
    private var filteredCurrenciesForPicker: [Currency] {
        let q = currencySearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return Currency.allCases }
        return Currency.allCases.filter { $0.rawValue.lowercased().contains(q) }
    }
    
    private var currencyPickerSheetContent: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    TextField(L10n.string("events.searchCurrencies", language: languageStore.language), text: $currencySearchText)
                        .textFieldStyle(.roundedBorder)
                        .padding(.bottom, 4)
                    Button {
                        if selectedCurrenciesForNewEvent.count == Currency.allCases.count {
                            selectedCurrenciesForNewEvent = []
                        } else {
                            selectedCurrenciesForNewEvent = Set(Currency.allCases)
                        }
                    } label: {
                        Text(L10n.string("events.selectAllCurrencies", language: languageStore.language))
                            .font(.subheadline)
                            .foregroundColor(Color.appAccent)
                    }
                    VStack(spacing: 6) {
                        ForEach(filteredCurrenciesForPicker, id: \.self) { currency in
                            Button {
                                if selectedCurrenciesForNewEvent.contains(currency) {
                                    selectedCurrenciesForNewEvent.remove(currency)
                                } else {
                                    selectedCurrenciesForNewEvent.insert(currency)
                                }
                            } label: {
                                HStack {
                                    Image(systemName: selectedCurrenciesForNewEvent.contains(currency) ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(selectedCurrenciesForNewEvent.contains(currency) ? Color.appAccent : .appSecondary)
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
            .navigationTitle(L10n.string("events.currenciesForTrip", language: languageStore.language))
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { currencySearchText = "" }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.string("common.done", language: languageStore.language)) {
                        showCurrencyPickerSheet = false
                    }
                }
            }
        }
    }
}

#Preview {
    TripsHomeView()
        .environmentObject(BudgetDataStore())
}
