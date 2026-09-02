import SwiftUI
import Combine

// MARK: - XPLevel

enum XPLevel: Int, CaseIterable {
    case goutte      = 1
    case ruisseau    = 2
    case source      = 3
    case riviere     = 4
    case lac         = 5
    case fleuve      = 6
    case ocean       = 7
    case aquaLegend  = 8

    // ── Courbe B — progressive medium ────────────────────────────────────────
    // Paliers validés : utilisateur régulier (4 verres/j + objectif + 3 défis/sem)
    // atteint le niveau 8 en ~18 mois.
    var threshold: Int {
        switch self {
        case .goutte:     return 0
        case .ruisseau:   return 100
        case .source:     return 300
        case .riviere:    return 750
        case .lac:        return 1_800
        case .fleuve:     return 4_000
        case .ocean:      return 8_500
        case .aquaLegend: return 15_000
        }
    }

    var localizedName: String {
        switch self {
        case .goutte:     return String(localized: "xp.level.goutte")
        case .ruisseau:   return String(localized: "xp.level.ruisseau")
        case .source:     return String(localized: "xp.level.source")
        case .riviere:    return String(localized: "xp.level.riviere")
        case .lac:        return String(localized: "xp.level.lac")
        case .fleuve:     return String(localized: "xp.level.fleuve")
        case .ocean:      return String(localized: "xp.level.ocean")
        case .aquaLegend: return String(localized: "xp.level.aqua_legend")
        }
    }

    /// Couleur accent de la barre liquide — utilisée pour le remplissage
    var color: Color {
        switch self {
        case .goutte:     return Color(hex: "4DA8F5")  // bleu principal app
        case .ruisseau:   return Color(hex: "4DA8F5")
        case .source:     return Color(hex: "2B87E8")
        case .riviere:    return Color(hex: "2B87E8")
        case .lac:        return Color(hex: "185FA5")
        case .fleuve:     return Color(hex: "7F77DD")
        case .ocean:      return Color(hex: "534AB7")
        case .aquaLegend: return Color(hex: "3C3489")
        }
    }

    /// Couleur du texte et des icônes — toujours lisible en mode clair/sombre
    /// Identique à color mais garantit un contraste suffisant pour les niveaux bas
    var displayColor: Color { color }

    /// Prochain niveau, nil si max
    var next: XPLevel? {
        XPLevel(rawValue: rawValue + 1)
    }

    static func level(for xp: Int) -> XPLevel {
        XPLevel.allCases.reversed().first { xp >= $0.threshold } ?? .goutte
    }
}

// MARK: - XPSource

enum XPSource {
    case water(ml: Double)          // 1–4 XP selon volume
    case dailyGoal                  // +10 XP
    case challenge                  // +15 XP
    case achievement                // +30 XP
    case streak7                    // +20 XP hebdo
    case sober7                     // +25 XP
    case heatwaveGoal               // +5 XP

    var amount: Int {
        switch self {
        case .water(let ml):
            switch ml {
            case ..<201:  return 1
            case ..<401:  return 2
            case ..<601:  return 3
            default:      return 4
            }
        case .dailyGoal:    return 10
        case .challenge:    return 15
        case .achievement:  return 30
        case .streak7:      return 20
        case .sober7:       return 25
        case .heatwaveGoal: return 5
        }
    }
}

// MARK: - XPManager

final class XPManager: ObservableObject {

    // ── État publié ───────────────────────────────────────────────────────────
    @Published private(set) var totalXP:      Int      = 0
    @Published private(set) var currentLevel: XPLevel  = .goutte
    @Published private(set) var lastGain:     Int?     = nil   // affichage toast "+N XP"
    @Published private(set) var didLevelUp:   Bool     = false

    // ── Persistence ───────────────────────────────────────────────────────────
    private let defaults   = UserDefaults.standard
    private let keyTotal   = "xp_total"

    // ── Plafond XP eau par jour ───────────────────────────────────────────────
    // Evite le "grind" : max 20 XP/jour issus des verres d'eau
    private let dailyWaterXPCap = 20
    private var waterXPToday: Int {
        get { defaults.integer(forKey: "xp_water_today_\(todayKey)") }
        set { defaults.set(newValue, forKey: "xp_water_today_\(todayKey)") }
    }
    private var todayKey: String {
        let f = DateFormatter(); f.dateFormat = "yyyyMMdd"
        return f.string(from: Date())
    }

    // ── Init ─────────────────────────────────────────────────────────────────
    init() {
        totalXP      = defaults.integer(forKey: keyTotal)
        currentLevel = XPLevel.level(for: totalXP)
    }

    // MARK: - API publique

    /// Ajoute des XP depuis une source donnée.
    /// Appelé depuis AppDataStore ou AchievementManager.
    @MainActor
    func add(_ source: XPSource) {
        var gain = source.amount

        // Plafonne les XP eau du jour
        if case .water = source {
            let remaining = max(0, dailyWaterXPCap - waterXPToday)
            guard remaining > 0 else { return }
            gain = min(gain, remaining)
            waterXPToday += gain
        }

        guard gain > 0 else { return }

        let previousLevel = currentLevel
        totalXP += gain
        defaults.set(totalXP, forKey: keyTotal)
        currentLevel = XPLevel.level(for: totalXP)

        // Toast "+N XP"
        lastGain = gain
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.lastGain = nil
        }

        // Level up
        if currentLevel != previousLevel {
            didLevelUp = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.didLevelUp = false
            }
        }
    }

    // MARK: - Computed helpers

    /// XP dans le niveau courant (depuis le seuil bas)
    var xpInCurrentLevel: Int {
        totalXP - currentLevel.threshold
    }

    /// Taille totale du niveau courant
    var currentLevelRange: Int {
        guard let next = currentLevel.next else { return 1 }
        return next.threshold - currentLevel.threshold
    }

    /// Ratio 0…1 de progression dans le niveau
    var progressRatio: Double {
        guard let _ = currentLevel.next else { return 1.0 }
        return min(1.0, Double(xpInCurrentLevel) / Double(currentLevelRange))
    }

    /// XP restants avant le prochain niveau
    var xpUntilNextLevel: Int? {
        guard let next = currentLevel.next else { return nil }
        return next.threshold - totalXP
    }
}
