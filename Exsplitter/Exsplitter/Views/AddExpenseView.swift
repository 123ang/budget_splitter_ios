//
//  AddExpenseView.swift
//  BudgetSplitter
//

import SwiftUI
import UIKit

/// Who pays for this expense: payer treats everyone (full amount on payer) or split with others.
enum ExpenseSplitMode: String, CaseIterable {
    case treatEveryone = "I'm treating"
    case splitWithOthers = "Split with others"
}

enum SplitType: String, CaseIterable {
    case equal = "Equal"
    case custom = "Custom"
}

/// When payer is not in the split: how to handle rounding extra.
enum PayerNotInSplitOption: String, CaseIterable {
    case randomExtra = "Random split extra"
    case payerEarns = "Everyone pays a bit more (payer earns)"
}

struct AddExpenseView: View {
    @EnvironmentObject var dataStore: BudgetDataStore
    @State private var description = ""
    @State private var amountText = ""
    @State private var category: ExpenseCategory = .meal
    @State private var currency: Currency = CurrencyStore.shared.preferredCurrency
    @State private var paidByMemberId: String = ""
    @State private var date = Date()
    @State private var splitType: SplitType = .equal
    @State private var customAmounts: [String: String] = [:] // memberId -> amount text
    @State private var payerNotInSplitOption: PayerNotInSplitOption = .randomExtra
    @State private var showSuccessToast = false
    @State private var addErrorMessage: String?
    @State private var isAddingExpense = false
    @State private var customSplitError: String?
    /// Who is included in this expense's split (checkboxes). Independent from global "selected" members.
    @State private var splitMemberIdsForThisExpense: Set<String> = []
    /// nil = must choose; .treatEveryone = full expense on payer; .splitWithOthers = show Equal/Custom.
    @State private var expenseSplitMode: ExpenseSplitMode? = nil
    
    private let iosBlue = Color(red: 10/255, green: 132/255, blue: 1)
    
    private var canAddExpense: Bool {
        guard let mode = expenseSplitMode else { return false }
        if mode == .treatEveryone { return true }
        return !selectedIds.isEmpty
    }
    
    /// Members selected for this expense's split (sorted by member order).
    private var selectedIds: [String] {
        dataStore.members
            .filter { splitMemberIdsForThisExpense.contains($0.id) }
            .map(\.id)
    }
    
    private var payerIsInSplit: Bool {
        selectedIds.contains(paidByMemberId)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    // Form card
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Add Expense")
                            .font(.headline.bold())
                            .foregroundColor(.appPrimary)
                        
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
                                    .padding(8)
                                    .background(Color.appTertiary)
                                    .cornerRadius(8)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Who pays for this?")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Picker("Who pays", selection: $expenseSplitMode) {
                                Text("Choose…").tag(nil as ExpenseSplitMode?)
                                ForEach(ExpenseSplitMode.allCases, id: \.self) { mode in
                                    Text(mode.rawValue).tag(mode as ExpenseSplitMode?)
                                }
                            }
                            .pickerStyle(.segmented)
                            .onChange(of: expenseSplitMode) { _, _ in
                                customSplitError = nil
                            }
                            
                            if expenseSplitMode == .treatEveryone {
                                Text("Full amount goes to your expenses. No one else owes anything.")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            
                            if expenseSplitMode == .splitWithOthers {
                                Text("Split with (\(selectedIds.count) selected)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text("Select who is in this split")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                VStack(spacing: 6) {
                                    ForEach(dataStore.members) { member in
                                        Toggle(isOn: Binding(
                                            get: { splitMemberIdsForThisExpense.contains(member.id) },
                                            set: { on in
                                                if on {
                                                    splitMemberIdsForThisExpense.insert(member.id)
                                                } else {
                                                    splitMemberIdsForThisExpense.remove(member.id)
                                                }
                                            }
                                        )) {
                                            Text(member.name)
                                                .font(.subheadline)
                                                .foregroundColor(.appPrimary)
                                        }
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 12)
                                        .background(Color.appTertiary)
                                        .cornerRadius(8)
                                    }
                                }
                                Picker("Split", selection: $splitType) {
                                    ForEach(SplitType.allCases, id: \.self) { type in
                                        Text(type.rawValue).tag(type)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .onChange(of: splitType) { _, new in
                                    if new == .equal { customSplitError = nil }
                                }
                                if splitType == .custom {
                                    customSplitFields
                                    if let err = customSplitError {
                                        Text(err)
                                            .font(.caption)
                                            .foregroundColor(.red)
                                            .padding(.top, 4)
                                    }
                                } else {
                                    Text("Amount divided equally. Any rounding extra goes to the person who paid.")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    if !payerIsInSplit {
                                        Text("Paid by is not in the split.")
                                            .font(.caption2)
                                            .foregroundColor(.orange)
                                        Picker("Extra from rounding", selection: $payerNotInSplitOption) {
                                            ForEach(PayerNotInSplitOption.allCases, id: \.self) { opt in
                                                Text(opt.rawValue).tag(opt)
                                            }
                                        }
                                        .pickerStyle(.menu)
                                    }
                                }
                            }
                        }
                        
                        if expenseSplitMode == nil {
                            Text("Choose \"I'm treating\" or \"Split with others\" above to add an expense.")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                        
                        if let err = addErrorMessage {
                            Text(err)
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding(.top, 4)
                        }
                        Button {
                            addExpense()
                        } label: {
                            HStack {
                                if isAddingExpense {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Add Expense")
                                }
                            }
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(iosBlue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(!canAddExpense || isAddingExpense)
                        .opacity(canAddExpense && !isAddingExpense ? 1 : 0.6)
                        .padding(.top, 8)
                    }
                    .padding()
                    .background(Color.appCard)
                    .cornerRadius(12)
                }
                .padding()
            }
            .background(Color.appBackground)
            .navigationTitle("💰 Budget Splitter")
            .navigationBarTitleDisplayMode(.inline)
            .keyboardDoneButton()
            .onAppear {
                currency = CurrencyStore.shared.preferredCurrency
                if paidByMemberId.isEmpty, let first = dataStore.members.first {
                    paidByMemberId = first.id
                }
                if splitMemberIdsForThisExpense.isEmpty {
                    let defaultIds = dataStore.selectedMemberIds.isEmpty
                        ? Set(dataStore.members.map(\.id))
                        : dataStore.selectedMemberIds
                    splitMemberIdsForThisExpense = defaultIds
                }
            }
            .onChange(of: dataStore.members.count) { _, _ in
                // Keep only existing members; add new members to split by default
                let memberIds = Set(dataStore.members.map(\.id))
                splitMemberIdsForThisExpense = splitMemberIdsForThisExpense.filter { memberIds.contains($0) }
                for id in memberIds where !splitMemberIdsForThisExpense.contains(id) {
                    splitMemberIdsForThisExpense.insert(id)
                }
            }
            .overlay(alignment: .top) {
                if showSuccessToast {
                    successToast
                        .padding(.top, 12)
                }
            }
        }
    }
    
    @ViewBuilder
    private var customSplitFields: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Enter each person's share (\(currency.symbol))")
                .font(.caption2)
                .foregroundColor(.secondary)
            ForEach(selectedIds, id: \.self) { memberId in
                let name = dataStore.members.first(where: { $0.id == memberId })?.name ?? "—"
                HStack {
                    Text(name)
                        .font(.subheadline)
                        .foregroundColor(.appPrimary)
                        .lineLimit(1)
                    Spacer()
                    TextField("0", text: Binding(
                        get: { customAmounts[memberId] ?? "" },
                        set: { customAmounts[memberId] = $0; customSplitError = nil }
                    ))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                    .padding(8)
                    .background(Color.appTertiary)
                    .cornerRadius(8)
                }
                .padding(.vertical, 4)
            }
        }
    }
    
    private var successToast: some View {
        Text("Successfully added")
            .font(.subheadline.bold())
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.green)
            .cornerRadius(25)
            .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
            .transition(.opacity.combined(with: .scale(scale: 0.9)))
            .zIndex(100)
    }
    
    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    private func addExpense() {
        let cleaned = amountText.replacingOccurrences(of: ",", with: "").trimmingCharacters(in: .whitespaces)
        guard let amount = Double(cleaned), amount > 0 else { return }
        guard !paidByMemberId.isEmpty else { return }
        guard canAddExpense else { return }
        
        let ids: [String]
        var splits: [String: Double]
        var payerEarned: Double? = nil
        
        if expenseSplitMode == .treatEveryone {
            // Payer treats: full amount on payer only, no one else owes anything.
            ids = [paidByMemberId]
            splits = [paidByMemberId: amount]
        } else {
            guard !selectedIds.isEmpty else {
                customSplitError = "Select at least one person for the split."
                return
            }
            ids = selectedIds
            
        if splitType == .custom {
            customSplitError = nil
            var sum: Double = 0
            var parsed: [String: Double] = [:]
            for id in ids {
                let t = (customAmounts[id] ?? "").replacingOccurrences(of: ",", with: "").trimmingCharacters(in: .whitespaces)
                let val = Double(t) ?? 0
                parsed[id] = max(0, currency == .JPY ? floor(val) : (val * 100).rounded() / 100)
                sum += parsed[id] ?? 0
            }
            if sum <= 0 {
                customSplitError = "Enter at least one amount."
                return
            }
            let tolerance = currency == .JPY ? 0.5 : 0.005
            if abs(sum - amount) > tolerance {
                let sym = currency.symbol
                let fmt = currency == .JPY ? "%.0f" : "%.2f"
                customSplitError = "Custom split does not tally. Total entered: \(sym)\(String(format: fmt, sum)), expense amount: \(sym)\(String(format: fmt, amount))."
                return
            }
            splits = parsed
        } else {
            // Equal split
            let n = Double(ids.count)
            let perPerson = amount / n
            let payerInSplit = ids.contains(paidByMemberId)
            
            if payerInSplit {
                // Others pay a bit more (ceil), payer pays the rest so payer pays less and "earns" the extra
                let othersShare = currency == .JPY ? ceil(perPerson) : (perPerson * 100).rounded(.up) / 100
                var totalOthers: Double = 0
                splits = [:]
                for id in ids {
                    if id == paidByMemberId {
                        continue
                    }
                    splits[id] = othersShare
                    totalOthers += othersShare
                }
                let payerShare = amount - totalOthers
                splits[paidByMemberId] = max(0, payerShare)
            } else {
                // Payer not in split
                if payerNotInSplitOption == .randomExtra {
                    var remainder = amount
                    splits = [:]
                    let baseShare = currency == .JPY ? floor(perPerson) : (perPerson * 100).rounded() / 100
                    for id in ids {
                        splits[id] = baseShare
                        remainder -= baseShare
                    }
                    if remainder > 0 {
                        let whoGetsExtra = ids.shuffled()
                        var r = remainder
                        for id in whoGetsExtra where r > 0 {
                            let add = currency == .JPY ? 1.0 : 0.01
                            splits[id, default: 0] += min(add, r)
                            r -= add
                        }
                    }
                } else {
                    // Everyone pays a bit more (payer earns)
                    let ceilShare = currency == .JPY ? ceil(perPerson) : (perPerson * 100).rounded(.up) / 100
                    var totalFromMembers: Double = 0
                    splits = [:]
                    for id in ids {
                        splits[id] = ceilShare
                        totalFromMembers += ceilShare
                    }
                    payerEarned = max(0, totalFromMembers - amount)
                }
            }
        }
        } // end else (split with others)
        
        let expense = Expense(
            description: description.trimmingCharacters(in: .whitespaces),
            amount: amount,
            category: category,
            currency: currency,
            paidByMemberId: paidByMemberId,
            date: date,
            splitMemberIds: ids,
            splits: splits,
            payerEarned: payerEarned
        )
        addErrorMessage = nil
        isAddingExpense = true
        Task {
            do {
                try await dataStore.addExpense(expense)
                await MainActor.run {
                    dismissKeyboard()
                    description = ""
                    amountText = ""
                    customAmounts = [:]
                    withAnimation(.easeInOut(duration: 0.2)) { showSuccessToast = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation(.easeOut(duration: 0.25)) { showSuccessToast = false }
                    }
                }
            } catch {
                await MainActor.run {
                    addErrorMessage = (error as? LocalizedError)?.errorDescription ?? "Failed to add expense"
                }
            }
            await MainActor.run { isAddingExpense = false }
        }
    }
}

struct InputField: View {
    let label: String
    @Binding var text: String
    var placeholder: String = ""
    var keyboardType: UIKeyboardType = .default
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            TextField(placeholder, text: $text)
                .keyboardType(keyboardType)
                .padding(10)
                .background(Color.appTertiary)
                .foregroundColor(.appPrimary)
                .cornerRadius(8)
        }
    }
}

struct CategoryPicker: View {
    @Binding var selection: ExpenseCategory
    
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
            .background(Color.appTertiary)
            .foregroundColor(.appPrimary)
            .cornerRadius(8)
        }
    }
}

struct CurrencyPicker: View {
    @Binding var selection: Currency
    
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
            .background(Color.appTertiary)
            .foregroundColor(.appPrimary)
            .cornerRadius(8)
        }
    }
}

struct MemberPicker: View {
    @ObservedObject var dataStore: BudgetDataStore
    @Binding var selection: String
    
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
            .background(Color.appTertiary)
            .foregroundColor(.appPrimary)
            .cornerRadius(8)
        }
    }
}

#Preview {
    AddExpenseView()
        .environmentObject(BudgetDataStore())
}
