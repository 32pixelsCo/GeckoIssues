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

/// 3-step onboarding wizard shown on first launch to guide the user
/// from a cold start to a live-syncing app.
///
/// Pass `startStep` to skip earlier steps (e.g. when launched from Settings
/// after the user is already authenticated).
struct OnboardingWizardSheet: View {
    var authStore: AuthStore
    var syncStore: SyncStore
    var appStore: AppStore
    var database: AppDatabase
    var startStep: WizardStep = .connectGitHub
    var alreadyTrackedRepoIds: Set<Int64> = []

    @Environment(\.dismiss) private var dismiss

    private let syncService = GitHubSyncService()

    @State private var step: WizardStep?
    @State private var selectedRepoIds: Set<Int64> = []

    // MARK: - Step Enum

    enum WizardStep {
        case connectGitHub
        case selectRepos
        case syncing
    }

    // MARK: - Body

    private var currentStep: WizardStep {
        step ?? startStep
    }

    var body: some View {
        VStack(spacing: 0) {
            switch currentStep {
            case .connectGitHub:
                ConnectGitHubStepView(
                    authStore: authStore,
                    onCancel: { dismiss() },
                    onContinue: { step = .selectRepos }
                )

            case .selectRepos:
                SelectReposStepView(
                    authStore: authStore,
                    syncService: syncService,
                    selectedRepoIds: $selectedRepoIds,
                    alreadyTrackedRepoIds: alreadyTrackedRepoIds,
                    onBack: {
                        if startStep == .selectRepos {
                            dismiss()
                        } else {
                            step = .connectGitHub
                        }
                    },
                    onContinue: { step = .syncing }
                )

            case .syncing:
                SyncingStepView(
                    syncStore: syncStore,
                    authStore: authStore,
                    selectedRepoIds: selectedRepoIds,
                    onBack: { step = .selectRepos },
                    onDone: { dismiss() }
                )
            }
        }
        .frame(width: 520, height: 460)
    }
}
