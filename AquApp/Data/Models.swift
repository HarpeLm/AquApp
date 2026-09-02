import SwiftData
import SwiftUI
import Foundation
import Combine

// MARK: - WaterEntry

@Model
final class WaterEntry {
    var id: UUID
    var date: Date
    var amountMl: Double

    /// Identifiant unique injecté par AquAppIntents lors d'une écriture Siri.
    /// Permet à flushWidgetPendingEntries() de détecter les doublons :
    /// si une entrée avec ce siriIntentID existe déjà en base (écrite
    /// directement par l'intent), la queue App Group est ignorée pour
    /// cette entrée. nil = entrée créée normalement dans l'app.
    var siriIntentID: String?

    init(amountMl: Double, date: Date = Date(), siriIntentID: String? = nil) {
        self.id           = UUID()
        self.date         = date
        self.amountMl     = amountMl
        self.siriIntentID = siriIntentID
    }

    var day: Date {
        Calendar.current.startOfDay(for: date)
    }
}

// MARK: - AlcoholKind
// Renommé pour éviter tout conflit avec des types existants dans le projet
//
// ⚠️ MIGRATION v1.0 → v1.1 :
// Les rawValues étaient en français ("Bière", "Vin"…) et persistées dans SwiftData.
// Ils sont maintenant en anglais stable ("beer", "wine"…).
// La migration est gérée dans WaterAlcoholEntry.alcoholType (getter) via migratedAlcoholKind().
// Aucun changement de schéma SwiftData n'est nécessaire — seule la valeur String change.

enum AlcoholKind: String, Codable, CaseIterable {
    case beer     = "beer"
    case wine     = "wine"
    case spirits  = "spirits"
    case cider    = "cider"
    case cocktail = "cocktail"
    case other    = "other"

    // MARK: - Migration depuis les anciens rawValues français
    // Appelé partout où on lit un rawValue depuis SwiftData ou UserDefaults.
    // Gère à la fois les nouvelles valeurs anglaises ET les anciennes valeurs
    // françaises persistées dans SwiftData avant la v1.1.
    static func migratedAlcoholKind(from raw: String) -> AlcoholKind {
        // Tente d'abord le rawValue anglais (nouvelles entrées)
        if let kind = AlcoholKind(rawValue: raw) { return kind }
        // Fallback : anciens rawValues français (entrées existantes avant v1.1)
        switch raw {
        case "Bière":      return .beer
        case "Vin":        return .wine
        case "Spiritueux": return .spirits
        case "Cidre":      return .cider
        case "Cocktail":   return .cocktail
        case "Autre":      return .other
        default:           return .other
        }
    }

    var sfSymbol: String {
        switch self {
        case .beer:     return "mug.fill"
        case .wine:     return "wineglass.fill"
        case .spirits:  return "flask.fill"
        case .cider:    return "bubbles.and.sparkles"
        case .cocktail: return "party.popper.fill"
        case .other:    return "drop.fill"
        }
    }

    /// Nom localisé affiché à l'utilisateur — utilise les mêmes clés
    /// que AddAlcoolSheet pour garantir la cohérence dans toute l'app.
    var localizedName: String {
        switch self {
        case .beer:     return String(localized: "alcohol.beer")
        case .wine:     return String(localized: "alcohol.wine")
        case .spirits:  return String(localized: "alcohol.spirits")
        case .cider:    return String(localized: "alcohol.cider")
        case .cocktail: return String(localized: "alcohol.cocktail")
        case .other:    return String(localized: "alcohol.other")
        }
    }

    var defaultAbv: Double {
        switch self {
        case .beer:     return 5.0
        case .wine:     return 12.5
        case .spirits:  return 40.0
        case .cider:    return 4.5
        case .cocktail: return 15.0
        case .other:    return 8.0
        }
    }
}

// MARK: - WaterAlcoholEntry
// Renommé pour éviter tout conflit avec des types existants dans le projet

@Model
final class WaterAlcoholEntry {
    var id: UUID
    var date: Date
    var amountMl: Double
    var alcoholKindRaw: String

    /// Même rôle que WaterEntry.siriIntentID — déduplication Siri.
    var siriIntentID: String?

    var alcoholType: AlcoholKind {
        get {
            // migratedAlcoholKind gère à la fois les nouveaux rawValues anglais
            // ET les anciens rawValues français persistés avant la v1.1.
            // Migration paresseuse : à la première lecture d'une ancienne entrée,
            // on réécrit le rawValue en anglais directement dans SwiftData,
            // pour que tous les accès suivants soient directs sans switch.
            let kind = AlcoholKind.migratedAlcoholKind(from: alcoholKindRaw)
            if alcoholKindRaw != kind.rawValue {
                alcoholKindRaw = kind.rawValue  // migration in-place, sans schéma
            }
            return kind
        }
        set { alcoholKindRaw = newValue.rawValue }
    }

    var pureAlcoholGrams: Double {
        (amountMl / 1000.0) * 789.0 * (alcoholType.defaultAbv / 100.0)
    }

    var standardDrinks: Double {
        pureAlcoholGrams / 10.0
    }

    init(amountMl: Double, alcoholType: AlcoholKind, date: Date = Date(), siriIntentID: String? = nil) {
        self.id             = UUID()
        self.date           = date
        self.amountMl       = amountMl
        self.alcoholKindRaw = alcoholType.rawValue
        self.siriIntentID   = siriIntentID
    }

    var day: Date {
        Calendar.current.startOfDay(for: date)
    }
}

// MARK: - AlcoholKind + Compensation
// Source de vérité unique pour le calcul de compensation hydrique liée à l'alcool.
//
// Formule scientifique validée :
//   grammes alcool pur  = volume (ml) × (ABV / 100) × 0.789 (densité éthanol)
//   eau à compenser (ml) = grammes alcool pur × 10
//
// Basé sur ~100 ml d'eau perdus par verre standard (10 g d'alcool pur).
// Toute modification de coefficient doit se faire ICI uniquement.

extension AlcoholKind {

    // MARK: - Constantes de la formule (un seul endroit à modifier)

    /// Densité de l'éthanol en g/ml
    static let ethanolDensity: Double = 0.789

    /// Facteur de compensation hydrique : ml d'eau à compenser par gramme d'alcool pur
    static let waterCompensationFactor: Double = 10.0

    // MARK: - API publique

    /// Grammes d'alcool pur pour un volume donné, en utilisant le taux ABV par défaut du type.
    func pureAlcoholGrams(for volumeMl: Double) -> Double {
        volumeMl * (defaultAbv / 100.0) * AlcoholKind.ethanolDensity
    }

    /// Millilitres d'eau à compenser pour un volume donné.
    func compensationMl(for volumeMl: Double) -> Double {
        pureAlcoholGrams(for: volumeMl) * AlcoholKind.waterCompensationFactor
    }
}

extension WaterAlcoholEntry {

    /// Millilitres d'eau à compenser pour cette entrée spécifique.
    var compensationMl: Double {
        alcoholType.compensationMl(for: amountMl)
    }
}

// MARK: - DayRecord

@Model
final class DayRecord {
    var id: UUID
    var date: Date
    var goalMl: Double
    var weightKg: Double?
    var temperatureC: Double?
    var goalReached: Bool

    init(
        date: Date,
        goalMl: Double,
        weightKg: Double?     = nil,
        temperatureC: Double? = nil,
        goalReached: Bool     = false
    ) {
        self.id           = UUID()
        self.date         = Calendar.current.startOfDay(for: date)
        self.goalMl       = goalMl
        self.weightKg     = weightKg
        self.temperatureC = temperatureC
        self.goalReached  = goalReached
    }
}
