//
//  RemoteModeRootView.swift
//  BudgetSplitter
//
//  VPS mode - Shows Login or main app based on auth. Auto-uploads local data on first login.
//

import SwiftUI

struct RemoteModeRootView: View {
    @ObservedObject private var auth = AuthService.shared
    @StateObject private var dataStore = BudgetDataStore(useLocalStorage: false)
    @State private var cloudLoadError: String?
    @State private var isCloudLoading = false

    var body: some View {
        Group {
            if !auth.isAuthenticated {
                LoginView()
            } else if isCloudLoading {
                cloudLoadingView
            } else if let err = cloudLoadError {
                cloudErrorView(err)
            } else {
                RemoteMainView()
                    .environmentObject(dataStore)
                    .environmentObject(auth)
            }
        }
        .animation(.easeInOut, value: auth.isAuthenticated)
        .task(id: auth.isAuthenticated) {
            guard auth.isAuthenticated else {
                CloudStateStore.shared.clear()
                return
            }
            await loadCloudState()
        }
    }

    private var cloudLoadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Syncing with cloud…")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
    }

    private func cloudErrorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.orange)
            Text("Could not load cloud data")
                .font(.headline)
                .foregroundColor(.appPrimary)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button("Retry") {
                cloudLoadError = nil
                Task { await loadCloudState() }
            }
            .fontWeight(.semibold)
            .foregroundColor(Color(red: 10/255, green: 132/255, blue: 1))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
    }

    private func loadCloudState() async {
        isCloudLoading = true
        cloudLoadError = nil
        defer { isCloudLoading = false }
        do {
            let localSnapshot = LocalStorage.shared.loadAll()
            let groupId: String
            if !localSnapshot.members.isEmpty {
                groupId = try await CloudDataService.shared.uploadLocalToCloud(snapshot: localSnapshot, groupName: nil)
                CloudStateStore.shared.currentGroupId = groupId
            } else {
                let groups = try await CloudDataService.shared.fetchGroups()
                if let saved = CloudStateStore.shared.currentGroupId, groups.contains(where: { $0.id == saved }) {
                    groupId = saved
                } else if let first = groups.first?.id {
                    groupId = first
                    CloudStateStore.shared.currentGroupId = first
                } else {
                    groupId = try await CloudDataService.shared.createGroup(name: "My Trip", description: nil)
                    CloudStateStore.shared.currentGroupId = groupId
                }
            }
            let snapshot = try await CloudDataService.shared.fetchSnapshot(groupId: groupId)
            await MainActor.run {
                dataStore.cloudGroupId = groupId
                dataStore.setSnapshot(snapshot)
                // Write-through: keep local SQLite in sync so "Switch to Local" has latest
                LocalStorage.shared.saveAll(
                    members: snapshot.members,
                    expenses: snapshot.expenses,
                    selectedMemberIds: snapshot.selectedMemberIds,
                    settledMemberIds: snapshot.settledMemberIds,
                    settlementPayments: snapshot.settlementPayments,
                    paidExpenseMarks: snapshot.paidExpenseMarks,
                    events: snapshot.events
                )
            }
        } catch {
            await MainActor.run {
                cloudLoadError = (error as? LocalizedError)?.errorDescription ?? "Network error"
            }
        }
    }
}

struct RemoteMainView: View {
    @EnvironmentObject var dataStore: BudgetDataStore
    @EnvironmentObject var auth: AuthService
    @State private var selectedTab = 0
    @State private var showSummary = false
    @State private var showAddExpenseSheet = false
    @State private var showSettingsSheet = false
    @State private var showTripPickerSheet = false
    @State private var hasRestoredTrip = false

    var body: some View {
        Group {
            if dataStore.selectedEvent == nil {
                TripsHomeView(
                    onSelectTab: { selectedTab = $0 },
                    onShowSummary: { showSummary = true },
                    onShowAddExpense: { showAddExpenseSheet = true },
                    onShowSettings: { showSettingsSheet = true },
                    onSelectTrip: { event in
                        dataStore.selectedEvent = event
                        UserDefaults.standard.set(event.id, forKey: lastSelectedEventIdKey)
                    }
                )
                .environmentObject(dataStore)
                .onAppear {
                    guard !hasRestoredTrip else { return }
                    hasRestoredTrip = true
                    guard let id = UserDefaults.standard.string(forKey: lastSelectedEventIdKey),
                          let event = dataStore.events.first(where: { $0.id == id }) else { return }
                    dataStore.selectedEvent = event
                }
            } else {
                RemoteTripTabView(
                    event: dataStore.selectedEvent!,
                    selectedTab: $selectedTab,
                    onShowSummary: { showSummary = true },
                    onShowAddExpense: { showAddExpenseSheet = true }
                )
                .environmentObject(dataStore)
                .environmentObject(auth)
            }
        }
        .onChange(of: dataStore.showTripPicker) { _, new in
            showTripPickerSheet = new
        }
        .sheet(isPresented: $showTripPickerSheet) {
            TripPickerSheet()
                .environmentObject(dataStore)
                .onDisappear {
                    dataStore.showTripPicker = false
                }
        }
        .sheet(isPresented: $showSummary) {
            SummarySheetView()
                .environmentObject(dataStore)
        }
        .sheet(isPresented: $showAddExpenseSheet) {
            NavigationStack {
                AddExpenseView()
                    .environmentObject(dataStore)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                showAddExpenseSheet = false
                            }
                            .fontWeight(.semibold)
                            .foregroundColor(Color(red: 10/255, green: 132/255, blue: 1))
                        }
                    }
            }
        }
        .sheet(isPresented: $showSettingsSheet) {
            NavigationStack {
                RemoteSettingsView()
                    .environmentObject(dataStore)
                    .environmentObject(auth)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                showSettingsSheet = false
                            }
                            .fontWeight(.semibold)
                            .foregroundColor(Color(red: 10/255, green: 132/255, blue: 1))
                        }
                    }
            }
        }
    }
}

struct RemoteTripTabView: View {
    @EnvironmentObject var dataStore: BudgetDataStore
    @ObservedObject private var languageStore = LanguageStore.shared
    let event: Event
    @Binding var selectedTab: Int
    var onShowSummary: () -> Void
    var onShowAddExpense: () -> Void

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                OverviewView(
                    event: event,
                    onSelectTab: { selectedTab = $0 },
                    onShowSummary: onShowSummary,
                    onShowAddExpense: onShowAddExpense
                )
                .environmentObject(dataStore)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        BackToTripsButton()
                            .environmentObject(dataStore)
                    }
                }
            }
            .tabItem {
                Image(systemName: "map.fill")
                Text(L10n.string("tab.overviews", language: languageStore.language))
            }
            .tag(0)

            ExpensesListView()
                .environmentObject(dataStore)
                .tabItem {
                    Image(systemName: "list.bullet.rectangle.fill")
                    Text(L10n.string("tab.expenses", language: languageStore.language))
                }
                .tag(1)

            SettleUpView()
                .environmentObject(dataStore)
                .tabItem {
                    Image(systemName: "arrow.left.arrow.right")
                    Text(L10n.string("tab.settleUp", language: languageStore.language))
                }
                .tag(2)

            MembersView()
                .environmentObject(dataStore)
                .tabItem {
                    Image(systemName: "person.2.fill")
                    Text(L10n.string("tab.members", language: languageStore.language))
                }
                .tag(3)

            RemoteSettingsView()
                .environmentObject(dataStore)
                .tabItem {
                    Image(systemName: "gear")
                    Text(L10n.string("tab.settings", language: languageStore.language))
                }
                .tag(4)
        }
        .tint(Color(red: 10/255, green: 132/255, blue: 1))
    }
}


struct RemoteSettingsView: View {
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var dataStore: BudgetDataStore
    @ObservedObject private var appMode = AppModeStore.shared
    @ObservedObject private var languageStore = LanguageStore.shared
    @ObservedObject private var currencyStore = CurrencyStore.shared

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker(selection: $languageStore.language, label: HStack {
                        Image(systemName: "globe")
                            .foregroundColor(Color(red: 10/255, green: 132/255, blue: 1))
                        Text(L10n.string("settings.language", language: languageStore.language))
                            .font(.headline)
                    }) {
                        ForEach(AppLanguage.allCases) { lang in
                            Text(lang.displayName).tag(lang)
                        }
                    }
                    .pickerStyle(.navigationLink)
                } header: {
                    Text(L10n.string("settings.language", language: languageStore.language))
                } footer: {
                    Text(L10n.string("settings.language.footer", language: languageStore.language))
                }

                Section {
                    Picker(selection: $currencyStore.preferredCurrency, label: HStack {
                        Image(systemName: "dollarsign.circle")
                            .foregroundColor(.green)
                        Text(L10n.string("settings.currency", language: languageStore.language))
                            .font(.headline)
                    }) {
                        ForEach(Currency.allCases, id: \.self) { curr in
                            Text("\(curr.symbol) \(curr.rawValue)").tag(curr)
                        }
                    }
                    .pickerStyle(.navigationLink)
                    .onAppear {
                        currencyStore.fetchRatesIfNeeded()
                    }
                } header: {
                    Text(L10n.string("settings.currency", language: languageStore.language))
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.string("settings.currency.footer", language: languageStore.language))
                        if !currencyStore.lastFetchSucceeded {
                            Text(L10n.string("settings.currency.offline", language: languageStore.language))
                                .foregroundColor(.orange)
                        }
                    }
                }

                if !currencyStore.lastFetchSucceeded || !currencyStore.customRates.isEmpty {
                    Section {
                        CustomRateRow(currencyStore: currencyStore, target: .MYR)
                        CustomRateRow(currencyStore: currencyStore, target: .SGD)
                    } header: {
                        Text(L10n.string("settings.customRatesWhenOffline", language: languageStore.language))
                            .font(.caption)
                    } footer: {
                        Text(L10n.string("settings.customRatesFooter", language: languageStore.language))
                    }
                }

                Section {
                    Picker(selection: Binding(
                        get: { appMode.useRemoteAPI ? StorageMode.cloud : StorageMode.local },
                        set: { if $0 == .cloud { appMode.switchToCloudMode() } else { appMode.switchToLocalMode() } }
                    ), label: HStack {
                        Image(systemName: "externaldrive.fill")
                            .foregroundColor(.secondary)
                        Text(L10n.string("settings.storage", language: languageStore.language))
                            .font(.headline)
                    }) {
                        Text(L10n.string("settings.localMode", language: languageStore.language)).tag(StorageMode.local)
                        Text(L10n.string("settings.cloudSync", language: languageStore.language)).tag(StorageMode.cloud)
                    }
                    .pickerStyle(.navigationLink)
                } header: {
                    Text(L10n.string("settings.storage", language: languageStore.language))
                } footer: {
                    Text(L10n.string("settings.storage.footer", language: languageStore.language))
                }

                Section {
                    Button(role: .destructive) {
                        auth.logout()
                    } label: {
                        Label(L10n.string("settings.logOut", language: languageStore.language), systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .background(Color.appBackground)
            .scrollContentBackground(.hidden)
            .navigationTitle(L10n.string("settings.title", language: languageStore.language))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if dataStore.selectedEvent != nil {
                    ToolbarItem(placement: .cancellationAction) {
                        BackToTripsButton()
                            .environmentObject(dataStore)
                    }
                }
            }
            .keyboardDoneButton()
        }
    }
}
