import HealthKit
import Foundation

struct SleepSummary: Sendable {
    let date: Date
    let totalMinutes: Double
    let inBedMinutes: Double
    let remMinutes: Double
    let deepMinutes: Double
    let coreMinutes: Double
    let awakeMinutes: Double
    let quality: SleepQuality
}

enum SleepQuality: String, Sendable {
    case good
    case fair
    case poor

    var displayName: String {
        switch self {
        case .good: "Good"
        case .fair: "Fair"
        case .poor: "Poor"
        }
    }

    var icon: String {
        switch self {
        case .good: "moon.zzz.fill"
        case .fair: "moon.fill"
        case .poor: "moon"
        }
    }
}

struct StepsSummary: Sendable {
    let date: Date
    let count: Int
    let goalMet: Bool
}

struct HeartRateSummary: Sendable {
    let date: Date
    let restingBPM: Double?
    let averageBPM: Double
    let maxBPM: Double
}

@Observable
final class HealthIngestionService {
    private let healthStore = HKHealthStore()
    private let stepGoal = 10_000

    var lastSleepSummary: SleepSummary?
    var lastStepsSummary: StepsSummary?
    var lastSyncDate: Date?

    // MARK: - Sleep Analysis

    func fetchSleepData(days: Int = 7) async -> [SleepSummary] {
        guard HKHealthStore.isHealthDataAvailable() else { return [] }

        let sleepType = HKCategoryType(.sleepAnalysis)
        let calendar = Calendar.current
        let now = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -days, to: now) else { return [] }

        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: now,
            options: .strictStartDate
        )

        let samples: [HKCategorySample] = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, results, _ in
                continuation.resume(returning: (results as? [HKCategorySample]) ?? [])
            }
            healthStore.execute(query)
        }

        // Group by night (use the date of waking up)
        var nightBuckets: [String: [HKCategorySample]] = [:]
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        for sample in samples {
            let nightKey = dateFormatter.string(from: sample.endDate)
            nightBuckets[nightKey, default: []].append(sample)
        }

        return nightBuckets.compactMap { (nightKey, samples) in
            guard let date = dateFormatter.date(from: nightKey) else { return nil }
            return buildSleepSummary(date: date, samples: samples)
        }.sorted { $0.date > $1.date }
    }

    func fetchLastNightSleep() async -> SleepSummary? {
        let summaries = await fetchSleepData(days: 2)
        lastSleepSummary = summaries.first
        return summaries.first
    }

    private func buildSleepSummary(date: Date, samples: [HKCategorySample]) -> SleepSummary {
        var inBed: Double = 0
        var rem: Double = 0
        var deep: Double = 0
        var core: Double = 0
        var awake: Double = 0
        var asleep: Double = 0

        for sample in samples {
            let minutes = sample.endDate.timeIntervalSince(sample.startDate) / 60.0

            switch HKCategoryValueSleepAnalysis(rawValue: sample.value) {
            case .inBed:
                inBed += minutes
            case .asleepREM:
                rem += minutes
                asleep += minutes
            case .asleepDeep:
                deep += minutes
                asleep += minutes
            case .asleepCore:
                core += minutes
                asleep += minutes
            case .awake:
                awake += minutes
            case .asleepUnspecified:
                asleep += minutes
            default:
                break
            }
        }

        let totalAsleep = rem + deep + core + asleep
        let quality: SleepQuality
        if totalAsleep >= 420 { // 7+ hours
            quality = .good
        } else if totalAsleep >= 360 { // 6+ hours
            quality = .fair
        } else {
            quality = .poor
        }

        return SleepSummary(
            date: date,
            totalMinutes: totalAsleep,
            inBedMinutes: inBed,
            remMinutes: rem,
            deepMinutes: deep,
            coreMinutes: core,
            awakeMinutes: awake,
            quality: quality
        )
    }

    // MARK: - Step Count

    func fetchSteps(days: Int = 7) async -> [StepsSummary] {
        guard HKHealthStore.isHealthDataAvailable() else { return [] }

        let stepType = HKQuantityType(.stepCount)
        let calendar = Calendar.current
        let now = Date()

        var summaries: [StepsSummary] = []

        for dayOffset in 0..<days {
            guard let dayStart = calendar.date(byAdding: .day, value: -dayOffset, to: calendar.startOfDay(for: now)),
                  let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { continue }

            let predicate = HKQuery.predicateForSamples(
                withStart: dayStart,
                end: dayEnd,
                options: .strictStartDate
            )

            let steps: Double = await withCheckedContinuation { continuation in
                let query = HKStatisticsQuery(
                    quantityType: stepType,
                    quantitySamplePredicate: predicate,
                    options: .cumulativeSum
                ) { _, result, _ in
                    let sum = result?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                    continuation.resume(returning: sum)
                }
                healthStore.execute(query)
            }

            summaries.append(StepsSummary(
                date: dayStart,
                count: Int(steps),
                goalMet: Int(steps) >= stepGoal
            ))
        }

        lastStepsSummary = summaries.first
        return summaries
    }

    // MARK: - Heart Rate

    func fetchHeartRate(days: Int = 1) async -> [HeartRateSummary] {
        guard HKHealthStore.isHealthDataAvailable() else { return [] }

        let heartRateType = HKQuantityType(.heartRate)
        let calendar = Calendar.current
        let now = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -days, to: now) else { return [] }

        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: now,
            options: .strictStartDate
        )

        let samples: [HKQuantitySample] = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: heartRateType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, results, _ in
                continuation.resume(returning: (results as? [HKQuantitySample]) ?? [])
            }
            healthStore.execute(query)
        }

        guard !samples.isEmpty else { return [] }

        let bpmValues = samples.map { $0.quantity.doubleValue(for: HKUnit(from: "count/min")) }
        let average = bpmValues.reduce(0, +) / Double(bpmValues.count)
        let maxBPM = bpmValues.max() ?? 0

        // Resting heart rate (lowest 10th percentile)
        let sorted = bpmValues.sorted()
        let restingIndex = Swift.max(0, Int(Double(sorted.count) * 0.1))
        let resting = sorted[restingIndex]

        return [HeartRateSummary(
            date: now,
            restingBPM: resting,
            averageBPM: average,
            maxBPM: maxBPM
        )]
    }

    // MARK: - Map to BinderItems

    func mapToBinderItems() async -> [BinderItem] {
        var items: [BinderItem] = []

        // Sleep insight
        if let sleep = await fetchLastNightSleep() {
            let hours = Int(sleep.totalMinutes) / 60
            let mins = Int(sleep.totalMinutes) % 60
            let detail = "\(hours)h \(mins)m · \(sleep.quality.displayName) quality"

            let item = BinderItem(
                title: "Last night's sleep",
                detail: detail,
                category: .notes,
                source: "health"
            )
            items.append(item)
        }

        // Steps today
        let stepsSummaries = await fetchSteps(days: 1)
        if let today = stepsSummaries.first {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            let stepsStr = formatter.string(from: NSNumber(value: today.count)) ?? "\(today.count)"

            let item = BinderItem(
                title: "Steps today: \(stepsStr)",
                detail: today.goalMet ? "Goal met" : "\(stepGoal - today.count) to go",
                category: .notes,
                source: "health"
            )
            items.append(item)
        }

        lastSyncDate = Date()
        return items
    }

    // MARK: - Background Delivery Registration

    func enableBackgroundDelivery() {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        let sleepType = HKCategoryType(.sleepAnalysis)
        healthStore.enableBackgroundDelivery(for: sleepType, frequency: .hourly) { _, _ in }

        let stepType = HKQuantityType(.stepCount)
        healthStore.enableBackgroundDelivery(for: stepType, frequency: .hourly) { _, _ in }
    }
}
