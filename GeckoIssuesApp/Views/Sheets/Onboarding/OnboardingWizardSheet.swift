import SwiftUI

// MARK: - Wizard Data Types

struct OrgOption: Identifiable, Equatable, Hashable {
    let id: Int64
    let login: String
    let avatarURL: String?
    let isPersonalAccount: Bool
}

struct RepoOption: Identifiable, Equatable {
    let id: Int64
    let name: String
    let nameWithOwner: String
    let isPrivate: Bool
}

// MARK: - Wizard Sheet

/// 4-step onboarding wizard shown on first launch to guide the user
/// from a cold start to a live-syncing app.
struct OnboardingWizardSheet: View {
    var authStore: AuthStore
    var syncStore: SyncStore
    var appStore: AppStore
    var database: AppDatabase

    @Environment(\.dismiss) private var dismiss

    private let syncService = GitHubSyncService()

    @State private var step: WizardStep = .connectGitHub
    @State private var selectedOrg: OrgOption?
    @State private var selectedRepoIds: Set<Int64> = []

    // MARK: - Step Enum

    enum WizardStep {
        case connectGitHub
        case selectOrg
        case selectRepos
        case syncing
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            switch step {
            case .connectGitHub:
                ConnectGitHubStepView(
                    authStore: authStore,
                    onCancel: { dismiss() },
                    onContinue: { step = .selectOrg }
                )

            case .selectOrg:
                SelectOrgStepView(
                    authStore: authStore,
                    syncService: syncService,
                    selectedOrg: $selectedOrg,
                    onBack: { step = .connectGitHub },
                    onContinue: { step = .selectRepos }
                )

            case .selectRepos:
                if let org = selectedOrg {
                    SelectReposStepView(
                        authStore: authStore,
                        syncService: syncService,
                        selectedOrg: org,
                        selectedRepoIds: $selectedRepoIds,
                        onBack: { step = .selectOrg },
                        onContinue: { step = .syncing }
                    )
                }

            case .syncing:
                SyncingStepView(
                    syncStore: syncStore,
                    authStore: authStore,
                    onDone: { dismiss() }
                )
            }
        }
        .frame(width: 520, height: 460)
    }
}
