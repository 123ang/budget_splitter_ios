//
//  SummarySheetView.swift
//  BudgetSplitter
//

import SwiftUI

struct SummarySheetView: View {
    @EnvironmentObject var dataStore: BudgetDataStore
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    SummaryCard(dataStore: dataStore)
                }
                .padding()
            }
            .background(Color.appBackground)
            .navigationTitle("Summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(Color(red: 10/255, green: 132/255, blue: 1))
                }
            }
        }
    }
}

#Preview {
    SummarySheetView()
        .environmentObject(BudgetDataStore())
}
