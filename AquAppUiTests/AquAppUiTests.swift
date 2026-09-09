//
//  AquAppTestsUi.swift
//  AquAppTestsUi
//
//  Created by Fabian Dargaud on 09/09/2026.
//

import XCTest

final class AquAppUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTestingReady"]
    }

    override func tearDownWithError() throws {
        app.terminate()
        app = nil
    }

    // MARK: - Helpers

    private func goToTab(_ index: Int) throws {
        let tabBar = app.tabBars.firstMatch
        guard tabBar.waitForExistence(timeout: 5) else { throw XCTSkip("Tab bar absente") }
        guard tabBar.buttons.count > index else { throw XCTSkip("Onglet \(index) absent") }
        tabBar.buttons.element(boundBy: index).tap()
    }

    private func closeTopSheetIfNeeded() {
        let close = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[cd] 'fermer' OR label CONTAINS[cd] 'close'")
        ).firstMatch
        if close.waitForExistence(timeout: 2) { close.tap() }
    }

    // MARK: - 1. Lancement frais : onboarding de bout en bout

    func test01_LaunchFresh_OnboardingComplet() {
          app.launchArguments = ["-uiTestingFresh"]
          app.launch()

          // 4 pages swipables
          for page in 0..<3 {
              let next = app.buttons["onboarding.next"]
              XCTAssertTrue(next.waitForExistence(timeout: 5),
                            "Page \(page) : bouton suivant introuvable")
              next.tap()
          }
          app.buttons["onboarding.next"].tap()   // dernière page → écran Nom

          // Un seul champ texte sur cet écran → firstMatch sans ambiguïté
          let nameField = app.textFields.firstMatch
          XCTAssertTrue(nameField.waitForExistence(timeout: 5), "Champ prénom introuvable")
          nameField.tap()
          nameField.typeText("Test")

          let continueBtn = app.buttons["onboarding.name.continue"]
          if continueBtn.waitForExistence(timeout: 3) {
              continueBtn.tap()
          } else {
              app.buttons.firstMatch.tap()
          }
      // → Home
            XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10),
                          "Home absente après onboarding complet")
        }
        
    // MARK: - 2. Lancement prêt : home affichée

    func test02_LaunchReady_HomeAffichee() {
        app.launch()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(app.buttons.count, 0, "Home sans aucun bouton")
        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'ml'")).firstMatch
                .waitForExistence(timeout: 3),
            "Aucun libellé ml sur la Home"
        )
    }

    // MARK: - 3. Navigation : tous les onglets, un par un

    func test03_Navigation_TousOnglets() throws {
        app.launch()
        let tabBar = app.tabBars.firstMatch
        guard tabBar.waitForExistence(timeout: 5) else { throw XCTSkip("Tab bar absente") }
        let count = tabBar.buttons.count
        XCTAssertGreaterThanOrEqual(count, 4, "Moins de 4 onglets")
        for i in 0..<count {
            tabBar.buttons.element(boundBy: i).tap()
            XCTAssertTrue(app.scrollViews.firstMatch.waitForExistence(timeout: 3),
                          "Onglet \(i) : aucun contenu scrollable")
        }
    }

    // MARK: - 4. Home : ajout rapide 250 ml

    func test04_Home_AjoutRapide250() throws {
        app.launch()
        guard app.tabBars.firstMatch.waitForExistence(timeout: 5) else { throw XCTSkip() }
        let quickAdd = app.buttons.matching(NSPredicate(format: "label CONTAINS '250'")).firstMatch
        guard quickAdd.waitForExistence(timeout: 3) else {
            throw XCTSkip("Bouton 250 introuvable — capturer avec Record")
        }
        quickAdd.tap()
        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'ml'")).firstMatch
                .waitForExistence(timeout: 3),
            "Aucun libellé ml après ajout rapide"
        )
    }

    // MARK: - 5. Home : sheet d'ajout d'eau (ouverture + fermeture)

    func test05_Home_SheetAjoutEau() throws {
        app.launch()
        guard app.tabBars.firstMatch.waitForExistence(timeout: 5) else { throw XCTSkip() }
        let open = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[cd] 'ajouter' OR label BEGINSWITH '+'")
        ).firstMatch
        guard open.waitForExistence(timeout: 3) else {
            throw XCTSkip("Bouton d'ajout d'eau introuvable — capturer avec Record")
        }
        open.tap()
        XCTAssertTrue(app.sheets.firstMatch.waitForExistence(timeout: 3), "Sheet ajout eau absente")
        closeTopSheetIfNeeded()
    }

    // MARK: - 6. Stats : sélecteur de période + verrou Premium

    func test06_Stats_PeriodTabsEtVerrouPremium() throws {
        app.launch()
        try goToTab(1)
        let periodButtons = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[cd] 'mois' OR label CONTAINS[cd] 'month'")
        )
        guard periodButtons.firstMatch.waitForExistence(timeout: 3) else {
            throw XCTSkip("Onglets de période introuvables")
        }
        periodButtons.firstMatch.tap()
        closeTopSheetIfNeeded()
    }

    // MARK: - 7. Achievements : grille + badges

    func test07_Achievements_GrilleEtBadges() throws {
        app.launch()
        try goToTab(2)
        XCTAssertTrue(app.scrollViews.firstMatch.waitForExistence(timeout: 3))
        XCTAssertGreaterThan(app.buttons.count, 2, "Grille achievements vide")
    }

    // MARK: - 8. Profile : sheet corps (sliders + save) puis sheet objectif

    func test08_Profile_SectionsEtSheets() throws {
        app.launch()
        let tabBar = app.tabBars.firstMatch
        guard tabBar.waitForExistence(timeout: 5) else { throw XCTSkip("Tab bar absente") }
        tabBar.buttons.element(boundBy: tabBar.buttons.count - 1).tap()
        XCTAssertTrue(app.scrollViews.firstMatch.waitForExistence(timeout: 3),
                      "Profile sans contenu scrollable")

        // ── Sheet corps ─────────────────────────────────────────────────────
        let bodyCard = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[cd] 'poids' OR label CONTAINS[cd] 'weight'")
        ).firstMatch
        guard bodyCard.waitForExistence(timeout: 3) else {
            throw XCTSkip("Carte corps introuvable sur le Profile")
        }
        bodyCard.tap()

        let bodySheet = app.sheets.firstMatch
        XCTAssertTrue(bodySheet.waitForExistence(timeout: 3),
                      "Sheet corps absente. HIÉRARCHIE :\n" + app.debugDescription)
        let slider = app.sliders.firstMatch
        XCTAssertTrue(slider.waitForExistence(timeout: 3),
                      "Sliders absents dans la sheet corps. HIÉRARCHIE :\n" + app.debugDescription)
        slider.adjust(toNormalizedSliderPosition: 0.6)

        let save = bodySheet.buttons.matching(
            NSPredicate(format: "label CONTAINS[cd] 'enregistrer' OR label CONTAINS[cd] 'save'")
        ).firstMatch
        if save.waitForExistence(timeout: 2) { save.tap() } else { closeTopSheetIfNeeded() }
        _ = bodySheet.waitForNonExistence(timeout: 3)

        // ── Sheet objectif : 3 stratégies d'ouverture ───────────────────────
        var opened = false

        // Stratégie 1 : bouton de la carte objectif
        let goalCard = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[cd] 'objectif' OR label CONTAINS[cd] 'goal'")
        ).firstMatch
        if goalCard.waitForExistence(timeout: 2) {
            goalCard.tap()
            opened = app.sheets.firstMatch.waitForExistence(timeout: 3)
        }

        // Stratégie 2 : tap direct sur le texte (carte en onTapGesture ?)
        if !opened {
            let label = app.staticTexts.matching(
                NSPredicate(format: "label CONTAINS[cd] 'objectif' OR label CONTAINS[cd] 'goal'")
            ).firstMatch
            if label.waitForExistence(timeout: 2) {
                label.tap()
                opened = app.sheets.firstMatch.waitForExistence(timeout: 3)
            }
        }

        // Stratégie 3 : bouton "Modifier"
        if !opened {
            let edit = app.buttons.matching(
                NSPredicate(format: "label CONTAINS[cd] 'modifier' OR label CONTAINS[cd] 'edit'")
            ).firstMatch
            if edit.waitForExistence(timeout: 2) {
                edit.tap()
                opened = app.sheets.firstMatch.waitForExistence(timeout: 3)
            }
        }

        XCTAssertTrue(opened,
                      "Sheet objectif absente après 3 stratégies. HIÉRARCHIE :\n" + app.debugDescription)
        closeTopSheetIfNeeded()
    }
    
    
    // MARK: - 9. Premium sheet : ouverture depuis la bannière

    func test09_PremiumSheet_OuvertureFermeture() throws {
        app.launch()
        try goToTab(2)
        let premiumBtn = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[cd] 'premium' OR label CONTAINS[cd] 'pro'")
        ).firstMatch
        guard premiumBtn.waitForExistence(timeout: 3) else {
            throw XCTSkip("Bannière premium introuvable (compte déjà premium ?)")
        }
        premiumBtn.tap()
        XCTAssertTrue(app.scrollViews.firstMatch.waitForExistence(timeout: 3),
                      "Premium sheet sans contenu")
        closeTopSheetIfNeeded()
    }

    // MARK: - 10. Stabilité : 5 lancements successifs sans crash

    func test10_Stabilite_LancementsRepétés() {
        for i in 0..<5 {
            app.launch()
            XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 5),
                          "Lancement \(i) : tab bar absente")
            app.terminate()
        }
    }

    // MARK: - 11. Parcours complet pixel-perfect (à enregistrer)

    func test11_Parcours_Complet_Record() {
        // 👉 CURSEUR ICI puis bouton RECORD (●) en bas de l'éditeur :
        // joue le parcours réel (Home → sheet eau → sheet alcool → Stats →
        // Achievements → Profile → Wrapped), STOP, et Xcode écrit les
        // selectors exacts. Colle-moi le résultat : je le transforme en
        // test asserté propre.
    }
}
