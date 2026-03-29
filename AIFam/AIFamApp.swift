import SwiftUI
import SwiftData

@main
struct AIFamApp: App {
    @State private var syncCoordinator = DataSyncCoordinator()

    var body: some Scene {
        WindowGroup {
            AppShell()
                .environment(syncCoordinator)
                .environment(syncCoordinator.permissionManager)
                .onAppear {
                    DataSyncCoordinator.registerBackgroundTasks()
                }
        }
        .modelContainer(for: [BinderItem.self, ChatMessage.self, UserProfile.self])
        .backgroundTask(.appRefresh(DataSyncCoordinator.appRefreshIdentifier)) {
            DataSyncCoordinator.scheduleAppRefresh()
        }
    }
}
