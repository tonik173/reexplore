//
//  InAppPurchaseProducts.swift
//  Reexplore
//
//  Created by Flavian Kaufmann on 16.11.20.
//  Copyright © 2020 n3xd software studios ag. All rights reserved.
//
import Foundation

struct InAppPurchaseProducts
{
    private static let enableAllPurchases = false

    enum AvailableProducts: InAppPurchaseProvider.ProductId, CaseIterable {
        case gpxTrack = "com.n3xd.reexplore.iap.swissmaps"
    }

    static func isPurchased(_ product: AvailableProducts) -> Bool
    {
        let trialAvailable = SecureStore.isAvailableForTrial(feature: .gpxUpload)
        if enableAllPurchases || trialAvailable {
            return true
        }
        return Preferences.purchasedInAppPurchases[product.rawValue] ?? false
    }

    private static var productIds: Set<InAppPurchaseProvider.ProductId> {
        var ids = Set<InAppPurchaseProvider.ProductId>()
        for id in AvailableProducts.allCases {
            ids.insert(id.rawValue)
        }
        return ids
    }

    static let provider = InAppPurchaseProvider(productIds: productIds)
}

// Note: at this time, ReExplore has no purchable products. However, the infrastructure is here and we will enable it in the future.
