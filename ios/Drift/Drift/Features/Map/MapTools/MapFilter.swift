//
//  MapFilter.swift
//  Drift
//
//  Created by alexandre emond on 2025-12-14.
//


import Foundation

enum MapFilter: String, CaseIterable, Identifiable {
    case all
    case myBottles
    case active
    case locked
    case expired

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "All"
        case .myBottles: return "My bottles"
        case .active: return "Active"
        case .locked: return "Locked"
        case .expired: return "Expired"
        }
    }
}
