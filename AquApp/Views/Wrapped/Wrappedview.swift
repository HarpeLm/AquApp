//
//  Wrappedview.swift
//  AquApp
//
//  Created by Fabian Dargaud on 01/07/2026.
//

//
//  WrappedView.swift
//  AquApp
//
//  AquApp Wrapped — récapitulatif annuel façon Spotify Wrapped.
//  10 slides (9 standards + 1 easter egg légendaire conditionnel),
//  navigation tactile (tap gauche/droite + swipe), haptiques/sons
//  thématiques, anti-spoil progressif, export image story/carré
//  avec QR code App Store.
//
//  Déclenchement : automatique le 31 décembre (DailyResetManager),
//  ou manuellement depuis ProfileView.

import SwiftUI
import CoreImage.CIFilterBuiltins

// MARK: - WrappedView (racine)

struct WrappedView: View {
    let data: WrappedData
    @Binding var isPresented: Bool

    @State private var currentSlide:  Int    = 0
    @State private var dragOffset:    CGFloat = 0
    @State private var showShareSheet: Bool   = false
    @State private var shareImage:    UIImage? = nil
    @State private var shareFormat:   WrappedShareFormat = .story

    /// Slides incluant l'easter egg légendaire si la condition est remplie.
    private var slideThemes: [WrappedSlideTheme] {
        var themes: [WrappedSlideTheme] = [
            .intro, .water, .streak, .sober, .month, .habits, .xp, .finale
        ]
        if data.isLegendary { themes.append(.legendary) }
        themes.append(.share)
        return themes
    }

    private var slideCount: Int { slideThemes.count }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Tabs de navigation rapide
                slidePicker

                // Téléphone simulé — carte centrale
                GeometryReader { geo in
                    ZStack {
                        ForEach(Array(slideThemes.enumerated()), id: \.offset) { index, theme in
                            if index == currentSlide {
                                slideContent(for: theme, index: index)
                                    .frame(width: geo.size.width, height: geo.size.height)
                                    .transition(.opacity)
                            }
                        }

                        // Zones tap gauche / droite (invisibles)
                        HStack(spacing: 0) {
                            Color.clear
                                .contentShape(Rectangle())
                                .onTapGesture { goToPrevious() }
                            Color.clear
                                .contentShape(Rectangle())
                                .onTapGesture { goToNext() }
                        }

                        // Barres de progression en haut
                        VStack {
                            progressBars
                                .padding(.horizontal, 16)
                                .padding(.top, 14)
                            Spacer()
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 36))
                    .overlay(
                        RoundedRectangle(cornerRadius: 36)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                    .gesture(
                        DragGesture()
                            .onEnded { value in
                                if value.translation.width < -40 { goToNext() }
                                if value.translation.width >  40 { goToPrevious() }
                            }
                    )
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)

                // Bouton fermer
                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white.opacity(0.6))
                        .padding(14)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                }
                .padding(.top, 16)
                .padding(.bottom, 24)
                .accessibilityLabel(String(localized: "wrapped.close"))
            }
        }
        .onAppear {
            WrappedHapticsManager.shared.play(for: slideThemes.first ?? .intro)
        }
        .sheet(isPresented: $showShareSheet) {
            if let shareImage {
                WrappedShareSheet(items: [shareImage])
            }
        }
    }

    // MARK: - Slide picker (tabs)

    private var slidePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Array(slideThemes.enumerated()), id: \.offset) { index, theme in
                    Button {
                        navigateTo(index)
                    } label: {
                        Text(theme.label)
                            .font(.system(size: 10, weight: index == currentSlide ? .bold : .regular))
                            .foregroundColor(index == currentSlide ? .white : .white.opacity(0.3))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(index == currentSlide ? Color(hex: "4DA8F5") : Color.white.opacity(0.08))
                            )
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.top, 12)
    }

    // MARK: - Progress bars

    private var progressBars: some View {
        HStack(spacing: 3) {
            ForEach(0..<slideCount, id: \.self) { i in
                RoundedRectangle(cornerRadius: 3)
                    .fill(i <= currentSlide ? Color.white.opacity(0.9) : Color.white.opacity(0.2))
                    .frame(height: 3)
            }
        }
    }

    // MARK: - Navigation

    private func goToNext() {
        guard currentSlide < slideCount - 1 else { return }
        navigateTo(currentSlide + 1)
    }

    private func goToPrevious() {
        guard currentSlide > 0 else { return }
        navigateTo(currentSlide - 1)
    }

    private func navigateTo(_ index: Int) {
        guard index >= 0 && index < slideCount else { return }
        withAnimation(.easeInOut(duration: 0.25)) {
            currentSlide = index
        }
        WrappedHapticsManager.shared.play(for: slideThemes[index])
    }

    // MARK: - Slide content router

    @ViewBuilder
    private func slideContent(for theme: WrappedSlideTheme, index: Int) -> some View {
        let isActive = index == currentSlide
        switch theme {
        case .intro:     WrappedIntroSlide(data: data)
        case .water:     WrappedVolumeSlide(data: data, active: isActive)
        case .streak:    WrappedStreakSlide(data: data, active: isActive)
        case .sober:     WrappedSoberSlide(data: data, active: isActive)
        case .month:     WrappedMonthSlide(data: data, active: isActive)
        case .habits:    WrappedHabitsSlide(data: data, active: isActive)
        case .xp:        WrappedXPSlide(data: data, active: isActive)
        case .finale:    WrappedFinaleSlide(data: data)
        case .legendary: WrappedLegendarySlide(data: data)
        case .share:
            WrappedShareSlide(data: data) { format in
                shareFormat = format
                exportAndShare(format: format)
            }
        }
    }

    // MARK: - Export image

    private func exportAndShare(format: WrappedShareFormat) {
        let renderer = ImageRenderer(content: WrappedShareCard(data: data, format: format))
        if let uiImage = renderer.uiImage {
            shareImage = uiImage
            WrappedHapticsManager.shared.play(for: .share)
            showShareSheet = true
        }
    }
}

// MARK: - WrappedSlideTheme label

extension WrappedSlideTheme {
    var label: String {
        switch self {
        case .intro:     return String(localized: "wrapped.tab.intro")
        case .water:     return String(localized: "wrapped.tab.water")
        case .streak:    return String(localized: "wrapped.tab.streak")
        case .sober:     return String(localized: "wrapped.tab.sober")
        case .month:     return String(localized: "wrapped.tab.month")
        case .habits:    return String(localized: "wrapped.tab.habits")
        case .xp:        return String(localized: "wrapped.tab.xp")
        case .finale:    return String(localized: "wrapped.tab.finale")
        case .legendary: return String(localized: "wrapped.tab.legendary")
        case .share:     return String(localized: "wrapped.tab.share")
        }
    }
}

// MARK: - Shared building blocks

/// Fond avec effet de respiration — pulse doux et continu du dégradé.
struct WrappedBreathingBackground: View {
    let colors: [Color]
    @State private var pulse: Bool = false

    var body: some View {
        LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            .scaleEffect(pulse ? 1.04 : 1.0)
            .opacity(pulse ? 1.0 : 0.92)
            .animation(.easeInOut(duration: 4.5).repeatForever(autoreverses: true), value: pulse)
            .onAppear { pulse = true }
            .ignoresSafeArea()
    }
}

/// Particules flottantes thématiques.
struct WrappedParticles: View {
    let colors: [Color]
    var count: Int = 16

    @State private var particles: [WrappedParticle] = []

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(particles) { particle in
                    Circle()
                        .fill(particle.color)
                        .frame(width: particle.size, height: particle.size)
                        .position(x: particle.x * geo.size.width, y: particle.y * geo.size.height)
                        .opacity(particle.opacity)
                }
            }
            .onAppear {
                particles = (0..<count).map { _ in
                    WrappedParticle(
                        x: .random(in: 0...1), y: .random(in: 0...1),
                        size: .random(in: 3...9),
                        color: colors.randomElement() ?? .white,
                        opacity: .random(in: 0.2...0.5)
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }
}

private struct WrappedParticle: Identifiable {
    let id = UUID()
    let x, y: CGFloat
    let size: CGFloat
    let color: Color
    let opacity: Double
}

/// Texte avec anti-spoil : flou/pixelisé brièvement avant de se révéler.
struct WrappedRevealText: View {
    let text: String
    let font: Font
    let color: Color
    var delay: Double = 0.3

    @State private var revealed: Bool = false

    var body: some View {
        Text(text)
            .font(font)
            .foregroundColor(color)
            .blur(radius: revealed ? 0 : 14)
            .opacity(revealed ? 1 : 0.4)
            .scaleEffect(revealed ? 1 : 0.92)
            .animation(.easeOut(duration: 0.5), value: revealed)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    revealed = true
                }
            }
    }
}

/// Compteur animé classique (count-up).
struct WrappedCountUpText: View {
    let target: Int
    var duration: Double = 1.2
    var active: Bool
    let font: Font
    let color: Color
    var formatter: (Int) -> String = { "\($0)" }

    @State private var current: Int = 0

    var body: some View {
        Text(formatter(current))
            .font(font)
            .foregroundColor(color)
            .monospacedDigit()
            .onChange(of: active) { _, newValue in
                guard newValue else { current = 0; return }
                animate()
            }
            .onAppear { if active { animate() } }
    }

    private func animate() {
        let steps = 40
        let stepDuration = duration / Double(steps)
        for i in 0...steps {
            let progress = Double(i) / Double(steps)
            let eased    = 1 - pow(1 - progress, 3)
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * stepDuration) {
                current = Int(eased * Double(target))
            }
        }
    }
}

/// Compteur XP en gouttes — chaque goutte tombe et ajoute des XP au total,
/// avec un petit haptique synchronisé à chaque impact.
struct WrappedDropletCounter: View {
    let targetXP: Int
    var active: Bool

    @State private var displayedXP: Int = 0
    @State private var droplets: [DropletAnim] = []

    private struct DropletAnim: Identifiable {
        let id = UUID()
        var fallen: Bool = false
    }

    /// Nombre de gouttes à animer — entre 6 et 12 selon le montant total
    private var dropletCount: Int { min(max(targetXP / 600, 6), 12) }
    private var xpPerDroplet: Int { targetXP / max(dropletCount, 1) }

    var body: some View {
        VStack(spacing: 14) {
            // Zone de chute des gouttes
            ZStack {
                ForEach(Array(droplets.enumerated()), id: \.element.id) { index, droplet in
                    Image(systemName: "drop.fill")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "4DA8F5"))
                        .offset(y: droplet.fallen ? 30 : -30)
                        .opacity(droplet.fallen ? 0 : 1)
                        .offset(x: CGFloat(index - dropletCount / 2) * 4)
                }
            }
            .frame(height: 50)

            // Compteur XP qui s'incrémente goutte par goutte
            Text("\(displayedXP.formatted()) XP")
                .font(.system(size: 52, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .monospacedDigit()
        }
        .onChange(of: active) { _, newValue in
            guard newValue else { reset(); return }
            startDropletAnimation()
        }
        .onAppear { if active { startDropletAnimation() } }
    }

    private func reset() {
        displayedXP = 0
        droplets = []
    }

    private func startDropletAnimation() {
        reset()
        droplets = (0..<dropletCount).map { _ in DropletAnim() }

        for i in 0..<dropletCount {
            let delay = Double(i) * 0.18
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.easeIn(duration: 0.3)) {
                    if i < droplets.count { droplets[i].fallen = true }
                }
                displayedXP = min(displayedXP + xpPerDroplet, targetXP)
                WrappedHapticsManager.shared.playSingleDroplet()
                if i == dropletCount - 1 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        displayedXP = targetXP // garantit le total exact
                    }
                }
            }
        }
    }
}

// MARK: - Slide générique (wrapper commun)

struct WrappedSlideBase<Content: View>: View {
    let gradientColors: [Color]
    let particleColors: [Color]
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            WrappedBreathingBackground(colors: gradientColors)
            WrappedParticles(colors: particleColors)
            VStack {
                Spacer()
                content()
                Spacer()
            }
            .padding(.horizontal, 28)
            .padding(.top, 50)
            .padding(.bottom, 30)
        }
    }
}

// MARK: - Slide 0 — Intro

struct WrappedIntroSlide: View {
    let data: WrappedData

    var body: some View {
        WrappedSlideBase(
            gradientColors: [Color(hex: "050D1A"), Color(hex: "0D1A2E"), Color(hex: "0A2240")],
            particleColors: [Color(hex: "4DA8F5"), Color(hex: "F59E0B"), Color(hex: "10B981"), Color(hex: "F06595")]
        ) {
            VStack(spacing: 14) {
                Image(systemName: "drop.fill")
                    .font(.system(size: 56))
                    .foregroundColor(Color(hex: "4DA8F5"))

                Text("AQUAPP")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color(hex: "4DA8F5"))
                    .kerning(3)

                Text(String(format: String(localized: "wrapped.intro.title"), data.year))
                    .font(.system(size: 36, weight: .black))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .padding(.top, 4)

                Text(String(format: String(localized: "wrapped.intro.subtitle"), data.userName))
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.top, 6)

                Text(String(localized: "wrapped.intro.cta"))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(
                        LinearGradient(colors: [Color(hex: "4DA8F5"), Color(hex: "2B87E8")],
                                       startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(Capsule())
                    .padding(.top, 24)
            }
        }
    }
}

// MARK: - Slide 1 — Volume

struct WrappedVolumeSlide: View {
    let data: WrappedData
    let active: Bool

    var body: some View {
        WrappedSlideBase(
            gradientColors: [Color(hex: "051828"), Color(hex: "0D1A2E")],
            particleColors: [Color(hex: "4DA8F5"), Color(hex: "4DABF7")]
        ) {
            VStack(spacing: 10) {
                Text(String(localized: "wrapped.volume.eyebrow"))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color(hex: "4DA8F5"))
                    .kerning(3)

                Text(String(localized: "wrapped.volume.lead"))
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.4))
                    .padding(.bottom, 18)

                Image(systemName: "drop.fill")
                    .font(.system(size: 36))
                    .foregroundColor(Color(hex: "4DA8F5").opacity(0.3))

                WrappedRevealText(
                    text: "\(Int(data.totalLiters))",
                    font: .system(size: 80, weight: .black, design: .rounded),
                    color: .white
                )
                .monospacedDigit()

                Text(String(localized: "wrapped.volume.unit"))
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(Color(hex: "4DA8F5"))
                    .padding(.bottom, 18)

                VStack(spacing: 2) {
                    Text("\(data.totalGlasses.formatted())")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    Text(String(localized: "wrapped.volume.glasses"))
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.45))
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 22)
                .background(Color(hex: "4DA8F5").opacity(0.10))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(hex: "4DA8F5").opacity(0.2), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))

                Text(String(format: String(localized: "wrapped.volume.avg"), data.avgDailyMl / 1000.0))
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.3))
                    .padding(.top, 14)
            }
        }
    }
}

// MARK: - Slide 2 — Streak & Objectif

struct WrappedStreakSlide: View {
    let data: WrappedData
    let active: Bool

    private var pct: Double { min(Double(data.goalDays) / 365.0, 1.0) }

    var body: some View {
        WrappedSlideBase(
            gradientColors: [Color(hex: "0A0520"), Color(hex: "1A0A30")],
            particleColors: [Color(hex: "8B5CF6"), Color(hex: "4DA8F5"), Color(hex: "F59E0B")]
        ) {
            VStack(spacing: 16) {
                Text(String(localized: "wrapped.streak.eyebrow"))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color(hex: "8B5CF6"))
                    .kerning(3)

                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.08), lineWidth: 8)
                        .frame(width: 140, height: 140)
                    Circle()
                        .trim(from: 0, to: active ? pct : 0)
                        .stroke(
                            LinearGradient(colors: [Color(hex: "8B5CF6"), Color(hex: "4DA8F5")],
                                           startPoint: .leading, endPoint: .trailing),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .frame(width: 140, height: 140)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut(duration: 1.0), value: active)
                    VStack(spacing: 2) {
                        Text("\(Int(pct * 100))%")
                            .font(.system(size: 28, weight: .black))
                            .foregroundColor(.white)
                        Text(String(localized: "wrapped.streak.ofyear"))
                            .font(.system(size: 9))
                            .foregroundColor(.white.opacity(0.4))
                    }
                }

                WrappedCountUpText(
                    target: data.goalDays, active: active,
                    font: .system(size: 48, weight: .black, design: .rounded),
                    color: .white
                )

                Text(String(localized: "wrapped.streak.goaldays"))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color(hex: "8B5CF6"))

                HStack(spacing: 10) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 22))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(String(format: String(localized: "wrapped.streak.best"), data.bestStreak))
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(Color(hex: "FCD34D"))
                        Text(String(localized: "wrapped.streak.best_label"))
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.4))
                    }
                }
                .foregroundColor(Color(hex: "FCD34D"))
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color(hex: "F59E0B").opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color(hex: "F59E0B").opacity(0.25), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.top, 6)
            }
        }
    }
}

// MARK: - Slide 3 — Sobriété

struct WrappedSoberSlide: View {
    let data: WrappedData
    let active: Bool

    var body: some View {
        WrappedSlideBase(
            gradientColors: [Color(hex: "021A0F"), Color(hex: "042810")],
            particleColors: [Color(hex: "10B981"), Color(hex: "34D399"), Color(hex: "6EE7B7")]
        ) {
            VStack(spacing: 10) {
                Text(String(localized: "wrapped.sober.eyebrow"))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color(hex: "10B981"))
                    .kerning(3)
                    .padding(.bottom, 14)

                Image(systemName: "leaf.fill")
                    .font(.system(size: 56))
                    .foregroundColor(Color(hex: "10B981"))

                WrappedCountUpText(
                    target: data.soberDays, active: active,
                    font: .system(size: 64, weight: .black, design: .rounded),
                    color: .white
                )

                Text(String(localized: "wrapped.sober.days"))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color(hex: "10B981"))
                    .padding(.bottom, 6)

                Text(String(format: String(localized: "wrapped.sober.percent"),
                            Int((Double(data.soberDays) / 365.0) * 100)))
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.4))

                if data.alcoholLiters > 0 {
                    VStack(spacing: 3) {
                        Text(String(localized: "wrapped.sober.alcohol_consumed"))
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.3))
                        Text(String(format: "%.1f L", data.alcoholLiters))
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.white.opacity(0.55))
                        if !data.topAlcoholKind.isEmpty {
                            Text(String(format: String(localized: "wrapped.sober.top_kind"), data.topAlcoholKind))
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.25))
                        }
                    }
                    .padding(.top, 20)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
        }
    }
}

// MARK: - Slide 4 — Mois record

struct WrappedMonthSlide: View {
    let data: WrappedData
    let active: Bool

    var body: some View {
        WrappedSlideBase(
            gradientColors: [Color(hex: "1A0E00"), Color(hex: "251500")],
            particleColors: [Color(hex: "F59E0B"), Color(hex: "FB923C"), Color(hex: "FCD34D")]
        ) {
            VStack(spacing: 8) {
                Text(String(localized: "wrapped.month.eyebrow"))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color(hex: "F59E0B"))
                    .kerning(3)

                Text(data.bestMonthName)
                    .font(.system(size: 36, weight: .black))
                    .foregroundColor(.white)
                    .padding(.top, 4)

                Text(String(format: String(localized: "wrapped.month.record"), Int(data.bestMonthLiters)))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "F59E0B"))
                    .padding(.bottom, 20)

                // Mini graphique 12 mois
                HStack(alignment: .bottom, spacing: 4) {
                    ForEach(Array(data.monthlyTotals.enumerated()), id: \.offset) { index, value in
                        let maxVal = data.monthlyTotals.max() ?? 1
                        let ratio  = maxVal > 0 ? value / maxVal : 0
                        let isBest = value == maxVal
                        VStack(spacing: 3) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(isBest
                                      ? AnyShapeStyle(LinearGradient(colors: [Color(hex: "F59E0B"), Color(hex: "FCD34D")], startPoint: .bottom, endPoint: .top))
                                      : AnyShapeStyle(Color.white.opacity(0.12)))
                                .frame(height: max(CGFloat(ratio) * 70, 4))
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 70)
                .padding(.horizontal, 4)

                HStack(spacing: 4) {
                    ForEach(data.monthLabels, id: \.self) { label in
                        Text(label)
                            .font(.system(size: 8))
                            .foregroundColor(.white.opacity(0.25))
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 4)

                if data.heatwaveDays > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "thermometer.sun.fill")
                            .font(.system(size: 12))
                        Text(String(format: String(localized: "wrapped.month.heatwave"), data.heatwaveDays))
                            .font(.system(size: 12))
                    }
                    .foregroundColor(Color(hex: "FB923C"))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color(hex: "FB923C").opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.top, 16)
                }
            }
        }
    }
}

// MARK: - Slide 5 — Habitudes

struct WrappedHabitsSlide: View {
    let data: WrappedData
    let active: Bool

    var body: some View {
        WrappedSlideBase(
            gradientColors: [Color(hex: "0D0520"), Color(hex: "180830")],
            particleColors: [Color(hex: "4DA8F5"), Color(hex: "F06595"), Color(hex: "8B5CF6")]
        ) {
            VStack(spacing: 8) {
                Text(String(localized: "wrapped.habits.eyebrow"))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color(hex: "F06595"))
                    .kerning(3)
                    .padding(.bottom, 14)

                Image(systemName: "sunrise.fill")
                    .font(.system(size: 48))
                    .foregroundColor(Color(hex: "F06595"))

                WrappedCountUpText(
                    target: data.morningDays, active: active,
                    font: .system(size: 56, weight: .black, design: .rounded),
                    color: .white
                )

                Text(String(localized: "wrapped.habits.mornings"))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color(hex: "F06595"))
                    .padding(.bottom, 20)

                HStack(spacing: 10) {
                    WrappedStatCard(
                        icon: "rosette", value: "\(data.achievementsCount)",
                        label: String(localized: "wrapped.habits.achievements"),
                        color: Color(hex: "F59E0B")
                    )
                    WrappedStatCard(
                        icon: "bolt.fill", value: "\(data.challengesCount)",
                        label: String(localized: "wrapped.habits.challenges"),
                        color: Color(hex: "4DA8F5")
                    )
                }
            }
        }
    }
}

private struct WrappedStatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 20, weight: .black))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.4))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.04))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.08), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Slide 6 — XP (gouttes qui tombent)

struct WrappedXPSlide: View {
    let data: WrappedData
    let active: Bool

    var body: some View {
        WrappedSlideBase(
            gradientColors: [Color(hex: "0A0518"), Color(hex: "130A28")],
            particleColors: [Color(hex: "8B5CF6"), Color(hex: "4DA8F5"), Color(hex: "F06595"), Color(hex: "F59E0B")]
        ) {
            VStack(spacing: 14) {
                Text(String(localized: "wrapped.xp.eyebrow"))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color(hex: "8B5CF6"))
                    .kerning(3)

                ZStack {
                    RoundedRectangle(cornerRadius: 26)
                        .fill(
                            LinearGradient(colors: [Color(hex: "8B5CF6"), Color(hex: "4DA8F5")],
                                           startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .frame(width: 84, height: 84)
                        .shadow(color: Color(hex: "8B5CF6").opacity(0.5), radius: 20)
                    Image(systemName: "drop.fill")
                        .font(.system(size: 36))
                        .foregroundColor(.white)
                }

                WrappedDropletCounter(targetXP: data.xpTotal, active: active)

                Text(String(format: String(localized: "wrapped.xp.level"), data.xpLevelName))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)

                Text(String(format: String(localized: "wrapped.xp.subtitle"), data.totalGlasses))
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.4))
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 8)
            }
        }
    }
}

// MARK: - Slide 7 — Bilan final

struct WrappedFinaleSlide: View {
    let data: WrappedData

    var body: some View {
        WrappedSlideBase(
            gradientColors: [Color(hex: "050D1A"), Color(hex: "0D1A2E"), Color(hex: "0A1A30")],
            particleColors: [Color(hex: "4DA8F5"), Color(hex: "F59E0B"), Color(hex: "10B981"), Color(hex: "F06595"), Color(hex: "8B5CF6")]
        ) {
            VStack(spacing: 16) {
                Image(systemName: "drop.fill")
                    .font(.system(size: 44))
                    .foregroundColor(Color(hex: "4DA8F5"))

                Text(String(format: String(localized: "wrapped.finale.eyebrow"), data.year))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color(hex: "4DA8F5"))
                    .kerning(3)

                Text(String(format: String(localized: "wrapped.finale.title"), data.percentileTop))
                    .font(.system(size: 28, weight: .black))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)

                VStack(spacing: 8) {
                    WrappedSummaryRow(label: String(localized: "wrapped.finale.water"),
                                       value: String(format: "%.0f L", data.totalLiters), color: Color(hex: "4DA8F5"))
                    WrappedSummaryRow(label: String(localized: "wrapped.finale.goaldays"),
                                       value: "\(data.goalDays)", color: Color(hex: "8B5CF6"))
                    WrappedSummaryRow(label: String(localized: "wrapped.finale.soberdays"),
                                       value: "\(data.soberDays)", color: Color(hex: "10B981"))
                    WrappedSummaryRow(label: String(localized: "wrapped.finale.beststreak"),
                                       value: "\(data.bestStreak)", color: Color(hex: "F59E0B"))
                }
                .padding(.top, 8)

                // Message adaptatif selon le profil dominant de l'utilisateur
                Text(data.adaptiveClosingMessage)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.4))
                    .multilineTextAlignment(.center)
                    .padding(.top, 10)
            }
        }
    }
}

private struct WrappedSummaryRow: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.5))
            Spacer()
            Text(value)
                .font(.system(size: 15, weight: .black))
                .foregroundColor(color)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.04))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.07), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Slide easter egg — Légendaire

struct WrappedLegendarySlide: View {
    let data: WrappedData

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "1A1400"), Color(hex: "2D2200"), Color(hex: "1A1400")],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            WrappedParticles(colors: [Color(hex: "FCD34D"), Color(hex: "F59E0B"), .white], count: 30)

            VStack(spacing: 18) {
                Spacer()

                Image(systemName: "crown.fill")
                    .font(.system(size: 52))
                    .foregroundColor(Color(hex: "FCD34D"))
                    .shadow(color: Color(hex: "F59E0B").opacity(0.6), radius: 16)

                Text(String(localized: "wrapped.legendary.eyebrow"))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color(hex: "FCD34D"))
                    .kerning(3)

                Text(String(localized: "wrapped.legendary.title"))
                    .font(.system(size: 32, weight: .black))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Text(data.legendaryReason)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color(hex: "FCD34D"))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)

                Text(String(localized: "wrapped.legendary.subtitle"))
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .padding(.top, 6)

                Spacer()
            }
            .padding(.horizontal, 28)
        }
    }
}

// MARK: - Slide partage

enum WrappedShareFormat {
    case story   // 9:16
    case square  // 1:1
}

struct WrappedShareSlide: View {
    let data: WrappedData
    let onShare: (WrappedShareFormat) -> Void

    var body: some View {
        WrappedSlideBase(
            gradientColors: [Color(hex: "050D1A"), Color(hex: "0A1525"), Color(hex: "051020")],
            particleColors: [Color(hex: "4DA8F5"), Color(hex: "F59E0B"), Color(hex: "F06595")]
        ) {
            VStack(spacing: 20) {
                // Mini aperçu de la carte
                WrappedShareCardPreview(data: data)

                Text(String(localized: "wrapped.share.title"))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white.opacity(0.5))
                    .kerning(1)

                HStack(spacing: 10) {
                    WrappedShareButton(icon: "rectangle.portrait.fill", label: String(localized: "wrapped.share.story")) {
                        onShare(.story)
                    }
                    WrappedShareButton(icon: "square.fill", label: String(localized: "wrapped.share.square")) {
                        onShare(.square)
                    }
                }
            }
        }
    }
}

private struct WrappedShareButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color(hex: "4DA8F5").opacity(0.12))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(hex: "4DA8F5").opacity(0.25), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
}

private struct WrappedShareCardPreview: View {
    let data: WrappedData

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "drop.fill").font(.system(size: 14)).foregroundColor(Color(hex: "4DA8F5"))
                Text("AQUAPP \(String(data.year))")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color(hex: "4DA8F5"))
                    .kerning(0.5)
            }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                WrappedMiniStat(value: String(format: "%.0f L", data.totalLiters), label: String(localized: "wrapped.finale.water"), color: Color(hex: "4DA8F5"))
                WrappedMiniStat(value: "\(data.goalDays)j", label: String(localized: "wrapped.finale.goaldays"), color: Color(hex: "8B5CF6"))
                WrappedMiniStat(value: "\(data.soberDays)j", label: String(localized: "wrapped.finale.soberdays"), color: Color(hex: "10B981"))
                WrappedMiniStat(value: data.xpLevelName, label: String(localized: "wrapped.xp.eyebrow"), color: Color(hex: "F59E0B"))
            }
        }
        .padding(16)
        .background(
            LinearGradient(colors: [Color(hex: "0D1A2E"), Color(hex: "0A2240")],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color(hex: "4DA8F5").opacity(0.2), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .frame(maxWidth: 260)
    }
}

private struct WrappedMiniStat: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.system(size: 15, weight: .black)).foregroundColor(color)
            Text(label).font(.system(size: 9)).foregroundColor(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Carte d'export (image réelle générée via ImageRenderer)

struct WrappedShareCard: View {
    let data: WrappedData
    let format: WrappedShareFormat

    private var size: CGSize {
        format == .story ? CGSize(width: 1080, height: 1920) : CGSize(width: 1080, height: 1080)
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "050D1A"), Color(hex: "0D1A2E"), Color(hex: "0A2240")],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )

            VStack(spacing: format == .story ? 36 : 24) {
                Spacer()

                Image(systemName: "drop.fill")
                    .font(.system(size: 56))
                    .foregroundColor(Color(hex: "4DA8F5"))

                Text("AQUAPP \(String(data.year))")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(Color(hex: "4DA8F5"))
                    .kerning(2)

                Text(String(format: String(localized: "wrapped.share.card_title"), data.userName))
                    .font(.system(size: 38, weight: .black))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 60)

                VStack(spacing: 16) {
                    WrappedExportStatRow(label: String(localized: "wrapped.finale.water"), value: String(format: "%.0f L", data.totalLiters), color: Color(hex: "4DA8F5"))
                    WrappedExportStatRow(label: String(localized: "wrapped.finale.goaldays"), value: "\(data.goalDays) jours", color: Color(hex: "8B5CF6"))
                    WrappedExportStatRow(label: String(localized: "wrapped.finale.soberdays"), value: "\(data.soberDays) jours", color: Color(hex: "10B981"))
                    WrappedExportStatRow(label: String(localized: "wrapped.finale.beststreak"), value: "\(data.bestStreak) jours", color: Color(hex: "F59E0B"))
                }
                .padding(.horizontal, 60)

                Text(String(format: String(localized: "wrapped.share.percentile"), data.percentileTop))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.top, 8)

                Spacer()

                // QR code + filigrane App Store
                VStack(spacing: 10) {
                    WrappedQRCodeView(urlString: "https://apps.apple.com/app/aquapp")
                        .frame(width: 90, height: 90)
                        .padding(8)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                    Text(String(localized: "wrapped.share.watermark"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.4))
                }
                .padding(.bottom, format == .story ? 60 : 32)
            }
        }
        .frame(width: size.width, height: size.height)
    }
}

private struct WrappedExportStatRow: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack {
            Text(label).font(.system(size: 20)).foregroundColor(.white.opacity(0.55))
            Spacer()
            Text(value).font(.system(size: 24, weight: .black)).foregroundColor(color)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color.white.opacity(0.05))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.1), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - QR Code generator

struct WrappedQRCodeView: View {
    let urlString: String

    var body: some View {
        if let image = generateQRCode(from: urlString) {
            Image(uiImage: image)
                .resizable()
                .interpolation(.none)
                .scaledToFit()
        } else {
            Color.gray.opacity(0.2)
        }
    }

    private func generateQRCode(from string: String) -> UIImage? {
        let context = CIContext()
        let filter  = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        guard let outputImage = filter.outputImage else { return nil }
        let transformed = outputImage.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        guard let cgImage = context.createCGImage(transformed, from: transformed.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

// MARK: - Share Sheet (UIActivityViewController wrapper)

struct WrappedShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
