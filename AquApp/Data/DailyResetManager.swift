import Foundation
import UserNotifications
import SwiftUI
import Combine

// MARK: - DailyResetManager

final class DailyResetManager: ObservableObject {

    private var dailyTimer:  Timer?
    private var weeklyTimer: Timer?
    private weak var store: AppDataStore?

    /// Publié quand le Wrapped annuel doit être proposé à l'utilisateur
    /// (1er janvier après une année d'utilisation). ContentView observe
    /// cette valeur pour présenter WrappedView automatiquement.
    @Published var shouldShowWrapped: Bool = false

    init(store: AppDataStore) {
        self.store = store
        scheduleNextDailyReset()
        scheduleNextWeeklyReset()
    }

    deinit {
        dailyTimer?.invalidate()
        weeklyTimer?.invalidate()
    }

    // MARK: - Reset quotidien (minuit)

    func scheduleNextDailyReset() {
        dailyTimer?.invalidate()

        let now          = Date()
        let calendar     = Calendar.current
        let tomorrow     = calendar.date(byAdding: .day, value: 1, to: now)!
        let nextMidnight = calendar.startOfDay(for: tomorrow)
        let delay        = nextMidnight.timeIntervalSince(now)

        dailyTimer = Timer.scheduledTimer(
            withTimeInterval: delay,
            repeats: false
        ) { [weak self] _ in
            self?.performDailyReset()
        }
        if let t = dailyTimer { RunLoop.main.add(t, forMode: .common) }
    }

    private func performDailyReset() {
        guard let store = store else { return }
        Task { @MainActor in
            store.performMidnightReset()
            self.sendMidnightNotification()
            self.checkWrappedTrigger()
            self.scheduleNextDailyReset()
        }
    }

    // MARK: - Reset hebdomadaire (lundi 00h00)

    func scheduleNextWeeklyReset() {
        weeklyTimer?.invalidate()

        let delay = secondsUntilNextMonday()
        guard delay > 0 else { return }

        weeklyTimer = Timer.scheduledTimer(
            withTimeInterval: delay,
            repeats: false
        ) { [weak self] _ in
            self?.performWeeklyReset()
        }
        if let t = weeklyTimer { RunLoop.main.add(t, forMode: .common) }
    }

    private func performWeeklyReset() {
        guard let store = store else { return }
        Task { @MainActor in
            // Force le recalcul des stats hebdomadaires
            store.objectWillChange.send()
            UserDefaults.standard.set(
                Calendar.current.startOfDay(for: Date()),
                forKey: "last_weekly_reset_date"
            )
            self.scheduleNextWeeklyReset()
        }
    }

    /// Calcule les secondes jusqu'au prochain lundi 00h00
    private func secondsUntilNextMonday() -> TimeInterval {
        let calendar = Calendar.current
        let now      = Date()
        let today    = calendar.startOfDay(for: now)
        let weekday  = calendar.component(.weekday, from: today)
        // weekday: 1=dim, 2=lun ... 7=sam
        let daysUntilMonday = (weekday == 2) ? 7 : (9 - weekday) % 7
        let nextMonday = calendar.date(byAdding: .day, value: daysUntilMonday, to: today)!
        return nextMonday.timeIntervalSince(now)
    }

    // MARK: - Notification minuit

    private func sendMidnightNotification() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else { return }
            let content   = UNMutableNotificationContent()
            content.title = L10n.notifReminderTitle
            content.body  = L10n.notifMidnightBody
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            let request = UNNotificationRequest(
                identifier: "aquapp_midnight_reset",
                content: content,
                trigger: trigger
            )
            UNUserNotificationCenter.current().add(request)
        }
    }

    // MARK: - AquApp Wrapped — déclenchement automatique
    //
    // Le Wrapped est proposé automatiquement le 1er janvier (lendemain du
    // 31 décembre à minuit), une seule fois par année, et seulement si
    // l'utilisateur a au moins quelques jours de données pour que le bilan
    // soit pertinent. Le flag "wrapped_shown_<year>" évite toute répétition.
    //
    // Désactivé en v1.0 : aucun écran ne présente encore WrappedView. Tant que
    // c'est le cas, le déclencheur ne doit PAS consommer "wrapped_shown_<year>",
    // sinon le bilan serait perdu pour ces utilisateurs une fois l'écran branché.
    // Pour l'activer : présenter WrappedView sur shouldShowWrapped, puis passer à true.
    static let isWrappedEnabled = false

    private func checkWrappedTrigger() {
        guard Self.isWrappedEnabled else { return }
        let calendar = Calendar.current
        let now       = Date()
        let month     = calendar.component(.month, from: now)
        let day       = calendar.component(.day, from: now)
        let yearJustEnded = calendar.component(.year, from: now) - 1

        // Se déclenche le 1er janvier (le jour suivant le 31 décembre minuit)
        guard month == 1, day == 1 else { return }

        let shownKey = "wrapped_shown_\(yearJustEnded)"
        guard !UserDefaults.standard.bool(forKey: shownKey) else { return }

        // Vérifie qu'il y a suffisamment de données pour un bilan pertinent
        guard let store = store, store.activeDaysTotal >= 7 else { return }

        UserDefaults.standard.set(true, forKey: shownKey)
        DispatchQueue.main.async {
            self.shouldShowWrapped = true
        }
    }

    /// Vérifie au lancement (handleForeground) si le Wrapped de l'année
    /// précédente n'a pas encore été montré — couvre le cas où l'app était
    /// fermée le 1er janvier.
    private func checkWrappedTriggerOnLaunch() {
        guard Self.isWrappedEnabled else { return }
        let calendar = Calendar.current
        let now      = Date()
        let currentYear = calendar.component(.year, from: now)
        let yearToCheck = currentYear - 1

        // Rattrapage limité à janvier : le bilan de l'année écoulée n'a plus de sens
        // en milieu d'année (l'ancienne condition currentYear > yearToCheck était toujours vraie).
        guard calendar.component(.month, from: now) == 1 else { return }

        let shownKey = "wrapped_shown_\(yearToCheck)"
        guard !UserDefaults.standard.bool(forKey: shownKey) else { return }
        guard let store = store, store.activeDaysTotal >= 7 else { return }

        UserDefaults.standard.set(true, forKey: shownKey)
        DispatchQueue.main.async {
            self.shouldShowWrapped = true
        }
    }

    // MARK: - Reprise depuis le background

    func handleForeground() {
        guard let store = store else { return }
        let calendar = Calendar.current
        let today    = calendar.startOfDay(for: Date())

        // Reset quotidien manqué
        let lastDaily = UserDefaults.standard.object(forKey: "last_reset_date") as? Date
        if lastDaily == nil || !calendar.isDate(lastDaily!, inSameDayAs: today) {
            Task { @MainActor in
                store.performMidnightReset()
            }
        }

        // Reset hebdomadaire manqué — vérifie si on est lundi et si le reset n'a pas encore été fait
        let lastWeekly  = UserDefaults.standard.object(forKey: "last_weekly_reset_date") as? Date
        let weekday     = calendar.component(.weekday, from: today)
        let isMonday    = weekday == 2
        let alreadyDone = lastWeekly != nil && calendar.isDate(lastWeekly!, inSameDayAs: today)

        if isMonday && !alreadyDone {
            Task { @MainActor in
                store.objectWillChange.send()
                UserDefaults.standard.set(today, forKey: "last_weekly_reset_date")
            }
        }

        // Vérifie si le Wrapped de l'année précédente doit être proposé
        // (couvre le cas où l'app était fermée exactement le 1er janvier)
        checkWrappedTriggerOnLaunch()

        scheduleNextDailyReset()
        scheduleNextWeeklyReset()
    }
}
