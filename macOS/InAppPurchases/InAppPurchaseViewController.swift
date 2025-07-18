//
//  InAppPurchaseViewController.swift
//  Reexplore-macOS
//
//  Created by Flavian Kaufmann on 30.12.20.
//  Copyright © 2020 n3xd software studios ag. All rights reserved.
//

import Cocoa
import StoreKit

class InAppPurchaseViewController: NSViewController {

    var product: InAppPurchaseProducts.AvailableProducts?
    private var skProduct: SKProduct?

    private var isLoading: Bool = false {
        didSet {
            titleTextField.isHidden = isLoading
            descriptionTextField.isHidden = isLoading
            purchaseButton.isHidden = isLoading
            restorePurchaseButton.isHidden = isLoading

            progressIndicator.isHidden = !isLoading
            if isLoading {
                progressIndicator.startAnimation(self)
            } else {
                progressIndicator.stopAnimation(self)
            }
        }
    }

    @IBOutlet weak var titleTextField: NSTextField!
    @IBOutlet weak var descriptionTextField: NSTextField!
    @IBOutlet weak var purchaseButton: NSButton!
    @IBOutlet weak var restorePurchaseButton: NSButton!
    @IBOutlet weak var doneButton: NSButton!
    @IBOutlet weak var progressIndicator: NSProgressIndicator!
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        self.isLoading = true

        InAppPurchaseProducts.provider.requestProducts { [weak self] (success, products) in
            if success && products != nil {
                for product in products! {
                    if product.productIdentifier == self?.product?.rawValue {
                        DispatchQueue.main.async {
                            self?.skProduct = product
                            self?.setupView(product: product)
                            self?.isLoading = false
                        }
                        break
                    }
                }
            }
        }
    }

    private func setupView(product: SKProduct)
    {
        self.titleTextField.stringValue = product.localizedTitle
        let productDescription = "\(product.localizedDescription)\nYou have to buy this function just once for an unlimitted number of track uploads."
        self.descriptionTextField.stringValue = productDescription
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = product.priceLocale
        let buttonText = "Purchase for \(formatter.string(from: product.price) ?? "Error")"
        purchaseButton.title = buttonText
    }

    @IBAction func purchase(_ sender: Any) {
        if let product = self.skProduct {
            InAppPurchaseProducts.provider.buyProduct(product)
        }
    }
    @IBAction func restorePurchases(_ sender: Any) {
        InAppPurchaseProducts.provider.restorePurchases()
    }
    @IBAction func close(_ sender: Any) {
        InAppPurchaseProducts.provider.clearRequestAndHandler()
        self.dismiss(self)
    }
    
}
