import SwiftUI

// MARK: - AlcoholDrink
struct AlcoholDrink: Identifiable {
    let id: String
    let name: String
    let sfSymbol: String
    let symbolColor: Color
    let alcoholPercent: Double

    func compensation(for volumeMl: Double) -> Double {
        volumeMl * (alcoholPercent / 100.0) * AlcoholKind.ethanolDensity * AlcoholKind.waterCompensationFactor
    }

    func compensationLabel(for volumeMl: Double) -> String {
        String(format: String(localized: "alcohol.compensation_label"), Int(compensation(for: volumeMl)))
    }

    var isCustom: Bool { id.hasPrefix("custom_") }

    static func custom(name: String, alcoholPercent: Double) -> AlcoholDrink {
        AlcoholDrink(id: "custom_\(name)_\(Int(alcoholPercent))", name: name,
                     sfSymbol: "wineglass", symbolColor: Color.app.alcoholLight,
                     alcoholPercent: alcoholPercent)
    }
}

// MARK: - Boissons personnalisées (persistées dans UserDefaults : nom + degré, rien de sensible)

enum CustomDrinkStore {
    private struct Stored: Codable {
        let name: String
        let alcoholPercent: Double
    }

    static let key = "custom_alcohol_drinks"

    static func load(from defaults: UserDefaults = .standard) -> [AlcoholDrink] {
        guard let data = defaults.data(forKey: key),
              let stored = try? JSONDecoder().decode([Stored].self, from: data)
        else { return [] }
        return stored.map { AlcoholDrink.custom(name: $0.name, alcoholPercent: $0.alcoholPercent) }
    }

    static func save(_ drinks: [AlcoholDrink], to defaults: UserDefaults = .standard) {
        let stored = drinks.filter(\.isCustom).map { Stored(name: $0.name, alcoholPercent: $0.alcoholPercent) }
        defaults.set(try? JSONEncoder().encode(stored), forKey: key)
    }
}

// MARK: - AlcoholDisplayEntry
struct AlcoholDisplayEntry: Identifiable {
    let id = UUID()
    let drinkName: String
    let sfSymbol: String
    let volumeMl: Double
    let compensationMl: Double
    let date: Date
    let storeRef: WaterAlcoholEntry
}

// MARK: - AddAlcoolSheet
struct AddAlcoolSheet: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var store: AppDataStore

    @State private var expandedDrinkID: String? = nil
    @State private var showCustomForm: Bool = false
    @State private var showHistory: Bool = false
    @State private var customName: String = ""
    @State private var customAlcohol: String = ""
    @State private var customDrinks: [AlcoholDrink] = CustomDrinkStore.load()
    @State private var showAddedFeedback: String? = nil

    @FocusState private var focusedField: CustomField?
    enum CustomField { case name, alcohol }

    var quantityPresets: [(label: String, sublabel: String, ml: Double)] {
        [
            (UnitFormatter.volumeDecimal(25), String(localized: "alcohol.preset.shot"), 25),
            (UnitFormatter.volumeDecimal(50), String(localized: "alcohol.preset.double_shot"), 50),
            (UnitFormatter.volume(125), String(localized: "alcohol.preset.flute"), 125),
            (UnitFormatter.volume(150), String(localized: "alcohol.preset.glass"), 150),
            (UnitFormatter.volume(250), String(localized: "alcohol.preset.large_glass"), 250),
            (UnitFormatter.volume(330), String(localized: "alcohol.preset.can"), 330),
            (UnitFormatter.volume(500), String(localized: "alcohol.preset.large_bottle"), 500),
        ]
    }

    var defaultDrinks: [AlcoholDrink] {
        [
            AlcoholDrink(id: "beer", name: String(localized: "alcohol.beer"), sfSymbol: "mug.fill", symbolColor: Color.app.amberDark, alcoholPercent: 5),
            AlcoholDrink(id: "wine", name: String(localized: "alcohol.wine"), sfSymbol: "wineglass.fill", symbolColor: Color.app.alcoholLight, alcoholPercent: 12),
            AlcoholDrink(id: "spirits", name: String(localized: "alcohol.spirits"), sfSymbol: "cylinder.fill", symbolColor: Color.app.red, alcoholPercent: 40),
            AlcoholDrink(id: "champagne", name: String(localized: "alcohol.champagne"), sfSymbol: "sparkles", symbolColor: Color.app.amber, alcoholPercent: 12),
            AlcoholDrink(id: "cocktail", name: String(localized: "alcohol.cocktail"), sfSymbol: "wineglass", symbolColor: Color.app.greenDark, alcoholPercent: 10),
        ]
    }

    var allDrinks: [AlcoholDrink] { defaultDrinks + customDrinks }

    var todayDisplayEntries: [AlcoholDisplayEntry] {
        store.todayAlcoholEntries().map { entry in
            AlcoholDisplayEntry(
                drinkName: entry.alcoholType.localizedName,
                sfSymbol: entry.alcoholType.sfSymbol,
                volumeMl: entry.amountMl,
                compensationMl: entry.compensationMl,
                date: entry.date,
                storeRef: entry
            )
        }
    }

    var totalVolumeTodayMl: Double { todayDisplayEntries.reduce(0) { $0 + $1.volumeMl } }
    var totalCompensationTodayMl: Double { todayDisplayEntries.reduce(0) { $0 + $1.compensationMl } }

    var body: some View {
        VStack(spacing: 0) {

            // Handle
            RoundedRectangle(cornerRadius: 3)
                .fill(Color(UIColor.systemGray4))
                .frame(width: 40, height: 5)
                .padding(.top, 12)
                .padding(.bottom, 20)

            // Header
            HStack {
                HStack(spacing: 8) {
                    Text(showHistory
                         ? String(localized: "alcohol.history_title")
                         : String(localized: "alcohol.sheet.title"))
                        .scaledFont(size: 22, weight: .bold)
                        .accessibilityAddTraits(.isHeader)
                    Image(systemName: showHistory ? "clock.arrow.circlepath" : "wineglass.fill")
                        .scaledFont(size: 20)
                        .foregroundColor(Color.app.alcoholLight)
                        .accessibilityHidden(true)
                }
                Spacer()

                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        showHistory.toggle()
                        if showHistory { expandedDrinkID = nil; showCustomForm = false }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: showHistory ? "arrow.left" : "clock.arrow.circlepath")
                            .scaledFont(size: 13, weight: .semibold)
                        if !showHistory {
                            if !todayDisplayEntries.isEmpty {
                                Text("\(todayDisplayEntries.count)")
                                    .scaledFont(size: 12, weight: .bold)
                            } else {
                                Text(String(localized: "alcohol.history_button"))
                                    .scaledFont(size: 12, weight: .semibold)
                            }
                        } else {
                            Text(String(localized: "alcohol.back_button"))
                                .scaledFont(size: 12, weight: .semibold)
                        }
                    }
                    .foregroundColor(showHistory ? .white : Color.app.alcoholLight)
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(showHistory
                                ? AnyShapeStyle(Color.app.alcoholLight)
                                : AnyShapeStyle(Color.app.alcoholLight.opacity(0.1)))
                    .cornerRadius(20)
                }
                .accessibilityLabel(showHistory
                    ? String(localized: "alcohol.back_button")
                    : String(localized: "a11y.alcohol.history \(todayDisplayEntries.count)"))

                Button { isPresented = false } label: {
                    ZStack {
                        Circle().fill(Color(UIColor.systemGray5)).frame(width: 32, height: 32)
                        Image(systemName: "xmark")
                            .scaledFont(size: 12, weight: .bold)
                            .foregroundColor(.secondary)
                            .accessibilityHidden(true)
                    }
                }
                .accessibilityLabel(String(localized: "goal.editor.close"))
                .padding(.leading, 8)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)

            if showHistory {
                historyView.transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                addView.transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .background(Color.app.background)
    }

    // MARK: - Vue Historique
    var historyView: some View {
        ScrollView {
            VStack(spacing: 16) {
                if todayDisplayEntries.isEmpty {
                    VStack(spacing: 12) {
                        ZStack {
                            Circle().fill(Color.app.alcoholPale).frame(width: 72, height: 72)
                            Image(systemName: "wineglass")
                                .scaledFont(size: 32)
                                .foregroundColor(Color.app.alcoholLight.opacity(0.5))
                        }
                        .accessibilityHidden(true)
                        Text(String(localized: "alcohol.no_entries"))
                            .scaledFont(size: 17, weight: .semibold)
                        Text(String(localized: "alcohol.no_entries_sub"))
                            .scaledFont(size: 14)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 48)
                } else {
                    HStack(spacing: 12) {
                        VStack(spacing: 4) {
                            Text(UnitFormatter.volume(totalVolumeTodayMl))
                                .scaledFont(size: 20, weight: .bold)
                                .foregroundColor(Color.app.alcoholLight)
                            Text(String(localized: "alcohol.total_volume"))
                                .scaledFont(size: 12).foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(Color.app.alcoholLight.opacity(0.08)).cornerRadius(12)
                        .accessibilityElement(children: .combine)

                        VStack(spacing: 4) {
                            Text(UnitFormatter.volume(totalCompensationTodayMl))
                                .scaledFont(size: 20, weight: .bold).foregroundColor(.orange)
                            Text(String(localized: "alcohol.to_compensate"))
                                .scaledFont(size: 12).foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(Color.orange.opacity(0.08)).cornerRadius(12)
                        .accessibilityElement(children: .combine)
                    }
                    .padding(.horizontal, 20)

                    VStack(spacing: 0) {
                        ForEach(todayDisplayEntries) { entry in
                            HStack(spacing: 14) {
                                ZStack {
                                    Circle().fill(Color.app.alcoholPale).frame(width: 40, height: 40)
                                    Image(systemName: entry.sfSymbol)
                                        .scaledFont(size: 16).foregroundColor(Color.app.alcoholLight)
                                }
                                .accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.drinkName).scaledFont(size: 15, weight: .semibold)
                                    Text(UnitFormatter.volume(entry.volumeMl)).scaledFont(size: 13).foregroundColor(.secondary)
                                }
                                .accessibilityElement(children: .combine)
                                Spacer()
                                Button {
                                    store.deleteAlcohol(entry.storeRef)
                                    HapticManager.shared.entryDeleted()
                                } label: {
                                    Image(systemName: "trash")
                                        .scaledFont(size: 14)
                                        .foregroundColor(.red.opacity(0.6)).padding(10)
                                }
                                .accessibilityLabel(String(format: String(localized: "accessibility.delete_entry"),
                                                           "\(entry.drinkName), \(UnitFormatter.volume(entry.volumeMl))"))
                            }
                            .padding(.horizontal, 16).padding(.vertical, 10)
                        }
                    }
                    .background(Color.app.card).cornerRadius(16)
                    .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
                    .padding(.horizontal, 20)
                }
            }
            .padding(.bottom, 32)
        }
    }

    // MARK: - Vue Ajout
    var addView: some View {
        ScrollView {
            VStack(spacing: 20) {

                if let feedback = showAddedFeedback {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                            .accessibilityHidden(true)
                        Text(feedback).scaledFont(size: 13, weight: .medium).foregroundColor(.primary)
                    }
                    .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.app.card).cornerRadius(12)
                    .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                    .padding(.horizontal, 20)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                // Avertissement santé
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .scaledFont(size: 15)
                            .foregroundColor(Color(hex: "F59E0B"))
                            .accessibilityHidden(true)
                        Text(String(localized: "alcohol.warning.title"))
                            .scaledFont(size: 14, weight: .bold)
                            .foregroundColor(Color(hex: "92400E"))
                            .accessibilityAddTraits(.isHeader)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        WarningRow(symbol: "drop.fill", color: Color(hex: "4DA8F5"), text: String(localized: "alcohol.warning.hydration"))
                        WarningRow(symbol: "heart.fill", color: Color(hex: "EF4444"), text: String(localized: "alcohol.warning.limit"))
                        WarningRow(symbol: "moon.fill", color: Color(hex: "6C3483"), text: String(localized: "alcohol.warning.sober_days"))
                        WarningRow(symbol: "brain.head.profile", color: Color(hex: "D97706"), text: String(localized: "alcohol.warning.health"))
                    }
                }
                .padding(14)
                .background(Color(hex: "FFFBEB"))
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color(hex: "F59E0B").opacity(0.4), lineWidth: 1)
                )
                .padding(.horizontal, 20)

                VStack(spacing: 12) {
                    ForEach(allDrinks) { drink in
                        DrinkRow(
                            drink: drink,
                            isExpanded: expandedDrinkID == drink.id,
                            presets: quantityPresets
                        ) {
                            withAnimation(.spring()) {
                                expandedDrinkID = expandedDrinkID == drink.id ? nil : drink.id
                            }
                        } onAdd: { volumeMl in
                            logDrink(drink, volumeMl: volumeMl)
                        }
                        .contextMenu {
                            if drink.isCustom {
                                Button(role: .destructive) { deleteCustomDrink(drink) } label: {
                                    Label(String(localized: "alcohol.custom.delete"), systemImage: "trash")
                                }
                            }
                        }
                        .accessibilityActions {
                            if drink.isCustom {
                                Button(String(localized: "alcohol.custom.delete")) { deleteCustomDrink(drink) }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)

                // Formulaire boisson custom
                VStack(alignment: .leading, spacing: 12) {
                    Button {
                        withAnimation(.spring()) { showCustomForm.toggle() }
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill").foregroundColor(Color.app.primary)
                            Text(String(localized: "alcohol.add_custom"))
                                .scaledFont(size: 15, weight: .semibold).foregroundColor(.primary)
                            Spacer()
                            Image(systemName: showCustomForm ? "chevron.up" : "chevron.down")
                                .scaledFont(size: 13).foregroundColor(.secondary)
                        }
                        .padding(16).background(Color.app.card).cornerRadius(14)
                        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
                    }

                    if showCustomForm {
                        VStack(spacing: 14) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(String(localized: "alcohol.custom.name_label"))
                                    .scaledFont(size: 13, weight: .semibold).foregroundColor(.secondary)
                                TextField(String(localized: "alcohol.custom.name_placeholder"), text: $customName)
                                    .focused($focusedField, equals: .name)
                                    .padding(12).background(Color(UIColor.systemGray6)).cornerRadius(10)
                                    .withDoneButton() // ← BOUTON "TERMINÉ" AJOUTÉ
                            }
                            VStack(alignment: .leading, spacing: 6) {
                                Text(String(localized: "alcohol.custom.abv_label"))
                                    .scaledFont(size: 13, weight: .semibold).foregroundColor(.secondary)
                                TextField(String(localized: "alcohol.custom.abv_placeholder"), text: $customAlcohol)
                                    .keyboardType(.decimalPad)
                                    .focused($focusedField, equals: .alcohol)
                                    .padding(12).background(Color(UIColor.systemGray6)).cornerRadius(10)
                                    .withDoneButton() // ← BOUTON "TERMINÉ" AJOUTÉ
                            }
                            Button { saveCustomDrink() } label: {
                                Text(String(localized: "alcohol.custom.save"))
                                    .scaledFont(size: 15, weight: .semibold).foregroundColor(.white)
                                    .frame(maxWidth: .infinity).frame(height: 46)
                                    .background(isCustomFormValid
                                                ? AnyShapeStyle(LinearGradient(
                                                    colors: [Color.app.primary, Color.app.primaryDark],
                                                    startPoint: .leading, endPoint: .trailing))
                                                : AnyShapeStyle(Color(UIColor.systemGray4)))
                                    .cornerRadius(12)
                            }
                            .disabled(!isCustomFormValid)
                        }
                        .padding(16).background(Color.app.card).cornerRadius(14)
                        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 20)

                Spacer().frame(height: 32)
            }
        }
    }

    var isCustomFormValid: Bool {
        !customName.trimmingCharacters(in: .whitespaces).isEmpty && parsedCustomAlcohol != nil
    }

    private func logDrink(_ drink: AlcoholDrink, volumeMl: Double) {
        let kind: AlcoholKind
        switch drink.id {
        case "beer": kind = .beer
        case "wine": kind = .wine
        case "spirits": kind = .spirits
        case "champagne": kind = .wine
        case "cocktail": kind = .cocktail
        default: kind = .other
        }
        store.addAlcohol(amountMl: volumeMl, type: kind)
        HapticManager.shared.alcoholAdded()
        withAnimation {
            showAddedFeedback = String(format: String(localized: "alcohol.added_feedback"), drink.name, Int(volumeMl), drink.compensationLabel(for: volumeMl))
        }
        expandedDrinkID = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation { showAddedFeedback = nil }
        }
    }

    /// Accepte « 12,5 » (clavier français) comme « 12.5 » ; refuse ce qui n'est pas un degré plausible.
    private var parsedCustomAlcohol: Double? {
        guard let value = Double(customAlcohol.replacingOccurrences(of: ",", with: ".")),
              value > 0, value <= 100 else { return nil }
        return value
    }

    private func deleteCustomDrink(_ drink: AlcoholDrink) {
        withAnimation { customDrinks.removeAll { $0.id == drink.id } }
        if expandedDrinkID == drink.id { expandedDrinkID = nil }
        CustomDrinkStore.save(customDrinks)
    }

    private func saveCustomDrink() {
        guard let alc = parsedCustomAlcohol else { return }
        let trimmedName = customName.trimmingCharacters(in: .whitespaces)
        let newDrink = AlcoholDrink.custom(name: trimmedName, alcoholPercent: alc)
        withAnimation {
            customDrinks.removeAll { $0.id == newDrink.id }
            customDrinks.append(newDrink)
        }
        CustomDrinkStore.save(customDrinks)
        customName = ""
        customAlcohol = ""
        showCustomForm = false
    }
}

// MARK: - DrinkRow
struct DrinkRow: View {
    let drink: AlcoholDrink
    let isExpanded: Bool
    let presets: [(label: String, sublabel: String, ml: Double)]
    let onTap: () -> Void
    let onAdd: (Double) -> Void

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onTap) {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(drink.symbolColor.opacity(0.12)).frame(width: 44, height: 44)
                        Image(systemName: drink.sfSymbol)
                            .scaledFont(size: 18, weight: .medium).foregroundColor(drink.symbolColor)
                    }
                    .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(drink.name).scaledFont(size: 15, weight: .semibold).foregroundColor(.primary)
                        Text(String(format: String(localized: "alcohol.abv_label"), Int(drink.alcoholPercent)))
                            .scaledFont(size: 12).foregroundColor(.secondary)
                    }
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .scaledFont(size: 13).foregroundColor(.secondary)
                        .accessibilityHidden(true)
                }
                .padding(16)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityValue(String(localized: isExpanded ? "a11y.expanded" : "a11y.collapsed"))
            .accessibilityHint(String(localized: "a11y.alcohol.expand_hint"))

            if isExpanded {
                VStack(spacing: 12) {
                    Divider()
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(presets, id: \.ml) { preset in
                            Button { onAdd(preset.ml) } label: {
                                VStack(spacing: 2) {
                                    Text(preset.label)
                                        .scaledFont(size: 13, weight: .semibold).foregroundColor(.primary)
                                    Text(drink.compensationLabel(for: preset.ml))
                                        .scaledFont(size: 11, weight: .medium).foregroundColor(.orange.opacity(0.8))
                                    Text(preset.sublabel)
                                        .scaledFont(size: 10).foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity).padding(.vertical, 10)
                                .background(Color(UIColor.systemGray6)).cornerRadius(10)
                            }
                            .accessibilityLabel(String(format: String(localized: "a11y.alcohol.add_preset"),
                                                       UnitFormatter.volume(preset.ml), drink.name,
                                                       drink.compensationLabel(for: preset.ml)))
                        }
                    }
                    CustomQuantityRow(drink: drink, onAdd: onAdd)
                }
                .padding(.horizontal, 16).padding(.bottom, 16)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .background(Color.app.card).cornerRadius(14)
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
        .clipped()
    }
}

// MARK: - CustomQuantityRow
struct CustomQuantityRow: View {
    let drink: AlcoholDrink
    let onAdd: (Double) -> Void

    @State private var customMl: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 10) {
            TextField(UnitFormatter.volumePlaceholder, text: $customMl)
                .keyboardType(.numberPad).focused($isFocused)
                .padding(10).background(Color(UIColor.systemGray6)).cornerRadius(10).scaledFont(size: 14)
                .withDoneButton() // ← BOUTON "TERMINÉ" AJOUTÉ
                .accessibilityLabel(String(localized: "water.custom_quantity"))

            if let ml = Double(customMl), ml > 0 {
                VStack(spacing: 1) {
                    Text(drink.compensationLabel(for: ml))
                        .scaledFont(size: 11, weight: .bold).foregroundColor(.orange)
                    Text(String(localized: "alcohol.to_compensate_short"))
                        .scaledFont(size: 10).foregroundColor(.secondary)
                }
            }

            Button {
                if let ml = Double(customMl), ml > 0, ml <= 5000 {
                    onAdd(ml)
                    customMl = ""
                    isFocused = false
                }
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(customMl.isEmpty
                              ? AnyShapeStyle(Color(UIColor.systemGray4))
                              : AnyShapeStyle(LinearGradient(
                                colors: [Color.app.alcoholMid, Color.app.alcoholDark],
                                startPoint: .topLeading, endPoint: .bottomTrailing)))
                        .frame(width: 44, height: 44)
                    Image(systemName: "plus").scaledFont(size: 18, weight: .bold).foregroundColor(.white)
                }
            }
            .disabled(customMl.isEmpty)
            .accessibilityLabel(String(format: String(localized: "a11y.alcohol.add_custom"), drink.name))
        }
    }
}

// MARK: - WarningRow
private struct WarningRow: View {
    let symbol: String
    let color: Color
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: symbol)
                .scaledFont(size: 11, weight: .semibold)
                .foregroundColor(color)
                .frame(width: 16)
                .padding(.top, 1)
                .accessibilityHidden(true)
            Text(text)
                .scaledFont(size: 12)
                .foregroundColor(Color(hex: "92400E"))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
