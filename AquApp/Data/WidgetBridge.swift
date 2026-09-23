import Foundation

struct WidgetDay {
    let date: Date
    let netMl: Double
    let goalReached: Bool
}

struct WidgetSnapshot {
    let todayMl: Double
    let goalMl: Double
    let dailyGoalMl: Double
    let streak: Int
    let soberStreak: Int
    let activeDays: Int
    /// Offset 0 = aujourd'hui.
    let week: [WidgetDay]
}

struct PendingEntry {
    let amountMl: Double
    let date: Date
    let siriIntentID: String?
    /// `nil` pour une entrée d'eau.
    let alcoholKind: AlcoholKind?
}

/// Échanges avec le widget via les UserDefaults de l'App Group. Les clés sont
/// lues par l'extension : ne pas les renommer.
struct WidgetBridge {
    static let appGroup = "group.com.fabian.dargaud.AquApp"

    private var defaults: UserDefaults? { UserDefaults(suiteName: Self.appGroup) }

    func write(_ snapshot: WidgetSnapshot) {
        guard let defaults else {
            print("WidgetBridge — App Group introuvable.")
            return
        }

        defaults.set(snapshot.todayMl, forKey: "widget_today_ml")
        defaults.set(snapshot.goalMl, forKey: "widget_goal_ml")
        defaults.set(snapshot.streak, forKey: "widget_streak")
        defaults.set(snapshot.soberStreak, forKey: "widget_sober_streak")
        defaults.set(snapshot.activeDays, forKey: "widget_active_days")
        defaults.set(snapshot.dailyGoalMl, forKey: "widget_daily_goal_ml")

        let formatter = StatsCalculator.weekdayFormatter
        var weekData: [[String: Any]] = []

        for (offset, day) in snapshot.week.enumerated() {
            weekData.append([
                "label": String(formatter.string(from: day.date).prefix(1).uppercased()),
                "ml": day.netMl,
                "goalReached": day.goalReached,
                "offset": offset
            ])

            if (1...3).contains(offset) {
                defaults.set(String(formatter.string(from: day.date).prefix(3).capitalized), forKey: "widget_day\(offset)_label")
                defaults.set(day.netMl, forKey: "widget_day\(offset)_ml")
                defaults.set(day.goalReached, forKey: "widget_day\(offset)_goalReached")
            }
        }

        if let data = try? JSONSerialization.data(withJSONObject: weekData) {
            defaults.set(data, forKey: "widget_week_data")
        }
    }

    /// Lit et vide la file d'entrées ajoutées depuis le widget. Les entrées invalides sont ignorées.
    func drainPendingEntries() -> [PendingEntry] {
        guard let defaults,
              let raw = defaults.array(forKey: "widget_pending_entries") as? [[String: Any]],
              !raw.isEmpty
        else { return [] }

        defaults.removeObject(forKey: "widget_pending_entries")

        return raw.compactMap { entry in
            guard let amount = entry["amountMl"] as? Double,
                  let timestamp = entry["timestamp"] as? TimeInterval
            else { return nil }

            guard EntryValidation.isValid(amountMl: amount), EntryValidation.isValid(timestamp: timestamp) else {
                print("⚠️ WidgetBridge — entrée rejetée: amountMl=\(amount), timestamp=\(timestamp)")
                return nil
            }

            let isAlcohol = entry["isAlcohol"] as? Bool ?? false
            let kind = isAlcohol
                ? AlcoholKind.migratedAlcoholKind(from: entry["alcoholKindRaw"] as? String ?? AlcoholKind.other.rawValue)
                : nil

            return PendingEntry(
                amountMl: amount,
                date: Date(timeIntervalSince1970: timestamp),
                siriIntentID: entry["siriIntentID"] as? String,
                alcoholKind: kind
            )
        }
    }
}
