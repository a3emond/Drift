//
//  ClusterPillView.swift
//  Drift
//
//  Created by alexandre emond on 2025-12-14.
//


import SwiftUI

struct ClusterPillView: View {

    let count: Int
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text("\(count)")
                .font(.system(size: 50, weight: .semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                
                    
        }
        .buttonStyle(.plain)
        
    }
}
