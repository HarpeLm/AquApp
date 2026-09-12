//
//  AquAppWidget.swift
//  AquAppWidgetExtension
//
//  7 widgets :
//  • Small  — Progression du jour (anneau)
//  • Small  — Streak objectif seul
//  • Small  — Jours sobre seul
//  • Small  — Streak + Sobre ensemble
//  • Medium — Ajout interactif (AppIntent)
//  • Medium — Suivi semaine (graphique barres)
//  • Large  — Résumé complet
//
//  Données lues depuis l'App Group : group.com.fabian.dargaud.AquApp
//  Ajout d'eau via AppIntent → queue widget_pending_entries (flush au premier plan)

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - App Group

private let appGroupID = "group.com.fabian.dargaud.AquApp"

// MARK: - Couleurs

private extension Color {
    static let aqBlue      = Color(red: 0.302, green: 0.659, blue: 0.961)
    static let aqBlueDark  = Color(red: 0.169, green: 0.529, blue: 0.910)
    static let aqBluePale  = Color(red: 0.859, green: 0.929, blue: 1.000)
    static let aqGreenDark = Color(red: 0.063, green: 0.725, blue: 0.506)
    static let aqOrange    = Color(red: 0.984, green: 0.573, blue: 0.235)
}

// Helpers couleurs contextuelles (scheme passé explicitement)
private func bgBlue(_ scheme: ColorScheme) -> Color {
    Color.aqBlue.opacity(scheme == .dark ? 0.10 : 0.08)
}
private func bgOrange(_ scheme: ColorScheme) -> Color {
    Color.aqOrange.opacity(scheme == .dark ? 0.12 : 0.08)
}
private func bgGreen(_ scheme: ColorScheme) -> Color {
    Color.aqGreenDark.opacity(scheme == .dark ? 0.12 : 0.08)
}
private func borderColor(_ scheme: ColorScheme) -> Color {
    scheme == .dark ? Color.white.opacity(0.07) : Color.aqBlue.opacity(0.12)
}
private func gradStart(_ scheme: ColorScheme) -> Color {
    scheme == .dark
        ? Color(red: 0.051, green: 0.102, blue: 0.180)
        : Color(red: 0.933, green: 0.945, blue: 1.000)
}
private func gradEnd(_ scheme: ColorScheme) -> Color {
    scheme == .dark
        ? Color(red: 0.102, green: 0.180, blue: 0.259)
        : Color(red: 0.859, green: 0.929, blue: 1.000)
}

// MARK: - Modèle de données widget

struct AquWidgetData {
    var todayMl:     Double = 0
    var goalMl:      Double = 2170
    var streak:      Int    = 0
    var soberStreak: Int    = 0

    // 7 jours : index 0 = J-6, index 6 = aujourd'hui
    var week: [(label: String, ml: Double)] = []

    var progress: Double { min(todayMl / max(goalMl, 1), 1.0) }

    static func load() -> AquWidgetData {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return AquWidgetData() }
        var d = AquWidgetData()
        d.todayMl     = defaults.double(forKey: "widget_today_ml")
        d.goalMl      = { let v = defaults.double(forKey: "widget_goal_ml"); return v == 0 ? 2170 : v }()
        d.streak      = defaults.integer(forKey: "widget_streak")
        d.soberStreak = defaults.integer(forKey: "widget_sober_streak")

        // Lecture des 7 jours depuis widget_week_data (JSON ecrit par syncWidgetData)
        // Format : [{label, ml, goalReached, offset}] offset 0 = aujourd'hui
        // Fallback sur l'ancien format si le JSON n'existe pas encore.
        if let data = defaults.data(forKey: "widget_week_data"),
           let raw  = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            // Convertit en tableau (index 0 = aujourd'hui) puis reverse pour
            // que week[0] = J-6 et week[6] = aujourd'hui (ordre chronologique)
            let sorted = raw.sorted { ($0["offset"] as? Int ?? 0) > ($1["offset"] as? Int ?? 0) }
            d.week = sorted.map { dict in
                let label = dict["label"] as? String ?? "?"
                let ml    = dict["ml"]    as? Double ?? 0
                return (label: label, ml: ml)
            }
        } else {
            // Fallback : reconstitue depuis les anciennes cles widget_day{i}_ml
            let cal = Calendar.current
            let fmt = DateFormatter()
            fmt.locale = Locale.current
            fmt.dateFormat = "EEE"
            d.week = (0..<7).reversed().map { offset -> (String, Double) in
                let date  = cal.date(byAdding: .day, value: -offset, to: Date())!
                let label = String(fmt.string(from: date).prefix(1).uppercased())
                let idx   = 6 - offset
                let ml    = idx == 0 ? d.todayMl : defaults.double(forKey: "widget_day\(idx)_ml")
                return (label: label, ml: ml)
            }
        }
        return d
    }
}

// MARK: - Timeline Entry & Provider

struct AquEntry: TimelineEntry {
    let date: Date
    let data: AquWidgetData
}

struct AquProvider: TimelineProvider {
    func placeholder(in context: Context) -> AquEntry {
        AquEntry(date: Date(), data: AquWidgetData())
    }
    func getSnapshot(in context: Context, completion: @escaping (AquEntry) -> Void) {
        completion(AquEntry(date: Date(), data: AquWidgetData.load()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<AquEntry>) -> Void) {
        let now      = Date()
        let data     = AquWidgetData.load()
        let calendar = Calendar.current

        // Entrée courante — données du moment
        let currentEntry = AquEntry(date: now, data: data)

        // Entrée minuit — iOS réveille la Widget Extension à ce moment précis
        // pour recalculer la timeline avec les vraies données du nouveau jour
        let tomorrow     = calendar.date(byAdding: .day, value: 1, to: now)!
        let midnight     = calendar.startOfDay(for: tomorrow)
        var midnightData = data
        midnightData.todayMl = 0  // progression remise à zéro visuellement
        midnightData.week    = [] // sera rechargé depuis lApp Group
        let midnightEntry    = AquEntry(date: midnight, data: midnightData)

        // policy: .after(midnight) → iOS recharge la timeline après minuit
        completion(Timeline(
            entries: [currentEntry, midnightEntry],
            policy:  .after(midnight)
        ))
    }
}

// MARK: - AppIntent : Ajouter de l'eau

struct AddWaterIntent: AppIntent {
    static var title: LocalizedStringResource = "Ajouter de l'eau"

    @Parameter(title: "Volume ml")
    var amountMl: Int

    init() { amountMl = 250 }
    init(ml: Int) { amountMl = ml }

    func perform() async throws -> some IntentResult {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return .result() }

        // 1. Ajoute a la queue pour que l'app persiste dans SwiftData au prochain lancement
        var pending = defaults.array(forKey: "widget_pending_entries") as? [[String: Any]] ?? []
        pending.append([
            "amountMl":  Double(amountMl),
            "timestamp": Date().timeIntervalSince1970,
            "isAlcohol": false
        ])
        defaults.set(pending, forKey: "widget_pending_entries")

        // 2. Mise a jour optimiste de widget_today_ml
        let newTodayMl = defaults.double(forKey: "widget_today_ml") + Double(amountMl)
        defaults.set(newTodayMl, forKey: "widget_today_ml")

        // 3. Met a jour le jour courant (offset 0) dans widget_week_data
        // pour que les widgets semaine et large refletent l'ajout immediatement,
        // meme si l'app n'a pas ete ouverte.
        if let data = defaults.data(forKey: "widget_week_data"),
           var raw  = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            if let idx = raw.firstIndex(where: { ($0["offset"] as? Int) == 0 }) {
                let currentMl = raw[idx]["ml"] as? Double ?? 0
                raw[idx]["ml"] = currentMl + Double(amountMl)
                // Verifie si l'objectif est maintenant atteint
                let goalMl = defaults.double(forKey: "widget_daily_goal_ml")
                raw[idx]["goalReached"] = (currentMl + Double(amountMl)) >= goalMl
            }
            if let updated = try? JSONSerialization.data(withJSONObject: raw) {
                defaults.set(updated, forKey: "widget_week_data")
            }
        }

        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

// MARK: ─────────────────────────────────────────────────────────────────────
// MARK: COMPOSANTS PARTAGÉS
// MARK: ─────────────────────────────────────────────────────────────────────

struct AquWidgetBackground: View {
    @Environment(\.colorScheme) var scheme
    var body: some View {
        LinearGradient(
            colors: [gradStart(scheme), gradEnd(scheme)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(alignment: .topTrailing) {
            Circle()
                .fill(Color.aqBlue.opacity(0.08))
                .frame(width: 140, height: 140)
                .offset(x: 50, y: -50)
        }
    }
}

struct AquAppLabel: View {
    var fontSize: CGFloat = 10
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "drop.fill")
                .font(.system(size: fontSize, weight: .bold))
                .foregroundStyle(Color.aqBlue)
            Text("AQUAPP")
                .font(.system(size: fontSize, weight: .bold, design: .rounded))
                .foregroundStyle(Color.aqBlue)
                .kerning(0.6)
        }
    }
}

struct AquRing: View {
    let progress:  Double
    let size:      CGFloat
    let lineWidth: CGFloat
    var color:     Color = .aqBlue

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.aqBluePale.opacity(0.5), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(progress, 1))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.6), value: progress)
        }
        .frame(width: size, height: size)
    }
}

struct AquProgressBar: View {
    let progress: Double
    var height: CGFloat = 5
    @Environment(\.colorScheme) var scheme

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height)
                    .fill(scheme == .dark ? Color.white.opacity(0.07) : Color.aqBlue.opacity(0.12))
                RoundedRectangle(cornerRadius: height)
                    .fill(LinearGradient(
                        colors: [Color.aqBlue.opacity(0.8), Color.aqBlue],
                        startPoint: .leading, endPoint: .trailing
                    ))
                    .frame(width: geo.size.width * min(progress, 1))
                    .animation(.easeInOut(duration: 0.5), value: progress)
            }
        }
        .frame(height: height)
    }
}

struct AquStatPill: View {
    let sfSymbol: String
    let value:    String
    let label:    String
    let color:    Color
    let bg:       Color
    let border:   Color

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Image(systemName: sfSymbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundStyle(color)
                .monospacedDigit()
            Text(label)
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(bg)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(border, lineWidth: 1))
    }
}

struct AquBarChart: View {
    let days:    [(label: String, ml: Double)]
    let goalMl:  Double
    let barMaxH: CGFloat
    @Environment(\.colorScheme) var scheme

    var body: some View {
        HStack(alignment: .bottom, spacing: 5) {
            ForEach(Array(days.enumerated()), id: \.offset) { idx, day in
                let ratio   = min(day.ml / max(goalMl, 1), 1.0)
                let barH    = max(CGFloat(ratio) * barMaxH, 4)
                let reached = day.ml >= goalMl
                let isToday = idx == days.count - 1

                VStack(spacing: 3) {
                    // Conteneur hauteur fixe — base identique pour toutes les barres
                    ZStack(alignment: .bottom) {
                        Color.clear.frame(height: barMaxH)
                        RoundedRectangle(cornerRadius: 5)
                            .fill(reached
                                ? AnyShapeStyle(LinearGradient(
                                    colors: [.aqBlueDark, .aqBlue],
                                    startPoint: .bottom, endPoint: .top))
                                : AnyShapeStyle(
                                    scheme == .dark
                                        ? Color.aqBlue.opacity(0.20)
                                        : Color.aqBlue.opacity(0.18)
                                  )
                            )
                            .frame(height: barH)
                            .overlay(
                                isToday
                                ? RoundedRectangle(cornerRadius: 5)
                                    .stroke(Color.aqBlue.opacity(0.8), lineWidth: 1.5)
                                : nil
                            )
                    }
                    // Label hauteur fixe
                    Text(day.label)
                        .font(.system(size: 9, weight: isToday ? .heavy : .medium))
                        .foregroundStyle(isToday ? Color.aqBlue : Color.secondary)
                        .frame(height: 12)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

// MARK: ─────────────────────────────────────────────────────────────────────
// MARK: VUES WIDGET
// MARK: ─────────────────────────────────────────────────────────────────────

// MARK: Small 1 — Progression (anneau seul)

struct SmallProgressView: View {
    let data: AquWidgetData
    @Environment(\.colorScheme) var scheme

    var body: some View {
        ZStack {
            AquWidgetBackground()
            VStack(alignment: .leading, spacing: 0) {
                AquAppLabel(fontSize: 9)
                Spacer()
                ZStack {
                    AquRing(progress: data.progress, size: 96, lineWidth: 8)
                    VStack(spacing: 2) {
                        Text("\(Int(data.progress * 100))%")
                            .font(.system(size: 22, weight: .heavy, design: .rounded))
                            .foregroundStyle(.primary)
                            .monospacedDigit()
                        Text("du jour")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .kerning(0.3)
                    }
                }
                .frame(maxWidth: .infinity)
                Spacer()
            }
            .padding(14)
        }
    }
}

// MARK: Small 2 — Streak seul

struct SmallStreakView: View {
    let data: AquWidgetData
    @Environment(\.colorScheme) var scheme

    var body: some View {
        ZStack {
            AquWidgetBackground()
            VStack(alignment: .leading, spacing: 0) {
                AquAppLabel(fontSize: 9)
                Spacer()
                VStack(spacing: 6) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.aqOrange.opacity(0.15))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.aqOrange.opacity(0.25), lineWidth: 1)
                            )
                            .frame(width: 52, height: 52)
                        Image(systemName: "flame.fill")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(Color.aqOrange)
                    }
                    VStack(spacing: 2) {
                        Text("\(data.streak)")
                            .font(.system(size: 32, weight: .heavy, design: .rounded))
                            .foregroundStyle(Color.aqOrange)
                            .monospacedDigit()
                        Text("jours streak")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                Spacer()
            }
            .padding(14)
        }
    }
}

// MARK: Small 3 — Sobre seul

struct SmallSoberView: View {
    let data: AquWidgetData
    @Environment(\.colorScheme) var scheme

    var body: some View {
        ZStack {
            AquWidgetBackground()
            VStack(alignment: .leading, spacing: 0) {
                AquAppLabel(fontSize: 9)
                Spacer()
                VStack(spacing: 6) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.aqGreenDark.opacity(0.15))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.aqGreenDark.opacity(0.25), lineWidth: 1)
                            )
                            .frame(width: 52, height: 52)
                        Image(systemName: "leaf.fill")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(Color.aqGreenDark)
                    }
                    VStack(spacing: 2) {
                        Text("\(data.soberStreak)")
                            .font(.system(size: 32, weight: .heavy, design: .rounded))
                            .foregroundStyle(Color.aqGreenDark)
                            .monospacedDigit()
                        Text("jours sobre")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                Spacer()
            }
            .padding(14)
        }
    }
}

// MARK: Small 4 — Streak + Sobre ensemble

struct SmallStreakSoberView: View {
    let data: AquWidgetData
    @Environment(\.colorScheme) var scheme

    var body: some View {
        ZStack {
            AquWidgetBackground()
            VStack(alignment: .leading, spacing: 0) {
                AquAppLabel(fontSize: 9)
                Spacer()
                VStack(spacing: 8) {
                    // Streak
                    HStack(spacing: 8) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.aqOrange.opacity(0.15))
                                .frame(width: 28, height: 28)
                            Image(systemName: "flame.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.aqOrange)
                        }
                        VStack(alignment: .leading, spacing: 0) {
                            Text("\(data.streak)")
                                .font(.system(size: 20, weight: .heavy, design: .rounded))
                                .foregroundStyle(Color.aqOrange)
                                .monospacedDigit()
                            Text("jours streak")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(bgOrange(scheme))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.aqOrange.opacity(0.22), lineWidth: 1)
                    )

                    // Sobre
                    HStack(spacing: 8) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.aqGreenDark.opacity(0.15))
                                .frame(width: 28, height: 28)
                            Image(systemName: "leaf.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.aqGreenDark)
                        }
                        VStack(alignment: .leading, spacing: 0) {
                            Text("\(data.soberStreak)")
                                .font(.system(size: 20, weight: .heavy, design: .rounded))
                                .foregroundStyle(Color.aqGreenDark)
                                .monospacedDigit()
                            Text("jours sobre")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(bgGreen(scheme))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.aqGreenDark.opacity(0.22), lineWidth: 1)
                    )
                }
                Spacer()
            }
            .padding(14)
        }
    }
}

// MARK: Medium 1 — Ajout interactif

struct MediumInteractiveView: View {
    let data: AquWidgetData
    @Environment(\.colorScheme) var scheme

    var body: some View {
        ZStack {
            AquWidgetBackground()
            HStack(spacing: 0) {

                // Gauche : anneau + ml
                VStack(alignment: .leading, spacing: 0) {
                    AquAppLabel(fontSize: 9)
                    Spacer()
                    ZStack {
                        AquRing(progress: data.progress, size: 72, lineWidth: 6)
                        Text("\(Int(data.progress * 100))%")
                            .font(.system(size: 15, weight: .heavy, design: .rounded))
                            .foregroundStyle(.primary)
                            .monospacedDigit()
                    }
                    .frame(maxWidth: .infinity)
                    Spacer()
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(alignment: .lastTextBaseline, spacing: 2) {
                            Text("\(Int(data.todayMl))")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(.primary)
                                .monospacedDigit()
                            Text("ml")
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                        }
                        Text("sur \(Int(data.goalMl)) ml")
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 100)
                .padding(.leading, 14)
                .padding(.vertical, 14)

                // Séparateur
                Rectangle()
                    .fill(borderColor(scheme))
                    .frame(width: 1)
                    .padding(.vertical, 14)
                    .padding(.horizontal, 10)

                // Droite : boutons interactifs
                VStack(alignment: .leading, spacing: 6) {
                    Text("Ajouter de l'eau")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.primary)

                    ForEach([
                        (150, "150 ml", "Gorgée"),
                        (250, "250 ml", "Verre"),
                        (330, "330 ml", "Canette"),
                    ], id: \.0) { ml, label, sub in
                        Button(intent: AddWaterIntent(ml: ml)) {
                            HStack {
                                HStack(spacing: 6) {
                                    Image(systemName: "drop.fill")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(Color.aqBlue)
                                    Text(label)
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(.primary)
                                }
                                Spacer()
                                Text(sub)
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(bgBlue(scheme))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.aqBlue.opacity(0.18), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, 14)
                .padding(.vertical, 14)
            }
        }
    }
}

// MARK: Medium 2 — Suivi semaine

struct MediumWeekView: View {
    let data: AquWidgetData
    @Environment(\.colorScheme) var scheme

    var avg: Double {
        guard !data.week.isEmpty else { return 0 }
        return data.week.reduce(0) { $0 + $1.ml } / Double(data.week.count)
    }

    var body: some View {
        ZStack {
            AquWidgetBackground()
            VStack(alignment: .leading, spacing: 10) {
                // Header
                HStack {
                    AquAppLabel(fontSize: 9)
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: "chart.bar.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                        Text("Cette semaine")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }

                // Barres
                AquBarChart(days: data.week, goalMl: data.goalMl, barMaxH: 52)

                // Footer
                Divider().overlay(borderColor(scheme))
                HStack {
                    HStack(spacing: 4) {
                        Rectangle()
                            .fill(Color.aqBlue)
                            .frame(width: 12, height: 2)
                            .cornerRadius(1)
                        Text("Objectif \(Int(data.goalMl)) ml")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    HStack(spacing: 3) {
                        Image(systemName: "drop.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(Color.aqBlue)
                        Text("Moy. \(Int(avg)) ml")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.primary)
                            .monospacedDigit()
                    }
                }
            }
            .padding(14)
        }
    }
}

// MARK: Large — Résumé complet

struct LargeView: View {
    let data: AquWidgetData
    @Environment(\.colorScheme) var scheme

    var body: some View {
        ZStack {
            AquWidgetBackground()
            VStack(alignment: .leading, spacing: 10) {

                // Header
                HStack {
                    AquAppLabel(fontSize: 11)
                    Spacer()
                    Text("7 derniers jours")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(bgBlue(scheme))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(borderColor(scheme), lineWidth: 1))
                }

                // Stats pills
                HStack(spacing: 7) {
                    AquStatPill(
                        sfSymbol: "flame.fill",
                        value: "\(data.streak) j",
                        label: "Streak",
                        color: .aqOrange,
                        bg: bgOrange(scheme),
                        border: Color.aqOrange.opacity(0.22)
                    )
                    AquStatPill(
                        sfSymbol: "leaf.fill",
                        value: "\(data.soberStreak) j",
                        label: "Sobre",
                        color: .aqGreenDark,
                        bg: bgGreen(scheme),
                        border: Color.aqGreenDark.opacity(0.22)
                    )
                    AquStatPill(
                        sfSymbol: "target",
                        value: "\(Int(data.progress * 100))%",
                        label: "Aujourd'hui",
                        color: .aqBlue,
                        bg: bgBlue(scheme),
                        border: Color.aqBlue.opacity(0.22)
                    )
                }

                // Graphique
                VStack(alignment: .leading, spacing: 6) {
                    Text("HYDRATATION")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.secondary)
                        .kerning(0.6)

                    AquBarChart(days: data.week, goalMl: data.goalMl, barMaxH: 72)

                    HStack(spacing: 4) {
                        Rectangle()
                            .fill(Color.aqBlue)
                            .frame(width: 12, height: 2)
                            .cornerRadius(1)
                        Text("Objectif \(Int(data.goalMl)) ml")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    scheme == .dark
                        ? Color.white.opacity(0.03)
                        : Color.white.opacity(0.55)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(borderColor(scheme), lineWidth: 1)
                )

                // Aujourd'hui
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Aujourd'hui")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                        HStack(alignment: .lastTextBaseline, spacing: 3) {
                            Text("\(Int(data.todayMl))")
                                .font(.system(size: 12, weight: .heavy, design: .rounded))
                                .foregroundStyle(.primary)
                                .monospacedDigit()
                            Text("/ \(Int(data.goalMl)) ml")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                    AquProgressBar(progress: data.progress, height: 5)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(bgBlue(scheme))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.aqBlue.opacity(0.22), lineWidth: 1)
                )
            }
            .padding(15)
        }
    }
}

// MARK: ─────────────────────────────────────────────────────────────────────
// MARK: DÉCLARATIONS WIDGET
// MARK: ─────────────────────────────────────────────────────────────────────

struct AquProgressWidget: Widget {
    let kind = "AquProgressWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AquProvider()) { entry in
            SmallProgressView(data: entry.data)
                .containerBackground(for: .widget) { AquWidgetBackground() }
        }
        .configurationDisplayName("Hydratation")
        .description("Progression du jour en anneau.")
        .supportedFamilies([.systemSmall])
    }
}

struct AquStreakWidget: Widget {
    let kind = "AquStreakWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AquProvider()) { entry in
            SmallStreakView(data: entry.data)
                .containerBackground(for: .widget) { AquWidgetBackground() }
        }
        .configurationDisplayName("Streak objectif")
        .description("Jours consécutifs d'objectif atteint.")
        .supportedFamilies([.systemSmall])
    }
}

struct AquSoberWidget: Widget {
    let kind = "AquSoberWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AquProvider()) { entry in
            SmallSoberView(data: entry.data)
                .containerBackground(for: .widget) { AquWidgetBackground() }
        }
        .configurationDisplayName("Jours sobre")
        .description("Nombre de jours sans alcool.")
        .supportedFamilies([.systemSmall])
    }
}

struct AquStreakSoberWidget: Widget {
    let kind = "AquStreakSoberWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AquProvider()) { entry in
            SmallStreakSoberView(data: entry.data)
                .containerBackground(for: .widget) { AquWidgetBackground() }
        }
        .configurationDisplayName("Streak & Sobre")
        .description("Streak objectif et jours sobre.")
        .supportedFamilies([.systemSmall])
    }
}

struct AquInteractiveWidget: Widget {
    let kind = "AquInteractiveWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AquProvider()) { entry in
            MediumInteractiveView(data: entry.data)
                .containerBackground(for: .widget) { AquWidgetBackground() }
        }
        .configurationDisplayName("Ajouter de l'eau")
        .description("Ajout rapide directement depuis le widget.")
        .supportedFamilies([.systemMedium])
    }
}

struct AquWeekWidget: Widget {
    let kind = "AquWeekWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AquProvider()) { entry in
            MediumWeekView(data: entry.data)
                .containerBackground(for: .widget) { AquWidgetBackground() }
        }
        .configurationDisplayName("Semaine")
        .description("Graphique des 7 derniers jours.")
        .supportedFamilies([.systemMedium])
    }
}

struct AquLargeWidget: Widget {
    let kind = "AquLargeWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AquProvider()) { entry in
            LargeView(data: entry.data)
                .containerBackground(for: .widget) { AquWidgetBackground() }
        }
        .configurationDisplayName("Résumé AquApp")
        .description("Vue complète : stats, semaine et progression du jour.")
        .supportedFamilies([.systemLarge])
    }
}

// MARK: - Bundle principal de la Widget Extension
// ⚠️ Un seul @main par extension.
// Si HydrationLiveActivityWidget.swift a déjà un @main ou un WidgetBundle,
// supprime-le et ajoute HydrationLiveActivityWidget() dans ce bundle.

struct AquAppWidgetBundle: WidgetBundle {
    var body: some Widget {
        // Widgets hydratation — Home Screen
        AquProgressWidget()
        AquStreakWidget()
        AquSoberWidget()
        AquStreakSoberWidget()
        AquInteractiveWidget()
        AquWeekWidget()
        AquLargeWidget()
        // Widgets hydratation — Lock Screen (iOS 16+)
        AquLockCircularWidget()
        AquLockRectangularWidget()
        AquLockInlineWidget()
        // Live Activity
        HydrationLiveActivityWidget()
    }
}
