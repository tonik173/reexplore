//
//  MapViewController.swift
//  Reexplore-macOS
//
//  Created by Flavian Kaufmann on 10.09.20.
//  Copyright © 2020 n3xd software studios ag. All rights reserved.
//

import Foundation
import Cocoa
import MapKit

class MapViewController: NSViewController
{
    public weak var delegate: MapViewControllerDelegate?

    private var currentPlacemark: MKPlacemark? {
        didSet {
            if let placemark = currentPlacemark {
                self.mapView.show(annotation: placemark)
            }
            else {
                mapView.clearAnnotations()
            }
            chooseButton.isEnabled = currentPlacemark != nil
        }
    }

    private lazy var clickGestureRecognizer: NSClickGestureRecognizer = {
        return NSClickGestureRecognizer(target: self, action: #selector(selectLocationOnMap(sender:)))
    }()

    private let mapSearch = MapSearch()

    @IBOutlet private weak var mapView: MKMapView!
    @IBOutlet private weak var searchField: NSSearchField!
    @IBOutlet weak var chooseButton: NSButton!

    override func viewDidLoad()
    {
        super.viewDidLoad()
        searchField.delegate = self
        chooseButton.isEnabled = false
        chooseButton.isHighlighted = true
    }

    override func viewWillAppear()
    {
        super.viewWillAppear()
        mapView.addGestureRecognizer(clickGestureRecognizer)
    }

    override func viewWillDisappear()
    {
        super.viewWillDisappear()
        mapView.removeGestureRecognizer(clickGestureRecognizer)
    }
    
    @IBAction func chooseLocation(_ sender: NSButton)
    {
        if let coordinate = currentPlacemark?.coordinate {
            delegate?.didChooseLocation?(location: coordinate)
            self.dismiss(sender)
        }
    }

    @IBAction func cancel(_ sender: NSButton)
    {
        self.dismiss(sender)
    }

    @objc private func selectLocationOnMap(sender: NSClickGestureRecognizer)
    {
        if sender.state == .ended {
            let clickLocation = sender.location(in: mapView)
            let coordinates = mapView.convert(clickLocation, toCoordinateFrom: mapView)
            let location = CLLocation(latitude: coordinates.latitude, longitude: coordinates.longitude)
            mapSearch.reverseGeocode(location: location) { [weak self] (placemarks, error) in
                guard error == nil else { return }
                guard placemarks != nil && placemarks?.first != nil else { return }
                let placemark = placemarks!.first!
                self?.currentPlacemark = MKPlacemark(placemark: placemark)
            }
        }
    }
}

// MARK: - NSSearchfieldDelegate
extension MapViewController: NSSearchFieldDelegate
{
    func controlTextDidEndEditing(_ obj: Notification) {
        mapSearch.search(for: searchField.stringValue) { [weak self] (response, error) in
            guard error == nil else { return }
            guard response != nil else { return }
            guard let mapItem = response?.mapItems.first else { return }
            self?.currentPlacemark = mapItem.placemark
        }
    }
}

@objc protocol MapViewControllerDelegate
{
    @objc optional func didChooseLocation(location: CLLocationCoordinate2D)
}
