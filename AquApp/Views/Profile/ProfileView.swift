import SwiftUI
import SwiftData

struct ProfileView: View {
    @ObservedObject private var healthStore = HealthDataManager.shared
    @AppStorage("dailyGoalMl") private var dailyGoalMl: Double = 2170
    @AppStorage("selectedBadgeID") private var selectedBadgeID: String = ""
    @AppStorage("colorSchemeRaw") private var colorSchemeRaw: String = "system"
    @AppStorage("notificationsOn") private var notificationsOn: Bool = true
    @ObservedObject private var premiumStore = PremiumManager.shared

    private var isPremiumUser: Bool {
        get { premiumStore.isPremium }
        nonmutating set { premiumStore.set(newValue) }
    }
    private var isPremiumUserBinding: Binding<Bool> {
        Binding(get: { premiumStore.isPremium }, set: { premiumStore.set($0) })
    }

    @EnvironmentObject var store: AppDataStore
    @EnvironmentObject var storeKit: StoreKitManager
    @EnvironmentObject var xpManager: XPManager
    @EnvironmentObject var appIconManager: AppIconManager
    @EnvironmentObject var achievementManager: AchievementManager
    @EnvironmentObject var challengeManager: ChallengeManager

    @State private var showBadgePicker  = false
    @State private var showGoalEditor   = false
    @State private var showBodyEditor   = false
    @State private var showPremiumSheet = false

    var scrollToTopID: UUID = UUID()
    init(scrollToTopID: UUID = UUID()) { self.scrollToTopID = scrollToTopID }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "–"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
        return build.isEmpty ? version : "\(version) (\(build))"
    }

    // MARK: - IDs (static let → typés une seule fois → Preview stable)

    private static let achievementIDs: [String] = [
        "constance", "semaine_sobre", "sleep_hydrated", "heatwave",
        "perfect_week", "iron_month", "centurion",
        "marathonien", "indestructible", "centurion_sobre",
        "legende", "aqua_addict", "dry_january", "sober_october",
        "no_alcohol_november", "summer_hydration"
    ]
    private static let challengeIDs: [String] = [
        "matinal", "regulier", "grand_buveur", "active_day",
        "soiree_tranquille", "cadence_parfaite", "grand_ecart",
        "flash_hydrate", "recuperation", "matin_champion"
    ]

    var completedAchievements: Int {
        Self.achievementIDs.filter { HealthDataManager.shared.isAchievementCompleted($0) }.count
    }
    var completedChallenges: Int {
        Self.challengeIDs.filter { HealthDataManager.shared.isChallengeCompleted($0) }.count
    }

    // MARK: - Badges (cosmétiques + succès + défis)

    private var allBadges: [(id: String, sfSymbol: String, color: Color, title: String, isPro: Bool)] {
        var list: [(id: String, sfSymbol: String, color: Color, title: String, isPro: Bool)] = [
            (id: "drop",  sfSymbol: "drop.fill",         color: Color(hex: "4DA8F5"), title: "Drop",  isPro: false),
            (id: "wave",  sfSymbol: "waveform.path.ecg", color: Color(hex: "10B981"), title: "Wave",  isPro: false),
            (id: "flame", sfSymbol: "flame.fill",        color: .orange,              title: "Flame", isPro: false),
            (id: "leaf",  sfSymbol: "leaf.fill",         color: .green,               title: "Leaf",  isPro: false),
            (id: "star",  sfSymbol: "star.fill",         color: .yellow,              title: "Star",  isPro: false),
            (id: "bolt",  sfSymbol: "bolt.fill",         color: Color(hex: "F59E0B"), title: "Bolt",  isPro: false),
            (id: "sun",   sfSymbol: "sun.max.fill",      color: .orange,              title: "Sun",   isPro: false),
            (id: "cloud", sfSymbol: "cloud.sun.fill",    color: Color(hex: "4DA8F5"), title: "Cloud", isPro: false),
            (id: "crown",   sfSymbol: "crown.fill",      color: .purple,              title: "Crown",   isPro: true),
            (id: "diamond", sfSymbol: "diamond.fill",    color: .cyan,                title: "Diamond", isPro: true),
            (id: "heart",   sfSymbol: "heart.fill",      color: .red,                 title: "Heart",   isPro: true),
            (id: "moon",    sfSymbol: "moon.stars.fill", color: .indigo,              title: "Moon",    isPro: true),
        ]
        for a in achievementManager.achievements + achievementManager.monthlyAchievements {
            list.append((id: "ach_\(a.id)", sfSymbol: a.sfSymbol, color: a.symbolColor, title: a.title, isPro: a.isPro))
        }
        for c in challengeManager.challenges {
            list.append((id: "cha_\(c.id)", sfSymbol: c.sfSymbol, color: c.symbolColor, title: c.title, isPro: c.isPro))
        }
        return list
    }

    private var unlockedBadgeIDs: Set<String> {
        var unlocked: Set<String> = ["drop", "wave", "flame", "leaf", "star", "bolt", "sun", "cloud"]
        let total = completedAchievements + completedChallenges
        if isPremiumUser && total >= 4  { unlocked.insert("crown") }
        if isPremiumUser && total >= 8  { unlocked.insert("diamond") }
        if isPremiumUser && total >= 12 { unlocked.insert("heart") }
        if isPremiumUser && total >= 16 { unlocked.insert("moon") }
        for a in achievementManager.achievements + achievementManager.monthlyAchievements
        where HealthDataManager.shared.isAchievementCompleted(a.id) {
            unlocked.insert("ach_\(a.id)")
        }
        for c in challengeManager.challenges
        where HealthDataManager.shared.isChallengeCompleted(c.id) {
            unlocked.insert("cha_\(c.id)")
        }
        return unlocked
    }

    private var effectiveBadgeID: String {
        guard !selectedBadgeID.isEmpty, unlockedBadgeIDs.contains(selectedBadgeID) else { return "" }
        return selectedBadgeID
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 24) {
                        Color.clear.frame(height: 0).id("top")

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Profile").font(.system(size: 32, weight: .bold))
                            Text("Manage your preferences").font(.subheadline).foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal).padding(.top, 8)

                        profileHeaderCard.padding(.horizontal)

                        if showBadgePicker {
                            badgePickerSection
                                .padding(.horizontal)
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }

                        ProfileHydrationView(dailyGoalMl: dailyGoalMl) { showGoalEditor = true }

                        ProfileBodyView(
                            weightKg: healthStore.weightKg,
                            heightCm: healthStore.heightCm,
                            genderRaw: healthStore.gender
                        ) { showBodyEditor = true }

                        ProfileNotificationView(notificationsOn: $notificationsOn)

                        ProfileAppearanceView(colorSchemeRaw: $colorSchemeRaw)
                            .environmentObject(storeKit)
                            .environmentObject(appIconManager)

                        #if DEBUG
                        Button { premiumStore.set(!isPremiumUser) } label: {
                            HStack(spacing: 10) {
                                Image(systemName: isPremiumUser ? "checkmark.seal.fill" : "crown.fill")
                                    .font(.system(size: 16, weight: .bold))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(isPremiumUser ? "Premium Actif ✓" : "Activer Premium (Debug)")
                                        .font(.system(size: 14, weight: .semibold))
                                    Text(isPremiumUser ? "Tap to disable" : "Tap to enable")
                                        .font(.system(size: 11)).foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "arrow.triangle.2.circlepath").font(.system(size: 14))
                            }
                            .foregroundColor(isPremiumUser ? .green : .orange)
                            .padding(14)
                            .background(RoundedRectangle(cornerRadius: 12)
                                .fill((isPremiumUser ? Color.green : Color.orange).opacity(0.12)))
                        }
                        .padding(.horizontal)
                        #endif

                        ProfilePremiumBannerView(isPremiumUser: isPremiumUser) { showPremiumSheet = true }

                        appInfoSection.padding(.top, 8)

                        Color.clear.frame(height: 16)
                    }
                    .padding(.bottom, 32)
                }
                .background(Color("AppBackground"))
                .navigationBarHidden(true)
                .onChange(of: scrollToTopID) { _, _ in
                    withAnimation(.easeOut(duration: 0.3)) { proxy.scrollTo("top") }
                }
                .onChange(of: unlockedBadgeIDs) { _, newSet in
                    if !selectedBadgeID.isEmpty && !newSet.contains(selectedBadgeID) {
                        selectedBadgeID = ""
                    }
                }
            }
        }
        .sheet(isPresented: $showGoalEditor) {
            GoalEditorSheet(dailyGoalMl: $dailyGoalMl, isPresented: $showGoalEditor)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(24)
        }
        .sheet(isPresented: $showBodyEditor) {
            BodyEditSheet(
                weightKg: healthStore.weightBinding,
                heightCm: healthStore.heightBinding,
                genderRaw: healthStore.genderBinding,
                dailyGoalMl: $dailyGoalMl,
                isPresented: $showBodyEditor
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.hidden)
            .presentationCornerRadius(24)
        }
        .sheet(isPresented: $showPremiumSheet) {
            PremiumSheet(isPremiumUser: isPremiumUserBinding, isPresented: $showPremiumSheet)
                .environmentObject(storeKit)
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(24)
        }
    }

    // MARK: - Header

    private var profileHeaderCard: some View {
        VStack(spacing: 20) {
            HStack(spacing: 16) {
                ZStack {
                    Circle().fill(gradientForBadge(effectiveBadgeID)).frame(width: 70, height: 70)
                    Text(healthStore.firstName.prefix(1).uppercased())
                        .font(.system(size: 28, weight: .bold)).foregroundColor(.white)
                }
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(healthStore.firstName.isEmpty ? "User" : healthStore.firstName)
                            .font(.system(size: 22, weight: .bold))
                        if !effectiveBadgeID.isEmpty {
                            Image(systemName: "crown.fill").font(.system(size: 12)).foregroundColor(.yellow)
                        }
                    }
                    Button { showBadgePicker = true } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "trophy.fill").font(.system(size: 10))
                            Text("Choose a badge").font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(.white).padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Color.blue.opacity(0.8)).cornerRadius(6)
                    }
                }
                Spacer()
            }
            HStack(spacing: 0) {
                statItem(value: "\(store.currentStreak)", label: "Streak days", color: .orange)
                Divider().frame(height: 40)
                statItem(value: "\(completedAchievements + completedChallenges)", label: "Achievements\n& challenges", color: .blue)
                Divider().frame(height: 40)
                statItem(value: String(format: "%.1f L", store.totalAlcoholLiters), label: "Total drunk", color: .purple)
            }
            .padding(.vertical, 8)
            xpLevelSection
        }
        .padding(20).background(Color("AppCardBackground")).cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    private var xpLevelSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Level \(xpManager.currentLevel.rawValue)").font(.system(size: 14, weight: .bold))
                    Text(xpManager.currentLevel.localizedName).font(.system(size: 13, weight: .medium)).foregroundColor(.blue)
                }
                Spacer()
                Text("\(xpManager.xpInCurrentLevel) / \(xpManager.currentLevelRange) XP")
                    .font(.system(size: 12)).foregroundColor(.secondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(Color(UIColor.systemGray5)).frame(height: 8)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(LinearGradient(colors: [Color(hex: "4DA8F5"), Color(hex: "2B87E8")], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(0, geo.size.width * (xpManager.progressRatio.isFinite ? xpManager.progressRatio : 0)), height: 8)
                        .animation(.easeInOut(duration: 0.6), value: xpManager.progressRatio)
                }
            }
            .frame(height: 8)
            HStack {
                Text("\(xpManager.xpInCurrentLevel) XP accumulated").font(.system(size: 11)).foregroundColor(.secondary)
                Spacer()
                if let left = xpManager.xpUntilNextLevel, let next = xpManager.currentLevel.next {
                    Text("\(left) XP left → \(next.localizedName)").font(.system(size: 11)).foregroundColor(.secondary)
                } else {
                    Text("Max level reached!").font(.system(size: 11)).foregroundColor(.green)
                }
            }
        }
        .padding(16).background(Color.black.opacity(0.2)).cornerRadius(12)
    }

    private var badgePickerSection: some View {
        BadgePickerSection(
            allBadges: allBadges,
            selectedBadgeID: $selectedBadgeID,
            isPremiumUser: isPremiumUser,
            unlockedBadgeIDs: unlockedBadgeIDs
        ) { withAnimation { showBadgePicker = false } }
    }

    private var appInfoSection: some View {
        VStack(spacing: 4) {
            Text("AquApp").font(.system(size: 13, weight: .semibold)).foregroundColor(.secondary)
            Text("Version \(appVersion)").font(.system(size: 12)).foregroundColor(Color(UIColor.systemGray3))
        }
    }

    private func statItem(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.system(size: 20, weight: .bold)).foregroundColor(color)
            Text(label).font(.system(size: 11)).foregroundColor(.secondary).multilineTextAlignment(.center).lineLimit(2)
        }
        .frame(maxWidth: .infinity)
    }

    private func gradientForBadge(_ badgeID: String) -> AnyShapeStyle {
        if let badge = allBadges.first(where: { $0.id == badgeID }) { return AnyShapeStyle(badge.color) }
        return AnyShapeStyle(Color.blue)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: WaterEntry.self, WaterAlcoholEntry.self, DayRecord.self, configurations: config
    )
    let store = AppDataStore(modelContext: container.mainContext)
    return ProfileView()
        .environmentObject(store)
        .environmentObject(StoreKitManager())
        .environmentObject(XPManager())
        .environmentObject(AppIconManager())
        .environmentObject(AchievementManager())
        .environmentObject(ChallengeManager())
        .modelContainer(container)
}
