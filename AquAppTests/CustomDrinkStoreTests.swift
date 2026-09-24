import XCTest
import SwiftUI
@testable import AquApp

@MainActor
final class CustomDrinkStoreTests: XCTestCase {

    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "CustomDrinkStoreTests")
        defaults.removePersistentDomain(forName: "CustomDrinkStoreTests")
    }

    func testRoundTrip_keepsNameAndDegree() {
        let drinks = [AlcoholDrink.custom(name: "Mojito", alcoholPercent: 12.5),
                      AlcoholDrink.custom(name: "IPA", alcoholPercent: 7)]
        CustomDrinkStore.save(drinks, to: defaults)

        let loaded = CustomDrinkStore.load(from: defaults)
        XCTAssertEqual(loaded.map(\.name), ["Mojito", "IPA"])
        XCTAssertEqual(loaded.map(\.alcoholPercent), [12.5, 7])
        XCTAssertTrue(loaded.allSatisfy(\.isCustom))
    }

    func testSave_ignoresBuiltInDrinks() {
        let builtIn = AlcoholDrink(id: "beer", name: "Beer", sfSymbol: "mug.fill", symbolColor: .yellow, alcoholPercent: 5)
        CustomDrinkStore.save([builtIn, .custom(name: "Cidre maison", alcoholPercent: 4)], to: defaults)
        XCTAssertEqual(CustomDrinkStore.load(from: defaults).map(\.name), ["Cidre maison"])
    }

    func testLoad_emptyWhenNothingSaved() {
        XCTAssertTrue(CustomDrinkStore.load(from: defaults).isEmpty)
    }
}
