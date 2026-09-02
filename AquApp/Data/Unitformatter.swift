//
//  Unitformatter.swift
//  AquApp
//
//  Created by Fabian Dargaud on 13/06/2026.
//
//
//  UnitFormatter.swift
//  AquApp
//
// Couche de présentation des unités — source de vérité unique.
//
// RÈGLE ABSOLUE : toutes les données sont stockées en SI (ml, kg, cm).
// Ce fichier ne sert QU'À l'affichage. Ne jamais l'utiliser pour stocker
// ou transmettre une valeur au modèle.
//
// iOS/MeasurementFormatter gère automatiquement la conversion selon la
// locale de l'appareil :
//   • en_US  → fl oz, lbs, ft + in
//   • en_GB  → ml, stone/lbs, ft + in
//   • autres → ml, kg, cm
//
// Usage :
//   Text(UnitFormatter.volume(store.todayWaterMl))       // "250 ml" ou "8.5 fl oz"
//   Text(UnitFormatter.weight(weightKg))                 // "70 kg" ou "154 lbs"
//   Text(UnitFormatter.height(heightCm))                 // "175 cm" ou "5 ft 9 in"

import Foundation

enum UnitFormatter {

    // MARK: - Formatters (statiques, instanciés une seule fois)

    private static let volumeFormatter: MeasurementFormatter = {
        let f = MeasurementFormatter()
        f.unitOptions = .providedUnit   // laisse iOS choisir l'unité locale
        f.numberFormatter.maximumFractionDigits = 0
        return f
    }()

    private static let volumeFormatter1dp: MeasurementFormatter = {
        let f = MeasurementFormatter()
        f.unitOptions = .providedUnit
        f.numberFormatter.maximumFractionDigits = 1
        return f
    }()

    private static let weightFormatter: MeasurementFormatter = {
        let f = MeasurementFormatter()
        f.unitOptions = .providedUnit
        f.numberFormatter.maximumFractionDigits = 1
        return f
    }()

    // MARK: - Volume (ml → ml ou fl oz selon locale)

    /// Affiche un volume en ml avec conversion locale.
    /// Ex. : 250 → "250 ml" (FR) / "8 fl oz" (en-US)
    static func volume(_ ml: Double) -> String {
        let m = Measurement(value: ml, unit: UnitVolume.milliliters).converted(to: preferredVolumeUnit)
        return volumeFormatter.string(from: m)
    }

    /// Affiche un volume avec 1 décimale (utile pour les petites valeurs fl oz).
    /// Ex. : 25 ml → "0.8 fl oz" (en-US) / "25 ml" (FR)
    static func volumeDecimal(_ ml: Double) -> String {
        let m = Measurement(value: ml, unit: UnitVolume.milliliters).converted(to: preferredVolumeUnit)
        return volumeFormatter1dp.string(from: m)
    }

    /// Affiche seulement la valeur numérique, sans unité (pour les grandes valeurs dans les titres).
    /// Ex. : 1630 ml → "1 630" (FR) / "55" (en-US, fl oz)
    static func volumeNumber(_ ml: Double) -> String {
        let converted = Measurement(value: ml, unit: UnitVolume.milliliters).converted(to: preferredVolumeUnit)
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: converted.value)) ?? "\(Int(converted.value))"
    }

    /// Symbole de l'unité de volume selon la locale ("ml" ou "fl oz").
    static var volumeUnitSymbol: String {
        preferredVolumeUnit.symbol
    }

    /// Placeholder pour les champs de texte de volume ("ml" ou "fl oz").
    static var volumePlaceholder: String {
        preferredVolumeUnit == .fluidOunces ? "fl oz" : "ml"
    }

    // MARK: - Poids (kg → kg ou lbs selon locale)

    /// Affiche un poids avec conversion locale.
    /// Ex. : 70 → "70 kg" (FR) / "154 lbs" (en-US)
    static func weight(_ kg: Double) -> String {
        let m = Measurement(value: kg, unit: UnitMass.kilograms).converted(to: preferredWeightUnit)
        return weightFormatter.string(from: m)
    }

    /// Valeur numérique du poids converti (pour les sliders).
    /// Ex. : 70 kg → 70.0 (SI) / 154.3 (en-US)
    static func weightValue(_ kg: Double) -> Double {
        Measurement(value: kg, unit: UnitMass.kilograms).converted(to: preferredWeightUnit).value
    }

    /// Reconvertit une valeur affichée (lbs ou kg) en kg pour le stockage.
    static func weightToSI(_ displayValue: Double) -> Double {
        Measurement(value: displayValue, unit: preferredWeightUnit).converted(to: .kilograms).value
    }

    /// Symbole de l'unité de poids selon la locale ("kg" ou "lbs").
    static var weightUnitSymbol: String {
        preferredWeightUnit.symbol
    }

    // MARK: - Taille (cm → cm ou ft+in selon locale)

    /// Affiche une taille avec conversion locale.
    /// Ex. : 175 → "175 cm" (FR) / "5 ft 9 in" (en-US)
    static func height(_ cm: Double) -> String {
        if usesImperialLength {
            let totalInches = cm / 2.54
            let feet  = Int(totalInches / 12)
            let inches = Int(totalInches.truncatingRemainder(dividingBy: 12))
            return "\(feet) ft \(inches) in"
        } else {
            return "\(Int(cm)) cm"
        }
    }

    /// Valeur numérique de la taille convertie (pour les sliders en-US : pouces totaux).
    static func heightValue(_ cm: Double) -> Double {
        usesImperialLength ? cm / 2.54 : cm
    }

    /// Reconvertit une valeur affichée (pouces ou cm) en cm pour le stockage.
    static func heightToSI(_ displayValue: Double) -> Double {
        usesImperialLength ? displayValue * 2.54 : displayValue
    }

    /// Symbole de l'unité de taille selon la locale ("cm" ou "in").
    static var heightUnitSymbol: String {
        usesImperialLength ? "in" : "cm"
    }

    // MARK: - Bornes de sliders (pour les labels min/max)

    /// Borne min/max du slider de volume, convertie et formatée.
    static func volumeSliderBound(_ ml: Double) -> String { volume(ml) }

    /// Borne min/max du slider de poids, convertie et formatée.
    static func weightSliderBound(_ kg: Double) -> String {
        let converted = Measurement(value: kg, unit: UnitMass.kilograms).converted(to: preferredWeightUnit)
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        let val = f.string(from: NSNumber(value: converted.value)) ?? "\(Int(converted.value))"
        return "\(val) \(preferredWeightUnit.symbol)"
    }

    /// Borne min/max du slider de taille, convertie et formatée.
    static func heightSliderBound(_ cm: Double) -> String {
        if usesImperialLength {
            let inches = cm / 2.54
            let feet   = Int(inches / 12)
            let rem    = Int(inches.truncatingRemainder(dividingBy: 12))
            return "\(feet)'\(rem)\""
        } else {
            return "\(Int(cm)) cm"
        }
    }

    // MARK: - Ranges de sliders (valeurs internes en SI, affichage converti)

    /// Range du slider de volume en unités locales.
    /// Le slider reste en ml en interne ; les bornes affichées sont converties.
    static var waterSliderRange: ClosedRange<Double> { 50...2000 }   // toujours en ml
    static var goalSliderRange:  ClosedRange<Double> { 500...5000 }  // toujours en ml
    static var weightSliderRange: ClosedRange<Double> {
        usesImperialWeight
            ? (66...441)    // lbs (30–200 kg)
            : (30...200)    // kg
    }
    static var heightSliderRange: ClosedRange<Double> {
        usesImperialLength
            ? (55...87)     // pouces totaux (140–220 cm)
            : (140...220)   // cm
    }

    // MARK: - Détection de locale (privé)

    private static var preferredVolumeUnit: UnitVolume {
        // en_US utilise fl oz ; tous les autres pays utilisent ml
        let regionCode = Locale.current.region?.identifier ?? ""
        return regionCode == "US" ? .fluidOunces : .milliliters
    }

    private static var preferredWeightUnit: UnitMass {
        let regionCode = Locale.current.region?.identifier ?? ""
        // en_US et en_GB utilisent des unités non-SI pour le poids
        switch regionCode {
        case "US": return .pounds
        case "GB": return .pounds   // GB utilise stone en pratique mais lbs est plus simple pour une app santé
        default:   return .kilograms
        }
    }

    static var usesImperialLength: Bool {
        let regionCode = Locale.current.region?.identifier ?? ""
        return regionCode == "US" || regionCode == "GB"
    }

    private static var usesImperialWeight: Bool {
        let regionCode = Locale.current.region?.identifier ?? ""
        return regionCode == "US" || regionCode == "GB"
    }
}
