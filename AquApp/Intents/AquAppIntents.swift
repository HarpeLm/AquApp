import AppIntents

// Siri & Raccourcis. Les intents s'exécutent dans le processus de l'app et passent par
// AppDataStore (enregistré dans AquAppApp.init via AppDependencyManager) : même pipeline
// que l'UI — HealthKit, XP, séries, succès, widget.

// MARK: - Boissons alcoolisées

nonisolated extension AlcoholKind: AppEnum {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "intent.alcohol_kind.type"

    static var caseDisplayRepresentations: [AlcoholKind: DisplayRepresentation] = [
        .beer:     "alcohol.beer",
        .wine:     "alcohol.wine",
        .spirits:  "alcohol.spirits",
        .cider:    "alcohol.cider",
        .cocktail: "alcohol.cocktail",
        .other:    "alcohol.other",
    ]

    /// Portion servie quand l'utilisateur ne précise pas de volume à Siri.
    var defaultServingMl: Int {
        switch self {
        case .beer, .cider: return 250
        case .wine:         return 125
        case .spirits:      return 40
        case .cocktail, .other: return 150
        }
    }
}

// MARK: - Actions (séparées des intents pour être testables avec un store en mémoire)

@MainActor
enum IntentActions {
    static func addWater(_ amountMl: Int, store: AppDataStore) -> String {
        store.addWater(amountMl: Double(amountMl))
        return String(format: String(localized: "intent.add_water.done"),
                      UnitFormatter.volume(Double(amountMl)), UnitFormatter.volume(store.todayWaterMl),
                      UnitFormatter.volume(store.effectiveGoalMl))
    }

    static func addAlcohol(_ kind: AlcoholKind, amountMl: Int?, store: AppDataStore) -> String {
        let amount = amountMl ?? kind.defaultServingMl
        let compensationBefore = store.todayAlcoholCompensationMl
        store.addAlcohol(amountMl: Double(amount), type: kind)
        let toCompensate = store.todayAlcoholCompensationMl - compensationBefore
        return String(format: String(localized: "intent.add_alcohol.done"),
                      kind.localizedName, UnitFormatter.volume(Double(amount)), UnitFormatter.volume(toCompensate))
    }

    static func todayProgress(store: AppDataStore) -> String {
        let drunk = UnitFormatter.volume(store.todayWaterMl)
        let goal = UnitFormatter.volume(store.effectiveGoalMl)
        return store.todayGoalReached
            ? String(format: String(localized: "intent.today.goal_reached"), drunk, goal)
            : String(format: String(localized: "intent.today.result"), drunk, goal, Int(store.todayProgress * 100))
    }
}

// MARK: - Eau

struct AddWaterIntent: AppIntent {
    static var title: LocalizedStringResource = "intent.add_water.title"
    static var description = IntentDescription("intent.add_water.description")

    @Parameter(title: "intent.param.amount_ml", default: 250, inclusiveRange: (50, 2000))
    var amountMl: Int

    @Dependency private var store: AppDataStore

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        .result(dialog: IntentDialog(stringLiteral: IntentActions.addWater(amountMl, store: store)))
    }
}

// MARK: - Alcool

struct AddAlcoholIntent: AppIntent {
    static var title: LocalizedStringResource = "intent.add_alcohol.title"
    static var description = IntentDescription("intent.add_alcohol.description")

    @Parameter(title: "intent.param.alcohol_kind")
    var kind: AlcoholKind

    @Parameter(title: "intent.param.amount_ml", inclusiveRange: (10, 2000))
    var amountMl: Int?

    @Dependency private var store: AppDataStore

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        .result(dialog: IntentDialog(stringLiteral: IntentActions.addAlcohol(kind, amountMl: amountMl, store: store)))
    }
}

// MARK: - Progression

struct TodayProgressIntent: AppIntent {
    static var title: LocalizedStringResource = "intent.today.title"
    static var description = IntentDescription("intent.today.description")

    @Dependency private var store: AppDataStore

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        .result(dialog: IntentDialog(stringLiteral: IntentActions.todayProgress(store: store)))
    }
}

// MARK: - Phrases Siri (traduites dans AppShortcuts.xcstrings)

struct AquAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddWaterIntent(),
            phrases: [
                "Ajoute de l'eau dans \(.applicationName)",
                "Enregistre un verre d'eau dans \(.applicationName)",
                "J'ai bu un verre d'eau avec \(.applicationName)",
            ],
            shortTitle: "intent.add_water.short",
            systemImageName: "drop.fill"
        )
        AppShortcut(
            intent: AddAlcoholIntent(),
            phrases: [
                "Ajoute \(\.$kind) dans \(.applicationName)",
                "Enregistre une boisson dans \(.applicationName)",
            ],
            shortTitle: "intent.add_alcohol.short",
            systemImageName: "wineglass.fill"
        )
        AppShortcut(
            intent: TodayProgressIntent(),
            phrases: [
                "Où j'en suis dans \(.applicationName)",
                "Combien j'ai bu aujourd'hui dans \(.applicationName)",
            ],
            shortTitle: "intent.today.short",
            systemImageName: "chart.bar.fill"
        )
    }
}
