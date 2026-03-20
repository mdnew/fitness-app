import SwiftUI
import WatchConnectivity

@main
struct FitnessWatchAppApp: App {
    @StateObject private var store = AppStore()
    @StateObject private var workoutSender = WatchWorkoutSender()

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environmentObject(store)
                .environmentObject(workoutSender)
                .task {
                    let service = HealthKitService()
                    try? await service.requestAuthorization()
                }
        }
    }
}

private enum WatchTrackPhase {
    case chooseActivity
    case targetBodyParts
    case chooseExercise
    case exerciseTimer
}

private struct WatchRootView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var workoutSender: WatchWorkoutSender
    @StateObject private var liveWorkout = LiveWorkoutManager()

    @State private var phase: WatchTrackPhase = .chooseActivity
    @State private var selectedActivityType: String = "Traditional Strength Training"
    @State private var selectedBodyParts: Set<ExerciseBodyArea> = []
    @State private var selectedLocationID: UUID?
    @State private var selectedDurationMinutes: Int = 20
    @State private var suggestedExercises: [ExerciseLibraryItem] = []
    @State private var activeExercise: ExerciseLibraryItem?
    @State private var totalExerciseDuration: TimeInterval = 0
    @State private var hasActiveWorkout: Bool = false
    @State private var completedExercises: [WatchCompletedExercise] = []
    @State private var isShowingOtherExercisePicker = false

    var body: some View {
        Group {
            switch phase {
            case .chooseActivity:
            VStack(spacing: 0) {
                ChooseActivityView(
                    onSelectStrength: {
                        beginConfiguration(for: "Traditional Strength Training")
                    },
                    onSelectCore: {
                        beginConfiguration(for: "Core Training")
                    },
                    onSelectFlexibility: {
                        beginConfiguration(for: "Flexibility")
                    }
                )
                .frame(maxHeight: .infinity)

                if workoutSender.pendingWorkoutCount > 0 {
                    UnsyncedWorkoutsBar(
                        count: workoutSender.pendingWorkoutCount,
                        onRetry: { workoutSender.retrySyncing() }
                    )
                }
            }

        case .targetBodyParts:
            TargetBodyPartsView(
                activityType: selectedActivityType,
                selectedBodyParts: $selectedBodyParts,
                allowedBodyParts: allowedTrainingBodyAreas(for: selectedActivityType),
                locations: store.locations,
                selectedLocationID: $selectedLocationID,
                selectedDurationMinutes: $selectedDurationMinutes,
                onContinue: {
                    loadSuggestedExercises()
                    phase = .chooseExercise
                },
                onCancel: {
                    resetToStart()
                }
            )

        case .chooseExercise:
            ChooseExerciseView(
                activityType: selectedActivityType,
                exercises: suggestedExercises,
                completedExerciseTitles: Set(completedExercises.map(\.title)),
                totalExerciseDuration: totalExerciseDuration,
                onSelectExercise: { exercise in
                    activeExercise = exercise
                    if !hasActiveWorkout {
                        hasActiveWorkout = true
                        try? liveWorkout.start(activityTypeName: selectedActivityType)
                    }
                    phase = .exerciseTimer
                },
                onTapOther: { isShowingOtherExercisePicker = true },
                onFinish: {
                    guard hasActiveWorkout else {
                        resetToStart()
                        return
                    }
                    Task {
                        if completedExercises.isEmpty {
                            try? await liveWorkout.endWithoutSaving()
                        } else {
                            let (start, end) = (try? await liveWorkout.stop()) ?? (Date(), Date())
                            workoutSender.sendWorkout(
                                activityType: selectedActivityType,
                                completedAt: end,
                                durationSeconds: end.timeIntervalSince(start),
                                exercises: completedExercises
                            )
                        }
                        resetToStart()
                    }
                },
                onCancel: {
                    guard hasActiveWorkout else {
                        resetToStart()
                        return
                    }
                    Task {
                        try? await liveWorkout.endWithoutSaving()
                        resetToStart()
                    }
                }
            )
            .sheet(isPresented: $isShowingOtherExercisePicker) {
                WatchOtherExercisePicker(
                    exercises: otherExercisesForCurrentActivity,
                    onSelect: { exercise in
                        suggestedExercises.append(exercise)
                        isShowingOtherExercisePicker = false
                    },
                    onCancel: { isShowingOtherExercisePicker = false }
                )
            }

        case .exerciseTimer:
            if let exercise = activeExercise {
                ExerciseTimerView(
                    exerciseTitle: exercise.name,
                    heartRate: liveWorkout.heartRate,
                    activeCalories: liveWorkout.activeCalories,
                    totalCalories: liveWorkout.totalCalories,
                    onFinish: { elapsed in
                        completedExercises.append(WatchCompletedExercise(title: exercise.name, durationSeconds: elapsed))
                        totalExerciseDuration += elapsed
                        phase = .chooseExercise
                    },
                    onCancel: {
                        phase = .chooseExercise
                    }
                )
            } else {
                // Safety fallback – show chooser again.
                ChooseActivityView(
                    onSelectStrength: {
                        beginConfiguration(for: "Traditional Strength Training")
                    },
                    onSelectCore: {
                        beginConfiguration(for: "Core Training")
                    },
                    onSelectFlexibility: {
                        beginConfiguration(for: "Flexibility")
                    }
                )
            }
        }
        }
        .onAppear {
            workoutSender.setStore(store)
        }
    }

    private func beginConfiguration(for activityType: String) {
        selectedActivityType = activityType
        let defaultAreas = defaultBodyParts(for: activityType)
        selectedBodyParts = Set(defaultAreas)
        if selectedLocationID == nil, let firstLocation = store.locations.first {
            selectedLocationID = firstLocation.id
        }
        phase = .targetBodyParts
    }

    private func loadSuggestedExercises() {
        let normalized = selectedActivityType.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized == "flexibility" {
            suggestedExercises = store.recommendedStretches(durationMinutes: selectedDurationMinutes, focusAreas: Array(selectedBodyParts))
            return
        }

        let areas = Array(selectedBodyParts)
        guard !areas.isEmpty else {
            suggestedExercises = []
            return
        }

        let temporaryRoutine = RoutineActivity(
            id: UUID(),
            title: selectedActivityType,
            activityType: selectedActivityType,
            focusAreas: areas,
            scheduledWeekdays: [],
            defaultLocationID: nil,
            defaultDurationMinutes: nil,
            bodyPartSchedules: [],
            isTrainingTemplate: false
        )

        suggestedExercises = store.recommendedExercises(
            for: temporaryRoutine,
            targetDate: .now,
            locationID: selectedLocationID,
            desiredCount: 6,
            priorPlannedExerciseTitles: []
        )
    }

    private func resetToStart() {
        activeExercise = nil
        suggestedExercises = []
        selectedBodyParts.removeAll()
        totalExerciseDuration = 0
        hasActiveWorkout = false
        completedExercises = []
        phase = .chooseActivity
    }

    private func defaultBodyParts(for activityType: String) -> [ExerciseBodyArea] {
        let today = store.weekday(for: .now)
        if let template = trainingTemplate(for: activityType) {
            let scheduled = template.bodyPartSchedules
                .filter { $0.weekdays.contains(today) }
                .map(\.bodyPart)
            if !scheduled.isEmpty {
                return scheduled
            }
        }
        return allowedTrainingBodyAreas(for: activityType)
    }

    private func trainingTemplate(for activityType: String) -> RoutineActivity? {
        store.routineActivities.first {
            $0.isTrainingTemplate &&
            $0.activityType.trimmingCharacters(in: .whitespacesAndNewlines)
                .caseInsensitiveCompare(activityType) == .orderedSame
        }
    }

    private func allowedTrainingBodyAreas(for activityType: String) -> [ExerciseBodyArea] {
        let normalized = activityType.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized == "flexibility" {
            return AppStore.flexibilityBodyAreas
        }
        if normalized == "core training" {
            return [.glutes, .abs]
        }
        return ExerciseBodyArea.allCases.filter { area in
            area != .glutes && area != .abs
        }
    }

    private var otherExercisesForCurrentActivity: [ExerciseLibraryItem] {
        let normalized = selectedActivityType.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized == "flexibility" {
            let inList = Set(suggestedExercises.map(\.id))
            return store.stretchExercises.filter { !inList.contains($0.id) }
        }
        return otherExercisesForBodyParts
    }

    private var otherExercisesForBodyParts: [ExerciseLibraryItem] {
        let areas = Set(selectedBodyParts)
        guard !areas.isEmpty else { return store.exerciseLibrary }
        return store.exerciseLibrary.filter { exercise in
            !Set(exercise.primaryMuscles).isDisjoint(with: areas)
        }
    }

}

// MARK: - Subviews

private struct ChooseActivityView: View {
    let onSelectStrength: () -> Void
    let onSelectCore: () -> Void
    let onSelectFlexibility: () -> Void

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 12) {
                Text("Training Day")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)

                Text("Choose an Activity")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)

                Divider()
                    .frame(maxWidth: .infinity)

                VStack(spacing: 8) {
                    Button(action: onSelectStrength) {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.blue)
                            .overlay(
                                HStack {
                                    Image(systemName: "figure.strengthtraining.traditional")
                                        .font(.body)
                                    Text("Strength Training")
                                        .font(.callout.weight(.semibold))
                                }
                                .foregroundStyle(.white)
                                .padding(.vertical, 14)
                                .padding(.horizontal, 6)
                            )
                            .frame(height: 56)
                    }
                    .buttonStyle(.plain)

                    Button(action: onSelectCore) {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.blue)
                            .overlay(
                                HStack {
                                    Image(systemName: "figure.core.training")
                                        .font(.body)
                                    Text("Core Training")
                                        .font(.callout.weight(.semibold))
                                }
                                .foregroundStyle(.white)
                                .padding(.vertical, 14)
                                .padding(.horizontal, 6)
                            )
                            .frame(height: 56)
                    }
                    .buttonStyle(.plain)

                    Button(action: onSelectFlexibility) {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.blue)
                            .overlay(
                                HStack {
                                    Image(systemName: "figure.flexibility")
                                        .font(.body)
                                    Text("Flexibility")
                                        .font(.callout.weight(.semibold))
                                }
                                .foregroundStyle(.white)
                                .padding(.vertical, 14)
                                .padding(.horizontal, 6)
                            )
                            .frame(height: 56)
                    }
                    .buttonStyle(.plain)
                }

                Color.clear
                    .frame(height: 8)
            }
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 8)
        }
    }
}

private struct TargetBodyPartsView: View {
    let activityType: String
    @Binding var selectedBodyParts: Set<ExerciseBodyArea>
    let allowedBodyParts: [ExerciseBodyArea]
    let locations: [LocationItem]
    @Binding var selectedLocationID: UUID?
    @Binding var selectedDurationMinutes: Int
    let onContinue: () -> Void
    let onCancel: () -> Void

    var body: some View {
        List {
            if !allowedBodyParts.isEmpty {
                Section("Target Body Parts") {
                    ForEach(allowedBodyParts) { area in
                    Toggle(
                        area.title,
                        isOn: Binding(
                            get: { selectedBodyParts.contains(area) },
                            set: { isOn in
                                if isOn {
                                    selectedBodyParts.insert(area)
                                } else {
                                    selectedBodyParts.remove(area)
                                }
                            }
                        )
                    )
                }
            }
            }

            if !locations.isEmpty || allowedBodyParts.isEmpty {
                if !locations.isEmpty {
                    Section {
                        Picker("Location", selection: $selectedLocationID) {
                            ForEach(locations) { location in
                                Text(location.name).tag(Optional(location.id))
                            }
                        }

                        Picker("Duration", selection: $selectedDurationMinutes) {
                            ForEach([10, 15, 20, 30, 45], id: \.self) { minutes in
                                Text("\(minutes) min").tag(minutes)
                            }
                        }
                    }
                } else {
                    Section("Duration") {
                        Picker("Duration", selection: $selectedDurationMinutes) {
                            ForEach([10, 15, 20, 30, 45], id: \.self) { minutes in
                                Text("\(minutes) min").tag(minutes)
                            }
                        }
                    }
                }

                Section {
                    VStack(spacing: 6) {
                        Button("Continue", action: onContinue)
                            .buttonStyle(.borderedProminent)
                            .tint(.blue)

                        Button("Cancel", action: onCancel)
                            .buttonStyle(.bordered)
                    }
                }
            }
        }
    }
}

private let watchAccent = Color.gray

private struct ChooseExerciseRowLabel: View {
    let title: String
    let isDone: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(isDone ? Color.clear : watchAccent.opacity(0.3))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(watchAccent, lineWidth: isDone ? 2 : 0)
            )
            .overlay(
                HStack {
                    Text(title)
                        .font(.caption.weight(.semibold))
                        .multilineTextAlignment(.leading)
                        .foregroundStyle(isDone ? Color.primary : Color.white)
                    Spacer()
                    if isDone {
                        Image(systemName: "checkmark")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(watchAccent)
                    }
                }
                .padding(10)
            )
            .frame(height: 52)
    }
}

private struct ChooseExerciseView: View {
    let activityType: String
    let exercises: [ExerciseLibraryItem]
    let completedExerciseTitles: Set<String>
    let totalExerciseDuration: TimeInterval
    let onSelectExercise: (ExerciseLibraryItem) -> Void
    let onTapOther: () -> Void
    let onFinish: () -> Void
    let onCancel: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text(activityType.uppercased())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.blue)

                Text("Choose an Exercise")
                    .font(.headline)

                HStack(spacing: 4) {
                    Text("Total time")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(formattedTime(from: totalExerciseDuration))
                        .font(.system(.body, design: .monospaced).weight(.semibold))
                }

                Divider()

                VStack(spacing: 8) {
                    ForEach(exercises, id: \.id) { exercise in
                        Button {
                            onSelectExercise(exercise)
                        } label: {
                            ChooseExerciseRowLabel(
                                title: exercise.name,
                                isDone: completedExerciseTitles.contains(exercise.name)
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    Button(action: onTapOther) {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(watchAccent.opacity(0.3))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(watchAccent, lineWidth: 0)
                            )
                            .overlay(
                                HStack {
                                    Text("Other")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(Color.white)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(Color.white)
                                }
                                .padding(10)
                            )
                            .frame(height: 52)
                    }
                    .buttonStyle(.plain)
                }

                Spacer(minLength: 4)

                VStack(spacing: 6) {
                    Button("Finish", action: onFinish)
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)

                    Button("Cancel", action: onCancel)
                        .buttonStyle(.bordered)
                }
            }
            .padding()
        }
    }

    private func formattedTime(from interval: TimeInterval) -> String {
        let totalHundredths = Int((interval * 100).rounded())
        let hundredths = totalHundredths % 100
        let totalSeconds = max(totalHundredths / 100, 0)
        let seconds = totalSeconds % 60
        let minutes = (totalSeconds / 60) % 60
        let hours = totalSeconds / 3600
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d.%02d", minutes, seconds, hundredths)
        }
    }
}

private struct WatchOtherExercisePicker: View {
    let exercises: [ExerciseLibraryItem]
    let onSelect: (ExerciseLibraryItem) -> Void
    let onCancel: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text("OTHER")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.blue)
                Text("Choose an exercise from your catalog")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Divider()

                VStack(spacing: 8) {
                    ForEach(exercises, id: \.id) { exercise in
                        Button {
                            onSelect(exercise)
                        } label: {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(watchAccent.opacity(0.3))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .strokeBorder(watchAccent, lineWidth: 0)
                                )
                                .overlay(
                                    HStack {
                                        Text(exercise.name)
                                            .font(.caption.weight(.semibold))
                                            .multilineTextAlignment(.leading)
                                            .foregroundStyle(Color.white)
                                        Spacer()
                                    }
                                    .padding(10)
                                )
                                .frame(height: 52)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Spacer(minLength: 8)

                Button("Cancel", action: onCancel)
                    .buttonStyle(.bordered)
            }
            .padding()
        }
    }
}

private struct ExerciseTimerView: View {
    let exerciseTitle: String
    let heartRate: Double
    let activeCalories: Double
    let totalCalories: Double
    let onFinish: (TimeInterval) -> Void
    let onCancel: () -> Void

    @State private var startDate = Date()

    var body: some View {
        let active = max(Int(activeCalories.rounded()), 0)
        let total = max(Int(totalCalories.rounded()), 0)

        return ScrollView {
            VStack(spacing: 10) {
                TimelineView(.periodic(from: startDate, by: 0.1)) { context in
                    let elapsed = context.date.timeIntervalSince(startDate)
                    Text(formattedTime(from: max(0, elapsed)))
                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                        .foregroundStyle(.yellow)
                }

                Text(exerciseTitle)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                HStack(spacing: 24) {
                    VStack(spacing: 2) {
                        Text("\(active)")
                            .font(.system(.title3, design: .monospaced).weight(.semibold))
                        Text("ACTIVE CAL")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    VStack(spacing: 2) {
                        Text("\(total)")
                            .font(.system(.title3, design: .monospaced).weight(.semibold))
                        Text("TOTAL CAL")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 6) {
                    Text(heartRate > 0 ? "\(Int(heartRate))" : "--")
                        .font(.system(.title3, design: .monospaced).weight(.semibold))
                    Image(systemName: "heart.fill")
                        .foregroundStyle(.red)
                }
                .frame(maxWidth: .infinity)

                Button("Finish") {
                    let elapsed = Date().timeIntervalSince(startDate)
                    onFinish(max(elapsed, 0))
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)

                Button("Cancel", action: onCancel)
                    .buttonStyle(.bordered)
            }
            .padding()
        }
    }

    private func formattedTime(from interval: TimeInterval) -> String {
        let totalHundredths = Int((interval * 100).rounded())
        let hundredths = totalHundredths % 100
        let totalSeconds = totalHundredths / 100
        let seconds = totalSeconds % 60
        let minutes = (totalSeconds / 60) % 60
        let hours = totalSeconds / 3600
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d.%02d", minutes, seconds, hundredths)
        }
    }
}

// MARK: - Unsynced workouts bar

private struct UnsyncedWorkoutsBar: View {
    let count: Int
    let onRetry: () -> Void

    var body: some View {
        Button(action: onRetry) {
            HStack(spacing: 4) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.caption2)
                Text(count == 1 ? "1 workout waiting to sync" : "\(count) workouts waiting to sync")
                    .font(.caption2)
                    .lineLimit(1)
            }
            .foregroundStyle(.secondary)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .background(Color.gray.opacity(0.25))
    }
}

// MARK: - Watch → Phone workout transfer

private struct WatchCompletedExercise: Codable {
    let title: String
    let durationSeconds: TimeInterval
}

private enum WatchWorkoutPayload {
    static let key = "watchWorkout"
    static let id = "id"
    static let activityType = "activityType"
    static let completedAtTimestamp = "completedAtTimestamp"
    static let durationSeconds = "durationSeconds"
    static let exercises = "exercises"
}

private enum WatchWorkoutAck {
    static let key = "watchWorkoutAck"
}

private struct PendingWorkoutToSend: Codable {
    var id: String
    var activityType: String
    var completedAtTimestamp: TimeInterval
    var durationSeconds: TimeInterval
    var exercises: [WatchCompletedExercise]

    init(id: String, activityType: String, completedAtTimestamp: TimeInterval, durationSeconds: TimeInterval, exercises: [WatchCompletedExercise] = []) {
        self.id = id
        self.activityType = activityType
        self.completedAtTimestamp = completedAtTimestamp
        self.durationSeconds = durationSeconds
        self.exercises = exercises
    }

    enum CodingKeys: String, CodingKey {
        case id, activityType, completedAtTimestamp, durationSeconds, exercises
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        activityType = try c.decode(String.self, forKey: .activityType)
        completedAtTimestamp = try c.decode(TimeInterval.self, forKey: .completedAtTimestamp)
        durationSeconds = try c.decode(TimeInterval.self, forKey: .durationSeconds)
        exercises = try c.decodeIfPresent([WatchCompletedExercise].self, forKey: .exercises) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(activityType, forKey: .activityType)
        try c.encode(completedAtTimestamp, forKey: .completedAtTimestamp)
        try c.encode(durationSeconds, forKey: .durationSeconds)
        try c.encode(exercises, forKey: .exercises)
    }
}

private enum PendingWorkoutsStore {
    static let userDefaultsKey = "fitness.pendingWatchWorkouts"

    static func load() -> [PendingWorkoutToSend] {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else { return [] }
        return (try? JSONDecoder().decode([PendingWorkoutToSend].self, from: data)) ?? []
    }

    static func save(_ pending: [PendingWorkoutToSend]) {
        guard let data = try? JSONEncoder().encode(pending) else { return }
        UserDefaults.standard.set(data, forKey: userDefaultsKey)
    }
}

@MainActor
final class WatchWorkoutSender: NSObject, ObservableObject {
    @Published private(set) var pendingWorkoutCount: Int = 0
    weak var store: AppStore?

    /// Call once when the Watch app has the store (e.g. from root view .onAppear) so received snapshots can be applied.
    func setStore(_ store: AppStore) {
        self.store = store
        if WCSession.default.activationState == .activated {
            applyReceivedContext(WCSession.default.receivedApplicationContext)
        }
    }

    override init() {
        super.init()
        pendingWorkoutCount = PendingWorkoutsStore.load().count
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    /// Sends workout data to the phone; the phone saves it to HealthKit. Persists for retry if transfer fails.
    fileprivate func sendWorkout(activityType: String, completedAt: Date, durationSeconds: TimeInterval, exercises: [WatchCompletedExercise] = []) {
        let id = UUID().uuidString
        let item = PendingWorkoutToSend(
            id: id,
            activityType: activityType,
            completedAtTimestamp: completedAt.timeIntervalSince1970,
            durationSeconds: durationSeconds,
            exercises: exercises
        )
        var pending = PendingWorkoutsStore.load()
        pending.append(item)
        PendingWorkoutsStore.save(pending)
        pendingWorkoutCount = pending.count
        sendPayload(for: item)
    }

    /// Resend all pending workouts to the phone (e.g. after transfer failed or user taps retry).
    func retrySyncing() {
        resendPendingWorkouts()
    }

    private func sendPayload(for item: PendingWorkoutToSend) {
        guard WCSession.default.activationState == .activated else { return }
        var payload: [String: Any] = [
            WatchWorkoutPayload.id: item.id,
            WatchWorkoutPayload.activityType: item.activityType,
            WatchWorkoutPayload.completedAtTimestamp: item.completedAtTimestamp,
            WatchWorkoutPayload.durationSeconds: item.durationSeconds
        ]
        let exerciseDicts = item.exercises.map { ["title": $0.title, "durationSeconds": $0.durationSeconds] as [String: Any] }
        payload[WatchWorkoutPayload.exercises] = exerciseDicts
        WCSession.default.transferUserInfo([WatchWorkoutPayload.key: payload])
    }

    private func resendPendingWorkouts() {
        let pending = PendingWorkoutsStore.load()
        for item in pending {
            sendPayload(for: item)
        }
    }

    private func removePending(ackId: String) {
        var pending = PendingWorkoutsStore.load()
        pending.removeAll { $0.id == ackId }
        PendingWorkoutsStore.save(pending)
        pendingWorkoutCount = pending.count
    }
}

extension WatchWorkoutSender: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        guard activationState == .activated else { return }
        let snapshotData = session.receivedApplicationContext["snapshot"] as? Data
        Task { @MainActor [weak self] in
            self?.resendPendingWorkouts()
            self?.applyReceivedSnapshotData(snapshotData)
        }
    }

    nonisolated(unsafe) func session(
        _ session: WCSession,
        didReceiveUserInfo userInfo: [String: Any] = [:]
    ) {
        guard let ackId = userInfo[WatchWorkoutAck.key] as? String else { return }
        Task { @MainActor [weak self] in
            self?.removePending(ackId: ackId)
        }
    }

    nonisolated(unsafe) func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        let snapshotData = applicationContext["snapshot"] as? Data
        Task { @MainActor [weak self] in
            self?.applyReceivedSnapshotData(snapshotData)
        }
    }

    private func applyReceivedContext(_ applicationContext: [String: Any]) {
        let data = applicationContext["snapshot"] as? Data
        applyReceivedSnapshotData(data)
    }

    private func applyReceivedSnapshotData(_ data: Data?) {
        guard let data,
              let snapshot = try? JSONDecoder().decode(AppSnapshot.self, from: data) else { return }
        store?.apply(snapshot: snapshot)
    }
}
