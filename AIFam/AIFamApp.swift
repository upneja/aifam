import SwiftUI
import SwiftData

@main
struct AIFamApp: App {
    var body: some Scene {
        WindowGroup {
            AppShell()
        }
        .modelContainer(for: [BinderItem.self, ChatMessage.self, UserProfile.self])
    }
}
