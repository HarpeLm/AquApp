//
//  KeyboardToolbarModifier.swift
//  AquApp
//
//  Created by Fabian Dargaud on 02/09/2026.
//

import SwiftUI

// MARK: - Modificateur pour ajouter un bouton "Terminé" au clavier
struct KeyboardToolbarModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Terminé") {
                        UIApplication.shared.sendAction(
                            #selector(UIResponder.resignFirstResponder),
                            to: nil,
                            from: nil,
                            for: nil
                        )
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(hex: "4DA8F5"))
                }
            }
    }
}

// MARK: - Extension pour une utilisation simplifiée
extension View {
    func withDoneButton() -> some View {
        self.modifier(KeyboardToolbarModifier())
    }
}
