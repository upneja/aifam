import SwiftUI
import SwiftData

// Stub — replaced in Task 2
struct BinderDetailView: View {
    let category: BinderCategory

    var body: some View {
        Text(category.displayName)
            .navigationTitle(category.displayName)
    }
}
