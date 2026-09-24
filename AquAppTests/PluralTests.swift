import XCTest
@testable import AquApp

final class PluralTests: XCTestCase {

    private func string(_ key: String.LocalizationValue, language: String) throws -> String {
        let path = try XCTUnwrap(Bundle.main.path(forResource: language, ofType: "lproj"))
        return String(localized: key, bundle: try XCTUnwrap(Bundle(path: path)),
                      locale: Locale(identifier: language))
    }

    func testDaysCount_french_zeroAndOneAreSingular() throws {
        XCTAssertEqual(try string("home.days_count \(0)", language: "fr"), "0 jour")
        XCTAssertEqual(try string("home.days_count \(1)", language: "fr"), "1 jour")
        XCTAssertEqual(try string("home.days_count \(2)", language: "fr"), "2 jours")
    }

    func testDaysCount_english_onlyOneIsSingular() throws {
        XCTAssertEqual(try string("home.days_count \(0)", language: "en"), "0 days")
        XCTAssertEqual(try string("home.days_count \(1)", language: "en"), "1 day")
        XCTAssertEqual(try string("home.days_count \(3)", language: "en"), "3 days")
    }

    func testHomeDays_keepsOnlyTheUnit() {
        XCTAssertFalse(L10n.homeDays(1).contains("1"))
        XCTAssertFalse(L10n.homeDays(402).contains("402"))
        XCTAssertFalse(L10n.homeDays(402).isEmpty)
    }

    func testCountedStrings_includeTheNumber() throws {
        XCTAssertEqual(try string("notif.settings.count \(1)", language: "fr"), "1 rappel/jour")
        XCTAssertEqual(try string("notif.settings.count \(4)", language: "en"), "4 reminders/day")
        XCTAssertEqual(try string("storekit.trial.days \(7)", language: "fr"), "7 jours offerts")
        XCTAssertEqual(try string("storekit.trial.months \(1)", language: "en"), "1 month free")
    }
}
