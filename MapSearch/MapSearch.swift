//
//  MapSearch.swift
//  Reexplore
//
//  Created by Flavian Kaufmann on 10.09.20.
//  Copyright © 2020 n3xd software studios ag. All rights reserved.
//

import Foundation
import MapKit

class MapSearch: NSObject {

    private var search: MKLocalSearch?

    private var geocoder: CLGeocoder?

    func search(for searchString: String, completion: @escaping MKLocalSearch.CompletionHandler) {
        search?.cancel()

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchString

        search = MKLocalSearch(request: request)
        search?.start(completionHandler: completion)
    }

    func reverseGeocode(location: CLLocation, completion: @escaping CLGeocodeCompletionHandler) {
        if let pendingGeocoder = geocoder {
            if pendingGeocoder.isGeocoding {
                pendingGeocoder.cancelGeocode()
            }
        }

        geocoder = CLGeocoder()
        geocoder?.reverseGeocodeLocation(location, completionHandler: completion)
    }
}
