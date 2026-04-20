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
            Text("Copy")
                .opacity(copied ? 0 : 1)
                .overlay {
                    Image(systemName: "checkmark")
                        .opacity(copied ? 1 : 0)
                }
        }
        .accessibilityLabel(copied ? "Copied" : "Copy to clipboard")
    }
}

#Preview {
    HStack(spacing: 16) {
        CopyButton(value: "ABCD-1234")
    }
    .padding()
}
