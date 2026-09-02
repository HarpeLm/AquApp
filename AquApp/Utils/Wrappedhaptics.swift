//
//  Wrappedhaptics.swift
//  AquApp
//
//  Created by Fabian Dargaud on 01/07/2026.
//

//
//  WrappedHaptics.swift
//  AquApp
//
//  Sons et haptiques thématiques pour chaque slide du AquApp Wrapped.
//  Chaque transition de slide déclenche un haptique + son cohérent avec son thème :
//  eau qui coule, feu qui crépite, pulsation organique, etc.
//
//  Les fichiers sons (.caf/.m4a courts, < 1s) doivent être ajoutés dans
//  Assets/Sounds/ et référencés ici. Si absents, seul l'haptique se déclenche
//  (fail-safe silencieux).

import UIKit
import AVFoundation

// MARK: - WrappedSlideTheme

/// Identifie le thème sonore/haptique de chaque slide du Wrapped.
enum WrappedSlideTheme {
    case intro
    case water       // volume total — eau qui coule
    case streak      // objectif & série — feu qui crépite
    case sober       // sobriété — souffle apaisant
    case month       // mois record — éclat solaire
    case habits      // habitudes — pop léger
    case xp          // XP — gouttes qui tombent
    case finale      // bilan — cristal/carillon
    case share       // partage — clic net
    case legendary   // easter egg record absolu — fanfare dorée

    /// Nom du fichier son associé (sans extension), nil si silencieux.
    var soundFileName: String? {
        switch self {
        case .intro:     return "wrapped_intro"
        case .water:     return "wrapped_water_flow"
        case .streak:    return "wrapped_fire_crackle"
        case .sober:     return "wrapped_soft_breath"
        case .month:     return "wrapped_sun_glow"
        case .habits:    return "wrapped_pop"
        case .xp:        return "wrapped_droplet"
        case .finale:    return "wrapped_chime"
        case .share:     return "wrapped_click"
        case .legendary: return "wrapped_fanfare"
        }
    }

    /// Pattern haptique associé — joué même si le son est absent.
    var hapticPattern: WrappedHapticPattern {
        switch self {
        case .intro:     return .single(.medium)
        case .water:     return .wave
        case .streak:    return .crackle
        case .sober:     return .single(.soft)
        case .month:     return .burst
        case .habits:    return .single(.light)
        case .xp:        return .droplets
        case .finale:    return .chime
        case .share:     return .single(.rigid)
        case .legendary: return .fanfare
        }
    }
}

// MARK: - WrappedHapticPattern

enum WrappedHapticPattern {
    case single(UIImpactFeedbackGenerator.FeedbackStyle)
    case wave        // 3 impacts croissants, façon vague
    case crackle      // impacts irréguliers façon crépitement
    case burst       // impact fort + notification succès
    case droplets    // série de petits impacts espacés
    case chime       // impact léger + notification succès différée
    case fanfare     // pattern complexe pour l'easter egg légendaire
}

// MARK: - WrappedHapticsManager

@MainActor
final class WrappedHapticsManager {

    static let shared = WrappedHapticsManager()
    private init() { prepareGenerators() }

    // ── Générateurs pré-instanciés (latence minimale) ────────────────────────
    private let lightImpact  = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpact  = UIImpactFeedbackGenerator(style: .heavy)
    private let rigidImpact  = UIImpactFeedbackGenerator(style: .rigid)
    private let softImpact   = UIImpactFeedbackGenerator(style: .soft)
    private let notification = UINotificationFeedbackGenerator()

    private var audioPlayer: AVAudioPlayer?

    private func prepareGenerators() {
        lightImpact.prepare()
        mediumImpact.prepare()
        heavyImpact.prepare()
        rigidImpact.prepare()
        softImpact.prepare()
        notification.prepare()
    }

    // MARK: - API publique

    /// Joue le son + haptique associés à une slide.
    /// Appelé à chaque transition vers une nouvelle slide.
    func play(for theme: WrappedSlideTheme) {
        playHaptic(theme.hapticPattern)
        playSound(theme.soundFileName)
    }

    // MARK: - Haptique

    private func playHaptic(_ pattern: WrappedHapticPattern) {
        switch pattern {
        case .single(let style):
            generator(for: style).impactOccurred()

        case .wave:
            // 3 impacts croissants espacés de 80ms — façon vague qui arrive
            softImpact.impactOccurred(intensity: 0.4)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                self.lightImpact.impactOccurred(intensity: 0.6)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                self.mediumImpact.impactOccurred(intensity: 0.8)
            }

        case .crackle:
            // Impacts irréguliers façon crépitement de feu
            let delays: [Double] = [0, 0.05, 0.13, 0.18, 0.27]
            for delay in delays {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    self.rigidImpact.impactOccurred(intensity: Double.random(in: 0.3...0.7))
                }
            }

        case .burst:
            heavyImpact.impactOccurred()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.notification.notificationOccurred(.success)
            }

        case .droplets:
            // 4 petites gouttes espacées — utilisé en boucle pendant le count-up XP
            for i in 0..<4 {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.12) {
                    self.lightImpact.impactOccurred(intensity: 0.5)
                }
            }

        case .chime:
            softImpact.impactOccurred(intensity: 0.6)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                self.notification.notificationOccurred(.success)
            }

        case .fanfare:
            // Pattern riche pour l'easter egg "légendaire"
            heavyImpact.impactOccurred()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.heavyImpact.impactOccurred(intensity: 0.7)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                self.notification.notificationOccurred(.success)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                self.mediumImpact.impactOccurred(intensity: 0.5)
            }
        }
    }

    private func generator(for style: UIImpactFeedbackGenerator.FeedbackStyle) -> UIImpactFeedbackGenerator {
        switch style {
        case .light:  return lightImpact
        case .medium: return mediumImpact
        case .heavy:  return heavyImpact
        case .rigid:  return rigidImpact
        case .soft:   return softImpact
        @unknown default: return mediumImpact
        }
    }

    // MARK: - Son
    // Fail-safe : si le fichier son n'existe pas dans le bundle, on ignore
    // silencieusement — seul l'haptique reste actif. Permet de livrer la
    // fonctionnalité même sans assets sonores créés.

    private func playSound(_ fileName: String?) {
        guard let fileName else { return }
        guard let url = Bundle.main.url(forResource: fileName, withExtension: "caf")
            ?? Bundle.main.url(forResource: fileName, withExtension: "m4a") else {
            return // Fichier son absent — silencieux, l'haptique suffit
        }
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.volume = 0.7
            audioPlayer?.play()
        } catch {
            // Échec silencieux — ne doit jamais bloquer l'expérience visuelle
        }
    }

    /// Joue une seule goutte — utilisé pendant l'animation de count-up XP
    /// pour synchroniser un tap haptique à chaque "goutte" qui tombe.
    func playSingleDroplet() {
        lightImpact.impactOccurred(intensity: 0.45)
    }
}
