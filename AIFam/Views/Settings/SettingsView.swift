import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Tone") {
                    Text("Default")
                }
                Section("Permissions") {
                    Text("Manage permissions")
                }
            }
            .navigationTitle("Settings")
        }
    }
}
