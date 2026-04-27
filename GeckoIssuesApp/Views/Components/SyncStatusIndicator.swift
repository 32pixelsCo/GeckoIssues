import SwiftUI

/// Compact sync status indicator displayed at the bottom of the sidebar.
///
/// Shows the current sync state (idle, syncing, error, offline) and allows
/// the user to trigger a manual sync by clicking when idle or in error state.
struct SyncStatusIndicator: View {
    var syncStore: SyncStore
    var authStore: AuthStore

    @State private var tick = 0

    var body: some View {
        Button(action: triggerSync) {
            HStack(spacing: 6) {
                statusIcon
                statusText
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isTappable)
        .accessibilityLabel(accessibilityText)
        .accessibilityHint(isTappable ? "Double-tap to sync" : "")
        .overlay(alignment: .top) {
            Divider()
        }
        .task(id: syncStore.state) {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(15))
                tick += 1
            }
        }
    }

    // MARK: - Status Icon

    @ViewBuilder
    private var statusIcon: some View {
        switch syncStore.state {
        case .idle:
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        case .syncing:
            ProgressView()
                .controlSize(.mini)
        case .completed:
            Image(systemName: "checkmark.icloud")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        case .error:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 11))
                .foregroundStyle(.red)
        }
    }

    // MARK: - Status Text

    @ViewBuilder
    private var statusText: some View {
        switch syncStore.state {
        case .idle:
            Text("Not synced")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        case .syncing(let progress):
            Text(syncingText(for: progress))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
        case .completed(let date):
            Text("Updated \(relativeText(from: date))")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        case .error:
            HStack(spacing: 4) {
                Text("Sync failed")
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
                Text("· Retry")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Helpers

    private var isTappable: Bool {
        switch syncStore.state {
        case .idle, .completed, .error:
            return true
        case .syncing:
            return false
        }
    }

    private var accessibilityText: String {
        switch syncStore.state {
        case .idle:
            return "Not synced"
        case .syncing:
            return "Syncing"
        case .completed(let date):
            return "Updated \(relativeText(from: date))"
        case .error(let message):
            return "Sync failed: \(message)"
        }
    }

    private func triggerSync() {
        guard let token = authStore.accessToken else { return }
        syncStore.startFullSync(token: token)
    }

    private func relativeText(from date: Date) -> String {
        _ = tick
        let now = Date()
        let seconds = now.timeIntervalSince(date)
        if seconds < 5 { return "just now" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: now)
    }

    private func syncingText(for progress: SyncStore.SyncProgress) -> String {
        switch progress.phase {
        case .fetchingAccount:
            return "Connecting\u{2026}"
        case .fetchingRepositories:
            return "Fetching repos\u{2026}"
        case .checkingForUpdates:
            return "Checking\u{2026}"
        case .syncingRepository(let name):
            let shortName = name.split(separator: "/").last.map(String.init) ?? name
            if progress.repositoriesTotal > 1 {
                return "Syncing \(shortName) (\(progress.repositoriesSynced + 1)/\(progress.repositoriesTotal))"
            }
            return "Syncing \(shortName)\u{2026}"
        }
    }
}
