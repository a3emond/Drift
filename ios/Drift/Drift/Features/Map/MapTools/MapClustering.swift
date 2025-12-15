//
//  MapClustering.swift
//  Drift
//
//  Created by alexandre emond on 2025-12-14.
//


import Foundation
import MapKit

enum MapClustering {

    static func clusterItems(
        items: [MapAnnotationItem],
        region: MKCoordinateRegion
    ) -> [MapClusterItem] {

        guard !items.isEmpty else { return [] }

        let cellLat = max(region.span.latitudeDelta / 8.0, 0.02)
        let cellLon = max(region.span.longitudeDelta / 8.0, 0.02)

        var buckets: [String: [MapAnnotationItem]] = [:]
        buckets.reserveCapacity(min(items.count, 256))

        for item in items {
            let latIndex = Int(floor(item.latitude / cellLat))
            let lonIndex = Int(floor(item.longitude / cellLon))
            let key = "\(latIndex):\(lonIndex)"
            buckets[key, default: []].append(item)
        }

        return buckets.map { key, bucket in
            let avgLat = bucket.map(\.latitude).reduce(0, +) / Double(bucket.count)
            let avgLon = bucket.map(\.longitude).reduce(0, +) / Double(bucket.count)

            return MapClusterItem(
                id: key,
                latitude: avgLat,
                longitude: avgLon,
                count: bucket.count
            )
        }
    }
}