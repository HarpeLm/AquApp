import HealthKit
import SwiftData
import SwiftUI
import Combine
import Foundation

// MARK: - AppDataStore

@MainActor
final class AppDataStore: ObservableObject {
    private let modelContext: ModelContext
    var modelContextPublic: ModelContext { modelContext }
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

    // MARK: - Cache du jour

    private var _cachedWaterEntries: [WaterEntry]?
    private var _cachedAlcoholEntries: [WaterAlcoholEntry]?
    private var _cacheDay: Date = .distantPast

    private func invalidateCache() {
        _cachedWaterEntries   = nil
        _cachedAlcoholEntries = nil
    }

    private func cachedWaterEntries() -> [WaterEntry] {
        let today = Calendar.current.startOfDay(for: Date())
        if _cachedWaterEntries == nil || _cacheDay != today {
            let (start, end) = todayRange()
            _cachedWaterEntries = fetchWater(from: start, to: end)
            _cacheDay = today
        }
        return _cachedWaterEntries!
    }

    private func cachedAlcoholEntries() -> [WaterAlcoholEntry] {
        let today = Calendar.current.startOfDay(for: Date())
        if _cachedAlcoholEntries == nil || _cacheDay != today {
            let (start, end) = todayRange()
            _cachedAlcoholEntries = fetchAlcohol(from: start, to: end)
            _cacheDay = today
        }
        return _cachedAlcoholEntries!
    }

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        bootstrapCumulativeTotals()
        fullScanSoberStreakAtLaunch()
        recalculateGoalStreak()
    }

    /// Recale l'XP eau d'un jour donné sur ses entrées réellement présentes.
    private func syncWaterXP(for date: Date = Date()) {
        let day = Calendar.current.startOfDay(for: date)
        let amounts: [Double]
        if Calendar.current.isDateInToday(date) {
            amounts = cachedWaterEntries().map(\.amountMl)
        } else {
            let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: day)!
            amounts = fetchWater(from: day, to: dayEnd).map(\.amountMl)
        }
        xpManager?.syncWaterXP(for: day, amountsMl: amounts)
    }

    // MARK: - Bootstrap au lancement

    private func bootstrapCumulativeTotals() {
        if HealthDataManager.shared.totalWaterMl == 0,
           let sum = sumWaterMl(), sum > 0 {
            HealthDataManager.shared.setTotalWaterMl(sum)
        }
        if HealthDataManager.shared.totalAlcoholMl == 0,
           let sum = sumAlcoholMl(), sum > 0 {
            HealthDataManager.shared.setTotalAlcoholMl(sum)
        }
    }

    private func fullScanSoberStreakAtLaunch() {
        guard cachedAlcoholEntries().isEmpty else {
            HealthDataManager.shared.setSoberStreak(0)
            achievementManager?.onSoberStreakUpdated(streak: 0)
            return
        }
        let streak = fullScanSoberStreak()
        HealthDataManager.shared.setSoberStreak(streak)
        achievementManager?.onSoberStreakUpdated(streak: streak)
    }

    public func recalculateCumulativeTotals() {
        if let w = sumWaterMl() { HealthDataManager.shared.setTotalWaterMl(w) }
        if let a = sumAlcoholMl() { HealthDataManager.shared.setTotalAlcoholMl(a) }
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
        cachedWaterEntries().reduce(0) { $0 + $1.amountMl }
    }

    var todayAlcoholCompensationMl: Double {
        cachedAlcoholEntries().reduce(0) { $0 + $1.compensationMl }
    }

    var todayWaterMl: Double {
        max(0, todayWaterMlRaw - todayAlcoholCompensationMl)
    }

    var todayAlcoholMl: Double {
        cachedAlcoholEntries().reduce(0) { $0 + $1.amountMl }
    }

    var todayProgress: Double {
        min(todayWaterMl / max(effectiveGoalMl, 1), 1.0)
    }

    var todayGoalReached: Bool {
        todayWaterMl >= effectiveGoalMl
    }

    var todayEffectiveGoalMl: Double { effectiveGoalMl }

    // MARK: - Entrées du jour (API publique)

    func todayWaterEntries() -> [WaterEntry] { cachedWaterEntries() }
    func todayAlcoholEntries() -> [WaterAlcoholEntry] { cachedAlcoholEntries() }

    // MARK: - Ajout eau

    func addWater(amountMl: Double, date: Date = Date()) {
        guard amountMl.isFinite, amountMl > 0, amountMl <= 5000 else {
            print("⚠️ addWater — valeur rejetée: \(amountMl)")
            return
        }

        let wasGoalReached = todayGoalReached
        let entry = WaterEntry(amountMl: amountMl, date: date)
        modelContext.insert(entry)
        save()
        HealthDataManager.shared.addWaterMl(amountMl)
        HealthKitWriter.shared.write(amountMl: amountMl, date: date, entryID: entry.id)
        invalidateCache()
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
        let waterEntries = cachedWaterEntries()
        let mlBeforeNine = waterEntries.filter { $0.date < nineAM }.reduce(0) { $0 + $1.amountMl }

        challengeManager?.onWaterUpdated(
            totalTodayMl: todayWaterMlRaw,
            dailyGoalMl: dailyGoalMl,
            dailyGoalReached: todayGoalReached,
            drinkCount: waterEntries.count,
            mlBeforeNine: mlBeforeNine,
            waterEntries: waterEntries,
            alcoholCount: cachedAlcoholEntries().count
        )

        fetchAndCacheTodaySteps { [weak self] steps in
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
        HealthKitWriter.shared.delete(entryID: entry.id, date: entry.date)
        modelContext.delete(entry)
        save()
        HealthDataManager.shared.addWaterMl(-entry.amountMl)
        invalidateCache()
        syncWaterXP(for: entry.date)
        updateDayRecord(for: entry.date)
        recalculateGoalStreak()
        objectWillChange.send()
    }

    // MARK: - Ajout alcool

    func addAlcohol(amountMl: Double, type: AlcoholKind, date: Date = Date()) {
        guard amountMl.isFinite, amountMl > 0, amountMl <= 5000 else {
            print("⚠️ addAlcohol — valeur rejetée: \(amountMl)")
            return
        }

        let entry = WaterAlcoholEntry(amountMl: amountMl, alcoholType: type, date: date)
        modelContext.insert(entry)
        save()
        HealthDataManager.shared.addAlcoholMl(amountMl)
        invalidateCache()
        updateDayRecord(for: date)
        recalculateSoberStreak()
        challengeManager?.onAlcoholUpdated(
            alcoholCount: cachedAlcoholEntries().count,
            dailyGoalReached: todayGoalReached
        )
        objectWillChange.send()
    }

    func deleteAlcohol(_ entry: WaterAlcoholEntry) {
        modelContext.delete(entry)
        save()
        HealthDataManager.shared.addAlcoholMl(-entry.amountMl)
        invalidateCache()
        updateDayRecord(for: entry.date)
        recalculateSoberStreak()
        challengeManager?.onAlcoholUpdated(
            alcoholCount: cachedAlcoholEntries().count,
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
        let allEntries = fetchWater(from: weekStart, to: weekEnd)
        let grouped = Dictionary(grouping: allEntries) { calendar.startOfDay(for: $0.date) }

        let allAlcohol = fetchAlcohol(from: weekStart, to: weekEnd)
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
        fetchDayRecords(last: 30).filter { $0.goalReached }.count
    }

    var activeDaysTotal: Int {
        countDistinctWaterDays() ?? 0
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
        let entries = fetchWater(from: currentWeekStart, to: currentWeekEnd)
        guard !entries.isEmpty else { return 0 }
        let byDay = Dictionary(grouping: entries) { $0.day }
        let totals = byDay.values.map { $0.reduce(0) { $0 + $1.amountMl } }
        return totals.reduce(0, +) / Double(max(totals.count, 1))
    }

    var weekAlcoholLiters: Double {
        fetchAlcohol(from: currentWeekStart, to: currentWeekEnd)
            .reduce(0) { $0 + $1.amountMl } / 1000.0
    }

    var monthAlcoholLiters: Double {
        let start = Calendar.current.date(byAdding: .month, value: -1, to: Date())!
        return fetchAlcohol(from: start, to: Date()).reduce(0) { $0 + $1.amountMl } / 1000.0
    }

    var totalWaterLiters: Double {
        HealthDataManager.shared.totalWaterMl / 1000.0
    }

    func weekTotalMl(from start: Date, to end: Date) -> Double {
        let waterEntries = fetchWater(from: start, to: end)
        let alcoholEntries = fetchAlcohol(from: start, to: end)
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

        let todayWater = cachedWaterEntries().reduce(0) { $0 + $1.amountMl }
        let todayGoalMet = todayWater >= effectiveGoalMl

        var streakFromPast = 0
        var checkDate = calendar.date(byAdding: .day, value: -1, to: today)!

        while checkDate >= installDate {
            guard let record = fetchDayRecord(for: checkDate) else { break }
            if record.goalReached {
                streakFromPast += 1
                checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
            } else {
                break
            }
        }

        let streak = todayGoalMet ? streakFromPast + 1 : streakFromPast
        let total = (try? modelContext.fetch(FetchDescriptor<DayRecord>()))?.filter { $0.goalReached }.count ?? 0

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
        guard cachedAlcoholEntries().isEmpty else {
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
        let alcoholYesterday = fetchAlcohol(from: calendar.startOfDay(for: yesterday), to: yesterdayEnd)
        
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

        let allAlcohol = fetchAlcohol(from: installDate, to: yesterday)
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

        let existingWaterIDs = (try? modelContext.fetch(FetchDescriptor<WaterEntry>()))
            .map { Set($0.compactMap(\.siriIntentID)) } ?? Set()
        let existingAlcoholIDs = (try? modelContext.fetch(FetchDescriptor<WaterAlcoholEntry>()))
            .map { Set($0.compactMap(\.siriIntentID)) } ?? Set()

        var datesAffected: Set<Date> = []
        var needsSoberRecalc = false

        for entry in pending {
            guard
                let amount = entry["amountMl"] as? Double,
                let timestamp = entry["timestamp"] as? TimeInterval
            else { continue }

            guard amount.isFinite, amount > 0, amount <= 5000 else {
                print("⚠️ flushWidgetPendingEntries — entrée rejetée, amountMl invalide: \(amount)")
                continue
            }
            guard timestamp.isFinite, timestamp > 0 else {
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
                modelContext.insert(alcoholEntry)
                HealthDataManager.shared.addAlcoholMl(amount)
                needsSoberRecalc = true
            } else {
                if let id = intentID, existingWaterIDs.contains(id) { continue }
                let waterEntry = WaterEntry(amountMl: amount, date: date, siriIntentID: intentID)
                modelContext.insert(waterEntry)
                HealthDataManager.shared.addWaterMl(amount)
                HealthKitWriter.shared.write(amountMl: amount, date: date, entryID: waterEntry.id)
            }

            datesAffected.insert(Calendar.current.startOfDay(for: date))
        }

        save()
        invalidateCache()
        for day in datesAffected { syncWaterXP(for: day) }
        for day in datesAffected { updateDayRecord(for: day) }
        recalculateGoalStreak()
        if needsSoberRecalc { recalculateSoberStreak() }
        objectWillChange.send()
    }

    func performMidnightReset() {
        invalidateCache()
        recalculateSoberStreak()
        recalculateGoalStreak()
        challengeManager?.performDailyReset()
        syncWidgetData()
        UserDefaults.standard.set(Calendar.current.startOfDay(for: Date()), forKey: "last_reset_date")
        objectWillChange.send()
    }

    // MARK: - Historique complet (Premium)

    func allWaterEntries() -> [WaterEntry] { fetchAllWater() }
    func allAlcoholEntries() -> [WaterAlcoholEntry] { fetchAllAlcohol() }

    // MARK: - Nettoyage non-Premium

    func cleanOldDataIfNeeded() {
        guard !isPremiumUser else { return }
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        fetchWater(to: cutoff).forEach { modelContext.delete($0) }
        fetchAlcohol(to: cutoff).forEach { modelContext.delete($0) }
        let oldRecords = (try? modelContext.fetch(FetchDescriptor<DayRecord>(
            predicate: #Predicate { $0.date < cutoff }
        ))) ?? []
        oldRecords.forEach { modelContext.delete($0) }
        save()
        invalidateCache()
        recalculateCumulativeTotals()
    }

    // MARK: - DayRecord

    private func updateDayRecord(for date: Date) {
        let day = Calendar.current.startOfDay(for: date)
        let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: day)!

        let netMl: Double
        if Calendar.current.isDateInToday(date) {
            let waterRaw = cachedWaterEntries().reduce(0.0) { $0 + $1.amountMl }
            let alcoholComp = cachedAlcoholEntries().reduce(0.0) { $0 + $1.compensationMl }
            netMl = max(0, waterRaw - alcoholComp)
        } else {
            let waterRaw = fetchWater(from: day, to: dayEnd).reduce(0.0) { $0 + $1.amountMl }
            let alcoholComp = fetchAlcohol(from: day, to: dayEnd).reduce(0.0) { $0 + $1.compensationMl }
            netMl = max(0, waterRaw - alcoholComp)
        }

        let goalForDay = Calendar.current.isDateInToday(date) ? effectiveGoalMl : dailyGoalMl
        let reached = netMl >= goalForDay

        if let existing = fetchDayRecord(for: day) {
            existing.goalReached = reached
            existing.goalMl = goalForDay
        } else {
            let record = DayRecord(date: day, goalMl: goalForDay, goalReached: reached)
            modelContext.insert(record)
        }
        save()
    }

    func fetchDayRecord(for day: Date) -> DayRecord? {
        let start = Calendar.current.startOfDay(for: day)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start)!
        let descriptor = FetchDescriptor<DayRecord>(
            predicate: #Predicate { $0.date >= start && $0.date < end }
        )
        return (try? modelContext.fetch(descriptor))?.first
    }

    private func fetchDayRecords(last days: Int) -> [DayRecord] {
        let start = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        let descriptor = FetchDescriptor<DayRecord>(
            predicate: #Predicate { $0.date >= start },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    // MARK: - Grille de contributions

    func contributionRatios(days: Int = 365) -> [Date: Double] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let start = calendar.date(byAdding: .day, value: -(days - 1), to: today)!

        let allWater = (try? modelContext.fetch(FetchDescriptor<WaterEntry>())) ?? []
        let allAlcohol = (try? modelContext.fetch(FetchDescriptor<WaterAlcoholEntry>())) ?? []
        let allRecords = (try? modelContext.fetch(FetchDescriptor<DayRecord>())) ?? []

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

    // MARK: - Pas (HealthKit)

    private func fetchAndCacheTodaySteps(completion: @escaping (Double) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            completion(UserDefaults.standard.double(forKey: "cached_steps_today"))
            return
        }
        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let store = HKHealthStore()
        guard store.authorizationStatus(for: stepType) != .notDetermined else {
            completion(UserDefaults.standard.double(forKey: "cached_steps_today"))
            return
        }
        let calendar = Calendar.current
        let startDay = calendar.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: startDay, end: Date(), options: .strictStartDate)
        let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
            let steps = result?.sumQuantity()?.doubleValue(for: HKUnit.count()) ?? 0
            UserDefaults.standard.set(steps, forKey: "cached_steps_today")
            DispatchQueue.main.async { completion(steps) }
        }
        store.execute(query)
    }

    // MARK: - Requêtes agrégées (bootstrap / restore uniquement)

    private func sumWaterMl() -> Double? {
        let descriptor = FetchDescriptor<WaterEntry>()
        guard let results = try? modelContext.fetch(descriptor) else { return nil }
        return results.reduce(0.0) { $0 + $1.amountMl }
    }

    private func sumAlcoholMl() -> Double? {
        let descriptor = FetchDescriptor<WaterAlcoholEntry>()
        guard let results = try? modelContext.fetch(descriptor) else { return nil }
        return results.reduce(0.0) { $0 + $1.amountMl }
    }

    private func countDistinctWaterDays() -> Int? {
        let descriptor = FetchDescriptor<WaterEntry>()
        guard let results = try? modelContext.fetch(descriptor) else { return nil }
        let uniqueDays = Set(results.map { Calendar.current.startOfDay(for: $0.date) })
        return uniqueDays.count
    }

    // MARK: - Fetch Water

    private func fetchWater(from start: Date? = nil, to end: Date? = nil) -> [WaterEntry] {
        var descriptor = FetchDescriptor<WaterEntry>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        if let s = start, let e = end {
            descriptor.predicate = #Predicate { $0.date >= s && $0.date < e }
        } else if let e = end {
            descriptor.predicate = #Predicate { $0.date < e }
        }
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func fetchAllWater() -> [WaterEntry] {
        let descriptor = FetchDescriptor<WaterEntry>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    // MARK: - Fetch Alcohol

    private func fetchAlcohol(from start: Date? = nil, to end: Date? = nil) -> [WaterAlcoholEntry] {
        var descriptor = FetchDescriptor<WaterAlcoholEntry>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        if let s = start, let e = end {
            descriptor.predicate = #Predicate { $0.date >= s && $0.date < e }
        } else if let e = end {
            descriptor.predicate = #Predicate { $0.date < e }
        }
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func fetchAllAlcohol() -> [WaterAlcoholEntry] {
        let descriptor = FetchDescriptor<WaterAlcoholEntry>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    // MARK: - Save

    private func save() {
        do {
            try modelContext.save()
        } catch {
            print("⚠️ AppDataStore – échec de la sauvegarde : \(error)")
        }
        syncWidgetData()
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

        let allWater = fetchWater(from: sevenDaysAgo, to: tomorrow)
        let allAlcohol = fetchAlcohol(from: sevenDaysAgo, to: tomorrow)

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
                reached = fetchDayRecord(for: dayStart)?.goalReached ?? false
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

    // MARK: - Helpers

    private func todayRange() -> (Date, Date) {
        let start = Calendar.current.startOfDay(for: Date())
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start)!
        return (start, end)
    }
}
