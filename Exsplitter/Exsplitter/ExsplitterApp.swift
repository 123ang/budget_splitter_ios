//
//  ExsplitterApp.swift
//  Exsplitter
//
//  Created by Kevin Soon on 31/01/2026.
//

import SwiftUI

@main
struct ExsplitterApp: App {
    @StateObject private var dataStore = BudgetDataStore()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(dataStore)
        }
    }
}
