//
//  ContentView.swift
//  BudgetSplitter
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var dataStore: BudgetDataStore
    @State private var selectedTab = 0
    @State private var showSummarySheet = false
    
    var body: some View {
        TabView(selection: $selectedTab) {
            TripsHomeView(
                onSelectTab: { tab in
                    selectedTab = tab
                },
                onShowSummary: { showSummarySheet = true },
                onShowAddExpense: { selectedTab = 1 }
            )
                .tabItem {
                    Image(systemName: "map.fill")
                    Text(L10n.string("tab.trips"))
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
        }
        .tint(Color.appAccent)
        .sheet(isPresented: $showSummarySheet) {
            SummarySheetView()
                .environmentObject(dataStore)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(BudgetDataStore())
}
