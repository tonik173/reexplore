//
//  MapSearchResultsViewController.swift
//  Reexplore-iOS
//
//  Created by Flavian Kaufmann on 10.09.20.
//  Copyright © 2020 n3xd software studios ag. All rights reserved.
//

import Foundation
import UIKit
import MapKit

class MapSearchResultsViewController: UITableViewController {

    // MARK: - Public Properties

    weak var delegate: MapSearchResultsViewControllerDelegate?

    var placemarks: [MKPlacemark] = [] {
        didSet {
            tableView.reloadData()
        }
    }

    // MARK: - UITableViewDataSource

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return placemarks.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "MapSearchResultCell", for: indexPath)
        let placemark = placemarks[indexPath.row]
        cell.textLabel?.text = placemark.name
        cell.detailTextLabel?.text = placemark.format()?.replacingOccurrences(of: "\n", with: ", ")
        return cell
    }

    // MARK: - UITableViewDelegate

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let placemark = placemarks[indexPath.row]
        delegate?.didSelect?(placemark: placemark)
    }
    
}

@objc protocol MapSearchResultsViewControllerDelegate {
    @objc optional func didSelect(placemark: MKPlacemark)
}
