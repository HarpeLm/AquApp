//
//  HapticManager.swift
//  AquApp
//
//  Created by Fabian Dargaud on 18/03/2026.
//
import UIKit

// MARK: - HapticManager
// Gère tous les retours haptiques de l'app.
// Utilise des noms sémantiques plutôt que des styles bruts
// pour faciliter l'ajustement global de l'intensité.

final class HapticManager {

    static let shared = HapticManager()
    private init() {}

    // MARK: - Générateurs (pré-instanciés pour éviter la latence)
    private let lightImpact  = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpact  = UIImpactFeedbackGenerator(style: .heavy)
    private let rigidImpact  = UIImpactFeedbackGenerator(style: .rigid)
    private let softImpact   = UIImpactFeedbackGenerator(style: .soft)
    private let notification = UINotificationFeedbackGenerator()
    private let selection    = UISelectionFeedbackGenerator()

    // MARK: - API sémantique

    /// Tap léger sur un preset (sélection d'une quantité)
    func selectionTap() {
        selection.selectionChanged()
    }

    /// Confirmation d'ajout d'eau
    func waterAdded() {
        mediumImpact.impactOccurred()
    }

    /// Confirmation d'ajout d'alcool
    func alcoholAdded() {
        mediumImpact.impactOccurred()
    }

    /// Suppression d'une entrée
    func entryDeleted() {
        mediumImpact.impactOccurred(intensity: 0.7)
    }

    /// Déclenchement des confettis — heavy + succès + light
    /// Pattern : impact fort immédiat → notification succès à 0.1s → impact léger à 0.3s.
    /// Centralisé ici pour éviter de créer des générateurs sans prepare() dans les vues.
    func confettiTriggered() {
        heavyImpact.impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.notification.notificationOccurred(.success)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.lightImpact.impactOccurred()
        }
    }

    /// Objectif journalier atteint — double impact fort + notification succès
    func goalReached() {
        heavyImpact.impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            self.heavyImpact.impactOccurred(intensity: 0.6)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            self.notification.notificationOccurred(.success)
        }
    }

    /// Succès ou défi complété — pattern distinctif rigid + soft
    func achievementUnlocked() {
        rigidImpact.impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.softImpact.impactOccurred(intensity: 0.8)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            self.rigidImpact.impactOccurred(intensity: 0.5)
        }
    }

    /// Erreur ou action impossible
    func error() {
        notification.notificationOccurred(.error)
    }

    /// Changement de slider (poids, taille, quantité)
    func sliderChanged() {
        selection.selectionChanged()
    }

    /// Haptique progressif pour le slider de quantité d'eau.
    /// Plus la quantité est élevée, plus l'impact est fort.
    /// Déclenché uniquement au franchissement d'un palier, pas à chaque tick.
    ///
    /// Paliers :
    ///   0 →  < 250 ml  : sélection légère
    ///   1 → 250–499 ml : soft
    ///   2 → 500–749 ml : light
    ///   3 → 750–999 ml : medium
    ///   4 → 1000–1499 ml : heavy
    ///   5 → ≥ 1500 ml   : heavy × 2 (double impact)
    func sliderWaterLevel(_ level: Int) {
        switch level {
        case 0:  selection.selectionChanged()
        case 1:  softImpact.impactOccurred(intensity: 0.5)
        case 2:  lightImpact.impactOccurred(intensity: 0.8)
        case 3:  mediumImpact.impactOccurred(intensity: 0.7)
        case 4:  heavyImpact.impactOccurred(intensity: 0.7)
        default:
            // Palier max : double impact pour un effet "plein"
            heavyImpact.impactOccurred(intensity: 1.0)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                self.heavyImpact.impactOccurred(intensity: 0.6)
            }
        }
    }

    // MARK: - Préchauffage
    // À appeler au lancement pour éviter la latence du premier haptic

    func prepare() {
        lightImpact.prepare()
        mediumImpact.prepare()
        heavyImpact.prepare()
        rigidImpact.prepare()
        softImpact.prepare()
        notification.prepare()
        selection.prepare()
    }
}
