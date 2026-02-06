//
//  Event.swift
//  Exsplitter
//

import Foundation

/// A trip or event (e.g. Japan trip, Korea trip) that groups expenses.
/// Each trip has its own members list so data is not shared between trips.
struct Event: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var createdAt: Date
    /// When set, the trip is ended (archived). Nil = ongoing.
    var endedAt: Date?
    /// When set, only these member IDs participate (legacy filter). Prefer using `members` for per-trip data.
    var memberIds: [String]?
    /// When set, trip only shows expenses in these currencies. Nil = all currencies.
    var currencyCodes: [String]?
    /// Members for this trip only. Not shared with other trips.
    var members: [Member]
    
    var isOngoing: Bool { endedAt == nil }
    
    /// Currencies allowed for this trip; nil = all.
    var allowedCurrencies: Set<Currency>? {
        guard let codes = currencyCodes, !codes.isEmpty else { return nil }
        let set = Set(codes.compactMap { Currency(rawValue: $0) })
        return set.isEmpty ? nil : set
    }
    
    init(id: String = UUID().uuidString, name: String, createdAt: Date = Date(), endedAt: Date? = nil, memberIds: [String]? = nil, currencyCodes: [String]? = nil, members: [Member] = []) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.endedAt = endedAt
        self.memberIds = memberIds
        self.currencyCodes = currencyCodes
        self.members = members
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, createdAt, endedAt, memberIds, currencyCodes, members
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        endedAt = try c.decodeIfPresent(Date.self, forKey: .endedAt)
        memberIds = try c.decodeIfPresent([String].self, forKey: .memberIds)
        currencyCodes = try c.decodeIfPresent([String].self, forKey: .currencyCodes)
        members = (try? c.decode([Member].self, forKey: .members)) ?? []
    }
    
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encodeIfPresent(endedAt, forKey: .endedAt)
        try c.encodeIfPresent(memberIds, forKey: .memberIds)
        try c.encodeIfPresent(currencyCodes, forKey: .currencyCodes)
        try c.encode(members, forKey: .members)
    }
}
