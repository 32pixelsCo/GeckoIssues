import SwiftUI

/// A colored badge displaying a GitHub label's name.
struct LabelBadge: View {
    var label: Label

    var body: some View {
        Text(label.name)
            .font(.system(size: 10, weight: .medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(labelColor.opacity(0.2))
            .foregroundStyle(labelColor)
            .clipShape(Capsule())
    }

    private var labelColor: Color {
        Color(hex: label.color)
    }
}

// MARK: - Color Hex Extension

extension Color {
    /// Creates a Color from a hex string (e.g. "d73a4a" or "#d73a4a").
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard hex.count == 6,
              let value = UInt64(hex, radix: 16) else {
            self = .secondary
            return
        }
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8) & 0xFF) / 255
        let b = Double(value & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
