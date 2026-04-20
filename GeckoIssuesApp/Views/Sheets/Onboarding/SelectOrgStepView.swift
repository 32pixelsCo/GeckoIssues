import SwiftUI

/// Step 2 of the onboarding wizard: select an organization or personal account to sync.
struct SelectOrgStepView: View {
    var authStore: AuthStore
    var syncService: any SyncServiceProtocol
    @Binding var selectedOrg: OrgOption?
    var onBack: () -> Void
    var onContinue: () -> Void

    @State private var orgs: [OrgOption] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            Text("Get Started")
                .font(.system(size: 15, weight: .semibold))
                .padding(.top, 24)

            Text("Select an organization")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .padding(.top, 8)

            Spacer().frame(height: 24)

            orgListContent
                .padding(.horizontal, 40)

            Spacer()

            HStack {
                Spacer()
                Button("Back", action: onBack)
                    .keyboardShortcut(.cancelAction)
                Button("Continue", action: onContinue)
                    .keyboardShortcut(.defaultAction)
                    .disabled(selectedOrg == nil)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 24)
        }
        .task {
            await loadOrgs()
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var orgListContent: some View {
        if isLoading {
            VStack(spacing: 12) {
                ProgressView()
                    .controlSize(.regular)
                Text("Loading organizations...")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = errorMessage {
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.red)
                Text(error)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Retry") {
                    Task { await loadOrgs() }
                }
                .accessibilityLabel("Retry loading organizations")
            }
            .frame(maxWidth: .infinity)
        } else {
            List(orgs, selection: selectedOrgBinding) { org in
                OrgRow(org: org)
                    .tag(org)
            }
            .listStyle(.bordered)
            .frame(maxHeight: .infinity)
        }
    }

    // MARK: - Selection Binding

    private var selectedOrgBinding: Binding<OrgOption?> {
        Binding(
            get: { selectedOrg },
            set: { selectedOrg = $0 }
        )
    }

    // MARK: - Data Loading

    private func loadOrgs() async {
        guard let token = authStore.accessToken else { return }
        isLoading = true
        errorMessage = nil
        do {
            let data = try await syncService.fetchViewerWithOrganizations(token: token)
            var options: [OrgOption] = [
                OrgOption(
                    id: data.viewer.databaseId,
                    login: data.viewer.login,
                    avatarURL: data.viewer.avatarUrl,
                    isPersonalAccount: true
                )
            ]
            options += data.organizations.map { org in
                OrgOption(
                    id: org.databaseId,
                    login: org.login,
                    avatarURL: org.avatarUrl,
                    isPersonalAccount: false
                )
            }
            orgs = options
            // Auto-select if only one option
            if orgs.count == 1 {
                selectedOrg = orgs.first
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Previews

#Preview("Loading") {
    SelectOrgStepView(
        authStore: AuthStore(previewState: .authenticated(username: "octocat")),
        syncService: PreviewSyncService(),
        selectedOrg: .constant(nil),
        onBack: {},
        onContinue: {}
    )
    .frame(width: 520, height: 460)
}

#Preview("Loaded") {
    SelectOrgStepView(
        authStore: AuthStore(previewState: .authenticated(username: "octocat")),
        syncService: PreviewSyncService(orgs: [.preview]),
        selectedOrg: .constant(OrgOption(id: 1, login: "octocat", avatarURL: nil, isPersonalAccount: true)),
        onBack: {},
        onContinue: {}
    )
    .frame(width: 520, height: 460)
}

// MARK: - Org Row

private struct OrgRow: View {
    var org: OrgOption

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: org.isPersonalAccount ? "person.circle" : "building.2")
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
                .frame(width: 22)
            Text(org.login)
                .font(.system(size: 13))
            if org.isPersonalAccount {
                Text("Personal")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule().fill(.quaternary)
                    )
            }
            Spacer()
        }
        .padding(.vertical, 2)
        .accessibilityLabel("\(org.login)\(org.isPersonalAccount ? ", personal account" : ", organization")")
    }
}
