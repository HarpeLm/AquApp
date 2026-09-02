//
//  ConfettisView.swift
//  AquApp
//
//  Created by Fabian Dargaud on 15/03/2026.
//
import SwiftUI

// MARK: - Confetti Particle

struct ConfettiParticle: Identifiable {
    let id = UUID()
    let color: Color
    let position: CGPoint
    let size: CGSize
    let rotation: Double
    let velocity: CGVector
    let shape: ConfettiShape
}

enum ConfettiShape {
    case rectangle, circle, triangle
}

// MARK: - ConfettiView

struct ConfettiView: View {

    @State private var particles: [ConfettiParticle] = []
    @State private var animating = false
    @Binding var isActive: Bool

    let colors: [Color] = [
        Color(hex: "4DA8F5"), Color(hex: "FF6B6B"), Color(hex: "FFD93D"),
        Color(hex: "6BCB77"), Color(hex: "FF922B"), Color(hex: "CC5DE8"),
        Color(hex: "F06595"), Color(hex: "4DABF7"), Color(hex: "51CF66")
    ]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(particles) { particle in
                    ConfettiPieceView(particle: particle, animating: animating, screenHeight: geo.size.height)
                }
            }
            .onAppear {
                guard isActive else { return }
                triggerConfetti(in: geo.size)
            }
            
            .onChange(of: isActive) { _, newValue in
                if newValue {
                    triggerConfetti(in: geo.size)
                }
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }

    private func triggerConfetti(in size: CGSize) {
        generateParticles(in: size)
        withAnimation { animating = true }

        // Délègue tous les haptiques à HapticManager dont les générateurs
        // sont préchauffés au lancement — évite la latence et respecte
        // le réglage système "Réduire le mouvement".
        HapticManager.shared.confettiTriggered()

        // Stop après 3.5s
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            isActive = false
            particles = []
            animating = false
        }
    }

    private func generateParticles(in size: CGSize) {
        particles = (0..<120).map { _ in
            ConfettiParticle(
                color: colors.randomElement()!,
                position: CGPoint(
                    x: CGFloat.random(in: 0...size.width),
                    y: -20
                ),
                size: CGSize(
                    width: CGFloat.random(in: 6...14),
                    height: CGFloat.random(in: 6...14)
                ),
                rotation: Double.random(in: 0...360),
                velocity: CGVector(
                    dx: CGFloat.random(in: -60...60),
                    dy: CGFloat.random(in: 200...600)
                ),
                shape: [ConfettiShape.rectangle, .circle, .triangle].randomElement()!
            )
        }
    }
}

// MARK: - Confetti Piece

struct ConfettiPieceView: View {
    let particle: ConfettiParticle
    let animating: Bool
    let screenHeight: CGFloat

    @State private var offset: CGSize = .zero
    @State private var rotation: Double = 0
    @State private var opacity: Double = 1

    var body: some View {

        Group {
            switch particle.shape {
            case .rectangle:
                Rectangle()
                    .fill(particle.color)
                    .frame(width: particle.size.width, height: particle.size.height)
            case .circle:
                Circle()
                    .fill(particle.color)
                    .frame(width: particle.size.width, height: particle.size.height)
            case .triangle:
                Triangle()
                    .fill(particle.color)
                    .frame(width: particle.size.width, height: particle.size.height)
            }
        }
     
        .rotationEffect(Angle(degrees: rotation))
        .opacity(opacity)
        .position(particle.position)
        .offset(offset)
        .onAppear {
            let duration = Double.random(in: 2.0...3.5)
            withAnimation(.easeIn(duration: duration)) {
                offset = CGSize(
                    width: particle.velocity.dx,
                    height: particle.velocity.dy + screenHeight
                )
                rotation = Double.random(in: 360...1080)
            }
            withAnimation(.linear(duration: duration).delay(duration * 0.6)) {
                opacity = 0
            }
        }
    }
}

// MARK: - Triangle Shape

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Bannière de complétion

struct CompletionBanner: View {
    let sfSymbol: String
    let color: Color
    let title: String
    let onDismiss: () -> Void

    @State private var offset: CGFloat = -200

    var body: some View {
        VStack {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 48, height: 48)
                    Image(systemName: sfSymbol)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(color)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "confetti.challenge_completed"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                    Text(title)
                        .font(.system(size: 17, weight: .bold))
                }

                Spacer()

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.green)
            }
            .padding(16)
            .background(Color("AppCardBackground"))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 4)
            .padding(.horizontal, 16)
            .offset(y: offset)

            Spacer()
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                offset = 60
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                withAnimation(.easeIn(duration: 0.3)) {
                    offset = -200
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    onDismiss()
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.gray.opacity(0.2).ignoresSafeArea()
        ConfettiView(isActive: .constant(true))
    }
}
