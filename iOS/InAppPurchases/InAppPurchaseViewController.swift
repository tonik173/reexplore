//
//  InAppPurchaseViewController.swift
//  Reexplore-iOS
//
//  Created by Flavian Kaufmann on 30.12.20.
//  Copyright © 2020 n3xd software studios ag. All rights reserved.
//

import UIKit
import StoreKit

class InAppPurchaseViewController: UIViewController
{
    var product: InAppPurchaseProducts.AvailableProducts?
    private var skProduct: SKProduct?
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var descriptionLabel: UILabel!
    @IBOutlet private weak var purchaseButton: UIButton!
    @IBOutlet private weak var purchaseButtonWidthConstraint: NSLayoutConstraint!
    @IBOutlet private weak var restorePurchaseButton: UIButton!
    @IBOutlet private weak var activityIndicator: UIActivityIndicatorView!

    private var isLoading: Bool = false {
        didSet {
            titleLabel.isHidden = isLoading
            descriptionLabel.isHidden = isLoading
            purchaseButton.isHidden = isLoading
            restorePurchaseButton.isHidden = isLoading

            activityIndicator.isHidden = !isLoading
            if isLoading {
                activityIndicator.startAnimating()
            } else {
                activityIndicator.stopAnimating()
            }
        }
    }

    override func viewDidLoad()
    {
        super.viewDidLoad()
        self.isLoading = true

        self.purchaseButton.backgroundColor = .secondarySystemBackground
        self.purchaseButton.layer.cornerRadius = 15

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
        self.titleLabel.text = product.localizedTitle
        let productDescription = "\(product.localizedDescription)\nYou have to buy this function just once for an unlimitted number of track uploads."
        self.descriptionLabel.text = productDescription

        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = product.priceLocale
        let buttonText = "Purchase for \(formatter.string(from: product.price) ?? "Error")"

        purchaseButton.setTitle(buttonText, for: .normal)
        let buttonFont = purchaseButton.titleLabel?.font
        let buttonSize = (buttonText as NSString).size(withAttributes: [.font:buttonFont as Any])
        purchaseButtonWidthConstraint.constant = buttonSize.width + 20
    }

    @IBAction private func purchase(_ sender: Any)
    {
        if let product = self.skProduct {
            InAppPurchaseProducts.provider.buyProduct(product)
        }
    }
    
    @IBAction private func restorePurchase(_ sender: Any)
    {
        InAppPurchaseProducts.provider.restorePurchases()
    }
    
    @IBAction private func close(_ sender: Any) {
        InAppPurchaseProducts.provider.clearRequestAndHandler()
        self.dismiss(animated: true, completion: nil)
    }
}
