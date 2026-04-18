import SwiftUI
import AppKit

/// A button that copies a string to the clipboard and briefly shows a checkmark as confirmation.
struct CopyButton: View {
    let value: String

    @State private var copied = false

    var body: some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(value, forType: .string)
            withAnimation {
                copied = true
            }
            Task {
                try? await Task.sleep(for: .seconds(2))
                withAnimation {
                    copied = false
                }
            }
        } label: {
            if copied {
                Image(systemName: "checkmark")
            } else {
                Text("Copy")
            }
        }
        .accessibilityLabel(copied ? "Copied" : "Copy to clipboard")
    }
}
