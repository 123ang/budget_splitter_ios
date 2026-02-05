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
                var groups = try await CloudDataService.shared.fetchGroups()
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
                    paidExpenseMarks: snapshot.paidExpenseMarks
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

    var body: some View {
        Group {
            if dataStore.members.isEmpty {
                HostOnboardingView()
                    .environmentObject(dataStore)
            } else {
                mainTabView
            }
        }
    }

    private var mainTabView: some View {
        TabView(selection: $selectedTab) {
            OverviewView(
                onSelectTab: { selectedTab = $0 },
                onShowSummary: { showSummary = true },
                onShowAddExpense: { showAddExpenseSheet = true }
            )
            .tabItem {
                Image(systemName: "chart.pie.fill")
                Text("Overview")
            }
            .tag(0)

            ExpensesListView()
                .tabItem {
                    Image(systemName: "list.bullet.rectangle.fill")
                    Text("Expenses")
                }
                .tag(1)

            SettleUpView()
                .tabItem {
                    Image(systemName: "arrow.left.arrow.right")
                    Text("Settle up")
                }
                .tag(2)

            MembersView()
                .tabItem {
                    Image(systemName: "person.2.fill")
                    Text("Members")
                }
                .tag(3)

            RemoteSettingsView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
                .tag(4)
        }
        .tint(Color(red: 10/255, green: 132/255, blue: 1))
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
    }
}


struct RemoteSettingsView: View {
    @EnvironmentObject var auth: AuthService
    @ObservedObject private var appMode = AppModeStore.shared
    @ObservedObject private var languageStore = LanguageStore.shared
    @ObservedObject private var currencyStore = CurrencyStore.shared
    @State private var isSwitchingToLocal = false
    @State private var switchToLocalError: String?

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

                Section {
                    CustomRateRow(currencyStore: currencyStore, target: .MYR)
                    CustomRateRow(currencyStore: currencyStore, target: .SGD)
                } header: {
                    Text("Custom rates (when offline)")
                        .font(.caption)
                } footer: {
                    Text("Set 1 JPY = X for each currency. Used when no network.")
                }

                Section {
                    HStack {
                        Image(systemName: "cloud.fill")
                            .foregroundColor(.blue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L10n.string("settings.cloudMode", language: languageStore.language))
                                .font(.headline)
                            Text("Synced with server. Logged in as \(auth.currentUser?.displayName ?? "—")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Section {
                    if let err = switchToLocalError {
                        Text(err)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    Button {
                        switchToLocalError = nil
                        Task { await downloadCloudToLocalThenSwitch() }
                    } label: {
                        HStack {
                            if isSwitchingToLocal {
                                ProgressView()
                                    .scaleEffect(0.9)
                            } else {
                                Image(systemName: "iphone.gen3")
                                    .foregroundColor(.green)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(L10n.string("settings.switchToLocal", language: languageStore.language))
                                    .font(.headline)
                                Text(L10n.string("settings.switchToLocal.desc", language: languageStore.language))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .disabled(isSwitchingToLocal)
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
            .keyboardDoneButton()
        }
    }

    /// Sync: download current cloud group into local SQLite, then switch to local mode.
    private func downloadCloudToLocalThenSwitch() async {
        isSwitchingToLocal = true
        switchToLocalError = nil
        defer { isSwitchingToLocal = false }
        if let gid = CloudStateStore.shared.currentGroupId {
            do {
                let snapshot = try await CloudDataService.shared.fetchSnapshot(groupId: gid)
                await MainActor.run {
                    LocalStorage.shared.saveAll(
                        members: snapshot.members,
                        expenses: snapshot.expenses,
                        selectedMemberIds: snapshot.selectedMemberIds,
                        settledMemberIds: snapshot.settledMemberIds,
                        settlementPayments: snapshot.settlementPayments,
                        paidExpenseMarks: snapshot.paidExpenseMarks
                    )
                }
            } catch {
                await MainActor.run {
                    switchToLocalError = (error as? LocalizedError)?.errorDescription ?? "Could not sync from cloud"
                }
                return
            }
        }
        await MainActor.run {
            appMode.switchToLocalMode()
        }
    }
}
