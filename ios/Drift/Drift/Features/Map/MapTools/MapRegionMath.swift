//
//  MapRegionMath.swift
//  Drift
//
//  Created by alexandre emond on 2025-12-14.
//


import Foundation
import MapKit

enum MapRegionMath {

    static func contains(
        latitude: Double,
        longitude: Double,
        in region: MKCoordinateRegion
    ) -> Bool {
        let latHalf = region.span.latitudeDelta / 2.0
        let lonHalf = region.span.longitudeDelta / 2.0

        let minLat = region.center.latitude - latHalf
        let maxLat = region.center.latitude + latHalf

        let minLon = region.center.longitude - lonHalf
        let maxLon = region.center.longitude + lonHalf

        return latitude >= minLat && latitude <= maxLat &&
               longitude >= minLon && longitude <= maxLon
    }

    static func zoomedIntoCluster(
        current region: MKCoordinateRegion,
        clusterLatitude: Double,
        clusterLongitude: Double
    ) -> MKCoordinateRegion {

        MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: clusterLatitude,
                longitude: clusterLongitude
            ),
            span: MKCoordinateSpan(
                latitudeDelta: max(region.span.latitudeDelta * 0.45, 0.05),
                longitudeDelta: max(region.span.longitudeDelta * 0.45, 0.05)
            )
        )
    }
}