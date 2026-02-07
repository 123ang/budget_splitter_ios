//
//  RemoteModeRootView.swift
//  BudgetSplitter
//
//  VPS mode - Shows Login or main app based on auth
//

import SwiftUI

struct RemoteModeRootView: View {
    @StateObject private var auth = AuthService.shared
    @StateObject private var dataStore = BudgetDataStore()

    var body: some View {
        Group {
            if auth.isAuthenticated {
                RemoteMainView()
                    .environmentObject(dataStore)
                    .environmentObject(auth)
            } else {
                LoginView()
            }
        }
        .animation(.easeInOut, value: auth.isAuthenticated)
    }
}

struct RemoteMainView: View {
    @EnvironmentObject var dataStore: BudgetDataStore
    @EnvironmentObject var auth: AuthService
    @State private var selectedTab = 0
    @State private var showSummary = false
    @State private var showAddExpenseSheet = false

    var body: some View {
        TabView(selection: $selectedTab) {
            OverviewView(
                onSelectTab: { selectedTab = $0 },
                onShowSummary: { showSummary = true },
                onShowAddExpense: { showAddExpenseSheet = true }
            )
            .tabItem {
                Image(systemName: "chart.pie.fill")
                Text(L10n.string("tab.overview"))
            }
            .tag(0)

            ExpensesListView()
                .tabItem {
                    Image(systemName: "list.bullet.rectangle.fill")
                    Text(L10n.string("tab.expenses"))
                }
                .tag(1)

            SettleUpView()
                .tabItem {
                    Image(systemName: "arrow.left.arrow.right")
                    Text(L10n.string("tab.settleUp"))
                }
                .tag(2)

            MembersView()
                .tabItem {
                    Image(systemName: "person.2.fill")
                    Text(L10n.string("tab.members"))
                }
                .tag(3)

            RemoteSettingsView()
                .tabItem {
                    Image(systemName: "gear")
                    Text(L10n.string("tab.settings"))
                }
                .tag(4)
        }
        .tint(Color.appAccent)
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
                            Button(L10n.string("common.done")) {
                                showAddExpenseSheet = false
                            }
                            .fontWeight(.semibold)
                            .foregroundColor(Color.appAccent)
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

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker(selection: $languageStore.language, label: HStack {
                        Image(systemName: "globe")
                            .foregroundColor(Color.appAccent)
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
                    Text(L10n.string("settings.customRatesWhenOffline", language: languageStore.language))
                        .font(.caption)
                } footer: {
                    Text(L10n.string("settings.customRatesFooter", language: languageStore.language))
                }

                Section {
                    HStack {
                        Image(systemName: "cloud.fill")
                            .foregroundColor(.blue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L10n.string("settings.cloudMode", language: languageStore.language))
                                .font(.headline)
                            Text(String(format: L10n.string("auth.syncedAs", language: languageStore.language), auth.currentUser?.displayName ?? "—"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Section {
                    Button {
                        appMode.switchToLocalMode()
                    } label: {
                        HStack {
                            Image(systemName: "iphone.gen3")
                                .foregroundColor(.green)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(L10n.string("settings.switchToLocal", language: languageStore.language))
                                    .font(.headline)
                                Text(L10n.string("settings.switchToLocal.desc", language: languageStore.language))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
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
}
