import Foundation
import GRDB

/// Manages the current account, selected repository/project, and navigation state.
@MainActor @Observable
final class AppStore {
    var accounts: [Account] = []
    var selectedAccount: Account?
    var selectedRepository: Repository?
    var selectedIssue: Issue?

    /// Load accounts that own at least one tracked repository, sorted with user accounts first, then orgs.
    func loadAccounts(from database: AppDatabase) async {
        do {
            accounts = try await database.dbQueue.read { db in
                try Account
                    .joining(required: Account.repositories.filter(Column("tracked") == true))
                    .order(
                        // Users first, then organizations
                        Column("type").desc,
                        Column("login").collating(.localizedCaseInsensitiveCompare)
                    )
                    .fetchAll(db)
            }
            // Auto-select first account if none selected
            if selectedAccount == nil {
                selectedAccount = accounts.first
            }
        } catch {
            // Non-fatal; accounts list stays empty
        }
    }
}
