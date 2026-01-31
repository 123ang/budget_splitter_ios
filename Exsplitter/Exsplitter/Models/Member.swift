//
//  Member.swift
//  BudgetSplitter
//

import Foundation

struct Member: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    
    init(id: String = UUID().uuidString, name: String) {
        self.id = id
        self.name = name
    }
}
