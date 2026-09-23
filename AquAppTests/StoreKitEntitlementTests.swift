//
//  StoreKitEntitlementTests.swift
//  AquApp
//
//  Created by Fabian Dargaud on 13/09/2026.
//


import XCTest
import StoreKit
@testable import AquApp

@MainActor
final class StoreKitEntitlementTests: XCTestCase {

    func testRefreshPurchaseStatus_singleSourceOfTruth() async throws {
        let manager = StoreKitManager()

        await manager.refreshPurchaseStatus()

        XCTAssertFalse(manager.isPremiumUser,
            "Sans entitlement actif, isPremiumUser doit être false")
    }

    func testPremiumManagerSynchronization() async throws {
        let manager = StoreKitManager()

        await manager.refreshPurchaseStatus()

        XCTAssertEqual(
            manager.isPremiumUser,
            PremiumManager.shared.isPremium,
            "StoreKitManager et PremiumManager doivent être synchronisés"
        )
    }

    func testProductIDs_areValid() {
        XCTAssertEqual(StoreKitManager.monthlyID, "com.AquApp.premium.monthly")
        XCTAssertEqual(StoreKitManager.yearlyID, "com.AquApp.premium.yearly")
        XCTAssertEqual(StoreKitManager.allProductIDs.count, 2)
    }

    func testLoadProducts_doesNotCrash() async throws {
        let manager = StoreKitManager()

        await manager.loadProducts()

        XCTAssertGreaterThanOrEqual(manager.products.count, 0)
    }

    func testMonthlyTrialDuration_accessible() async throws {
        let manager = StoreKitManager()
        _ = manager.monthlyTrialDuration
    }
}
