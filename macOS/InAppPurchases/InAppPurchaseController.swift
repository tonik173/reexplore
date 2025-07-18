//
//  InAppPurchaseController.swift
//  Reexplore-macOS
//
//  Created by Flavian Kaufmann on 30.12.20.
//  Copyright © 2020 n3xd software studios ag. All rights reserved.
//

import Foundation
import Cocoa

protocol InAppPurchaseController where Self: NSWindowController {
    var product: InAppPurchaseProducts.AvailableProducts { get }
}

extension InAppPurchaseController {

    func showInAppPurchaseViewController() {
        if InAppPurchaseProducts.isPurchased(self.product) {

        } else {
            if let inAppPurchaseViewController = createInAppPurchaseViewController() {
                self.contentViewController?.presentAsSheet(inAppPurchaseViewController)
            }
        }
    }

    private func createInAppPurchaseViewController() -> InAppPurchaseViewController? {
        let storyBoard = NSStoryboard(name: "Main", bundle: Bundle.main)
        let vc = storyBoard.instantiateController(withIdentifier: .init("InAppPurchaseViewController"))
        guard let inAppPurchaseViewController = vc as? InAppPurchaseViewController else { return nil }
        inAppPurchaseViewController.product = self.product
        return inAppPurchaseViewController
    }
}
