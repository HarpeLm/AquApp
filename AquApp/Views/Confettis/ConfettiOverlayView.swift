import SwiftUI
import Combine

// MARK: - ConfettiOverlayView

struct ConfettiOverlayView: View {
    @EnvironmentObject var confettiManager: ConfettiManager

    var body: some View {
        ZStack {

            // Fond semi-transparent
            if confettiManager.isActive {
                Color.black.opacity(0.10)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture {
                        confettiManager.dismiss()
                    }
            }

            // Confettis toujours présents
            ConfettiView(isActive: $confettiManager.isActive)

            // Carte message — tiers supérieur
            if confettiManager.isActive, let event = confettiManager.currentEvent {
                VStack {
                    EventCard(event: event)
                        .padding(.horizontal, 32)
                        .padding(.top, 80)
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .allowsHitTesting(false)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: confettiManager.isActive)
        .onChange(of: confettiManager.isActive) { _, newValue in
            if newValue {
                confettiManager.autoDismiss(after: 3.0)
            }
        }
    }
}

// MARK: - EventCard

private struct EventCard: View {
    let event: ConfettiEvent

    var body: some View {
        HStack(spacing: 12) {

            // Icône principale
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.25))
                    .frame(width: 44, height: 44)
                Image(systemName: event.sfSymbol)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.white)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 3) {
                // Subtitle avec SF Symbol
                HStack(spacing: 4) {
                    Image(systemName: event.subtitleSymbol)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.85))
                        .accessibilityHidden(true)
                    Text(event.subtitle)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.85))
                }

                // Titre principal
                Text(event.title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 22))
                .foregroundColor(.white)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "FFE878"), Color(hex: "FFAB5E")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: Color(hex: "FFAB5E").opacity(0.3), radius: 16, x: 0, y: 6)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(event.subtitle)
        .accessibilityValue(event.title)
    }
}
