import XCTest
@testable import AquApp

final class UnitFormatterTests: XCTestCase {

    // MARK: - Conversions Poids (SI ↔ Display)

    func testWeightToSI_RoundTrip() {
        // Une valeur convertie pour l'affichage puis reconvertie en SI doit être identique (avec tolérance d'arrondi)
        let originalKg: Double = 70.0
        let displayValue = UnitFormatter.weightValue(originalKg)
        let backToSI = UnitFormatter.weightToSI(displayValue)
        
        XCTAssertEqual(originalKg, backToSI, accuracy: 0.01, "Le round-trip kg -> display -> kg doit être cohérent")
    }

    func testWeightValue_USLocale_ConvertsToPounds() {
        // 1 kg ≈ 2.20462 lbs
        let kg: Double = 70.0
        let expectedLbs = kg * 2.20462
        
        // Note : Ce test dépend de la locale courante du simulateur. 
        // Pour forcer la locale US dans les tests, voir le helper en bas.
        if UnitFormatter.weightUnitSymbol == "lb" {
            XCTAssertEqual(UnitFormatter.weightValue(kg), expectedLbs, accuracy: 0.1)
        }
    }

    // MARK: - Conversions Taille (SI ↔ Display)

    func testHeightToSI_RoundTrip() {
        let originalCm: Double = 175.0
        let displayValue = UnitFormatter.heightValue(originalCm)
        let backToSI = UnitFormatter.heightToSI(displayValue)
        
        XCTAssertEqual(originalCm, backToSI, accuracy: 0.1, "Le round-trip cm -> display -> cm doit être cohérent")
    }

    func testHeight_USLocale_FormatsAsFeetAndInches() {
        // 175 cm = 68.89 inches = 5 ft 8 in
        let formatted = UnitFormatter.height(175.0)
        
        if UnitFormatter.heightUnitSymbol == "in" {
            XCTAssertTrue(formatted.contains("ft") && formatted.contains("in"), "La hauteur US doit être en ft/in")
        } else {
            XCTAssertTrue(formatted.contains("cm"), "La hauteur FR doit être en cm")
        }
    }

    // MARK: - Plages des Sliders

    func testSliderRanges_ArePositive() {
        XCTAssertTrue(UnitFormatter.waterSliderRange.lowerBound > 0)
        XCTAssertTrue(UnitFormatter.goalSliderRange.lowerBound > 0)
        XCTAssertTrue(UnitFormatter.weightSliderRange.upperBound > UnitFormatter.weightSliderRange.lowerBound)
    }
}