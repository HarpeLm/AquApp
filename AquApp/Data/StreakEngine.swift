import Foundation

/// Séries (objectif et sobriété) et DayRecord. Persiste les valeurs dans
/// HealthDataManager ; les notifications (succès, UI) restent à l'appelant.
@MainActor
final class StreakEngine {
    private let repository: EntryRepository
    private let health = HealthDataManager.shared

    static let lastSoberRecalcKey = "last_sober_recalc"

    init(repository: EntryRepository) {
        self.repository = repository
    }

    var firstLaunchDate: Date {
        let date = health.firstLaunchDate
        if date == Date(timeIntervalSince1970: 0) {
            let now = Date()
            health.setFirstLaunchDate(now)
            return now
        }
        return date
    }

    // MARK: - DayRecord

    /// Crée ou met à jour le DayRecord du jour de `date`, sans sauvegarder.
    func upsertDayRecord(for date: Date, effectiveGoalMl: Double, dailyGoalMl: Double) {
        let isToday = Calendar.current.isDateInToday(date)
        let (day, dayEnd) = EntryRepository.dayRange(containing: date)

        let water = isToday ? repository.todayWater() : repository.water(from: day, to: dayEnd)
        let alcohol = isToday ? repository.todayAlcohol() : repository.alcohol(from: day, to: dayEnd)
        let netMl = max(0, water.reduce(0.0) { $0 + $1.amountMl } - alcohol.reduce(0.0) { $0 + $1.compensationMl })

        let goalForDay = isToday ? effectiveGoalMl : dailyGoalMl
        let reached = netMl >= goalForDay

        if let existing = repository.dayRecord(for: day) {
            existing.goalReached = reached
            existing.goalMl = goalForDay
        } else {
            repository.insert(DayRecord(date: day, goalMl: goalForDay, goalReached: reached))
        }
    }

    // MARK: - Série d'objectif

    func recalculateGoalStreak(effectiveGoalMl: Double) {
        let calendar = Calendar.current
        let installDate = calendar.startOfDay(for: firstLaunchDate)
        let today = calendar.startOfDay(for: Date())

        let todayWater = repository.todayWater().reduce(0) { $0 + $1.amountMl }
        let todayGoalMet = todayWater >= effectiveGoalMl

        var streakFromPast = 0
        var checkDate = calendar.date(byAdding: .day, value: -1, to: today)!
        while checkDate >= installDate {
            guard let record = repository.dayRecord(for: checkDate), record.goalReached else { break }
            streakFromPast += 1
            checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
        }

        let streak = todayGoalMet ? streakFromPast + 1 : streakFromPast
        let total = repository.allDayRecords().filter { $0.goalReached }.count

        health.setCurrentStreak(streak)
        health.setTotalGoalDays(total)
    }

    // MARK: - Série sobre

    /// Nouvelle valeur de la série, ou `nil` si rien n'a changé (déjà recalculée aujourd'hui).
    func recalculateSoberStreak() -> Int? {
        let calendar = Calendar.current

        guard repository.todayAlcohol().isEmpty else {
            health.setSoberStreak(0)
            return 0
        }

        let today = calendar.startOfDay(for: Date())
        if let lastRecalc = UserDefaults.standard.object(forKey: Self.lastSoberRecalcKey) as? Date,
           calendar.isDate(lastRecalc, inSameDayAs: today) {
            return nil
        }

        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let alcoholYesterday = repository.alcohol(from: yesterday, to: today)
        let streak = alcoholYesterday.isEmpty ? health.soberStreak + 1 : 1

        health.setSoberStreak(streak)
        UserDefaults.standard.set(today, forKey: Self.lastSoberRecalcKey)
        return streak
    }

    /// Recalcul complet depuis l'historique, utilisé au lancement.
    func soberStreakAtLaunch() -> Int {
        let streak = repository.todayAlcohol().isEmpty ? fullScanSoberStreak() : 0
        health.setSoberStreak(streak)
        return streak
    }

    private func fullScanSoberStreak() -> Int {
        let calendar = Calendar.current
        let installDate = calendar.startOfDay(for: firstLaunchDate)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: Date()))!

        let alcoholDays = Set(repository.alcohol(from: installDate, to: yesterday).map { calendar.startOfDay(for: $0.date) })

        var streak = 1
        var checkDate = yesterday
        while checkDate >= installDate {
            if alcoholDays.contains(checkDate) { break }
            streak += 1
            checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
        }
        return streak
    }
}
