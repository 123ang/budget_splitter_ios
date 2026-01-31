//
//  AddExpenseView.swift
//  BudgetSplitter
//

import SwiftUI

struct AddExpenseView: View {
    @EnvironmentObject var dataStore: BudgetDataStore
    @State private var description = ""
    @State private var amountText = ""
    @State private var category: ExpenseCategory = .meal
    @State private var currency: Currency = .JPY
    @State private var paidByMemberId: String = ""
    @State private var date = Date()
    @State private var selectedMemberIds: Set<String> = []
    
    private let iosBlue = Color(red: 10/255, green: 132/255, blue: 1)
    private let iosCard = Color(white: 0.11)
    private let iosSec = Color(white: 0.17)
    private let iosSep = Color(white: 0.22)
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    // Form card
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Add Expense")
                            .font(.headline.bold())
                            .foregroundColor(.white)
                        
                        InputField(label: "Description", text: $description, placeholder: "Ramen dinner @ Ichiran")
                        InputField(label: "Amount", text: $amountText, placeholder: "5,400", keyboardType: .decimalPad)
                        
                        HStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Category")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                CategoryPicker(selection: $category)
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Currency")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                CurrencyPicker(selection: $currency)
                            }
                        }
                        
                        HStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Paid by")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                MemberPicker(dataStore: dataStore, selection: $paidByMemberId)
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Date")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                DatePicker("", selection: $date, displayedComponents: .date)
                                    .labelsHidden()
                                    .colorScheme(.dark)
                                    .padding(8)
                                    .background(iosSec)
                                    .cornerRadius(8)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Split with (\(selectedMemberIds.count) selected)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text("Equal split")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        Button {
                            addExpense()
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Add Expense")
                            }
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(iosBlue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .padding(.top, 8)
                    }
                    .padding()
                    .background(iosCard)
                    .cornerRadius(12)
                }
                .padding()
            }
            .background(Color.black)
            .navigationTitle("💰 Budget Splitter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Text("🌐 EN")
                        .foregroundColor(Color(red: 10/255, green: 132/255, blue: 1))
                }
            }
            .onAppear {
                if paidByMemberId.isEmpty, let first = dataStore.members.first {
                    paidByMemberId = first.id
                }
                if selectedMemberIds.isEmpty {
                    selectedMemberIds = Set(dataStore.members.map(\.id))
                }
            }
        }
    }
    
    private func addExpense() {
        guard let amount = Double(amountText.replacingOccurrences(of: ",", with: "")),
              amount > 0,
              !description.trimmingCharacters(in: .whitespaces).isEmpty,
              !paidByMemberId.isEmpty else { return }
        
        let selectedIds = Array(selectedMemberIds)
        guard !selectedIds.isEmpty else { return }
        
        // Equal split
        let perPerson = amount / Double(selectedIds.count)
        var splits: [String: Double] = [:]
        var remainder = amount
        for id in selectedIds {
            let share = currency == .JPY ? floor(perPerson) : (perPerson * 100).rounded() / 100
            splits[id] = share
            remainder -= share
        }
        if remainder > 0, let firstId = selectedIds.first {
            splits[firstId, default: 0] += remainder
        }
        
        let expense = Expense(
            description: description.trimmingCharacters(in: .whitespaces),
            amount: amount,
            category: category,
            currency: currency,
            paidByMemberId: paidByMemberId,
            date: date,
            splitMemberIds: selectedIds,
            splits: splits
        )
        dataStore.addExpense(expense)
        
        description = ""
        amountText = ""
    }
}

struct InputField: View {
    let label: String
    @Binding var text: String
    var placeholder: String = ""
    var keyboardType: UIKeyboardType = .default
    
    private let iosSec = Color(white: 0.17)
    private let iosSep = Color(white: 0.22)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            TextField(placeholder, text: $text)
                .keyboardType(keyboardType)
                .padding(10)
                .background(iosSec)
                .foregroundColor(.white)
                .cornerRadius(8)
        }
    }
}

struct CategoryPicker: View {
    @Binding var selection: ExpenseCategory
    private let iosSec = Color(white: 0.17)
    
    var body: some View {
        Menu {
            ForEach(ExpenseCategory.allCases, id: \.self) { cat in
                Button {
                    selection = cat
                } label: {
                    HStack {
                        Image(systemName: cat.icon)
                        Text(cat.rawValue)
                    }
                }
            }
        } label: {
            HStack {
                Image(systemName: selection.icon)
                Text(selection.rawValue)
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.caption)
            }
            .padding(10)
            .background(iosSec)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
    }
}

struct CurrencyPicker: View {
    @Binding var selection: Currency
    private let iosSec = Color(white: 0.17)
    
    var body: some View {
        Menu {
            ForEach(Currency.allCases, id: \.self) { curr in
                Button {
                    selection = curr
                } label: {
                    Text("\(curr.rawValue) (\(curr.symbol))")
                }
            }
        } label: {
            HStack {
                Text("\(selection.rawValue) (\(selection.symbol))")
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.caption)
            }
            .padding(10)
            .background(iosSec)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
    }
}

struct MemberPicker: View {
    @ObservedObject var dataStore: BudgetDataStore
    @Binding var selection: String
    private let iosSec = Color(white: 0.17)
    
    var body: some View {
        Menu {
            ForEach(dataStore.members) { member in
                Button {
                    selection = member.id
                } label: {
                    Text(member.name)
                }
            }
        } label: {
            HStack {
                Text(dataStore.members.first(where: { $0.id == selection })?.name ?? "Select")
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.caption)
            }
            .padding(10)
            .background(iosSec)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
    }
}

#Preview {
    AddExpenseView()
        .environmentObject(BudgetDataStore())
}
