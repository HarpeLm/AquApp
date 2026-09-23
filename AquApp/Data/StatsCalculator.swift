import Foundation

struct DailyTotal {
    let date: Date
    let dayStart: Date
    let waterMl: Double
    let alcoholCompensationMl: Double
    var netMl: Double { max(0, waterMl - alcoholCompensationMl) }
}

/// Statistiques en lecture seule, calculées à partir du repository.
@MainActor
struct StatsCalculator {
    let repository: EntryRepository

    static let weekdayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale.current
        f.dateFormat = "EEE"
        return f
    }()

    // MARK: - Totaux journaliers

    /// Du plus récent (offset 0 = aujourd'hui) au plus ancien.
    func dailyTotals(lastDays count: Int) -> [DailyTotal] {
        let calendar = Calendar.current
        let start = calendar.date(byAdding: .day, value: -(count - 1), to: calendar.startOfDay(for: Date()))!
        let end = calendar.date(byAdding: .day, value: 1, to: Date())!

        let waterByDay = Dictionary(grouping: repository.water(from: start, to: end)) { calendar.startOfDay(for: $0.date) }
        let alcoholByDay = Dictionary(grouping: repository.alcohol(from: start, to: end)) { calendar.startOfDay(for: $0.date) }

        return (0..<count).map { offset in
            let date = calendar.date(byAdding: .day, value: -offset, to: Date())!
            let dayStart = calendar.startOfDay(for: date)
            return DailyTotal(
                date: date,
                dayStart: dayStart,
                waterMl: waterByDay[dayStart]?.reduce(0) { $0 + $1.amountMl } ?? 0,
                alcoholCompensationMl: alcoholByDay[dayStart]?.reduce(0) { $0 + $1.compensationMl } ?? 0
            )
        }
    }

    var last7DaysWater: [(day: String, ml: Double)] {
        dailyTotals(lastDays: 7).reversed().map { total in
            let label = String(Self.weekdayFormatter.string(from: total.date).prefix(3).capitalized)
            return (day: label, ml: total.netMl)
        }
    }

    // MARK: - Jours actifs

    var activeDaysLast30: Int {
        let start = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        return repository.dayRecords(since: start).filter { $0.goalReached }.count
    }

    var activeDaysTotal: Int {
        repository.distinctWaterDayCount()
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

    func weekTotalMl(from start: Date, to end: Date) -> Double {
        let waterTotal = repository.water(from: start, to: end).reduce(0.0) { $0 + $1.amountMl }
        let alcoholComp = repository.alcohol(from: start, to: end).reduce(0.0) { $0 + $1.compensationMl }
        return max(0, waterTotal - alcoholComp)
    }

    // MARK: - Grille de contributions

    func contributionRatios(days: Int, todayProgress: Double, effectiveGoalMl: Double, dailyGoalMl: Double) -> [Date: Double] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let start = calendar.date(byAdding: .day, value: -(days - 1), to: today)!
        let end = calendar.date(byAdding: .day, value: 1, to: today)!

        // Uniquement la fenêtre affichée : le coût ne dépend plus de l'ancienneté de l'historique.
        let waterByDay = repository.waterMlByDay(from: start, to: end)
        var alcoholCompByDay: [Date: Double] = [:]
        for entry in repository.alcohol(from: start, to: end) {
            alcoholCompByDay[calendar.startOfDay(for: entry.date), default: 0] += entry.compensationMl
        }
        var recordByDay: [Date: DayRecord] = [:]
        for record in repository.dayRecords(since: start) {
            recordByDay[calendar.startOfDay(for: record.date)] = record
        }

        var result: [Date: Double] = [:]
        for day in Set(waterByDay.keys).union(recordByDay.keys) where day <= today {
            let record = recordByDay[day]
            let goal = record?.goalMl ?? (calendar.isDateInToday(day) ? effectiveGoalMl : dailyGoalMl)
            guard goal > 0 else { continue }
            guard let water = waterByDay[day] else {
                if record?.goalReached == true { result[day] = 1.0 }
                continue
            }
            result[day] = max(0, water - (alcoholCompByDay[day] ?? 0)) / goal
        }

        result[today] = todayProgress
        return result
    }
}
