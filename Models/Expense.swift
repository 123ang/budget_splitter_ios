//
//  Expense.swift
//  BudgetSplitter
//

import Foundation

enum ExpenseCategory: String, Codable, CaseIterable {
    case meal = "Meal"
    case transport = "Transport"
    case tickets = "Tickets"
    case shopping = "Shopping"
    case hotel = "Hotel"
    case other = "Other"
    
    var icon: String {
        switch self {
        case .meal: return "fork.knife"
        case .transport: return "train.side.front.car"
        case .tickets: return "ticket"
        case .shopping: return "bag"
        case .hotel: return "bed.double"
        case .other: return "square.grid.2x2"
        }
    }
}

enum Currency: String, Codable, CaseIterable {
    case JPY
    case MYR
    case SGD
    
    var symbol: String {
        switch self {
        case .JPY: return "¥"
        case .MYR: return "RM"
        case .SGD: return "S$"
        }
    }
    
    var decimals: Int {
        self == .JPY ? 0 : 2
    }
}

struct Expense: Identifiable, Codable {
    var id: String
    var description: String
    var amount: Double
    var category: ExpenseCategory
    var currency: Currency
    var paidByMemberId: String
    var date: Date
    var splitMemberIds: [String]
    var splits: [String: Double] // memberId -> amount
    
    init(
        id: String = UUID().uuidString,
        description: String,
        amount: Double,
        category: ExpenseCategory,
        currency: Currency = .JPY,
        paidByMemberId: String,
        date: Date = Date(),
        splitMemberIds: [String],
        splits: [String: Double]
    ) {
        self.id = id
        self.description = description
        self.amount = amount
        self.category = category
        self.currency = currency
        self.paidByMemberId = paidByMemberId
        self.date = date
        self.splitMemberIds = splitMemberIds
        self.splits = splits
    }
}
