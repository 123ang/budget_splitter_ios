//
//  BudgetSplitterApp.swift
//  BudgetSplitter
//
//  Budget Splitter - Local (SQLite) & VPS (PostgreSQL) modes
//  Mode can be switched in Settings. Cloud mode requires subscription.
//

import SwiftUI

@main
struct BudgetSplitterApp: App {
    @StateObject private var localDataStore = BudgetDataStore()
    @StateObject private var appMode = AppModeStore.shared

    var body: some Scene {
        WindowGroup {
            if appMode.useRemoteAPI {
                RemoteModeRootView()
            } else {
                LocalModeView()
                    .environmentObject(localDataStore)
            }
        }
    }
}

// MARK: - Local Mode (no login, device storage)
struct LocalModeView: View {
    @EnvironmentObject var dataStore: BudgetDataStore
    @State private var selectedTab = 0
    @State private var showSummarySheet = false

    var body: some View {
        TabView(selection: $selectedTab) {
            OverviewView(
                onSelectTab: { selectedTab = $0 },
                onShowSummary: { showSummarySheet = true }
            )
            .tabItem {
                Image(systemName: "chart.pie.fill")
                Text("Overview")
            }
            .tag(0)

            AddExpenseView()
                .tabItem {
                    Image(systemName: "plus.circle.fill")
                    Text("Add")
                }
                .tag(1)

            ExpensesListView()
                .tabItem {
                    Image(systemName: "list.bullet.rectangle.fill")
                    Text("Expenses")
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
    }
}

// MARK: - Local Settings (mode toggle, subscription hidden for now)
struct LocalSettingsView: View {
    @ObservedObject private var appMode = AppModeStore.shared

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Image(systemName: "iphone.gen3")
                            .foregroundColor(.green)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Local Mode")
                                .font(.headline)
                            Text("Data stored on this device. No login required.")
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
                                Text("Switch to Cloud Sync")
                                    .font(.headline)
                                Text("Sync data across devices")
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
            .background(Color.black)
            .scrollContentBackground(.hidden)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
