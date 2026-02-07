//
//  BudgetSplitterApp.swift
//  Exsplitter
//
//  View hierarchy (one root):
//    App → RootView  →  TripsHomeView (trip list)  OR  TripTabView (Overview | Expenses | Settle | Members | Settings)
//

import SwiftUI

@main
struct BudgetSplitterApp: App {
    @StateObject private var localDataStore = BudgetDataStore()
    @StateObject private var themeStore = ThemeStore.shared
    @StateObject private var languageStore = LanguageStore.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(localDataStore)
                .environmentObject(themeStore)
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

// MARK: - Back to trip list (left side only; user does not want right-top button)
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
        .foregroundColor(Color.appAccent)
    }
}

// MARK: - Root (single root view: trip list OR selected trip tabs)
struct RootView: View {
    @EnvironmentObject var dataStore: BudgetDataStore
    @EnvironmentObject var themeStore: ThemeStore
    @ObservedObject private var languageStore = LanguageStore.shared
    @State private var selectedTab = 0
    @State private var showSummarySheet = false
    @State private var showAddExpenseSheet = false
    @State private var showSettingsSheet = false
    @State private var hasRestoredTrip = false
    @State private var forceShowTripList = false
    /// Ignore trip taps for this long after Home tap (stops immediate switch-back).
    @State private var lastHomeTapTime: Date?

    var body: some View {
        return Group {
            if dataStore.selectedEvent == nil || forceShowTripList {
                TripsHomeView(
                    onSelectTab: { selectedTab = $0 },
                    onShowSummary: { showSummarySheet = true },
                    onShowAddExpense: { showAddExpenseSheet = true },
                    onShowSettings: { showSettingsSheet = true },
                    onSelectTrip: { event in
                        if let t = lastHomeTapTime, Date().timeIntervalSince(t) < 0.6 {
                            return
                        }
                        forceShowTripList = false  // only clear when user actually picks a trip
                        dataStore.selectedEvent = event
                        UserDefaults.standard.set(event.id, forKey: lastSelectedEventIdKey)
                        selectedTab = 0  // open trip on Overview first
                    }
                )
                .environmentObject(dataStore)
            } else if let currentEvent = dataStore.selectedEvent {
                TripTabView(
                    selectedTab: $selectedTab,
                    onShowSummary: { showSummarySheet = true },
                    onShowAddExpense: { showAddExpenseSheet = true },
                    onGoToTripList: {
                        lastHomeTapTime = Date()
                        forceShowTripList = true
                        dataStore.clearSelectedTrip()
                    }
                )
                .environmentObject(dataStore)
                .id(currentEvent.id)
            }
        }
        .id("\(dataStore.selectedEvent?.id ?? "trips-home")-\(themeStore.theme.rawValue)")
        .onAppear {
            // Restore last selected trip only once at launch (not when user taps Home to return to list).
            guard !hasRestoredTrip else { return }
            hasRestoredTrip = true
            guard dataStore.selectedEvent == nil,
                  let id = UserDefaults.standard.string(forKey: lastSelectedEventIdKey),
                  let event = dataStore.events.first(where: { $0.id == id }) else {
                return
            }
            dataStore.selectedEvent = event
            selectedTab = 0  // show Overview when restoring trip
        }
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
                            .foregroundColor(Color.appAccent)
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
                            .foregroundColor(Color.appAccent)
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
    /// Same as Overview: go back to trip list. Passed to every tab so home button works from all.
    var onGoToTripList: () -> Void

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
                        .environment(\.goToTripList, onGoToTripList)
                    }
                    .tabItem {
                        Image(systemName: "map.fill")
                        Text(L10n.string("tab.overviews", language: languageStore.language))
                    }
                    .tag(0)

                    NavigationStack {
                        ExpensesListView()
                            .environmentObject(dataStore)
                            .environment(\.goToTripList, onGoToTripList)
                    }
                    .tabItem {
                        Image(systemName: "list.bullet.rectangle.fill")
                        Text(L10n.string("tab.expenses", language: languageStore.language))
                    }
                    .tag(1)

                    NavigationStack {
                        SettleUpView()
                            .environmentObject(dataStore)
                            .environment(\.goToTripList, onGoToTripList)
                    }
                    .tabItem {
                        Image(systemName: "arrow.left.arrow.right")
                        Text(L10n.string("tab.settleUp", language: languageStore.language))
                    }
                    .tag(2)

                    NavigationStack {
                        MembersView()
                            .environmentObject(dataStore)
                            .environment(\.goToTripList, onGoToTripList)
                    }
                    .tabItem {
                        Image(systemName: "person.2.fill")
                        Text(L10n.string("tab.members", language: languageStore.language))
                    }
                    .tag(3)

                    NavigationStack {
                        LocalSettingsView()
                            .environmentObject(dataStore)
                            .environment(\.goToTripList, onGoToTripList)
                    }
                    .tabItem {
                        Image(systemName: "gear")
                        Text(L10n.string("tab.settings", language: languageStore.language))
                    }
                    .tag(4)
                }
                .tint(Color.appAccent)
            } else {
                EmptyView()
            }
        }
    }
}

// MARK: - Local Settings (theme, language)
struct LocalSettingsView: View {
    @EnvironmentObject var dataStore: BudgetDataStore
    @ObservedObject private var themeStore = ThemeStore.shared
    @ObservedObject private var languageStore = LanguageStore.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Language
                settingsCard(
                    icon: "globe",
                    iconColor: Color.appAccent,
                    title: L10n.string("settings.language", language: languageStore.language),
                    content: {
                        Picker(selection: $languageStore.language, label: HStack {
                            Text(L10n.string("settings.language", language: languageStore.language))
                                .foregroundColor(.appPrimary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.appSecondary)
                        }) {
                            ForEach(AppLanguage.allCases) { lang in
                                Text(lang.displayName).tag(lang)
                            }
                        }
                        .pickerStyle(.navigationLink)
                    },
                    footer: L10n.string("settings.language.footer", language: languageStore.language)
                )

                // Theme
                settingsCard(
                    icon: "paintbrush.fill",
                    iconColor: Color.appAccent,
                    title: L10n.string("settings.theme", language: languageStore.language),
                    content: {
                        Picker(selection: $themeStore.theme, label: HStack {
                            Text(L10n.string("settings.appearance", language: languageStore.language))
                                .foregroundColor(.appPrimary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.appSecondary)
                        }) {
                            ForEach(AppTheme.allCases, id: \.self) { theme in
                                Label(L10n.themeName(theme, language: languageStore.language), systemImage: theme.icon)
                                    .tag(theme)
                            }
                        }
                        .pickerStyle(.navigationLink)
                    },
                    footer: L10n.string("settings.theme.footer", language: languageStore.language)
                )
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
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

    private func settingsCard<Content: View, Footer: View>(
        icon: String,
        iconColor: Color,
        title: String,
        @ViewBuilder content: () -> Content,
        @ViewBuilder footer: () -> Footer
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(iconColor)
                Text(title)
                    .font(.headline.bold())
                    .foregroundColor(.appPrimary)
            }
            content()
            footer()
                .font(.caption)
                .foregroundColor(.appSecondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appCard)
        .cornerRadius(14)
    }

    private func settingsCard<Content: View>(
        icon: String,
        iconColor: Color,
        title: String,
        @ViewBuilder content: () -> Content,
        footer: String
    ) -> some View {
        settingsCard(icon: icon, iconColor: iconColor, title: title, content: content) {
            Text(footer)
        }
    }
}
