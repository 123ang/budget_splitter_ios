//
//  BudgetSplitterApp.swift
//  Exsplitter
//
//  Budget Splitter - Local (SQLite) & VPS (PostgreSQL) modes
//  Mode can be switched in Settings. Cloud mode requires subscription.
//

import SwiftUI

@main
struct BudgetSplitterApp: App {
    @StateObject private var localDataStore = BudgetDataStore()
    @StateObject private var appMode = AppModeStore.shared
    @StateObject private var themeStore = ThemeStore.shared
    @StateObject private var languageStore = LanguageStore.shared

    init() {
        CurrencyStore.shared.fetchRatesIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if appMode.useRemoteAPI {
                    RemoteModeRootView()
                } else {
                    LocalModeView()
                        .environmentObject(localDataStore)
                }
            }
            .environment(\.locale, languageStore.locale)
            .preferredColorScheme(themeStore.resolvedColorScheme)
        }
    }
}

// MARK: - Local Mode (no login, device storage)
struct LocalModeView: View {
    @EnvironmentObject var dataStore: BudgetDataStore
    @State private var selectedTab = 0
    @State private var showSummarySheet = false
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
                onShowSummary: { showSummarySheet = true },
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

            LocalSettingsView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
                .tag(4)
        }
        .tint(Color(red: 10/255, green: 132/255, blue: 1))
        .sheet(isPresented: $showSummarySheet) {
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

// MARK: - New user: first screen is "Who is the host?"
struct HostOnboardingView: View {
    @EnvironmentObject var dataStore: BudgetDataStore
    @State private var hostNameInput = ""

    private let iosBlue = Color(red: 10/255, green: 132/255, blue: 1)

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Who is the host? Enter the first member's name. This person will be the only member until you add more.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                TextField("e.g. John", text: $hostNameInput)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)
                    .autocapitalization(.words)
                Spacer()
            }
            .padding()
            .background(Color.appBackground)
            .navigationTitle("Who is the host?")
            .navigationBarTitleDisplayMode(.inline)
            .keyboardDoneButton()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        let name = hostNameInput.trimmingCharacters(in: .whitespacesAndNewlines)
                        dataStore.addMember(name.isEmpty ? "Member 1" : name)
                        hostNameInput = ""
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(iosBlue)
                    .disabled(hostNameInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

// MARK: - Local Settings (theme, mode toggle)
struct LocalSettingsView: View {
    @ObservedObject private var appMode = AppModeStore.shared
    @ObservedObject private var themeStore = ThemeStore.shared
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
                    Picker(selection: $themeStore.theme, label: HStack {
                        Image(systemName: "paintbrush.fill")
                            .foregroundColor(.orange)
                        Text(L10n.string("settings.appearance", language: languageStore.language))
                            .font(.headline)
                    }) {
                        ForEach(AppTheme.allCases, id: \.self) { theme in
                            Label(theme.displayName, systemImage: theme.icon)
                                .tag(theme)
                        }
                    }
                } header: {
                    Text(L10n.string("settings.theme", language: languageStore.language))
                } footer: {
                    Text(L10n.string("settings.theme.footer", language: languageStore.language))
                }

                Section {
                    HStack {
                        Image(systemName: "iphone.gen3")
                            .foregroundColor(.green)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L10n.string("settings.localMode", language: languageStore.language))
                                .font(.headline)
                            Text(L10n.string("settings.localMode.desc", language: languageStore.language))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Section {
                    Button {
                        appMode.switchToCloudMode()
                    } label: {
                        HStack {
                            Image(systemName: "cloud.fill")
                                .foregroundColor(.blue)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(L10n.string("settings.switchToCloud", language: languageStore.language))
                                    .font(.headline)
                                Text(L10n.string("settings.switchToCloud.desc", language: languageStore.language))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .navigationTitle(L10n.string("settings.title", language: languageStore.language))
            .navigationBarTitleDisplayMode(.inline)
            .keyboardDoneButton()
        }
    }
}

// MARK: - Custom rate row (when offline)
struct CustomRateRow: View {
    @ObservedObject var currencyStore: CurrencyStore
    let target: Currency
    @State private var text: String = ""

    var body: some View {
        HStack {
            Text("1 JPY = ")
                .font(.subheadline)
                .foregroundColor(.secondary)
            TextField(target.rawValue, text: $text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .onChange(of: text) { _, new in
                    if let val = Double(new.replacingOccurrences(of: ",", with: "")), val > 0 {
                        currencyStore.setCustomRate(currency: target, rateFromJPY: val)
                    } else if new.isEmpty {
                        currencyStore.clearCustomRate(currency: target)
                    }
                }
            Text(target.rawValue)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .onAppear {
            if let r = currencyStore.customRates[target.rawValue] {
                text = r == Double(Int(r)) ? "\(Int(r))" : String(format: "%.4f", r)
            }
        }
    }
}
