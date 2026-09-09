import SwiftUI
import SwiftData
import StoreKit
import BackgroundTasks

// MARK: - Identifiant BGTask

private let bgRefreshID = "com.fabian.dargaud.AquApp.refresh"

@main
struct AquAppApp: App {

    // MARK: - ModelContainer avec récupération gracieuse

    let container:              ModelContainer
    let containerRecoveryError: Error?

    @StateObject private var store:              AppDataStore
    @StateObject private var resetManager:       DailyResetManager
    @StateObject private var confettiManager:    ConfettiManager
    @StateObject private var achievementManager: AchievementManager
    @StateObject private var challengeManager:   ChallengeManager
    @StateObject private var storeKit:           StoreKitManager
    @StateObject private var weatherManager:     WeatherManager
    @StateObject private var appIconManager:     AppIconManager
    @StateObject private var xpManager:          XPManager

    @Environment(\.scenePhase) private var scenePhase

    @MainActor
    init() {
        // 🧪 Hook tests UI — état déterministe sur demande (launch arguments)
        // -uiTestingFresh  : app vierge, onboarding visible
        // -uiTestingReady  : app vierge, onboarding sauté, arrive sur Home
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-uiTestingFresh") || args.contains("-uiTestingReady") {
            if let bid = Bundle.main.bundleIdentifier {
                UserDefaults.standard.removePersistentDomain(forName: bid)
            }
            UserDefaults(suiteName: "group.com.fabian.dargaud.AquApp")?
                .removePersistentDomain(forName: "group.com.fabian.dargaud.AquApp")
            PremiumManager.shared.set(false)
            HealthDataManager.shared.resetForTests()
            if args.contains("-uiTestingReady") {
                UserDefaults.standard.set(true, forKey: "onboardingCompleted")
                HealthDataManager.shared.setFirstName("Test")
            }
        }

        let schema = Schema([WaterEntry.self, WaterAlcoholEntry.self, DayRecord.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        // Niveau 1 — chemin normal
        if let c = try? ModelContainer(for: schema, configurations: [config]) {
            container              = c
            containerRecoveryError = nil

        } else {
            // Niveau 2 — suppression du WAL puis nouvelle tentative
            let storeURL = config.url
            let walURL   = storeURL.appendingPathExtension("wal")
            let shmURL   = storeURL.appendingPathExtension("shm")
            try? FileManager.default.removeItem(at: walURL)
            try? FileManager.default.removeItem(at: shmURL)

            if let c = try? ModelContainer(for: schema, configurations: [config]) {
                container              = c
                containerRecoveryError = nil
            } else {
                // Niveau 3 — base in-memory, app reste utilisable
                let fallbackConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                container = (try? ModelContainer(for: schema, configurations: [fallbackConfig]))
                    ?? { fatalError("SwiftData ne peut pas créer de container in-memory.") }()

                struct DBRecoveryError: LocalizedError {
                    var errorDescription: String? {
                        "La base de données a dû être réinitialisée suite à une corruption. Vos données précédentes ne sont plus accessibles."
                    }
                }
                containerRecoveryError = DBRecoveryError()
            }
        }

        // Initialisation des managers
        let ctx = container.mainContext
        let s   = AppDataStore(modelContext: ctx)
        let cm  = ConfettiManager()
        let am  = AchievementManager()
        let chm = ChallengeManager()
        let rm  = DailyResetManager(store: s)
        let sk  = StoreKitManager()
        let wm  = WeatherManager(store: s)
        let aim = AppIconManager()
        let xpm = XPManager()

        s.confettiManager    = cm
        s.achievementManager = am
        s.challengeManager   = chm
        s.xpManager          = xpm
        am.confettiManager   = cm
        chm.confettiManager  = cm
        am.xpManager         = xpm
        chm.xpManager        = xpm
        am.isPremiumUser     = PremiumManager.shared.isPremium   // ✅ corrigé (Phase 2)

        s.recalculateAllAchievementsFromHistory()

        _store              = StateObject(wrappedValue: s)
        _resetManager       = StateObject(wrappedValue: rm)
        _confettiManager    = StateObject(wrappedValue: cm)
        _achievementManager = StateObject(wrappedValue: am)
        _challengeManager   = StateObject(wrappedValue: chm)
        _storeKit           = StateObject(wrappedValue: sk)
        _weatherManager     = StateObject(wrappedValue: wm)
        _appIconManager     = StateObject(wrappedValue: aim)
        _xpManager          = StateObject(wrappedValue: xpm)

        HapticManager.shared.prepare()
        HealthKitWriter.shared.requestWriteAuthorizationIfNeeded()

        // Enregistre le handler BGAppRefreshTask.
        // DOIT être appelé avant la fin de application(_:didFinishLaunchingWithOptions:)
        // — ici dans init() qui s'exécute au même moment.
        // Le handler est appelé par iOS quand il réveille l'app en background.
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: bgRefreshID,
            using: nil   // nil = MainActor (DispatchQueue.main)
        ) { task in
            // iOS nous donne 30 secondes max — on traite et on signale la fin.
            guard let refreshTask = task as? BGAppRefreshTask else { return }
            AquAppApp.handleBackgroundRefresh(refreshTask)
        }
    }

    // MARK: - Body

    var body: some Scene {
        WindowGroup {
            ContentView(dbRecoveryError: containerRecoveryError)
                .modelContainer(container)
                .environmentObject(store)
                .environmentObject(confettiManager)
                .environmentObject(achievementManager)
                .environmentObject(challengeManager)
                .environmentObject(storeKit)
                .environmentObject(weatherManager)
                .environmentObject(appIconManager)
                .environmentObject(xpManager)
        }
        .onChange(of: storeKit.isPremiumUser) { _, newValue in
            store.isPremiumUser              = newValue
            achievementManager.isPremiumUser = newValue
            challengeManager.isPremiumUser   = newValue
            if !newValue {
                appIconManager.resetToOceanIfNeeded()
                store.cleanOldDataIfNeeded()
            }
        }
        .onChange(of: weatherManager.adaptedGoalMl) { _, adapted in
            store.heatwaveGoalMl = adapted
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                resetManager.handleForeground()
                store.flushWidgetPendingEntries()
                weatherManager.refresh()
                Task { await storeKit.refreshPurchaseStatus() }
                store.cleanOldDataIfNeeded()
                // Garantit que les widgets sont toujours a jour
                // a chaque retour au premier plan, meme sans action utilisateur.
                store.syncWidgetData()

            case .background:
                // Quand l'app passe en background, on programme le prochain
                // BGAppRefreshTask. iOS le déclenchera au moment le plus opportun
                // (activité réseau, utilisation d'une autre app, etc.)
                scheduleBackgroundRefresh()

            default:
                break
            }
        }
    }

    // MARK: - Programmation du BGAppRefreshTask

    private func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: bgRefreshID)

        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date())!
        let midnight = calendar.startOfDay(for: tomorrow)
        request.earliestBeginDate = midnight

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("⚠️ BGTaskScheduler.submit failed: \(error)")
        }
    }

    // MARK: - Exécution du BGAppRefreshTask

    private static func handleBackgroundRefresh(_ task: BGAppRefreshTask) {
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }

        Task { @MainActor in
            let schema = Schema([WaterEntry.self, WaterAlcoholEntry.self, DayRecord.self])
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

            guard let container = try? ModelContainer(for: schema, configurations: [config]) else {
                task.setTaskCompleted(success: false)
                return
            }

            let bgStore = AppDataStore(modelContext: container.mainContext)

            let calendar  = Calendar.current
            let today     = calendar.startOfDay(for: Date())
            let lastReset = UserDefaults.standard.object(forKey: "last_reset_date") as? Date

            if lastReset == nil || !calendar.isDate(lastReset!, inSameDayAs: today) {
                bgStore.performMidnightReset()
            } else {
                bgStore.recalculateGoalStreak()
                bgStore.recalculateSoberStreak()
                bgStore.syncWidgetData()
            }

            let nextMidnight = calendar.startOfDay(
                for: calendar.date(byAdding: .day, value: 1, to: Date())!
            )
            let nextRequest = BGAppRefreshTaskRequest(identifier: bgRefreshID)
            nextRequest.earliestBeginDate = nextMidnight
            try? BGTaskScheduler.shared.submit(nextRequest)

            task.setTaskCompleted(success: true)
        }
    }
}
