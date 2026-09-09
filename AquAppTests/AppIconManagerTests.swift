//
//  AppIconManagerTests.swift
//  AquApp
//
//  Created by Fabian Dargaud on 07/09/2026.
//


import XCTest
@testable import AquApp

@MainActor
final class AppIconManagerTests: XCTestCase {

    var manager: AppIconManager!

    override func setUp() async throws {
        try await super.setUp()
        manager = AppIconManager()
    }

    func testDefaultIcon_IsOcean() {
        XCTAssertEqual(manager.currentIcon, .ocean)
    }

    func testSetIcon_SameIcon_Ignored() async {
        manager.setIcon(.ocean, isPremiumUser: false)
        try? await Task.sleep(for: .seconds(0.6))
        XCTAssertEqual(manager.currentIcon, .ocean)
        XCTAssertFalse(manager.isChanging)
    }

    func testSetIcon_PremiumIcon_LockedForFreeUser() async throws {
        guard let premium = AppIcon.allCases.first(where: { $0.isPremium }) else {
            throw XCTSkip("Aucune icône premium définie")
        }
        manager.setIcon(premium, isPremiumUser: false)
        try? await Task.sleep(for: .seconds(0.6))
        XCTAssertEqual(manager.currentIcon, .ocean, "Un utilisateur free ne doit pas pouvoir appliquer une icône premium")
    }

    func testSetIcon_FreeIcon_AppliesAfterDelay() async throws {
        guard let free = AppIcon.allCases.first(where: { !$0.isPremium && $0 != .ocean }) else {
            throw XCTSkip("Aucune icône gratuite secondaire")
        }
        manager.setIcon(free, isPremiumUser: false)
        XCTAssertTrue(manager.isChanging, "Pendant l'animation, isChanging doit être true")
        try? await Task.sleep(for: .seconds(0.6))
        XCTAssertEqual(manager.currentIcon, free)
        XCTAssertFalse(manager.isChanging)
    }

    func testSetIcon_PremiumUser_CanApplyPremiumIcon() async throws {
        guard let premium = AppIcon.allCases.first(where: { $0.isPremium }) else {
            throw XCTSkip("Aucune icône premium définie")
        }
        manager.setIcon(premium, isPremiumUser: true)
        try? await Task.sleep(for: .seconds(0.6))
        XCTAssertEqual(manager.currentIcon, premium)
    }

    func testReentrancyGuard_SecondCallIgnored() async throws {
        guard let free1 = AppIcon.allCases.first(where: { !$0.isPremium && $0 != .ocean }),
              let free2 = AppIcon.allCases.last(where: { !$0.isPremium && $0 != free1 }) else {
            throw XCTSkip("Pas assez d'icônes gratuites")
        }
        manager.setIcon(free1, isPremiumUser: false)
        manager.setIcon(free2, isPremiumUser: false)
        try? await Task.sleep(for: .seconds(0.6))
        XCTAssertEqual(manager.currentIcon, free1)
    }
}
