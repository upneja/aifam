import SwiftUI
import SwiftData
import WidgetKit

@main
struct AIFamApp: App {
    @State private var syncCoordinator = DataSyncCoordinator()
    @State private var notificationService = NotificationService()
    @State private var showOnboarding = false

    var body: some Scene {
        WindowGroup {
            Group {
                if showOnboarding {
                    OnboardingContainerView {
                        completeOnboarding()
                    }
                    .environment(syncCoordinator)
                    .environment(syncCoordinator.permissionManager)
                } else {
                    AppShell()
                        .environment(syncCoordinator)
                        .environment(syncCoordinator.permissionManager)
                }
            }
            .onAppear {
                checkOnboardingState()
                DataSyncCoordinator.registerBackgroundTasks()
                notificationService.registerCategories()
                refreshWidgetAndNotifications()
            }
        }
        .modelContainer(for: [BinderItem.self, ChatMessage.self, UserProfile.self])
        .backgroundTask(.appRefresh(DataSyncCoordinator.appRefreshIdentifier)) {
            DataSyncCoordinator.scheduleAppRefresh()
        }
    }

    private func checkOnboardingState() {
        // Check UserDefaults for fast path — SwiftData may not be ready yet
        let hasCompleted = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        showOnboarding = !hasCompleted
    }

    private func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        withAnimation(.easeInOut(duration: 0.5)) {
            showOnboarding = false
        }
        refreshWidgetAndNotifications()
    }

    private func refreshWidgetAndNotifications() {
        // If a briefing exists in the shared container, update widget and schedule notifications
        if let briefing = SharedDataManager.shared.loadBriefing() {
            WidgetCenter.shared.reloadAllTimelines()
            notificationService.scheduleFromBriefing(briefing)
        }
    }
}
