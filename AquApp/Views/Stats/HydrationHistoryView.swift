//
//  HydrationHistoryView.swift
//  AquApp
//
//  Created by Fabian Dargaud on 10/09/2026.
//

import SwiftUI
import SwiftData

// MARK: - HydrationHistoryView
// Sheet plein écran : historique complet d'une année sélectionnée,
// 12 mois affichés en grille 4 colonnes x 3 lignes (tout sur un écran).

struct HydrationHistoryView: View {
    @EnvironmentObject var store: AppDataStore
    @Environment(\.dismiss) private var dismiss

    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @State private var ratios: [Date: Double] = [:]

    private let calendar  = Calendar.current
    private let cellSize: CGFloat = 11
    private let spacing:  CGFloat = 3
    private let monthGap: CGFloat = 14

    // MARK: - Plage de l'année sélectionnée

    private var yearRange: (start: Date, end: Date) {
        let start = calendar.date(from: DateComponents(year: selectedYear, month: 1, day: 1))!
        let end   = calendar.date(from: DateComponents(year: selectedYear, month: 12, day: 31))!
        return (start, end)
    }

    /// Groupes de mois pour l'année sélectionnée
    private var monthGroups: [(month: Date, columns: [[Date?]])] {
        let (start, end) = yearRange
        var result: [(Date, [[Date?]])] = []
        var month = start

        while month <= end {
            let nextMonth = calendar.date(byAdding: .month, value: 1, to: month)!
            var columns: [[Date?]] = []
            var weekStart = calendar.dateInterval(of: .weekOfYear, for: month)!.start

            while weekStart < nextMonth && weekStart <= end {
                var col: [Date?] = []
                for offset in 0..<7 {
                    let day = calendar.date(byAdding: .day, value: offset, to: weekStart)!
                    let inMonth = calendar.isDate(day, equalTo: month, toGranularity: .month)
                    col.append(inMonth ? day : nil)
                }
                columns.append(col)
                weekStart = calendar.date(byAdding: .day, value: 7, to: weekStart)!
            }

            result.append((month, columns))
            month = nextMonth
        }
        return result
    }

    private var reachedTotal: Int {
        ratios.values.filter { $0 >= 1.0 }.count
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {

                // Sélecteur d'année
                HStack {
                    Text(String(localized: "stats.history.year"))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.primary)
                    Spacer()
                    Picker(String(localized: "stats.history.year"), selection: $selectedYear) {
                        ForEach(yearsRange, id: \.self) { year in
                            Text(verbatim: "\(year)").tag(year)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.accentColor)
                }
                .padding(.horizontal)

                // Compteur
                HStack {
                    Text(String(localized: "stats.grid.title"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(reachedTotal)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.primary)
                }
                .padding(.horizontal)

                // Grille 4 colonnes x 3 lignes (tout sur un écran)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: monthGap), count: 4), spacing: monthGap) {
                    ForEach(monthGroups, id: \.month) { group in
                        monthBlock(group.month, columns: group.columns)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)

                // Légende
                legend
                    .padding(.horizontal)

                Spacer()
            }
            .padding(.top)
            .background(Color("AppBackground"))
            .navigationTitle(String(localized: "stats.history.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .onAppear { ratios = store.contributionRatios(days: 4000) }
            .onChange(of: selectedYear) { _, _ in
                ratios = store.contributionRatios(days: 4000)
            }
        }
    }

    // MARK: - Bloc mois

    private func monthBlock(_ month: Date, columns: [[Date?]]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(month.formatted(.dateTime.month(.abbreviated)))
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.secondary)
                .padding(.bottom, 1)

            HStack(alignment: .top, spacing: spacing) {
                ForEach(columns.indices, id: \.self) { c in
                    VStack(spacing: spacing) {
                        ForEach(0..<7, id: \.self) { i in
                            if let date = columns[c][i] {
                                cell(for: date)
                            } else {
                                Color.clear.frame(width: cellSize, height: cellSize)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Case jour

    private func cell(for date: Date) -> some View {
        let isFuture = date > calendar.startOfDay(for: Date())
        let ratio    = ratios[date] ?? 0
        return RoundedRectangle(cornerRadius: 2)
            .fill(color(for: ratio))
            .frame(width: cellSize, height: cellSize)
            .opacity(isFuture ? 0.12 : 1.0)
    }

    private func color(for ratio: Double) -> Color {
        switch ratio {
        case ..<0.01: return Color.white.opacity(0.08)
        case ..<0.34: return Color(hex: "185FA5").opacity(0.45)
        case ..<0.67: return Color(hex: "2B87E8").opacity(0.70)
        case ..<1.00: return Color(hex: "4DA8F5").opacity(0.90)
        default:      return Color(hex: "4DA8F5")
        }
    }

    // MARK: - Légende

    private var legend: some View {
        HStack(spacing: 6) {
            Text(String(localized: "stats.grid.less"))
            ForEach(0..<5, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(legendColor(i))
                    .frame(width: 10, height: 10)
            }
            Text(String(localized: "stats.grid.more"))
        }
        .font(.system(size: 10, weight: .medium))
        .foregroundColor(.secondary)
    }

    private func legendColor(_ i: Int) -> Color {
        switch i {
        case 0:  return Color.white.opacity(0.08)
        case 1:  return Color(hex: "185FA5").opacity(0.45)
        case 2:  return Color(hex: "2B87E8").opacity(0.70)
        case 3:  return Color(hex: "4DA8F5").opacity(0.90)
        default: return Color(hex: "4DA8F5")
        }
    }

    // MARK: - Années disponibles (depuis firstLaunchDate jusqu'à aujourd'hui)

    private var yearsRange: [Int] {
        let currentYear = Calendar.current.component(.year, from: Date())
        let launchYear  = Calendar.current.component(.year, from: store.firstLaunchDate)
        return Array(launchYear...currentYear).reversed()
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
    return HydrationHistoryView()
        .environmentObject(store)
}
