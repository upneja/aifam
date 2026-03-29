import SwiftUI
import SwiftData

struct SettingsView: View {
    @Query private var profiles: [UserProfile]
    @Environment(\.modelContext) private var modelContext
    @Environment(PermissionManager.self) private var permissionManager

    private var profile: UserProfile {
        if let existing = profiles.first {
            return existing
        }
        let newProfile = UserProfile()
        modelContext.insert(newProfile)
        try? modelContext.save()
        return newProfile
    }

    var body: some View {
        NavigationStack {
            List {
                // Tone Section
                Section {
                    TonePickerView(selectedTone: Binding(
                        get: { profile.tonePreset },
                        set: { newTone in
                            profile.tonePreset = newTone
                            try? modelContext.save()
                        }
                    ))
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                } header: {
                    Text("How should I talk?")
                        .font(AppTypography.subheadline)
                        .foregroundStyle(AppColors.secondaryText)
                        .textCase(nil)
                }

                // Permissions Section
                Section {
                    ForEach(PermissionType.allCases) { permissionType in
                        permissionRow(permissionType)
                    }
                } header: {
                    Text("Data Sources")
                        .font(AppTypography.subheadline)
                        .foregroundStyle(AppColors.secondaryText)
                        .textCase(nil)
                } footer: {
                    Text("Everything stays on your device. These permissions let me build a better file on your life.")
                        .font(AppTypography.footnote)
                        .foregroundStyle(AppColors.secondaryText)
                }

                // About Section
                Section {
                    HStack {
                        Text("Version")
                            .font(AppTypography.body)
                        Spacer()
                        Text("1.0.0")
                            .font(AppTypography.body)
                            .foregroundStyle(AppColors.secondaryText)
                    }

                    HStack {
                        Text("Data Sources Active")
                            .font(AppTypography.body)
                        Spacer()
                        Text("\(permissionManager.grantedCount) of \(PermissionType.allCases.count)")
                            .font(AppTypography.body)
                            .foregroundStyle(AppColors.gold)
                    }
                } header: {
                    Text("About")
                        .font(AppTypography.subheadline)
                        .foregroundStyle(AppColors.secondaryText)
                        .textCase(nil)
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                permissionManager.refreshAllStatuses()
            }
        }
    }

    private func permissionRow(_ type: PermissionType) -> some View {
        let status = permissionManager.statuses[type] ?? .notDetermined

        return HStack(spacing: 14) {
            Image(systemName: type.icon)
                .font(.system(size: 16))
                .foregroundStyle(statusColor(status))
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(type.displayName)
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.primaryText)

                Text(type.benefit)
                    .font(AppTypography.footnote)
                    .foregroundStyle(AppColors.secondaryText)
            }

            Spacer()

            statusBadge(status, type: type)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func statusBadge(_ status: PermissionStatus, type: PermissionType) -> some View {
        switch status {
        case .granted:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(AppColors.calendar)

        case .limited:
            Text("Limited")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.tasks)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(AppColors.tasksBg)
                .clipShape(Capsule())

        case .denied:
            Button("Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .font(AppTypography.caption)
            .foregroundStyle(AppColors.dates)

        case .notDetermined:
            Button("Enable") {
                Task {
                    _ = await permissionManager.request(type)
                }
            }
            .font(AppTypography.caption)
            .foregroundStyle(AppColors.gold)
        }
    }

    private func statusColor(_ status: PermissionStatus) -> Color {
        switch status {
        case .granted: AppColors.calendar
        case .limited: AppColors.tasks
        case .denied: AppColors.dates
        case .notDetermined: AppColors.secondaryText
        }
    }
}
