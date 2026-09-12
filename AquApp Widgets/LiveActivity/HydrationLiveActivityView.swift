//
//  HydrationLiveActivityView.swift
//  AquApp
//
//  Created by Fabian Dargaud on 24/05/2026.
//
import SwiftUI
import ActivityKit
import WidgetKit

// MARK: - HydrationLiveActivityView
// Compact  — anneau circulaire + barre glow (Proposition A)
// Expanded — valeur massive à gauche, ml à côté, / goal à droite, barre fine glow
// Lock     — valeur + % même ligne, barre 5px glow, 3 boutons ajout rapide

// ─────────────────────────────────────────────────────────────────────────────
// MARK: 1 — Compact
// ─────────────────────────────────────────────────────────────────────────────

struct HydrationCompactLeading: View {
    let state: HydrationActivityAttributes.ContentState

    private var accentColor: Color {
        state.goalReached
            ? Color(red: 0.204, green: 0.831, blue: 0.600)
            : Color(red: 0.302, green: 0.659, blue: 0.961)
    }

    @State private var glowing = false

    var body: some View {
        HStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.10), lineWidth: 2.8)
                Circle()
                    .trim(from: 0, to: state.progress)
                    .stroke(accentColor,
                            style: StrokeStyle(lineWidth: 2.8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .shadow(color: accentColor.opacity(glowing ? 1.0 : 0.5),
                            radius: glowing ? 5 : 2)
                    .animation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true),
                               value: glowing)
                if state.goalReached {
                    Text("✓")
                        .font(.system(size: 8, weight: .black))
                        .foregroundStyle(accentColor)
                }
            }
            .frame(width: 24, height: 24)
            .onAppear { glowing = true }

            Text("\(state.percent)%")
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundStyle(state.goalReached ? accentColor : .white)
                .monospacedDigit()
        }
    }
}

struct HydrationCompactTrailing: View {
    let state: HydrationActivityAttributes.ContentState

    private var accentColor: Color {
        state.goalReached
            ? Color(red: 0.204, green: 0.831, blue: 0.600)
            : Color(red: 0.302, green: 0.659, blue: 0.961)
    }

    @State private var glowing  = false
    @State private var shimmerX: CGFloat = -1.0

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.08))

                Capsule()
                    .fill(LinearGradient(
                        colors: state.goalReached
                            ? [Color(red: 0.024, green: 0.588, blue: 0.412),
                               Color(red: 0.204, green: 0.831, blue: 0.600)]
                            : [Color(red: 0.102, green: 0.435, blue: 0.855),
                               Color(red: 0.302, green: 0.659, blue: 0.961)],
                        startPoint: .leading, endPoint: .trailing))
                    .frame(width: geo.size.width * state.progress)
                    .shadow(color: accentColor.opacity(glowing ? 0.9 : 0.4),
                            radius: glowing ? 5 : 2)
                    .animation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true),
                               value: glowing)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8),
                               value: state.progress)

                Capsule()
                    .fill(LinearGradient(
                        colors: [.clear, .white.opacity(0.28), .clear],
                        startPoint: UnitPoint(x: shimmerX - 0.3, y: 0),
                        endPoint:   UnitPoint(x: shimmerX + 0.3, y: 0)))
                    .frame(width: geo.size.width * state.progress)
                    .clipShape(Capsule())
            }
        }
        .frame(width: 46, height: 7)
        .onAppear {
            glowing = true
            withAnimation(.linear(duration: 2.4).repeatForever(autoreverses: false)) {
                shimmerX = 1.5
            }
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: 2 — Expanded
// Layout : label discret / valeur massive + ml + / goal / barre fine glow
// ─────────────────────────────────────────────────────────────────────────────

struct HydrationExpanded: View {
    let attributes: HydrationActivityAttributes
    let state:      HydrationActivityAttributes.ContentState

    private var accentColor: Color {
        state.goalReached
            ? Color(red: 0.204, green: 0.831, blue: 0.600)
            : Color(red: 0.302, green: 0.659, blue: 0.961)
    }

    private var bgColor: Color {
        state.goalReached
            ? Color(red: 0.016, green: 0.102, blue: 0.063)
            : .clear
    }

    @State private var glowing  = false
    @State private var shimmerX: CGFloat = -0.5

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            // ── "HYDRATATION" label discret en haut à gauche ─────────────────
            Text(state.goalReached ? state.labelGoalReachedFull : state.labelToday)
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.8)
                .textCase(.uppercase)
                .foregroundStyle(.white.opacity(state.goalReached ? 0.35 : 0.28))

            // ── Valeur massive à gauche + "ml" juste après ───────────────────
            HStack(alignment: .lastTextBaseline, spacing: 5) {
                Text(state.formattedCurrent)
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                    .foregroundStyle(state.goalReached ? accentColor : .white)
                    .monospacedDigit()
                    .shadow(color: state.goalReached ? accentColor.opacity(0.4) : .clear,
                            radius: 10)
                    .animation(.easeInOut(duration: 0.4), value: state.goalReached)

                Text("ml")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(state.goalReached
                        ? accentColor.opacity(0.4)
                        : .white.opacity(0.22))
            }

            // ── Barre ultra-fine + glow + point lumineux ─────────────────────
            GeometryReader { geo in
                ZStack(alignment: .leading) {

                    RoundedRectangle(cornerRadius: 2)
                        .fill(.white.opacity(0.06))
                        .frame(height: 3)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(LinearGradient(
                            colors: state.goalReached
                                ? [Color(red: 0.024, green: 0.588, blue: 0.412),
                                   Color(red: 0.204, green: 0.831, blue: 0.600),
                                   Color(red: 0.431, green: 0.906, blue: 0.714)]
                                : [Color(red: 0.102, green: 0.435, blue: 0.855),
                                   Color(red: 0.302, green: 0.659, blue: 0.961),
                                   Color(red: 0.447, green: 0.784, blue: 1.000)],
                            startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * state.progress, height: 3)
                        .shadow(color: accentColor.opacity(glowing ? 0.9 : 0.4),
                                radius: glowing ? 6 : 3)
                        .animation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true),
                                   value: glowing)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8),
                                   value: state.progress)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(LinearGradient(
                            colors: [.clear, .white.opacity(0.30), .clear],
                            startPoint: UnitPoint(x: shimmerX - 0.3, y: 0),
                            endPoint:   UnitPoint(x: shimmerX + 0.3, y: 0)))
                        .frame(width: geo.size.width * state.progress, height: 3)
                        .clipShape(RoundedRectangle(cornerRadius: 2))

                    if state.progress > 0.02 && state.progress < 1.0 {
                        Circle()
                            .fill(accentColor)
                            .frame(width: 7, height: 7)
                            .shadow(color: accentColor.opacity(glowing ? 1.0 : 0.6),
                                    radius: glowing ? 5 : 2)
                            .offset(x: geo.size.width * state.progress - 3.5, y: 0)
                            .animation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true),
                                       value: glowing)
                    }
                }
            }
            .frame(height: 7)

            // ── Bornes min / max sous la barre ───────────────────────────────
            HStack {
                Text("0")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(.white.opacity(0.2))
                Spacer()
                Text(state.formattedGoal)
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(.white.opacity(0.2))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(bgColor.animation(.easeInOut(duration: 0.5), value: state.goalReached))
        .onAppear {
            glowing = true
            withAnimation(.linear(duration: 2.4).repeatForever(autoreverses: false)) {
                shimmerX = 1.5
            }
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: 3 — Lock Screen
// ─────────────────────────────────────────────────────────────────────────────

struct HydrationLockScreen: View {
    let state: HydrationActivityAttributes.ContentState

    private var accentColor: Color {
        state.goalReached
            ? Color(red: 0.204, green: 0.831, blue: 0.600)
            : Color(red: 0.302, green: 0.659, blue: 0.961)
    }

    private var barGradient: LinearGradient {
        state.goalReached
        ? LinearGradient(
            colors: [Color(red: 0.024, green: 0.588, blue: 0.412),
                     Color(red: 0.204, green: 0.831, blue: 0.600),
                     Color(red: 0.431, green: 0.906, blue: 0.714)],
            startPoint: .leading, endPoint: .trailing)
        : LinearGradient(
            colors: [Color(red: 0.102, green: 0.435, blue: 0.855),
                     Color(red: 0.302, green: 0.659, blue: 0.961),
                     Color(red: 0.447, green: 0.784, blue: 1.000)],
            startPoint: .leading, endPoint: .trailing)
    }

    @State private var glowing  = false
    @State private var shimmerX: CGFloat = -0.5

    var body: some View {
        VStack(spacing: 0) {

            // ── App dot + nom ─────────────────────────────────────────────────
            HStack(spacing: 6) {
                Circle()
                    .fill(accentColor)
                    .frame(width: 8, height: 8)
                    .shadow(color: accentColor.opacity(glowing ? 1.0 : 0.4),
                            radius: glowing ? 6 : 2)
                    .animation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true),
                               value: glowing)
                Text("AquApp")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(.white.opacity(0.35))
                Spacer()
            }
            .padding(.bottom, 12)

            // ── Valeur + % sur la même ligne ──────────────────────────────────
            HStack(alignment: .lastTextBaseline) {
                Text(state.formattedCurrent)
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .foregroundStyle(state.goalReached ? accentColor : .white)
                    .monospacedDigit()
                    .shadow(color: state.goalReached ? accentColor.opacity(0.4) : .clear,
                            radius: 8)

                Spacer()

                Text("\(state.percent)%")
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .foregroundStyle(accentColor)
                    .monospacedDigit()
                    .shadow(color: accentColor.opacity(glowing ? 0.8 : 0.3),
                            radius: glowing ? 10 : 3)
                    .animation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true),
                               value: glowing)
            }
            .padding(.bottom, 10)

            // ── Barre 5px + glow + shimmer ────────────────────────────────────
            GeometryReader { geo in
                ZStack(alignment: .leading) {

                    Capsule().fill(.white.opacity(0.07)).frame(height: 5)

                    Capsule()
                        .fill(barGradient)
                        .frame(width: geo.size.width * state.progress, height: 5)
                        .shadow(color: accentColor.opacity(glowing ? 0.9 : 0.4),
                                radius: glowing ? 8 : 3)
                        .animation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true),
                                   value: glowing)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8),
                                   value: state.progress)

                    Capsule()
                        .fill(LinearGradient(
                            colors: [.clear, .white.opacity(0.28), .clear],
                            startPoint: UnitPoint(x: shimmerX - 0.3, y: 0),
                            endPoint:   UnitPoint(x: shimmerX + 0.3, y: 0)))
                        .frame(width: geo.size.width * state.progress, height: 5)
                        .clipShape(Capsule())
                }
            }
            .frame(height: 5)
            .padding(.bottom, 12)

            // ── Trois pastilles ───────────────────────────────────────────────
            HStack(spacing: 6) {
                LiveStatPill(
                    label: state.labelGoal,
                    value: state.goalReached
                        ? String(localized: "live_activity.goal_reached_word")
                        : state.formattedGoal,
                    valueColor: accentColor,
                    bgColor:    accentColor.opacity(0.12),
                    labelColor: accentColor.opacity(0.6),
                    border:     state.goalReached ? accentColor.opacity(0.2) : .clear
                )
                LiveStatPill(
                    label: state.labelStreak,
                    value: "\(state.streak) \(state.labelDays)",
                    valueColor: Color(red: 0.984, green: 0.573, blue: 0.235),
                    bgColor:    Color(red: 0.984, green: 0.573, blue: 0.235).opacity(0.12),
                    labelColor: Color(red: 0.984, green: 0.573, blue: 0.235).opacity(0.6)
                )
                LiveStatPill(
                    label: state.labelSober,
                    value: "\(state.soberStreak) \(state.labelDays)",
                    valueColor: Color(red: 0.655, green: 0.545, blue: 0.980),
                    bgColor:    Color(red: 0.545, green: 0.361, blue: 0.965).opacity(0.12),
                    labelColor: Color(red: 0.655, green: 0.545, blue: 0.980).opacity(0.65)
                )
            }
            .padding(.bottom, 9)

            // ── Boutons d'ajout rapide ────────────────────────────────────────
            // MARK: ⚠️ Remplacer Link par Button(intent: AddWaterIntent(amountMl: amount))
            // une fois AddWaterIntent créé dans la Widget Extension target.
            HStack(spacing: 5) {
                ForEach([150, 250, 500], id: \.self) { amount in
                    Link(destination: URL(string: "aquapp://addwater?ml=\(amount)")!) {
                        VStack(spacing: 1) {
                            Text("\(amount)")
                                .font(.system(size: 12, weight: .heavy, design: .rounded))
                                .foregroundStyle(
                                    state.goalReached
                                        ? accentColor.opacity(0.3)
                                        : Color(red: 0.302, green: 0.659, blue: 0.961)
                                )
                                .monospacedDigit()
                            Text("ml")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(
                                    state.goalReached
                                        ? accentColor.opacity(0.22)
                                        : Color(red: 0.302, green: 0.659, blue: 0.961).opacity(0.55)
                                )
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(
                            Color(red: 0.302, green: 0.659, blue: 0.961).opacity(
                                state.goalReached ? 0.04
                                : amount == 250 ? 0.16 : 0.10)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(
                                    Color(red: 0.302, green: 0.659, blue: 0.961).opacity(
                                        state.goalReached ? 0.08
                                        : amount == 250 ? 0.30 : 0.20),
                                    lineWidth: 1
                                )
                        )
                        .opacity(state.goalReached ? 0.3 : 1.0)
                    }
                    .disabled(state.goalReached)
                }
            }
        }
        .padding(14)
        .onAppear {
            glowing = true
            withAnimation(.linear(duration: 2.4).repeatForever(autoreverses: false)) {
                shimmerX = 1.5
            }
        }
    }
}

// MARK: - LiveStatPill

private struct LiveStatPill: View {
    let label:      String
    let value:      String
    let valueColor: Color
    let bgColor:    Color
    let labelColor: Color
    var border:     Color = .clear

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(labelColor)
                .kerning(0.4)
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 7)
        .padding(.vertical, 6)
        .background(bgColor)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(border, lineWidth: 1)
        )
    }
}

// MARK: - Preview

#Preview("Lock Screen", as: .content,
         using: HydrationActivityAttributes(userName: "Fabian")) {
    HydrationLiveActivityWidget()
} contentStates: {
    HydrationActivityAttributes.ContentState(
        currentMl:   1630,
        goalMl:      2350,
        streak:      5,
        soberStreak: 12,
        goalReached: false
    )
    HydrationActivityAttributes.ContentState(
        currentMl:   2350,
        goalMl:      2350,
        streak:      5,
        soberStreak: 12,
        goalReached: true
    )
}
