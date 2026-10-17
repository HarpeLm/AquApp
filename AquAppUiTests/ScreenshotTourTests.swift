import XCTest

/// Visite de tous les écrans dans plusieurs configurations, avec une capture par écran
/// (pièces jointes du rapport de test). Sert à la relecture avant une soumission :
/// texte qui déborde, contraste en mode sombre, traduction manquante…
/// Lancé avec les données de démo (`-demoData`, build Debug), en mémoire.
///
/// Plusieurs minutes : ne tourne que sur demande.
///   TEST_RUNNER_SCREENSHOT_TOUR=1 xcodebuild test -scheme AquApp \
///     -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
///     -only-testing:AquAppTestsUi/ScreenshotTourTests -resultBundlePath tour.xcresult
///
/// Récupérer les captures :
///   xcrun xcresulttool export attachments --path tour.xcresult --output-path <dossier>
final class ScreenshotTourTests: XCTestCase {

    private struct Configuration {
        let name: String
        let language: String
        let locale: String
        let scheme: String               // valeur de colorSchemeRaw : light / dark
        let contentSize: String?         // catégorie Dynamic Type
        let reduceMotion: Bool
    }

    private let configurations = [
        Configuration(name: "fr-clair", language: "fr", locale: "fr_FR", scheme: "light",
                      contentSize: nil, reduceMotion: false),
        Configuration(name: "en-sombre", language: "en", locale: "en_GB", scheme: "dark",
                      contentSize: nil, reduceMotion: false),
        Configuration(name: "fr-texte-tres-grand", language: "fr", locale: "fr_FR", scheme: "light",
                      contentSize: "UICTContentSizeCategoryAccessibilityXL", reduceMotion: false),
        Configuration(name: "en-us-reduce-motion", language: "en", locale: "en_US", scheme: "dark",
                      contentSize: nil, reduceMotion: true),
    ]

    override func setUpWithError() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["SCREENSHOT_TOUR"] == "1",
                          "Visite des écrans : lancer avec TEST_RUNNER_SCREENSHOT_TOUR=1")
        continueAfterFailure = true
    }

    func testTour() {
        for configuration in configurations {
            XCTContext.runActivity(named: configuration.name) { _ in
                tour(configuration)
            }
        }
    }

    // MARK: - Visite

    private func tour(_ c: Configuration) {
        let app = XCUIApplication()
        app.launchArguments = ["-demoData",
                               "-AppleLanguages", "(\(c.language))", "-AppleLocale", c.locale,
                               "-colorSchemeRaw", c.scheme]
        if let size = c.contentSize {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", size]
        }
        if c.reduceMotion {
            app.launchArguments += ["-reduceMotion"]
        }
        app.launch()
        defer { app.terminate() }

        let tabBar = app.tabBars.firstMatch
        guard tabBar.waitForExistence(timeout: 30) else {
            XCTFail("\(c.name) : accueil absent")
            return
        }
        let tabs = ["1-accueil", "2-stats", "3-defis", "4-succes", "5-profil"]
        for (index, tab) in tabs.enumerated() {
            tabBar.buttons.element(boundBy: index).tap()
            snap(app, "\(c.name)-\(tab)")
            if index == 4 {
                app.swipeUp(); app.swipeUp()
                snap(app, "\(c.name)-\(tab)-bas")
            }
        }

        // Feuilles principales
        tabBar.buttons.element(boundBy: 0).tap()
        open(app, "home.add_water", sheet: "sheet.water", name: "\(c.name)-6-feuille-eau")
        open(app, "home.add_alcohol", sheet: "sheet.alcohol", name: "\(c.name)-7-feuille-alcool")

        tabBar.buttons.element(boundBy: 4).tap()
        let more = app.descendants(matching: .any)["profile.more"].firstMatch
        if more.waitForExistence(timeout: 5) {
            more.tap()
            snap(app, "\(c.name)-8-menu-confidentialite")
            app.buttons.matching(NSPredicate(format: "label IN %@",
                                             ["Politique de confidentialité", "Privacy policy"])).firstMatch.tap()
            let policy = app.descendants(matching: .any)["sheet.privacy_policy"].firstMatch
            if policy.waitForExistence(timeout: 5) {
                snap(app, "\(c.name)-9-politique")
                app.swipeUp(); app.swipeUp()
                snap(app, "\(c.name)-9-politique-bas")
            }
        }
    }

    private func open(_ app: XCUIApplication, _ button: String, sheet: String, name: String) {
        let trigger = app.descendants(matching: .any)[button].firstMatch
        guard trigger.waitForExistence(timeout: 5) else { XCTFail("\(button) introuvable"); return }
        trigger.tap()
        let container = app.descendants(matching: .any)[sheet].firstMatch
        guard container.waitForExistence(timeout: 5) else { XCTFail("\(sheet) absente"); return }
        snap(app, name)
        app.swipeDown(velocity: .fast)   // ferme la feuille
        _ = container.waitForNonExistence(timeout: 5)
    }

    private func snap(_ app: XCUIApplication, _ name: String) {
        sleep(1)   // laisse finir les transitions
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
