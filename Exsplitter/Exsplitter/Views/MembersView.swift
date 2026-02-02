//
//  MembersView.swift
//  BudgetSplitter
//

import SwiftUI

struct MembersView: View {
    @EnvironmentObject var dataStore: BudgetDataStore
    @State private var newMemberName = ""
    @State private var showResetConfirmation = false
    
    private let iosBlue = Color(red: 10/255, green: 132/255, blue: 1)
    private let iosCard = Color(white: 0.11)
    private let iosSec = Color(white: 0.17)
    private let iosRed = Color(red: 1, green: 69/255, blue: 58/255)
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    // Members management card
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Members")
                            .font(.headline.bold())
                            .foregroundColor(.white)
                        
                        HStack(spacing: 8) {
                            TextField("e.g. John", text: $newMemberName)
                                .padding(10)
                                .background(iosSec)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                                .submitLabel(.done)
                                .onSubmit { addMember() }
                            Button {
                                addMember()
                            } label: {
                                Text("Add")
                                    .font(.subheadline.bold())
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(iosBlue)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }
                        }
                        
                        FlowLayout(spacing: 4) {
                            ForEach(dataStore.members) { member in
                                HStack(spacing: 6) {
                                    Text(member.name)
                                        .font(.caption)
                                        .foregroundColor(.white)
                                    Button {
                                        dataStore.removeMember(id: member.id)
                                    } label: {
                                        Text("Delete")
                                            .font(.caption)
                                            .foregroundColor(iosRed)
                                    }
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(iosSec)
                                .cornerRadius(16)
                            }
                        }
                        
                        Button {
                            showResetConfirmation = true
                        } label: {
                            Text("Reset All Data")
                                .font(.subheadline.bold())
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(iosRed)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        .padding(.top, 16)
                    }
                    .padding()
                    .background(iosCard)
                    .cornerRadius(12)
                    
                    // Summary by member
                    if !dataStore.expenses.isEmpty {
                        SummaryCard(dataStore: dataStore)
                    }
                }
                .padding()
            }
            .background(Color.black)
            .navigationTitle("💰 Budget Splitter")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Text("🌐 EN")
                        .foregroundColor(Color(red: 10/255, green: 132/255, blue: 1))
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .alert("Reset All Data?", isPresented: $showResetConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    dataStore.resetAll()
                }
            } message: {
                Text("This will remove all members and expenses. You cannot undo this.")
            }
        }
    }
    
    private func addMember() {
        let name = newMemberName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        dataStore.addMember(name)
        newMemberName = ""
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }
    
    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let proposedWidth = proposal.width ?? 400
        let maxWidth = proposedWidth.isFinite && proposedWidth > 0 ? proposedWidth : 400
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
        
        return (CGSize(width: max(maxWidth, x), height: y + rowHeight), positions)
    }
}

struct SummaryCard: View {
    @ObservedObject var dataStore: BudgetDataStore
    
    private let iosCard = Color(white: 0.11)
    private let iosSep = Color(white: 0.22)
    
    private func formatMoney(_ amount: Double, _ currency: Currency) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = currency.decimals
        formatter.minimumFractionDigits = currency.decimals
        let str = formatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
        return "\(currency.symbol)\(str)"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            let total = dataStore.totalSpent(currency: .JPY)
            Text("JPY — Total Spent: \(formatMoney(total, .JPY))")
                .font(.headline.bold())
                .foregroundColor(.white)
            
            let memberTotals = dataStore.members
                .map { ($0, dataStore.memberTotal(memberId: $0.id, currency: .JPY)) }
                .filter { $0.1 > 0 }
                .sorted { $0.1 > $1.1 }
            
            ForEach(memberTotals.prefix(5), id: \.0.id) { member, amount in
                HStack {
                    Text(member.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    Spacer()
                    Text(formatMoney(amount, .JPY))
                        .font(.subheadline.bold())
                        .foregroundColor(.green)
                        .fontVariant(.tabularNumbers)
                }
                .padding(.vertical, 8)
                .overlay(
                    Rectangle()
                        .frame(height: 0.5)
                        .foregroundColor(iosSep),
                    alignment: .bottom
                )
            }
            if memberTotals.count > 5 {
                Text("+ \(memberTotals.count - 5) more members")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            }
        }
        .padding()
        .background(iosCard)
        .cornerRadius(12)
        
        // By Category
        VStack(alignment: .leading, spacing: 10) {
            Text("By Category")
                .font(.headline.bold())
                .foregroundColor(.white)
            
            let categories = dataStore.categoryTotals(currency: .JPY)
                .sorted { $0.value > $1.value }
            
            ForEach(categories, id: \.key) { category, amount in
                HStack {
                    Image(systemName: category.icon)
                    Text(category.rawValue)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    Spacer()
                    Text(formatMoney(amount, .JPY))
                        .font(.subheadline.bold())
                        .foregroundColor(.green)
                        .fontVariant(.tabularNumbers)
                }
                .padding(.vertical, 8)
                .overlay(
                    Rectangle()
                        .frame(height: 0.5)
                        .foregroundColor(iosSep),
                    alignment: .bottom
                )
            }
        }
        .padding()
        .background(iosCard)
        .cornerRadius(12)
    }
}

#Preview {
    MembersView()
        .environmentObject(BudgetDataStore())
}
