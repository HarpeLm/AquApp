import SwiftUI
import SwiftData

// MARK: - Période graphique

enum ChartPeriod: String, CaseIterable {
    case week  = "week"
    case month = "month"
    case all   = "all"

    var label: String {
        switch self {
        case .week:  return String(localized: "stats.period.week")
        case .month: return String(localized: "stats.period.month")
        case .all:   return String(localized: "stats.period.all")
        }
    }

    var isPro: Bool { self == .month || self == .all }
}

// MARK: - Helpers de formatage sûrs
// String(format:) plante silencieusement (nombre aberrant, pas de crash net)
// si le specifier de la traduction (%d/%f) ne correspond pas au type fourni
// (String). Cette fonction insère la valeur sans dépendre du specifier —
// utilisée par toutes les vues de ce fichier qui affichent l'objectif.

private func insertValue(_ value: String, into key: String) -> String {
    let template = String(localized: String.LocalizationValue(key))
    if template.contains("%@") {
        return template.replacingOccurrences(of: "%@", with: value)
    }
    for specifier in ["%d", "%1$d", "%.0f", "%.1f"] {
        if template.contains(specifier) {
            return template.replacingOccurrences(of: specifier, with: value)
        }
    }
    return "\(template) \(value)"
}

// MARK: - StatsView

struct StatsView: View {

    @EnvironmentObject var store:    AppDataStore
    @EnvironmentObject var storeKit: StoreKitManager
    @AppStorage("isPremiumUser") private var isPremiumUser: Bool = false
    @State private var showPremiumSheet  = false
    @State private var selectedPeriod:   ChartPeriod = .week

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

                    // MARK: Header
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .center, spacing: 8) {
                            Text(L10n.statsTitle)
                                .font(.system(size: 32, weight: .bold))
                            Image(systemName: "chart.bar.fill")
                                .font(.system(size: 26, weight: .medium))
                                .foregroundColor(Color(hex: "4DA8F5"))
                                .frame(width: 32, height: 32)
                        }
                        Text(L10n.statsTrends)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)

                    // MARK: Graphique avec sélecteur de période
                    ChartCard(
                        period:        selectedPeriod,
                        isPremiumUser: isPremiumUser,
                        store:         store,
                        onSelectPeriod: { period in
                            if period.isPro && !isPremiumUser {
                                showPremiumSheet = true
                            } else {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    selectedPeriod = period
                                }
                            }
                        }
                    )
                    .padding(.horizontal)

                    // MARK: Grille de contributions (gratuit)
                    HydrationGridView()
                        .environmentObject(store)
                        .padding(.horizontal)

                    // MARK: Stats rapides
                    HStack(spacing: 12) {
                        MetricCard(
                            sfSymbol:    "drop.fill",
                            symbolColor: Color(hex: "4DA8F5"),
                            value:       UnitFormatter.volumeNumber(store.avgMlPerDay),
                            unit:        UnitFormatter.volumeUnitSymbol,
                            label:       L10n.statsAvgPerDay
                        )
                        MetricCard(
                            sfSymbol:    "calendar.badge.checkmark",
                            symbolColor: .green,
                            value:       "\(store.activeDaysTotal)",
                            unit:        String(localized: "stats.days_unit"),
                            label:       L10n.statsActiveDays
                        )
                        MetricCard(
                            sfSymbol:    "wineglass.fill",
                            symbolColor: .purple,
                            value:       String(format: "%.1f", store.weekAlcoholLiters),
                            unit:        "L",
                            label:       L10n.statsAlcoholWeek
                        )
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 32)
            }
            .background(Color("AppBackground"))
            .onChange(of: scrollToTopID) { _, _ in
                withAnimation(.easeOut(duration: 0.3)) { proxy.scrollTo("top") }
            }
            } // ScrollViewReader
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showPremiumSheet) {
            PremiumSheet(isPremiumUser: $isPremiumUser, isPresented: $showPremiumSheet)
                .environmentObject(storeKit)
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(24)
        }
    }
}

// MARK: - ChartCard (conteneur période + graphique)

private struct ChartCard: View {
    let period:        ChartPeriod
    let isPremiumUser: Bool
    let store:         AppDataStore
    let onSelectPeriod: (ChartPeriod) -> Void

    // Données selon la période sélectionnée
    var chartData: [ChartBar] {
        switch period {
        case .week:  return weekData
        case .month: return monthData
        case .all:   return allTimeData
        }
    }

    // ── 7 jours ──────────────────────────────────────────────────────────────
    private var weekData: [ChartBar] {
        store.last7DaysWater.map {
            ChartBar(label: $0.day, ml: $0.ml, isToday: $0.day == todayAbbr())
        }
    }

    // ── Mois courant (données semaine par semaine) ────────────────────────────
    private var monthData: [ChartBar] {
        let calendar = Calendar.current
        let now      = Date()
        return (0..<4).reversed().map { weekOffset -> ChartBar in
            let weekEnd   = calendar.date(byAdding: .day, value: -(weekOffset * 7), to: now)!
            let weekStart = calendar.date(byAdding: .day, value: -6, to: weekEnd)!
            let (start, end) = (calendar.startOfDay(for: weekStart),
                                calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: weekEnd))!)
            let totalMl = store.weekTotalMl(from: start, to: end)
            let label   = weekLabel(weekEnd: weekEnd, weekOffset: weekOffset)
            return ChartBar(label: label, ml: totalMl, isToday: weekOffset == 0)
        }
    }

    // ── Depuis toujours (groupé par mois) ────────────────────────────────────
    private var allTimeData: [ChartBar] {
        let calendar  = Calendar.current
        let formatter = DateFormatter()
        formatter.locale     = Locale.current
        formatter.dateFormat = "MMM"

        let now = Date()
        return (0..<12).reversed().compactMap { offset -> ChartBar? in
            guard let monthDate  = calendar.date(byAdding: .month, value: -offset, to: now),
                  let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: monthDate)),
                  let monthEnd   = calendar.date(byAdding: .month, value: 1, to: monthStart)
            else { return nil }

            let totalMl = store.weekTotalMl(from: monthStart, to: monthEnd)
            let label   = String(formatter.string(from: monthDate).prefix(3).capitalized)
            return ChartBar(label: label, ml: totalMl, isToday: offset == 0)
        }
    }

    // ── Helpers ──────────────────────────────────────────────────────────────
    private func todayAbbr() -> String {
        let f = DateFormatter()
        f.locale     = Locale.current
        f.dateFormat = "EEE"
        return String(f.string(from: Date()).prefix(3).capitalized)
    }

    private func weekLabel(weekEnd: Date, weekOffset: Int) -> String {
        if weekOffset == 0 { return String(localized: "stats.week.label") }
        let f = DateFormatter()
        f.locale     = Locale.current
        f.dateFormat = "dd/MM"
        return f.string(from: weekEnd)
    }

    // ── Titre dynamique selon la période ────────────────────────────────────
    private var chartTitle: String {
        switch period {
        case .week:  return String(localized: "stats.chart.title.week")
        case .month: return String(localized: "stats.chart.title.month")
        case .all:   return String(localized: "stats.chart.title.all")
        }
    }

    // ── Légende objectif dynamique ────────────────────────────────────────────
    // ⚠️ Ne pas utiliser String(format:) avec une String en argument : si la
    // traduction contient %d au lieu de %@ (cas vu avec "Objectif %d ml"),
    // String(format:) ne plante pas — il réinterprète les bits du pointeur
    // de la String comme un entier, produisant un nombre aberrant à l'écran.
    // On insère donc la valeur nous-mêmes, insensible au specifier utilisé
    // dans la traduction.
    private var goalLegend: String {
        switch period {
        case .week:
            return insertValue(UnitFormatter.volume(store.dailyGoalMl), into: "stats.goal_label")
        case .month:
            return insertValue(UnitFormatter.volume(store.dailyGoalMl * 7), into: "stats.goal_week_label")
        case .all:
            return insertValue(UnitFormatter.volume(store.dailyGoalMl * 30), into: "stats.goal_month_label")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            // ── Header carte ──────────────────────────────────────────────────
            HStack(alignment: .center, spacing: 8) {
                Text(chartTitle)
                    .font(.system(size: 17, weight: .bold))
                    .lineLimit(1)
                    .layoutPriority(1)

                Spacer(minLength: 4)

                // Sélecteur de période
                HStack(spacing: 0) {
                    ForEach(ChartPeriod.allCases, id: \.self) { p in
                        PeriodTab(
                            period:        p,
                            isSelected:    period == p,
                            isPremiumUser: isPremiumUser,
                            onTap:         { onSelectPeriod(p) }
                        )
                    }
                }
                .background(Color(UIColor.systemGray6))
                .cornerRadius(10)
                .fixedSize()
            }

            // ── Graphique ─────────────────────────────────────────────────────
            AdaptiveBarChart(
                data:   chartData,
                goal:   store.dailyGoalMl,
                period: period
            )
            .transition(.opacity.combined(with: .scale(scale: 0.97)))
            .id(period)

            // ── Légende objectif (adaptée à la période) ──────────────────────
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(hex: "2B87E8"))
                    .frame(width: 16, height: 3)
                Text(goalLegend)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
        .padding(20)
        .background(Color("AppCardBackground"))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: period)
    }
}

// MARK: - Onglet période (bouton du sélecteur)

private struct PeriodTab: View {
    let period:        ChartPeriod
    let isSelected:    Bool
    let isPremiumUser: Bool
    let onTap:         () -> Void

    private var isLocked: Bool { period.isPro && !isPremiumUser }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 3) {
                Text(period.label)
                    .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                    .foregroundColor(
                        isSelected
                            ? .white
                            : (isLocked ? Color(UIColor.systemGray3) : .primary)
                    )

                if isLocked {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.orange)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                isSelected
                    ? AnyShapeStyle(LinearGradient(
                        colors: [Color(hex: "4DA8F5"), Color(hex: "2B87E8")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                      ))
                    : AnyShapeStyle(Color.clear)
            )
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(period.label + (isLocked ? String(localized: "stats.premium_required") : ""))
    }
}

// MARK: - Modèle barre

private struct ChartBar: Identifiable {
    let id      = UUID()
    let label:    String
    let ml:       Double
    let isToday:  Bool
}

// MARK: - Graphique adaptatif

private struct AdaptiveBarChart: View {
    let data:   [ChartBar]
    let goal:   Double
    let period: ChartPeriod

    private var effectiveGoal: Double {
        switch period {
        case .week:  return goal
        case .month: return goal * 7
        case .all:   return goal * 30
        }
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: period == .all ? 4 : 8) {
            ForEach(data) { bar in
                BarColumn(
                    bar:    bar,
                    goal:   effectiveGoal,
                    period: period
                )
            }
        }
        .frame(height: 120)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(localized: "accessibility.chart_label"))
    }
}

// MARK: - Colonne barre

private struct BarColumn: View {
    let bar:    ChartBar
    let goal:   Double
    let period: ChartPeriod

    private var ratio: CGFloat {
        guard goal > 0, bar.ml > 0 else { return 0 }
        return min(CGFloat(bar.ml / goal), 1.0)
    }

    private var goalReached: Bool { bar.ml >= goal }

    var body: some View {
        VStack(spacing: 4) {
            GeometryReader { geo in
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    RoundedRectangle(cornerRadius: 5)
                        .fill(
                            goalReached
                            ? AnyShapeStyle(LinearGradient(
                                colors: [Color(hex: "4DA8F5"), Color(hex: "2B87E8")],
                                startPoint: .top, endPoint: .bottom
                              ))
                            : AnyShapeStyle(LinearGradient(
                                colors: [Color(hex: "B8D9F8"), Color(hex: "D6EAFC")],
                                startPoint: .top, endPoint: .bottom
                              ))
                        )
                        .frame(
                            height: bar.ml == 0
                                ? 4
                                : max(geo.size.height * ratio, 8)
                        )
                        .overlay(
                            bar.isToday
                                ? RoundedRectangle(cornerRadius: 5)
                                    .stroke(Color(hex: "4DA8F5").opacity(0.5), lineWidth: 1.5)
                                : nil
                        )
                }
            }
            .frame(height: 100)

            Text(bar.label)
                .font(.system(size: period == .all ? 9 : 11))
                .foregroundColor(bar.isToday ? Color(hex: "2B87E8") : .secondary)
                .fontWeight(bar.isToday ? .bold : .regular)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .frame(height: 20)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(bar.isToday
            ? String(format: String(localized: "accessibility.chart_bar_today"), bar.label)
            : bar.label)
        .accessibilityValue(bar.ml == 0
            ? String(localized: "accessibility.chart_bar_empty")
            : String(format: String(localized: "accessibility.chart_bar_value"),
                     Int(bar.ml), Int(goal), goalReached
                        ? String(localized: "accessibility.chart_bar_goal_reached")
                        : ""))
    }
}

// MARK: - Graphique 7 jours (conservé pour rétrocompatibilité)

struct WeeklyChartCard: View {
    let data: [(day: String, ml: Double)]
    let goal: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.statsWeekly)
                .font(.system(size: 17, weight: .bold))

            HStack(alignment: .bottom, spacing: 8) {
                ForEach(data, id: \.day) { item in
                    VStack(spacing: 6) {
                        GeometryReader { geo in
                            VStack(spacing: 0) {
                                Spacer(minLength: 0)
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(
                                        item.ml >= goal
                                        ? LinearGradient(
                                            colors: [Color(hex: "4DA8F5"), Color(hex: "2B87E8")],
                                            startPoint: .top, endPoint: .bottom)
                                        : LinearGradient(
                                            colors: [Color(hex: "B8D9F8"), Color(hex: "D6EAFC")],
                                            startPoint: .top, endPoint: .bottom)
                                    )
                                    .frame(
                                        height: item.ml == 0
                                            ? 4
                                            : max(min(geo.size.height * (item.ml / goal), geo.size.height), 8)
                                    )
                            }
                        }
                        .frame(height: 120)
                        .clipped()

                        Text(item.day)
                            .font(.system(size: 12))
                            .foregroundColor(
                                item.day == currentDayAbbr()
                                ? Color(hex: "2B87E8") : .secondary
                            )
                            .fontWeight(item.day == currentDayAbbr() ? .bold : .regular)
                    }
                }
            }

            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(hex: "2B87E8"))
                    .frame(width: 16, height: 3)
                Text(insertValue("\(Int(goal))", into: "stats.goal_label"))
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
        .padding(20)
        .background(Color("AppCardBackground"))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    private func currentDayAbbr() -> String {
        let formatter = DateFormatter()
        formatter.locale     = Locale.current
        formatter.dateFormat = "EEE"
        return String(formatter.string(from: Date()).prefix(3).capitalized)
    }
}

// MARK: - Carte Analyse Alcool PREMIUM

struct AlcoolAnalysisCard: View {
    let isPremium:   Bool
    let weekLiters:  Double
    let monthLiters: Double
    let onUnlock:    () -> Void

    var tendanceText: String {
        if weekLiters == 0  { return String(localized: "stats.alcohol_none") }
        if weekLiters < 0.5 { return String(localized: "stats.alcohol_low") }
        if weekLiters < 1.5 { return String(localized: "stats.alcohol_moderate") }
        return String(localized: "stats.alcohol_high")
    }

    var tendanceColor: Color {
        if weekLiters == 0  { return .green }
        if weekLiters < 0.5 { return Color(hex: "4DA8F5") }
        if weekLiters < 1.5 { return .orange }
        return .red
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(L10n.statsAlcohol)
                    .font(.system(size: 17, weight: .bold))
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                    Text(String(localized: "premium.badge"))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.orange)
                .cornerRadius(6)
            }
            .padding(20)

            Divider()

            if isPremium {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 16) {
                        StatPill(
                            label: String(localized: "stats.this_week"),
                            value: String(format: "%.2f L", weekLiters),
                            color: .purple
                        )
                        StatPill(
                            label: String(localized: "stats.this_month"),
                            value: String(format: "%.2f L", monthLiters),
                            color: Color(hex: "4DA8F5")
                        )
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text(String(localized: "stats.trend"))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                        HStack(spacing: 6) {
                            Circle().fill(tendanceColor).frame(width: 8, height: 8)
                            Text(tendanceText).font(.system(size: 14)).foregroundColor(.primary)
                        }
                    }
                }
                .padding(20)
            } else {
                VStack(spacing: 16) {
                    ZStack {
                        Circle().fill(Color(UIColor.systemGray5)).frame(width: 64, height: 64)
                        Image(systemName: "lock.fill").font(.system(size: 26)).foregroundColor(.gray)
                    }
                    Text(String(localized: "stats.alcohol_locked"))
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Button(action: onUnlock) {
                        HStack(spacing: 8) {
                            Image(systemName: "crown.fill").font(.system(size: 16)).foregroundColor(.white)
                            Text(L10n.premiumCTA).font(.system(size: 16, weight: .semibold)).foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity).frame(height: 50)
                        .background(LinearGradient(
                            colors: [Color(hex: "FF8C00"), Color(hex: "E05F00")],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                        .cornerRadius(14)
                    }
                }
                .padding(20)
            }
        }
        .background(Color("AppCardBackground"))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

// MARK: - StatPill

private struct StatPill: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value).font(.system(size: 20, weight: .bold)).foregroundColor(color)
            Text(label).font(.system(size: 12)).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 12)
        .background(color.opacity(0.08)).cornerRadius(12)
    }
}

// MARK: - Carte métrique

struct MetricCard: View {
    let sfSymbol:    String
    let symbolColor: Color
    let value:       String
    let unit:        String
    let label:       String

    var body: some View {
        VStack(alignment: .center, spacing: 10) {
            ZStack {
                Circle().fill(symbolColor.opacity(0.12)).frame(width: 40, height: 40)
                Image(systemName: sfSymbol)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(symbolColor)
                    .accessibilityHidden(true)
            }
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 24, weight: .bold))
                    .minimumScaleFactor(0.7).lineLimit(1)
                Text(unit)
                    .font(.system(size: 12)).foregroundColor(.secondary).minimumScaleFactor(0.8)
            }
            Text(label)
                .font(.system(size: 12)).foregroundColor(.secondary)
                .multilineTextAlignment(.center).minimumScaleFactor(0.8).lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16).padding(.horizontal, 8)
        .background(Color("AppCardBackground"))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue("\(value) \(unit)")
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: WaterEntry.self, WaterAlcoholEntry.self, DayRecord.self,
        configurations: config
    )
    let store    = AppDataStore(modelContext: container.mainContext)
    let storeKit = StoreKitManager()
    StatsView()
        .environmentObject(store)
        .environmentObject(storeKit)
        .modelContainer(container)
}
