//
//  KeyboardDoneToolbar.swift
//  Exsplitter
//
//  Adds a "Done" button above the keyboard so number/decimal pad can be dismissed.
//

import SwiftUI
import UIKit

extension View {
    /// Adds a Done button above the keyboard. Use on views that contain decimal/number pad fields.
    func keyboardDoneButton() -> some View {
        toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(L10n.string("common.done", language: LanguageStore.shared.language)) {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
                .fontWeight(.semibold)
                .foregroundColor(Color.appAccent)
            }
        }
    }
}
