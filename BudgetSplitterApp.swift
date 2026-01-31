//
//  BudgetSplitterApp.swift
//  BudgetSplitter
//
//  Budget Splitter - Japan Trip 2026
//

import SwiftUI

@main
struct BudgetSplitterApp: App {
    @StateObject private var dataStore = BudgetDataStore()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(dataStore)
        }
    }
}
