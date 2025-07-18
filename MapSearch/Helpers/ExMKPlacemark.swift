//
//  MKPlacemark.swift
//  Reexplore
//
//  Created by Flavian Kaufmann on 10.09.20.
//  Copyright © 2020 n3xd software studios ag. All rights reserved.
//

import Foundation
import MapKit
import Contacts

extension MKPlacemark {
    func format() -> String? {
        guard let postalAddress = self.postalAddress else { return nil }
        return Self.addressFormatter.string(from: postalAddress)
    }

    private static var addressFormatter: CNPostalAddressFormatter {
        let formatter = CNPostalAddressFormatter()
        formatter.style = .mailingAddress
        return formatter
    }

}
