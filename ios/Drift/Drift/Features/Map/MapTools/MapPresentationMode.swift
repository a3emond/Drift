//
//  MapPresentationMode.swift
//  Drift
//
//  Created by alexandre emond on 2025-12-14.
//


import Foundation
import MapKit

enum MapPresentationMode: Equatable {
    case individual
    case clustered
}

enum MapPresentationModeResolver {

    static func mode(for region: MKCoordinateRegion) -> MapPresentationMode {
        if region.span.latitudeDelta > 0.40 || region.span.longitudeDelta > 0.40 {
            return .clustered
        }
        return .individual
    }
}
