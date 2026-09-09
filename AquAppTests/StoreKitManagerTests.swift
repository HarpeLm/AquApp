//
//  StoreKitManagerTests.swift
//  AquApp
//
//  Created by Fabian Dargaud on 07/09/2026.
//


import XCTest
import StoreKit
@testable import AquApp

@MainActor
final class StoreKitManagerTests: XCTestCase {

    func testProductIDs_Contract() {
        XCTAssertEqual(StoreKitManager.monthlyID, "com.AquApp.premium.monthly")
        XCTAssertEqual(StoreKitManager.yearlyID, "com.AquApp.premium.yearly")
        XCTAssertEqual(StoreKitManager.allProductIDs,
                       ["com.AquApp.premium.monthly", "com.AquApp.premium.yearly"])
    }

    func testProductFor_UnknownID_ReturnsNil() async {
        let m = StoreKitManager()
        await m.loadProducts()
        XCTAssertNil(m.product(for: "com.AquApp.premium.lifetime"))
        XCTAssertEqual(m.monthlyProduct, m.product(for: StoreKitManager.monthlyID))
        XCTAssertEqual(m.yearlyProduct, m.product(for: StoreKitManager.yearlyID))
    }

    func testRefreshPurchaseStatus_NoEntitlement_NotPremium() async {
        let m = StoreKitManager()
        await m.refreshPurchaseStatus()
        XCTAssertFalse(m.isPremiumUser)
        XCTAssertFalse(UserDefaults.standard.bool(forKey: "isPremiumUser"))
    }
}

final class HealthKitWriterTests: XCTestCase {

    /// Sur simulateur sans autorisation, write/delete doivent être des no-ops silencieux.
    func testWrite_NoCrash_WhenNotAuthorized() {
        HealthKitWriter.shared.write(amountMl: 250, date: Date(), entryID: UUID())
        HealthKitWriter.shared.delete(entryID: UUID(), date: Date())
        HealthKitWriter.shared.requestWriteAuthorizationIfNeeded()
    }
}
