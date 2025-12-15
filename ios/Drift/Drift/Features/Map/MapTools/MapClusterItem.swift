//
//  MapClusterItem.swift
//  Drift
//
//  Created by alexandre emond on 2025-12-14.
//


import Foundation

struct MapClusterItem: Identifiable, Equatable {
    let id: String
    let latitude: Double
    let longitude: Double
    let count: Int
}