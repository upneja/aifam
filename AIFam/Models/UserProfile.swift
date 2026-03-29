import Foundation
import SwiftData

@Model
final class UserProfile {
    var id: UUID
    var name: String
    var tonePresetRaw: String
    var hasCompletedOnboarding: Bool
    var grantedPermissions: [String]
    var createdAt: Date

    var tonePreset: TonePreset {
        get { TonePreset(rawValue: tonePresetRaw) ?? .standard }
        set { tonePresetRaw = newValue.rawValue }
    }

    init(name: String = "", tonePreset: TonePreset = .standard) {
        self.id = UUID()
        self.name = name
        self.tonePresetRaw = tonePreset.rawValue
        self.hasCompletedOnboarding = false
        self.grantedPermissions = []
        self.createdAt = Date()
    }
}
