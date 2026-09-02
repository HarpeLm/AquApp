//
//  AppColor.swift
//  AquApp
//
//  Created by Fabian Dargaud on 17/03/2026.
//
import SwiftUI

// MARK: - AppColors
// Source de vérité unique pour toutes les couleurs de l'app.
// Usage : Color.app.primary, Color.app.background, etc.

extension Color {

    static let app = AppColors()

    struct AppColors {

        // MARK: - Bleus principaux (eau, hydratation)
        /// Bleu clair — accent principal, barres de progression, boutons eau
        let primary       = Color(hex: "4DA8F5")
        /// Bleu moyen — utilisé dans les dégradés
        let primaryMid    = Color(hex: "4DABF7")
        /// Bleu foncé — fin de dégradé, ombres
        let primaryDark   = Color(hex: "2B87E8")
        /// Bleu très clair — fond des icônes eau, tracks de progression
        let primaryLight  = Color(hex: "EEF4FF")
        /// Bleu pâle — fond de carte, track de cercle
        let primaryPale   = Color(hex: "E3EFFC")
        /// Bleu pastel — fond alternatif
        let primaryPastel = Color(hex: "D6EAFC")
        /// Bleu très pâle — utilisé dans StatsView
        let primaryFaint  = Color(hex: "B8D9F8")

        // MARK: - Violets (alcool, premium, succès)
        /// Violet foncé — bouton alcool fond
        let alcoholDark   = Color(hex: "6C3483")
        /// Violet moyen — bouton alcool accent
        let alcoholMid    = Color(hex: "9B59B6")
        /// Violet clair — icône alcool dans activité récente
        let alcoholLight  = Color(hex: "8B5CF6")
        /// Violet pastel — fond icône alcool
        let alcoholPale   = Color(hex: "F3E5F5")
        /// Violet vif — confettis / charts
        let purple        = Color(hex: "CC5DE8")

        // MARK: - Verts (succès, objectif atteint)
        let green         = Color(hex: "51CF66")
        let greenAlt      = Color(hex: "6BCB77")
        let greenDark     = Color(hex: "10B981")
        let greenPale     = Color(hex: "E8F5E9")

        // MARK: - Oranges / Jaunes (confettis, premium, canicule)
        let orange        = Color(hex: "FF8C00")
        let orangeLight   = Color(hex: "FF922B")
        let orangeVibrant = Color(hex: "E05F00")
        let amber         = Color(hex: "F59E0B")
        let amberDark     = Color(hex: "D4A017")
        let yellow        = Color(hex: "FFD93D")

        // MARK: - Confettis / Bannière celebration
        let confettiYellow = Color(hex: "FFE878")
        let confettiOrange = Color(hex: "FFAB5E")
        let coral          = Color(hex: "FF6B6B")
        let pink           = Color(hex: "F06595")

        // MARK: - Fonds chauds (Premium, bannières)
        let warmWhite      = Color(hex: "FFF7ED")
        let warmLight      = Color(hex: "FFEDD5")
        let creamLight     = Color(hex: "FFF3CD")
        let creamPale      = Color(hex: "FFFDE7")
        let pinkPale       = Color(hex: "FCE4EC")

        // MARK: - Neutres
        let slate          = Color(hex: "94A3B8")
        let red            = Color(hex: "EF4444")
    }
}
