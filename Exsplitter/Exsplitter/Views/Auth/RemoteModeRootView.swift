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
