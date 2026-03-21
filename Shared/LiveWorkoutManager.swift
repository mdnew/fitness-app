#if os(watchOS)
import Foundation
import HealthKit

@MainActor
final class LiveWorkoutManager: NSObject, ObservableObject {
    @Published var heartRate: Double = 0
    @Published var activeCalories: Double = 0
    @Published var basalCalories: Double = 0
    var totalCalories: Double { activeCalories + basalCalories }
    @Published var elapsedSeconds: Int = 0
    @Published var isRunning: Bool = false

    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private var startDate: Date?
    private var timer: Timer?

    /// Mirrors `HKWorkoutSession` state; updated from the delegate so we can wait for async transitions.
    private var sessionState: HKWorkoutSessionState = .notStarted

    private let healthKitService = HealthKitService()

    private static let statePollIntervalNanoseconds: UInt64 = 50_000_000 // 50 ms
    private static let stateWaitMaxAttempts = 120 // ~6 s total

    /// HealthKit only attributes active time correctly across pause/resume if matching events are appended to the builder.
    /// Without this, finishing often leaves only the brief final `resume`→`end` window (~seconds) as “active” in Health.
    private func appendWorkoutEvent(type: HKWorkoutEventType) {
        guard let builder else { return }
        let now = Date()
        let event = HKWorkoutEvent(type: type, dateInterval: DateInterval(start: now, duration: 0), metadata: nil)
        builder.addWorkoutEvents([event]) { _, error in
            if let error {
                NSLog("LiveWorkoutManager addWorkoutEvents(\(type.rawValue)) failed: \(error.localizedDescription)")
            }
        }
    }

    private func refreshSessionStateFromSession() {
        if let session {
            sessionState = session.state
        }
    }

    /// Waits until the delegate-driven state matches `target`, or times out.
    private func waitForSessionState(_ target: HKWorkoutSessionState) async {
        for _ in 0..<Self.stateWaitMaxAttempts {
            refreshSessionStateFromSession()
            if sessionState == target { return }
            try? await Task.sleep(nanoseconds: Self.statePollIntervalNanoseconds)
        }
        refreshSessionStateFromSession()
        if sessionState != target {
            NSLog("LiveWorkoutManager: timed out waiting for session state \(target.rawValue), have \(sessionState.rawValue)")
        }
    }

    /// Starts the live workout session, begins data collection, waits until **running**, then pauses and waits until **paused**
    /// so time between exercises does not count until `resumeWorkout()` runs on the exercise timer.
    func start(activityTypeName: String) async throws {
        let (session, builder) = try healthKitService.startLiveWorkout(activityTypeName: activityTypeName)
        self.session = session
        self.builder = builder

        session.delegate = self
        builder.delegate = self

        let now = Date()
        self.startDate = now
        self.isRunning = true
        sessionState = session.state

        session.startActivity(with: now)
        try await builder.beginCollection(at: now)

        // `pause()` only works once the session is actually running; otherwise it can be ignored.
        await waitForSessionState(.running)
        session.pause()
        appendWorkoutEvent(type: .pause)
        await waitForSessionState(.paused)

        timer?.invalidate()
        timer = nil
    }

    /// Resume the HealthKit session when the user enters an exercise timer screen.
    func resumeWorkout() async {
        guard let session else { return }
        refreshSessionStateFromSession()
        if sessionState == .running {
            startElapsedTimerIfRunning()
            return
        }
        if sessionState == .paused {
            session.resume()
            appendWorkoutEvent(type: .resume)
            await waitForSessionState(.running)
        }
        startElapsedTimerIfRunning()
    }

    /// Pause the HealthKit session when the user returns to the exercise list (finished or cancelled a set).
    func pauseWorkout() async {
        guard let session else { return }
        timer?.invalidate()
        timer = nil

        refreshSessionStateFromSession()
        if sessionState == .paused { return }
        if sessionState == .running {
            session.pause()
            appendWorkoutEvent(type: .pause)
            await waitForSessionState(.paused)
        }
    }

    private func startElapsedTimerIfRunning() {
        timer?.invalidate()
        timer = nil
        refreshSessionStateFromSession()
        guard sessionState == .running, let start = startDate else { return }

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in
                guard let self, let start = self.startDate else { return }
                self.elapsedSeconds = Int(Date().timeIntervalSince(start))
            }
        }
    }

    /// Ends the session and returns the start and end dates.
    /// `HKLiveWorkoutBuilder.finishWorkout()` saves the workout to HealthKit automatically —
    /// no manual `saveWorkout()` call is needed after this.
    func stop() async throws -> (startDate: Date, endDate: Date) {
        timer?.invalidate()
        timer = nil
        isRunning = false

        let end = Date()
        refreshSessionStateFromSession()
        if let session, sessionState == .paused {
            session.resume()
            appendWorkoutEvent(type: .resume)
            await waitForSessionState(.running)
        }
        session?.end()
        try await builder?.endCollection(at: end)
        try await builder?.finishWorkout()

        return (startDate ?? end, end)
    }

    /// Ends the session without saving to HealthKit. Use when the user cancels or completes no exercises.
    func endWithoutSaving() async throws {
        timer?.invalidate()
        timer = nil
        isRunning = false

        let end = Date()
        refreshSessionStateFromSession()
        if let session, sessionState == .paused {
            session.resume()
            appendWorkoutEvent(type: .resume)
            await waitForSessionState(.running)
        }
        session?.end()
        try await builder?.endCollection(at: end)
        // Do not call finishWorkout() — workout is not written to HealthKit
    }
}

extension LiveWorkoutManager: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilder(
        _ workoutBuilder: HKLiveWorkoutBuilder,
        didCollectDataOf collectedTypes: Set<HKSampleType>
    ) {
        for type in collectedTypes {
            guard let quantityType = type as? HKQuantityType else { continue }
            let stats = workoutBuilder.statistics(for: quantityType)

            Task { @MainActor in
                switch quantityType {
                case HKQuantityType(.heartRate):
                    self.heartRate = stats?.mostRecentQuantity()?
                        .doubleValue(for: .count().unitDivided(by: .minute())) ?? 0
                case HKQuantityType(.activeEnergyBurned):
                    self.activeCalories = stats?.sumQuantity()?
                        .doubleValue(for: .kilocalorie()) ?? 0
                case HKQuantityType(.basalEnergyBurned):
                    self.basalCalories = stats?.sumQuantity()?
                        .doubleValue(for: .kilocalorie()) ?? 0
                default:
                    break
                }
            }
        }
    }

    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}
}

extension LiveWorkoutManager: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(
        _ session: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {
        Task { @MainActor in
            self.sessionState = toState
        }
    }

    nonisolated func workoutSession(
        _ session: HKWorkoutSession,
        didFailWithError error: Error
    ) {}
}
#endif
