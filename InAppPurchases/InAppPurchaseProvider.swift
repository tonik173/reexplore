//
//  InAppPurchaseProvider.swift
//  Reexplore
//
//  Created by Flavian Kaufmann on 30.10.20.
//  Copyright © 2020 n3xd software studios ag. All rights reserved.
//

import Foundation
import StoreKit

class InAppPurchaseProvider: NSObject {
    typealias ProductId = String
    typealias ProductsRequestCompletionHandler = (_ success: Bool, _ products: [SKProduct]?) -> Void

    private let productIds: Set<ProductId>
    private var purchasedProductIds: Set<ProductId> = []
    private var productsRequest: SKProductsRequest?
    private var productsRequestCompletionHandler: ProductsRequestCompletionHandler?

    public init(productIds: Set<ProductId>) {
        self.productIds = productIds

        let purchasedInAppPurchases = Preferences.purchasedInAppPurchases
        let purchasedProductIds = productIds.filter { (productId) in
            return purchasedInAppPurchases[productId] ?? false
        }
        self.purchasedProductIds.formUnion(purchasedProductIds)
        super.init()

        SKPaymentQueue.default().add(self)
    }
}

extension Notification.Name {
    static let InAppPurchaseProviderPurchaseNotification = Notification.Name("InAppPurchaseProviderPurchaseNotification")
}

// MARK: - StoreKit API

extension InAppPurchaseProvider {

    func requestProducts(_ completionHandler: @escaping ProductsRequestCompletionHandler) {
        productsRequest?.cancel()
        productsRequestCompletionHandler = completionHandler

        productsRequest = SKProductsRequest(productIdentifiers: productIds)
        productsRequest?.delegate = self
        productsRequest?.start()
    }

    func buyProduct(_ product: SKProduct) {
        let payment = SKPayment(product: product)
        SKPaymentQueue.default().add(payment)
    }

    func isProductPurchased(_ productIds: ProductId) -> Bool {
        return purchasedProductIds.contains(productIds)
    }

    func canMakePayments() -> Bool {
        return SKPaymentQueue.canMakePayments()
    }

    func restorePurchases() {
        SKPaymentQueue.default().restoreCompletedTransactions()
    }
}

// MARK: - SKProductsRequestDelegate

extension InAppPurchaseProvider: SKProductsRequestDelegate {

    func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        let products = response.products
        productsRequestCompletionHandler?(true, products)
        clearRequestAndHandler()
    }

    func request(_ request: SKRequest, didFailWithError error: Error) {
        productsRequestCompletionHandler?(false, nil)
        clearRequestAndHandler()
    }

    func clearRequestAndHandler() {
        productsRequest = nil
        productsRequestCompletionHandler = nil
    }
}

// MARK: - SKPaymentTransactionObserver

extension InAppPurchaseProvider: SKPaymentTransactionObserver {

    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        for transaction in transactions {
            switch (transaction.transactionState) {
                case .purchased:
                    complete(transaction: transaction)
                    break
                case .failed:
                    fail(transaction: transaction)
                    break
                case .restored:
                    restore(transaction: transaction)
                    break
                case .deferred:
                    break
                case .purchasing:
                    break
                default:
                    break
            }
        }
    }

    private func complete(transaction: SKPaymentTransaction) {
        deliverPurchaseNotificationFor(identifier: transaction.payment.productIdentifier)
        SKPaymentQueue.default().finishTransaction(transaction)
    }

    private func restore(transaction: SKPaymentTransaction) {
        guard let productIdentifier = transaction.original?.payment.productIdentifier else { return }
        deliverPurchaseNotificationFor(identifier: productIdentifier)
        SKPaymentQueue.default().finishTransaction(transaction)
    }

    private func fail(transaction: SKPaymentTransaction) {
        if let transactionError = transaction.error as NSError?,
           let localizedDescription = transaction.error?.localizedDescription,
           transactionError.code != SKError.paymentCancelled.rawValue {
            Log.iap("In App Purchase Transaction failed with: \(localizedDescription)")
        }

        SKPaymentQueue.default().finishTransaction(transaction)
    }

    private func deliverPurchaseNotificationFor(identifier: String?) {
        guard let identifier = identifier else { return }

        purchasedProductIds.insert(identifier)
        Preferences.purchasedInAppPurchases[identifier] = true
        NotificationCenter.default.post(name: .InAppPurchaseProviderPurchaseNotification, object: identifier)
    }
}
