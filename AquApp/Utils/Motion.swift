import SwiftUI
import UIKit

// MARK: - Motion
// Respect de « Réduire les animations » (Réglages › Accessibilité › Mouvement).
// Quand c'est activé : pas de glissements, de rebonds ni d'effets en boucle,
// mais des fondus courts. Les changements d'état restent visibles.

enum Motion {

    /// Remplace la valeur système dans les tests unitaires.
    static var reduceOverride: Bool?

    /// Argument de lancement des tests d'interface (le réglage iOS ne se force pas au lancement).
    private static let launchedWithReducedMotion = ProcessInfo.processInfo.arguments.contains("-reduceMotion")

    /// Vrai si l'utilisateur a activé « Réduire les animations ».
    static var isReduced: Bool {
        reduceOverride ?? (launchedWithReducedMotion || UIAccessibility.isReduceMotionEnabled)
    }

    /// L'animation demandée, ou un fondu court si les animations sont réduites.
    static func animation(_ animation: Animation) -> Animation {
        isReduced ? .easeInOut(duration: 0.2) : animation
    }
}

extension AnyTransition {
    /// La transition demandée (glissement, zoom…), ou un simple fondu si les
    /// animations sont réduites.
    static func motionAware(_ transition: AnyTransition) -> AnyTransition {
        Motion.isReduced ? .opacity : transition
    }
}
