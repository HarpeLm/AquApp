import SwiftUI

// MARK: - AlcoholDrink

struct AlcoholDrink: Identifiable {
    let id: String          // ID stable (pas UUID) pour éviter la perte d'état au rerendu
    let name:           String
    let sfSymbol:       String
    let symbolColor:    Color
    let alcoholPercent: Double

    func compensation(for volumeMl: Double) -> Double {
        volumeMl * (alcoholPercent / 100.0) * AlcoholKind.ethanolDensity * AlcoholKind.waterCompensationFactor
    }

    func compensationLabel(for volumeMl: Double) -> String {
        String(format: String(localized: "alcohol.compensation_label"), Int(compensation(for: volumeMl)))
    }
}

// MARK: - AlcoholDisplayEntry

struct AlcoholDisplayEntry: Identifiable {
    let id             = UUID()
    let drinkName:      String
    let sfSymbol:       String
    let volumeMl:       Double
    let compensationMl: Double
    let date:           Date
    let storeRef:       WaterAlcoholEntry
}

// MARK: - AddAlcoolSheet

struct AddAlcoolSheet: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var store: AppDataStore

    @State private var expandedDrinkID: String? = nil   // String? au lieu de UUID?
    @State private var showCustomForm:  Bool   = false
    @State private var showHistory:     Bool   = false
    @State private var customName:      String = ""
    @State private var customAlcohol:   String = ""
    @State private var customDrinks:    [AlcoholDrink] = []
    @State private var showAddedFeedback: String? = nil

    @FocusState private var focusedField: CustomField?
    enum CustomField { case name, alcohol }

    var quantityPresets: [(label: String, sublabel: String, ml: Double)] {
        [
            (UnitFormatter.volumeDecimal(25),  String(localized: "alcohol.preset.shot"),         25),
            (UnitFormatter.volumeDecimal(50),  String(localized: "alcohol.preset.double_shot"),  50),
            (UnitFormatter.volume(125),        String(localized: "alcohol.preset.flute"),        125),
            (UnitFormatter.volume(150),        String(localized: "alcohol.preset.glass"),        150),
            (UnitFormatter.volume(250),        String(localized: "alcohol.preset.large_glass"),  250),
            (UnitFormatter.volume(330),        String(localized: "alcohol.preset.can"),          330),
            (UnitFormatter.volume(500),        String(localized: "alcohol.preset.large_bottle"), 500),
        ]
    }

    // IDs stables — ne dépendent PAS d'UUID() pour survivre aux rerenders
    var defaultDrinks: [AlcoholDrink] {
        [
            AlcoholDrink(id: "beer",      name: String(localized: "alcohol.beer"),      sfSymbol: "mug.fill",       symbolColor: Color(hex: "D4A017"), alcoholPercent: 5),
            AlcoholDrink(id: "wine",      name: String(localized: "alcohol.wine"),      sfSymbol: "wineglass.fill", symbolColor: Color(hex: "8B5CF6"), alcoholPercent: 12),
            AlcoholDrink(id: "spirits",   name: String(localized: "alcohol.spirits"),   sfSymbol: "cylinder.fill",  symbolColor: Color(hex: "EF4444"), alcoholPercent: 40),
            AlcoholDrink(id: "champagne", name: String(localized: "alcohol.champagne"), sfSymbol: "sparkles",       symbolColor: Color(hex: "F59E0B"), alcoholPercent: 12),
            AlcoholDrink(id: "cocktail",  name: String(localized: "alcohol.cocktail"),  sfSymbol: "wineglass",      symbolColor: Color(hex: "10B981"), alcoholPercent: 10),
        ]
    }

    var allDrinks: [AlcoholDrink] { defaultDrinks + customDrinks }

    var todayDisplayEntries: [AlcoholDisplayEntry] {
        store.todayAlcoholEntries().map { entry in
            AlcoholDisplayEntry(
                drinkName:      entry.alcoholType.localizedName,
                sfSymbol:       entry.alcoholType.sfSymbol,
                volumeMl:       entry.amountMl,
                compensationMl: entry.compensationMl,
                date:           entry.date,
                storeRef:       entry
            )
        }
    }

    var totalVolumeTodayMl:       Double { todayDisplayEntries.reduce(0) { $0 + $1.volumeMl } }
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
                        .font(.system(size: 22, weight: .bold))
                    Image(systemName: showHistory ? "clock.arrow.circlepath" : "wineglass.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Color(hex: "8B5CF6"))
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
                            .font(.system(size: 13, weight: .semibold))
                        if !showHistory {
                            if !todayDisplayEntries.isEmpty {
                                Text("\(todayDisplayEntries.count)")
                                    .font(.system(size: 12, weight: .bold))
                            } else {
                                Text(String(localized: "alcohol.history_button"))
                                    .font(.system(size: 12, weight: .semibold))
                            }
                        } else {
                            Text(String(localized: "alcohol.back_button"))
                                .font(.system(size: 12, weight: .semibold))
                        }
                    }
                    .foregroundColor(showHistory ? .white : Color(hex: "8B5CF6"))
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(showHistory
                                ? AnyShapeStyle(Color(hex: "8B5CF6"))
                                : AnyShapeStyle(Color(hex: "8B5CF6").opacity(0.1)))
                    .cornerRadius(20)
                }

                Button { isPresented = false } label: {
                    ZStack {
                        Circle().fill(Color(UIColor.systemGray5)).frame(width: 32, height: 32)
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
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
        .background(Color("AppBackground"))
    }

    // MARK: - Vue Historique

    var historyView: some View {
        ScrollView {
            VStack(spacing: 16) {
                if todayDisplayEntries.isEmpty {
                    VStack(spacing: 12) {
                        ZStack {
                            Circle().fill(Color(hex: "F3E5F5")).frame(width: 72, height: 72)
                            Image(systemName: "wineglass")
                                .font(.system(size: 32))
                                .foregroundColor(Color(hex: "8B5CF6").opacity(0.5))
                        }
                        Text(String(localized: "alcohol.no_entries"))
                            .font(.system(size: 17, weight: .semibold))
                        Text(String(localized: "alcohol.no_entries_sub"))
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 48)
                } else {
                    HStack(spacing: 12) {
                        VStack(spacing: 4) {
                            Text(UnitFormatter.volume(totalVolumeTodayMl))
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(Color(hex: "8B5CF6"))
                            Text(String(localized: "alcohol.total_volume"))
                                .font(.system(size: 12)).foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(Color(hex: "8B5CF6").opacity(0.08)).cornerRadius(12)

                        VStack(spacing: 4) {
                            Text(UnitFormatter.volume(totalCompensationTodayMl))
                                .font(.system(size: 20, weight: .bold)).foregroundColor(.orange)
                            Text(String(localized: "alcohol.to_compensate"))
                                .font(.system(size: 12)).foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(Color.orange.opacity(0.08)).cornerRadius(12)
                    }
                    .padding(.horizontal, 20)

                    VStack(spacing: 0) {
                        ForEach(todayDisplayEntries) { entry in
                            HStack(spacing: 14) {
                                ZStack {
                                    Circle().fill(Color(hex: "F3E5F5")).frame(width: 40, height: 40)
                                    Image(systemName: entry.sfSymbol)
                                        .font(.system(size: 16)).foregroundColor(Color(hex: "8B5CF6"))
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.drinkName).font(.system(size: 15, weight: .semibold))
                                    Text(UnitFormatter.volume(entry.volumeMl)).font(.system(size: 13)).foregroundColor(.secondary)
                                }
                                Spacer()
                                Button {
                                    store.deleteAlcohol(entry.storeRef)
                                    HapticManager.shared.entryDeleted()
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.system(size: 14))
                                        .foregroundColor(.red.opacity(0.6)).padding(10)
                                        .accessibilityHidden(true)
                                }
                                .accessibilityLabel(String(format: String(localized: "accessibility.delete_entry"), entry.drinkName))
                                .accessibilityHint(String(localized: "accessibility.delete_hint"))
                            }
                            .padding(.horizontal, 16).padding(.vertical, 10)
                            Divider().padding(.leading, 70)
                        }
                    }
                    .background(Color("AppCardBackground")).cornerRadius(16)
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
                        Text(feedback).font(.system(size: 13, weight: .medium)).foregroundColor(.primary)
                    }
                    .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color("AppCardBackground")).cornerRadius(12)
                    .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                    .padding(.horizontal, 20)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                // Avertissement santé — au-dessus de la liste
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 15))
                            .foregroundColor(Color(hex: "F59E0B"))
                        Text(String(localized: "alcohol.warning.title"))
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Color(hex: "92400E"))
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        WarningRow(symbol: "drop.fill",          color: Color(hex: "4DA8F5"), text: String(localized: "alcohol.warning.hydration"))
                        WarningRow(symbol: "heart.fill",         color: Color(hex: "EF4444"), text: String(localized: "alcohol.warning.limit"))
                        WarningRow(symbol: "moon.fill",          color: Color(hex: "6C3483"), text: String(localized: "alcohol.warning.sober_days"))
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
                    }
                }
                .padding(.horizontal, 20)

                // Formulaire boisson custom
                VStack(alignment: .leading, spacing: 12) {
                    Button {
                        withAnimation(.spring()) { showCustomForm.toggle() }
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill").foregroundColor(Color(hex: "4DA8F5"))
                            Text(String(localized: "alcohol.add_custom"))
                                .font(.system(size: 15, weight: .semibold)).foregroundColor(.primary)
                            Spacer()
                            Image(systemName: showCustomForm ? "chevron.up" : "chevron.down")
                                .font(.system(size: 13)).foregroundColor(.secondary)
                        }
                        .padding(16).background(Color("AppCardBackground")).cornerRadius(14)
                        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
                    }

                    if showCustomForm {
                        VStack(spacing: 14) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(String(localized: "alcohol.custom.name_label"))
                                    .font(.system(size: 13, weight: .semibold)).foregroundColor(.secondary)
                                TextField(String(localized: "alcohol.custom.name_placeholder"), text: $customName)
                                    .focused($focusedField, equals: .name)
                                    .padding(12).background(Color(UIColor.systemGray6)).cornerRadius(10)
                            }
                            VStack(alignment: .leading, spacing: 6) {
                                Text(String(localized: "alcohol.custom.abv_label"))
                                    .font(.system(size: 13, weight: .semibold)).foregroundColor(.secondary)
                                TextField(String(localized: "alcohol.custom.abv_placeholder"), text: $customAlcohol)
                                    .keyboardType(.decimalPad)
                                    .focused($focusedField, equals: .alcohol)
                                    .padding(12).background(Color(UIColor.systemGray6)).cornerRadius(10)
                            }
                            Button { saveCustomDrink() } label: {
                                Text(String(localized: "alcohol.custom.save"))
                                    .font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                                    .frame(maxWidth: .infinity).frame(height: 46)
                                    .background(isCustomFormValid
                                                ? AnyShapeStyle(LinearGradient(
                                                    colors: [Color(hex: "4DA8F5"), Color(hex: "2B87E8")],
                                                    startPoint: .leading, endPoint: .trailing))
                                                : AnyShapeStyle(Color(UIColor.systemGray4)))
                                    .cornerRadius(12)
                            }
                            .disabled(!isCustomFormValid)
                        }
                        .padding(16).background(Color("AppCardBackground")).cornerRadius(14)
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
        !customName.trimmingCharacters(in: .whitespaces).isEmpty && Double(customAlcohol) != nil
    }

    private func logDrink(_ drink: AlcoholDrink, volumeMl: Double) {
        let kind: AlcoholKind
        switch drink.id {
        case "beer":      kind = .beer
        case "wine":      kind = .wine
        case "spirits":   kind = .spirits
        case "champagne": kind = .wine
        case "cocktail":  kind = .cocktail
        default:          kind = .other
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

    private func saveCustomDrink() {
        guard let alc = Double(customAlcohol) else { return }
        let trimmedName = customName.trimmingCharacters(in: .whitespaces)
        let newDrink = AlcoholDrink(
            id: "custom_\(trimmedName)_\(Int(alc))",   // ID stable basé sur le nom
            name: trimmedName,
            sfSymbol: "wineglass",
            symbolColor: Color(hex: "8B5CF6"),
            alcoholPercent: alc
        )
        withAnimation { customDrinks.append(newDrink) }
        customName = ""; customAlcohol = ""; showCustomForm = false
    }
}

// MARK: - DrinkRow

struct DrinkRow: View {
    let drink:      AlcoholDrink
    let isExpanded: Bool
    let presets:    [(label: String, sublabel: String, ml: Double)]
    let onTap:      () -> Void
    let onAdd:      (Double) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header — toujours tappable pour toggle
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(drink.symbolColor.opacity(0.12)).frame(width: 44, height: 44)
                    Image(systemName: drink.sfSymbol)
                        .font(.system(size: 18, weight: .medium)).foregroundColor(drink.symbolColor)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(drink.name).font(.system(size: 15, weight: .semibold)).foregroundColor(.primary)
                    Text(String(format: String(localized: "alcohol.abv_label"), Int(drink.alcoholPercent)))
                        .font(.system(size: 12)).foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 13)).foregroundColor(.secondary)
            }
            .padding(16)
            .contentShape(Rectangle())          // zone de tap = tout le header
            .onTapGesture { onTap() }

            if isExpanded {
                VStack(spacing: 12) {
                    Divider()
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(presets, id: \.ml) { preset in
                            Button { onAdd(preset.ml) } label: {
                                VStack(spacing: 2) {
                                    Text(preset.label)
                                        .font(.system(size: 13, weight: .semibold)).foregroundColor(.primary)
                                    Text(drink.compensationLabel(for: preset.ml))
                                        .font(.system(size: 11, weight: .medium)).foregroundColor(.orange.opacity(0.8))
                                    Text(preset.sublabel)
                                        .font(.system(size: 10)).foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity).padding(.vertical, 10)
                                .background(Color(UIColor.systemGray6)).cornerRadius(10)
                            }
                        }
                    }
                    CustomQuantityRow(drink: drink, onAdd: onAdd)
                }
                .padding(.horizontal, 16).padding(.bottom, 16)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .background(Color("AppCardBackground")).cornerRadius(14)
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
                .padding(10).background(Color(UIColor.systemGray6)).cornerRadius(10).font(.system(size: 14))

            if let ml = Double(customMl), ml > 0 {
                VStack(spacing: 1) {
                    Text(drink.compensationLabel(for: ml))
                        .font(.system(size: 11, weight: .bold)).foregroundColor(.orange)
                    Text(String(localized: "alcohol.to_compensate_short"))
                        .font(.system(size: 10)).foregroundColor(.secondary)
                }
            }

            Button {
                if let ml = Double(customMl), ml > 0 {
                    onAdd(ml); customMl = ""; isFocused = false
                }
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(customMl.isEmpty
                              ? AnyShapeStyle(Color(UIColor.systemGray4))
                              : AnyShapeStyle(LinearGradient(
                                colors: [Color(hex: "9B59B6"), Color(hex: "6C3483")],
                                startPoint: .topLeading, endPoint: .bottomTrailing)))
                        .frame(width: 44, height: 44)
                    Image(systemName: "plus").font(.system(size: 18, weight: .bold)).foregroundColor(.white)
                }
            }
            .disabled(customMl.isEmpty)
        }
    }
}

// MARK: - WarningRow

private struct WarningRow: View {
    let symbol: String
    let color:  Color
    let text:   String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 16)
                .padding(.top, 1)
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "92400E"))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
