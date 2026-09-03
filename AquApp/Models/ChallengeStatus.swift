//
//  ChallengeStatus.swift
//  AquApp
//
//  Created by Fabian Dargaud on 02/09/2026.
//

// ChallengeStatus.swift
import Foundation

/// Statut d'un défi ou d'un succès
enum ChallengeStatus {
    case locked       // Verrouillé (nécessite Premium)
    case available    // Disponible
    case inProgress   // En cours
    case completed    // Terminé
}
