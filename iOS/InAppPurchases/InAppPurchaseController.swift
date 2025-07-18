//
//  InAppPurchaseController.swift
//  Reexplore-iOS
//
//  Created by Flavian Kaufmann on 30.12.20.
//  Copyright © 2020 n3xd software studios ag. All rights reserved.
//
import Foundation
import UIKit

protocol InAppPurchaseController where Self: UIViewController {
    var product: InAppPurchaseProducts.AvailableProducts { get }
}

extension InAppPurchaseController {

    func showInAppPurchaseViewController()
    {
        if InAppPurchaseProducts.isPurchased(self.product)
        {

        }
        else {
            if let inAppPurchaseViewController = createInAppPurchaseViewController() {
                self.present(inAppPurchaseViewController, animated: true, completion: nil)
            }
        }
    }

    func enableIfPurchased()
    {
        if InAppPurchaseProducts.isPurchased(self.product) {
            self.view.isUserInteractionEnabled = true
            self.view.subviews.forEach { view in
                view.alpha = 1.0
            }
        }
        else {
            self.view.isUserInteractionEnabled = false
            self.view.subviews.forEach { view in
                view.alpha = 0.2
                view.isOpaque = false
            }
        }
    }

    private func createInAppPurchaseViewController() -> InAppPurchaseViewController?
    {
        let storyBoard = UIStoryboard(name: "Main", bundle: Bundle.main)
        let vc = storyBoard.instantiateViewController(identifier: "InAppPurchaseViewController")
        guard let inAppPurchaseViewController = vc as? InAppPurchaseViewController else { return nil }
        inAppPurchaseViewController.product = self.product
        return inAppPurchaseViewController
    }
}
