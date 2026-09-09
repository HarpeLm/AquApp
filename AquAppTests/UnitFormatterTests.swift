//
//  UnitFormatterTests.swift
//  AquApp
//
//  Created by Fabian Dargaud on 07/09/2026.
//


import XCTest
@testable import AquApp

final class UnitFormatterTests: XCTestCase {

    func testVolume_ContainsUnitSymbol() {
        let symbol = UnitFormatter.volumeUnitSymbol.lowercased()
        for ml in [0.0, 25, 250, 1630, 5000, 1_000_000] {
            XCTAssertTrue(UnitFormatter.volume(ml).lowercased().contains(symbol), "volume(\(ml))")
            XCTAssertTrue(UnitFormatter.volumeDecimal(ml).lowercased().contains(symbol), "volumeDecimal(\(ml))")
        }
    }

    func testVolumeNumber_HasNoUnitSymbol() {
        for ml in [0.0, 250, 1630, 999_999] {
            // La chaîne numérique ne doit contenir AUCUNE lettre (pas d'unité)
            XCTAssertFalse(UnitFormatter.volumeNumber(ml).contains(where: { $0.isLetter }))
            XCTAssertFalse(UnitFormatter.volumeNumber(ml).isEmpty)
        }
    }


    func testVolume_NegativeAndHuge_DontCrash() {
        _ = UnitFormatter.volume(-100)
        _ = UnitFormatter.volumeDecimal(-0.5)
        _ = UnitFormatter.volumeNumber(1e9)
    }

    func testVolumePlaceholder_ConsistentWithSymbol() {
        if UnitFormatter.volumeUnitSymbol == "fl oz" {
            XCTAssertEqual(UnitFormatter.volumePlaceholder, "fl oz")
        } else {
            XCTAssertEqual(UnitFormatter.volumePlaceholder, "ml")
        }
    }

    func testWeight_RoundTrips() {
        for kg in [0.0, 30, 55.5, 70, 100, 199.9, 200] {
            XCTAssertEqual(UnitFormatter.weightToSI(UnitFormatter.weightValue(kg)), kg, accuracy: 0.01, "kg=\(kg)")
        }
    }

    func testWeight_StringContainsSymbol() {
        for kg in [30.0, 70, 200] {
            XCTAssertTrue(UnitFormatter.weight(kg).contains(UnitFormatter.weightUnitSymbol))
        }
    }

    func testWeightToSI_Zero() {
        XCTAssertEqual(UnitFormatter.weightToSI(0), 0, accuracy: TestKit.accuracy)
    }

    func testHeight_MetricBranch() {
        guard !UnitFormatter.usesImperialLength else { return }
        XCTAssertEqual(UnitFormatter.height(175), "175 cm")
        XCTAssertEqual(UnitFormatter.height(175.9), "175 cm")
        XCTAssertEqual(UnitFormatter.height(0), "0 cm")
        XCTAssertEqual(UnitFormatter.height(220), "220 cm")
    }

    func testHeight_ImperialBranch() {
        guard UnitFormatter.usesImperialLength else { return }
        XCTAssertEqual(UnitFormatter.height(175), "5 ft 8 in")
        XCTAssertEqual(UnitFormatter.height(304.8), "10 ft 0 in")
        XCTAssertEqual(UnitFormatter.height(140), "4 ft 7 in")
    }

    func testHeight_RoundTrips() {
        for cm in [140.0, 155.3, 175, 200.7, 220] {
            XCTAssertEqual(UnitFormatter.heightToSI(UnitFormatter.heightValue(cm)), cm, accuracy: 0.01)
        }
    }

    func testHeightUnitSymbol_Consistent() {
        XCTAssertEqual(UnitFormatter.heightUnitSymbol, UnitFormatter.usesImperialLength ? "in" : "cm")
    }

    func testSliderBounds_Strings() {
        XCTAssertEqual(UnitFormatter.volumeSliderBound(250), UnitFormatter.volume(250))
        XCTAssertTrue(UnitFormatter.weightSliderBound(70).contains(UnitFormatter.weightUnitSymbol))
        if UnitFormatter.usesImperialLength {
            XCTAssertTrue(UnitFormatter.heightSliderBound(175).contains("'"))
        } else {
            XCTAssertEqual(UnitFormatter.heightSliderBound(175), "175 cm")
        }
    }

    func testSliderRanges_ExactValues() {
        XCTAssertEqual(UnitFormatter.waterSliderRange, 50...2000)
        XCTAssertEqual(UnitFormatter.goalSliderRange, 500...5000)
        XCTAssertEqual(UnitFormatter.heightSliderRange, UnitFormatter.usesImperialLength ? 55...87 : 140...220)
        XCTAssertLessThan(UnitFormatter.weightSliderRange.lowerBound, UnitFormatter.weightSliderRange.upperBound)
    }
}
