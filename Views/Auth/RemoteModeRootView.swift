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

    var body: some View {
        TabView(selection: $selectedTab) {
            OverviewView(
                onSelectTab: { selectedTab = $0 },
                onShowSummary: { showSummary = true }
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
    }
}

struct RemoteSettingsView: View {
    @EnvironmentObject var auth: AuthService

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Image(systemName: "cloud.fill")
                            .foregroundColor(.blue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Cloud Mode")
                                .font(.headline)
                            Text("Synced with server. Logged in as \(auth.currentUser?.displayName ?? "—")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                Section {
                    Button(role: .destructive) {
                        auth.logout()
                    } label: {
                        Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right")
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
