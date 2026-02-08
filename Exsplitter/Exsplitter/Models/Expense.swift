//
//  Expense.swift
//  Xsplitter
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
    case USD
    case EUR
    case GBP
    case JPY
    case CNY
    case HKD
    case KRW
    case SGD
    case MYR
    case THB
    case IDR
    case PHP
    case VND
    case INR
    case AUD
    case NZD
    case CAD
    case CHF
    case AED
    case SAR
    
    var symbol: String {
        switch self {
        case .USD: return "$"
        case .EUR: return "€"
        case .GBP: return "£"
        case .JPY: return "¥"
        case .CNY: return "¥"
        case .HKD: return "HK$"
        case .KRW: return "₩"
        case .SGD: return "S$"
        case .MYR: return "RM"
        case .THB: return "฿"
        case .IDR: return "Rp"
        case .PHP: return "₱"
        case .VND: return "₫"
        case .INR: return "₹"
        case .AUD: return "A$"
        case .NZD: return "NZ$"
        case .CAD: return "C$"
        case .CHF: return "CHF"
        case .AED: return "AED"
        case .SAR: return "SAR"
        }
    }
    
    var decimals: Int {
        switch self {
        case .JPY, .KRW, .VND: return 0
        default: return 2
        }
    }
}

struct Expense: Identifiable, Codable, Hashable {
    var id: String
    var description: String
    var amount: Double
    var category: ExpenseCategory
    var currency: Currency
    var paidByMemberId: String
    var date: Date
    var splitMemberIds: [String]
    var splits: [String: Double] // memberId -> amount
    /// When payer is not in split and "everyone pays a bit more": extra paid by split members that the payer keeps.
    var payerEarned: Double?
    /// Optional trip/event this expense belongs to (e.g. Japan trip, Korea trip).
    var eventId: String?
    
    init(
        id: String = UUID().uuidString,
        description: String,
        amount: Double,
        category: ExpenseCategory,
        currency: Currency = .JPY,
        paidByMemberId: String,
        date: Date = Date(),
        splitMemberIds: [String],
        splits: [String: Double],
        payerEarned: Double? = nil,
        eventId: String? = nil
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
        self.payerEarned = payerEarned
        self.eventId = eventId
    }
}
