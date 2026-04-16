import Foundation

/// Manages the current account, selected repository/project, and navigation state.
@MainActor @Observable
final class AppStore {
    var selectedRepository: Repository?
}
