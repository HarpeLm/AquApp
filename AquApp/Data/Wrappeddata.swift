//
//  Wrappeddata.swift
//  AquApp
//
//  Created by Fabian Dargaud on 01/07/2026.
//

//
//  WrappedData.swift
//  AquApp
//
//  Modèle de données pour le AquApp Wrapped annuel.
//  Calculé depuis AppDataStore en début d'année (ou manuellement depuis le profil).
//  Stocké dans UserDefaults pour éviter de recalculer à chaque affichage.

import Foundation
import SwiftData

// MARK: - WrappedData

struct WrappedData: Codable {

    let year:             Int
    let userName:         String

    // ── Eau ──────────────────────────────────────────────────────────────────
    let totalLiters:      Double   // total eau bue dans l'année
    let totalGlasses:     Int      // équivalent verres de 250ml
    let avgDailyMl:       Double   // moyenne journalière
    let bestMonthName:    String   // mois avec le plus d'eau
    let bestMonthLiters:  Double   // litres ce mois-là

    // ── Objectifs & Streaks ───────────────────────────────────────────────────
    let goalDays:         Int      // jours où l'objectif a été atteint
    let bestStreak:       Int      // meilleure série consécutive
    let soberDays:        Int      // jours sans alcool

    // ── Alcool ───────────────────────────────────────────────────────────────
    let alcoholLiters:    Double   // litres d'alcool total
    let topAlcoholKind:   String   // boisson la plus consommée

    // ── Habitudes ─────────────────────────────────────────────────────────────
    let morningDays:      Int      // jours avec une entrée avant 9h
    let heatwaveDays:     Int      // jours de canicule gérés (>3000ml)

    // ── XP & Succès ───────────────────────────────────────────────────────────
    let xpTotal:          Int
    let xpLevelName:      String
    let achievementsCount:Int
    let challengesCount:  Int

    // ── Détail mensuel (pour le graphique slide 4) ──────────────────────────────
    let monthlyTotals:    [Double]  // 12 valeurs, janvier → décembre, en litres
    let monthLabels:      [String]  // 12 labels courts localisés

    // ── Percentile ───────────────────────────────────────────────────────────
    // Calculé localement — basé sur le ratio jours d'objectif atteint / 365
    var percentileTop: Int {
        let ratio = Double(goalDays) / 365.0
        if ratio >= 0.95 { return 1  }
        if ratio >= 0.90 { return 5  }
        if ratio >= 0.80 { return 10 }
        if ratio >= 0.70 { return 20 }
        if ratio >= 0.50 { return 35 }
        return 50
    }

    // ── Easter egg légendaire ────────────────────────────────────────────────
    // Déclenché si une statistique dépasse un seuil exceptionnel.
    // Vérifié dans cet ordre : streak, sobriété, percentile, XP.
    var isLegendary: Bool {
        bestStreak >= 100 || soberDays >= 300 || percentileTop <= 1 || xpTotal >= 8500
    }

    /// Raison textuelle de l'easter egg légendaire — affichée sur la slide bonus.
    var legendaryReason: String {
        if bestStreak >= 100 {
            return String(format: String(localized: "wrapped.legendary.reason_streak"), bestStreak)
        }
        if soberDays >= 300 {
            return String(format: String(localized: "wrapped.legendary.reason_sober"), soberDays)
        }
        if percentileTop <= 1 {
            return String(localized: "wrapped.legendary.reason_percentile")
        }
        if xpTotal >= 8500 {
            return String(format: String(localized: "wrapped.legendary.reason_xp"), xpTotal)
        }
        return String(localized: "wrapped.legendary.reason_default")
    }

    // ── Message de clôture adaptatif ─────────────────────────────────────────
    // Choisi selon le profil dominant de l'utilisateur (santé / discipline /
    // équilibre) plutôt qu'un message générique fixe.
    var adaptiveClosingMessage: String {
        let soberRatio = Double(soberDays) / 365.0
        let goalRatio  = Double(goalDays) / 365.0

        if soberRatio >= 0.8 {
            return String(format: String(localized: "wrapped.closing.health"), userName)
        }
        if bestStreak >= 30 {
            return String(format: String(localized: "wrapped.closing.discipline"), userName)
        }
        if goalRatio >= 0.6 {
            return String(format: String(localized: "wrapped.closing.balance"), userName)
        }
        return String(format: String(localized: "wrapped.closing.default"), userName)
    }
}

// MARK: - WrappedDataBuilder

/// Calcule le WrappedData depuis AppDataStore + UserDefaults.
/// Appelé en fin d'année (31 décembre) ou manuellement depuis le profil.
@MainActor
struct WrappedDataBuilder {

    static func build(
        store:      AppDataStore,
        xpManager:  XPManager,
        achievementManager: AchievementManager,
        challengeManager:   ChallengeManager,
        modelContext: ModelContext
    ) -> WrappedData {

        let calendar = Calendar.current
        let year     = calendar.component(.year, from: Date())
        let userName = UserDefaults.standard.string(forKey: "userFirstName") ?? ""

        // Bornes de l'année
        var comps        = DateComponents()
        comps.year       = year
        comps.month      = 1
        comps.day        = 1
        let yearStart    = calendar.date(from: comps) ?? Date()
        comps.year       = year + 1
        let yearEnd      = calendar.date(from: comps) ?? Date()

        // ── Fetch eau de l'année ──────────────────────────────────────────────
        var waterDesc = FetchDescriptor<WaterEntry>(
            predicate: #Predicate { $0.date >= yearStart && $0.date < yearEnd },
            sortBy: [SortDescriptor(\.date)]
        )
        let waterEntries = (try? modelContext.fetch(waterDesc)) ?? []

        // ── Fetch alcool de l'année ───────────────────────────────────────────
        var alcDesc = FetchDescriptor<WaterAlcoholEntry>(
            predicate: #Predicate { $0.date >= yearStart && $0.date < yearEnd },
            sortBy: [SortDescriptor(\.date)]
        )
        let alcoholEntries = (try? modelContext.fetch(alcDesc)) ?? []

        // ── Total eau ─────────────────────────────────────────────────────────
        let totalMl      = waterEntries.reduce(0.0) { $0 + $1.amountMl }
        let totalLiters  = totalMl / 1000.0
        let totalGlasses = Int(totalMl / 250.0)

        // ── Jours actifs et moyenne ───────────────────────────────────────────
        let activeDays = Set(waterEntries.map { calendar.startOfDay(for: $0.date) }).count
        let avgDailyMl = activeDays > 0 ? totalMl / Double(activeDays) : 0

        // ── Meilleur mois ─────────────────────────────────────────────────────
        var monthTotals = [Int: Double]()
        for entry in waterEntries {
            let month = calendar.component(.month, from: entry.date)
            monthTotals[month, default: 0] += entry.amountMl
        }
        let bestMonthNum    = monthTotals.max(by: { $0.value < $1.value })?.key ?? 7
        let bestMonthLiters = (monthTotals[bestMonthNum] ?? 0) / 1000.0
        let bestMonthName   = monthName(bestMonthNum)

        // ── Objectifs atteints ────────────────────────────────────────────────
        var dayRecordDesc = FetchDescriptor<DayRecord>(
            predicate: #Predicate { $0.date >= yearStart && $0.date < yearEnd }
        )
        let dayRecords  = (try? modelContext.fetch(dayRecordDesc)) ?? []
        let goalDays    = dayRecords.filter { $0.goalReached }.count

        // ── Meilleure streak ──────────────────────────────────────────────────
        let sortedRecords = dayRecords.sorted { $0.date < $1.date }
        var bestStreak    = 0
        var curStreak     = 0
        for record in sortedRecords {
            if record.goalReached { curStreak += 1; bestStreak = max(bestStreak, curStreak) }
            else                  { curStreak = 0 }
        }

        // ── Jours sobres ──────────────────────────────────────────────────────
        let alcoholDays = Set(alcoholEntries.map { calendar.startOfDay(for: $0.date) })
        let totalDays   = calendar.dateComponents([.day], from: yearStart, to: min(yearEnd, Date())).day ?? 365
        let soberDays   = totalDays - alcoholDays.count

        // ── Alcool ────────────────────────────────────────────────────────────
        let alcoholLiters = alcoholEntries.reduce(0.0) { $0 + $1.amountMl } / 1000.0
        var kindCounts    = [String: Double]()
        for e in alcoholEntries { kindCounts[e.alcoholType.localizedName, default: 0] += e.amountMl }
        let topKind = kindCounts.max(by: { $0.value < $1.value })?.key ?? "—"

        // ── Habitudes matinales ───────────────────────────────────────────────
        let morningDays = Set(
            waterEntries.compactMap { entry -> Date? in
                let hour = calendar.component(.hour, from: entry.date)
                return hour < 9 ? calendar.startOfDay(for: entry.date) : nil
            }
        ).count

        // ── Canicule ──────────────────────────────────────────────────────────
        let heatwaveDays = Int(UserDefaults.standard.double(forKey: "heatwave_days"))

        // ── XP & Succès ───────────────────────────────────────────────────────
        let xpTotal   = xpManager.totalXP
        let xpLevel   = xpManager.currentLevel.localizedName
        let achCount  = achievementManager.achievements.filter { $0.status == .completed }.count
                      + achievementManager.monthlyAchievements.filter { $0.status == .completed }.count
        let chalCount = challengeManager.challenges.filter { $0.status == .completed }.count

        // ── Détail mensuel pour le graphique ──────────────────────────────────
        let monthlyTotals = (1...12).map { (monthTotals[$0] ?? 0) / 1000.0 }
        let monthFormatter = DateFormatter()
        monthFormatter.locale = Locale.current
        let monthLabels = (1...12).map { month -> String in
            String(monthFormatter.shortMonthSymbols[safe: month - 1]?.prefix(1).uppercased() ?? "?")
        }

        return WrappedData(
            year:              year,
            userName:          userName,
            totalLiters:       totalLiters,
            totalGlasses:      totalGlasses,
            avgDailyMl:        avgDailyMl,
            bestMonthName:     bestMonthName,
            bestMonthLiters:   bestMonthLiters,
            goalDays:          goalDays,
            bestStreak:        bestStreak,
            soberDays:         max(0, soberDays),
            alcoholLiters:     alcoholLiters,
            topAlcoholKind:    topKind,
            morningDays:       morningDays,
            heatwaveDays:      heatwaveDays,
            xpTotal:           xpTotal,
            xpLevelName:       xpLevel,
            achievementsCount: achCount,
            challengesCount:   chalCount,
            monthlyTotals:     monthlyTotals,
            monthLabels:       monthLabels
        )
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private static func monthName(_ month: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        return formatter.monthSymbols[safe: month - 1]?.capitalized ?? "—"
    }
}

// MARK: - Array safe subscript

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
