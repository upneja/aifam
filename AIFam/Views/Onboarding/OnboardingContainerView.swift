import SwiftUI

struct OnboardingContainerView: View {
    @Environment(PermissionManager.self) private var permissionManager
    @Environment(DataSyncCoordinator.self) private var syncCoordinator
    @Environment(\.modelContext) private var modelContext

    @State private var currentStep = 0
    @State private var ingestedCount = 0

    let onComplete: () -> Void

    var body: some View {
        TabView(selection: $currentStep) {
            WelcomeView(onContinue: { currentStep = 1 })
                .tag(0)

            PermissionCascadeView(onContinue: {
                currentStep = 2
                startBuildPhase()
            })
            .tag(1)

            BuildingPhaseView(
                syncCoordinator: syncCoordinator,
                onComplete: { count in
                    ingestedCount = count
                    currentStep = 3
                }
            )
            .tag(2)

            InstantValueView(
                ingestedCount: ingestedCount,
                onComplete: onComplete
            )
            .tag(3)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .animation(.easeInOut(duration: 0.4), value: currentStep)
        .interactiveDismissDisabled()
    }

    private func startBuildPhase() {
        syncCoordinator.configure(modelContext: modelContext)
        Task {
            let count = await syncCoordinator.performOnboardingSync()
            ingestedCount = count
        }
    }
}
