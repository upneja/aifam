import SwiftUI
import SwiftData

@main
struct AIFamApp: App {
    @State private var syncCoordinator = DataSyncCoordinator()
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
    }
}
