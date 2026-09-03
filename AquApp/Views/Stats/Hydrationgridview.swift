import SwiftUI
import SwiftData

// MARK: - HydrationGridView
// Grille annuelle "façon GitHub contributions" montrant les jours où
// l'objectif d'hydratation a été atteint sur les 365 derniers jours.
// Entièrement gratuite — remplace l'ancienne carte Premium AlcoolAnalysisCard
// dans StatsView.
//
// Colonnes = semaines (53), lignes = jours (Lun → Dim), teinte bleue selon
// le ratio net/objectif du jour. Fond sombre pour matcher le style GitHub,
// quel que soit le thème choisi dans l'app (cohérent avec l'esthétique
// "carte sombre" déjà utilisée dans WrappedView).
//
// Interactions :
//   - Ouverture : la grille se scroll automatiquement sur la semaine
//     courante (sinon l'utilisateur atterrit sur J-364, peu utile).
//   - La case du jour courant a un anneau distinctif.
//   - Tap sur une case : popup avec la date + le volume du jour, et une
//     onde animée façon "goutte d'eau" se propage depuis la case tapée.

struct HydrationGridView: View {

    @EnvironmentObject var store: AppDataStore

    /// [jour startOfDay → ratio net/objectif] — calculé une seule fois au
    /// chargement puis rafraîchi seulement quand l'eau du jour change
    /// (voir `.onAppear` et `.onChange` dans `body`). Une computed property
    /// lue directement dans `body` refetchait SwiftData à chaque cycle de
    /// layout et provoquait un crash dans SwiftData/AttributeGraph.
    @State private var ratiosByDay: [Date: Double] = [:]

    /// Jour actuellement sélectionné (tap) — pilote à la fois le popup de
    /// détail et le déclenchement de l'onde animée.
    @State private var selectedDay: Date? = nil

    /// Centre de l'onde en cours (coordonnées de grille : semaine, jour de
    /// la semaine) — nil quand aucune onde n'est active.
    @State private var rippleOrigin: (week: Int, dow: Int)? = nil

    /// Incrémenté à chaque tap pour donner un identifiant unique à
    /// l'animation d'onde, garantissant son redéclenchement même si on
    /// retape la même case.
    @State private var rippleID: Int = 0

    private let calendar = Calendar.current
    private let weeksCount = 53
    private let cellSize: CGFloat = 11
    private let cellSpacing: CGFloat = 3
    private let dowLabels: [Int: String] = [
        1: String(localized: "grid.day.mon"),
        3: String(localized: "grid.day.wed"),
        5: String(localized: "grid.day.fri"),
    ]

    /// Premier jour affiché (dimanche englobant J-364) pour aligner la grille
    /// exactement comme GitHub — colonnes alignées sur des semaines complètes.
    private var gridStart: Date {
        let today = calendar.startOfDay(for: Date())
        let start = calendar.date(byAdding: .day, value: -(weeksCount * 7 - 1), to: today)!
        let startDow = calendar.component(.weekday, from: start) - 1 // 0 = dimanche
        return calendar.date(byAdding: .day, value: -startDow, to: start)!
    }

    private var totalGoalDaysLastYear: Int {
        ratiosByDay.values.filter { $0 >= 1.0 }.count
    }

    /// Texte du résumé — évite `String(format:)` (qui peut crasher si un
    /// spécificateur `%@`/`%d` ne correspond pas exactement à ce qui est
    /// stocké dans le catalogue de localisation) au profit d'un simple
    /// remplacement de token, robuste quel que soit le format exact de la
    /// chaîne traduite.
    private var summaryText: String {
        let template = String(localized: "grid.summary")
        if template.contains("%d") {
            return template.replacingOccurrences(of: "%d", with: "\(totalGoalDaysLastYear)")
        }
        // Filet de sécurité si jamais le token attendu diffère.
        return "\(template) \(totalGoalDaysLastYear)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            header

            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    gridBody
                        .padding(.horizontal, 20)
                }
                .padding(.bottom, 12)
                .onAppear {
                    // Scroll auto vers la semaine courante — sans animation
                    // pour que ça n'aie pas l'air d'un "saut" au chargement.
                    scrollToToday(proxy: proxy, animated: false)
                }
            }

            legend
        }
        .background(Color(hex: "0D1117"))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "grid.accessibility_label"))
        .accessibilityValue(summaryText)
        .onAppear {
            // Calcul initial — une seule fois au chargement de la vue.
            //
            // Volontairement PAS `.task` : dans l'environnement Preview,
            // un fetch SwiftData déclenché depuis une Task async (donc
            // potentiellement hors MainActor selon le contexte d'exécution)
            // provoque un crash reproductible dans SwiftData/AttributeGraph
            // (SIGTRAP, cf. stack `contributionRatios` ← `Task`). `.onAppear`
            // s'exécute de manière synchrone sur le MainActor, ce que
            // `ModelContext.fetch` exige strictement.
            guard ratiosByDay.isEmpty else { return }
            refreshRatios()
        }
        .onChange(of: store.todayWaterMl) { _, _ in
            // Live refresh : dès que l'eau nette du jour change (ajout,
            // suppression, compensation alcool), on recalcule uniquement
            // le ratio du jour courant sans refaire un fetch complet des
            // 365 jours — bien moins coûteux qu'un recalcul intégral.
            refreshToday()
        }
        .onChange(of: store.dailyGoalMl) { _, _ in
            // L'objectif a changé (réglage utilisateur) → le ratio du
            // jour courant doit être recalculé en conséquence.
            refreshToday()
        }
        .overlay(alignment: .top) {
            if let day = selectedDay {
                DayDetailPopup(day: day, ratio: ratiosByDay[day], store: store) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedDay = nil
                    }
                }
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(1)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text(summaryText)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color.white.opacity(0.85))
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 12)
    }

    // MARK: - Legend

    private var legend: some View {
        HStack(spacing: 5) {
            Spacer()
            Text(String(localized: "grid.legend.less"))
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.45))
            ForEach(legendSwatches, id: \.self) { color in
                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: 10, height: 10)
            }
            Text(String(localized: "grid.legend.more"))
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.45))
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }

    /// Recalcule la grille complète (365 jours) — utilisé au premier
    /// affichage uniquement, coûteux car il fetch les DayRecord historiques.
    /// Doit rester synchrone et appelé sur le MainActor (voir `.onAppear`).
    private func refreshRatios() {
        ratiosByDay = store.contributionRatios(days: 365)
        let today = calendar.startOfDay(for: Date())
        print("🔍 [HydrationGrid] refreshRatios — today=\(today) ratio=\(String(describing: ratiosByDay[today])) todayWaterMl=\(store.todayWaterMl) goal=\(store.effectiveGoalMl)")
    }

    /// Recalcule uniquement le ratio du jour courant — appelé en live
    /// après chaque mutation d'eau/alcool/objectif, sans refetch complet.
    private func refreshToday() {
        let today = calendar.startOfDay(for: Date())
        let goal  = store.effectiveGoalMl
        guard goal > 0 else { return }
        ratiosByDay[today] = store.todayWaterMl / goal
        print("🔍 [HydrationGrid] refreshToday — today=\(today) ratio=\(ratiosByDay[today]!) todayWaterMl=\(store.todayWaterMl) goal=\(goal)")
    }

    /// Fait défiler la grille jusqu'à la semaine courante.
    private func scrollToToday(proxy: ScrollViewProxy, animated: Bool) {
        let today = calendar.startOfDay(for: Date())
        // L'identifiant utilisé par ForEach est l'offset de semaine — on le
        // retrouve en comptant le nombre de jours entre gridStart et
        // aujourd'hui, divisé par 7.
        let daysSinceStart = calendar.dateComponents([.day], from: gridStart, to: today).day ?? 0
        let weekOffset = max(0, daysSinceStart / 7)
        if animated {
            withAnimation(.easeInOut(duration: 0.4)) {
                proxy.scrollTo(weekOffset, anchor: .trailing)
            }
        } else {
            proxy.scrollTo(weekOffset, anchor: .trailing)
        }
    }

    // MARK: - Corps de la grille

    private var gridBody: some View {
        let columns = weekColumns()
        let today = calendar.startOfDay(for: Date())

        return HStack(alignment: .top, spacing: cellSpacing) {

            // Colonne des labels de jour (Lun/Mer/Ven)
            VStack(alignment: .leading, spacing: cellSpacing) {
                Color.clear.frame(height: 12) // aligne avec les labels de mois
                ForEach(0..<7, id: \.self) { dow in
                    Text(dowLabels[dow] ?? "")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.4))
                        .frame(width: 22, height: cellSize, alignment: .leading)
                }
            }

            ForEach(Array(columns.enumerated()), id: \.offset) { weekIndex, week in
                VStack(alignment: .leading, spacing: cellSpacing) {
                    Text(week.monthLabel ?? "")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.4))
                        .frame(height: 12, alignment: .leading)
                        .fixedSize()

                    ForEach(0..<7, id: \.self) { dow in
                        if let day = week.days[dow] {
                            DayCell(
                                ratio: ratiosByDay[day],
                                isFuture: day > today,
                                isToday: day == today,
                                cellSize: cellSize,
                                rippleDelay: rippleDelay(week: weekIndex, dow: dow),
                                rippleID: rippleID,
                                rippleActive: rippleOrigin != nil
                            )
                            .onTapGesture {
                                handleTap(day: day, week: weekIndex, dow: dow)
                            }
                        } else {
                            Color.clear.frame(width: cellSize, height: cellSize)
                        }
                    }
                }
                .id(weekIndex)
            }
        }
    }

    /// Délai de départ de l'onde pour une case donnée, en fonction de sa
    /// distance (euclidienne, en unités de case) au point d'origine du tap.
    /// Plus la case est loin, plus l'onde y arrive tard — effet concentrique.
    private func rippleDelay(week: Int, dow: Int) -> Double {
        guard let origin = rippleOrigin else { return 0 }
        let dx = Double(week - origin.week)
        let dy = Double(dow - origin.dow)
        let distance = (dx * dx + dy * dy).squareRoot()
        return distance * 0.035
    }

    /// Gère le tap sur une case : affiche le popup de détail et déclenche
    /// l'onde animée depuis cette case.
    private func handleTap(day: Date, week: Int, dow: Int) {
        HapticManager.shared.selectionTap()

        rippleID += 1
        rippleOrigin = (week, dow)

        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            selectedDay = day
        }

        // L'onde se termine après un court délai — on la désactive pour
        // permettre de la redéclencher proprement au prochain tap.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            rippleOrigin = nil
        }
    }

    private var legendSwatches: [Color] {
        [
            Color(hex: "161B22"),
            Color(hex: "0C2D48"),
            Color(hex: "0D4F8B"),
            Color(hex: "1F6FEB"),
            Color(hex: "58A6FF"),
        ]
    }

    // MARK: - Construction des colonnes semaine par semaine

    private struct WeekColumn {
        var days: [Int: Date] = [:]       // dow (0=dim) → date
        var monthLabel: String? = nil     // affiché seulement au 1er jour du mois visible dans la semaine
    }

    private func weekColumns() -> [WeekColumn] {
        let today = calendar.startOfDay(for: Date())
        var columns: [WeekColumn] = []
        var lastMonth = -1
        let monthFormatter = DateFormatter()
        monthFormatter.locale     = Locale.current
        monthFormatter.dateFormat = "MMM"

        for w in 0..<weeksCount {
            var column = WeekColumn()
            for dow in 0..<7 {
                guard let day = calendar.date(byAdding: .day, value: w * 7 + dow, to: gridStart) else { continue }
                guard day <= today else { continue }
                column.days[dow] = day

                let month = calendar.component(.month, from: day)
                if dow == 0 && month != lastMonth {
                    column.monthLabel = String(monthFormatter.string(from: day).prefix(3).capitalized)
                    lastMonth = month
                }
            }
            columns.append(column)
        }
        return columns
    }
}

// MARK: - DayCell

private struct DayCell: View {
    let ratio:        Double?
    let isFuture:      Bool
    let isToday:       Bool
    let cellSize:      CGFloat
    let rippleDelay:   Double
    let rippleID:      Int
    let rippleActive:  Bool

    /// Échelle de la case, animée pendant le passage de l'onde.
    @State private var rippleScale: CGFloat = 1.0

    private var fillColor: Color {
        guard !isFuture else { return Color(hex: "0D1117") }
        guard let ratio, ratio > 0 else { return Color(hex: "161B22") }
        switch ratio {
        case ..<0.5:  return Color(hex: "0C2D48")
        case ..<0.85: return Color(hex: "0D4F8B")
        case ..<1.0:  return Color(hex: "1F6FEB")
        default:      return Color(hex: "58A6FF")
        }
    }

    private var borderColor: Color {
        if isToday { return Color(hex: "58A6FF") }
        return isFuture ? Color(hex: "21262D") : Color.clear
    }

    private var borderWidth: CGFloat {
        isToday ? 1.3 : 0.5
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(fillColor)
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .stroke(borderColor, lineWidth: borderWidth)
            )
            .frame(width: cellSize, height: cellSize)
            .scaleEffect(rippleScale)
            .contentShape(Rectangle().inset(by: -2)) // zone de tap généreuse malgré la petite taille
            .onChange(of: rippleID) { _, _ in
                guard rippleActive else { return }
                triggerRipple()
            }
    }

    /// Anime un petit "pulse" d'échelle sur la case, avec le délai calculé
    /// selon la distance au point d'origine du tap — donne l'impression
    /// d'une onde/goutte d'eau qui se propage sur la grille.
    private func triggerRipple() {
        DispatchQueue.main.asyncAfter(deadline: .now() + rippleDelay) {
            withAnimation(.easeOut(duration: 0.18)) {
                rippleScale = 1.6
            }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.5).delay(0.18)) {
                rippleScale = 1.0
            }
        }
    }
}

// MARK: - DayDetailPopup

/// Petit panneau affiché au tap sur une case, montrant la date exacte et
/// le volume net bu ce jour-là. Se ferme au tap sur le fond ou sur la croix.
private struct DayDetailPopup: View {
    let day: Date
    let ratio: Double?
    let store: AppDataStore
    let onDismiss: () -> Void

    private var dateText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("EEEE d MMMM")
        return formatter.string(from: day).capitalized
    }

    private var volumeText: String {
        guard let ratio else { return "—" }
        let ml = ratio * store.effectiveGoalMl
        return UnitFormatter.volume(max(0, ml))
    }

    private var goalReached: Bool {
        (ratio ?? 0) >= 1.0
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: goalReached ? "checkmark.circle.fill" : "drop.fill")
                .font(.system(size: 14))
                .foregroundColor(goalReached ? Color(hex: "58A6FF") : .white.opacity(0.5))

            VStack(alignment: .leading, spacing: 1) {
                Text(dateText)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
                Text(volumeText)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.55))
            }

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.5))
                    .padding(6)
                    .background(Circle().fill(Color.white.opacity(0.08)))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(hex: "161B22"))
                .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 4)
        )
        .padding(.horizontal, 20)
    }
}

// MARK: - Preview

#Preview {
    let config    = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: WaterEntry.self, WaterAlcoholEntry.self, DayRecord.self,
        configurations: config
    )
    let store = AppDataStore(modelContext: container.mainContext)
    ScrollView {
        HydrationGridView()
            .environmentObject(store)
            .padding()
    }
    .background(Color("AppBackground"))
}
