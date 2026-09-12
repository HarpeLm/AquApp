//
//  HydrationActivityAttributes.swift
//  AquApp
//
//  Created by Fabian Dargaud on 24/05/2026.
//
import ActivityKit
import Foundation

// MARK: - HydrationActivityAttributes
// Définit la structure de données de la Live Activity AquApp.
//
// • Attributes  : données STATIQUES (ne changent pas pendant la session)
// • ContentState: données DYNAMIQUES (mises à jour via AppDataStore)

struct HydrationActivityAttributes: ActivityAttributes {

    // ── Données statiques ─────────────────────────────────────────────────────
    // Fixées à la création de l'activité, ne changent pas.

    /// Prénom de l'utilisateur (affiché dans l'étendu)
    let userName: String

    // ── État dynamique ────────────────────────────────────────────────────────
    // Mis à jour à chaque addWater / deleteWater / reset.

    public struct ContentState: Codable, Hashable {

        /// ml bus aujourd'hui (eau nette compensée alcool)
        var currentMl:    Double

        /// Objectif du jour en ml (adaptatif canicule si actif)
        var goalMl:       Double

        /// Streak objectif (jours consécutifs)
        var streak:       Int

        /// Streak sobre (jours sans alcool)
        var soberStreak:  Int

        /// Objectif du jour atteint
        var goalReached:  Bool

        // ── Labels localisés ──────────────────────────────────────────────────
        // Les extensions Widget/LiveActivity ne peuvent pas accéder au bundle
        // principal au runtime. Les labels sont donc calculés une fois dans
        // l'app (qui a accès au String Catalog) et transportés ici.

        /// "aujourd'hui" / "today" / "heute" …
        var labelToday:              String

        /// "Objectif atteint ✓" / "Goal reached ✓" …
        var labelGoalReachedFull:    String

        /// "Objectif" / "Goal" / "Ziel" …
        var labelGoal:               String

        /// "✓ atteint" / "✓ reached" …
        var labelGoalReachedShort:   String

        /// "Série" / "Streak" / "Serie" …
        var labelStreak:             String

        /// "Sobre" / "Sober" / "Nüchtern" …
        var labelSober:              String

        /// Abréviation "jours" : "j" / "d" / "T" …
        var labelDays:               String

        // ── Valeurs formatées (unités locales) ───────────────────────────────
        // UnitFormatter ne peut pas tourner dans la Widget Extension.
        // Les valeurs converties sont calculées dans l'app et stockées ici.

        /// currentMl formaté en unités locales : "1 630 ml" ou "55 fl oz"
        var formattedCurrent: String

        /// goalMl formaté en unités locales : "2 350 ml" ou "79 fl oz"
        var formattedGoal:    String

        // ── Computed helpers ──────────────────────────────────────────────────

        /// Progression 0…1
        var progress: Double {
            guard goalMl > 0 else { return 0 }
            return min(currentMl / goalMl, 1.0)
        }

        /// Pourcentage 0…100
        var percent: Int { Int(progress * 100) }

        /// ml restants avant l'objectif (0 si atteint)
        var remainingMl: Double { max(0, goalMl - currentMl) }

        // ── Initialiseur avec labels depuis le bundle principal ───────────────

        init(
            currentMl:   Double,
            goalMl:      Double,
            streak:      Int,
            soberStreak: Int,
            goalReached: Bool
        ) {
            self.currentMl   = currentMl
            self.goalMl      = goalMl
            self.streak      = streak
            self.soberStreak = soberStreak
            self.goalReached = goalReached

            // Résolution des labels depuis le String Catalog de l'app principale.
            // Appelé uniquement dans le contexte app (start/update LiveActivity),
            // jamais dans la target Extension.
            self.labelToday            = String(localized: "live_activity.today")
            self.labelGoalReachedFull  = String(localized: "live_activity.goal_reached")
            self.labelGoal             = String(localized: "live_activity.label.goal")
            self.labelGoalReachedShort = String(localized: "live_activity.goal_reached_checkmark")
            self.labelStreak           = String(localized: "live_activity.label.streak")
            self.labelSober            = String(localized: "live_activity.label.sober")
            self.labelDays             = String(localized: "live_activity.unit.days")
            self.formattedCurrent      = UnitFormatter.volume(currentMl)
            self.formattedGoal         = UnitFormatter.volume(goalMl)
        }
    }
}
