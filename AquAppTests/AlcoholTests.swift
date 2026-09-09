//
//  AlcoholTests.swift
//  AquApp
//
//  Created by Fabian Dargaud on 07/09/2026.
//


import XCTest
@testable import AquApp

final class AlcoholTests: XCTestCase {

    // MARK: - Formules Scientifiques

    func testPureAlcoholGrams_Formula() {
        // Formule : volume(ml) × (ABV/100) × 0.789 (densité éthanol)
        let beer = AlcoholKind.beer // 5.0% ABV
        let volumeMl: Double = 500.0 // Une pinte
        
        let grams = beer.pureAlcoholGrams(for: volumeMl)
        let expected = 500.0 * (5.0 / 100.0) * 0.789 // ≈ 19.725g
        
        XCTAssertEqual(grams, expected, accuracy: 0.01, "La formule de l'alcool pur est incorrecte")
    }

    func testStandardDrinks_Calculation() {
        let wine = AlcoholKind.wine // 12.5% ABV
        let volumeMl: Double = 150.0 // Un verre de vin
        
        let grams = wine.pureAlcoholGrams(for: volumeMl)
        let standardDrinks = grams / 10.0
        
        // 150ml * 12.5% * 0.789 = 14.79g -> 1.48 unités
        XCTAssertEqual(standardDrinks, 1.48, accuracy: 0.01)
    }

    func testCompensationMl_WaterToDrink() {
        // Pour 10g d'alcool pur, il faut compenser par 100ml d'eau
        let beer = AlcoholKind.beer
        let volumeMl: Double = 250.0
        
        let compensation = beer.compensationMl(for: volumeMl)
        let pureGrams = beer.pureAlcoholGrams(for: volumeMl)
        
        XCTAssertEqual(compensation, pureGrams * 10.0, accuracy: 0.01, "Le facteur de compensation doit être de 10")
    }

    // MARK: - Migration des Données (v1.0 -> v1.1)

    func testAlcoholKindMigration_HandlesFrenchRawValues() {
        // Simule les anciennes valeurs persistées avant la v1.1
        XCTAssertEqual(AlcoholKind.migratedAlcoholKind(from: "Bière"), .beer)
        XCTAssertEqual(AlcoholKind.migratedAlcoholKind(from: "Vin"), .wine)
        XCTAssertEqual(AlcoholKind.migratedAlcoholKind(from: "Spiritueux"), .spirits)
        XCTAssertEqual(AlcoholKind.migratedAlcoholKind(from: "Cocktail"), .cocktail)
    }

    func testAlcoholKindMigration_HandlesNewEnglishRawValues() {
        // Les nouvelles valeurs doivent fonctionner directement
        XCTAssertEqual(AlcoholKind.migratedAlcoholKind(from: "beer"), .beer)
        XCTAssertEqual(AlcoholKind.migratedAlcoholKind(from: "wine"), .wine)
    }

    func testAlcoholKindMigration_FallsBackToOther() {
        // Une valeur inconnue doit être traitée comme "other"
        XCTAssertEqual(AlcoholKind.migratedAlcoholKind(from: "UnknownDrink"), .other)
        XCTAssertEqual(AlcoholKind.migratedAlcoholKind(from: "Jus de pomme"), .other)
    }
}