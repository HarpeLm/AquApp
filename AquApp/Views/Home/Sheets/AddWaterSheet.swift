import SwiftUI

// MARK: - AddWaterSheet

struct AddWaterSheet: View {
    @Binding var isPresented: Bool
    var onGoalReached: (() -> Void)? = nil
    @EnvironmentObject var store: AppDataStore

    @State private var customAmount: String = ""
    @State private var sliderValue: Double = 250
    @State private var showSlider: Bool = false
    @State private var showRemove: Bool = false
    @State private var removeAmount: String = ""
    @State private var lastHapticThreshold: Int = 0

    @FocusState private var isCustomFocused: Bool
    @FocusState private var isRemoveFocused: Bool

    var presets: [(label: String, sublabel: String, ml: Double)] {
        [
            (UnitFormatter.volume(150), String(localized: "water.preset.small_sip"), 150),
            (UnitFormatter.volume(250), String(localized: "water.preset.glass"), 250),
            (UnitFormatter.volume(330), String(localized: "water.preset.can"), 330),
            (UnitFormatter.volume(500), String(localized: "water.preset.large_bottle"), 500),
            (UnitFormatter.volume(750), String(localized: "water.preset.sport_bottle"), 750),
            (UnitFormatter.volume(1000), String(localized: "water.preset.full_litre"), 1000),
        ]
    }

    let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

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
                    Text(String(localized: "water.sheet.title"))
                        .font(.system(size: 22, weight: .bold))
                    Image(systemName: "drop.fill")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(Color(hex: "4DA8F5"))
                        .frame(width: 24, height: 24)
                }
                Spacer()
                Button { isPresented = false } label: {
                    ZStack {
                        Circle()
                            .fill(Color(UIColor.systemGray5))
                            .frame(width: 32, height: 32)
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.secondary)
                            .accessibilityHidden(true)
                    }
                }
                .accessibilityLabel(String(localized: "goal.editor.close"))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)

            ScrollView {
                VStack(spacing: 20) {

                    // Grille preset
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(presets, id: \.ml) { preset in
                            PresetButton(
                                label: preset.label,
                                sublabel: preset.sublabel,
                                ml: preset.ml
                            ) {
                                HapticManager.shared.selectionTap()
                                addWater(ml: preset.ml)
                            }
                        }
                    }
                    .padding(.horizontal, 20)

                    // Slider personnalisé
                    VStack(alignment: .leading, spacing: 12) {
                        Button {
                            withAnimation(.spring()) {
                                showSlider.toggle()
                                if showSlider { showRemove = false }
                            }
                        } label: {
                            HStack {
                                Image(systemName: "slider.horizontal.3")
                                    .foregroundColor(Color(hex: "4DA8F5"))
                                Text(String(localized: "water.custom_quantity"))
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: showSlider ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                            }
                            .padding(16)
                            .background(Color(UIColor.systemBackground))
                            .cornerRadius(14)
                            .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
                        }

                        if showSlider {
                            VStack(spacing: 16) {
                                HStack {
                                    Text(String(localized: "water.quantity_label"))
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text(UnitFormatter.volume(sliderValue))
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(Color(hex: "2B87E8"))
                                }
                                VStack(spacing: 6) {
                                    Slider(value: $sliderValue, in: UnitFormatter.waterSliderRange, step: 10)
                                        .tint(Color(hex: "4DA8F5"))
                                        .accessibilityLabel(String(localized: "water.quantity_label"))
                                        .accessibilityValue(UnitFormatter.volume(sliderValue))
                                        .onChange(of: sliderValue) { _, newValue in
                                            let threshold: Int
                                            switch newValue {
                                            case ..<250: threshold = 0
                                            case 250..<500: threshold = 1
                                            case 500..<750: threshold = 2
                                            case 750..<1000: threshold = 3
                                            case 1000..<1500: threshold = 4
                                            default: threshold = 5
                                            }
                                            if threshold != lastHapticThreshold {
                                                lastHapticThreshold = threshold
                                                HapticManager.shared.sliderWaterLevel(threshold)
                                            }
                                        }
                                    HStack {
                                        Text(UnitFormatter.volumeSliderBound(50))
                                            .font(.system(size: 11)).foregroundColor(.secondary)
                                        Spacer()
                                        Text(UnitFormatter.volumeSliderBound(2000))
                                            .font(.system(size: 11)).foregroundColor(.secondary)
                                    }
                                }
                                Button { addWater(ml: sliderValue) } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: "plus")
                                            .font(.system(size: 16, weight: .bold))
                                        Text(String(format: String(localized: "water.add_ml"), UnitFormatter.volume(sliderValue)))
                                            .font(.system(size: 16, weight: .semibold))
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                                    .background(LinearGradient(
                                        colors: [Color(hex: "4DA8F5"), Color(hex: "2B87E8")],
                                        startPoint: .leading, endPoint: .trailing
                                    ))
                                    .cornerRadius(14)
                                }
                            }
                            .padding(16)
                            .background(Color(UIColor.systemBackground))
                            .cornerRadius(14)
                            .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }
                    }
                    .padding(.horizontal, 20)

                    // Retirer de l'eau
                    VStack(alignment: .leading, spacing: 12) {
                        Button {
                            withAnimation(.spring()) {
                                showRemove.toggle()
                                if showRemove { showSlider = false }
                            }
                        } label: {
                            HStack {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red.opacity(0.7))
                                Text(String(localized: "water.remove_water"))
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: showRemove ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                            }
                            .padding(16)
                            .background(Color(UIColor.systemBackground))
                            .cornerRadius(14)
                            .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
                        }

                        if showRemove {
                            VStack(spacing: 12) {
                                HStack(spacing: 12) {
                                    TextField(UnitFormatter.volumePlaceholder, text: $removeAmount)
                                        .keyboardType(.numberPad)
                                        .focused($isRemoveFocused)
                                        .padding(14)
                                        .background(Color(UIColor.systemGray6))
                                        .cornerRadius(12)
                                        .font(.system(size: 15))
                                        .withDoneButton() // ← BOUTON "TERMINÉ" AJOUTÉ

                                    Button {
                                        if let ml = Double(removeAmount), ml > 0 {
                                            removeWater(ml: ml)
                                            removeAmount = ""
                                            isRemoveFocused = false
                                        }
                                    } label: {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(removeAmount.isEmpty
                                                      ? AnyShapeStyle(Color(UIColor.systemGray4))
                                                      : AnyShapeStyle(Color.red.opacity(0.8)))
                                                .frame(width: 52, height: 52)
                                            Image(systemName: "minus")
                                                .font(.system(size: 20, weight: .bold))
                                                .foregroundColor(.white)
                                        }
                                    }
                                    .disabled(removeAmount.isEmpty)
                                }
                                HStack(spacing: 6) {
                                    Image(systemName: "info.circle")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                    Text(String(format: String(localized: "water.current_intake"), UnitFormatter.volume(store.todayWaterMl), UnitFormatter.volume(store.dailyGoalMl)))
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(16)
                            .background(Color(UIColor.systemBackground))
                            .cornerRadius(14)
                            .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }
                    }
                    .padding(.horizontal, 20)

                    // Champ personnalisé + bouton ajouter
                    HStack(spacing: 12) {
                        TextField(UnitFormatter.volumePlaceholder, text: $customAmount)
                            .keyboardType(.numberPad)
                            .focused($isCustomFocused)
                            .padding(14)
                            .background(Color(UIColor.systemGray6))
                            .cornerRadius(12)
                            .font(.system(size: 15))
                            .withDoneButton() // ← BOUTON "TERMINÉ" AJOUTÉ

                        Button {
                            if let ml = Double(customAmount), ml > 0, ml <= 5000 {
                                addWater(ml: ml)
                                customAmount = ""
                                isCustomFocused = false
                            }
                        } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(customAmount.isEmpty
                                          ? AnyShapeStyle(Color(UIColor.systemGray4))
                                          : AnyShapeStyle(LinearGradient(
                                            colors: [Color(hex: "4DA8F5"), Color(hex: "2B87E8")],
                                            startPoint: .topLeading, endPoint: .bottomTrailing
                                          )))
                                    .frame(width: 52, height: 52)
                                Image(systemName: "plus")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                        .disabled(customAmount.isEmpty)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }
            }
        }
        .background(Color(UIColor.systemGroupedBackground))
    }

    private func addWater(ml: Double) {
        let wasGoalReached = store.todayGoalReached
        store.addWater(amountMl: ml)
        if !wasGoalReached && store.todayGoalReached {
            onGoalReached?()
        } else {
            HapticManager.shared.waterAdded()
        }
        isPresented = false
    }

    private func removeWater(ml: Double) {
        let entries = store.todayWaterEntries()
        if let match = entries.first(where: { $0.amountMl == ml }) {
            store.deleteWater(match)
        } else if let last = entries.first {
            store.deleteWater(last)
        }
        HapticManager.shared.entryDeleted()
        isPresented = false
    }
}

// MARK: - Bouton preset
struct PresetButton: View {
    let label: String
    let sublabel: String
    let ml: Double
    let action: () -> Void

    var dropSize: CGFloat {
        switch ml {
        case ..<200: return 28
        case ..<400: return 34
        case ..<600: return 40
        case ..<800: return 44
        case ..<1000: return 48
        default: return 52
        }
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: "drop.fill")
                    .font(.system(size: dropSize * 0.6, weight: .medium))
                    .foregroundColor(Color(hex: "4DA8F5"))
                    .frame(width: dropSize, height: dropSize)
                    .accessibilityHidden(true)
                Text(label)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)
                Text(sublabel)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.8)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color("AppCardBackground"))
            .cornerRadius(14)
            .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
        }
        .accessibilityLabel("\(sublabel), \(label)")
        .accessibilityHint(String(format: String(localized: "water.preset.accessibility_hint"), UnitFormatter.volume(ml)))
    }
}
