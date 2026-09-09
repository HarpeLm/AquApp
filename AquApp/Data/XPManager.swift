import SwiftUI
import Combine

enum XPLevel: Int, CaseIterable {
    case goutte      = 1
    case ruisseau    = 2
    case source      = 3
    case riviere     = 4
    case lac         = 5
    case fleuve      = 6
    case ocean       = 7
    case aquaLegend  = 8

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

    var color: Color {
        switch self {
        case .goutte:     return Color(hex: "4DA8F5")
        case .ruisseau:   return Color(hex: "4DA8F5")
        case .source:     return Color(hex: "2B87E8")
        case .riviere:    return Color(hex: "2B87E8")
        case .lac:        return Color(hex: "185FA5")
        case .fleuve:     return Color(hex: "7F77DD")
        case .ocean:      return Color(hex: "534AB7")
        case .aquaLegend: return Color(hex: "3C3489")
        }
    }

    var displayColor: Color { color }

    var next: XPLevel? {
        XPLevel(rawValue: rawValue + 1)
    }

    static func level(for xp: Int) -> XPLevel {
        XPLevel.allCases.reversed().first { xp >= $0.threshold } ?? .goutte
    }
}

enum XPSource {
    case water(ml: Double)
    case dailyGoal
    case challenge
    case achievement
    case streak7
    case sober7
    case heatwaveGoal

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

final class XPManager: ObservableObject {

    @Published private(set) var totalXP:      Int      = 0
    @Published private(set) var currentLevel: XPLevel  = .goutte
    @Published private(set) var lastGain:     Int?     = nil
    @Published private(set) var didLevelUp:   Bool     = false

    private let defaults   = UserDefaults.standard
    private let dailyWaterXPCap = 20
    private var waterXPToday: Int {
        get { defaults.integer(forKey: "xp_water_today_\(todayKey)") }
        set { defaults.set(newValue, forKey: "xp_water_today_\(todayKey)") }
    }
    private var todayKey: String {
        let f = DateFormatter(); f.dateFormat = "yyyyMMdd"
        return f.string(from: Date())
    }

    init() {
        totalXP      = HealthDataManager.shared.xpTotal
        currentLevel = XPLevel.level(for: totalXP)
    }

    @MainActor
    func add(_ source: XPSource) {
        var gain = source.amount

        if case .water = source {
            let remaining = max(0, dailyWaterXPCap - waterXPToday)
            guard remaining > 0 else { return }
            gain = min(gain, remaining)
            waterXPToday += gain
        }

        guard gain > 0 else { return }

        let previousLevel = currentLevel
        totalXP += gain
        HealthDataManager.shared.setXPTotal(totalXP)
        currentLevel = XPLevel.level(for: totalXP)

        lastGain = gain
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.lastGain = nil
        }

        if currentLevel != previousLevel {
            didLevelUp = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.didLevelUp = false
            }
        }
    }

    var xpInCurrentLevel: Int {
        totalXP - currentLevel.threshold
    }

    var currentLevelRange: Int {
        guard let next = currentLevel.next else { return 1 }
        return next.threshold - currentLevel.threshold
    }

    var progressRatio: Double {
        guard let _ = currentLevel.next else { return 1.0 }
        return min(1.0, Double(xpInCurrentLevel) / Double(currentLevelRange))
    }

    var xpUntilNextLevel: Int? {
        guard let next = currentLevel.next else { return nil }
        return next.threshold - totalXP
    }
}
