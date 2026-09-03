import SwiftUI
import HealthKit
import Combine

// MARK: - Achievement Model

struct Achievement: Identifiable {
    let id: String
    let sfSymbol: String
    let symbolColor: Color
    let title: String
    let description: String
    let isPro: Bool
    let targetProgress: Double

    var status: ChallengeStatus = .available
    var currentProgress: Double = 0

    var progressRatio: Double {
        guard targetProgress > 0 else { return 0 }
        let ratio = currentProgress / targetProgress
        guard ratio.isFinite else { return 0 }
        return min(max(ratio, 0), 1.0)
    }

    var progressLabel: String {
        switch id {
        case "constance", "semaine_sobre", "perfect_week":
            return String(format: String(localized: "achievement.progress_days"), Int(currentProgress), Int(targetProgress))
        case "heatwave":
            return String(format: String(localized: "achievement.progress_heatwave"), Int(currentProgress))
        case "sleep_hydrated":
            return String(format: String(localized: "achievement.progress_nights"), Int(currentProgress))
        case "iron_month":
            return String(format: String(localized: "achievement.progress_days"), Int(currentProgress), 30)
        case "centurion":
            return String(format: String(localized: "achievement.progress_days"), Int(currentProgress), 100)
        case "dry_january", "sober_october", "no_alcohol_november":
            return String(format: String(localized: "achievement.progress_days"), Int(currentProgress), Int(targetProgress))
        case "centurion_sobre":
            return String(format: String(localized: "achievement.progress_sober_days"), Int(currentProgress), 100)
        case "indestructible":
            return String(format: String(localized: "achievement.progress_days"), Int(currentProgress), 60)
        case "marathonien":
            return String(format: String(localized: "achievement.marathonien.progress"), Int(currentProgress))
        case "summer_hydration":
            return String(format: String(localized: "achievement.progress_days"), Int(currentProgress), 7)
        case "legende":
            guard currentProgress.isFinite, currentProgress >= 0 else { return "" }
            let current = min(Int(currentProgress / 1000), 1_000_000)
            return String(format: String(localized: "achievement.progress_liters"), current, "1 000 000")
        case "aqua_addict":
            guard currentProgress.isFinite, currentProgress >= 0 else { return "" }
            let current = min(Int(currentProgress / 1000), 1_000_000)
            return "\(current) / 1 000 000 L"
        default:
            return ""
        }
    }
}

// MARK: - AchievementManager

final class AchievementManager: ObservableObject {

    @Published var achievements: [Achievement] = []
    @Published var monthlyAchievements: [Achievement] = []

    weak var confettiManager: ConfettiManager?
    weak var xpManager: XPManager?

    var isPremiumUser: Bool = UserDefaults.standard.bool(forKey: "isPremiumUser") {
        didSet {
            guard oldValue != isPremiumUser else { return }
            UserDefaults.standard.set(isPremiumUser, forKey: "isPremiumUser")
            updateProStatus()
        }
    }

    private let healthStore = HKHealthStore()
    private let defaults = UserDefaults.standard

    init() {
        loadAchievements()
        loadMonthlyAchievements()
        restoreProgress()
        updateProStatus()
        checkSleepHydration()
    }

    // MARK: - Chargement succès standards

    private func loadAchievements() {
        achievements = [
            Achievement(
                id: "constance", sfSymbol: "checkmark.seal.fill", symbolColor: Color.blue,
                title: String(localized: "achievement.constance.title"),
                description: String(localized: "achievement.constance.desc"),
                isPro: false, targetProgress: 7
            ),
            Achievement(
                id: "semaine_sobre", sfSymbol: "moon.stars.fill", symbolColor: Color.purple,
                title: String(localized: "achievement.semaine_sobre.title"),
                description: String(localized: "achievement.semaine_sobre.desc"),
                isPro: false, targetProgress: 7
            ),
            Achievement(
                id: "sleep_hydrated", sfSymbol: "moon.zzz.fill", symbolColor: Color.indigo,
                title: String(localized: "achievement.sleep_hydrated.title"),
                description: String(localized: "achievement.sleep_hydrated.desc"),
                isPro: false, targetProgress: 5
            ),
            Achievement(
                id: "heatwave", sfSymbol: "thermometer.sun.fill", symbolColor: Color.red,
                title: String(localized: "achievement.heatwave.title"),
                description: String(localized: "achievement.heatwave.desc"),
                isPro: false, targetProgress: 3
            ),
            Achievement(
                id: "perfect_week", sfSymbol: "star.fill", symbolColor: Color.yellow,
                title: String(localized: "achievement.perfect_week.title"),
                description: String(localized: "achievement.perfect_week.desc"),
                isPro: false, targetProgress: 7
            ),
            Achievement(
                id: "marathonien", sfSymbol: "figure.run", symbolColor: Color(hex: "10B981"),
                title: String(localized: "achievement.marathonien.title"),
                description: String(localized: "achievement.marathonien.desc"),
                isPro: false, targetProgress: 3
            ),
            Achievement(
                id: "indestructible", sfSymbol: "bolt.shield.fill", symbolColor: Color(hex: "2B87E8"),
                title: String(localized: "achievement.indestructible.title"),
                description: String(localized: "achievement.indestructible.desc"),
                isPro: false, targetProgress: 60
            ),
            Achievement(
                id: "centurion_sobre", sfSymbol: "drop.triangle.fill", symbolColor: Color.purple,
                title: String(localized: "achievement.centurion_sobre.title"),
                description: String(localized: "achievement.centurion_sobre.desc"),
                isPro: false, targetProgress: 100
            ),
            Achievement(
                id: "legende", sfSymbol: "crown.fill", symbolColor: Color(hex: "F59E0B"),
                title: String(localized: "achievement.legende.title"),
                description: String(localized: "achievement.legende.desc"),
                isPro: false, targetProgress: 1_000_000
            ),
            Achievement(
                id: "aqua_addict", sfSymbol: "drop.fill", symbolColor: Color(hex: "4DA8F5"),
                title: String(localized: "achievement.aqua_addict.title"),
                description: String(localized: "achievement.aqua_addict.desc"),
                isPro: false, targetProgress: 1_000_000_000
            ),
            Achievement(
                id: "iron_month", sfSymbol: "flame.fill", symbolColor: Color.orange,
                title: String(localized: "achievement.iron_month.title"),
                description: String(localized: "achievement.iron_month.desc"),
                isPro: true, targetProgress: 30
            ),
            Achievement(
                id: "centurion", sfSymbol: "shield.fill", symbolColor: Color.indigo,
                title: String(localized: "achievement.centurion.title"),
                description: String(localized: "achievement.centurion.desc"),
                isPro: true, targetProgress: 100
            ),
        ]
    }

    // MARK: - Chargement succès mensuels

    func loadMonthlyAchievements() {
        let list: [Achievement] = [
            Achievement(
                id: "dry_january", sfSymbol: "snowflake", symbolColor: Color(hex: "4DA8F5"),
                title: String(localized: "achievement.dry_january.title"),
                description: String(localized: "achievement.dry_january.desc"),
                isPro: false, targetProgress: 31
            ),
            Achievement(
                id: "sober_october", sfSymbol: "leaf.fill", symbolColor: Color(hex: "F97316"),
                title: String(localized: "achievement.sober_october.title"),
                description: String(localized: "achievement.sober_october.desc"),
                isPro: false, targetProgress: 31
            ),
            Achievement(
                id: "no_alcohol_november", sfSymbol: "nosign", symbolColor: Color(hex: "8B5CF6"),
                title: String(localized: "achievement.no_alcohol_november.title"),
                description: String(localized: "achievement.no_alcohol_november.desc"),
                isPro: false, targetProgress: 30
            ),
            Achievement(
                id: "summer_hydration", sfSymbol: "sun.max.fill", symbolColor: Color(hex: "F59E0B"),
                title: String(localized: "achievement.summer_hydration.title"),
                description: String(localized: "achievement.summer_hydration.desc"),
                isPro: false, targetProgress: 7
            ),
        ]
        monthlyAchievements = list.map { ach in
            var a = ach
            let progress = defaults.double(forKey: "ach_progress_\(a.id)")
            let done = defaults.bool(forKey: "ach_completed_\(a.id)")
            a.currentProgress = progress
            if done { a.status = .completed }
            else if progress > 0 { a.status = .inProgress }
            return a
        }
    }

    // MARK: - API publique

    func onGoalReached(streak: Int, totalDays: Int) {
        updateProgress(id: "constance", value: Double(streak))
        updateProgress(id: "perfect_week", value: Double(streak))
        updateProgress(id: "iron_month", value: Double(streak))
        updateProgress(id: "indestructible", value: Double(streak))
        updateProgress(id: "centurion", value: Double(totalDays))

        if streak >= 7 {
            completeAchievement(id: "constance")
            completeAchievement(id: "perfect_week")
        }
        if streak >= 30 { completeAchievement(id: "iron_month") }
        if streak >= 60 { completeAchievement(id: "indestructible") }
        if totalDays >= 100 { completeAchievement(id: "centurion") }
    }

    func onSoberStreakUpdated(streak: Int) {
        updateProgress(id: "semaine_sobre", value: Double(streak))
        if streak >= 7 { completeAchievement(id: "semaine_sobre") }

        if streak > 0 {
            let soberTotal = defaults.double(forKey: "sober_days_total") + 1
            defaults.set(soberTotal, forKey: "sober_days_total")
            updateProgress(id: "centurion_sobre", value: min(soberTotal, 100))
            if soberTotal >= 100 { completeAchievement(id: "centurion_sobre") }
        }

        let month = Calendar.current.component(.month, from: Date())
        if month == 1 {
            updateProgress(id: "dry_january", value: min(Double(streak), 31))
            if streak >= 31 { completeAchievement(id: "dry_january") }
        }
        if month == 10 {
            updateProgress(id: "sober_october", value: min(Double(streak), 31))
            if streak >= 31 { completeAchievement(id: "sober_october") }
        }
        if month == 11 {
            updateProgress(id: "no_alcohol_november", value: min(Double(streak), 30))
            if streak >= 30 { completeAchievement(id: "no_alcohol_november") }
        }
    }

    func onHeatwaveDay(totalMl: Double) {
        guard totalMl.isFinite else { return }
        if totalMl >= 3000 {
            let days = defaults.double(forKey: "heatwave_days") + 1
            defaults.set(days, forKey: "heatwave_days")
            updateProgress(id: "heatwave", value: min(days, 3))
            if days >= 3 {
                DispatchQueue.main.async { [weak self] in
                    self?.completeAchievement(id: "heatwave")
                }
            }
        }
    }

    func onWaterAdded(totalCumulatedMl: Double) {
        // Protection contre les valeurs NaN/Infinity ou négatives
        guard totalCumulatedMl.isFinite, totalCumulatedMl >= 0 else {
            print("⚠️ Valeur invalide pour totalCumulatedMl: \(totalCumulatedMl)")
            return
        }

        updateProgress(id: "legende", value: min(totalCumulatedMl, 1_000_000))
        if totalCumulatedMl >= 1_000_000 { completeAchievement(id: "legende") }

        updateProgress(id: "aqua_addict", value: min(totalCumulatedMl, 1_000_000_000))
        if totalCumulatedMl >= 1_000_000_000 { completeAchievement(id: "aqua_addict") }
    }

    func onDailyGoalReached(totalMl: Double, goalMl: Double) {
        let month = Calendar.current.component(.month, from: Date())
        guard month == 7 || month == 8, goalMl > 0, totalMl >= goalMl * 1.5 else { return }
        let year = Calendar.current.component(.year, from: Date())
        let key = "summer_hydration_days_\(year)"
        let count = defaults.double(forKey: key) + 1
        defaults.set(count, forKey: key)
        updateProgress(id: "summer_hydration", value: min(count, 7))
        if count >= 7 { completeAchievement(id: "summer_hydration") }
    }

    func onMarathonienCheck(drinkCount: Int, goalReached: Bool, steps: Double) {
        let c1 = drinkCount >= 5
        let c2 = goalReached
        let c3 = steps >= 8000
        let count = [c1, c2, c3].filter { $0 }.count
        updateProgress(id: "marathonien", value: Double(count))
        if c1 && c2 && c3 { completeAchievement(id: "marathonien") }
    }

    func restoreHeatwaveProgress(days: Double) {
        guard days.isFinite && days >= 0 else {
            print("⚠️ Valeur invalide pour heatwave_days: \(days)")
            return
        }
        let safeDays = min(days, 3)
        updateProgress(id: "heatwave", value: safeDays)
        if safeDays >= 3 {
            DispatchQueue.main.async { [weak self] in
                self?.completeAchievement(id: "heatwave")
            }
        }
    }

    // MARK: - Sleep Hydration (HealthKit)

    func checkSleepHydration() {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("⚠️ HealthKit non disponible")
            return
        }

        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis),
              let waterType = HKQuantityType.quantityType(forIdentifier: .dietaryWater) else {
            print("⚠️ Types HealthKit non disponibles")
            return
        }

        let sleepAuth = healthStore.authorizationStatus(for: sleepType)
        let waterAuth = healthStore.authorizationStatus(for: waterType)

        if sleepAuth == .notDetermined || waterAuth == .notDetermined {
            requestHealthKitAndThenCheck()
        } else if sleepAuth == .sharingAuthorized || waterAuth == .sharingAuthorized {
            performSleepHydrationCheck()
        }
    }

    private func requestHealthKitAndThenCheck() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis),
              let waterType = HKQuantityType.quantityType(forIdentifier: .dietaryWater),
              let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return }

        healthStore.requestAuthorization(toShare: [], read: [sleepType, waterType, stepType]) { [weak self] granted, error in
            guard let self = self, granted, error == nil else {
                if let error = error {
                    print("⚠️ Erreur HealthKit: \(error.localizedDescription)")
                }
                return
            }
            DispatchQueue.main.async {
                self.performSleepHydrationCheck()
            }
        }
    }

    private func performSleepHydrationCheck() {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis),
              let waterType = HKQuantityType.quantityType(forIdentifier: .dietaryWater) else { return }

        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        let predicate = HKQuery.predicateForSamples(withStart: sevenDaysAgo, end: Date())

        guard healthStore.authorizationStatus(for: sleepType) == .sharingAuthorized else { return }

        let sleepQuery = HKSampleQuery(
            sampleType: sleepType,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
        ) { [weak self] _, samples, error in
            guard let self = self else { return }

            if let error = error {
                print("⚠️ Erreur SleepHydration: \(error.localizedDescription)")
                return
            }

            guard let sleepSamples = samples as? [HKCategorySample] else { return }

            let sleepStarts = sleepSamples
                .filter {
                    $0.value == HKCategoryValueSleepAnalysis.inBed.rawValue ||
                    $0.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
                }
                .map { $0.startDate }

            guard !sleepStarts.isEmpty else { return }
            guard self.healthStore.authorizationStatus(for: waterType) == .sharingAuthorized else { return }

            let group = DispatchGroup()
            let countQueue = DispatchQueue(label: "aquapp.sleepHydration.count")
            var hydratedNights = 0

            for sleepStart in sleepStarts.prefix(7) {
                group.enter()
                let windowStart = Calendar.current.date(byAdding: .hour, value: -2, to: sleepStart)!
                let windowPred = HKQuery.predicateForSamples(withStart: windowStart, end: sleepStart)

                let waterQuery = HKStatisticsQuery(
                    quantityType: waterType,
                    quantitySamplePredicate: windowPred,
                    options: .cumulativeSum
                ) { _, result, error in
                    if let error = error {
                        print("⚠️ Erreur WaterQuery: \(error.localizedDescription)")
                    }
                    let ml = result?.sumQuantity()?.doubleValue(for: .literUnit(with: .milli)) ?? 0
                    if ml >= 150 {
                        countQueue.sync { hydratedNights += 1 }
                    }
                    group.leave()
                }
                self.healthStore.execute(waterQuery)
            }

            group.notify(queue: .main) { [weak self] in
                guard let self = self else { return }
                let nights = min(hydratedNights, 5)
                self.updateProgress(id: "sleep_hydrated", value: Double(nights))
                if nights >= 5 {
                    self.completeAchievement(id: "sleep_hydrated")
                }
            }
        }
        healthStore.execute(sleepQuery)
    }

    // MARK: - Statut Premium

    func updateProStatus() {
        for i in achievements.indices {
            guard achievements[i].isPro else { continue }
            if isPremiumUser {
                if achievements[i].status == .locked {
                    let p = defaults.double(forKey: "ach_progress_\(achievements[i].id)")
                    let c = defaults.bool(forKey: "ach_completed_\(achievements[i].id)")
                    if c {
                        achievements[i].status = .completed
                        achievements[i].currentProgress = achievements[i].targetProgress
                    } else if p > 0 {
                        achievements[i].status = .inProgress
                        achievements[i].currentProgress = p
                    } else {
                        achievements[i].status = .available
                    }
                }
            } else {
                achievements[i].status = .locked
            }
        }
    }

    // MARK: - Persistence

    private func saveProgress() {
        for a in achievements + monthlyAchievements {
            defaults.set(a.currentProgress, forKey: "ach_progress_\(a.id)")
            defaults.set(a.status == .completed, forKey: "ach_completed_\(a.id)")
        }
    }

    private func restoreProgress() {
        for i in achievements.indices {
            let id = achievements[i].id
            let progress = defaults.double(forKey: "ach_progress_\(id)")
            let done = defaults.bool(forKey: "ach_completed_\(id)")
            achievements[i].currentProgress = progress
            if done {
                achievements[i].status = .completed
            } else if progress > 0 {
                achievements[i].status = .inProgress
            }
        }
    }

    private func updateProgress(id: String, value: Double) {
        guard value.isFinite else { return }

        if let idx = achievements.firstIndex(where: { $0.id == id }) {
            guard achievements[idx].status != .locked && achievements[idx].status != .completed else { return }
            achievements[idx].currentProgress = value
            if achievements[idx].status == .available {
                achievements[idx].status = .inProgress
            }
            saveProgress()
        } else if let idx = monthlyAchievements.firstIndex(where: { $0.id == id }) {
            guard monthlyAchievements[idx].status != .completed else { return }
            monthlyAchievements[idx].currentProgress = value
            if monthlyAchievements[idx].status == .available {
                monthlyAchievements[idx].status = .inProgress
            }
            saveProgress()
        }
    }

    private func completeAchievement(id: String) {
        var title: String?
        var isMonthly = false

        if let idx = achievements.firstIndex(where: { $0.id == id }) {
            guard achievements[idx].status != .locked && achievements[idx].status != .completed else { return }
            achievements[idx].status = .completed
            achievements[idx].currentProgress = achievements[idx].targetProgress
            title = achievements[idx].title
        } else if let idx = monthlyAchievements.firstIndex(where: { $0.id == id }) {
            guard monthlyAchievements[idx].status != .completed else { return }
            monthlyAchievements[idx].status = .completed
            monthlyAchievements[idx].currentProgress = monthlyAchievements[idx].targetProgress
            title = monthlyAchievements[idx].title
            isMonthly = true
        }

        guard let t = title else { return }
        saveProgress()

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            HapticManager.shared.achievementUnlocked()

            if let confettiManager = self.confettiManager {
                confettiManager.trigger(.achievementUnlocked(title: t))
            }

            Task { @MainActor in
                self.xpManager?.add(.achievement)
            }
        }
    }
}

// MARK: - AchievementsView

struct AchievementsView: View {

    @EnvironmentObject var manager: AchievementManager
    @EnvironmentObject var confettiManager: ConfettiManager
    @EnvironmentObject var storeKit: StoreKitManager
    @AppStorage("isPremiumUser") private var isPremiumUser: Bool = false
    @Environment(\.colorScheme) private var colorScheme

    @State private var showPremiumSheet = false

    var scrollToTopID: UUID = UUID()

    init(scrollToTopID: UUID = UUID()) {
        self.scrollToTopID = scrollToTopID
    }

    var allForCount: [Achievement] { manager.achievements + manager.monthlyAchievements }
    var completedCount: Int { allForCount.filter { $0.status == .completed }.count }
    var totalCount: Int { allForCount.count }

    var legendaryAchievement: Achievement? {
        manager.achievements.first { $0.id == "aqua_addict" }
    }
    var regularAchievements: [Achievement] {
        manager.achievements.filter { $0.id != "aqua_addict" }
    }

    let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        Color.clear.frame(height: 0).id("top")

                        // Header
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L10n.achievementsTitle)
                                .font(.system(size: 32, weight: .bold))
                            Text(L10n.achievementsSub)
                                .font(.subheadline)
                                .foregroundColor(Color.secondary)
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)

                        // Résumé progression
                        SummaryCard(completed: completedCount, total: totalCount)
                            .padding(.horizontal)

                        // Défis du mois
                        VStack(alignment: .leading, spacing: 12) {
                            AchievementSectionTitle(
                                sfSymbol: "calendar.badge.clock",
                                color: Color(hex: "4DA8F5"),
                                label: String(localized: "achievements.monthly_section")
                            )
                            .padding(.horizontal)

                            LazyVGrid(columns: columns, spacing: 16) {
                                ForEach(manager.monthlyAchievements) { ach in
                                    AchievementBadge(achievement: ach) { showPremiumSheet = true }
                                }
                            }
                            .padding(.horizontal)
                        }

                        // Succès
                        VStack(alignment: .leading, spacing: 12) {
                            AchievementSectionTitle(
                                sfSymbol: "rosette",
                                color: Color(hex: "2B87E8"),
                                label: String(localized: "achievements.all_title")
                            )
                            .padding(.horizontal)

                            LazyVGrid(columns: columns, spacing: 16) {
                                ForEach(regularAchievements) { ach in
                                    AchievementBadge(achievement: ach) { showPremiumSheet = true }
                                }
                            }
                            .padding(.horizontal)
                        }

                        // Aqua'ddict — bannière légendaire
                        if let legendary = legendaryAchievement {
                            AquaAddictBanner(achievement: legendary)
                                .padding(.horizontal)
                        }

                        // Bannière Premium
                        if !isPremiumUser {
                            Button { showPremiumSheet = true } label: {
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.orange.opacity(colorScheme == .dark ? 0.18 : 0.15))
                                            .frame(width: 44, height: 44)
                                        Image(systemName: "crown.fill")
                                            .font(.system(size: 20))
                                            .foregroundColor(Color.orange)
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(String(localized: "achievements.unlock_pro_title"))
                                            .font(.system(size: 15, weight: .bold))
                                            .foregroundColor(colorScheme == .dark ? Color(hex: "FCD34D") : Color(hex: "92400E"))
                                        Text(String(localized: "achievements.unlock_pro_detail"))
                                            .font(.system(size: 13))
                                            .foregroundColor(colorScheme == .dark ? Color(hex: "F59E0B").opacity(0.75) : Color(hex: "B45309"))
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(colorScheme == .dark ? Color(hex: "F59E0B") : Color(hex: "B45309"))
                                }
                                .padding(16)
                                .background(colorScheme == .dark ? Color(hex: "2D1F00") : Color(hex: "FFF7ED"))
                                .cornerRadius(16)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.orange.opacity(colorScheme == .dark ? 0.35 : 0.30), lineWidth: 1)
                                )
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.bottom, 32)
                }
                .background(Color("AppBackground"))
                .navigationBarHidden(true)
                .onChange(of: scrollToTopID) { _, _ in
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo("top")
                    }
                }
            }
            .sheet(isPresented: $showPremiumSheet) {
                PremiumSheet(isPremiumUser: $isPremiumUser, isPresented: $showPremiumSheet)
                    .environmentObject(storeKit)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.hidden)
                    .presentationCornerRadius(24)
            }
            .onChange(of: isPremiumUser) { _, newValue in
                manager.isPremiumUser = newValue
            }
            .onAppear {
                manager.isPremiumUser = isPremiumUser
                manager.confettiManager = confettiManager
                manager.loadMonthlyAchievements()
            }
        }
    }
}

// MARK: - AquaAddictBanner

private struct AquaAddictBanner: View {
    let achievement: Achievement

    var isCompleted: Bool { achievement.status == .completed }
    var litersProgress: Int {
        guard achievement.currentProgress.isFinite else { return 0 }
        return Int(achievement.currentProgress / 1000)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.20))
                        .frame(width: 56, height: 56)
                    Image(systemName: "drop.fill")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(Color.white)
                    if isCompleted {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(Color.white)
                            .background(Color(hex: "4DA8F5").clipShape(Circle()))
                            .offset(x: 20, y: 20)
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(achievement.title)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(Color.white)
                        Text(String(localized: "achievement.legendary_badge"))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Color(hex: "4DA8F5"))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.white)
                            .cornerRadius(6)
                    }
                    Text(achievement.description)
                        .font(.system(size: 12))
                        .foregroundColor(Color.white.opacity(0.85))
                        .lineLimit(2)
                }
                Spacer()
            }
            VStack(alignment: .trailing, spacing: 5) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 5)
                            .fill(Color.white.opacity(0.25))
                            .frame(height: 7)
                        RoundedRectangle(cornerRadius: 5)
                            .fill(Color.white)
                            .frame(width: geo.size.width * achievement.progressRatio, height: 7)
                            .animation(.easeInOut(duration: 0.6), value: achievement.progressRatio)
                    }
                }
                .frame(height: 7)
                Text(isCompleted
                     ? String(localized: "achievement.completed_tag")
                     : String(format: String(localized: "achievement.aqua_addict.progress"), litersProgress, "1 000 000"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color.white.opacity(0.9))
            }
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [Color(hex: "4DA8F5"), Color(hex: "1A5FBB")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(20)
        .shadow(color: Color(hex: "4DA8F5").opacity(0.4), radius: 12, x: 0, y: 6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(achievement.title)
        .accessibilityValue(isCompleted
            ? String(localized: "accessibility.completed")
            : String(format: String(localized: "achievement.aqua_addict.progress"), litersProgress, "1 000 000"))
    }
}

// MARK: - AchievementSectionTitle

private struct AchievementSectionTitle: View {
    let sfSymbol: String
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: sfSymbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 20, weight: .bold))
        }
    }
}

// MARK: - SummaryCard

struct SummaryCard: View {
    let completed: Int
    let total: Int

    var ratio: Double {
        guard total > 0 else { return 0 }
        let r = Double(completed) / Double(total)
        return r.isFinite ? r : 0
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(completed) / \(total)")
                        .font(.system(size: 32, weight: .bold))
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                    Text(L10n.achievementsUnlocked)
                        .font(.system(size: 14))
                        .foregroundColor(Color.secondary)
                }
                Spacer()
                ZStack {
                    Circle()
                        .stroke(Color(hex: "E3EFFC"), lineWidth: 10)
                        .frame(width: 72, height: 72)
                    Circle()
                        .trim(from: 0, to: ratio)
                        .stroke(
                            LinearGradient(
                                colors: [Color(hex: "4DA8F5"), Color(hex: "2B87E8")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 72, height: 72)
                        .animation(.easeInOut(duration: 0.6), value: ratio)
                    Text("\(Int(ratio * 100))%")
                        .font(.system(size: 16, weight: .bold))
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(String(localized: "accessibility.achievement_progress"))
                .accessibilityValue(String(format: String(localized: "accessibility.achievement_value"), Int(ratio * 100), completed, total))
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(hex: "E3EFFC"))
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "4DA8F5"), Color(hex: "2B87E8")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * ratio, height: 8)
                        .animation(.easeInOut(duration: 0.6), value: ratio)
                }
            }
            .frame(height: 8)
            .accessibilityHidden(true)
        }
        .padding(20)
        .background(Color("AppCardBackground"))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

// MARK: - AchievementBadge

struct AchievementBadge: View {
    let achievement: Achievement
    let onUnlock: () -> Void

    var isLocked: Bool { achievement.status == .locked }
    var isCompleted: Bool { achievement.status == .completed }

    var badgeBackground: Color {
        if isCompleted { return achievement.symbolColor.opacity(0.12) }
        if isLocked { return Color(UIColor.systemGray6) }
        return Color("AppCardBackground")
    }

    var body: some View {
        Button { if isLocked { onUnlock() } } label: {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(isCompleted ? achievement.symbolColor.opacity(0.15) : Color(UIColor.systemGray5))
                        .frame(width: 64, height: 64)
                    if isLocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 24))
                            .foregroundColor(Color(UIColor.systemGray3))
                    } else {
                        Image(systemName: achievement.sfSymbol)
                            .font(.system(size: 28, weight: .medium))
                            .foregroundColor(isCompleted ? achievement.symbolColor : Color(UIColor.systemGray3))
                    }
                    if achievement.isPro {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 11))
                            .foregroundColor(Color.white)
                            .padding(4)
                            .background(Color.orange)
                            .clipShape(Circle())
                            .offset(x: 22, y: -22)
                    }
                    if isCompleted {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(Color.green)
                            .background(Color.white.clipShape(Circle()))
                            .offset(x: 22, y: 22)
                    }
                }
                Text(achievement.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(isLocked ? Color.secondary : Color.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                Text(achievement.description)
                    .font(.system(size: 11))
                    .foregroundColor(Color.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                if achievement.status == .inProgress {
                    VStack(spacing: 3) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color(UIColor.systemGray5))
                                    .frame(height: 4)
                                if achievement.progressRatio.isFinite {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(achievement.symbolColor)
                                        .frame(width: geo.size.width * achievement.progressRatio, height: 4)
                                }
                            }
                        }
                        .frame(height: 4)
                        Text(achievement.progressLabel)
                            .font(.system(size: 10))
                            .foregroundColor(Color.secondary)
                    }
                    .padding(.top, 2)
                }
                if isCompleted {
                    Text(String(localized: "achievement.completed_tag"))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color.green)
                }
                if isLocked {
                    HStack(spacing: 4) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 9))
                            .foregroundColor(Color.orange)
                        Text(String(localized: "premium.label"))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color.orange)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(6)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(badgeBackground)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
            .opacity(isLocked ? 0.7 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(!isLocked)
        .accessibilityLabel(achievement.title)
        .accessibilityValue(accessibilityValue)
        .accessibilityHint(isLocked ? String(localized: "accessibility.premium_required_hint") : "")
    }

    private var accessibilityValue: String {
        if isLocked { return String(localized: "accessibility.locked_premium") }
        if isCompleted { return String(localized: "accessibility.completed") }
        if achievement.status == .inProgress {
            return String(format: String(localized: "accessibility.in_progress"), achievement.progressLabel)
        }
        return String(format: String(localized: "accessibility.available"), achievement.description)
    }
}

// MARK: - Preview

#Preview {
    let manager = AchievementManager()
    let confettiManager = ConfettiManager()
    AchievementsView()
        .environmentObject(manager)
        .environmentObject(confettiManager)
}
