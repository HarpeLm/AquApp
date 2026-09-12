import SwiftUI
import HealthKit
import Combine
import SwiftData

// MARK: - Challenge Category & Status

enum ChallengeCategory: String {
    case hydration = "hydration"
    case sport     = "sport"
    case wellness  = "wellness"
    case streak    = "streak"
    case weather   = "weather"

    var label: String {
        switch self {
        case .hydration: return String(localized: "challenge.category.hydration")
        case .sport:     return String(localized: "challenge.category.sport")
        case .wellness:  return String(localized: "challenge.category.wellness")
        case .streak:    return String(localized: "challenge.category.streak")
        case .weather:   return String(localized: "challenge.category.weather")
        }
    }
}


// MARK: - Challenge Model

struct Challenge: Identifiable {
    let id: String
    let sfSymbol: String
    let symbolColor: Color
    let title: String
    let titleEmoji: String
    let description: String
    let category: ChallengeCategory
    let isPro: Bool

    var status: ChallengeStatus = .available
    var currentProgress: Double = 0
    var targetProgress: Double  = 1

    var progressRatio: Double {
        guard targetProgress > 0 else { return 0 }
        let ratio = currentProgress / targetProgress
        guard ratio.isFinite else { return 0 }
        return min(max(ratio, 0), 1.0)
    }

    var badgeSFSymbol: String {
        switch id {
        case "matinal":          return "sunrise.fill"
        case "regulier":         return "clock.fill"
        case "grand_buveur":     return "bolt.fill"
        case "active_day":       return "figure.run"
        case "soiree_tranquille":return "moon.stars.fill"
        case "cadence_parfaite": return "waveform.path.ecg"
        case "grand_ecart":      return "arrow.up.arrow.down"
        case "flash_hydrate":    return "bolt.circle.fill"
        case "recuperation":     return "heart.fill"
        case "matin_champion":   return "sun.max.fill"
        default:                 return "star.fill"
        }
    }

    var progressLabel: String {
        switch id {
        case "active_day":
            return String(format: String(localized: "challenge.progress_steps"), Int(currentProgress), Int(targetProgress))
        case "regulier":
            return String(format: String(localized: "challenge.progress_times"), Int(currentProgress))
        case "grand_buveur":
            return String(format: String(localized: "challenge.progress_ml"), Int(currentProgress))          // ← Int, plus UnitFormatter.volume
        case "cadence_parfaite":
            return String(format: String(localized: "challenge.cadence.progress"), Int(currentProgress), Int(targetProgress))
        case "flash_hydrate":
            return String(format: String(localized: "challenge.flash.progress"), Int(currentProgress))       // ← Int
        case "matin_champion":
            return String(format: String(localized: "challenge.matin.progress"), Int(currentProgress))       // ← Int
        case "recuperation":
            return String(format: String(localized: "challenge.recuperation.progress"), Int(currentProgress)) // ← Int
        default:
            return ""
        }
    }
}

// MARK: - ChallengeManager

class ChallengeManager: ObservableObject {

    @Published var challenges: [Challenge] = []

    var isPremiumUser: Bool = PremiumManager.shared.isPremium {
        didSet {
            guard oldValue != isPremiumUser else { return }
            PremiumManager.shared.set(isPremiumUser)
            updateProStatus()
        }
    }

    weak var confettiManager: ConfettiManager?
    weak var xpManager:       XPManager?

    private let healthStore = HKHealthStore()
    private let defaults    = UserDefaults.standard

    private var cachedWorkoutEndDate: Date? = nil
    private var workoutFetchedToday: Bool   = false

    init() {
        loadChallenges()
        restoreProgress()
        requestHealthKitPermission()
    }

    // MARK: - Chargement des défis

    private func loadChallenges() {
        challenges = [
            Challenge(
                id: "matinal",
                sfSymbol: "sunrise.fill", symbolColor: .orange,
                title: String(localized: "challenge.matinal.title"), titleEmoji: "🌅",
                description: String(localized: "challenge.matinal.desc"),
                category: .hydration, isPro: false, targetProgress: 1
            ),
            Challenge(
                id: "grand_buveur",
                sfSymbol: "drop.fill", symbolColor: Color(hex: "4DA8F5"),
                title: String(localized: "challenge.grand_buveur.title"), titleEmoji: "💪",
                description: String(localized: "challenge.grand_buveur.desc"),
                category: .hydration, isPro: false, targetProgress: 3000
            ),
            Challenge(
                id: "matin_champion",
                sfSymbol: "sun.max.fill", symbolColor: Color(hex: "F59E0B"),
                title: String(localized: "challenge.matin_champion.title"), titleEmoji: "🌞",
                description: String(localized: "challenge.matin_champion.desc"),
                category: .hydration, isPro: false, targetProgress: 1
            ),
            Challenge(
                id: "cadence_parfaite",
                sfSymbol: "waveform.path.ecg", symbolColor: Color(hex: "10B981"),
                title: String(localized: "challenge.cadence_parfaite.title"), titleEmoji: "⚡",
                description: String(localized: "challenge.cadence_parfaite.desc"),
                category: .hydration, isPro: false, targetProgress: 6
            ),
            Challenge(
                id: "grand_ecart",
                sfSymbol: "arrow.up.arrow.down", symbolColor: Color(hex: "8B5CF6"),
                title: String(localized: "challenge.grand_ecart.title"), titleEmoji: "🌗",
                description: String(localized: "challenge.grand_ecart.desc"),
                category: .hydration, isPro: false, targetProgress: 2
            ),
            Challenge(
                id: "flash_hydrate",
                sfSymbol: "bolt.fill", symbolColor: Color(hex: "EF4444"),
                title: String(localized: "challenge.flash_hydrate.title"), titleEmoji: "⚡",
                description: String(localized: "challenge.flash_hydrate.desc"),
                category: .hydration, isPro: false, targetProgress: 500
            ),
            Challenge(
                id: "regulier",
                sfSymbol: "arrow.clockwise", symbolColor: .blue,
                title: String(localized: "challenge.regulier.title"), titleEmoji: "⏰",
                description: String(localized: "challenge.regulier.desc"),
                category: .hydration, isPro: false, targetProgress: 4
            ),
            Challenge(
                id: "soiree_tranquille",
                sfSymbol: "moon.stars.fill", symbolColor: Color(hex: "6C3483"),
                title: String(localized: "challenge.soiree_tranquille.title"), titleEmoji: "🌙",
                description: String(localized: "challenge.soiree_tranquille.desc"),
                category: .wellness, isPro: false, targetProgress: 1
            ),
            Challenge(
                id: "active_day",
                sfSymbol: "figure.walk", symbolColor: .green,
                title: String(localized: "challenge.active_day.title"), titleEmoji: "🚶",
                description: String(localized: "challenge.active_day.desc"),
                category: .sport, isPro: false, targetProgress: 10000
            ),
            Challenge(
                id: "recuperation",
                sfSymbol: "heart.fill", symbolColor: Color(hex: "EF4444"),
                title: String(localized: "challenge.recuperation.title"), titleEmoji: "🏋️",
                description: String(localized: "challenge.recuperation.desc"),
                category: .sport, isPro: false, targetProgress: 300
            ),
        ]
        updateProStatus()
    }

    // MARK: - HealthKit

    func requestHealthKitPermission() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let stepType    = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let waterType   = HKQuantityType.quantityType(forIdentifier: .dietaryWater)!
        let workoutType = HKObjectType.workoutType()
        healthStore.requestAuthorization(toShare: [], read: [stepType, waterType, workoutType]) { _, _ in }
    }

    func fetchTodaySteps(completion: @escaping (Double) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else { completion(0); return }
        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        switch healthStore.authorizationStatus(for: stepType) {
        case .sharingAuthorized:
            performStepQuery(completion: completion)
        case .notDetermined:
            healthStore.requestAuthorization(toShare: [], read: [stepType]) { [weak self] granted, _ in
                guard granted else { completion(0); return }
                self?.performStepQuery(completion: completion)
            }
        default:
            completion(0)
        }
    }

    private func performStepQuery(completion: @escaping (Double) -> Void) {
        let stepType   = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let predicate  = HKQuery.predicateForSamples(withStart: startOfDay, end: Date())
        let query = HKStatisticsQuery(
            quantityType: stepType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum
        ) { _, result, _ in
            let steps = result?.sumQuantity()?.doubleValue(for: .count()) ?? 0
            DispatchQueue.main.async { completion(steps) }
        }
        healthStore.execute(query)
    }

    private func fetchLastWorkoutEndDateCached(completion: @escaping (Date?) -> Void) {
        if workoutFetchedToday {
            completion(cachedWorkoutEndDate)
            return
        }
        guard HKHealthStore.isHealthDataAvailable() else { completion(nil); return }
        let workoutType = HKObjectType.workoutType()
        guard healthStore.authorizationStatus(for: workoutType) == .sharingAuthorized else {
            healthStore.requestAuthorization(toShare: [], read: [workoutType]) { [weak self] granted, _ in
                guard granted else { completion(nil); return }
                self?.performWorkoutQuery(completion: completion)
            }
            return
        }
        performWorkoutQuery(completion: completion)
    }

    private func performWorkoutQuery(completion: @escaping (Date?) -> Void) {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let predicate  = HKQuery.predicateForSamples(withStart: startOfDay, end: Date())
        let sort       = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(
            sampleType:      HKObjectType.workoutType(),
            predicate:       predicate,
            limit:           1,
            sortDescriptors: [sort]
        ) { [weak self] _, samples, _ in
            let endDate = (samples?.first as? HKWorkout)?.endDate
            DispatchQueue.main.async {
                self?.cachedWorkoutEndDate = endDate
                self?.workoutFetchedToday  = true
                completion(endDate)
            }
        }
        healthStore.execute(query)
    }

    // MARK: - Reset quotidien

    func performDailyReset() {
        let today     = Calendar.current.startOfDay(for: Date())
        let lastReset = defaults.object(forKey: "challenges_last_reset") as? Date
        if let last = lastReset, Calendar.current.isDate(last, inSameDayAs: today) { return }

        for i in challenges.indices {
            guard challenges[i].status != .locked else { continue }
            challenges[i].currentProgress = 0
            if challenges[i].status == .completed || challenges[i].status == .inProgress {
                challenges[i].status = .available
            }
            defaults.set(0,    forKey: "progress_\(challenges[i].id)")
            defaults.removeObject(forKey: "today_completed_\(challenges[i].id)")
        }

        defaults.set(false, forKey: "grand_ecart_before9")
        defaults.set(false, forKey: "grand_ecart_after21")

        cachedWorkoutEndDate = nil
        workoutFetchedToday  = false

        defaults.set(today, forKey: "challenges_last_reset")
        objectWillChange()
    }

    private func objectWillChange() {
        DispatchQueue.main.async { self.challenges = self.challenges }
    }

    // MARK: - Point d'entrée principal

    func onWaterUpdated(
        totalTodayMl:     Double,
        dailyGoalMl:      Double,
        dailyGoalReached: Bool,
        drinkCount:       Int,
        mlBeforeNine:     Double,
        waterEntries:     [WaterEntry],
        alcoholCount:     Int
    ) {
        if mlBeforeNine > 0 { completeChallenge(id: "matinal") }

        updateProgress(id: "grand_buveur", value: totalTodayMl)
        if totalTodayMl >= 3000 { completeChallenge(id: "grand_buveur") }

        updateProgress(id: "regulier", value: Double(drinkCount))
        if drinkCount >= 4 { completeChallenge(id: "regulier") }

        checkMatinChampion(waterEntries: waterEntries, dailyGoalMl: dailyGoalMl)

        checkCadenceParfaite(waterEntries: waterEntries)

        checkGrandEcart(waterEntries: waterEntries)

        checkFlashHydrate(waterEntries: waterEntries)

        if dailyGoalReached && alcoholCount == 0 {
            completeChallenge(id: "soiree_tranquille")
        }

        fetchTodaySteps { [weak self] steps in
            guard let self else { return }
            self.updateProgress(id: "active_day", value: steps)
            if steps >= 10000 && dailyGoalReached {
                self.completeChallenge(id: "active_day")
            }
        }

        checkRecuperation(waterEntries: waterEntries)
    }

    func onAlcoholUpdated(alcoholCount: Int, dailyGoalReached: Bool) {
        if alcoholCount > 0 {
            if let idx = challenges.firstIndex(where: { $0.id == "soiree_tranquille" }),
               challenges[idx].status == .completed {
                challenges[idx].status          = .inProgress
                challenges[idx].currentProgress = 0
                saveTodayProgress()
            }
        } else if dailyGoalReached {
            completeChallenge(id: "soiree_tranquille")
        }
    }

    // MARK: - Logique de chaque défi

    private func checkMatinChampion(waterEntries: [WaterEntry], dailyGoalMl: Double) {
        let calendar = Calendar.current
        let noon     = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: Date())!
        let mlBeforeNoon = waterEntries
            .filter { $0.date < noon }
            .reduce(0.0) { $0 + $1.amountMl }
        let target = dailyGoalMl * 0.5
        updateProgress(id: "matin_champion", value: mlBeforeNoon >= target ? 1 : 0)
        if mlBeforeNoon >= target { completeChallenge(id: "matin_champion") }
    }

    private func checkCadenceParfaite(waterEntries: [WaterEntry]) {
        let calendar = Calendar.current
        let windows: [(Int, Int)] = [(8,10),(10,12),(12,14),(14,16),(16,18),(18,20)]
        var coveredWindows = 0
        for (startH, endH) in windows {
            let windowStart = calendar.date(bySettingHour: startH, minute: 0, second: 0, of: Date())!
            let windowEnd   = calendar.date(bySettingHour: endH,   minute: 0, second: 0, of: Date())!
            let mlInWindow  = waterEntries
                .filter { $0.date >= windowStart && $0.date < windowEnd }
                .reduce(0.0) { $0 + $1.amountMl }
            if mlInWindow >= 200 { coveredWindows += 1 }
        }
        updateProgress(id: "cadence_parfaite", value: Double(coveredWindows))
        if coveredWindows >= 6 { completeChallenge(id: "cadence_parfaite") }
    }

    private func checkGrandEcart(waterEntries: [WaterEntry]) {
        let calendar = Calendar.current
        let nineAM   = calendar.date(bySettingHour: 9,  minute: 0, second: 0, of: Date())!
        let ninePM   = calendar.date(bySettingHour: 21, minute: 0, second: 0, of: Date())!

        if waterEntries.contains(where: { $0.date < nineAM })  { defaults.set(true, forKey: "grand_ecart_before9") }
        if waterEntries.contains(where: { $0.date >= ninePM }) { defaults.set(true, forKey: "grand_ecart_after21") }

        let b9  = defaults.bool(forKey: "grand_ecart_before9")
        let a21 = defaults.bool(forKey: "grand_ecart_after21")

        updateProgress(id: "grand_ecart", value: Double([b9, a21].filter { $0 }.count))
        if b9 && a21 { completeChallenge(id: "grand_ecart") }
    }

    private func checkFlashHydrate(waterEntries: [WaterEntry]) {
        guard !waterEntries.isEmpty else { return }

        let sorted = waterEntries.sorted { $0.date < $1.date }
        let windowDuration: TimeInterval = 30 * 60

        var bestCumulative: Double = 0

        for startIdx in 0..<sorted.count {
            let windowStart = sorted[startIdx].date
            var cumulative: Double = 0

            for entry in sorted[startIdx...] {
                guard entry.date.timeIntervalSince(windowStart) <= windowDuration else { break }
                cumulative += entry.amountMl
            }

            if cumulative > bestCumulative {
                bestCumulative = cumulative
            }

            if bestCumulative >= 500 {
                updateProgress(id: "flash_hydrate", value: 500)
                completeChallenge(id: "flash_hydrate")
                return
            }
        }

        updateProgress(id: "flash_hydrate", value: min(bestCumulative, 500))
    }

    private func checkRecuperation(waterEntries: [WaterEntry]) {
        fetchLastWorkoutEndDateCached { [weak self] workoutEnd in
            guard let self, let workoutEnd else { return }
            let oneHourAfter = workoutEnd.addingTimeInterval(3600)
            let mlAfterWorkout = waterEntries
                .filter { $0.date >= workoutEnd && $0.date <= oneHourAfter }
                .reduce(0.0) { $0 + $1.amountMl }
            self.updateProgress(id: "recuperation", value: min(mlAfterWorkout, 300))
            if mlAfterWorkout >= 300 { self.completeChallenge(id: "recuperation") }
        }
    }

    // MARK: - Helpers

    private func updateProgress(id: String, value: Double) {
        guard let idx = challenges.firstIndex(where: { $0.id == id }) else { return }
        guard challenges[idx].status != .locked,
              challenges[idx].status != .completed else { return }
        challenges[idx].currentProgress = value
        if challenges[idx].status == .available { challenges[idx].status = .inProgress }
        saveTodayProgress()
    }

    private func completeChallenge(id: String) {
        guard let idx = challenges.firstIndex(where: { $0.id == id }) else { return }
        guard challenges[idx].status != .locked,
              challenges[idx].status != .completed else { return }
        challenges[idx].status          = .completed
        challenges[idx].currentProgress = challenges[idx].targetProgress
        saveTodayProgress()
        defaults.set(true, forKey: "completed_\(id)")
        HealthDataManager.shared.setChallengeCompleted(id, value: true)
        let title = challenges[idx].title
        DispatchQueue.main.async {
            HapticManager.shared.achievementUnlocked()
            self.confettiManager?.trigger(.challengeCompleted(title: title))
            Task { @MainActor in self.xpManager?.add(.challenge) }
        }
    }

    func updateProStatus() {
        for i in challenges.indices {
            if challenges[i].isPro && !isPremiumUser { challenges[i].status = .locked }
        }
    }

    private func saveTodayProgress() {
        for c in challenges {
            defaults.set(c.currentProgress, forKey: "progress_\(c.id)")
            if c.status == .completed { defaults.set(true, forKey: "today_completed_\(c.id)") }
        }
    }

    private func restoreProgress() {
        let today      = Calendar.current.startOfDay(for: Date())
        let lastReset  = defaults.object(forKey: "challenges_last_reset") as? Date
        let needsReset = lastReset == nil || !Calendar.current.isDate(lastReset!, inSameDayAs: today)

        for i in challenges.indices {
            let id = challenges[i].id
            if needsReset {
                challenges[i].currentProgress = 0
                challenges[i].status = challenges[i].isPro && !isPremiumUser ? .locked : .available
            } else {
                let progress       = defaults.double(forKey: "progress_\(id)")
                let todayCompleted = defaults.bool(forKey: "today_completed_\(id)")
                challenges[i].currentProgress = progress
                if todayCompleted    { challenges[i].status = .completed  }
                else if progress > 0 { challenges[i].status = .inProgress }
            }
        }
        if needsReset {
            defaults.set(today,  forKey: "challenges_last_reset")
            defaults.set(false,  forKey: "grand_ecart_before9")
            defaults.set(false,  forKey: "grand_ecart_after21")
        }
    }
}

// MARK: - ChallengesView

struct ChallengesView: View {

    @EnvironmentObject var manager:         ChallengeManager
    @EnvironmentObject var store:           AppDataStore
    @EnvironmentObject var confettiManager: ConfettiManager
    @ObservedObject private var premiumStore = PremiumManager.shared
    private var isPremiumUser: Bool {
        get { premiumStore.isPremium }
        nonmutating set { premiumStore.set(newValue) }
    }

    var scrollToTopID: UUID = UUID()

    init(scrollToTopID: UUID = UUID()) {
        self.scrollToTopID = scrollToTopID
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    Color.clear.frame(height: 0).id("top")
                    VStack(alignment: .leading, spacing: 24) {

                        VStack(alignment: .leading, spacing: 4) {
                            Text(L10n.challengesTitle)
                                .font(.system(size: 32, weight: .bold))
                            Text(L10n.challengesSub)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)

                        ActiveChallengeCard(current: store.todayWaterMl, goal: store.dailyGoalMl)
                            .padding(.horizontal)

                        VStack(alignment: .leading, spacing: 0) {
                            Text(L10n.challengesDayTitle)
                                .font(.system(size: 20, weight: .bold))
                                .padding(.horizontal)
                                .padding(.bottom, 12)

                            VStack(spacing: 0) {
                                ForEach(Array(manager.challenges.enumerated()), id: \.element.id) { index, challenge in
                                    ChallengeRow(challenge: challenge)
                                    if index < manager.challenges.count - 1 {
                                        Divider().padding(.leading, 72)
                                    }
                                }
                            }
                            .background(Color("AppCardBackground"))
                            .cornerRadius(16)
                            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
                            .padding(.horizontal)
                        }
                    }
                    .padding(.bottom, 32)
                }
                .background(Color("AppBackground"))
                .onChange(of: scrollToTopID) { _, _ in
                    withAnimation(.easeOut(duration: 0.3)) { proxy.scrollTo("top") }
                }
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            manager.confettiManager = confettiManager
            manager.isPremiumUser   = isPremiumUser
        }
        .onChange(of: isPremiumUser) { _, newValue in
            manager.isPremiumUser = newValue
        }
    }
}

// MARK: - ActiveChallengeCard

struct ActiveChallengeCard: View {
    let current: Double
    let goal: Double
    var progress: Double { min(current / max(goal, 1), 1.0) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.9))
                Text(String(localized: "challenge.card.ongoing"))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
            }
            Text(String(localized: "challenge.card.title"))
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(.white)
            Text(String(format: String(localized: "challenge.card.subtitle"), Int(goal)))
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.85))
            Spacer().frame(height: 4)
            VStack(alignment: .trailing, spacing: 6) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.3)).frame(height: 8)
                        RoundedRectangle(cornerRadius: 6).fill(Color.white)
                            .frame(width: geo.size.width * progress, height: 8)
                            .animation(.easeInOut(duration: 0.4), value: progress)
                    }
                }
                .frame(height: 8)
                Text("\(UnitFormatter.volumeNumber(current)) / \(UnitFormatter.volume(goal))")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
            }
        }
        .padding(20)
        .background(LinearGradient(
            colors: [Color(hex: "4DA8F5"), Color(hex: "2B87E8")],
            startPoint: .topLeading, endPoint: .bottomTrailing
        ))
        .cornerRadius(20)
    }
}

// MARK: - ChallengeRow

struct ChallengeRow: View {
    let challenge: Challenge

    var iconBackground: Color {
        switch challenge.status {
        case .locked:    return Color(UIColor.systemGray5)
        case .completed: return Color.green.opacity(0.15)
        default:         return challenge.symbolColor.opacity(0.10)
        }
    }

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().fill(iconBackground).frame(width: 48, height: 48)
                if challenge.status == .completed {
                    Image(systemName: "checkmark").font(.system(size: 18, weight: .bold)).foregroundColor(.green)
                } else if challenge.status == .locked {
                    Image(systemName: "lock.fill").font(.system(size: 18)).foregroundColor(.gray)
                } else {
                    Image(systemName: challenge.sfSymbol).font(.system(size: 20, weight: .medium)).foregroundColor(challenge.symbolColor)
                }
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(challenge.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(challenge.status == .locked ? .secondary : .primary)
                        .minimumScaleFactor(0.85).lineLimit(1)
                    if challenge.status != .locked {
                        Image(systemName: challenge.badgeSFSymbol)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(challenge.symbolColor)
                            .padding(4).background(challenge.symbolColor.opacity(0.12)).clipShape(Circle())
                    }
                    if challenge.isPro { PremiumBadge() }
                }
                Text(challenge.description)
                    .font(.system(size: 13)).foregroundColor(.secondary)
                    .minimumScaleFactor(0.8).lineLimit(2)

                if challenge.status == .inProgress && !challenge.progressLabel.isEmpty {
                    let ratio = challenge.progressRatio.isFinite ? min(max(challenge.progressRatio, 0), 1) : 0
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(challenge.progressLabel)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(Int(ratio * 100))%")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(challenge.symbolColor)
                                .monospacedDigit()
                        }
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.white.opacity(0.12))          // track visible en dark ET light
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(LinearGradient(                      // dégradé vif par défi
                                        colors: [challenge.symbolColor.opacity(0.85), challenge.symbolColor],
                                        startPoint: .leading, endPoint: .trailing))
                                    .frame(width: ratio == 0 ? 0 : max(6, geo.size.width * ratio)) // min 6pt si > 0
                                    .animation(.easeInOut(duration: 0.5), value: ratio)
                            }
                        }
                        .frame(height: 8)
                    }
                    .padding(.top, 6)
                }
            }

            Spacer()

            if challenge.status == .locked {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(UIColor.systemGray3))
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .opacity(challenge.status == .locked ? 0.6 : 1.0)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(challenge.title)
        .accessibilityValue(a11yValue)
    }

    private var a11yValue: String {
        switch challenge.status {
        case .locked:     return String(localized: "accessibility.locked_premium")
        case .completed:  return String(localized: "accessibility.completed")
        case .inProgress: return challenge.progressLabel.isEmpty ? challenge.description : String(format: String(localized: "accessibility.in_progress"), challenge.progressLabel)
        case .available:  return challenge.description
        }
    }
}

// MARK: - PremiumBadge

struct PremiumBadge: View {
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "crown.fill").font(.system(size: 9, weight: .bold)).foregroundColor(.white)
            Text(String(localized: "premium.badge")).font(.system(size: 10, weight: .bold)).foregroundColor(.white)
        }
        .padding(.horizontal, 8).padding(.vertical, 3).background(Color.orange).cornerRadius(6)
    }
}

// MARK: - Preview

private func makeChallengesPreviewDependencies() -> (AppDataStore, ConfettiManager, ChallengeManager, ModelContainer) {
    let config    = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: WaterEntry.self, WaterAlcoholEntry.self, DayRecord.self, configurations: config)
    let store     = AppDataStore(modelContext: container.mainContext)
    let cm        = ConfettiManager()
    let chm       = ChallengeManager()
    chm.confettiManager = cm
    return (store, cm, chm, container)
}

#Preview {
    let (store, cm, chm, container) = makeChallengesPreviewDependencies()
    ChallengesView()
        .environmentObject(store).environmentObject(cm).environmentObject(chm)
        .modelContainer(container)
}
