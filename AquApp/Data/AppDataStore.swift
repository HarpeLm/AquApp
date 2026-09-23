import SwiftData
import SwiftUI
import Combine
import Foundation

// MARK: - AppDataStore

@MainActor
final class AppDataStore: ObservableObject {
    private let repository: EntryRepository
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
        self.repository = EntryRepository(context: modelContext)
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
        guard repository.todayAlcohol().isEmpty else {
            HealthDataManager.shared.setSoberStreak(0)
            achievementManager?.onSoberStreakUpdated(streak: 0)
            return
        }
        let streak = fullScanSoberStreak()
        HealthDataManager.shared.setSoberStreak(streak)
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

    // MARK: - Graphique 7 jours

    var last7DaysWater: [(day: String, ml: Double)] {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = "EEE"

        let weekStart = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: Date()))!
        let weekEnd = calendar.date(byAdding: .day, value: 1, to: Date())!
        let allEntries = repository.water(from: weekStart, to: weekEnd)
        let grouped = Dictionary(grouping: allEntries) { calendar.startOfDay(for: $0.date) }

        let allAlcohol = repository.alcohol(from: weekStart, to: weekEnd)
        let groupedAlcohol = Dictionary(grouping: allAlcohol) { calendar.startOfDay(for: $0.date) }

        return (0..<7).reversed().map { offset in
            let date = calendar.date(byAdding: .day, value: -offset, to: Date())!
            let dayStart = calendar.startOfDay(for: date)
            let waterMl = grouped[dayStart]?.reduce(0) { $0 + $1.amountMl } ?? 0
            let alcoholComp = groupedAlcohol[dayStart]?.reduce(0.0) { $0 + $1.compensationMl } ?? 0.0
            let total = max(0, waterMl - alcoholComp)
            let label = String(formatter.string(from: date).prefix(3).capitalized)
            return (day: label, ml: total)
        }
    }

    // MARK: - Stats globales

    var activeDaysLast30: Int {
        let start = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        return repository.dayRecords(since: start).filter { $0.goalReached }.count
    }

    var activeDaysTotal: Int {
        repository.distinctWaterDayCount() ?? 0
    }

    var totalAlcoholLiters: Double {
        HealthDataManager.shared.totalAlcoholMl / 1000.0
    }

    // MARK: - Semaine en cours

    var currentWeekStart: Date {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekday = calendar.component(.weekday, from: today)
        let daysFromMonday = (weekday == 1) ? 6 : weekday - 2
        return calendar.date(byAdding: .day, value: -daysFromMonday, to: today)!
    }

    var currentWeekEnd: Date {
        Calendar.current.date(byAdding: .day, value: 7, to: currentWeekStart)!
    }

    var avgMlPerDay: Double {
        let entries = repository.water(from: currentWeekStart, to: currentWeekEnd)
        guard !entries.isEmpty else { return 0 }
        let byDay = Dictionary(grouping: entries) { $0.day }
        let totals = byDay.values.map { $0.reduce(0) { $0 + $1.amountMl } }
        return totals.reduce(0, +) / Double(max(totals.count, 1))
    }

    var weekAlcoholLiters: Double {
        repository.alcohol(from: currentWeekStart, to: currentWeekEnd)
            .reduce(0) { $0 + $1.amountMl } / 1000.0
    }

    var monthAlcoholLiters: Double {
        let start = Calendar.current.date(byAdding: .month, value: -1, to: Date())!
        return repository.alcohol(from: start, to: Date()).reduce(0) { $0 + $1.amountMl } / 1000.0
    }

    var totalWaterLiters: Double {
        HealthDataManager.shared.totalWaterMl / 1000.0
    }

    func weekTotalMl(from start: Date, to end: Date) -> Double {
        let waterEntries = repository.water(from: start, to: end)
        let alcoholEntries = repository.alcohol(from: start, to: end)
        let waterTotal = waterEntries.reduce(0.0) { $0 + $1.amountMl }
        let alcoholComp = alcoholEntries.reduce(0.0) { $0 + $1.compensationMl }
        return max(0, waterTotal - alcoholComp)
    }

    // MARK: - Goal streak

    var currentStreak: Int {
        HealthDataManager.shared.currentStreak
    }

    var totalGoalDays: Int {
        HealthDataManager.shared.totalGoalDays
    }

    func recalculateGoalStreak() {
        let calendar = Calendar.current
        let installDate = calendar.startOfDay(for: firstLaunchDate)
        let today = calendar.startOfDay(for: Date())

        let todayWater = repository.todayWater().reduce(0) { $0 + $1.amountMl }
        let todayGoalMet = todayWater >= effectiveGoalMl

        var streakFromPast = 0
        var checkDate = calendar.date(byAdding: .day, value: -1, to: today)!

        while checkDate >= installDate {
            guard let record = repository.dayRecord(for: checkDate) else { break }
            if record.goalReached {
                streakFromPast += 1
                checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
            } else {
                break
            }
        }

        let streak = todayGoalMet ? streakFromPast + 1 : streakFromPast
        let total = repository.allDayRecords().filter { $0.goalReached }.count

        HealthDataManager.shared.setCurrentStreak(streak)
        HealthDataManager.shared.setTotalGoalDays(total)
        objectWillChange.send()
    }

    // MARK: - Sober streak

    var soberDaysStreak: Int {
        HealthDataManager.shared.soberStreak
    }

    func recalculateSoberStreak() {
        let calendar = Calendar.current

        // Si alcool aujourd'hui → streak = 0
        guard repository.todayAlcohol().isEmpty else {
            HealthDataManager.shared.setSoberStreak(0)
            achievementManager?.onSoberStreakUpdated(streak: 0)
            objectWillChange.send()
            return
        }

        // Vérifier si on a déjà recalculé aujourd'hui
        let today = calendar.startOfDay(for: Date())
        let lastRecalcDate = UserDefaults.standard.object(forKey: "last_sober_recalc") as? Date

        if let lastRecalc = lastRecalcDate, calendar.isDate(lastRecalc, inSameDayAs: today) {
            // Déjà recalculé aujourd'hui → ne pas incrémenter
            return
        }

        // Vérifier hier
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let yesterdayEnd = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: yesterday))!
        let alcoholYesterday = repository.alcohol(from: calendar.startOfDay(for: yesterday), to: yesterdayEnd)

        // Calculer le nouveau streak
        let storedStreak = HealthDataManager.shared.soberStreak
        let streak = alcoholYesterday.isEmpty ? storedStreak + 1 : 1

        // Sauvegarder
        HealthDataManager.shared.setSoberStreak(streak)
        UserDefaults.standard.set(today, forKey: "last_sober_recalc")
        achievementManager?.onSoberStreakUpdated(streak: streak)
        objectWillChange.send()
    }

    private func fullScanSoberStreak() -> Int {
        let calendar = Calendar.current
        let installDate = calendar.startOfDay(for: firstLaunchDate)
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        let allAlcohol = repository.alcohol(from: installDate, to: yesterday)
        let alcoholDays = Set(allAlcohol.map { calendar.startOfDay(for: $0.date) })

        var streak = 1
        var checkDate = yesterday

        while checkDate >= installDate {
            if alcoholDays.contains(checkDate) { break }
            streak += 1
            checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
        }

        return streak
    }

    var firstLaunchDate: Date {
        let date = HealthDataManager.shared.firstLaunchDate
        if date == Date(timeIntervalSince1970: 0) {
            let now = Date()
            HealthDataManager.shared.setFirstLaunchDate(now)
            return now
        }
        return date
    }

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
        let day = Calendar.current.startOfDay(for: date)
        let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: day)!

        let netMl: Double
        if Calendar.current.isDateInToday(date) {
            let waterRaw = repository.todayWater().reduce(0.0) { $0 + $1.amountMl }
            let alcoholComp = repository.todayAlcohol().reduce(0.0) { $0 + $1.compensationMl }
            netMl = max(0, waterRaw - alcoholComp)
        } else {
            let waterRaw = repository.water(from: day, to: dayEnd).reduce(0.0) { $0 + $1.amountMl }
            let alcoholComp = repository.alcohol(from: day, to: dayEnd).reduce(0.0) { $0 + $1.compensationMl }
            netMl = max(0, waterRaw - alcoholComp)
        }

        let goalForDay = Calendar.current.isDateInToday(date) ? effectiveGoalMl : dailyGoalMl
        let reached = netMl >= goalForDay

        if let existing = repository.dayRecord(for: day) {
            existing.goalReached = reached
            existing.goalMl = goalForDay
        } else {
            let record = DayRecord(date: day, goalMl: goalForDay, goalReached: reached)
            repository.insert(record)
        }
        save()
    }

    func fetchDayRecord(for day: Date) -> DayRecord? {
        repository.dayRecord(for: day)
    }

    // MARK: - Grille de contributions

    func contributionRatios(days: Int = 365) -> [Date: Double] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let start = calendar.date(byAdding: .day, value: -(days - 1), to: today)!

        let allWater = repository.allWater()
        let allAlcohol = repository.allAlcohol()
        let allRecords = repository.allDayRecords()

        var waterByDay: [Date: Double] = [:]
        for entry in allWater where entry.date >= start {
            waterByDay[calendar.startOfDay(for: entry.date), default: 0] += entry.amountMl
        }
        var alcoholCompByDay: [Date: Double] = [:]
        for entry in allAlcohol where entry.date >= start {
            alcoholCompByDay[calendar.startOfDay(for: entry.date), default: 0] += entry.compensationMl
        }

        var goalByDay: [Date: Double] = [:]
        for record in allRecords where record.date >= start {
            goalByDay[calendar.startOfDay(for: record.date)] = record.goalMl
        }

        var result: [Date: Double] = [:]
        var allDays = Set(waterByDay.keys)
        allDays.formUnion(goalByDay.keys)
        for day in allDays where day <= today {
            let net = max(0, (waterByDay[day] ?? 0) - (alcoholCompByDay[day] ?? 0))
            let goal = goalByDay[day] ?? (calendar.isDateInToday(day) ? effectiveGoalMl : dailyGoalMl)
            guard goal > 0 else { continue }
            if waterByDay[day] == nil {
                if let reached = allRecords.first(where: { calendar.startOfDay(for: $0.date) == day })?.goalReached, reached {
                    result[day] = 1.0
                }
                continue
            }
            result[day] = net / goal
        }

        result[today] = todayProgress

        return result
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

        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = "EEE"

        let sevenDaysAgo = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: Date()))!
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date())!

        let allWater = repository.water(from: sevenDaysAgo, to: tomorrow)
        let allAlcohol = repository.alcohol(from: sevenDaysAgo, to: tomorrow)

        let waterByDay = Dictionary(grouping: allWater) { calendar.startOfDay(for: $0.date) }
        let alcoholByDay = Dictionary(grouping: allAlcohol) { calendar.startOfDay(for: $0.date) }

        var weekData: [[String: Any]] = []

        for offset in 0..<7 {
            let date = calendar.date(byAdding: .day, value: -offset, to: Date())!
            let dayStart = calendar.startOfDay(for: date)

            let waterMl: Double
            let alcoholComp: Double
            let reached: Bool
            if offset == 0 {
                waterMl = todayWaterMlRaw
                alcoholComp = todayAlcoholCompensationMl
                reached = todayGoalReached
            } else {
                waterMl = waterByDay[dayStart]?.reduce(0) { $0 + $1.amountMl } ?? 0
                alcoholComp = alcoholByDay[dayStart]?.reduce(0.0) { $0 + $1.compensationMl } ?? 0.0
                reached = repository.dayRecord(for: dayStart)?.goalReached ?? false
            }

            let netMl = max(0, waterMl - alcoholComp)
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
