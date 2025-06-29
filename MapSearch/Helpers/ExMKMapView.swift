//
//  ExMKMapView.swift
//  Reexplore
//
//  Created by Flavian Kaufmann on 10.09.20.
//  Copyright © 2020 n3xd software studios ag. All rights reserved.
//

import Foundation
import MapKit

extension MKMapView {
    func show(annotation: MKAnnotation) {
        clearAnnotations()
        self.addAnnotation(annotation)
        self.showAnnotations(self.annotations, animated: true)
    }

    func clearAnnotations() {
        self.removeAnnotations(self.annotations)
    }
}
