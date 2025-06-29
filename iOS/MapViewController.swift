//
//  MapViewController.swift
//  Reexplore-iOS
//
//  Created by Flavian Kaufmann on 10.09.20.
//  Copyright © 2020 n3xd software studios ag. All rights reserved.
//
import UIKit
import MapKit

class MapNavigationController: UINavigationController
{
    override func viewDidLoad()
    {
        super.viewDidLoad()
        self.navigationBar.tintColor = .brown
    }
}

class MapViewController: UIViewController
{
    var location: CLLocation? = .none
    
    internal lazy var vc: ViewController = {
        guard
            let appDelegate = UIApplication.shared.delegate as? AppDelegate,
            let window = appDelegate.window,
            let vc = window.rootViewController as? ViewController
        else { fatalError("view controller not found") }
        return vc
    }()
    
    // MARK: - Private Properties

    private lazy var tapGestureRecognizer: UITapGestureRecognizer = {
        return UITapGestureRecognizer(target: self, action: #selector(selectLocationOnMap(sender:)))
    }()

    private let mapSearch = MapSearch()

    private lazy var mapSearchResultsViewController: MapSearchResultsViewController = {
        let storyboard = UIStoryboard(name: "Main", bundle: .main)
        let viewController = storyboard.instantiateViewController(identifier: "MapSearchResultsViewController")
        let mapSearchResultsViewController = viewController as! MapSearchResultsViewController
        mapSearchResultsViewController.delegate = self
        return mapSearchResultsViewController
    }()

    private lazy var searchController: UISearchController = {
        let searchController = UISearchController(searchResultsController: mapSearchResultsViewController)
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.hidesNavigationBarDuringPresentation = false
        return searchController
    }()
    
    @IBAction func chancel(_ sender: UIBarButtonItem)
    {
        self.dismiss(animated: true) { }
    }
    
    @IBAction func done(_ sender: UIBarButtonItem)
    {
        var coordinates: CLLocationCoordinate2D? = .none
        if let coord = self.location?.coordinate {
            coordinates = coord
        }
        else {
            coordinates = mapView.centerCoordinate
        }

        if let coord = coordinates {
            var config = vc.gameConfig
            config.location = GeoLocation(lat: coord.latitude, lon: coord.longitude)
            vc.updateGameConfig(config, changed: .location) { }
        }
        
        self.dismiss(animated: true) { }
    }
    
    // MARK: - IB Outlets

    @IBOutlet private weak var mapView: MKMapView!

    // MARK: - Target Actions

    @objc private func selectLocationOnMap(sender: UITapGestureRecognizer)
    {
        if sender.state == .ended {
            let touchLocation = sender.location(in: mapView)
            let coordinates = mapView.convert(touchLocation, toCoordinateFrom: mapView)
            let location = CLLocation(latitude: coordinates.latitude, longitude: coordinates.longitude)
            mapSearch.reverseGeocode(location: location) { [weak self] (placemarks, error) in
                guard error == nil else { return }
                guard placemarks != nil else { return }
                guard !placemarks!.isEmpty else { return }
                self?.mapView.show(annotation: MKPlacemark(placemark: placemarks!.first!))
                self?.location = location
            }
        }
    }

    // MARK: - ViewController Lifecycle

    override func viewDidLoad()
    {
        super.viewDidLoad()
        self.navigationItem.searchController = searchController
        definesPresentationContext = true
        
        let textAttributes = [NSAttributedString.Key.foregroundColor:UIColor.brown]
        navigationController?.navigationBar.titleTextAttributes = textAttributes
        self.title = "Select Location"
    }

    override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated)
        mapView.addGestureRecognizer(tapGestureRecognizer)
    }

    override func viewWillDisappear(_ animated: Bool)
    {
        super.viewWillDisappear(animated)
        mapView.removeGestureRecognizer(tapGestureRecognizer)
    }
}

// MARK: - UISearchResultsUpdating

extension MapViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        let searchText = searchController.searchBar.text ?? ""
        mapSearch.search(for: searchText) { [weak self] (response, error) in
            guard error == nil else { return }
            guard response != nil else { return }
            let placemarks = response!.mapItems.map { $0.placemark }
            self?.mapSearchResultsViewController.placemarks = placemarks
        }
    }
}

// MARK: - MapSearchResultsViewControllerDelegate

extension MapViewController: MapSearchResultsViewControllerDelegate {
    func didSelect(placemark: MKPlacemark) {
        searchController.dismiss(animated: true, completion: nil)
        mapView.show(annotation: placemark)
    }
}

