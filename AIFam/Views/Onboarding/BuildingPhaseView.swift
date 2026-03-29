import SwiftUI

struct BuildingPhaseView: View {
    let syncCoordinator: DataSyncCoordinator
    let onComplete: (Int) -> Void

    @State private var calendarProgress: Double = 0
    @State private var contactsProgress: Double = 0
    @State private var remindersProgress: Double = 0
    @State private var patternsProgress: Double = 0
    @State private var briefingProgress: Double = 0
    @State private var isComplete = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 44))
                    .foregroundStyle(AppColors.gold)

                Text("Building your file...")
                    .font(AppTypography.title)
                    .foregroundStyle(AppColors.primaryText)
            }

            VStack(alignment: .leading, spacing: 20) {
                progressRow(
                    icon: "calendar",
                    label: "Reading your calendar...",
                    detail: syncCoordinator.calendarService.eventCount > 0
                        ? "\(syncCoordinator.calendarService.eventCount) events"
                        : nil,
                    progress: calendarProgress,
                    color: AppColors.calendar
                )

                progressRow(
                    icon: "person.2.fill",
                    label: "Mapping your people...",
                    detail: syncCoordinator.contactsService.contactCount > 0
                        ? "\(syncCoordinator.contactsService.contactCount) contacts"
                        : nil,
                    progress: contactsProgress,
                    color: AppColors.gold
                )

                progressRow(
                    icon: "checklist",
                    label: "Checking your reminders...",
                    detail: syncCoordinator.remindersService.reminderCount > 0
                        ? "\(syncCoordinator.remindersService.reminderCount) reminders"
                        : nil,
                    progress: remindersProgress,
                    color: AppColors.tasks
                )

                progressRow(
                    icon: "brain",
                    label: "Finding patterns...",
                    detail: nil,
                    progress: patternsProgress,
                    color: AppColors.notes
                )

                progressRow(
                    icon: "doc.richtext",
                    label: "Building your briefing...",
                    detail: nil,
                    progress: briefingProgress,
                    color: AppColors.dates
                )
            }
            .padding(.horizontal, 32)

            Spacer()

            if isComplete {
                Button {
                    onComplete(syncCoordinator.totalItemsIngested)
                } label: {
                    Text("See what I found")
                        .font(AppTypography.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(AppColors.gold)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .background(AppColors.cardBackground)
        .task {
            await animateProgress()
        }
    }

    private func progressRow(
        icon: String,
        label: String,
        detail: String?,
        progress: Double,
        color: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(progress >= 1.0 ? color : AppColors.secondaryText)
                    .frame(width: 20)

                Text(label)
                    .font(AppTypography.callout)
                    .foregroundStyle(progress > 0 ? AppColors.primaryText : AppColors.secondaryText)

                Spacer()

                if let detail, progress >= 1.0 {
                    Text(detail)
                        .font(AppTypography.caption)
                        .foregroundStyle(color)
                }

                if progress >= 1.0 {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(color)
                }
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(uiColor: .systemGray5))
                        .frame(height: 4)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: geometry.size.width * progress, height: 4)
                }
            }
            .frame(height: 4)
        }
    }

    private func animateProgress() async {
        // Animate progress bars in sequence, timed to real data ingestion
        await animateBar(setting: { calendarProgress = $0 }, syncKey: .calendar, duration: 3.0)
        await animateBar(setting: { contactsProgress = $0 }, syncKey: .contacts, duration: 2.5)
        await animateBar(setting: { remindersProgress = $0 }, syncKey: .reminders, duration: 2.0)
        await animateBar(setting: { patternsProgress = $0 }, syncKey: nil, duration: 3.0)
        await animateBar(setting: { briefingProgress = $0 }, syncKey: nil, duration: 2.0)

        withAnimation(.spring(duration: 0.5)) {
            isComplete = true
        }
    }

    private func animateBar(
        setting updateProgress: @escaping (Double) -> Void,
        syncKey: SyncSource?,
        duration: Double
    ) async {
        let steps = 20
        let stepDuration = duration / Double(steps)

        for i in 1...steps {
            try? await Task.sleep(for: .seconds(stepDuration))
            withAnimation(.linear(duration: stepDuration)) {
                updateProgress(Double(i) / Double(steps))
            }
        }

        // Wait for actual sync to complete for this source if applicable
        if let syncKey {
            while syncCoordinator.syncProgress[syncKey] != true {
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
    }
}
