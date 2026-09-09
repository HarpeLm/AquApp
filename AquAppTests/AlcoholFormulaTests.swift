import XCTest
@testable import AquApp

final class AlcoholFormulaTests: XCTestCase {

    func testConstants_AreSingleSourceOfTruth() {
        XCTAssertEqual(AlcoholKind.ethanolDensity, 0.789, accuracy: TestKit.accuracy)
        XCTAssertEqual(AlcoholKind.waterCompensationFactor, 10.0, accuracy: TestKit.accuracy)
    }

    // Valeurs calculées à la main : volume × (ABV/100) × 0.789
    func testPureAlcoholGrams_HandComputedValues() {
        let table: [(AlcoholKind, Double, Double)] = [
            (.beer,     500,  19.725),
            (.wine,     150,  14.79375),
            (.spirits,   40,  12.624),
            (.cider,    500,  17.7525),
            (.cocktail, 200,  23.67),
            (.other,    100,   6.312),
        ]
        for (kind, volume, expected) in table {
            XCTAssertEqual(kind.pureAlcoholGrams(for: volume), expected, accuracy: 0.00001,
                           "\(kind) \(volume)ml")
        }
    }

    func testPureAlcoholGrams_ZeroAndTiny() {
        for kind in AlcoholKind.allCases {
            XCTAssertEqual(kind.pureAlcoholGrams(for: 0), 0, accuracy: TestKit.accuracy)
            XCTAssertEqual(kind.pureAlcoholGrams(for: 1), kind.defaultAbv / 100 * 0.789, accuracy: TestKit.accuracy)
        }
    }

    func testPureAlcoholGrams_IsLinear() {
        for kind in AlcoholKind.allCases {
            let a = kind.pureAlcoholGrams(for: 250)
            let b = kind.pureAlcoholGrams(for: 500)
            XCTAssertEqual(b, a * 2, accuracy: TestKit.accuracy, "Linéarité violée pour \(kind)")
        }
    }

    func testCompensationMl_IsGramsTimesTen() {
        for kind in AlcoholKind.allCases {
            for volume in [0.0, 125, 250, 330, 500, 1000] {
                XCTAssertEqual(kind.compensationMl(for: volume),
                               kind.pureAlcoholGrams(for: volume) * 10,
                               accuracy: TestKit.accuracy)
            }
        }
    }

    func testCompensationMl_HandComputed() {
        XCTAssertEqual(AlcoholKind.beer.compensationMl(for: 500), 197.25, accuracy: 0.0001)
        XCTAssertEqual(AlcoholKind.wine.compensationMl(for: 150), 147.9375, accuracy: 0.0001)
    }

    func testStrongerDrink_CompensatesMore() {
        // À volume égal : spiritueux > cocktail > vin > autre > bière > cidre
        let v = 100.0
        XCTAssertGreaterThan(AlcoholKind.spirits.compensationMl(for: v), AlcoholKind.cocktail.compensationMl(for: v))
        XCTAssertGreaterThan(AlcoholKind.cocktail.compensationMl(for: v), AlcoholKind.wine.compensationMl(for: v))
        XCTAssertGreaterThan(AlcoholKind.wine.compensationMl(for: v), AlcoholKind.other.compensationMl(for: v))
        XCTAssertGreaterThan(AlcoholKind.other.compensationMl(for: v), AlcoholKind.beer.compensationMl(for: v))
        XCTAssertGreaterThan(AlcoholKind.beer.compensationMl(for: v), AlcoholKind.cider.compensationMl(for: v))
    }
}