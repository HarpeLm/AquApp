import SwiftData
import SwiftUI
import Combine
import Foundation

// MARK: - AppDataStore

@MainActor
final class AppDataStore: ObservableObject {
    private let repository: EntryRepository
    private let stats: StatsCalculator
    private let streaks: StreakEngine
    weak var confettiManager: ConfettiManager?
    weak var achievementManager: AchievementManager?
    weak var challengeManager: ChallengeManager?
    weak var xpManager: XPManager?

    @AppStorage("dailyGoalMl") var dailyGoalMl: Double = 2170
    var isPremiumUser: Bool {
        get { PremiumManager.shared.isPremium }
        set { PremiumManager.shared.set(newValue) }
    }

    var heatwaveGoalMl: Double? = nil
    var effectiveGoalMl: Double { heatwaveGoalMl ?? dailyGoalMl }

    init(modelContext: ModelContext) {
        let repository = EntryRepository(context: modelContext)
        self.repository = repository
        self.stats = StatsCalculator(repository: repository)
        self.streaks = StreakEngine(repository: repository)
        bootstrapCumulativeTotals()
        fullScanSoberStreakAtLaunch()
        recalculateGoalStreak()
    }

    /// Recale l'XP eau d'un jour donné sur ses entrées réellement présentes.
    private func syncWaterXP(for date: Date = Date()) {
        let day = Calendar.current.startOfDay(for: date)
        let amounts: [Double]
        if Calendar.current.isDateInToday(date) {
            amounts = repository.todayWater().map(\.amountMl)
        } else {
            let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: day)!
            amounts = repository.water(from: day, to: dayEnd).map(\.amountMl)
        }
        xpManager?.syncWaterXP(for: day, amountsMl: amounts)
    }

    // MARK: - Bootstrap au lancement

    private func bootstrapCumulativeTotals() {
        if HealthDataManager.shared.totalWaterMl == 0,
           let sum = repository.totalWaterMl(), sum > 0 {
            HealthDataManager.shared.setTotalWaterMl(sum)
        }
        if HealthDataManager.shared.totalAlcoholMl == 0,
           let sum = repository.totalAlcoholMl(), sum > 0 {
            HealthDataManager.shared.setTotalAlcoholMl(sum)
        }
    }

    private func fullScanSoberStreakAtLaunch() {
        let streak = streaks.soberStreakAtLaunch()
        achievementManager?.onSoberStreakUpdated(streak: streak)
    }

    public func recalculateCumulativeTotals() {
        if let w = repository.totalWaterMl() { HealthDataManager.shared.setTotalWaterMl(w) }
        if let a = repository.totalAlcoholMl() { HealthDataManager.shared.setTotalAlcoholMl(a) }
    }

    // MARK: - Recalcul des succès au démarrage

    func recalculateAllAchievementsFromHistory() {
        guard let am = achievementManager else { return }
        let totalMl = HealthDataManager.shared.totalWaterMl
        am.onWaterAdded(totalCumulatedMl: totalMl)
        am.onGoalReached(streak: currentStreak, totalDays: totalGoalDays)
        am.onSoberStreakUpdated(streak: soberDaysStreak)
        let heatwaveDays = HealthDataManager.shared.heatwaveDays
        if heatwaveDays > 0 {
            am.restoreHeatwaveProgress(days: heatwaveDays)
        }
    }

    // MARK: - Aujourd'hui

    var todayWaterMlRaw: Double {
        repository.todayWater().reduce(0) { $0 + $1.amountMl }
    }

    var todayAlcoholCompensationMl: Double {
        repository.todayAlcohol().reduce(0) { $0 + $1.compensationMl }
    }

    var todayWaterMl: Double {
        max(0, todayWaterMlRaw - todayAlcoholCompensationMl)
    }

    var todayAlcoholMl: Double {
        repository.todayAlcohol().reduce(0) { $0 + $1.amountMl }
    }

    var todayProgress: Double {
        min(todayWaterMl / max(effectiveGoalMl, 1), 1.0)
    }

    var todayGoalReached: Bool {
        todayWaterMl >= effectiveGoalMl
    }

    var todayEffectiveGoalMl: Double { effectiveGoalMl }

    // MARK: - Entrées du jour (API publique)

    func todayWaterEntries() -> [WaterEntry] { repository.todayWater() }
    func todayAlcoholEntries() -> [WaterAlcoholEntry] { repository.todayAlcohol() }

    // MARK: - Ajout eau

    func addWater(amountMl: Double, date: Date = Date()) {
        guard EntryValidation.isValid(amountMl: amountMl) else {
            print("⚠️ addWater — valeur rejetée: \(amountMl)")
            return
        }

        let wasGoalReached = todayGoalReached
        let entry = WaterEntry(amountMl: amountMl, date: date)
        repository.insert(entry)

        guard save() else {
            repository.rollback()
            return
        }

        // Seulement APRÈS succès SwiftData
        HealthDataManager.shared.addWaterMl(amountMl)
        HealthKitWriter.shared.write(amountMl: amountMl, date: date, entryID: entry.id)
        syncWaterXP(for: date)
        updateDayRecord(for: date)
        recalculateGoalStreak()

        if !wasGoalReached && todayGoalReached {
            HapticManager.shared.goalReached()
            confettiManager?.trigger(.goalReached)
            achievementManager?.onGoalReached(streak: currentStreak, totalDays: totalGoalDays)
            achievementManager?.onHeatwaveDay(totalMl: todayWaterMl)
            achievementManager?.onDailyGoalReached(totalMl: todayWaterMl, goalMl: dailyGoalMl)
            Task { @MainActor in xpManager?.add(.dailyGoal) }
        }

        achievementManager?.onWaterAdded(totalCumulatedMl: HealthDataManager.shared.totalWaterMl)

        let nineAM = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date())!
        let waterEntries = repository.todayWater()
        let mlBeforeNine = waterEntries.filter { $0.date < nineAM }.reduce(0) { $0 + $1.amountMl }

        challengeManager?.onWaterUpdated(
            totalTodayMl: todayWaterMlRaw,
            dailyGoalMl: dailyGoalMl,
            dailyGoalReached: todayGoalReached,
            drinkCount: waterEntries.count,
            mlBeforeNine: mlBeforeNine,
            waterEntries: waterEntries,
            alcoholCount: repository.todayAlcohol().count
        )

        HealthDataManager.shared.fetchTodaySteps { [weak self] steps in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.achievementManager?.onMarathonienCheck(
                    drinkCount: waterEntries.count,
                    goalReached: self.todayGoalReached,
                    steps: steps
                )
            }
        }

        objectWillChange.send()
    }

    func deleteWater(_ entry: WaterEntry) {
        repository.delete(entry)

        guard save() else {
            repository.rollback()
            return
        }

        HealthKitWriter.shared.delete(entryID: entry.id, date: entry.date)
        HealthDataManager.shared.addWaterMl(-entry.amountMl)
        syncWaterXP(for: entry.date)
        updateDayRecord(for: entry.date)
        recalculateGoalStreak()
        objectWillChange.send()
    }

    // MARK: - Ajout alcool

    func addAlcohol(amountMl: Double, type: AlcoholKind, date: Date = Date()) {
        guard EntryValidation.isValid(amountMl: amountMl) else {
            print("⚠️ addAlcohol — valeur rejetée: \(amountMl)")
            return
        }

        let entry = WaterAlcoholEntry(amountMl: amountMl, alcoholType: type, date: date)
        repository.insert(entry)

        guard save() else {
            repository.rollback()
            return
        }

        HealthDataManager.shared.addAlcoholMl(amountMl)
        updateDayRecord(for: date)
        recalculateSoberStreak()
        challengeManager?.onAlcoholUpdated(
            alcoholCount: repository.todayAlcohol().count,
            dailyGoalReached: todayGoalReached
        )
        objectWillChange.send()
    }

    func deleteAlcohol(_ entry: WaterAlcoholEntry) {
        repository.delete(entry)

        guard save() else {
            repository.rollback()
            return
        }

        HealthDataManager.shared.addAlcoholMl(-entry.amountMl)
        updateDayRecord(for: entry.date)
        recalculateSoberStreak()
        challengeManager?.onAlcoholUpdated(
            alcoholCount: repository.todayAlcohol().count,
            dailyGoalReached: todayGoalReached
        )
        objectWillChange.send()
    }

    // MARK: - Statistiques (déléguées à StatsCalculator)

    var last7DaysWater: [(day: String, ml: Double)] { stats.last7DaysWater }
    var activeDaysLast30: Int { stats.activeDaysLast30 }
    var activeDaysTotal: Int { stats.activeDaysTotal }
    var currentWeekStart: Date { stats.currentWeekStart }
    var currentWeekEnd: Date { stats.currentWeekEnd }
    var avgMlPerDay: Double { stats.avgMlPerDay }
    var weekAlcoholLiters: Double { stats.weekAlcoholLiters }
    var monthAlcoholLiters: Double { stats.monthAlcoholLiters }
    func weekTotalMl(from start: Date, to end: Date) -> Double { stats.weekTotalMl(from: start, to: end) }

    func contributionRatios(days: Int = 365) -> [Date: Double] {
        stats.contributionRatios(days: days, todayProgress: todayProgress,
                                 effectiveGoalMl: effectiveGoalMl, dailyGoalMl: dailyGoalMl)
    }

    var totalWaterLiters: Double { HealthDataManager.shared.totalWaterMl / 1000.0 }
    var totalAlcoholLiters: Double { HealthDataManager.shared.totalAlcoholMl / 1000.0 }

    // MARK: - Goal streak

    var currentStreak: Int {
        HealthDataManager.shared.currentStreak
    }

    var totalGoalDays: Int {
        HealthDataManager.shared.totalGoalDays
    }

    func recalculateGoalStreak() {
        streaks.recalculateGoalStreak(effectiveGoalMl: effectiveGoalMl)
        objectWillChange.send()
    }

    // MARK: - Sober streak

    var soberDaysStreak: Int {
        HealthDataManager.shared.soberStreak
    }

    func recalculateSoberStreak() {
        guard let streak = streaks.recalculateSoberStreak() else { return }
        achievementManager?.onSoberStreakUpdated(streak: streak)
        objectWillChange.send()
    }

    var firstLaunchDate: Date { streaks.firstLaunchDate }

    // MARK: - Reset quotidien

    func flushWidgetPendingEntries() {
        guard let defaults = UserDefaults(suiteName: "group.com.fabian.dargaud.AquApp") else { return }
        let pending = defaults.array(forKey: "widget_pending_entries") as? [[String: Any]] ?? []
        guard !pending.isEmpty else { return }

        defaults.removeObject(forKey: "widget_pending_entries")

        let existingWaterIDs = repository.waterIntentIDs()
        let existingAlcoholIDs = repository.alcoholIntentIDs()

        var datesAffected: Set<Date> = []
        var needsSoberRecalc = false

        for entry in pending {
            guard
                let amount = entry["amountMl"] as? Double,
                let timestamp = entry["timestamp"] as? TimeInterval
            else { continue }

            guard EntryValidation.isValid(amountMl: amount) else {
                print("⚠️ flushWidgetPendingEntries — entrée rejetée, amountMl invalide: \(amount)")
                continue
            }
            guard EntryValidation.isValid(timestamp: timestamp) else {
                print("⚠️ flushWidgetPendingEntries — entrée rejetée, timestamp invalide: \(timestamp)")
                continue
            }

            let date = Date(timeIntervalSince1970: timestamp)
            let intentID = entry["siriIntentID"] as? String
            let isAlcohol = entry["isAlcohol"] as? Bool ?? false

            if isAlcohol {
                if let id = intentID, existingAlcoholIDs.contains(id) { continue }
                let kindRaw = entry["alcoholKindRaw"] as? String ?? AlcoholKind.other.rawValue
                let kind = AlcoholKind.migratedAlcoholKind(from: kindRaw)
                let alcoholEntry = WaterAlcoholEntry(amountMl: amount, alcoholType: kind, date: date, siriIntentID: intentID)
                repository.insert(alcoholEntry)
                HealthDataManager.shared.addAlcoholMl(amount)
                needsSoberRecalc = true
            } else {
                if let id = intentID, existingWaterIDs.contains(id) { continue }
                let waterEntry = WaterEntry(amountMl: amount, date: date, siriIntentID: intentID)
                repository.insert(waterEntry)
                HealthDataManager.shared.addWaterMl(amount)
                HealthKitWriter.shared.write(amountMl: amount, date: date, entryID: waterEntry.id)
            }

            datesAffected.insert(Calendar.current.startOfDay(for: date))
        }

        save()
        for day in datesAffected { syncWaterXP(for: day) }
        for day in datesAffected { updateDayRecord(for: day) }
        recalculateGoalStreak()
        if needsSoberRecalc { recalculateSoberStreak() }
        objectWillChange.send()
    }

    func performMidnightReset() {
        repository.invalidateTodayCache()
        recalculateSoberStreak()
        recalculateGoalStreak()
        challengeManager?.performDailyReset()
        syncWidgetData()
        UserDefaults.standard.set(Calendar.current.startOfDay(for: Date()), forKey: "last_reset_date")
        objectWillChange.send()
    }

    // MARK: - Historique complet (Premium)

    func allWaterEntries() -> [WaterEntry] { repository.allWater() }
    func allAlcoholEntries() -> [WaterAlcoholEntry] { repository.allAlcohol() }

    // MARK: - Nettoyage non-Premium

    func cleanOldDataIfNeeded() {
        guard !isPremiumUser else { return }
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        repository.water(to: cutoff).forEach { repository.delete($0) }
        repository.alcohol(to: cutoff).forEach { repository.delete($0) }
        repository.dayRecords(before: cutoff).forEach { repository.delete($0) }
        save()
        recalculateCumulativeTotals()
    }

    // MARK: - DayRecord

    private func updateDayRecord(for date: Date) {
        streaks.upsertDayRecord(for: date, effectiveGoalMl: effectiveGoalMl, dailyGoalMl: dailyGoalMl)
        save()
    }

    func fetchDayRecord(for day: Date) -> DayRecord? {
        repository.dayRecord(for: day)
    }

    // MARK: - Save

    @discardableResult
    private func save() -> Bool {
        guard repository.save() else { return false }
        syncWidgetData()
        return true
    }

    // MARK: - Widget Data Sync

    func syncWidgetData() {
        guard let defaults = UserDefaults(suiteName: "group.com.fabian.dargaud.AquApp") else {
            print("syncWidgetData — App Group introuvable.")
            return
        }

        defaults.set(todayWaterMl, forKey: "widget_today_ml")
        defaults.set(effectiveGoalMl, forKey: "widget_goal_ml")
        defaults.set(currentStreak, forKey: "widget_streak")
        defaults.set(soberDaysStreak, forKey: "widget_sober_streak")
        defaults.set(activeDaysTotal, forKey: "widget_active_days")
        defaults.set(dailyGoalMl, forKey: "widget_daily_goal_ml")

        let formatter = StatsCalculator.weekdayFormatter
        var weekData: [[String: Any]] = []

        for (offset, total) in stats.dailyTotals(lastDays: 7).enumerated() {
            let date = total.date
            let netMl = total.netMl
            let reached = offset == 0
                ? todayGoalReached
                : repository.dayRecord(for: total.dayStart)?.goalReached ?? false
            let label = String(formatter.string(from: date).prefix(1).uppercased())

            weekData.append([
                "label": label,
                "ml": netMl,
                "goalReached": reached,
                "offset": offset
            ])

            if offset >= 1 && offset <= 3 {
                let legacyLabel = String(formatter.string(from: date).prefix(3).capitalized)
                defaults.set(legacyLabel, forKey: "widget_day\(offset)_label")
                defaults.set(netMl, forKey: "widget_day\(offset)_ml")
                defaults.set(reached, forKey: "widget_day\(offset)_goalReached")
            }
        }

        if let data = try? JSONSerialization.data(withJSONObject: weekData) {
            defaults.set(data, forKey: "widget_week_data")
        }
    }
}
