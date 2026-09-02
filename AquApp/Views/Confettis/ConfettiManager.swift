import SwiftUI
import Combine

// MARK: - ConfettiEvent

enum ConfettiEvent {
    case goalReached
    case achievementUnlocked(title: String)
    case challengeCompleted(title: String)

    var title: String {
        switch self {
        case .goalReached:
            return String(localized: "confetti.goal_reached.title")
        case .achievementUnlocked(let title):
            return String(format: String(localized: "confetti.achievement.unlocked_title"), title)
        case .challengeCompleted(let title):
            return String(format: String(localized: "confetti.challenge.completed_title"), title)
        }
    }

    var subtitle: String {
        switch self {
        case .goalReached:         return String(localized: "confetti.goal_reached.subtitle")
        case .achievementUnlocked: return String(localized: "confetti.achievement.subtitle")
        case .challengeCompleted:  return String(localized: "confetti.challenge.subtitle")
        }
    }

    var sfSymbol: String {
        switch self {
        case .goalReached:         return "drop.fill"
        case .achievementUnlocked: return "star.fill"
        case .challengeCompleted:  return "trophy.fill"
        }
    }

    /// SF Symbol affiché à côté du subtitle
    var subtitleSymbol: String {
        switch self {
        case .goalReached:         return "hand.thumbsup.fill"
        case .achievementUnlocked: return "rosette"
        case .challengeCompleted:  return "flame.fill"
        }
    }

    var subtitleSymbolColor: Color {
        switch self {
        case .goalReached:         return .orange
        case .achievementUnlocked: return .yellow
        case .challengeCompleted:  return .red
        }
    }

    var color: Color {
        switch self {
        case .goalReached:         return Color(hex: "4DA8F5")
        case .achievementUnlocked: return .yellow
        case .challengeCompleted:  return .orange
        }
    }
}

// MARK: - ConfettiManager

@MainActor
final class ConfettiManager: ObservableObject {

    @Published var isActive: Bool = false
    @Published var currentEvent: ConfettiEvent? = nil

    // Stocke la Task en cours pour pouvoir l'annuler si un nouveau trigger arrive
    // avant la fin de l'auto-dismiss. Remplace DispatchWorkItem.
    private var dismissTask: Task<Void, Never>?

    func trigger(_ event: ConfettiEvent) {
        // @MainActor garantit qu'on est déjà sur le Main Thread —
        // plus besoin de DispatchQueue.main.async
        dismissTask?.cancel()
        currentEvent = event
        isActive     = true
    }

    func dismiss() {
        dismissTask?.cancel()
        withAnimation(.easeOut(duration: 0.4)) {
            isActive = false
        }
        // Task { @MainActor in } remplace DispatchQueue.main.asyncAfter —
        // la Task hérite de l'acteur courant (@MainActor)
        dismissTask = Task {
            try? await Task.sleep(for: .seconds(0.4))
            guard !Task.isCancelled else { return }
            currentEvent = nil
        }
    }

    func autoDismiss(after seconds: Double = 3.0) {
        dismissTask?.cancel()
        dismissTask = Task {
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.6)) {
                isActive = false
            }
            try? await Task.sleep(for: .seconds(0.6))
            guard !Task.isCancelled else { return }
            currentEvent = nil
        }
    }
}
