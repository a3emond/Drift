//
//  MapFilterBar.swift
//  Drift
//
//  Created by alexandre emond on 2025-12-14.
//


import SwiftUI

struct MapFilterBar: View {

    let active: MapFilter
    let onSelect: (MapFilter) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(MapFilter.allCases) { filter in
                    Button {
                        onSelect(filter)
                    } label: {
                        Text(filter.title)
                            .font(.system(size: 13, weight: .semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                active == filter
                                ? Color.accentColor.opacity(0.25)
                                : Color.clear
                            )
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
        }
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .padding(.horizontal)
    }
}
