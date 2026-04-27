import SwiftUI

/// User-facing refresh interval options.
enum RefreshInterval: Int, CaseIterable, Identifiable {
    case oneMinute = 60
    case twoMinutes = 120
    case threeMinutes = 180
    case fiveMinutes = 300
    case tenMinutes = 600
    case fifteenMinutes = 900
    case thirtyMinutes = 1800

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .oneMinute: "1 minute"
        case .twoMinutes: "2 minutes"
        case .threeMinutes: "3 minutes"
        case .fiveMinutes: "5 minutes"
        case .tenMinutes: "10 minutes"
        case .fifteenMinutes: "15 minutes"
        case .thirtyMinutes: "30 minutes"
        }
    }
}

/// Settings tab for configuring background sync behavior.
struct SyncSettingsTab: View {
    @AppStorage("backgroundRefreshInterval") private var refreshInterval = RefreshInterval.fiveMinutes.rawValue

    var body: some View {
        Form {
            Picker("Refresh every", selection: $refreshInterval) {
                ForEach(RefreshInterval.allCases) { interval in
                    Text(interval.label).tag(interval.rawValue)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: 300)

            Text("Issues are automatically refreshed from GitHub while the app is active.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
    }
}
