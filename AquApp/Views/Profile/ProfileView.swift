import SwiftUI
import SwiftData

// MARK: - ProfileView

struct ProfileView: View {
    @AppStorage("userFirstName")   private var userName: String = ""
    @AppStorage("dailyGoalMl")     private var dailyGoalMl: Double = 2170
    @AppStorage("selectedBadgeID") private var selectedBadgeID: String = ""
    @AppStorage("isPremiumUser")   private var isPremiumUser: Bool = false
    @AppStorage("colorSchemeRaw")  private var colorSchemeRaw: String = "system"
    @AppStorage("notificationsOn") private var notificationsOn: Bool = false
    @AppStorage("userWeightKg")    private var weightKg: Double = 70
    @AppStorage("userHeightCm")    private var heightCm: Double = 170
    @AppStorage("userGender")      private var genderRaw: String = "notSpecified"

    @EnvironmentObject var store:    AppDataStore
    @EnvironmentObject var storeKit: StoreKitManager
    @EnvironmentObject var xpManager: XPManager
    @EnvironmentObject var achievementManager: AchievementManager
    @EnvironmentObject var challengeManager:   ChallengeManager

    @State private var showBadgePicker:  Bool = false
    @State private var showGoalEditor:   Bool = false
    @State private var showPremiumSheet: Bool = false
    @State private var showBodyEditor:   Bool = false
    @State private var showWrapped:      Bool = false
    @State private var wrappedData:      WrappedData? = nil

    // MARK: - Scroll-to-top
    var scrollToTopID: UUID = UUID()

    init(scrollToTopID: UUID = UUID()) {
        self.scrollToTopID = scrollToTopID
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "–"
        let build   = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
        return build.isEmpty ? version : "\(version) (\(build))"
    }

    var allBadges: [(id: String, sfSymbol: String, color: Color, title: String, isPro: Bool)] {
        [
            // ── Défis quotidiens ──────────────────────────────────────────────
            (id: "matinal",             sfSymbol: "sunrise.fill",         color: .orange,              title: String(localized: "challenge.matinal.title"),               isPro: false),
            (id: "regulier",            sfSymbol: "arrow.clockwise",      color: .blue,                title: String(localized: "challenge.regulier.title"),              isPro: false),
            (id: "grand_buveur",        sfSymbol: "drop.fill",            color: .blue,                title: String(localized: "challenge.grand_buveur.title"),          isPro: false),
            (id: "active_day",          sfSymbol: "figure.walk",          color: .green,               title: String(localized: "challenge.active_day.title"),            isPro: false),
            // ── Succès standards ──────────────────────────────────────────────
            (id: "constance",           sfSymbol: "checkmark.seal.fill",  color: .blue,                title: String(localized: "achievement.constance.title"),           isPro: false),
            (id: "heatwave",            sfSymbol: "thermometer.sun.fill", color: .red,                 title: String(localized: "achievement.heatwave.title"),            isPro: false),
            (id: "sleep_hydrated",      sfSymbol: "moon.zzz.fill",        color: .indigo,              title: String(localized: "achievement.sleep_hydrated.title"),      isPro: false),
            (id: "perfect_week",        sfSymbol: "star.fill",            color: .yellow,              title: String(localized: "achievement.perfect_week.title"),        isPro: false),
            // ── Succès long terme ─────────────────────────────────────────────
            (id: "marathonien",         sfSymbol: "figure.run",           color: Color(hex: "10B981"), title: String(localized: "achievement.marathonien.title"),         isPro: false),
            (id: "indestructible",      sfSymbol: "bolt.shield.fill",     color: Color(hex: "2B87E8"), title: String(localized: "achievement.indestructible.title"),      isPro: false),
            (id: "centurion_sobre",     sfSymbol: "drop.triangle.fill",   color: .purple,              title: String(localized: "achievement.centurion_sobre.title"),     isPro: false),
            (id: "legende",             sfSymbol: "crown.fill",           color: Color(hex: "F59E0B"), title: String(localized: "achievement.legende.title"),             isPro: false),
            (id: "aqua_addict",         sfSymbol: "drop.fill",            color: Color(hex: "4DA8F5"), title: String(localized: "achievement.aqua_addict.title"),         isPro: false),
            // ── Défis mensuels ────────────────────────────────────────────────
            (id: "dry_january",         sfSymbol: "snowflake",            color: Color(hex: "4DA8F5"), title: String(localized: "achievement.dry_january.title"),         isPro: false),
            (id: "sober_october",       sfSymbol: "leaf.fill",            color: Color(hex: "F97316"), title: String(localized: "achievement.sober_october.title"),       isPro: false),
            (id: "no_alcohol_november", sfSymbol: "nosign",               color: Color(hex: "8B5CF6"), title: String(localized: "achievement.no_alcohol_november.title"), isPro: false),
            (id: "summer_hydration",    sfSymbol: "sun.max.fill",         color: Color(hex: "F59E0B"), title: String(localized: "achievement.summer_hydration.title"),    isPro: false),
            // ── Succès Premium ────────────────────────────────────────────────
            (id: "iron_month",          sfSymbol: "flame.fill",           color: .orange,              title: String(localized: "achievement.iron_month.title"),          isPro: true),
            (id: "centurion",           sfSymbol: "shield.fill",          color: .indigo,              title: String(localized: "achievement.centurion.title"),           isPro: true),
        ]
    }

    var unlockedBadgeIDs: Set<String> {
        // Tous les défis quotidiens — clé UserDefaults : "completed_<id>"
        let challengeIDs = [
            "matinal", "regulier", "grand_buveur", "active_day",
            "soiree_tranquille", "cadence_parfaite", "grand_ecart",
            "flash_hydrate", "recuperation", "matin_champion"
        ]
        // Tous les succès — clé UserDefaults : "ach_completed_<id>"
        let achievementIDs = [
            "constance", "semaine_sobre", "sleep_hydrated", "heatwave",
            "perfect_week", "iron_month", "centurion",
            "marathonien", "indestructible", "centurion_sobre",
            "legende", "aqua_addict",
            "dry_january", "sober_october", "no_alcohol_november", "summer_hydration"
        ]
        let unlockedC = challengeIDs.filter  { UserDefaults.standard.bool(forKey: "completed_\($0)") }
        let unlockedA = achievementIDs.filter { UserDefaults.standard.bool(forKey: "ach_completed_\($0)") }
        return Set(unlockedC + unlockedA)
    }

    var completedAchievements: Int {
        ["constance", "semaine_sobre", "sleep_hydrated", "heatwave", "perfect_week",
         "iron_month", "centurion", "marathonien", "indestructible", "centurion_sobre",
         "legende", "aqua_addict", "dry_january", "sober_october", "no_alcohol_november", "summer_hydration"]
            .filter { UserDefaults.standard.bool(forKey: "ach_completed_\($0)") }.count
    }

    var completedChallenges: Int {
        ["matinal", "regulier", "grand_buveur", "active_day",
         "soiree_tranquille", "cadence_parfaite", "grand_ecart",
         "flash_hydrate", "recuperation", "matin_champion"]
            .filter { UserDefaults.standard.bool(forKey: "completed_\($0)") }.count
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                VStack(spacing: 24) {
                    Color.clear.frame(height: 0).id("top")

                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.profileTitle).font(.system(size: 32, weight: .bold))
                        Text(L10n.profileSubtitle).font(.subheadline).foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal).padding(.top, 8)

                    ProfileHeaderView(
                        userName:           userName,
                        isPremiumUser:      isPremiumUser,
                        allBadges:          allBadges,
                        unlockedBadgeIDs:   unlockedBadgeIDs,
                        selectedBadgeID:    $selectedBadgeID,
                        showBadgePicker:    $showBadgePicker,
                        currentStreak:      store.currentStreak,
                        totalCompleted:     completedAchievements + completedChallenges,
                        totalWaterLiters:   store.totalWaterLiters
                    )

                    if showBadgePicker {
                        BadgePickerSection(
                            allBadges: allBadges, selectedBadgeID: $selectedBadgeID,
                            isPremiumUser: isPremiumUser, unlockedBadgeIDs: unlockedBadgeIDs
                        ) { withAnimation { showBadgePicker = false } }
                        .padding(.horizontal)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }



                    ProfileHydrationView(dailyGoalMl: dailyGoalMl) { showGoalEditor = true }

                    ProfileBodyView(weightKg: weightKg, heightCm: heightCm, genderRaw: genderRaw) { showBodyEditor = true }

                    ProfileNotificationView(notificationsOn: $notificationsOn)

                    ProfileAppearanceView(colorSchemeRaw: $colorSchemeRaw)

                    // ── AquApp Wrapped — bilan annuel ────────────────────────────────
                    Button {
                        wrappedData = WrappedDataBuilder.build(
                            store: store, xpManager: xpManager,
                            achievementManager: achievementManager,
                            challengeManager: challengeManager,
                            modelContext: store.modelContextPublic
                        )
                        showWrapped = true
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(LinearGradient(colors: [Color(hex: "8B5CF6"), Color(hex: "4DA8F5")],
                                                          startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 44, height: 44)
                                Image(systemName: "sparkles")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(String(localized: "wrapped.profile.title"))
                                    .font(.system(size: 15, weight: .bold))
                                Text(String(localized: "wrapped.profile.subtitle"))
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12))
                                .foregroundColor(Color(UIColor.systemGray3))
                        }
                        .padding(16)
                        .background(Color("AppCardBackground"))
                        .cornerRadius(16)
                        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
                    }
                    .padding(.horizontal)
                    .accessibilityLabel(String(localized: "wrapped.profile.title"))
                    .accessibilityHint(String(localized: "wrapped.profile.subtitle"))

                    ProfilePremiumBannerView(isPremiumUser: isPremiumUser) { showPremiumSheet = true }

                    VStack(spacing: 4) {
                        Text(String(localized: "profile.app_name"))
                            .font(.system(size: 13, weight: .semibold)).foregroundColor(.secondary)
                        Text("\(L10n.profileVersion) \(appVersion)")
                            .font(.system(size: 12)).foregroundColor(Color(UIColor.systemGray3))
                    }

                    #if DEBUG
                    VStack(spacing: 8) {
                        Button {
                            UserDefaults.standard.removeObject(forKey: "onboardingCompleted")
                            UserDefaults.standard.removeObject(forKey: "userFirstName")
                            UserDefaults.standard.removeObject(forKey: "dailyGoalMl")
                            UserDefaults.standard.removeObject(forKey: "userWeightKg")
                            UserDefaults.standard.removeObject(forKey: "userHeightCm")
                            UserDefaults.standard.removeObject(forKey: "userGender")
                        } label: {
                            Label(String(localized: "profile.debug.reset_onboarding"), systemImage: "arrow.counterclockwise")
                                .font(.system(size: 12)).foregroundColor(.red.opacity(0.6))
                        }
                        Button {
                            isPremiumUser.toggle()
                            UserDefaults.standard.set(isPremiumUser, forKey: "isPremiumUser")
                            storeKit.isPremiumUser = isPremiumUser
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "crown.fill").font(.system(size: 12))
                                Text(isPremiumUser ? "DEBUG — Désactiver Premium" : "DEBUG — Activer Premium")
                                    .font(.system(size: 12))
                            }
                            .foregroundColor(isPremiumUser ? .red.opacity(0.6) : .orange.opacity(0.7))
                        }
                    }
                    .padding(.top, 4)
                    #endif

                    Color.clear.frame(height: 16)
                }
            }
            .background(Color("AppBackground"))
            .navigationBarHidden(true)
            .onChange(of: scrollToTopID) { _, _ in
                withAnimation(.easeOut(duration: 0.3)) { proxy.scrollTo("top") }
            }
            } // ScrollViewReader
        }
        .sheet(isPresented: $showGoalEditor) {
            GoalEditorSheet(dailyGoalMl: $dailyGoalMl, isPresented: $showGoalEditor)
                .presentationDetents([.medium, .large]).presentationDragIndicator(.hidden).presentationCornerRadius(24)
        }
        .sheet(isPresented: $showBodyEditor) {
            BodyEditSheet(weightKg: $weightKg, heightCm: $heightCm, genderRaw: $genderRaw, dailyGoalMl: $dailyGoalMl, isPresented: $showBodyEditor)
                .presentationDetents([.large]).presentationDragIndicator(.hidden).presentationCornerRadius(24)
        }
        .sheet(isPresented: $showPremiumSheet) {
            PremiumSheet(isPremiumUser: $isPremiumUser, isPresented: $showPremiumSheet)
                .environmentObject(storeKit)
                .presentationDetents([.large]).presentationDragIndicator(.hidden).presentationCornerRadius(24)
        }
        .onChange(of: storeKit.isPremiumUser) { _, newValue in isPremiumUser = newValue }
        .fullScreenCover(isPresented: $showWrapped) {
            if let wrappedData {
                WrappedView(data: wrappedData, isPresented: $showWrapped)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let config    = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: WaterEntry.self, WaterAlcoholEntry.self, DayRecord.self, configurations: config)
    let store     = AppDataStore(modelContext: container.mainContext)
    let storeKit  = StoreKitManager()
    let iconMgr   = AppIconManager()
    ProfileView()
        .environmentObject(store).environmentObject(storeKit).environmentObject(iconMgr)
        .modelContainer(container)
}
