import Foundation

/// Manages sheet/alert routing, command palette, and UI state.
@MainActor @Observable
final class NavigationStore {
    var activeSheet: SheetRoute?
    var isShowingNewIssueForm = false
}

// MARK: - Sheet Routes

enum SheetRoute: Identifiable {
    case onboarding

    var id: String {
        switch self {
        case .onboarding: "onboarding"
        }
    }
}
