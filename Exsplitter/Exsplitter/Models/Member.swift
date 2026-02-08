//
//  Member.swift
//  Xsplitter
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

/// Record of a member who left the group (for history: "X left on …").
struct FormerMember: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    /// When they joined (optional, for display).
    var joinedAt: Date?
    /// When they left the group.
    var leftAt: Date
    
    init(id: String, name: String, joinedAt: Date? = nil, leftAt: Date = Date()) {
        self.id = id
        self.name = name
        self.joinedAt = joinedAt
        self.leftAt = leftAt
    }
}
