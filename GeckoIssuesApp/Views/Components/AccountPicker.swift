import SwiftUI

/// Account switcher using Button + NSMenu, modeled after ContextStore's SpacePicker.
///
/// Shows the current account with its avatar. User account appears first,
/// followed by organizations.
struct AccountPicker: View {
    var accounts: [Account]
    @Binding var selectedAccount: Account?

    @State private var anchorView: NSView?

    var body: some View {
        Button {
            showMenu()
        } label: {
            HStack(spacing: 8) {
                AccountAvatar(
                    login: selectedAccount?.login ?? "",
                    avatarURL: selectedAccount?.avatarURL,
                    size: 24
                )

                Text(selectedAccount?.login ?? "Select Account")
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)

                Spacer()

                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity)
            .frame(height: 36)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(nsColor: .quaternaryLabelColor).opacity(0.5))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Account picker, \(selectedAccount?.login ?? "none selected")")
        .background(PickerAnchorView(nsView: $anchorView))
    }

    // MARK: - NSMenu

    private func showMenu() {
        let menu = NSMenu()

        for account in accounts {
            let action = PickerMenuAction {
                selectedAccount = account
            }
            let item = NSMenuItem(
                title: account.login,
                action: #selector(PickerMenuAction.execute),
                keyEquivalent: ""
            )
            item.image = avatarMenuImage(for: account)
            if account.id == selectedAccount?.id {
                item.state = .on
            }
            item.target = action
            item.representedObject = action
            menu.addItem(item)
        }

        guard let anchor = anchorView else { return }
        menu.minimumWidth = anchor.bounds.width
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: -6), in: anchor)
    }

    // MARK: - Menu Item Images

    private func avatarMenuImage(for account: Account) -> NSImage {
        if let urlString = account.avatarURL,
           let url = URL(string: urlString),
           let data = try? Data(contentsOf: url),
           let nsImage = NSImage(data: data) {
            return Self.roundedImage(nsImage, size: 20, cornerRadius: 10)
        }
        return Self.initialsImage(for: account.login, size: 20, cornerRadius: 10)
    }

    private static func roundedImage(_ source: NSImage, size: CGFloat, cornerRadius: CGFloat) -> NSImage {
        let targetSize = NSSize(width: size, height: size)
        let image = NSImage(size: targetSize)
        image.lockFocus()

        let rect = NSRect(origin: .zero, size: targetSize)
        let path = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
        path.addClip()

        let sourceSize = source.size
        let scale = max(size / sourceSize.width, size / sourceSize.height)
        let drawSize = NSSize(width: sourceSize.width * scale, height: sourceSize.height * scale)
        let drawOrigin = NSPoint(x: (size - drawSize.width) / 2, y: (size - drawSize.height) / 2)
        source.draw(
            in: NSRect(origin: drawOrigin, size: drawSize),
            from: NSRect(origin: .zero, size: sourceSize),
            operation: .copy,
            fraction: 1.0
        )

        image.unlockFocus()
        return image
    }

    private static func initialsImage(for name: String, size: CGFloat, cornerRadius: CGFloat) -> NSImage {
        let targetSize = NSSize(width: size, height: size)
        let image = NSImage(size: targetSize)
        image.lockFocus()

        let rect = NSRect(origin: .zero, size: targetSize)
        let path = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
        NSColor.systemGray.setFill()
        path.fill()

        let initials = String(name.prefix(2).uppercased())
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: size * 0.4, weight: .bold),
            .foregroundColor: NSColor.white
        ]
        let attrString = NSAttributedString(string: initials, attributes: attributes)
        let stringSize = attrString.size()
        let stringOrigin = NSPoint(
            x: (size - stringSize.width) / 2,
            y: (size - stringSize.height) / 2
        )
        attrString.draw(at: stringOrigin)

        image.unlockFocus()
        return image
    }
}

// MARK: - Account Avatar (SwiftUI)

/// Displays an account avatar loaded asynchronously, with initials fallback.
struct AccountAvatar: View {
    var login: String
    var avatarURL: String?
    var size: CGFloat

    var body: some View {
        Group {
            if let urlString = avatarURL, let url = URL(string: urlString) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    initialsView
                }
            } else {
                initialsView
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private var initialsView: some View {
        ZStack {
            Circle()
                .fill(.gray)
            Text(String(login.prefix(2).uppercased()))
                .font(.system(size: size * 0.4, weight: .bold))
                .foregroundStyle(.white)
        }
    }
}

// MARK: - NSMenuItem Action Helper

/// Retains a closure as the target for an NSMenuItem action.
class PickerMenuAction: NSObject {
    let handler: () -> Void

    init(handler: @escaping () -> Void) {
        self.handler = handler
    }

    @objc func execute() {
        handler()
    }
}

// MARK: - Picker Anchor View

/// Invisible NSViewRepresentable that exposes its backing NSView
/// so we can position an NSMenu relative to a SwiftUI view.
struct PickerAnchorView: NSViewRepresentable {
    @Binding var nsView: NSView?

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        Task { @MainActor in self.nsView = view }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        Task { @MainActor in self.nsView = nsView }
    }
}
