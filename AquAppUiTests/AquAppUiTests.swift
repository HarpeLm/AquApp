//
//  AquAppTestsUi.swift
//  AquAppTestsUi
//
//  Created by Fabian Dargaud on 09/09/2026.
//

import XCTest

/// Parcours réels dans l'app. Les modes `-uiTestingFresh` / `-uiTestingReady` lancent l'app
/// sur une base en mémoire : les tests ne touchent jamais aux données du simulateur.
/// Les éléments sont trouvés par identifiant d'accessibilité ; un test qui ne trouve pas
/// ce qu'il cherche échoue (il ne se met pas en « ignoré »).
final class AquAppUITests: XCTestCase {

    var app: XCUIApplication!

    // Les libellés vérifiés sont en français : on fige la langue quel que soit le simulateur.
    private let frenchLocale = ["-AppleLanguages", "(fr)", "-AppleLocale", "fr_FR"]

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDownWithError() throws {
        app.terminate()
        app = nil
    }

    // MARK: - Helpers

    private func launch(fresh: Bool = false) {
        app.launchArguments = [fresh ? "-uiTestingFresh" : "-uiTestingReady"] + frenchLocale
        app.launch()
    }

    /// N'importe quel élément portant cet identifiant (bouton, conteneur de feuille…).
    private func element(_ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id].firstMatch
    }

    private func tap(_ id: String, file: StaticString = #filePath, line: UInt = #line) {
        let target = element(id)
        XCTAssertTrue(target.waitForExistence(timeout: 5), "« \(id) » introuvable", file: file, line: line)
        target.tap()
    }

    private func goToTab(_ index: Int, file: StaticString = #filePath, line: UInt = #line) {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5), "Barre d'onglets absente", file: file, line: line)
        tabBar.buttons.element(boundBy: index).tap()
    }

    private func goToNameScreen() {
        launch(fresh: true)
        for _ in 0..<4 { tap("onboarding.next") }
    }

    // MARK: - Onboarding

    func test01_Onboarding_CompletJusquaLAccueil() {
        goToNameScreen()

        let nameField = app.textFields["onboarding.name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5), "Champ prénom introuvable")
        nameField.tap()
        nameField.typeText("Test")
        tap("onboarding.name.continue")

        tap("onboarding.body.save")
        tap("onboarding.health.later")
        tap("onboarding.reminders.later")

        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10), "Accueil absent après l'onboarding")
        XCTAssertTrue(element("home.add_water").exists)
    }

    /// Bug corrigé : le cercle passait sous l'encoche et le formulaire sous le clavier.
    func test02_EcranPrenom_ToutResteVisibleClavierOuvert() {
        goToNameScreen()

        let nameField = app.textFields["onboarding.name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        let keyboard = app.keyboards.firstMatch
        if !keyboard.waitForExistence(timeout: 3) { nameField.tap() }
        XCTAssertTrue(keyboard.waitForExistence(timeout: 5), "Le clavier ne s'ouvre pas")

        let title = app.staticTexts["Comment vous appelez-vous ?"]
        let continueButton = element("onboarding.name.continue")
        XCTAssertTrue(title.exists && continueButton.exists)

        let topSafe = app.windows.firstMatch.frame.minY + 50   // sous la barre d'état / l'îlot
        XCTAssertGreaterThan(title.frame.minY, topSafe, "Le titre passe sous l'encoche")
        XCTAssertLessThanOrEqual(continueButton.frame.maxY, keyboard.frame.minY, "Le bouton passe sous le clavier")
        XCTAssertTrue(nameField.isHittable)
    }

    // MARK: - Accueil

    func test03_Accueil_Affichee() {
        launch()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(element("home.add_water").exists, "Bouton Eau absent")
        XCTAssertTrue(element("home.add_alcohol").exists, "Bouton Alcool absent")
    }

    func test04_Navigation_TousLesOnglets() {
        launch()
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))
        XCTAssertEqual(tabBar.buttons.count, 5)
        for index in 0..<tabBar.buttons.count {
            tabBar.buttons.element(boundBy: index).tap()
            XCTAssertTrue(app.scrollViews.firstMatch.waitForExistence(timeout: 3), "Onglet \(index) vide")
        }
    }

    func test05_AjoutEau_250ml_ApparaitDansLActivite() {
        launch()
        tap("home.add_water")
        let sheet = element("sheet.water")
        XCTAssertTrue(sheet.waitForExistence(timeout: 5), "Feuille d'ajout d'eau absente")

        tap("water.preset.250")

        XCTAssertTrue(sheet.waitForNonExistence(timeout: 5), "La feuille ne se ferme pas après l'ajout")
        let entry = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '250' AND label CONTAINS[c] 'eau'")).firstMatch
        XCTAssertTrue(entry.waitForExistence(timeout: 5), "L'ajout n'apparaît pas dans l'activité récente")
    }

    func test06_FeuilleEau_SeFermeAvecLeBoutonFermer() {
        launch()
        tap("home.add_water")
        let sheet = element("sheet.water")
        XCTAssertTrue(sheet.waitForExistence(timeout: 5))
        sheet.buttons["Fermer"].tap()
        XCTAssertTrue(sheet.waitForNonExistence(timeout: 5))
    }

    func test07_FeuilleAlcool_SOuvre() {
        launch()
        tap("home.add_alcohol")
        XCTAssertTrue(element("sheet.alcohol").waitForExistence(timeout: 5), "Feuille alcool absente")
    }

    // MARK: - Profil

    func test08_Profil_FeuilleProfilPhysique() {
        launch()
        goToTab(4)
        tap("profile.card.body")
        let sheet = element("sheet.body")
        XCTAssertTrue(sheet.waitForExistence(timeout: 5), "Feuille profil physique absente")
        sheet.buttons["Fermer"].tap()
        XCTAssertTrue(sheet.waitForNonExistence(timeout: 5))
    }

    func test09_MenuConfidentialite_OuvreLaPolitique() {
        launch()
        goToTab(4)
        tap("profile.more")
        let policyButton = app.buttons["Politique de confidentialité"]
        XCTAssertTrue(policyButton.waitForExistence(timeout: 5), "Menu « ⋯ » sans la politique")
        policyButton.tap()

        let sheet = element("sheet.privacy_policy")
        XCTAssertTrue(sheet.waitForExistence(timeout: 5), "Politique absente")
        XCTAssertTrue(app.staticTexts["Avertissement santé"].waitForExistence(timeout: 3), "Avertissement santé absent")
        app.buttons["Fermer"].firstMatch.tap()
        XCTAssertTrue(sheet.waitForNonExistence(timeout: 5))
    }

    func test10_SupprimerMesDonnees_RevientALOnboarding() {
        launch()
        tap("home.add_water")
        tap("water.preset.250")
        goToTab(4)

        tap("profile.more")
        tap("profile.privacy.erase")
        let confirm = app.buttons["Tout supprimer"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), "Confirmation absente")
        confirm.tap()

        XCTAssertTrue(element("onboarding.next").waitForExistence(timeout: 10),
                      "L'onboarding ne réapparaît pas après la suppression")
    }

    func test11_SupprimerMesDonnees_Annuler_NeSupprimeRien() {
        launch()
        goToTab(4)
        tap("profile.more")
        tap("profile.privacy.erase")
        XCTAssertTrue(app.buttons["Tout supprimer"].waitForExistence(timeout: 5))

        // Toucher en dehors de la confirmation l'annule
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.95)).tap()

        XCTAssertTrue(app.buttons["Tout supprimer"].waitForNonExistence(timeout: 5))
        XCTAssertFalse(element("onboarding.next").exists, "Les données ont été supprimées malgré l'annulation")
        XCTAssertTrue(app.tabBars.firstMatch.exists)
    }

    // MARK: - Stabilité

    func test12_Stabilite_LancementsRepetes() {
        for index in 0..<3 {
            launch()
            XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 5), "Lancement \(index) : accueil absent")
            app.terminate()
        }
    }
}
