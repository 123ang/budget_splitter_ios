//
//  Member.swift
//  BudgetSplitter
//

import Foundation

struct Member: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    /// When this member was added to the group (for history: "X joined on …").
    var joinedAt: Date?
    
    init(id: String = UUID().uuidString, name: String, joinedAt: Date? = nil) {
        self.id = id
        self.name = name
        self.joinedAt = joinedAt
    }
}
