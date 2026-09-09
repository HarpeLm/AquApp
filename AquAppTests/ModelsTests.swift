//
//  ModelsTests.swift
//  AquApp
//
//  Created by Fabian Dargaud on 07/09/2026.
//


import XCTest
@testable import AquApp

final class ModelsTests: XCTestCase {

    // MARK: - WaterEntry

    func testWaterEntry_DefaultInit() {
        let before = Date()
        let e = WaterEntry(amountMl: 250)
        let after = Date()
        XCTAssertEqual(e.amountMl, 250)
        XCTAssertNil(e.siriIntentID)
        XCTAssertGreaterThanOrEqual(e.date, before)
        XCTAssertLessThanOrEqual(e.date, after)
    }

    func testWaterEntry_IDsAreUnique() {
        let a = WaterEntry(amountMl: 100)
        let b = WaterEntry(amountMl: 100)
        XCTAssertNotEqual(a.id, b.id)
    }

    func testWaterEntry_SiriIntentIDStored() {
        let e = WaterEntry(amountMl: 330, siriIntentID: "siri-123")
        XCTAssertEqual(e.siriIntentID, "siri-123")
    }

    func testWaterEntry_DayIsStartOfDay() {
        let date = Date()
        let e = WaterEntry(amountMl: 100, date: date)
        XCTAssertEqual(e.day, Calendar.current.startOfDay(for: date))
    }

    func testWaterEntry_EdgeAmounts() {
        XCTAssertEqual(WaterEntry(amountMl: 0).amountMl, 0)
        XCTAssertEqual(WaterEntry(amountMl: 0.5).amountMl, 0.5)
        XCTAssertEqual(WaterEntry(amountMl: 100_000).amountMl, 100_000)
    }

    // MARK: - AlcoholKind : table complète

    func testAlcoholKind_AllCases_CompleteMapping() {
        let table: [(AlcoholKind, String, String, Double)] = [
            (.beer,     "beer",     "mug.fill",              5.0),
            (.wine,     "wine",     "wineglass.fill",       12.5),
            (.spirits,  "spirits",  "flask.fill",           40.0),
            (.cider,    "cider",    "bubbles.and.sparkles",  4.5),
            (.cocktail, "cocktail", "party.popper.fill",    15.0),
            (.other,    "other",    "drop.fill",             8.0),
        ]
        XCTAssertEqual(AlcoholKind.allCases.count, 6)
        for (kind, raw, symbol, abv) in table {
            XCTAssertEqual(kind.rawValue, raw)
            XCTAssertEqual(kind.sfSymbol, symbol)
            XCTAssertEqual(kind.defaultAbv, abv, accuracy: TestKit.accuracy)
            XCTAssertEqual(AlcoholKind(rawValue: raw), kind) // round-trip
        }
    }

    // MARK: - Migration v1.0 → v1.1

    func testMigration_FrenchRawValues() {
        let table: [(String, AlcoholKind)] = [
            ("Bière", .beer), ("Vin", .wine), ("Spiritueux", .spirits),
            ("Cidre", .cider), ("Cocktail", .cocktail), ("Autre", .other),
        ]
        for (raw, expected) in table {
            XCTAssertEqual(AlcoholKind.migratedAlcoholKind(from: raw), expected, "Échec migration pour \(raw)")
        }
    }

    func testMigration_EnglishRawValues() {
        for kind in AlcoholKind.allCases {
            XCTAssertEqual(AlcoholKind.migratedAlcoholKind(from: kind.rawValue), kind)
        }
    }

    func testMigration_JunkInputs_FallbackToOther() {
        let junk = ["", " ", "🍺", "null", "BIÈRE", "bière", "beer ", " Bière", "123", "vin"]
        for raw in junk {
            XCTAssertEqual(AlcoholKind.migratedAlcoholKind(from: raw), .other, "Junk non géré : \(raw)")
        }
    }

    // MARK: - WaterAlcoholEntry

    func testAlcoholEntry_InitAndSetter() {
        let e = WaterAlcoholEntry(amountMl: 250, alcoholType: .wine)
        XCTAssertEqual(e.alcoholKindRaw, "wine")
        XCTAssertEqual(e.alcoholType, .wine)
        e.alcoholType = .spirits
        XCTAssertEqual(e.alcoholKindRaw, "spirits")
    }

    func testAlcoholEntry_InPlaceMigration_RewritesRaw() {
        let e = WaterAlcoholEntry(amountMl: 250, alcoholType: .beer)
        e.alcoholKindRaw = "Bière"              // simule une persistance v1.0
        XCTAssertEqual(e.alcoholType, .beer)    // lecture migrée
        XCTAssertEqual(e.alcoholKindRaw, "beer") // raw réécrit en place
    }

    func testAlcoholEntry_PureGrams_MatchesFormula() {
        let e = WaterAlcoholEntry(amountMl: 500, alcoholType: .beer)
        let expected = (500.0 / 1000.0) * 789.0 * (5.0 / 100.0) // 19.725
        XCTAssertEqual(e.pureAlcoholGrams, expected, accuracy: TestKit.accuracy)
        XCTAssertEqual(e.pureAlcoholGrams, e.alcoholType.pureAlcoholGrams(for: e.amountMl), accuracy: TestKit.accuracy)
    }

    func testAlcoholEntry_StandardDrinks() {
        let e = WaterAlcoholEntry(amountMl: 100, alcoholType: .other) // 8% → 6.312 g
        XCTAssertEqual(e.standardDrinks, e.pureAlcoholGrams / 10.0, accuracy: TestKit.accuracy)
        XCTAssertEqual(e.standardDrinks, 0.6312, accuracy: 0.0001)
    }

    func testAlcoholEntry_CompensationMl() {
        let e = WaterAlcoholEntry(amountMl: 250, alcoholType: .wine)
        XCTAssertEqual(e.compensationMl, e.alcoholType.compensationMl(for: 250), accuracy: TestKit.accuracy)
    }

    func testAlcoholEntry_DayIsStartOfDay() {
        let date = Date()
        let e = WaterAlcoholEntry(amountMl: 100, alcoholType: .cider, date: date)
        XCTAssertEqual(e.day, Calendar.current.startOfDay(for: date))
    }

    // MARK: - DayRecord

    func testDayRecord_DateNormalizedToStartOfDay() {
        let noon = Calendar.current.date(bySettingHour: 14, minute: 30, second: 0, of: Date())!
        let r = DayRecord(date: noon, goalMl: 2000)
        XCTAssertEqual(r.date, Calendar.current.startOfDay(for: noon))
    }

    func testDayRecord_Defaults() {
        let r = DayRecord(date: Date(), goalMl: 1500)
        XCTAssertNil(r.weightKg)
        XCTAssertNil(r.temperatureC)
        XCTAssertFalse(r.goalReached)
    }

    func testDayRecord_FullInit() {
        let r = DayRecord(date: Date(), goalMl: 2500, weightKg: 70, temperatureC: 35, goalReached: true)
        XCTAssertEqual(r.goalMl, 2500)
        XCTAssertEqual(r.weightKg, 70)
        XCTAssertEqual(r.temperatureC, 35)
        XCTAssertTrue(r.goalReached)
    }
}