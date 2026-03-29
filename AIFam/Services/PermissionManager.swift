import EventKit
import Contacts
import CoreLocation
import HealthKit
import UserNotifications
import SwiftUI

enum PermissionType: String, CaseIterable, Identifiable {
    case calendar
    case contacts
    case reminders
    case location
    case notifications
    case health

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .calendar: "Calendar"
        case .contacts: "Contacts"
        case .reminders: "Reminders"
        case .location: "Location"
        case .notifications: "Notifications"
        case .health: "Health"
        }
    }

    var benefit: String {
        switch self {
        case .calendar: "See your schedule, catch conflicts"
        case .contacts: "Know your people, remember birthdays"
        case .reminders: "Track what's on your plate"
        case .location: "Learn your home, work, routine"
        case .notifications: "Heads up when something matters"
        case .health: "Sleep + wellness awareness"
        }
    }

    var icon: String {
        switch self {
        case .calendar: "calendar"
        case .contacts: "person.2.fill"
        case .reminders: "checklist"
        case .location: "location.fill"
        case .notifications: "bell.fill"
        case .health: "heart.fill"
        }
    }
}

enum PermissionStatus: String {
    case notDetermined
    case granted
    case denied
    case limited
}

@Observable
@MainActor
final class PermissionManager {
    var statuses: [PermissionType: PermissionStatus] = [:]

    private let eventStore = EKEventStore()
    private let contactStore = CNContactStore()
    private let locationManager = CLLocationManager()
    private let healthStore: HKHealthStore? = HKHealthStore.isHealthDataAvailable() ? HKHealthStore() : nil

    init() {
        refreshAllStatuses()
    }

    // MARK: - Status Checking

    func refreshAllStatuses() {
        for type in PermissionType.allCases {
            statuses[type] = currentStatus(for: type)
        }
    }

    func currentStatus(for type: PermissionType) -> PermissionStatus {
        switch type {
        case .calendar:
            return mapEKStatus(EKEventStore.authorizationStatus(for: .event))
        case .reminders:
            return mapEKStatus(EKEventStore.authorizationStatus(for: .reminder))
        case .contacts:
            return mapCNStatus(CNContactStore.authorizationStatus(for: .contacts))
        case .location:
            return mapCLStatus(locationManager.authorizationStatus)
        case .notifications:
            // Notification status requires async check — default to notDetermined
            // Updated asynchronously via refreshNotificationStatus()
            return statuses[.notifications] ?? .notDetermined
        case .health:
            // HealthKit doesn't expose a global status — tracked per request
            return statuses[.health] ?? .notDetermined
        }
    }

    // MARK: - Permission Requests

    func request(_ type: PermissionType) async -> PermissionStatus {
        let status: PermissionStatus

        switch type {
        case .calendar:
            status = await requestCalendarAccess()
        case .reminders:
            status = await requestRemindersAccess()
        case .contacts:
            status = await requestContactsAccess()
        case .location:
            requestLocationAccess()
            status = .notDetermined // Updated via delegate
        case .notifications:
            status = await requestNotificationAccess()
        case .health:
            status = await requestHealthAccess()
        }

        statuses[type] = status
        return status
    }

    var grantedPermissions: [PermissionType] {
        PermissionType.allCases.filter { statuses[$0] == .granted }
    }

    var grantedCount: Int {
        grantedPermissions.count
    }

    // MARK: - Individual Requests

    private func requestCalendarAccess() async -> PermissionStatus {
        do {
            let granted = try await eventStore.requestFullAccessToEvents()
            return granted ? .granted : .denied
        } catch {
            return .denied
        }
    }

    private func requestRemindersAccess() async -> PermissionStatus {
        do {
            let granted = try await eventStore.requestFullAccessToReminders()
            return granted ? .granted : .denied
        } catch {
            return .denied
        }
    }

    private func requestContactsAccess() async -> PermissionStatus {
        do {
            let granted = try await contactStore.requestAccess(for: .contacts)
            return granted ? .granted : .denied
        } catch {
            return .denied
        }
    }

    private func requestLocationAccess() {
        locationManager.requestWhenInUseAuthorization()
    }

    func requestAlwaysLocationAccess() {
        locationManager.requestAlwaysAuthorization()
    }

    private func requestNotificationAccess() async -> PermissionStatus {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
            return granted ? .granted : .denied
        } catch {
            return .denied
        }
    }

    private func requestHealthAccess() async -> PermissionStatus {
        guard let healthStore else { return .denied }

        let readTypes: Set<HKObjectType> = [
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
        ]

        do {
            try await healthStore.requestAuthorization(toShare: [], read: readTypes)
            // HealthKit doesn't tell us if user actually granted — assume granted if no error
            return .granted
        } catch {
            return .denied
        }
    }

    func refreshNotificationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            statuses[.notifications] = .granted
        case .denied:
            statuses[.notifications] = .denied
        case .notDetermined:
            statuses[.notifications] = .notDetermined
        @unknown default:
            statuses[.notifications] = .notDetermined
        }
    }

    // MARK: - Status Mapping

    private func mapEKStatus(_ status: EKAuthorizationStatus) -> PermissionStatus {
        switch status {
        case .fullAccess: .granted
        case .writeOnly: .limited
        case .denied, .restricted: .denied
        case .notDetermined: .notDetermined
        @unknown default: .notDetermined
        }
    }

    private func mapCNStatus(_ status: CNAuthorizationStatus) -> PermissionStatus {
        switch status {
        case .authorized: .granted
        case .limited: .limited
        case .denied, .restricted: .denied
        case .notDetermined: .notDetermined
        @unknown default: .notDetermined
        }
    }

    private func mapCLStatus(_ status: CLAuthorizationStatus) -> PermissionStatus {
        switch status {
        case .authorizedAlways, .authorizedWhenInUse: .granted
        case .denied, .restricted: .denied
        case .notDetermined: .notDetermined
        @unknown default: .notDetermined
        }
    }
}
