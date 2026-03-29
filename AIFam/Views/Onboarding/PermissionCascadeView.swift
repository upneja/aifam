import SwiftUI

struct PermissionCascadeView: View {
    @Environment(PermissionManager.self) private var permissionManager

    @State private var currentIndex = 0
    @State private var isRequesting = false

    let onContinue: () -> Void

    private let permissionOrder: [PermissionType] = [
        .calendar, .contacts, .reminders, .location, .notifications, .health
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Progress indicator
            HStack(spacing: 8) {
                ForEach(0..<permissionOrder.count, id: \.self) { index in
                    let type = permissionOrder[index]
                    let status = permissionManager.statuses[type] ?? .notDetermined

                    Circle()
                        .fill(statusDotColor(status: status, index: index))
                        .frame(width: 10, height: 10)
                }
            }
            .padding(.top, 24)

            Spacer()

            if currentIndex < permissionOrder.count {
                let permission = permissionOrder[currentIndex]

                VStack(spacing: 24) {
                    // Permission icon
                    ZStack {
                        Circle()
                            .fill(AppColors.goldLight)
                            .frame(width: 100, height: 100)

                        Image(systemName: permission.icon)
                            .font(.system(size: 40))
                            .foregroundStyle(AppColors.gold)
                    }

                    VStack(spacing: 8) {
                        Text(permission.displayName)
                            .font(AppTypography.title)
                            .foregroundStyle(AppColors.primaryText)

                        Text(permission.benefit)
                            .font(AppTypography.callout)
                            .foregroundStyle(AppColors.secondaryText)
                            .multilineTextAlignment(.center)
                    }
                }

                Spacer()

                VStack(spacing: 12) {
                    Button {
                        requestCurrentPermission()
                    } label: {
                        Text("Allow \(permissionOrder[currentIndex].displayName)")
                            .font(AppTypography.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(AppColors.gold)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(isRequesting)

                    Button {
                        advanceToNext()
                    } label: {
                        Text("Skip")
                            .font(AppTypography.callout)
                            .foregroundStyle(AppColors.secondaryText)
                    }

                    Text("Skip any — I'll work with what you give me.")
                        .font(AppTypography.footnote)
                        .foregroundStyle(AppColors.secondaryText.opacity(0.6))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            } else {
                // All permissions requested
                allDoneView
            }

            // Checklist
            checklistView
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
        }
        .background(AppColors.cardBackground)
    }

    private var checklistView: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(permissionOrder) { type in
                let status = permissionManager.statuses[type] ?? .notDetermined
                HStack(spacing: 10) {
                    Image(systemName: checklistIcon(status))
                        .font(.system(size: 14))
                        .foregroundStyle(checklistColor(status))

                    Text(type.displayName)
                        .font(AppTypography.subheadline)
                        .foregroundStyle(status == .granted ? AppColors.primaryText : AppColors.secondaryText)
                }
            }
        }
    }

    private var allDoneView: some View {
        VStack(spacing: 24) {
            Spacer()

            let grantedCount = permissionManager.grantedCount

            VStack(spacing: 12) {
                Text(grantedCount >= 4 ? "Great access." : grantedCount >= 2 ? "Good start." : "Minimal access.")
                    .font(AppTypography.title)
                    .foregroundStyle(AppColors.primaryText)

                Text("I'll work with what you gave me. You can always change these later in Settings.")
                    .font(AppTypography.callout)
                    .foregroundStyle(AppColors.secondaryText)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            Button(action: onContinue) {
                Text("Build my file")
                    .font(AppTypography.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(AppColors.gold)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
    }

    private func requestCurrentPermission() {
        isRequesting = true
        let type = permissionOrder[currentIndex]

        Task {
            _ = await permissionManager.request(type)
            isRequesting = false
            advanceToNext()
        }
    }

    private func advanceToNext() {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentIndex += 1
        }
    }

    private func statusDotColor(status: PermissionStatus, index: Int) -> Color {
        switch status {
        case .granted: AppColors.calendar
        case .limited: AppColors.tasks
        case .denied: AppColors.dates
        case .notDetermined: index == currentIndex ? AppColors.gold : AppColors.secondaryText.opacity(0.3)
        }
    }

    private func checklistIcon(_ status: PermissionStatus) -> String {
        switch status {
        case .granted: "checkmark.circle.fill"
        case .limited: "exclamationmark.circle.fill"
        case .denied: "xmark.circle.fill"
        case .notDetermined: "circle"
        }
    }

    private func checklistColor(_ status: PermissionStatus) -> Color {
        switch status {
        case .granted: AppColors.calendar
        case .limited: AppColors.tasks
        case .denied: AppColors.dates
        case .notDetermined: AppColors.secondaryText.opacity(0.3)
        }
    }
}
