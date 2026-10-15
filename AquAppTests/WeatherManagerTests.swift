//
//  WeatherManagerTests.swift
//  AquApp
//
//  Created by Fabian Dargaud on 07/09/2026.
//


import XCTest
import SwiftData
import CoreLocation
@testable import AquApp

final class WeatherManagerContractTests: XCTestCase {

    /// Contrat : +200 ml/degré au-dessus de 32 °C, plafond +1000 ml, base 2170 ml.
    func testHeatwaveFormula_ContractTable() {
        let base = 2170.0
        let table: [(Double, Bool, Double)] = [
            (-10, false, 0), (0, false, 0), (31.99, false, 0),
            (32.0, true, 0), (32.5, true, 100), (33, true, 200),
            (35, true, 600), (36.9, true, 980),
            (37, true, 1000), (37.5, true, 1000), (45, true, 1000),
        ]
        for (temp, isHeat, bonus) in table {
            XCTAssertEqual(temp >= 32.0, isHeat, "temp=\(temp)")
            let extra = isHeat ? min((temp - 32.0) * 200, 1000) : 0
            XCTAssertEqual((extra + base).rounded(), bonus + base, accuracy: 0.5, "temp=\(temp)")
        }
    }
}

// MARK: - Comportement de WeatherManager (sans réseau)

@MainActor
final class WeatherManagerHeatwaveTests: XCTestCase {

    private var container: ModelContainer!
    private var store: AppDataStore!
    private var weather: WeatherManager!

    override func setUp() async throws {
        try await super.setUp()
        HealthDataManager.shared.resetForTests()
        container = try ModelContainer(
            for: WaterEntry.self, WaterAlcoholEntry.self, DayRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        store = AppDataStore(modelContext: container.mainContext)
        store.dailyGoalMl = 2000
        store.heatwaveGoalMl = nil
        weather = WeatherManager(store: store)
    }

    override func tearDown() async throws {
        weather = nil
        store = nil
        container = nil
        try await super.tearDown()
    }

    func testInitialState_noHeatwave() {
        XCTAssertNil(weather.currentTemperatureC)
        XCTAssertFalse(weather.isHeatwave)
        XCTAssertNil(weather.adaptedGoalMl)
    }

    func testBelowThreshold_noHeatwave() {
        weather.applyTemperature(31.9)
        XCTAssertEqual(weather.currentTemperatureC, 31.9)
        XCTAssertFalse(weather.isHeatwave)
        XCTAssertNil(weather.adaptedGoalMl)
    }

    func testAtThreshold_heatwaveWithoutBonus() {
        weather.applyTemperature(32)
        XCTAssertTrue(weather.isHeatwave)
        XCTAssertEqual(weather.adaptedGoalMl, 2000)
    }

    func testAboveThreshold_adds200mlPerDegree() {
        weather.applyTemperature(35)
        XCTAssertTrue(weather.isHeatwave)
        XCTAssertEqual(weather.adaptedGoalMl, 2600)
    }

    func testFractionalTemperature_isRoundedToTheMillilitre() {
        weather.applyTemperature(32.33)
        XCTAssertEqual(weather.adaptedGoalMl, 2066)
    }

    func testBonus_isCappedAt1000ml() {
        weather.applyTemperature(45)
        XCTAssertEqual(weather.adaptedGoalMl, 3000)
    }

    func testAdaptedGoal_followsTheCurrentDailyGoal() {
        store.dailyGoalMl = 2500
        weather.applyTemperature(33)
        XCTAssertEqual(weather.adaptedGoalMl, 2700)
    }

    func testMissingTemperature_clearsAnOngoingHeatwave() {
        weather.applyTemperature(35)
        weather.applyTemperature(nil)   // erreur WeatherKit, localisation refusée…
        XCTAssertNil(weather.currentTemperatureC)
        XCTAssertFalse(weather.isHeatwave)
        XCTAssertNil(weather.adaptedGoalMl)
    }

    func testCoolingDown_endsTheHeatwave() {
        weather.applyTemperature(36)
        weather.applyTemperature(24)
        XCTAssertEqual(weather.currentTemperatureC, 24)
        XCTAssertFalse(weather.isHeatwave)
        XCTAssertNil(weather.adaptedGoalMl)
    }

    func testNewReading_replacesThePreviousGoal() {
        weather.applyTemperature(34)
        weather.applyTemperature(36)
        XCTAssertEqual(weather.adaptedGoalMl, 2800)
    }
}

// MARK: - Position envoyée à WeatherKit

final class WeatherCoarseLocationTests: XCTestCase {

    func testCoordinates_areRoundedToTwoDecimals() {
        let paris = WeatherManager.coarseLocation(latitude: 48.856_61, longitude: 2.352_22)
        XCTAssertEqual(paris.coordinate.latitude, 48.86, accuracy: 1e-9)
        XCTAssertEqual(paris.coordinate.longitude, 2.35, accuracy: 1e-9)
    }

    func testNegativeCoordinates_areRoundedToo() {
        let sydney = WeatherManager.coarseLocation(latitude: -33.868_82, longitude: 151.209_29)
        XCTAssertEqual(sydney.coordinate.latitude, -33.87, accuracy: 1e-9)
        XCTAssertEqual(sydney.coordinate.longitude, 151.21, accuracy: 1e-9)
    }

    func testAlreadyCoarseCoordinates_areUnchanged() {
        let loc = WeatherManager.coarseLocation(latitude: 43.3, longitude: -5.99)
        XCTAssertEqual(loc.coordinate.latitude, 43.3, accuracy: 1e-9)
        XCTAssertEqual(loc.coordinate.longitude, -5.99, accuracy: 1e-9)
    }

    /// L'arrondi déplace la position d'au plus ~800 m : la météo reste juste,
    /// et la position reste « approximative » (moins de 3 décimales).
    func testRounding_staysWithinOneKilometre() {
        let samples: [(Double, Double)] = [
            (48.856_61, 2.352_22), (-33.868_82, 151.209_29), (37.384_99, -5.984_87),
            (64.146_6, -21.942_6), (0.004_99, 0.004_99), (-0.005_01, 179.994_9),
        ]
        for (lat, lon) in samples {
            let precise = CLLocation(latitude: lat, longitude: lon)
            let coarse = WeatherManager.coarseLocation(latitude: lat, longitude: lon)
            XCTAssertLessThan(precise.distance(from: coarse), 800, "\(lat), \(lon)")
            for value in [coarse.coordinate.latitude, coarse.coordinate.longitude] {
                XCTAssertEqual(value, (value * 100).rounded() / 100, accuracy: 1e-9, "plus de 2 décimales : \(value)")
            }
        }
    }
}

// MARK: - Mention Apple Weather et confidentialité

final class WeatherAttributionTests: XCTestCase {

    private func string(_ key: String.LocalizationValue, language: String) throws -> String {
        let path = try XCTUnwrap(Bundle.main.path(forResource: language, ofType: "lproj"))
        return String(localized: key, bundle: try XCTUnwrap(Bundle(path: path)),
                      locale: Locale(identifier: language))
    }

    func testAttributionLink_isTranslated() throws {
        XCTAssertEqual(try string("weather.attribution.sources", language: "fr"), "Sources des données météo")
        XCTAssertEqual(try string("weather.attribution.sources", language: "en"), "Weather data sources")
    }

    /// Le manifeste embarqué déclare toujours la position approximative (envoyée à WeatherKit),
    /// non liée à l'identité, sans tracking — aligné sur docs/APP_STORE_PRIVACY.md.
    func testPrivacyManifest_declaresOnlyCoarseLocation() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy"))
        let plist = try XCTUnwrap(
            PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil) as? [String: Any]
        )
        XCTAssertEqual(plist["NSPrivacyTracking"] as? Bool, false)
        XCTAssertEqual((plist["NSPrivacyTrackingDomains"] as? [String])?.isEmpty, true)

        let collected = try XCTUnwrap(plist["NSPrivacyCollectedDataTypes"] as? [[String: Any]])
        XCTAssertEqual(collected.count, 1)
        let location = try XCTUnwrap(collected.first)
        XCTAssertEqual(location["NSPrivacyCollectedDataType"] as? String, "NSPrivacyCollectedDataTypeCoarseLocation")
        XCTAssertEqual(location["NSPrivacyCollectedDataTypeLinked"] as? Bool, false)
        XCTAssertEqual(location["NSPrivacyCollectedDataTypeTracking"] as? Bool, false)
        XCTAssertEqual(location["NSPrivacyCollectedDataTypePurposes"] as? [String],
                       ["NSPrivacyCollectedDataTypePurposeAppFunctionality"])
    }
}
