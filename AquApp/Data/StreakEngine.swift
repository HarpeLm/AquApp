import Foundation

/// Séries (objectif et sobriété) et DayRecord. Persiste les valeurs dans
/// HealthDataManager ; les notifications (succès, UI) restent à l'appelant.
@MainActor
final class StreakEngine {
    private let repository: EntryRepository
    private let health = HealthDataManager.shared

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

    /// Eau bue moins la compensation alcool, jamais négative.
    func netWaterMl(on date: Date) -> Double {
        let water: [WaterEntry]
        let alcohol: [WaterAlcoholEntry]
        if Calendar.current.isDateInToday(date) {
            (water, alcohol) = (repository.todayWater(), repository.todayAlcohol())
        } else {
            let (day, dayEnd) = EntryRepository.dayRange(containing: date)
            (water, alcohol) = (repository.water(from: day, to: dayEnd), repository.alcohol(from: day, to: dayEnd))
        }
        return max(0, water.reduce(0.0) { $0 + $1.amountMl } - alcohol.reduce(0.0) { $0 + $1.compensationMl })
    }

    /// Crée ou met à jour le DayRecord du jour de `date`, sans sauvegarder.
    func upsertDayRecord(for date: Date, effectiveGoalMl: Double, dailyGoalMl: Double) {
        let day = Calendar.current.startOfDay(for: date)
        let goalForDay = Calendar.current.isDateInToday(date) ? effectiveGoalMl : dailyGoalMl
        let reached = netWaterMl(on: date) >= goalForDay

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

        // Eau nette, comme todayGoalReached et les DayRecord.
        let todayGoalMet = netWaterMl(on: today) >= effectiveGoalMl

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

    /// Jours consécutifs sans alcool, aujourd'hui inclus (0 si alcool aujourd'hui).
    /// Toujours recalculée depuis les données : idempotente, et supprimer une
    /// entrée d'alcool restaure la série.
    @discardableResult
    func recalculateSoberStreak() -> Int {
        let streak = computeSoberStreak()
        health.setSoberStreak(streak)
        return streak
    }

    private func computeSoberStreak() -> Int {
        guard repository.todayAlcohol().isEmpty else { return 0 }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let installDay = calendar.startOfDay(for: firstLaunchDate)
        let daysSinceInstall = max(0, calendar.dateComponents([.day], from: installDay, to: today).day ?? 0) + 1

        let lastAlcohol = [repository.latestAlcoholDate(before: today), health.prunedAlcoholDate]
            .compactMap { $0 }
            .max()
        guard let lastAlcohol else { return daysSinceInstall }

        let lastAlcoholDay = calendar.startOfDay(for: lastAlcohol)
        let daysSinceAlcohol = calendar.dateComponents([.day], from: lastAlcoholDay, to: today).day ?? 0
        return min(daysSinceAlcohol, daysSinceInstall)
    }

    /// À appeler avant que le nettoyage non-Premium supprime des entrées d'alcool,
    /// pour que la série ne remonte pas au-delà du dernier jour bu.
    func rememberPrunedAlcohol(on date: Date) {
        guard health.prunedAlcoholDate.map({ date > $0 }) ?? true else { return }
        health.setPrunedAlcoholDate(date)
    }
}
