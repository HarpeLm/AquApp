//
//  L10n.swift
//  AquApp
//
//  Localisation via String Catalog (Localizable.xcstrings).
//  Syntaxe : String(localized: "clé") — iOS 16+ / Xcode 15+
//  Toutes les 14 langues sont dans Localizable.xcstrings.
//  Pour ajouter une clé : ajouter ici + dans Localizable.xcstrings.

import Foundation

enum L10n {

    // MARK: - Accueil / HomeView

    static var homeGoodMorning: String    { String(localized: "home.good_morning") }
    static var homeGoalLabel: String      { String(localized: "home.goal_label") }
    static var homeAddWater: String       { String(localized: "home.add_water") }
    static var homeAddAlcohol: String     { String(localized: "home.add_alcohol") }
    static var homeStreakLabel: String    { String(localized: "home.streak_label") }
    static var homeSoberLabel: String     { String(localized: "home.sober_label") }
    static var homeRecentActivity: String { String(localized: "home.recent_activity") }
    static var homeNoActivity: String     { String(localized: "home.no_activity") }
    static var homeNoActivitySub: String  { String(localized: "home.no_activity_sub") }
    static var homeDays: String           { String(localized: "home.days") }

    // MARK: - Canicule / Heatwave

    static var heatwaveNotifTitle: String  { String(localized: "heatwave.notif_title") }
    static var heatwaveNotifBody: String   { String(localized: "heatwave.notif_body") }
    static var heatwaveBannerTitle: String { String(localized: "heatwave.banner_title") }
    static var heatwaveBannerBody: String  { String(localized: "heatwave.banner_body") }

    // MARK: - Stats / StatsView

    static var statsTitle: String       { String(localized: "stats.title") }
    static var statsTrends: String      { String(localized: "stats.trends") }
    static var statsWeekly: String      { String(localized: "stats.weekly") }
    static var statsAlcohol: String     { String(localized: "stats.alcohol") }
    static var statsAvgPerDay: String   { String(localized: "stats.avg_per_day") }
    static var statsActiveDays: String  { String(localized: "stats.active_days") }
    static var statsAlcoholWeek: String { String(localized: "stats.alcohol_week") }

    // MARK: - Profil / ProfileView

    static var profileTitle: String         { String(localized: "profile.title") }
    static var profileSubtitle: String      { String(localized: "profile.subtitle") }
    static var profileDailyGoal: String     { String(localized: "profile.daily_goal") }
    static var profileNotifications: String { String(localized: "profile.notifications") }
    static var profileTheme: String         { String(localized: "profile.theme") }
    static var profileSystem: String        { String(localized: "profile.system") }
    static var profileLight: String         { String(localized: "profile.light") }
    static var profileDark: String          { String(localized: "profile.dark") }
    static var profileVersion: String       { String(localized: "profile.version") }

    // MARK: - Icônes alternatives / AppIconManager

    static var appIconSectionTitle: String  { String(localized: "profile.section.app_icon") }
    static var appIconPickerTitle: String   { String(localized: "profile.app_icon.title") }
    static var appIconSubtitle: String      { String(localized: "profile.app_icon.subtitle") }
    static var appIconFreeLabel: String     { String(localized: "profile.app_icon.free_label") }
    static var appIconPremiumLabel: String  { String(localized: "profile.app_icon.premium_label") }
    static var appIconDefaultBadge: String  { String(localized: "profile.app_icon.default_badge") }
    static var appIconActiveBadge: String   { String(localized: "profile.app_icon.active_badge") }
    static var appIconUnlockHint: String    { String(localized: "profile.app_icon.unlock_hint") }
    static var appIconChangedToast: String  { String(localized: "profile.app_icon.changed_toast") }

    // MARK: - Premium / PremiumSheet

    static var premiumTitle: String       { String(localized: "premium.title") }
    static var premiumSubtitle: String    { String(localized: "premium.subtitle") }
    static var premiumMonthly: String     { String(localized: "premium.monthly") }
    static var premiumYearly: String      { String(localized: "premium.yearly") }
    static var premiumBestValue: String   { String(localized: "premium.best_value") }
    static var premiumCTA: String         { String(localized: "premium.cta") }
    static var premiumLater: String       { String(localized: "premium.later") }
    static var premiumLegal: String       { String(localized: "premium.legal") }
    static var premiumActive: String      { String(localized: "premium.active") }
    static var premiumAllUnlocked: String { String(localized: "premium.all_unlocked") }
    static var premiumUpgrade: String     { String(localized: "premium.upgrade") }
    static var premiumUpgradeSub: String  { String(localized: "premium.upgrade_sub") }

    static var premiumFeatures: [(title: String, subtitle: String, symbol: String)] {
        [
            (String(localized: "premium.feature1.title"), String(localized: "premium.feature1.subtitle"), "medal.fill"),
            (String(localized: "premium.feature2.title"), String(localized: "premium.feature2.subtitle"), "chart.bar.fill"),
            (String(localized: "premium.feature3.title"), String(localized: "premium.feature3.subtitle"), "clock.fill"),
            (String(localized: "premium.feature4.title"), String(localized: "premium.feature4.subtitle"), "paintbrush.fill"),
            (String(localized: "premium.feature5.title"), String(localized: "premium.feature5.subtitle"), "bell.badge.fill"),
            (String(localized: "premium.feature6.title"), String(localized: "premium.feature6.subtitle"), "widget.small.badge.plus"),
        ]
    }

    // MARK: - Premium Launch CTA (section bêta "Me prévenir")

    static var premiumLaunchFreeTitle: String    { String(localized: "premium.launch.free_title") }
    static var premiumLaunchBetaBadge: String    { String(localized: "premium.launch.beta_badge") }
    static var premiumLaunchComingSoon: String   { String(localized: "premium.launch.coming_soon") }
    static var premiumLaunchMessage: String      { String(localized: "premium.launch.message") }
    static var premiumLaunchNotifLoading: String { String(localized: "premium.launch.notify_loading") }
    static var premiumLaunchNotifReg: String     { String(localized: "premium.launch.notify_registered") }
    static var premiumLaunchNotifDenied: String  { String(localized: "premium.launch.notify_denied") }
    static var premiumLaunchNotifAlready: String { String(localized: "premium.launch.notify_already") }
    static var premiumLaunchNotifCta: String     { String(localized: "premium.launch.notify_cta") }
    static var premiumLaunchDismiss: String      { String(localized: "premium.launch.dismiss") }

    // Alerte permission refusée
    static var premiumLaunchAlertTitle: String        { String(localized: "premium.launch.alert.title") }
    static var premiumLaunchAlertOpenSettings: String { String(localized: "premium.launch.alert.open_settings") }
    static var premiumLaunchAlertCancel: String       { String(localized: "premium.launch.alert.cancel") }
    static var premiumLaunchAlertMessage: String      { String(localized: "premium.launch.alert.message") }

    // Notification de confirmation d'inscription
    static var premiumLaunchNotifConfirmTitle: String { String(localized: "premium.launch.notif.title") }
    static var premiumLaunchNotifConfirmBody: String  { String(localized: "premium.launch.notif.body") }

    // Accessibilité bouton "Me prévenir"
    static var premiumLaunchA11yLabelLoading: String    { String(localized: "premium.launch.a11y.label.loading") }
    static var premiumLaunchA11yLabelRegistered: String { String(localized: "premium.launch.a11y.label.registered") }
    static var premiumLaunchA11yLabelDenied: String     { String(localized: "premium.launch.a11y.label.denied") }
    static var premiumLaunchA11yLabelIdle: String       { String(localized: "premium.launch.a11y.label.idle") }
    static var premiumLaunchA11yValueLoading: String    { String(localized: "premium.launch.a11y.value.loading") }
    static var premiumLaunchA11yValueRegistered: String { String(localized: "premium.launch.a11y.value.registered") }
    static var premiumLaunchA11yValueDenied: String     { String(localized: "premium.launch.a11y.value.denied") }
    static var premiumLaunchA11yValueAlready: String    { String(localized: "premium.launch.a11y.value.already") }

    // MARK: - Défis / ChallengesView

    static var challengesTitle: String    { String(localized: "challenges.title") }
    static var challengesSub: String      { String(localized: "challenges.sub") }
    static var challengesDayTitle: String { String(localized: "challenges.day_title") }

    // MARK: - Succès / AchievementsView

    static var achievementsTitle: String    { String(localized: "achievements.title") }
    static var achievementsSub: String      { String(localized: "achievements.sub") }
    static var achievementsUnlocked: String { String(localized: "achievements.unlocked") }

    // MARK: - Notifications rappels

    static var notifReminderTitle: String { String(localized: "notif.reminder_title") }

    static var notifReminderMessages: [String] {
        [
            String(localized: "notif.reminder1"),
            String(localized: "notif.reminder2"),
            String(localized: "notif.reminder3"),
            String(localized: "notif.reminder4"),
        ]
    }

    static var notifMidnightBody: String { String(localized: "notif.midnight_body") }

    // MARK: - Onboarding

    static var onboardingWelcome: String  { String(localized: "onboarding.welcome") }
    static var onboardingStart: String    { String(localized: "onboarding.start") }
    static var onboardingName: String     { String(localized: "onboarding.name") }
    static var onboardingNameSub: String  { String(localized: "onboarding.name_sub") }
    static var onboardingContinue: String { String(localized: "onboarding.continue") }

    // MARK: - XP / ProfileHeaderView

    /// "%d XP cumulés" — ex. "1 250 XP cumulés"
    /// Format : %d → totalXP
    static var xpTotalCumulated: String { String(localized: "xp.total_cumulated") }

    /// "encore %d XP → %@" — ex. "encore 50 XP → Rivière"
    /// Format : %1$d → XP restants, %2$@ → nom du prochain niveau
    static var xpUntilNextLevel: String { String(localized: "xp.until_next_level") }

    // MARK: - Live Activity — labels localisés passés dans ContentState

    static var liveActivityToday:             String { String(localized: "live_activity.today") }
    static var liveActivityGoalReached:       String { String(localized: "live_activity.goal_reached") }
    static var liveActivityLabelGoal:         String { String(localized: "live_activity.label.goal") }
    static var liveActivityGoalReachedShort:  String { String(localized: "live_activity.goal_reached_checkmark") }
    static var liveActivityLabelStreak:       String { String(localized: "live_activity.label.streak") }
    static var liveActivityLabelSober:        String { String(localized: "live_activity.label.sober") }
    static var liveActivityUnitDays:          String { String(localized: "live_activity.unit.days") }

    // MARK: - Sliders — bornes min/max localisées

    static var sliderHeightMin: String { String(localized: "slider.height.min") }
    static var sliderHeightMax: String { String(localized: "slider.height.max") }
    static var sliderWeightMin: String { String(localized: "slider.weight.min") }
    static var sliderWeightMax: String { String(localized: "slider.weight.max") }
    static var sliderWaterMin:  String { String(localized: "slider.water.min") }
    static var sliderWaterMax:  String { String(localized: "slider.water.max") }
    static var sliderGoalMin:   String { String(localized: "slider.goal.min") }
    static var sliderGoalMax:   String { String(localized: "slider.goal.max") }

    // MARK: - Widget tags (11 états)

    static var widgetTag: [(tag: String, symbol: String)] {
        [
            (String(localized: "widget.tag0"),  "moon.stars.fill"),
            (String(localized: "widget.tag1"),  "drop.fill"),
            (String(localized: "widget.tag2"),  "sunrise.fill"),
            (String(localized: "widget.tag3"),  "bolt.fill"),
            (String(localized: "widget.tag4"),  "water.waves"),
            (String(localized: "widget.tag5"),  "flame.fill"),
            (String(localized: "widget.tag6"),  "target"),
            (String(localized: "widget.tag7"),  "timer"),
            (String(localized: "widget.tag8"),  "star.fill"),
            (String(localized: "widget.tag9"),  "sparkles"),
            (String(localized: "widget.tag10"), "trophy.fill"),
        ]
    }
}
