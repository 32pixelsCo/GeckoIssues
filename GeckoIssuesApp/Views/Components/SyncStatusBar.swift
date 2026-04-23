import SwiftUI

/// Status bar displayed at the bottom of the window showing sync state.
///
/// Shows progress during sync ("Syncing issue 8 of 42") and a relative
/// timestamp with a manual sync button when idle.
struct SyncStatusBar: View {
    var syncStore: SyncStore
    var authStore: AuthStore

    var body: some View {
        HStack(spacing: 8) {
            statusIcon
            statusText
            Spacer()
            actionButton
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .frame(height: 28)
        .background(.bar)
        .overlay(alignment: .top) {
            Divider()
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
                .foregroundStyle(.green)
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
        case .completed(let date):
            Text("Synced \(date, format: .relative(presentation: .named))")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        case .error(let message):
            Text("Sync failed \u{00B7} \(message)")
                .font(.system(size: 11))
                .foregroundStyle(.red)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }

    private func syncingText(for progress: SyncStore.SyncProgress) -> String {
        switch progress.phase {
        case .fetchingAccount:
            return "Connecting to GitHub\u{2026}"
        case .fetchingRepositories:
            return "Fetching repositories\u{2026}"
        case .syncingRepository(let name):
            if progress.repositoriesTotal > 1 {
                return "Syncing \(name) (\(progress.repositoriesSynced + 1) of \(progress.repositoriesTotal))"
            }
            return "Syncing \(name)\u{2026}"
        }
    }

    // MARK: - Action Button

    @ViewBuilder
    private var actionButton: some View {
        switch syncStore.state {
        case .syncing:
            EmptyView()
        case .idle, .completed, .error:
            Button("Sync Now") {
                guard let token = authStore.accessToken else { return }
                syncStore.startFullSync(token: token)
            }
            .controlSize(.small)
            .accessibilityLabel("Sync now")
        }
    }
}
