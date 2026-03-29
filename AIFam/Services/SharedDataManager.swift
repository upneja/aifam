import Foundation

final class SharedDataManager: Sendable {
    static let shared = SharedDataManager()

    private nonisolated(unsafe) let userDefaults: UserDefaults?

    init() {
        userDefaults = UserDefaults(suiteName: SharedDataKeys.appGroupID)
    }

    // MARK: - Write Briefing

    func saveBriefing(_ briefing: SharedBriefingData) {
        guard let data = try? JSONEncoder().encode(briefing) else { return }
        userDefaults?.set(data, forKey: SharedDataKeys.briefingKey)
    }

    // MARK: - Read Briefing

    func loadBriefing() -> SharedBriefingData? {
        guard let data = userDefaults?.data(forKey: SharedDataKeys.briefingKey),
              let briefing = try? JSONDecoder().decode(SharedBriefingData.self, from: data) else {
            return nil
        }
        return briefing
    }
}
