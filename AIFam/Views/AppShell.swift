import SwiftUI

struct AppShell: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Binder", systemImage: "book.closed.fill", value: 0) {
                BinderHomeView()
            }
            Tab("Chat", systemImage: "bubble.left.fill", value: 1) {
                ChatView()
            }
            Tab("Settings", systemImage: "gearshape.fill", value: 2) {
                SettingsView()
            }
        }
        .tint(AppColors.gold)
    }
}
