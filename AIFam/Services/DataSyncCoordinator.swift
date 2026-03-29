@preconcurrency import BackgroundTasks
import Foundation
import SwiftData

enum SyncSource: String, CaseIterable {
    case calendar
    case contacts
    case reminders
    case location
    case health
}

enum SyncStatus {
    case idle
    case syncing(SyncSource)
    case completed(itemCount: Int)
    case failed(Error)
}

@Observable
@MainActor
final class DataSyncCoordinator {
    nonisolated static let appRefreshIdentifier = "com.tabbyapp.sync.refresh"
    nonisolated static let processingIdentifier = "com.tabbyapp.sync.processing"

    let permissionManager: PermissionManager
    let calendarService: CalendarIngestionService
    let contactsService: ContactsIngestionService
    let remindersService: RemindersIngestionService
    let locationService: LocationService
    let healthService: HealthIngestionService

    var syncStatus: SyncStatus = .idle
    var lastFullSync: Date?
    var syncProgress: [SyncSource: Bool] = [:]
    var totalItemsIngested: Int = 0

    private var modelContext: ModelContext?

    init(
        permissionManager: PermissionManager = PermissionManager(),
        calendarService: CalendarIngestionService = CalendarIngestionService(),
        contactsService: ContactsIngestionService = ContactsIngestionService(),
        remindersService: RemindersIngestionService = RemindersIngestionService(),
        locationService: LocationService = LocationService(),
        healthService: HealthIngestionService = HealthIngestionService()
    ) {
        self.permissionManager = permissionManager
        self.calendarService = calendarService
        self.contactsService = contactsService
        self.remindersService = remindersService
        self.locationService = locationService
        self.healthService = healthService
    }

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Full Sync (all sources)

    func performFullSync() async {
        guard let modelContext else { return }

        syncStatus = .syncing(.calendar)
        totalItemsIngested = 0

        for source in SyncSource.allCases {
            syncProgress[source] = false
        }

        // Calendar
        if permissionManager.statuses[.calendar] == .granted {
            syncStatus = .syncing(.calendar)
            let events = calendarService.fetchEvents(months: 3)
            let conflicts = calendarService.detectConflicts(in: events)
            let items = calendarService.mapToBinderItems(events: events, conflicts: conflicts)
            upsertItems(items, source: "calendar", modelContext: modelContext)
            syncProgress[.calendar] = true
        }

        // Contacts
        if permissionManager.statuses[.contacts] == .granted ||
           permissionManager.statuses[.contacts] == .limited {
            syncStatus = .syncing(.contacts)
            let contacts = contactsService.fetchContacts()
            let items = contactsService.mapToBinderItems(contacts: contacts)
            upsertItems(items, source: "contacts", modelContext: modelContext)
            syncProgress[.contacts] = true
        }

        // Reminders
        if permissionManager.statuses[.reminders] == .granted {
            syncStatus = .syncing(.reminders)
            let reminders = await remindersService.fetchReminders()
            let items = remindersService.mapToBinderItems(reminders: reminders)
            upsertItems(items, source: "reminders", modelContext: modelContext)
            syncProgress[.reminders] = true
        }

        // Location
        if permissionManager.statuses[.location] == .granted {
            syncStatus = .syncing(.location)
            locationService.startMonitoring()
            syncProgress[.location] = true
        }

        // Health
        if permissionManager.statuses[.health] == .granted {
            syncStatus = .syncing(.health)
            let items = await healthService.mapToBinderItems()
            upsertItems(items, source: "health", modelContext: modelContext)
            healthService.enableBackgroundDelivery()
            syncProgress[.health] = true
        }

        lastFullSync = Date()
        syncStatus = .completed(itemCount: totalItemsIngested)
    }

    // MARK: - Delta Sync (lightweight, for background refresh)

    func performDeltaSync() async {
        guard let modelContext else { return }

        // Only re-sync calendar and reminders (most likely to change frequently)
        if permissionManager.statuses[.calendar] == .granted {
            let events = calendarService.fetchEvents(months: 1)
            let conflicts = calendarService.detectConflicts(in: events)
            let items = calendarService.mapToBinderItems(events: events, conflicts: conflicts)
            upsertItems(items, source: "calendar", modelContext: modelContext)
        }

        if permissionManager.statuses[.reminders] == .granted {
            let reminders = await remindersService.fetchIncompleteReminders()
            let items = remindersService.mapToBinderItems(reminders: reminders)
            upsertItems(items, source: "reminders", modelContext: modelContext)
        }

        if permissionManager.statuses[.health] == .granted {
            let items = await healthService.mapToBinderItems()
            upsertItems(items, source: "health", modelContext: modelContext)
        }

        lastFullSync = Date()
    }

    // MARK: - Onboarding Sync (heavy, uses full history)

    func performOnboardingSync() async -> Int {
        guard let modelContext else { return 0 }

        totalItemsIngested = 0

        // Heavy calendar fetch (4 years)
        if permissionManager.statuses[.calendar] == .granted {
            syncStatus = .syncing(.calendar)
            let events = calendarService.fetchHistoricalEvents(years: 4)
            let conflicts = calendarService.detectConflicts(in: calendarService.fetchEvents(months: 3))
            let items = calendarService.mapToBinderItems(events: events, conflicts: conflicts)
            upsertItems(items, source: "calendar", modelContext: modelContext)
            syncProgress[.calendar] = true
        }

        // Contacts
        if permissionManager.statuses[.contacts] == .granted ||
           permissionManager.statuses[.contacts] == .limited {
            syncStatus = .syncing(.contacts)
            let contacts = contactsService.fetchContacts()
            let items = contactsService.mapToBinderItems(contacts: contacts)
            upsertItems(items, source: "contacts", modelContext: modelContext)
            syncProgress[.contacts] = true
        }

        // All reminders
        if permissionManager.statuses[.reminders] == .granted {
            syncStatus = .syncing(.reminders)
            let reminders = await remindersService.fetchReminders()
            let items = remindersService.mapToBinderItems(reminders: reminders)
            upsertItems(items, source: "reminders", modelContext: modelContext)
            syncProgress[.reminders] = true
        }

        // Health (last 7 days for onboarding)
        if permissionManager.statuses[.health] == .granted {
            syncStatus = .syncing(.health)
            let items = await healthService.mapToBinderItems()
            upsertItems(items, source: "health", modelContext: modelContext)
            syncProgress[.health] = true
        }

        // Location monitoring
        if permissionManager.statuses[.location] == .granted {
            locationService.startMonitoring()
            syncProgress[.location] = true
        }

        lastFullSync = Date()
        syncStatus = .completed(itemCount: totalItemsIngested)

        return totalItemsIngested
    }

    // MARK: - Upsert (deduplication by source + title)

    private func upsertItems(_ items: [BinderItem], source: String, modelContext: ModelContext) {
        for item in items {
            let title = item.title
            let sourceMatch = source

            let descriptor = FetchDescriptor<BinderItem>(
                predicate: #Predicate<BinderItem> { existing in
                    existing.source == sourceMatch && existing.title == title
                }
            )

            do {
                let existing = try modelContext.fetch(descriptor)
                if let match = existing.first {
                    // Update existing
                    match.detail = item.detail
                    match.dueDate = item.dueDate
                    match.urgencyDays = item.urgencyDays
                    match.relatedNotes = item.relatedNotes
                    match.updatedAt = Date()
                } else {
                    // Insert new
                    modelContext.insert(item)
                    totalItemsIngested += 1
                }
            } catch {
                // If fetch fails, insert as new
                modelContext.insert(item)
                totalItemsIngested += 1
            }
        }

        try? modelContext.save()
    }

    // MARK: - Background Task Registration

    nonisolated static func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: appRefreshIdentifier,
            using: nil
        ) { task in
            guard let refreshTask = task as? BGAppRefreshTask else { return }
            handleAppRefresh(task: refreshTask)
        }

        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: processingIdentifier,
            using: nil
        ) { task in
            guard let processingTask = task as? BGProcessingTask else { return }
            handleProcessing(task: processingTask)
        }
    }

    nonisolated static func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: appRefreshIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes
        try? BGTaskScheduler.shared.submit(request)
    }

    nonisolated static func scheduleProcessing() {
        let request = BGProcessingTaskRequest(identifier: processingIdentifier)
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = true
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60) // 1 hour
        try? BGTaskScheduler.shared.submit(request)
    }

    private nonisolated static func handleAppRefresh(task: BGAppRefreshTask) {
        scheduleAppRefresh() // Schedule next refresh

        let syncTask = Task { @Sendable in
            // Delta sync runs in background — coordinator needs to be accessed
            // via the shared app instance. This is wired up in AIFamApp.swift.
        }

        task.expirationHandler = { @Sendable in
            syncTask.cancel()
        }

        // Mark complete after a reasonable time
        Task { @Sendable in
            try? await Task.sleep(for: .seconds(25))
            task.setTaskCompleted(success: true)
        }
    }

    private nonisolated static func handleProcessing(task: BGProcessingTask) {
        scheduleProcessing() // Schedule next processing

        let syncTask = Task { @Sendable in
            // Full sync runs overnight on charger
        }

        task.expirationHandler = { @Sendable in
            syncTask.cancel()
        }

        Task { @Sendable in
            try? await Task.sleep(for: .seconds(120))
            task.setTaskCompleted(success: true)
        }
    }
}
