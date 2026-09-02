import SwiftUI

// MARK: - LiquidXPBar
// Barre de progression XP avec effet liquide :
//   • Shimmer glissant sur le remplissage
//   • Bulles qui montent aléatoirement
//   • Vague animée sur le bord droit du remplissage
//   • Animation spring sur le changement de progression
//   • Couleurs bleues foncées bien visibles sur fond clair et sombre

struct LiquidXPBar: View {

    let progress:  Double    // 0…1
    let color:     Color
    var height:    CGFloat = 10

    // Couleurs fixes bleu AquApp — indépendantes du niveau
    // pour garantir la lisibilité sur fond clair
    private let fillStart  = Color(hex: "1A5FBB")  // bleu foncé
    private let fillMid    = Color(hex: "2B87E8")  // bleu medium
    private let fillEnd    = Color(hex: "4DA8F5")  // bleu clair

    // ── État interne ─────────────────────────────────────────────────────────
    @State private var shimmerOffset: CGFloat = -1.0
    @State private var bubbles: [Bubble]      = []
    @State private var waveOffset: CGFloat    = 0
    @State private var bubblesTimer: Timer?   = nil

    // ── Modèle bulle ─────────────────────────────────────────────────────────
    struct Bubble: Identifiable {
        let id    = UUID()
        var x:    CGFloat
        var y:    CGFloat
        var size: CGFloat
        var opacity: Double
    }

    var body: some View {
        GeometryReader { geo in
            let fillWidth = geo.size.width * max(0, min(1, progress))

            ZStack(alignment: .leading) {

                // ── Track ─────────────────────────────────────────────────────
                // Fond bleu désaturé visible sur fond clair (AppCardBackground)
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(Color(hex: "B8D9F8"))        // bleu pâle opaque
                    .overlay(
                        RoundedRectangle(cornerRadius: height / 2)
                            .stroke(Color(hex: "85B7EB"), lineWidth: 0.75)
                    )

                // ── Remplissage liquide ───────────────────────────────────────
                if progress > 0 {
                    ZStack {
                        // Gradient bleu foncé → bleu clair — toujours lisible
                        RoundedRectangle(cornerRadius: height / 2)
                            .fill(
                                LinearGradient(
                                    colors: [fillStart, fillMid, fillEnd],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )

                        // Shimmer glissant — subtil pour ne pas décolorer
                        RoundedRectangle(cornerRadius: height / 2)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        .clear,
                                        .white.opacity(0.20),
                                        .clear
                                    ],
                                    startPoint: UnitPoint(x: shimmerOffset - 0.3, y: 0),
                                    endPoint:   UnitPoint(x: shimmerOffset + 0.3, y: 0)
                                )
                            )

                        // Reflet supérieur style Apple glass
                        VStack {
                            RoundedRectangle(cornerRadius: height / 2)
                                .fill(
                                    LinearGradient(
                                        colors: [.white.opacity(0.18), .clear],
                                        startPoint: .top, endPoint: .bottom
                                    )
                                )
                                .frame(height: height * 0.40)
                            Spacer()
                        }

                        // Bulles flottantes
                        ForEach(bubbles) { bubble in
                            Circle()
                                .fill(.white.opacity(bubble.opacity))
                                .frame(width: bubble.size, height: bubble.size)
                                .position(
                                    x: bubble.x * fillWidth,
                                    y: bubble.y * geo.size.height
                                )
                        }
                    }
                    .frame(width: fillWidth)
                    .clipShape(RoundedRectangle(cornerRadius: height / 2))

                    // Vague sur le bord droit
                    if progress < 0.98 {
                        ZStack(alignment: .trailing) {
                            Color.clear
                            Circle()
                                .fill(fillMid.opacity(0.7))
                                .frame(width: height * 1.3, height: height * 1.3)
                                .scaleEffect(1.0 + 0.10 * sin(waveOffset * Double.pi * 2))
                                .opacity(0.7 + 0.2 * sin(waveOffset * Double.pi * 2))
                        }
                        .frame(width: fillWidth, height: geo.size.height)
                        .clipShape(RoundedRectangle(cornerRadius: height / 2))
                    }
                }
            }
            .frame(height: height)
            .onAppear {
                startShimmer()
                startBubbles(in: geo.size)
                startWave()
            }
            .onDisappear {
                // Invalide le Timer de bulles quand la vue disparaît
                // pour éviter qu'il continue de tourner en background.
                bubblesTimer?.invalidate()
                bubblesTimer = nil
            }
            .onChange(of: progress) { _, _ in
                spawnBurstBubbles(in: geo.size, count: 4)
            }
        }
        .frame(height: height)
        .animation(.spring(response: 0.8, dampingFraction: 0.75), value: progress)
    }

    // MARK: - Animations

    private func startShimmer() {
        shimmerOffset = -0.5
        withAnimation(.linear(duration: 2.4).repeatForever(autoreverses: false)) {
            shimmerOffset = 1.5
        }
    }

    private func startWave() {
        withAnimation(.linear(duration: 1.8).repeatForever(autoreverses: false)) {
            waveOffset = 1.0
        }
    }

    private func startBubbles(in size: CGSize) {
        // Stocké dans bubblesTimer pour pouvoir l'invalider dans onDisappear.
        bubblesTimer = Timer.scheduledTimer(withTimeInterval: 1.8, repeats: true) { _ in
            spawnBurstBubbles(in: size, count: 1)
        }
    }

    private func spawnBurstBubbles(in size: CGSize, count: Int) {
        guard progress > 0.05 else { return }
        for _ in 0..<count {
            let bubble = Bubble(
                x:       CGFloat.random(in: 0.05...0.95),
                y:       1.0,
                size:    CGFloat.random(in: 2...4),
                opacity: Double.random(in: 0.25...0.50)
            )
            withAnimation { bubbles.append(bubble) }

            let duration = Double.random(in: 0.7...1.4)
            withAnimation(.easeOut(duration: duration)) {
                if let idx = bubbles.firstIndex(where: { $0.id == bubble.id }) {
                    bubbles[idx].y       = CGFloat.random(in: -0.1...0.3)
                    bubbles[idx].opacity = 0
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.1) {
                bubbles.removeAll { $0.id == bubble.id }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 24) {
        ForEach([0.15, 0.42, 0.68, 0.92, 1.0], id: \.self) { p in
            LiquidXPBar(
                progress: p,
                color:    Color(hex: "4DA8F5"),
                height:   10
            )
            .padding(.horizontal)
        }
    }
    .padding(.vertical, 32)
    .background(Color("AppBackground"))
}
