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
    @StateObject private var themeStore = ThemeStore.shared
    @StateObject private var languageStore = LanguageStore.shared

    init() {
        CurrencyStore.shared.fetchRatesIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            LocalModeView()
                .environmentObject(localDataStore)
                .environment(\.locale, languageStore.locale)
                .preferredColorScheme(themeStore.resolvedColorScheme)
        }
    }
}

let lastSelectedEventIdKey = "BudgetSplitter_lastSelectedEventId"

// Environment: when set, home button uses this instead of store (so parent can force navigation from any tab).
private struct GoToTripListKey: EnvironmentKey {
    static let defaultValue: (() -> Void)? = nil
}
extension EnvironmentValues {
    fileprivate var goToTripList: (() -> Void)? {
        get { self[GoToTripListKey.self] }
        set { self[GoToTripListKey.self] = newValue }
    }
}

// MARK: - Back to session list (returns to first page to choose session)
struct BackToTripsButton: View {
    @EnvironmentObject var dataStore: BudgetDataStore
    @Environment(\.goToTripList) private var goToTripList

    var body: some View {
        Button {
            if let go = goToTripList {
                go()
            } else {
                dataStore.clearSelectedTrip()
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "house.fill")
                Text(L10n.string("events.backToTripList", language: LanguageStore.shared.language))
            }
        }
        .buttonStyle(.plain)
        .foregroundColor(Color(red: 10/255, green: 132/255, blue: 1))
    }
}

// MARK: - Local Mode (no login, device storage)
struct LocalModeView: View {
    @EnvironmentObject var dataStore: BudgetDataStore
    @ObservedObject private var languageStore = LanguageStore.shared
    @State private var selectedTab = 0
    @State private var showSummarySheet = false
    @State private var showAddExpenseSheet = false
    @State private var showSettingsSheet = false
    @State private var hasRestoredTrip = false
    /// When true, show trip list immediately (fixes home button from non-Overview tabs where store update doesn't trigger view switch).
    @State private var forceShowTripList = false

    var body: some View {
        Group {
            if dataStore.selectedEvent == nil || forceShowTripList {
                TripsHomeView(
                    onSelectTab: { selectedTab = $0 },
                    onShowSummary: { showSummarySheet = true },
                    onShowAddExpense: { showAddExpenseSheet = true },
                    onShowSettings: { showSettingsSheet = true },
                    onSelectTrip: { event in
                        dataStore.selectedEvent = event
                        UserDefaults.standard.set(event.id, forKey: lastSelectedEventIdKey)
                    }
                )
                .environmentObject(dataStore)
                .onAppear {
                    forceShowTripList = false
                    guard !hasRestoredTrip else { return }
                    hasRestoredTrip = true
                    guard let id = UserDefaults.standard.string(forKey: lastSelectedEventIdKey),
                          let event = dataStore.events.first(where: { $0.id == id }) else { return }
                    dataStore.selectedEvent = event
                }
            } else if let currentEvent = dataStore.selectedEvent {
                TripTabView(
                    selectedTab: $selectedTab,
                    onShowSummary: { showSummarySheet = true },
                    onShowAddExpense: { showAddExpenseSheet = true }
                )
                .environmentObject(dataStore)
                .environment(\.goToTripList, {
                    forceShowTripList = true
                    dataStore.clearSelectedTrip()
                })
                .id(currentEvent.id)
            }
        }
        .id(dataStore.selectedEvent?.id ?? "trips-home")
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
                            Button(L10n.string("common.done", language: languageStore.language)) {
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
                LocalSettingsView()
                    .environmentObject(dataStore)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button(L10n.string("common.done", language: languageStore.language)) {
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

// MARK: - Tab bar shown only when viewing a trip (Overviews, Expenses, Settle, Members, Settings)
struct TripTabView: View {
    @EnvironmentObject var dataStore: BudgetDataStore
    @ObservedObject private var languageStore = LanguageStore.shared
    @Binding var selectedTab: Int
    var onShowSummary: () -> Void
    var onShowAddExpense: () -> Void

    var body: some View {
        Group {
            if let event = dataStore.selectedEvent {
                TabView(selection: $selectedTab) {
                    NavigationStack {
                        OverviewView(
                            event: event,
                            onSelectTab: { selectedTab = $0 },
                            onShowSummary: onShowSummary,
                            onShowAddExpense: onShowAddExpense
                        )
                        .environmentObject(dataStore)
                    }
                    .tabItem {
                        Image(systemName: "map.fill")
                        Text(L10n.string("tab.overviews", language: languageStore.language))
                    }
                    .tag(0)

                    NavigationStack {
                        ExpensesListView()
                            .environmentObject(dataStore)
                    }
                    .tabItem {
                        Image(systemName: "list.bullet.rectangle.fill")
                        Text(L10n.string("tab.expenses", language: languageStore.language))
                    }
                    .tag(1)

                    NavigationStack {
                        SettleUpView()
                            .environmentObject(dataStore)
                    }
                    .tabItem {
                        Image(systemName: "arrow.left.arrow.right")
                        Text(L10n.string("tab.settleUp", language: languageStore.language))
                    }
                    .tag(2)

                    NavigationStack {
                        MembersView()
                            .environmentObject(dataStore)
                    }
                    .tabItem {
                        Image(systemName: "person.2.fill")
                        Text(L10n.string("tab.members", language: languageStore.language))
                    }
                    .tag(3)

                    NavigationStack {
                        LocalSettingsView()
                            .environmentObject(dataStore)
                    }
                    .tabItem {
                        Image(systemName: "gear")
                        Text(L10n.string("tab.settings", language: languageStore.language))
                    }
                    .tag(4)
                }
                .tint(Color(red: 10/255, green: 132/255, blue: 1))
            } else {
                EmptyView()
            }
        }
    }
}

// MARK: - Local Settings (theme, language, currency)
struct LocalSettingsView: View {
    @EnvironmentObject var dataStore: BudgetDataStore
    @ObservedObject private var themeStore = ThemeStore.shared
    @ObservedObject private var languageStore = LanguageStore.shared
    @ObservedObject private var currencyStore = CurrencyStore.shared

    var body: some View {
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
                    Picker(selection: $themeStore.theme, label: HStack {
                        Image(systemName: "paintbrush.fill")
                            .foregroundColor(.orange)
                        Text(L10n.string("settings.appearance", language: languageStore.language))
                            .font(.headline)
                    }) {
                        ForEach(AppTheme.allCases, id: \.self) { theme in
                            Label(L10n.themeName(theme, language: languageStore.language), systemImage: theme.icon)
                                .tag(theme)
                        }
                    }
                } header: {
                    Text(L10n.string("settings.theme", language: languageStore.language))
                } footer: {
                    Text(L10n.string("settings.theme.footer", language: languageStore.language))
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .navigationTitle(L10n.string("settings.title", language: languageStore.language))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    BackToTripsButton()
                        .environmentObject(dataStore)
                }
            }
            .keyboardDoneButton()
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
