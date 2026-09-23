import SwiftData
import SwiftUI
import Combine
import Foundation

// MARK: - AppDataStore

/// Façade unique exposée aux vues : orchestre les mutations et délègue
/// le stockage (EntryRepository), les stats (StatsCalculator), les séries
/// (StreakEngine) et le widget (WidgetBridge).
@MainActor
final class AppDataStore: ObservableObject {
    private let repository: EntryRepository
    private let stats: StatsCalculator
    private let streaks: StreakEngine
    private let widget = WidgetBridge()

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
        let sober = streaks.soberStreakAtLaunch()
        achievementManager?.onSoberStreakUpdated(streak: sober)
        recalculateGoalStreak()
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

    public func recalculateCumulativeTotals() {
        if let w = repository.totalWaterMl() { HealthDataManager.shared.setTotalWaterMl(w) }
        if let a = repository.totalAlcoholMl() { HealthDataManager.shared.setTotalAlcoholMl(a) }
    }

    func recalculateAllAchievementsFromHistory() {
        guard let am = achievementManager else { return }
        am.onWaterAdded(totalCumulatedMl: HealthDataManager.shared.totalWaterMl)
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

    func todayWaterEntries() -> [WaterEntry] { repository.todayWater() }
    func todayAlcoholEntries() -> [WaterAlcoholEntry] { repository.todayAlcohol() }

    // MARK: - Eau

    func addWater(amountMl: Double, date: Date = Date()) {
        guard EntryValidation.isValid(amountMl: amountMl) else {
            print("⚠️ addWater — valeur rejetée: \(amountMl)")
            return
        }

        let wasGoalReached = todayGoalReached
        let entry = WaterEntry(amountMl: amountMl, date: date)
        repository.insert(entry)
        guard repository.save() else {
            repository.rollback()
            return
        }

        // Seulement APRÈS succès SwiftData
        HealthDataManager.shared.addWaterMl(amountMl)
        HealthKitWriter.shared.write(amountMl: amountMl, date: date, entryID: entry.id)
        didChangeEntries(on: [date], water: true, alcohol: false)

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
    }

    func deleteWater(_ entry: WaterEntry) {
        let (id, date, amount) = (entry.id, entry.date, entry.amountMl)
        repository.delete(entry)
        guard repository.save() else {
            repository.rollback()
            return
        }

        HealthKitWriter.shared.delete(entryID: id, date: date)
        HealthDataManager.shared.addWaterMl(-amount)
        didChangeEntries(on: [date], water: true, alcohol: false)
    }

    // MARK: - Alcool

    func addAlcohol(amountMl: Double, type: AlcoholKind, date: Date = Date()) {
        guard EntryValidation.isValid(amountMl: amountMl) else {
            print("⚠️ addAlcohol — valeur rejetée: \(amountMl)")
            return
        }

        repository.insert(WaterAlcoholEntry(amountMl: amountMl, alcoholType: type, date: date))
        guard repository.save() else {
            repository.rollback()
            return
        }

        HealthDataManager.shared.addAlcoholMl(amountMl)
        didChangeEntries(on: [date], water: false, alcohol: true)
        notifyChallengesOfAlcohol()
    }

    func deleteAlcohol(_ entry: WaterAlcoholEntry) {
        let (date, amount) = (entry.date, entry.amountMl)
        repository.delete(entry)
        guard repository.save() else {
            repository.rollback()
            return
        }

        HealthDataManager.shared.addAlcoholMl(-amount)
        didChangeEntries(on: [date], water: false, alcohol: true)
        notifyChallengesOfAlcohol()
    }

    private func notifyChallengesOfAlcohol() {
        challengeManager?.onAlcoholUpdated(
            alcoholCount: repository.todayAlcohol().count,
            dailyGoalReached: todayGoalReached
        )
    }

    // MARK: - Pipeline commun aux mutations

    /// À appeler après toute écriture d'entrées déjà sauvegardée : met à jour XP,
    /// DayRecord et séries, puis synchronise le widget une seule fois avec des valeurs à jour.
    private func didChangeEntries(on dates: Set<Date>, water: Bool, alcohol: Bool) {
        let days = Set(dates.map { Calendar.current.startOfDay(for: $0) })
        for day in days {
            if water { syncWaterXP(for: day) }
            streaks.upsertDayRecord(for: day, effectiveGoalMl: effectiveGoalMl, dailyGoalMl: dailyGoalMl)
        }
        repository.save()
        streaks.recalculateGoalStreak(effectiveGoalMl: effectiveGoalMl)
        if alcohol, let sober = streaks.recalculateSoberStreak() {
            achievementManager?.onSoberStreakUpdated(streak: sober)
        }
        syncWidgetData()
        objectWillChange.send()
    }

    /// Recale l'XP eau d'un jour donné sur ses entrées réellement présentes.
    private func syncWaterXP(for day: Date) {
        let amounts: [Double]
        if Calendar.current.isDateInToday(day) {
            amounts = repository.todayWater().map(\.amountMl)
        } else {
            let (start, end) = EntryRepository.dayRange(containing: day)
            amounts = repository.water(from: start, to: end).map(\.amountMl)
        }
        xpManager?.syncWaterXP(for: day, amountsMl: amounts)
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

    // MARK: - Séries (déléguées à StreakEngine)

    var currentStreak: Int { HealthDataManager.shared.currentStreak }
    var totalGoalDays: Int { HealthDataManager.shared.totalGoalDays }
    var soberDaysStreak: Int { HealthDataManager.shared.soberStreak }
    var firstLaunchDate: Date { streaks.firstLaunchDate }

    func recalculateGoalStreak() {
        streaks.recalculateGoalStreak(effectiveGoalMl: effectiveGoalMl)
        objectWillChange.send()
    }

    func recalculateSoberStreak() {
        guard let streak = streaks.recalculateSoberStreak() else { return }
        achievementManager?.onSoberStreakUpdated(streak: streak)
        objectWillChange.send()
    }

    func fetchDayRecord(for day: Date) -> DayRecord? {
        repository.dayRecord(for: day)
    }

    // MARK: - Widget

    func flushWidgetPendingEntries() {
        let pending = widget.drainPendingEntries()
        guard !pending.isEmpty else { return }

        let existingWaterIDs = repository.waterIntentIDs()
        let existingAlcoholIDs = repository.alcoholIntentIDs()
        var datesAffected: Set<Date> = []
        var alcoholAdded = false

        for entry in pending {
            if let kind = entry.alcoholKind {
                if let id = entry.siriIntentID, existingAlcoholIDs.contains(id) { continue }
                repository.insert(WaterAlcoholEntry(amountMl: entry.amountMl, alcoholType: kind,
                                                     date: entry.date, siriIntentID: entry.siriIntentID))
                HealthDataManager.shared.addAlcoholMl(entry.amountMl)
                alcoholAdded = true
            } else {
                if let id = entry.siriIntentID, existingWaterIDs.contains(id) { continue }
                let waterEntry = WaterEntry(amountMl: entry.amountMl, date: entry.date, siriIntentID: entry.siriIntentID)
                repository.insert(waterEntry)
                HealthDataManager.shared.addWaterMl(entry.amountMl)
                HealthKitWriter.shared.write(amountMl: entry.amountMl, date: entry.date, entryID: waterEntry.id)
            }
            datesAffected.insert(entry.date)
        }

        repository.save()
        didChangeEntries(on: datesAffected, water: true, alcohol: alcoholAdded)
    }

    func syncWidgetData() {
        let week = stats.dailyTotals(lastDays: 7).enumerated().map { offset, total in
            WidgetDay(
                date: total.date,
                netMl: total.netMl,
                goalReached: offset == 0
                    ? todayGoalReached
                    : repository.dayRecord(for: total.dayStart)?.goalReached ?? false
            )
        }
        widget.write(WidgetSnapshot(
            todayMl: todayWaterMl,
            goalMl: effectiveGoalMl,
            dailyGoalMl: dailyGoalMl,
            streak: currentStreak,
            soberStreak: soberDaysStreak,
            activeDays: activeDaysTotal,
            week: week
        ))
    }

    // MARK: - Reset quotidien

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
        repository.save()
        recalculateCumulativeTotals()
        syncWidgetData()
    }
}
