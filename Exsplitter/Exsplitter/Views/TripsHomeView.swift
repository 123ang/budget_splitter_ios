//
//  TripsHomeView.swift
//  Xsplitter
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
    /// When adding from past trip, which member names from the selected group are included (user can deselect).
    @State private var selectedMemberNamesFromPastGroup: Set<String> = []
    @State private var newMemberNames: [String] = []
    @State private var newMemberNameInput: String = ""
    @State private var mainCurrencyForNewEvent: Currency = .JPY
    @State private var subCurrencyEntriesForNewEvent: [SubCurrencyEntry] = []
    @State private var addEventError: String? = nil
    @State private var eventToRemove: Event? = nil
    @State private var selectedSessionType: SessionType = .trip
    @State private var customSessionTypeText: String = ""
    @State private var showEndedTrips = false
    @State private var expandedPastGroupId: UUID? = nil
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
            guard selectedSavedGroupId != nil, !selectedMemberNamesFromPastGroup.isEmpty else { return false }
        }
        for entry in subCurrencyEntriesForNewEvent {
            guard let rate = Double(entry.rateText.replacingOccurrences(of: ",", with: "")), rate > 0 else { return false }
        }
        return true
    }
    
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
        selectedSessionType == .trip
            ? L10n.string("events.tripName", language: languageStore.language)
            : L10n.string("events.eventNameLabel", language: languageStore.language)
    }
    
    /// Display label for an event's purpose (e.g. "Trip", "Meal"; for .other uses custom text if set).
    private func eventPurposeLabel(_ event: Event) -> String {
        if event.sessionType == .other, let custom = event.sessionTypeCustom?.trimmingCharacters(in: .whitespacesAndNewlines), !custom.isEmpty {
            return custom
        }
        return sessionTypeLabel(event.sessionType)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Page title
                    Text(L10n.string("events.trips", language: languageStore.language))
                        .font(.title.bold())
                        .foregroundColor(.appPrimary)
                    
                    // Add activity — under the title, full width
                    Button {
                        newEventName = ""
                        memberSource = .createNew
                        selectedSavedGroupId = nil
                        expandedPastGroupId = nil
                        selectedMemberNamesFromPastGroup = []
                        newMemberNames = []
                        newMemberNameInput = ""
                        mainCurrencyForNewEvent = .JPY
                        subCurrencyEntriesForNewEvent = []
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
                                selectedMemberNamesFromPastGroup = []
                                newMemberNames = []
                                newMemberNameInput = ""
                                mainCurrencyForNewEvent = .JPY
                                subCurrencyEntriesForNewEvent = []
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
            .confirmationDialog(L10n.string("events.removeSession", language: languageStore.language), isPresented: Binding(get: { eventToRemove != nil }, set: { if !$0 { eventToRemove = nil } }), titleVisibility: .visible) {
                Button(L10n.string("events.removeSession", language: languageStore.language), role: .destructive) {
                    if let event = eventToRemove {
                        dataStore.removeEvent(id: event.id)
                        eventToRemove = nil
                    }
                }
                Button(L10n.string("common.cancel", language: languageStore.language), role: .cancel) {
                    eventToRemove = nil
                }
            } message: {
                Text(L10n.string("events.removeSessionConfirm", language: languageStore.language))
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
                    HStack(spacing: 6) {
                        Text(eventPurposeLabel(event))
                            .font(.caption)
                            .foregroundColor(.appAccent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.appAccent.opacity(0.12))
                            .cornerRadius(4)
                        Text(event.isOngoing
                             ? String(format: L10n.string("events.expensesCount", language: languageStore.language), dataStore.filteredExpenses(for: event).count)
                             : "\(L10n.string("events.ended", language: languageStore.language)) • \(String(format: L10n.string("events.expensesCount", language: languageStore.language), dataStore.filteredExpenses(for: event).count))")
                            .font(.subheadline)
                            .foregroundColor(.appSecondary)
                    }
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
                Label(L10n.string("events.removeSession", language: languageStore.language), systemImage: "trash")
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
                    // Purpose first so user picks Trip / Meal / Event / Others before naming
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.string("events.purpose", language: languageStore.language))
                            .font(.subheadline.bold())
                            .foregroundColor(.appPrimary)
                        Text(L10n.string("events.purposeHint", language: languageStore.language))
                            .font(.caption)
                            .foregroundColor(.appSecondary)
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
                    VStack(alignment: .leading, spacing: 6) {
                        Text(nameFieldLabel)
                            .font(.subheadline.bold())
                            .foregroundColor(.appPrimary)
                        TextField(nameFieldLabel, text: $newEventName)
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
                                                    selectedMemberNamesFromPastGroup = []
                                                } else {
                                                    selectedSavedGroupId = group.id
                                                    selectedMemberNamesFromPastGroup = Set(group.displayMemberNames)
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
                                                Text(L10n.string("events.selectMembersFromGroup", language: languageStore.language))
                                                    .font(.caption.bold())
                                                    .foregroundColor(.appSecondary)
                                                    .padding(.bottom, 4)
                                                ForEach(group.displayMemberNames, id: \.self) { name in
                                                    Button {
                                                        if selectedSavedGroupId != group.id {
                                                            selectedSavedGroupId = group.id
                                                            selectedMemberNamesFromPastGroup = [name]
                                                        } else if selectedMemberNamesFromPastGroup.contains(name) {
                                                            selectedMemberNamesFromPastGroup.remove(name)
                                                        } else {
                                                            selectedMemberNamesFromPastGroup.insert(name)
                                                        }
                                                    } label: {
                                                        HStack(spacing: 8) {
                                                            Image(systemName: selectedSavedGroupId == group.id && selectedMemberNamesFromPastGroup.contains(name) ? "checkmark.square.fill" : "square")
                                                                .foregroundColor(selectedSavedGroupId == group.id && selectedMemberNamesFromPastGroup.contains(name) ? Color.appAccent : .appSecondary)
                                                                .font(.body)
                                                            Text(name)
                                                                .font(.subheadline)
                                                                .foregroundColor(.appPrimary)
                                                            Spacer()
                                                        }
                                                        .padding(.vertical, 4)
                                                        .padding(.horizontal, 4)
                                                    }
                                                    .buttonStyle(.plain)
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
                        Text(L10n.string("events.mainCurrency", language: languageStore.language))
                            .font(.subheadline.bold())
                            .foregroundColor(.appPrimary)
                        Picker("", selection: $mainCurrencyForNewEvent) {
                            ForEach(Currency.allCases, id: \.self) { curr in
                                Text("\(curr.symbol) \(curr.rawValue)").tag(curr)
                            }
                        }
                        .pickerStyle(.menu)
                        .onChange(of: mainCurrencyForNewEvent) { _, newMain in
                            subCurrencyEntriesForNewEvent.removeAll { $0.currency == newMain }
                        }
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.string("events.subCurrency", language: languageStore.language))
                            .font(.subheadline.bold())
                            .foregroundColor(.appPrimary)
                        Text(L10n.string("events.subCurrenciesHint", language: languageStore.language))
                            .font(.caption)
                            .foregroundColor(.appSecondary)
                        ForEach(subCurrencyEntriesForNewEvent) { entry in
                            SubCurrencyRowView(
                                entry: bindingForSubCurrencyEntry(entry),
                                mainCurrency: mainCurrencyForNewEvent,
                                allSelected: subCurrencyEntriesForNewEvent.map(\.currency),
                                onRemove: subCurrencyEntriesForNewEvent.count > 1 ? { subCurrencyEntriesForNewEvent.removeAll { $0.id == entry.id } } : nil
                            )
                        }
                        if subCurrencyEntriesForNewEvent.count < 3 {
                            Button {
                                let available = Currency.allCases.filter { $0 != mainCurrencyForNewEvent && !subCurrencyEntriesForNewEvent.map(\.currency).contains($0) }
                                subCurrencyEntriesForNewEvent.append(SubCurrencyEntry(currency: available.first ?? .USD, rateText: ""))
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
            .navigationTitle(L10n.string("events.activitiesTitle", language: languageStore.language))
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
                            if selectedMemberNamesFromPastGroup.isEmpty {
                                addEventError = L10n.string("events.errorMembersRequired", language: languageStore.language)
                                return
                            }
                            names = group.displayMemberNames.filter { selectedMemberNamesFromPastGroup.contains($0) }
                        }
                        let ratesDict: [String: Double]? = {
                            var d: [String: Double] = [:]
                            for entry in subCurrencyEntriesForNewEvent {
                                guard let rate = Double(entry.rateText.replacingOccurrences(of: ",", with: "")), rate > 0 else {
                                    addEventError = L10n.string("events.errorExchangeRateRequired", language: languageStore.language)
                                    return nil
                                }
                                d[entry.currency.rawValue] = rate
                            }
                            return d.isEmpty ? nil : d
                        }()
                        if addEventError != nil { return }
                        let existingNames = Set(dataStore.members.map { $0.name })
                        let toAdd = names.filter { !existingNames.contains($0) }
                        if !toAdd.isEmpty {
                            dataStore.addMembersFromHistory(names: toAdd)
                        }
                        let memberIds = dataStore.members.filter { names.contains($0.name) }.map(\.id)
                        let customType = selectedSessionType == .other ? customSessionTypeText.trimmingCharacters(in: .whitespacesAndNewlines) : nil
                        if let newEvent = dataStore.addEvent(name: name, memberIds: memberIds.isEmpty ? nil : memberIds, mainCurrency: mainCurrencyForNewEvent, subCurrencyRatesByCode: ratesDict, sessionType: selectedSessionType, sessionTypeCustom: customType?.isEmpty == false ? customType : nil) {
                            dataStore.selectedEvent = newEvent
                            UserDefaults.standard.set(newEvent.id, forKey: lastSelectedEventIdKey)
                        }
                        showAddEventSheet = false
                    }
                    .disabled(!canAddNewEvent)
                }
            }
            .alert(L10n.string("events.sameNameInGroup", language: languageStore.language), isPresented: $showDuplicateNameAlert) {
                Button(L10n.string("common.ok", language: languageStore.language)) { showDuplicateNameAlert = false }
            }
        }
    }
    
    private func bindingForSubCurrencyEntry(_ entry: SubCurrencyEntry) -> Binding<SubCurrencyEntry> {
        Binding(
            get: { subCurrencyEntriesForNewEvent.first(where: { $0.id == entry.id }) ?? entry },
            set: { new in
                if let i = subCurrencyEntriesForNewEvent.firstIndex(where: { $0.id == entry.id }) {
                    subCurrencyEntriesForNewEvent[i] = new
                }
            }
        )
    }
}

struct SubCurrencyEntry: Identifiable {
    let id = UUID()
    var currency: Currency
    var rateText: String
}

struct SubCurrencyRowView: View {
    @Binding var entry: SubCurrencyEntry
    var mainCurrency: Currency
    /// All currencies already selected in other rows (including this one) for picker exclusion.
    var allSelected: [Currency]
    var onRemove: (() -> Void)?
    @ObservedObject private var languageStore = LanguageStore.shared
    
    /// Currencies available for this row: exclude main and any currency already chosen in another row.
    private var pickerCurrencies: [Currency] {
        let otherSelected = allSelected.filter { $0 != entry.currency }
        return Currency.allCases.filter { $0 != mainCurrency && !otherSelected.contains($0) }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Menu {
                    ForEach(pickerCurrencies, id: \.self) { curr in
                        Button {
                            entry.currency = curr
                        } label: {
                            HStack {
                                Text("\(curr.symbol) \(curr.rawValue)")
                                if curr == entry.currency {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.appAccent)
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Text(entry.currency.symbol)
                            .font(.title2)
                            .foregroundColor(.appAccent)
                        Text(entry.currency.rawValue)
                            .font(.subheadline.bold())
                            .foregroundColor(.appPrimary)
                        Spacer()
                        Image(systemName: "chevron.down.circle.fill")
                            .font(.body)
                            .foregroundColor(.appSecondary)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 14)
                    .background(Color.appCard)
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
                if let onRemove = onRemove {
                    Button {
                        onRemove()
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(String(format: L10n.string("events.exchangeRateLabel", language: languageStore.language), entry.currency.rawValue, mainCurrency.rawValue))
                    .font(.subheadline)
                    .foregroundColor(.appPrimary)
                HStack(spacing: 10) {
                    TextField("0", text: $entry.rateText)
                        .keyboardType(.decimalPad)
                        .font(.body)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(Color.appCard)
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.appTertiary, lineWidth: 1)
                        )
                    Text(mainCurrency.rawValue)
                        .font(.subheadline.bold())
                        .foregroundColor(.appSecondary)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appTertiary.opacity(0.6))
        .cornerRadius(12)
    }
}

#Preview {
    TripsHomeView()
        .environmentObject(BudgetDataStore())
}
