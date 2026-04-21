import SwiftUI

/// Step 4 of the onboarding wizard: initial sync with progress display.
struct SyncingStepView: View {
    var syncStore: SyncStore
    var authStore: AuthStore
    var selectedRepoIds: Set<Int64>
    var onBack: () -> Void
    var onDone: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Text("Initial setup")
                .font(.system(size: 15, weight: .semibold))
                .padding(.top, 24)

            Spacer()

            syncContent
                .padding(.horizontal, 40)

            Spacer()

            HStack {
                Spacer()
                Button("Back") {
                    syncStore.cancelSync()
                    onBack()
                }
                .keyboardShortcut(.cancelAction)
                .disabled(isDone)
                Button {
                    onDone()
                } label: {
                    SwiftUI.Label("Done", systemImage: "checkmark")
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isDone)
                .accessibilityLabel("Done, close wizard")
            }
            .controlSize(.large)
            .padding(.horizontal, 32)
            .padding(.bottom, 24)
        }
        .task {
            guard let token = authStore.accessToken else { return }
            syncStore.startSyncForRepos(repoIds: selectedRepoIds, token: token)
        }
    }

    // MARK: - Computed

    private var isDone: Bool {
        switch syncStore.state {
        case .completed, .error: true
        default: false
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var syncContent: some View {
        switch syncStore.state {
        case .idle:
            ProgressView()
                .controlSize(.large)

        case .syncing(let progress):
            VStack(spacing: 16) {
                if let fraction = syncFraction(progress) {
                    ProgressView(value: fraction)
                        .progressViewStyle(.linear)
                        .accessibilityLabel("Sync progress: \(Int(fraction * 100)) percent")
                } else {
                    ProgressView()
                        .controlSize(.large)
                }

                Text(progressLabel(progress))
                    .font(.system(size: 13))
                    .multilineTextAlignment(.center)
            }

        case .completed:
            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.green)
                Text("All issues synced successfully")
                    .font(.system(size: 13))
            }

        case .error(let message):
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.red)
                Text(message)
                    .font(.system(size: 13))
                    .multilineTextAlignment(.center)
                Button("Retry") {
                    guard let token = authStore.accessToken else { return }
                    syncStore.startSyncForRepos(repoIds: selectedRepoIds, token: token)
                }
                .controlSize(.large)
                .accessibilityLabel("Retry sync")
            }
        }
    }

    // MARK: - Helpers

    private func syncFraction(_ progress: SyncStore.SyncProgress) -> Double? {
        guard progress.repositoriesTotal > 0 else { return nil }
        return Double(progress.repositoriesSynced) / Double(progress.repositoriesTotal)
    }

    private func progressLabel(_ progress: SyncStore.SyncProgress) -> String {
        switch progress.phase {
        case .fetchingAccount:
            return "Fetching account..."
        case .fetchingRepositories:
            return "Fetching repositories..."
        case .syncingRepository(let name):
            if progress.repositoriesTotal > 0 {
                return "\(name) · Syncing issues (\(progress.repositoriesSynced) of \(progress.repositoriesTotal))"
            }
            return "\(name) · Syncing issues..."
        }
    }
}

// MARK: - Previews

#Preview("Syncing") {
    SyncingStepView(
        syncStore: SyncStore(previewState: .syncing(SyncStore.SyncProgress(
            phase: .syncingRepository("gecko-issues"),
            repositoriesSynced: 1,
            repositoriesTotal: 3
        ))),
        authStore: AuthStore(previewState: .authenticated(username: "octocat")),
        selectedRepoIds: [1, 2, 3],
        onBack: {},
        onDone: {}
    )
    .frame(width: 520, height: 460)
}

#Preview("Completed") {
    SyncingStepView(
        syncStore: SyncStore(previewState: .completed(Date())),
        authStore: AuthStore(previewState: .authenticated(username: "octocat")),
        selectedRepoIds: [1],
        onBack: {},
        onDone: {}
    )
    .frame(width: 520, height: 460)
}

#Preview("Error") {
    SyncingStepView(
        syncStore: SyncStore(previewState: .error("Could not connect to GitHub. Check your internet connection.")),
        authStore: AuthStore(previewState: .authenticated(username: "octocat")),
        selectedRepoIds: [1],
        onBack: {},
        onDone: {}
    )
    .frame(width: 520, height: 460)
}
