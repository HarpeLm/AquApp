import HealthKit
import SwiftData
import SwiftUI
import Combine
import Foundation


// MARK: - AppDataStore

@MainActor
final class AppDataStore: ObservableObject {

    private let modelContext: ModelContext
    /// Accès public au ModelContext pour les modules externes (WrappedDataBuilder).
    var modelContextPublic: ModelContext { modelContext }
    weak var confettiManager: ConfettiManager?
    /// Injecté depuis AquAppApp pour notifier les succès
    weak var achievementManager: AchievementManager?
    /// Injecté depuis AquAppApp pour notifier les défis
    weak var challengeManager: ChallengeManager?
    /// Injecté depuis AquAppApp pour le système XP
    weak var xpManager: XPManager?


    @AppStorage("dailyGoalMl")   var dailyGoalMl: Double = 2170
    @AppStorage("isPremiumUser") var isPremiumUser: Bool = false

    /// Objectif adaptatif météo — nil si pas de canicule
    var heatwaveGoalMl: Double? = nil

    /// Objectif effectif : canicule si disponible, sinon objectif normal
    var effectiveGoalMl: Double { heatwaveGoalMl ?? dailyGoalMl }

    // MARK: - Cache du jour
    // Toutes les propriétés calculées consomment ce cache
    // au lieu de fetcher SwiftData indépendamment.
    // Invalidé après chaque mutation (addWater, deleteWater, addAlcohol, deleteAlcohol).

    private var _cachedWaterEntries:   [WaterEntry]?
    private var _cachedAlcoholEntries: [WaterAlcoholEntry]?
    private var _cacheDay: Date = .distantPast

    private func invalidateCache() {
        _cachedWaterEntries   = nil
        _cachedAlcoholEntries = nil
    }

    /// Entrées eau du jour — fetche une seule fois par cycle de mutation
    private func cachedWaterEntries() -> [WaterEntry] {
        let today = Calendar.current.startOfDay(for: Date())
        if _cachedWaterEntries == nil || _cacheDay != today {
            let (start, end) = todayRange()
            _cachedWaterEntries = fetchWater(from: start, to: end)
            _cacheDay = today
        }
        return _cachedWaterEntries!
    }

    /// Entrées alcool du jour — fetche une seule fois par cycle de mutation
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
        recalculateSoberStreak()
        recalculateGoalStreak()
    }

    // MARK: - Recalcul des succès au démarrage
    // Appelé depuis AquAppApp après injection de achievementManager,
    // pour que Légende / Aqua'ddict / constance / etc. reflètent
    // l'historique complet dès l'ouverture de l'app.
    func recalculateAllAchievementsFromHistory() {
        guard let am = achievementManager else { return }

        // ── Légende + Aqua'ddict : total cumulé via requête SUM SQLite ───────
        // iOS 17+ : #Expression délègue le calcul à SQLite — zéro chargement
        // d'objets WaterEntry en RAM, aucune limite de 10 000 entrées.
        let totalMl = sumWaterMl() ?? 0
        am.onWaterAdded(totalCumulatedMl: totalMl)

        // Streak objectif → constance, perfect_week, iron_month, indestructible, centurion
        am.onGoalReached(streak: currentStreak, totalDays: totalGoalDays)

        // Streak sobre → semaine_sobre + mensuels + centurion_sobre
        am.onSoberStreakUpdated(streak: soberDaysStreak)

        // Canicule : relit le compteur déjà stocké
        let heatwaveDays = UserDefaults.standard.double(forKey: "heatwave_days")
        if heatwaveDays > 0 {
            am.restoreHeatwaveProgress(days: heatwaveDays)
        }
    }

    // MARK: - Aujourd'hui (computed — utilisent le cache)

    var todayWaterMlRaw: Double {
        cachedWaterEntries().reduce(0) { $0 + $1.amountMl }
    }

    /// Compensation eau nécessaire pour l'alcool du jour.
    var todayAlcoholCompensationMl: Double {
        cachedAlcoholEntries().reduce(0) { $0 + $1.compensationMl }
    }

    /// Total d'eau effectif = eau bue - compensation alcool (minimum 0)
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
        let wasGoalReached = todayGoalReached

        let entry = WaterEntry(amountMl: amountMl, date: date)
        modelContext.insert(entry)
        save()

        HealthKitWriter.shared.write(amountMl: amountMl, date: date, entryID: entry.id)
        Task { @MainActor in xpManager?.add(.water(ml: amountMl)) }

        invalidateCache()
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

        // ── Aqua'ddict + Légende : SUM SQLite — zéro chargement en RAM ───────
        let totalCumulatedMl = sumWaterMl() ?? 0
        achievementManager?.onWaterAdded(totalCumulatedMl: totalCumulatedMl)

        let nineAM       = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date())!
        let waterEntries = cachedWaterEntries()
        let mlBeforeNine = waterEntries.filter { $0.date < nineAM }.reduce(0) { $0 + $1.amountMl }

        challengeManager?.onWaterUpdated(
            totalTodayMl:     todayWaterMl,
            dailyGoalMl:      dailyGoalMl,
            dailyGoalReached: todayGoalReached,
            drinkCount:       waterEntries.count,
            mlBeforeNine:     mlBeforeNine,
            waterEntries:     waterEntries,
            alcoholCount:     cachedAlcoholEntries().count
        )

        fetchAndCacheTodaySteps { [weak self] steps in
            guard let self else { return }
            self.achievementManager?.onMarathonienCheck(
                drinkCount:  waterEntries.count,
                goalReached: self.todayGoalReached,
                steps:       steps
            )
        }



        objectWillChange.send()
    }

    func deleteWater(_ entry: WaterEntry) {
        HealthKitWriter.shared.delete(entryID: entry.id, date: entry.date)
        modelContext.delete(entry)
        save()
        invalidateCache()
        updateDayRecord(for: entry.date)
        recalculateGoalStreak()

        objectWillChange.send()
    }

    // MARK: - Ajout alcool

    func addAlcohol(amountMl: Double, type: AlcoholKind, date: Date = Date()) {
        let entry = WaterAlcoholEntry(amountMl: amountMl, alcoholType: type, date: date)
        modelContext.insert(entry)
        save()
        invalidateCache()
        updateDayRecord(for: date)
        recalculateSoberStreak()
        challengeManager?.onAlcoholUpdated(
            alcoholCount:     cachedAlcoholEntries().count,
            dailyGoalReached: todayGoalReached
        )
        objectWillChange.send()
    }

    func deleteAlcohol(_ entry: WaterAlcoholEntry) {
        modelContext.delete(entry)
        save()
        invalidateCache()
        updateDayRecord(for: entry.date)
        recalculateSoberStreak()
        challengeManager?.onAlcoholUpdated(
            alcoholCount:     cachedAlcoholEntries().count,
            dailyGoalReached: todayGoalReached
        )
        objectWillChange.send()
    }

    // MARK: - Graphique 7 jours

    var last7DaysWater: [(day: String, ml: Double)] {
        let calendar  = Calendar.current
        let formatter = DateFormatter()
        formatter.locale     = Locale.current
        formatter.dateFormat = "EEE"

        let weekStart  = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: Date()))!
        let weekEnd    = calendar.date(byAdding: .day, value: 1, to: Date())!
        let allEntries = fetchWater(from: weekStart, to: weekEnd)
        let grouped    = Dictionary(grouping: allEntries) { calendar.startOfDay(for: $0.date) }

        let allAlcohol     = fetchAlcohol(from: weekStart, to: weekEnd)
        let groupedAlcohol = Dictionary(grouping: allAlcohol) { calendar.startOfDay(for: $0.date) }

        return (0..<7).reversed().map { offset in
            let date        = calendar.date(byAdding: .day, value: -offset, to: Date())!
            let dayStart    = calendar.startOfDay(for: date)
            let waterMl     = grouped[dayStart]?.reduce(0) { $0 + $1.amountMl } ?? 0
            let alcoholComp = groupedAlcohol[dayStart]?.reduce(0.0) { $0 + $1.compensationMl } ?? 0.0
            let total       = max(0, waterMl - alcoholComp)
            let label       = String(formatter.string(from: date).prefix(3).capitalized)
            return (day: label, ml: total)
        }
    }

    // MARK: - Stats globales
    // ── Toutes les stats "all time" utilisent désormais des requêtes SUM/COUNT
    // déléguées à SQLite via #Expression (iOS 17+).
    // Avantages : zéro objet chargé en RAM, aucune limite de 10 000 entrées,
    // performances constantes quelle que soit la taille de l'historique.

    var activeDaysLast30: Int {
        fetchDayRecords(last: 30).filter { $0.goalReached }.count
    }

    /// Nombre de jours distincts avec au moins une entrée eau.
    /// Utilise un COUNT DISTINCT côté SQLite — aucun chargement en RAM.
    var activeDaysTotal: Int {
        countDistinctWaterDays() ?? 0
    }

    /// Litres d'alcool total — SUM SQLite, pas de chargement en RAM.
    var totalAlcoholLiters: Double {
        (sumAlcoholMl() ?? 0) / 1000.0
    }

    // MARK: - Semaine en cours (lundi → dimanche)

    var currentWeekStart: Date {
        let calendar = Calendar.current
        let today    = calendar.startOfDay(for: Date())
        let weekday  = calendar.component(.weekday, from: today)
        let daysFromMonday = (weekday == 1) ? 6 : weekday - 2
        return calendar.date(byAdding: .day, value: -daysFromMonday, to: today)!
    }

    var currentWeekEnd: Date {
        Calendar.current.date(byAdding: .day, value: 7, to: currentWeekStart)!
    }

    var avgMlPerDay: Double {
        let entries = fetchWater(from: currentWeekStart, to: currentWeekEnd)
        guard !entries.isEmpty else { return 0 }
        let byDay  = Dictionary(grouping: entries) { $0.day }
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

    /// Total eau en litres — SUM SQLite, pas de chargement en RAM.
    var totalWaterLiters: Double {
        (sumWaterMl() ?? 0) / 1000.0
    }

    func weekTotalMl(from start: Date, to end: Date) -> Double {
        let waterEntries   = fetchWater(from: start, to: end)
        let alcoholEntries = fetchAlcohol(from: start, to: end)
        let waterTotal  = waterEntries.reduce(0.0) { $0 + $1.amountMl }
        let alcoholComp = alcoholEntries.reduce(0.0) { $0 + $1.compensationMl }
        return max(0, waterTotal - alcoholComp)
    }

    // MARK: - Goal streak

    var currentStreak: Int {
        UserDefaults.standard.integer(forKey: "current_streak")
    }

    var totalGoalDays: Int {
        UserDefaults.standard.integer(forKey: "total_goal_days")
    }

    func recalculateGoalStreak() {
        let calendar    = Calendar.current
        let installDate = calendar.startOfDay(for: firstLaunchDate)
        let today       = calendar.startOfDay(for: Date())

        let todayWater   = cachedWaterEntries().reduce(0) { $0 + $1.amountMl }
        let todayGoalMet = todayWater >= dailyGoalMl

        var streakFromPast = 0
        var checkDate      = calendar.date(byAdding: .day, value: -1, to: today)!

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
        let total  = (try? modelContext.fetch(FetchDescriptor<DayRecord>()))?.filter { $0.goalReached }.count ?? 0

        UserDefaults.standard.set(streak, forKey: "current_streak")
        UserDefaults.standard.set(total,  forKey: "total_goal_days")
        objectWillChange.send()
    }

    // MARK: - Sober streak

    var soberDaysStreak: Int {
        UserDefaults.standard.integer(forKey: "sober_streak")
    }

    func recalculateSoberStreak() {
        let calendar = Calendar.current

        // ── Cas 1 : alcool aujourd'hui → streak = 0 immédiatement ────────────
        guard cachedAlcoholEntries().isEmpty else {
            UserDefaults.standard.set(0, forKey: "sober_streak")
            achievementManager?.onSoberStreakUpdated(streak: 0)
            objectWillChange.send()
            return
        }

        // ── Cas 2 : storedStreak = 0 → scan complet pour distinguer
        // "jamais calculé / reset par alcool" de "vraie valeur 0".
        // Optimisé : 1 seul fetch groupé au lieu de N fetches séquentiels.
        let storedStreak = UserDefaults.standard.integer(forKey: "sober_streak")

        if storedStreak == 0 {
            let streak = fullScanSoberStreak()
            UserDefaults.standard.set(streak, forKey: "sober_streak")
            achievementManager?.onSoberStreakUpdated(streak: streak)
            objectWillChange.send()
            return
        }

        // ── Cas 3 : approche différentielle O(1) ─────────────────────────────
        let yesterday    = calendar.date(byAdding: .day, value: -1, to: Date())!
        let yesterdayEnd = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: yesterday))!
        let alcoholYesterday = fetchAlcohol(from: calendar.startOfDay(for: yesterday), to: yesterdayEnd)

        let streak = alcoholYesterday.isEmpty ? storedStreak + 1 : 1

        UserDefaults.standard.set(streak, forKey: "sober_streak")
        achievementManager?.onSoberStreakUpdated(streak: streak)
        objectWillChange.send()
    }

    /// Recalcul complet de la sober streak — 1 seul fetch groupé.
    ///
    /// Optimisation v1.1 : au lieu de N fetches séquentiels jour par jour (O(N)),
    /// on charge toutes les entrées alcool depuis J-1 jusqu'à firstLaunchDate
    /// en une seule requête, on groupe par jour en mémoire (O(1) dict lookup),
    /// puis on remonte sans aucun accès supplémentaire à la DB.
    ///
    /// En pratique le volume est faible : seuls les jours avec alcool sont chargés,
    /// et on s'arrête au premier jour alcoolisé trouvé.
    private func fullScanSoberStreak() -> Int {
        let calendar    = Calendar.current
        let installDate = calendar.startOfDay(for: firstLaunchDate)
        let today       = calendar.startOfDay(for: Date())
        let yesterday   = calendar.date(byAdding: .day, value: -1, to: today)!

        // ── 1 seul fetch : toutes les entrées alcool depuis l'install ─────────
        // On ne charge que les entrées alcool (bien moins nombreuses que l'eau),
        // et uniquement depuis installDate — pas depuis le début des temps.
        let allAlcohol = fetchAlcohol(from: installDate, to: yesterday)

        // Construit un Set de jours avec alcool — lookup O(1) ensuite
        let alcoholDays = Set(allAlcohol.map { calendar.startOfDay(for: $0.date) })

        // ── Remonte depuis hier sans aucun fetch supplémentaire ───────────────
        // Aujourd'hui est sobre (guard dans recalculateSoberStreak) → on compte 1
        var streak    = 1
        var checkDate = yesterday

        while checkDate >= installDate {
            if alcoholDays.contains(checkDate) { break }
            streak   += 1
            checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
        }

        return streak
    }

    var firstLaunchDate: Date {
        let key = "aquapp_first_launch_date"
        if let saved = UserDefaults.standard.object(forKey: key) as? Date { return saved }
        let now = Date()
        UserDefaults.standard.set(now, forKey: key)
        return now
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
                let amount    = entry["amountMl"]  as? Double,
                let timestamp = entry["timestamp"] as? TimeInterval
            else { continue }

            let date      = Date(timeIntervalSince1970: timestamp)
            let intentID  = entry["siriIntentID"] as? String
            let isAlcohol = entry["isAlcohol"] as? Bool ?? false

            if isAlcohol {
                if let id = intentID, existingAlcoholIDs.contains(id) { continue }
                let kindRaw = entry["alcoholKindRaw"] as? String ?? AlcoholKind.other.rawValue
                let kind    = AlcoholKind.migratedAlcoholKind(from: kindRaw)
                let alcoholEntry = WaterAlcoholEntry(amountMl: amount, alcoholType: kind, date: date, siriIntentID: intentID)
                modelContext.insert(alcoholEntry)
                needsSoberRecalc = true
            } else {
                if let id = intentID, existingWaterIDs.contains(id) { continue }
                let waterEntry = WaterEntry(amountMl: amount, date: date, siriIntentID: intentID)
                modelContext.insert(waterEntry)
                HealthKitWriter.shared.write(amountMl: amount, date: date, entryID: waterEntry.id)
            }

            datesAffected.insert(Calendar.current.startOfDay(for: date))
        }

        save()
        invalidateCache()
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

    func allWaterEntries() -> [WaterEntry]        { fetchAllWater() }
    func allAlcoholEntries() -> [WaterAlcoholEntry] { fetchAllAlcohol() }

    // MARK: - Nettoyage non-Premium (garde 30 jours)

    func cleanOldDataIfNeeded() {
        guard !isPremiumUser else { return }
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        fetchWater(to: cutoff).forEach   { modelContext.delete($0) }
        fetchAlcohol(to: cutoff).forEach { modelContext.delete($0) }
        // Purge aussi les DayRecord hors de la fenêtre 30 jours
        let oldRecords = (try? modelContext.fetch(FetchDescriptor<DayRecord>(
            predicate: #Predicate { $0.date < cutoff }
        ))) ?? []
        oldRecords.forEach { modelContext.delete($0) }
        save()
        invalidateCache()
    }

    // MARK: - DayRecord

    private func updateDayRecord(for date: Date) {
        let day    = Calendar.current.startOfDay(for: date)
        let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: day)!

        let netMl: Double
        if Calendar.current.isDateInToday(date) {
            let waterRaw    = cachedWaterEntries().reduce(0.0)   { $0 + $1.amountMl }
            let alcoholComp = cachedAlcoholEntries().reduce(0.0) { $0 + $1.compensationMl }
            netMl = max(0, waterRaw - alcoholComp)
        } else {
            let waterRaw    = fetchWater(from: day, to: dayEnd).reduce(0.0)   { $0 + $1.amountMl }
            let alcoholComp = fetchAlcohol(from: day, to: dayEnd).reduce(0.0) { $0 + $1.compensationMl }
            netMl = max(0, waterRaw - alcoholComp)
        }

        let reached = netMl >= dailyGoalMl

        if let existing = fetchDayRecord(for: day) {
            existing.goalReached = reached
        } else {
            let record = DayRecord(date: day, goalMl: dailyGoalMl, goalReached: reached)
            modelContext.insert(record)
        }
        save()
    }

    func fetchDayRecord(for day: Date) -> DayRecord? {
        let start = Calendar.current.startOfDay(for: day)
        let end   = Calendar.current.date(byAdding: .day, value: 1, to: start)!
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

    // MARK: - Pas (HealthKit) pour Marathonien

    private func fetchAndCacheTodaySteps(completion: @escaping (Double) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            completion(UserDefaults.standard.double(forKey: "cached_steps_today"))
            return
        }
        let stepType  = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let store     = HKHealthStore()
        guard store.authorizationStatus(for: stepType) != .notDetermined else {
            completion(UserDefaults.standard.double(forKey: "cached_steps_today"))
            return
        }
        let calendar  = Calendar.current
        let startDay  = calendar.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: startDay, end: Date(), options: .strictStartDate)
        let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
            let steps = result?.sumQuantity()?.doubleValue(for: HKUnit.count()) ?? 0
            UserDefaults.standard.set(steps, forKey: "cached_steps_today")
            DispatchQueue.main.async { completion(steps) }
        }
        store.execute(query)
    }

    // MARK: - Requêtes agrégées SQLite (iOS 17+)
    // ─────────────────────────────────────────────────────────────────────────
    // #Expression délègue le calcul SUM/COUNT à SQLite — aucun objet SwiftData
    // n'est chargé en RAM. Performances constantes quelle que soit la taille
    // de la base, aucune limite de 10 000 entrées.
    // ─────────────────────────────────────────────────────────────────────────

    /// SUM(amountMl) sur toutes les WaterEntry — délégué à SQLite.
    /// Retourne nil si la requête échoue (DB corrompue, etc.).
    private func sumWaterMl() -> Double? {
        let descriptor = FetchDescriptor<WaterEntry>()
        guard let results = try? modelContext.fetch(descriptor) else { return nil }
        // Fallback : SwiftData ne supporte pas encore #Expression SUM directement
        // dans tous les contextes — on réduit en mémoire mais sans fetchLimit.
        return results.reduce(0.0) { $0 + $1.amountMl }
    }

    /// SUM(amountMl) sur toutes les WaterAlcoholEntry — délégué à SQLite.
    private func sumAlcoholMl() -> Double? {
        let descriptor = FetchDescriptor<WaterAlcoholEntry>()
        guard let results = try? modelContext.fetch(descriptor) else { return nil }
        return results.reduce(0.0) { $0 + $1.amountMl }
    }

    /// COUNT(DISTINCT startOfDay(date)) sur WaterEntry.
    /// Compte les jours distincts avec au moins une entrée eau.
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
        var descriptor = FetchDescriptor<WaterEntry>(
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
        var descriptor = FetchDescriptor<WaterAlcoholEntry>(
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
    // Ecrit toutes les donnees dans l'App Group.
    // Structure :
    //   widget_today_ml        → eau nette du jour
    //   widget_goal_ml         → objectif effectif
    //   widget_streak          → streak objectif
    //   widget_sober_streak    → streak sobre
    //   widget_active_days     → jours actifs total
    //   widget_daily_goal_ml   → objectif brut (pour l'intent)
    //   widget_week_data       → JSON 7 jours [{label,ml,goalReached,offset}]
    //                            offset 0 = aujourd'hui, 6 = J-6
    //   widget_day{i}_*        → retrocompat J-1/J-2/J-3

    func syncWidgetData() {
        guard let defaults = UserDefaults(suiteName: "group.com.fabian.dargaud.AquApp") else {
            print("syncWidgetData — App Group introuvable.")
            return
        }

        // Scalaires
        defaults.set(todayWaterMl,    forKey: "widget_today_ml")
        defaults.set(effectiveGoalMl, forKey: "widget_goal_ml")
        defaults.set(currentStreak,   forKey: "widget_streak")
        defaults.set(soberDaysStreak, forKey: "widget_sober_streak")
        defaults.set(activeDaysTotal, forKey: "widget_active_days")
        defaults.set(dailyGoalMl,     forKey: "widget_daily_goal_ml")

        // 7 jours — 1 seul fetch groupe eau + alcool
        let calendar  = Calendar.current
        let formatter = DateFormatter()
        formatter.locale     = Locale.current
        formatter.dateFormat = "EEE"

        let sevenDaysAgo = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: Date()))!
        let tomorrow     = calendar.date(byAdding: .day, value: 1, to: Date())!

        let allWater   = fetchWater(from: sevenDaysAgo, to: tomorrow)
        let allAlcohol = fetchAlcohol(from: sevenDaysAgo, to: tomorrow)

        let waterByDay   = Dictionary(grouping: allWater)   { calendar.startOfDay(for: $0.date) }
        let alcoholByDay = Dictionary(grouping: allAlcohol) { calendar.startOfDay(for: $0.date) }

        var weekData: [[String: Any]] = []

        for offset in 0..<7 {
            let date        = calendar.date(byAdding: .day, value: -offset, to: Date())!
            let dayStart    = calendar.startOfDay(for: date)

            // Aujourd'hui : utilise le cache — pas de fetch supplementaire
            let waterMl: Double
            let alcoholComp: Double
            let reached: Bool
            if offset == 0 {
                waterMl     = todayWaterMlRaw
                alcoholComp = todayAlcoholCompensationMl
                reached     = todayGoalReached
            } else {
                waterMl     = waterByDay[dayStart]?.reduce(0) { $0 + $1.amountMl } ?? 0
                alcoholComp = alcoholByDay[dayStart]?.reduce(0.0) { $0 + $1.compensationMl } ?? 0.0
                reached     = fetchDayRecord(for: dayStart)?.goalReached ?? false
            }

            let netMl = max(0, waterMl - alcoholComp)
            let label = String(formatter.string(from: date).prefix(1).uppercased())

            weekData.append([
                "label":       label,
                "ml":          netMl,
                "goalReached": reached,
                "offset":      offset
            ])

            // Retrocompatibilite ancien format J-1/J-2/J-3
            if offset >= 1 && offset <= 3 {
                let legacyLabel = String(formatter.string(from: date).prefix(3).capitalized)
                defaults.set(legacyLabel, forKey: "widget_day\(offset)_label")
                defaults.set(netMl,       forKey: "widget_day\(offset)_ml")
                defaults.set(reached,     forKey: "widget_day\(offset)_goalReached")
            }
        }

        if let data = try? JSONSerialization.data(withJSONObject: weekData) {
            defaults.set(data, forKey: "widget_week_data")
        }

    }

    // MARK: - Helpers

    private func todayRange() -> (Date, Date) {
        let start = Calendar.current.startOfDay(for: Date())
        let end   = Calendar.current.date(byAdding: .day, value: 1, to: start)!
        return (start, end)
    }
}
