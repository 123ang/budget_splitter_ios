//
//  AppFonts.swift
//  Exsplitter
//
//  Shared typography: trip title, section headers, and body. Keeps hierarchy clear without overwhelming.
//

import SwiftUI

enum AppFonts {
    /// Nav bar trip/event name (e.g. "Japan") – rounded, friendly, stands out.
    static let tripTitle = Font.system(size: 20, weight: .semibold, design: .rounded)

    /// Section headers (e.g. "Overview", "Quick Actions", "Recent Activity").
    static let sectionHeader = Font.system(size: 17, weight: .semibold, design: .rounded)

    /// Card/screen titles (e.g. "Trip Details" label, Settings card titles). Slightly rounded.
    static let cardTitle = Font.system(size: 15, weight: .semibold, design: .rounded)
}
