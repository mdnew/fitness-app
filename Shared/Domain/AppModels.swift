import Foundation
import SwiftUI

enum GoalSourceKind: String, CaseIterable, Codable {
    case event
    case recurringActivity
}

enum GoalEmphasis: String, CaseIterable, Codable {
    case maintain
    case improve
}

enum HealthSyncState: Equatable {
    case notConnected
    case connected
    case refreshing
    case refreshed(Date)
    case failed(String)

    var title: String {
        switch self {
        case .notConnected:
            "Not Connected"
        case .connected:
            "Connected"
        case .refreshing:
            "Refreshing"
        case let .refreshed(date):
            "Updated \(date.formatted(date: .abbreviated, time: .shortened))"
        case let .failed(message):
            "Failed: \(message)"
        }
    }
}

enum Weekday: Int, CaseIterable, Codable, Identifiable {
    case monday = 1
    case tuesday
    case wednesday
    case thursday
    case friday
    case saturday
    case sunday

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .monday: "Monday"
        case .tuesday: "Tuesday"
        case .wednesday: "Wednesday"
        case .thursday: "Thursday"
        case .friday: "Friday"
        case .saturday: "Saturday"
        case .sunday: "Sunday"
        }
    }
}

struct EventItem: Identifiable, Hashable, Codable {
    let id: UUID
    var title: String
    var eventType: String
    var targetDate: Date
    var notes: String
}

struct RecurringActivityItem: Identifiable, Hashable, Codable {
    let id: UUID
    var activityType: String
    var emphasis: GoalEmphasis
    var isDetectedFromHealth: Bool
}

struct PlannedActivityItem: Identifiable, Hashable, Codable {
    let id: UUID
    var activityType: String
    var date: Date
}

struct GoalItem: Identifiable, Hashable, Codable {
    let id: UUID
    var title: String
    var sourceKind: GoalSourceKind
    var emphasis: GoalEmphasis?
}

struct EquipmentItem: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
}

struct LocationItem: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var equipmentSummary: String
    var equipmentIDs: [UUID]

    init(
        id: UUID,
        name: String,
        equipmentSummary: String,
        equipmentIDs: [UUID] = []
    ) {
        self.id = id
        self.name = name
        self.equipmentSummary = equipmentSummary
        self.equipmentIDs = equipmentIDs
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        equipmentSummary = try container.decode(String.self, forKey: .equipmentSummary)
        equipmentIDs = try container.decodeIfPresent([UUID].self, forKey: .equipmentIDs) ?? []
    }
}

enum ExerciseBodyArea: String, CaseIterable, Codable, Identifiable {
    case chest
    case back
    case shoulders
    case biceps
    case triceps
    case legs
    case glutes
    case abs

    var id: String { rawValue }

    var title: String {
        switch self {
        case .chest: "Chest"
        case .back: "Back"
        case .shoulders: "Shoulders"
        case .biceps: "Biceps"
        case .triceps: "Triceps"
        case .legs: "Legs"
        case .glutes: "Glutes"
        case .abs: "Abs"
        }
    }

    static func fromLegacy(_ value: String) -> ExerciseBodyArea? {
        switch value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "-", with: " ")
        {
        case "chest":
            .chest
        case "back", "upper back", "mid back", "lats", "rear delts", "traps", "grip":
            .back
        case "shoulders", "delts":
            .shoulders
        case "biceps":
            .biceps
        case "triceps":
            .triceps
        case "legs", "lower body", "quads", "hamstrings", "calves", "single leg":
            .legs
        case "glutes":
            .glutes
        case "abs", "core", "obliques", "hip flexors":
            .abs
        default:
            nil
        }
    }
}

struct RoutineDay: Identifiable, Hashable, Codable {
    let id: UUID
    var weekday: Weekday
    var focusAreas: [ExerciseBodyArea]
    var defaultLocationID: UUID?
    var defaultDurationMinutes: Int?

    var focusSummary: String {
        guard !focusAreas.isEmpty else { return "" }
        return focusAreas.map(\.title).joined(separator: ", ")
    }

    init(
        id: UUID,
        weekday: Weekday,
        focusAreas: [ExerciseBodyArea],
        defaultLocationID: UUID?,
        defaultDurationMinutes: Int?
    ) {
        self.id = id
        self.weekday = weekday
        self.focusAreas = focusAreas
        self.defaultLocationID = defaultLocationID
        self.defaultDurationMinutes = defaultDurationMinutes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        weekday = try container.decode(Weekday.self, forKey: .weekday)
        defaultLocationID = try container.decodeIfPresent(UUID.self, forKey: .defaultLocationID)
        defaultDurationMinutes = try container.decodeIfPresent(Int.self, forKey: .defaultDurationMinutes)

        if let decodedAreas = try container.decodeIfPresent([ExerciseBodyArea].self, forKey: .focusAreas) {
            focusAreas = decodedAreas
        } else {
            let legacyContainer = try decoder.container(keyedBy: LegacyCodingKeys.self)
            let legacyFocus = try legacyContainer.decodeIfPresent(String.self, forKey: .focus) ?? ""
            focusAreas = Self.legacyFocusAreas(from: legacyFocus)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case weekday
        case focusAreas
        case defaultLocationID
        case defaultDurationMinutes
    }

    private enum LegacyCodingKeys: String, CodingKey {
        case focus
    }

    private static func legacyFocusAreas(from focus: String) -> [ExerciseBodyArea] {
        let normalized = focus.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch normalized {
        case "lower body":
            return [.legs, .glutes, .abs]
        case "upper body":
            return [.chest, .back, .shoulders, .biceps, .triceps]
        case "full body":
            return [.chest, .back, .shoulders, .biceps, .triceps, .legs, .glutes, .abs]
        default:
            let parsed = normalized
                .split(separator: ",")
                .compactMap { ExerciseBodyArea.fromLegacy(String($0)) }
            return parsed
        }
    }
}

struct RoutineActivity: Identifiable, Hashable, Codable {
    let id: UUID
    var title: String
    var activityType: String
    var focusAreas: [ExerciseBodyArea]
    var scheduledWeekdays: [Weekday]
    var defaultLocationID: UUID?
    var defaultDurationMinutes: Int?
    var bodyPartSchedules: [BodyPartSchedulePreference]
    var isTrainingTemplate: Bool

    var focusSummary: String {
        guard !focusAreas.isEmpty else { return "" }
        return focusAreas.map(\.title).joined(separator: ", ")
    }

    var scheduleSummary: String {
        let weekdayTitles = scheduledWeekdays
            .sorted { $0.rawValue < $1.rawValue }
            .map(\.title)
        return weekdayTitles.joined(separator: ", ")
    }

    init(
        id: UUID,
        title: String,
        activityType: String,
        focusAreas: [ExerciseBodyArea],
        scheduledWeekdays: [Weekday],
        defaultLocationID: UUID?,
        defaultDurationMinutes: Int?,
        bodyPartSchedules: [BodyPartSchedulePreference] = [],
        isTrainingTemplate: Bool = false
    ) {
        self.id = id
        self.title = title
        self.activityType = activityType
        self.focusAreas = focusAreas
        self.scheduledWeekdays = scheduledWeekdays
        self.defaultLocationID = defaultLocationID
        self.defaultDurationMinutes = defaultDurationMinutes
        self.bodyPartSchedules = bodyPartSchedules
        self.isTrainingTemplate = isTrainingTemplate
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        activityType = try container.decodeIfPresent(String.self, forKey: .activityType) ?? "Traditional Strength Training"
        focusAreas = try container.decode([ExerciseBodyArea].self, forKey: .focusAreas)
        scheduledWeekdays = try container.decode([Weekday].self, forKey: .scheduledWeekdays)
        defaultLocationID = try container.decodeIfPresent(UUID.self, forKey: .defaultLocationID)
        defaultDurationMinutes = try container.decodeIfPresent(Int.self, forKey: .defaultDurationMinutes)
        bodyPartSchedules = try container.decodeIfPresent([BodyPartSchedulePreference].self, forKey: .bodyPartSchedules) ?? []
        isTrainingTemplate = try container.decodeIfPresent(Bool.self, forKey: .isTrainingTemplate) ?? false
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case activityType
        case focusAreas
        case scheduledWeekdays
        case defaultLocationID
        case defaultDurationMinutes
        case bodyPartSchedules
        case isTrainingTemplate
    }
}

struct BodyPartSchedulePreference: Identifiable, Hashable, Codable {
    let id: UUID
    var bodyPart: ExerciseBodyArea
    var weekdays: [Weekday]

    init(id: UUID = UUID(), bodyPart: ExerciseBodyArea, weekdays: [Weekday]) {
        self.id = id
        self.bodyPart = bodyPart
        self.weekdays = weekdays
    }
}

struct ScheduledRoutineActivity: Identifiable, Hashable {
    let routineActivity: RoutineActivity
    let date: Date

    var id: String {
        "\(routineActivity.id.uuidString)-\(Calendar.current.startOfDay(for: date).timeIntervalSince1970)"
    }

    var title: String { routineActivity.title }
    var focusSummary: String { routineActivity.focusSummary }
    var locationID: UUID? { routineActivity.defaultLocationID }
    var durationMinutes: Int? { routineActivity.defaultDurationMinutes }
}

enum ExerciseMovementPattern: String, CaseIterable, Codable, Identifiable {
    case squat
    case hinge
    case horizontalPush
    case horizontalPull
    case verticalPush
    case verticalPull
    case singleLeg
    case carry
    case core

    var id: String { rawValue }

    var title: String {
        switch self {
        case .squat: "Squat"
        case .hinge: "Hinge"
        case .horizontalPush: "Horizontal Push"
        case .horizontalPull: "Horizontal Pull"
        case .verticalPush: "Vertical Push"
        case .verticalPull: "Vertical Pull"
        case .singleLeg: "Single Leg"
        case .carry: "Carry"
        case .core: "Core"
        }
    }
}

enum ExerciseEquipmentKind: String, CaseIterable, Codable, Identifiable {
    case bodyweight
    case dumbbells
    case barbell
    case cable
    case machine
    case bench
    case pullUpBar
    case kettlebell
    case trapBar
    case medicineBall

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bodyweight: "Bodyweight"
        case .dumbbells: "Dumbbells"
        case .barbell: "Barbell"
        case .cable: "Cable"
        case .machine: "Machine"
        case .bench: "Bench"
        case .pullUpBar: "Pull-Up Bar"
        case .kettlebell: "Kettlebell"
        case .trapBar: "Trap Bar"
        case .medicineBall: "Medicine Ball"
        }
    }
}

enum ExerciseSkillLevel: String, CaseIterable, Codable, Identifiable {
    case beginner
    case intermediate
    case advanced

    var id: String { rawValue }
}

enum ExerciseLibrarySourceKind: String, CaseIterable, Codable, Identifiable {
    case seeded
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .seeded: "Built In"
        case .custom: "Custom"
        }
    }
}

struct ExerciseLibraryItem: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var movementPattern: ExerciseMovementPattern
    var requiredEquipment: [ExerciseEquipmentKind]
    var primaryMuscles: [ExerciseBodyArea]
    var goalSupportTags: [String]
    var skillLevel: ExerciseSkillLevel
    var isUnilateral: Bool
    var notes: String
    var instructions: String
    var source: ExerciseLibrarySourceKind

    init(
        id: UUID,
        name: String,
        movementPattern: ExerciseMovementPattern,
        requiredEquipment: [ExerciseEquipmentKind],
        primaryMuscles: [ExerciseBodyArea],
        goalSupportTags: [String],
        skillLevel: ExerciseSkillLevel,
        isUnilateral: Bool,
        notes: String,
        instructions: String = "",
        source: ExerciseLibrarySourceKind
    ) {
        self.id = id
        self.name = name
        self.movementPattern = movementPattern
        self.requiredEquipment = requiredEquipment
        self.primaryMuscles = primaryMuscles
        self.goalSupportTags = goalSupportTags
        self.skillLevel = skillLevel
        self.isUnilateral = isUnilateral
        self.notes = notes
        self.instructions = instructions
        self.source = source
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        movementPattern = try container.decode(ExerciseMovementPattern.self, forKey: .movementPattern)
        requiredEquipment = try container.decode([ExerciseEquipmentKind].self, forKey: .requiredEquipment)
        if let decodedAreas = try container.decodeIfPresent([ExerciseBodyArea].self, forKey: .primaryMuscles) {
            primaryMuscles = decodedAreas
        } else {
            let legacyMuscles = try container.decodeIfPresent([String].self, forKey: .primaryMuscles) ?? []
            primaryMuscles = legacyMuscles.compactMap(ExerciseBodyArea.fromLegacy)
        }
        goalSupportTags = try container.decode([String].self, forKey: .goalSupportTags)
        skillLevel = try container.decode(ExerciseSkillLevel.self, forKey: .skillLevel)
        isUnilateral = try container.decode(Bool.self, forKey: .isUnilateral)
        notes = try container.decode(String.self, forKey: .notes)
        instructions = try container.decodeIfPresent(String.self, forKey: .instructions) ?? ""
        source = try container.decodeIfPresent(ExerciseLibrarySourceKind.self, forKey: .source) ?? .seeded
    }
}

struct PlannedExercise: Identifiable, Hashable, Codable {
    let id: UUID
    var title: String
    var reason: String
}

struct WorkoutPlan: Identifiable, Hashable, Codable {
    let id: UUID
    var summary: String
    var plannedDurationMinutes: Int
    var locationID: UUID?
    var exercises: [PlannedExercise]
}

struct TrackedExerciseState: Identifiable, Hashable, Codable {
    let id: UUID
    var plannedExercise: PlannedExercise
    var isCompleted: Bool
    /// Time spent on this exercise when completed (seconds). Nil if not completed or legacy.
    var completedDurationSeconds: TimeInterval? = nil
}

struct TrackedWorkoutSession: Identifiable, Hashable, Codable {
    let id: UUID
    var startedAt: Date
    var routineActivityID: UUID?
    var title: String
    var activityType: String
    var summary: String
    var plannedDurationMinutes: Int
    var locationID: UUID?
    var locationName: String
    var exercises: [TrackedExerciseState]

    init(
        id: UUID,
        startedAt: Date,
        routineActivityID: UUID?,
        title: String,
        activityType: String,
        summary: String,
        plannedDurationMinutes: Int,
        locationID: UUID?,
        locationName: String,
        exercises: [TrackedExerciseState]
    ) {
        self.id = id
        self.startedAt = startedAt
        self.routineActivityID = routineActivityID
        self.title = title
        self.activityType = activityType
        self.summary = summary
        self.plannedDurationMinutes = plannedDurationMinutes
        self.locationID = locationID
        self.locationName = locationName
        self.exercises = exercises
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        startedAt = try container.decode(Date.self, forKey: .startedAt)
        routineActivityID = try container.decodeIfPresent(UUID.self, forKey: .routineActivityID)
        title = try container.decode(String.self, forKey: .title)
        activityType = try container.decodeIfPresent(String.self, forKey: .activityType) ?? "Traditional Strength Training"
        summary = try container.decode(String.self, forKey: .summary)
        plannedDurationMinutes = try container.decode(Int.self, forKey: .plannedDurationMinutes)
        locationID = try container.decodeIfPresent(UUID.self, forKey: .locationID)
        locationName = try container.decode(String.self, forKey: .locationName)
        exercises = try container.decode([TrackedExerciseState].self, forKey: .exercises)
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case startedAt
        case routineActivityID
        case title
        case activityType
        case summary
        case plannedDurationMinutes
        case locationID
        case locationName
        case exercises
    }
}

struct PendingTrackedWorkoutMerge: Identifiable, Hashable, Codable {
    let id: UUID
    var startedAt: Date
    var completedAt: Date
    var durationMinutes: Int
    var locationName: String
    var activityType: String
    var summary: String
    var exerciseDetails: [CompletedExerciseDetail]
}

struct CompletedExerciseDetail: Identifiable, Hashable, Codable {
    let id: UUID
    var title: String
    var bodyPart: ExerciseBodyArea?
    var sets: Int?
    var reps: Int?
    var notes: String
}

struct CompletedWorkoutSummary: Identifiable, Hashable, Codable {
    let id: UUID
    var date: Date
    var durationMinutes: Int
    var locationName: String
    var activityType: String
    var summary: String
    var exerciseDetails: [CompletedExerciseDetail]

    init(
        id: UUID,
        date: Date,
        durationMinutes: Int,
        locationName: String,
        activityType: String,
        summary: String,
        exerciseDetails: [CompletedExerciseDetail] = []
    ) {
        self.id = id
        self.date = date
        self.durationMinutes = durationMinutes
        self.locationName = locationName
        self.activityType = activityType
        self.summary = summary
        self.exerciseDetails = exerciseDetails
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        date = try container.decode(Date.self, forKey: .date)
        durationMinutes = try container.decode(Int.self, forKey: .durationMinutes)
        locationName = try container.decode(String.self, forKey: .locationName)
        summary = try container.decode(String.self, forKey: .summary)
        activityType = try container.decodeIfPresent(String.self, forKey: .activityType) ?? summary
        exerciseDetails = try container.decodeIfPresent([CompletedExerciseDetail].self, forKey: .exerciseDetails) ?? []
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case date
        case durationMinutes
        case locationName
        case activityType
        case summary
        case exerciseDetails
    }
}

struct AppSnapshot: Codable {
    var events: [EventItem]
    var recurringActivities: [RecurringActivityItem]
    var plannedActivities: [PlannedActivityItem]
    var selectedFocusActivityType: String?
    var goals: [GoalItem]
    var equipmentCatalog: [EquipmentItem]
    var locations: [LocationItem]
    var routineActivities: [RoutineActivity]
    var exerciseLibrary: [ExerciseLibraryItem]
    var currentWorkout: WorkoutPlan
    var trackedWorkoutSession: TrackedWorkoutSession?
    var pendingTrackedWorkouts: [PendingTrackedWorkoutMerge]
    var history: [CompletedWorkoutSummary]

    init(
        events: [EventItem],
        recurringActivities: [RecurringActivityItem],
        plannedActivities: [PlannedActivityItem],
        selectedFocusActivityType: String?,
        goals: [GoalItem],
        equipmentCatalog: [EquipmentItem],
        locations: [LocationItem],
        routineActivities: [RoutineActivity],
        exerciseLibrary: [ExerciseLibraryItem],
        currentWorkout: WorkoutPlan,
        trackedWorkoutSession: TrackedWorkoutSession?,
        pendingTrackedWorkouts: [PendingTrackedWorkoutMerge],
        history: [CompletedWorkoutSummary]
    ) {
        self.events = events
        self.recurringActivities = recurringActivities
        self.plannedActivities = plannedActivities
        self.selectedFocusActivityType = selectedFocusActivityType
        self.goals = goals
        self.equipmentCatalog = equipmentCatalog
        self.locations = locations
        self.routineActivities = routineActivities
        self.exerciseLibrary = exerciseLibrary
        self.currentWorkout = currentWorkout
        self.trackedWorkoutSession = trackedWorkoutSession
        self.pendingTrackedWorkouts = pendingTrackedWorkouts
        self.history = history
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        events = try container.decode([EventItem].self, forKey: .events)
        recurringActivities = try container.decode([RecurringActivityItem].self, forKey: .recurringActivities)
        plannedActivities = try container.decodeIfPresent([PlannedActivityItem].self, forKey: .plannedActivities) ?? []
        selectedFocusActivityType = try container.decodeIfPresent(String.self, forKey: .selectedFocusActivityType)
        goals = try container.decode([GoalItem].self, forKey: .goals)
        equipmentCatalog = try container.decodeIfPresent([EquipmentItem].self, forKey: .equipmentCatalog) ?? []
        locations = try container.decode([LocationItem].self, forKey: .locations)
        if let decodedActivities = try container.decodeIfPresent([RoutineActivity].self, forKey: .routineActivities) {
            routineActivities = decodedActivities
        } else {
            let legacyRoutineDays = try container.decodeIfPresent([RoutineDay].self, forKey: .routineDays) ?? []
            routineActivities = legacyRoutineDays.map { routineDay in
                RoutineActivity(
                    id: routineDay.id,
                    title: routineDay.focusSummary,
                    activityType: "Traditional Strength Training",
                    focusAreas: routineDay.focusAreas,
                    scheduledWeekdays: [routineDay.weekday],
                    defaultLocationID: routineDay.defaultLocationID,
                    defaultDurationMinutes: routineDay.defaultDurationMinutes
                )
            }
        }
        exerciseLibrary = try container.decodeIfPresent([ExerciseLibraryItem].self, forKey: .exerciseLibrary) ?? []
        currentWorkout = try container.decode(WorkoutPlan.self, forKey: .currentWorkout)
        trackedWorkoutSession = try container.decodeIfPresent(TrackedWorkoutSession.self, forKey: .trackedWorkoutSession)
        pendingTrackedWorkouts = try container.decodeIfPresent([PendingTrackedWorkoutMerge].self, forKey: .pendingTrackedWorkouts) ?? []
        history = try container.decode([CompletedWorkoutSummary].self, forKey: .history)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(events, forKey: .events)
        try container.encode(recurringActivities, forKey: .recurringActivities)
        try container.encode(plannedActivities, forKey: .plannedActivities)
        try container.encodeIfPresent(selectedFocusActivityType, forKey: .selectedFocusActivityType)
        try container.encode(goals, forKey: .goals)
        try container.encode(equipmentCatalog, forKey: .equipmentCatalog)
        try container.encode(locations, forKey: .locations)
        try container.encode(routineActivities, forKey: .routineActivities)
        try container.encode(exerciseLibrary, forKey: .exerciseLibrary)
        try container.encode(currentWorkout, forKey: .currentWorkout)
        try container.encodeIfPresent(trackedWorkoutSession, forKey: .trackedWorkoutSession)
        try container.encode(pendingTrackedWorkouts, forKey: .pendingTrackedWorkouts)
        try container.encode(history, forKey: .history)
    }

    private enum CodingKeys: String, CodingKey {
        case events
        case recurringActivities
        case plannedActivities
        case selectedFocusActivityType
        case goals
        case equipmentCatalog
        case locations
        case routineActivities
        case routineDays
        case exerciseLibrary
        case currentWorkout
        case trackedWorkoutSession
        case pendingTrackedWorkouts
        case history
    }
}

@MainActor
final class AppStore: ObservableObject {
    @Published var events: [EventItem]
    @Published var recurringActivities: [RecurringActivityItem]
    @Published var plannedActivities: [PlannedActivityItem]
    @Published var selectedFocusActivityType: String?
    @Published var goals: [GoalItem]
    @Published var equipmentCatalog: [EquipmentItem]
    @Published var locations: [LocationItem]
    @Published var routineActivities: [RoutineActivity]
    @Published var exerciseLibrary: [ExerciseLibraryItem]
    @Published var currentWorkout: WorkoutPlan
    @Published var trackedWorkoutSession: TrackedWorkoutSession?
    @Published var pendingTrackedWorkouts: [PendingTrackedWorkoutMerge]
    @Published var history: [CompletedWorkoutSummary]
    /// Workouts older than 7 days; used when generating suggestion lists so recent workouts are not repeated.
    var historyExcludingLast7Days: [CompletedWorkoutSummary] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return history.filter { $0.date < cutoff }
    }
    @Published var healthSyncState: HealthSyncState = .notConnected
    @Published var futureActivitiesLastRegeneratedAt: Date?

    init() {
        let snapshot = Self.defaultSnapshot()
        events = snapshot.events
        recurringActivities = snapshot.recurringActivities
        plannedActivities = snapshot.plannedActivities
        selectedFocusActivityType = snapshot.selectedFocusActivityType
        goals = snapshot.goals
        equipmentCatalog = snapshot.equipmentCatalog
        locations = snapshot.locations
        routineActivities = snapshot.routineActivities
        exerciseLibrary = Self.mergedExerciseLibrary(from: snapshot.exerciseLibrary)
        currentWorkout = snapshot.currentWorkout
        trackedWorkoutSession = snapshot.trackedWorkoutSession
        pendingTrackedWorkouts = snapshot.pendingTrackedWorkouts
        history = snapshot.history
    }

    var snapshot: AppSnapshot {
        AppSnapshot(
            events: events,
            recurringActivities: recurringActivities,
            plannedActivities: plannedActivities,
            selectedFocusActivityType: selectedFocusActivityType,
            goals: goals,
            equipmentCatalog: equipmentCatalog,
            locations: locations,
            routineActivities: routineActivities,
            exerciseLibrary: exerciseLibrary,
            currentWorkout: currentWorkout,
            trackedWorkoutSession: trackedWorkoutSession,
            pendingTrackedWorkouts: pendingTrackedWorkouts,
            history: history
        )
    }

    func apply(snapshot: AppSnapshot) {
        events = snapshot.events
        recurringActivities = snapshot.recurringActivities
        plannedActivities = snapshot.plannedActivities
        selectedFocusActivityType = snapshot.selectedFocusActivityType
        goals = snapshot.goals
        equipmentCatalog = snapshot.equipmentCatalog.isEmpty ? Self.defaultEquipmentCatalog() : snapshot.equipmentCatalog
        locations = snapshot.locations
        routineActivities = snapshot.routineActivities
        exerciseLibrary = Self.mergedExerciseLibrary(from: snapshot.exerciseLibrary)
        currentWorkout = snapshot.currentWorkout
        trackedWorkoutSession = snapshot.trackedWorkoutSession
        pendingTrackedWorkouts = snapshot.pendingTrackedWorkouts
        history = snapshot.history
    }

    private static func defaultSnapshot() -> AppSnapshot {
        let eosID = UUID()
        let homeID = UUID()
        let benchID = UUID()
        let dumbbellsID = UUID()
        let cableID = UUID()
        let barbellID = UUID()
        let pullUpBarID = UUID()
        let medicineBallID = UUID()

        let equipmentCatalog = [
            EquipmentItem(id: benchID, name: "Bench"),
            EquipmentItem(id: dumbbellsID, name: "Dumbbells"),
            EquipmentItem(id: cableID, name: "Cable Machine"),
            EquipmentItem(id: barbellID, name: "Barbell"),
            EquipmentItem(id: pullUpBarID, name: "Pull-Up Bar"),
            EquipmentItem(id: medicineBallID, name: "Medicine Ball")
        ]

        let locations = [
            LocationItem(
                id: eosID,
                name: "Eos",
                equipmentSummary: "Barbell, Dumbbells, Cable Machine, Bench",
                equipmentIDs: [barbellID, dumbbellsID, cableID, benchID]
            ),
            LocationItem(
                id: homeID,
                name: "Home Gym",
                equipmentSummary: "Bench, Dumbbells, Pull-Up Bar, Medicine Ball",
                equipmentIDs: [benchID, dumbbellsID, pullUpBarID, medicineBallID]
            )
        ]

        let events: [EventItem] = []

        let recurringActivities: [RecurringActivityItem] = []
        let plannedActivities: [PlannedActivityItem] = []

        let goals: [GoalItem] = []

        // Seed Training Activities so they are configured by default.
        let allWeekdays = Array(Weekday.allCases)
        let strengthAreas = ExerciseBodyArea.allCases.filter { area in
            area != .glutes && area != .abs
        }
        let coreAreas: [ExerciseBodyArea] = [.glutes, .abs]

        let strengthSchedules = strengthAreas.map {
            BodyPartSchedulePreference(bodyPart: $0, weekdays: allWeekdays)
        }
        let coreSchedules = coreAreas.map {
            BodyPartSchedulePreference(bodyPart: $0, weekdays: allWeekdays)
        }

        let routineActivities: [RoutineActivity] = [
            RoutineActivity(
                id: UUID(),
                title: "Traditional Strength Training",
                activityType: "Traditional Strength Training",
                focusAreas: strengthAreas,
                scheduledWeekdays: [],
                defaultLocationID: nil,
                defaultDurationMinutes: nil,
                bodyPartSchedules: strengthSchedules,
                isTrainingTemplate: true
            ),
            RoutineActivity(
                id: UUID(),
                title: "Core Training",
                activityType: "Core Training",
                focusAreas: coreAreas,
                scheduledWeekdays: [],
                defaultLocationID: nil,
                defaultDurationMinutes: nil,
                bodyPartSchedules: coreSchedules,
                isTrainingTemplate: true
            )
        ]

        let exerciseLibrary = Self.defaultExerciseLibrary()

        let currentWorkout = WorkoutPlan(
            id: UUID(),
            summary: "Lower-body support for the top-ranked goal",
            plannedDurationMinutes: 20,
            locationID: eosID,
            exercises: [
                PlannedExercise(id: UUID(), title: "Rear-Foot Elevated Split Squat", reason: "Supports running durability and single-leg control."),
                PlannedExercise(id: UUID(), title: "Single-Arm Cable Row", reason: "Adds upper-back strength and posture support."),
                PlannedExercise(id: UUID(), title: "Lateral Lunge", reason: "Builds resilience and movement variety for weekly lifting.")
            ]
        )

        let trackedWorkoutSession: TrackedWorkoutSession? = nil
        let pendingTrackedWorkouts: [PendingTrackedWorkoutMerge] = []
        let history: [CompletedWorkoutSummary] = []

        return AppSnapshot(
            events: events,
            recurringActivities: recurringActivities,
            plannedActivities: plannedActivities,
            selectedFocusActivityType: nil,
            goals: goals,
            equipmentCatalog: equipmentCatalog,
            locations: locations,
            routineActivities: routineActivities,
            exerciseLibrary: exerciseLibrary,
            currentWorkout: currentWorkout,
            trackedWorkoutSession: trackedWorkoutSession,
            pendingTrackedWorkouts: pendingTrackedWorkouts,
            history: history
        )
    }

    private static func defaultEquipmentCatalog() -> [EquipmentItem] {
        [
            EquipmentItem(id: UUID(), name: "Bench"),
            EquipmentItem(id: UUID(), name: "Dumbbells"),
            EquipmentItem(id: UUID(), name: "Pull-Up Bar"),
            EquipmentItem(id: UUID(), name: "Medicine Ball"),
            EquipmentItem(id: UUID(), name: "Barbell"),
            EquipmentItem(id: UUID(), name: "Cable Machine"),
            EquipmentItem(id: UUID(), name: "Machine"),
            EquipmentItem(id: UUID(), name: "Trap Bar"),
            EquipmentItem(id: UUID(), name: "Kettlebell")
        ]
    }

    private static func defaultExerciseLibrary() -> [ExerciseLibraryItem] {
        [
            exercise("Goblet Squat", .squat, [.dumbbells], [.legs, .glutes, .abs], ["running", "hiking", "skiing"], .beginner, false, "Simple lower-body squat pattern that fits most gyms and home setups.", "Hold one dumbbell at your chest, sit your hips down and back, then stand tall through your whole foot."),
            exercise("Back Squat", .squat, [.barbell], [.legs, .glutes], ["running", "cycling", "field sports"], .intermediate, false, "Classic bilateral lower-body strength builder.", "Set the bar on your upper back, brace your core, squat to comfortable depth, then drive back up."),
            exercise("Step-Up", .singleLeg, [.dumbbells, .bench], [.legs, .glutes], ["running", "hiking", "skiing"], .beginner, true, "Low-complexity single-leg option with clear carryover to climbing and hiking.", "Step onto the bench with one foot, drive through that leg to stand, then return under control."),
            exercise("Reverse Lunge", .singleLeg, [.dumbbells], [.legs, .glutes], ["running", "court sports", "surfing"], .beginner, true, "Accessible unilateral lower-body work.", "Step one leg backward, lower both knees, then push through the front foot to return to standing."),
            exercise("Regular Lunge", .singleLeg, [.dumbbells], [.legs, .glutes], ["running", "court sports", "hiking", "surfing"], .beginner, true, "Forward lunge for unilateral lower-body strength and balance.", "Step one leg forward, lower your back knee toward the floor while keeping your front knee over your ankle, then push through the front foot to return to standing."),
            exercise("Hip Thrust", .hinge, [.barbell, .bench], [.glutes, .legs], ["running", "cycling", "surfing"], .intermediate, false, "Glute-focused bridge pattern.", "Rest your upper back on a bench, drive your hips up until your torso is level, then lower slowly."),
            exercise("Leg Curl", .hinge, [.machine], [.legs], ["running", "field sports"], .beginner, false, "Simple machine posterior-chain accessory.", "Set the pad above your heels, curl your heels toward you, pause, then return with control."),
            exercise("Leg Press", .squat, [.machine], [.legs, .glutes], ["running", "cycling", "field sports"], .beginner, false, "Machine-based leg press for quad and glute strength without spinal loading.", "Sit with your back against the pad, feet on the platform. Press through your whole foot to extend your legs, then lower with control."),
            exercise("Leg Extension", .squat, [.machine], [.legs], ["running", "field sports"], .beginner, false, "Machine quad isolation for knee extension.", "Sit with the pad against your ankles, extend your legs until straight, squeeze at the top, then lower with control."),
            exercise("Push-Up", .horizontalPush, [.bodyweight], [.chest, .triceps, .shoulders], ["general", "surfing"], .beginner, false, "Scalable upper-body push that works almost anywhere.", "Start in a straight plank, lower your chest toward the floor, then press back up without sagging."),
            exercise("Flat Barbell Bench Press", .horizontalPush, [.barbell, .bench], [.chest, .triceps, .shoulders], ["general", "surfing"], .beginner, false, "Standard flat barbell press for chest and triceps strength.", "Lower the bar to mid-chest with control, keep your shoulders set, then press straight up."),
            exercise("Incline Barbell Bench Press", .horizontalPush, [.barbell, .bench], [.chest, .shoulders, .triceps], ["general", "surfing"], .intermediate, false, "Upper-chest pressing variation using a barbell.", "Use an incline bench, lower the bar to your upper chest, then press it back above your shoulders."),
            exercise("Decline Barbell Bench Press", .horizontalPush, [.barbell, .bench], [.chest, .triceps], ["general"], .intermediate, false, "Lower-angle bench press variation using a barbell.", "Secure your legs, lower the bar to your lower chest, then press it back up with steady control."),
            exercise("Flat Dumbbell Bench Press", .horizontalPush, [.dumbbells, .bench], [.chest, .triceps], ["general", "surfing"], .beginner, false, "Simple flat dumbbell press option for most gyms.", "Start with dumbbells over your chest, lower until your elbows are just below the bench, then press up."),
            exercise("Incline Dumbbell Bench Press", .horizontalPush, [.dumbbells, .bench], [.chest, .shoulders, .triceps], ["general", "surfing"], .beginner, false, "Upper-chest dumbbell pressing variation.", "Use an incline bench, lower the dumbbells beside your upper chest, then press them up together."),
            exercise("Decline Dumbbell Bench Press", .horizontalPush, [.dumbbells, .bench], [.chest, .triceps], ["general"], .intermediate, false, "Decline dumbbell press for chest and triceps.", "On a decline bench, lower the dumbbells with control and press them back up over your chest."),
            exercise("Cable Chest Press", .horizontalPush, [.cable], [.chest, .triceps], ["general"], .beginner, false, "Stable pressing alternative when free weights are limited.", "Stand in a split stance, press the handles forward until your arms extend, then return slowly."),
            exercise("Cable Crossover", .horizontalPush, [.cable], [.chest, .shoulders], ["general"], .beginner, false, "Cable fly variation for chest isolation.", "With a slight bend in your elbows, bring the handles together in front of your chest, then open back up."),
            exercise("Machine Chest Fly", .horizontalPush, [.machine], [.chest], ["general"], .beginner, false, "Simple machine-based chest fly.", "Keep your chest up, bring the arms together in front of you, then return until you feel a stretch."),
            exercise("Machine Reverse Fly", .horizontalPull, [.machine], [.back, .shoulders], ["swimming", "surfing", "general"], .beginner, false, "Simple machine-based rear-delt and upper-back exercise.", "Sit tall, pull the machine arms out and back, squeeze your shoulder blades, then return slowly."),
            exercise("Single-Arm Dumbbell Row", .horizontalPull, [.dumbbells, .bench], [.back], ["running", "surfing", "general"], .beginner, true, "Easy horizontal pull that fits almost any program.", "Support yourself on a bench, row the dumbbell toward your hip, then lower it fully."),
            exercise("Machine Row", .horizontalPull, [.machine], [.back], ["surfing", "swimming", "general"], .beginner, false, "Simple machine-based row for upper-back strength.", "Sit tall against the pad, pull the handles toward your torso, squeeze your back, then return slowly."),
            exercise("Seated Cable Row", .horizontalPull, [.cable], [.back], ["surfing", "general"], .beginner, false, "Low-skill row with controllable loading.", "Sit tall, pull the handle toward your lower ribs, squeeze your back, then extend your arms again."),
            exercise("Chest-Supported Row", .horizontalPull, [.dumbbells, .bench], [.back], ["surfing", "general"], .beginner, false, "Pulling volume without much lower-back fatigue.", "Lie chest-down on an incline bench, row the weights to your sides, then lower under control."),
            exercise("Face Pull", .horizontalPull, [.cable], [.back, .shoulders], ["swimming", "surfing", "general"], .beginner, false, "Shoulder-friendly upper-back accessory.", "Pull the rope toward your face with elbows high, then return slowly while keeping tension."),
            exercise("Standing Overhead Press", .verticalPush, [.barbell], [.shoulders, .triceps, .abs], ["general", "surfing"], .intermediate, false, "Vertical press with trunk demand.", "Brace your core, press the bar overhead in a straight path, then lower it back to shoulder level."),
            exercise("Shoulder Press", .verticalPush, [.machine], [.shoulders, .triceps], ["general", "surfing"], .beginner, false, "Simple machine-based shoulder press variation.", "Start with the handles at shoulder height, press overhead until your arms are straight, then lower with control."),
            exercise("Dumbbell Shoulder Press", .verticalPush, [.dumbbells], [.shoulders, .triceps], ["general", "surfing"], .beginner, false, "Accessible vertical push alternative.", "Press the dumbbells overhead from shoulder height, finish with arms straight, then lower with control."),
            exercise("Arnold Press", .verticalPush, [.dumbbells], [.shoulders, .triceps], ["general", "surfing"], .intermediate, false, "Rotating dumbbell shoulder press variation.", "Start with palms facing you, rotate the dumbbells as you press overhead, then reverse the motion on the way down."),
            exercise("Dumbbell Front Raise", .verticalPush, [.dumbbells], [.shoulders], ["general", "surfing"], .beginner, false, "Simple front-delt isolation exercise with dumbbells.", "Raise the dumbbells in front of you to about shoulder height, then lower them slowly."),
            exercise("Dumbbell Lateral Raise", .verticalPush, [.dumbbells], [.shoulders], ["general", "surfing"], .beginner, false, "Simple side-delt isolation exercise with dumbbells.", "Lift the dumbbells out to your sides to shoulder height with soft elbows, then lower slowly."),
            exercise("Tricep Pulldown", .verticalPush, [.cable], [.triceps], ["general"], .beginner, false, "Simple cable triceps isolation exercise.", "Keep your elbows tucked by your sides, pull the handle down until your arms are straight, then return slowly."),
            exercise("Tricep Press", .verticalPush, [.cable], [.triceps], ["general"], .beginner, false, "Simple cable triceps press or pushdown.", "Keep your elbows by your sides, press the handle down until your arms are straight, then return."),
            exercise("Pull-Up", .verticalPull, [.pullUpBar], [.back, .biceps], ["surfing", "climbing", "general"], .intermediate, false, "High-value vertical pull for upper-body strength.", "Hang from the bar, pull your chest upward by driving your elbows down, then lower fully."),
            exercise("Lat Pulldown", .verticalPull, [.machine], [.back, .biceps], ["surfing", "swimming", "general"], .beginner, false, "Simple substitute for pull-ups when needed.", "Pull the bar to your upper chest while keeping your torso tall, then let it rise back up slowly."),
            exercise("Dumbbell Curl", .verticalPull, [.dumbbells], [.biceps], ["general"], .beginner, false, "Simple dumbbell biceps curl variation.", "Keep your elbows near your sides, curl the dumbbells up, then lower them without swinging."),
            exercise("Preacher Bar Curl", .verticalPull, [.barbell, .bench], [.biceps], ["general"], .beginner, false, "Supported curling variation for biceps.", "Rest your upper arms on the pad, curl the bar up smoothly, then lower it to full extension."),
            exercise("Dead Bug", .core, [.bodyweight], [.abs], ["running", "general"], .beginner, false, "Foundational trunk-control pattern.", "Keep your low back pressed down, extend opposite arm and leg, then return and switch sides."),
            exercise("Side Plank", .core, [.bodyweight], [.abs, .glutes], ["running", "surfing", "general"], .beginner, false, "Simple anti-lateral-flexion core work.", "Prop yourself on one forearm, lift your hips into a straight line, and hold steady."),
            exercise("Cable Crunch", .core, [.cable], [.abs], ["general"], .beginner, false, "Simple cable-based abdominal exercise.", "Kneel at the cable, curl your ribs toward your hips, then return without losing control."),
            exercise("Medicine Ball Situp to Twist", .core, [.medicineBall], [.abs], ["general"], .beginner, false, "Sit-up with rotation, holding a medicine ball.", "Lie on your back with the ball at your chest. Sit up and twist to one side, lower with control, then repeat to the other side."),
            exercise("Medicine Ball Russian Twist", .core, [.medicineBall], [.abs], ["general"], .beginner, false, "Seated rotation with a medicine ball for obliques and core.", "Sit with knees bent, feet on the floor or lifted. Hold the ball and rotate your torso side to side, tapping the ball beside your hip each rep."),
            exercise("Sit-up", .core, [.bodyweight], [.abs], ["running", "general"], .beginner, false, "Classic full sit-up from supine to seated.", "Lie on your back, knees bent. Curl up through your abs until you reach a seated position, then lower with control."),
            exercise("Mountain Climbers", .core, [.bodyweight], [.abs], ["running", "general"], .beginner, false, "Dynamic plank with alternating knee drive.", "Start in a high plank. Drive one knee toward your chest, then switch legs in a running motion while keeping your hips stable."),
            exercise("Beast Hold", .core, [.bodyweight], [.abs], ["general"], .beginner, false, "Static hold in beast position with knees off the floor.", "Start on hands and toes, knees under hips. Lift your knees an inch or two off the floor and hold a flat table-top position with a braced core."),
            exercise("Plank", .core, [.bodyweight], [.abs], ["running", "surfing", "general"], .beginner, false, "Static anti-extension core hold.", "Hold a straight line from head to heels on your forearms or hands; keep your core braced and avoid sagging or piking."),
            exercise("Bicycle Crunch", .core, [.bodyweight], [.abs], ["general"], .beginner, false, "Alternating elbow-to-knee crunch for abs and obliques.", "Lie on your back, hands behind your head. Bring one knee in while rotating your opposite elbow toward it, then switch sides in a pedaling motion."),
            exercise("Hollow Hold", .core, [.bodyweight], [.abs], ["running", "general"], .intermediate, false, "Static hollow-body position for core strength.", "Lie on your back. Press your low back down, lift your shoulders and legs off the floor, and hold a curved hollow shape with arms and legs extended."),
            exercise("Bird Dog", .core, [.bodyweight], [.abs, .glutes], ["running", "general"], .beginner, true, "Alternating arm and leg extension for core and glute stability.", "On hands and knees, extend one arm and the opposite leg until they are parallel to the floor. Hold briefly, then return and switch sides."),
            exercise("Reverse Crunch", .core, [.bodyweight], [.abs], ["general"], .beginner, false, "Lower-ab focus by curling hips toward your ribs.", "Lie on your back, legs bent. Use your abs to curl your hips off the floor and toward your ribs, then lower with control."),
            exercise("Glute Bridge", .hinge, [.bodyweight], [.glutes, .legs], ["running", "general"], .beginner, false, "Hip extension bridge for glute activation.", "Lie on your back, knees bent, feet flat. Drive through your heels to lift your hips until your body forms a straight line; squeeze your glutes at the top."),
            exercise("Cable Kickback", .hinge, [.cable], [.glutes], ["general"], .beginner, true, "Single-leg hip extension at the cable for glute isolation.", "Attach an ankle strap to the cable. Stand facing the machine, extend one leg back against the resistance, then return with control."),
            exercise("Frog Pump", .hinge, [.bodyweight], [.glutes], ["general"], .beginner, false, "Glute bridge with feet together and knees out for glute focus.", "Lie on your back with soles of your feet together and knees out. Drive through your heels to lift your hips, squeeze your glutes, then lower."),
            exercise("Clam Shell", .core, [.bodyweight], [.glutes], ["running", "general"], .beginner, true, "Side-lying hip external rotation for glute medius.", "Lie on your side, knees bent. Keeping your feet together, lift your top knee toward the ceiling, then lower with control. Repeat on both sides.")
        ]
    }

    private static func mergedExerciseLibrary(from storedExercises: [ExerciseLibraryItem]) -> [ExerciseLibraryItem] {
        let customExercises = storedExercises.filter { $0.source == .custom }
        let seededExercises = defaultExerciseLibrary()

        return (seededExercises + customExercises).sorted {
            if $0.source != $1.source {
                return $0.source == .seeded
            }

            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private static func exercise(
        _ name: String,
        _ movementPattern: ExerciseMovementPattern,
        _ requiredEquipment: [ExerciseEquipmentKind],
        _ primaryMuscles: [ExerciseBodyArea],
        _ goalSupportTags: [String],
        _ skillLevel: ExerciseSkillLevel,
        _ isUnilateral: Bool,
        _ notes: String,
        _ instructions: String
    ) -> ExerciseLibraryItem {
        ExerciseLibraryItem(
            id: UUID(),
            name: name,
            movementPattern: movementPattern,
            requiredEquipment: requiredEquipment,
            primaryMuscles: primaryMuscles,
            goalSupportTags: goalSupportTags,
            skillLevel: skillLevel,
            isUnilateral: isUnilateral,
            notes: notes,
            instructions: instructions,
            source: .seeded
        )
    }

    var todayScheduledRoutineActivities: [ScheduledRoutineActivity] {
        scheduledRoutineActivities(for: .now)
    }

    var defaultLocation: LocationItem? {
        guard let locationID = todayScheduledRoutineActivities.first?.locationID else { return nil }
        return locations.first { $0.id == locationID }
    }

    func weekday(for date: Date) -> Weekday {
        let weekdayIndex = Calendar.current.component(.weekday, from: date)
        return Weekday(rawValue: ((weekdayIndex + 5) % 7) + 1) ?? .monday
    }

    func scheduledRoutineActivities(for date: Date) -> [ScheduledRoutineActivity] {
        let mappedWeekday = weekday(for: date)
        return routineActivities
            .filter { $0.scheduledWeekdays.contains(mappedWeekday) }
            .sorted {
                if $0.scheduledWeekdays.count != $1.scheduledWeekdays.count {
                    return $0.scheduledWeekdays.count < $1.scheduledWeekdays.count
                }

                return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
            .map { ScheduledRoutineActivity(routineActivity: $0, date: date) }
    }

    func upcomingScheduledRoutineActivities(limit: Int, startingFrom startDate: Date = .now) -> [ScheduledRoutineActivity] {
        guard let startOfDay = Calendar.current.dateInterval(of: .day, for: startDate)?.start else {
            return []
        }

        var scheduledActivities: [ScheduledRoutineActivity] = []
        for offset in 0..<21 {
            guard let date = Calendar.current.date(byAdding: .day, value: offset, to: startOfDay) else {
                continue
            }

            scheduledActivities.append(contentsOf: scheduledRoutineActivities(for: date))
            if scheduledActivities.count >= limit {
                break
            }
        }

        return Array(scheduledActivities.prefix(limit))
    }

    func setHealthSyncState(_ state: HealthSyncState) {
        healthSyncState = state
    }

    func setSelectedFocusActivityType(_ activityType: String?) {
        let trimmedActivityType = activityType?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        selectedFocusActivityType = trimmedActivityType.isEmpty ? nil : trimmedActivityType
    }

    func upsertRoutineActivity(_ routineActivity: RoutineActivity) {
        if let index = routineActivities.firstIndex(where: { $0.id == routineActivity.id }) {
            routineActivities[index] = routineActivity
        } else {
            routineActivities.append(routineActivity)
        }

        routineActivities.sort {
            $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }
    }

    func removeRoutineActivity(id: UUID) {
        routineActivities.removeAll { $0.id == id }
    }

    func moveGoals(fromOffsets: IndexSet, toOffset: Int) {
        goals.move(fromOffsets: fromOffsets, toOffset: toOffset)
    }

    func removeGoal(id: UUID) {
        goals.removeAll { $0.id == id }
    }

    func regenerateFutureActivities() {
        futureActivitiesLastRegeneratedAt = .now

        guard let scheduledRoutineActivity = todayScheduledRoutineActivities.first else { return }

        currentWorkout = workoutPlan(
            for: scheduledRoutineActivity.routineActivity,
            targetDate: .now,
            locationID: scheduledRoutineActivity.locationID
        )
    }

    @discardableResult
    func startTrackedWorkout(
        for routineActivity: RoutineActivity,
        targetDate: Date = .now,
        locationID: UUID?,
        durationMinutes: Int? = nil
    ) -> TrackedWorkoutSession {
        let workoutPlan = workoutPlan(
            for: routineActivity,
            targetDate: targetDate,
            locationID: locationID,
            durationMinutes: durationMinutes
        )
        let locationName = locations.first(where: { $0.id == workoutPlan.locationID })?.name ?? "No location"
        let session = TrackedWorkoutSession(
            id: UUID(),
            startedAt: targetDate,
            routineActivityID: routineActivity.id,
            title: routineActivity.title,
            activityType: routineActivity.activityType,
            summary: "Track your suggested workout for \(locationName).",
            plannedDurationMinutes: workoutPlan.plannedDurationMinutes,
            locationID: workoutPlan.locationID,
            locationName: locationName,
            exercises: workoutPlan.exercises.map {
                TrackedExerciseState(id: UUID(), plannedExercise: $0, isCompleted: false)
            }
        )

        currentWorkout = workoutPlan
        trackedWorkoutSession = session
        return session
    }

    @discardableResult
    func startTrackedWorkout(
        for routineActivities: [RoutineActivity],
        routineWeights: [UUID: Int] = [:],
        targetDate: Date = .now,
        locationID: UUID?,
        durationMinutes: Int? = nil
    ) -> TrackedWorkoutSession {
        let normalizedRoutineActivities = routineActivities.sorted {
            $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }

        if normalizedRoutineActivities.count == 1, let onlyRoutineActivity = normalizedRoutineActivities.first {
            return startTrackedWorkout(
                for: onlyRoutineActivity,
                targetDate: targetDate,
                locationID: locationID,
                durationMinutes: durationMinutes
            )
        }

        let combinedFocusAreas = Array(Set(normalizedRoutineActivities.flatMap(\.focusAreas)))
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        let combinedActivityType = combinedTrackedWorkoutActivityType(for: normalizedRoutineActivities)
        let combinedTitle = normalizedRoutineActivities.map(\.title).joined(separator: " + ")
        let aggregateRoutineActivity = RoutineActivity(
            id: UUID(),
            title: combinedTitle,
            activityType: combinedActivityType,
            focusAreas: combinedFocusAreas,
            scheduledWeekdays: [],
            defaultLocationID: locationID,
            defaultDurationMinutes: durationMinutes
        )
        let resolvedDuration = durationMinutes ?? currentWorkout.plannedDurationMinutes
        let totalDesiredCount = suggestedExerciseCount(for: resolvedDuration)
        let plannedExerciseCounts = plannedExerciseCounts(
            for: normalizedRoutineActivities,
            totalDesiredCount: totalDesiredCount,
            routineWeights: routineWeights
        )
        var combinedExercises: [PlannedExercise] = []

        for routineActivity in normalizedRoutineActivities {
            let desiredCount = plannedExerciseCounts[routineActivity.id] ?? 0
            guard desiredCount > 0 else { continue }

            let routineExercises = plannedExercises(
                for: routineActivity,
                targetDate: targetDate,
                locationID: locationID,
                desiredCount: desiredCount,
                priorPlannedExerciseTitles: combinedExercises.map(\.title)
            )

            for exercise in routineExercises {
                let alreadyIncluded = combinedExercises.contains {
                    normalizedExerciseTitle($0.title) == normalizedExerciseTitle(exercise.title)
                }
                if !alreadyIncluded {
                    combinedExercises.append(exercise)
                }
            }
        }

        if combinedExercises.count < totalDesiredCount {
            let remainderExercises = plannedExercises(
                for: aggregateRoutineActivity,
                targetDate: targetDate,
                locationID: locationID,
                desiredCount: totalDesiredCount - combinedExercises.count,
                priorPlannedExerciseTitles: combinedExercises.map(\.title)
            )
            combinedExercises.append(contentsOf: remainderExercises)
        }

        let workoutPlan = WorkoutPlan(
            id: UUID(),
            summary: "Planned strength session",
            plannedDurationMinutes: resolvedDuration,
            locationID: locationID,
            exercises: Array(combinedExercises.prefix(totalDesiredCount))
        )
        let locationName = locations.first(where: { $0.id == workoutPlan.locationID })?.name ?? "No location"
        let session = TrackedWorkoutSession(
            id: UUID(),
            startedAt: targetDate,
            routineActivityID: nil,
            title: combinedTitle,
            activityType: combinedActivityType,
            summary: "Track your suggested workout for \(locationName).",
            plannedDurationMinutes: workoutPlan.plannedDurationMinutes,
            locationID: workoutPlan.locationID,
            locationName: locationName,
            exercises: workoutPlan.exercises.map {
                TrackedExerciseState(id: UUID(), plannedExercise: $0, isCompleted: false)
            }
        )

        currentWorkout = workoutPlan
        trackedWorkoutSession = session
        return session
    }

    func recommendedRoutineWeights(
        for routineActivities: [RoutineActivity],
        targetDate: Date = .now
    ) -> [UUID: Int] {
        guard !routineActivities.isEmpty else { return [:] }

        let calendar = Calendar.current
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: targetDate)?.start ?? calendar.startOfDay(for: targetDate)
        let weeklyStrengthWorkouts = history
            .filter { workout in
                workout.date >= startOfWeek &&
                workout.date <= targetDate &&
                workout.activityType.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare("Traditional Strength Training") == .orderedSame
            }

        let weeklyBodyPartCounts = Dictionary(
            weeklyStrengthWorkouts
                .flatMap(\.exerciseDetails)
                .compactMap(\.bodyPart)
                .map { ($0, 1) },
            uniquingKeysWith: +
        )
        let focusTag = normalizedActivityTag(selectedFocusActivityType)

        let scoredWeights = routineActivities.map { routineActivity -> (UUID, Int) in
            let routineAreas = Set(routineActivity.focusAreas)
            let areaCoverageTotal = routineAreas.reduce(0) { partialResult, area in
                partialResult + (weeklyBodyPartCounts[area] ?? 0)
            }
            let averageCoverage = routineAreas.isEmpty ? 0 : areaCoverageTotal / max(routineAreas.count, 1)
            let freshnessScore = max(1, 8 - min(averageCoverage, 7))

            let focusBonus: Int
            if let focusTag {
                let supportedCandidates = candidateExercises(for: routineActivity)
                    .filter { focusSupportScore(for: $0, focusTag: focusTag) > 0 }
                    .count
                focusBonus = min(supportedCandidates, 4)
            } else {
                focusBonus = 0
            }

            return (routineActivity.id, freshnessScore + focusBonus)
        }

        return allocatedUnits(
            for: routineActivities,
            totalUnits: 100,
            rawWeights: Dictionary(uniqueKeysWithValues: scoredWeights)
        )
    }

    @discardableResult
    func startTrackedWorkout(
        activityType: String = "Traditional Strength Training",
        focusAreas: [ExerciseBodyArea],
        targetDate: Date = .now,
        locationID: UUID?,
        durationMinutes: Int? = nil
    ) -> TrackedWorkoutSession {
        let adHocRoutineActivity = RoutineActivity(
            id: UUID(),
            title: "Unplanned Workout",
            activityType: activityType,
            focusAreas: focusAreas,
            scheduledWeekdays: [],
            defaultLocationID: locationID,
            defaultDurationMinutes: durationMinutes
        )

        return startTrackedWorkout(
            for: adHocRoutineActivity,
            targetDate: targetDate,
            locationID: locationID,
            durationMinutes: durationMinutes
        )
    }

    func toggleTrackedExercise(id: UUID) {
        guard let session = trackedWorkoutSession,
              let index = session.exercises.firstIndex(where: { $0.id == id })
        else {
            return
        }

        trackedWorkoutSession?.exercises[index].isCompleted.toggle()
    }

    /// Mark a tracked exercise as completed with the given duration (e.g. from the exercise timer).
    func completeTrackedExercise(id: UUID, durationSeconds: TimeInterval) {
        guard let session = trackedWorkoutSession,
              let index = session.exercises.firstIndex(where: { $0.id == id })
        else {
            return
        }
        trackedWorkoutSession?.exercises[index].isCompleted = true
        trackedWorkoutSession?.exercises[index].completedDurationSeconds = max(0, durationSeconds)
    }

    func addTrackedExercise(_ exercise: ExerciseLibraryItem) {
        let plannedExercise = PlannedExercise(
            id: UUID(),
            title: exercise.name,
            reason: "Added manually during tracking."
        )
        let trackedExercise = TrackedExerciseState(
            id: UUID(),
            plannedExercise: plannedExercise,
            isCompleted: false
        )

        trackedWorkoutSession?.exercises.append(trackedExercise)
    }

    func resetTrackedWorkoutSessionProgress() {
        guard let session = trackedWorkoutSession else { return }
        trackedWorkoutSession?.exercises = session.exercises.map { exercise in
            var updatedExercise = exercise
            updatedExercise.isCompleted = false
            updatedExercise.completedDurationSeconds = nil
            return updatedExercise
        }
    }

    func discardTrackedWorkoutSession() {
        trackedWorkoutSession = nil
    }

    var completedTrackedExerciseCount: Int {
        trackedWorkoutSession?.exercises.filter(\.isCompleted).count ?? 0
    }

    /// Total time (seconds) from all completed exercises in the current tracked session.
    var totalCompletedTrackedDuration: TimeInterval {
        guard let session = trackedWorkoutSession else { return 0 }
        return session.exercises
            .filter(\.isCompleted)
            .compactMap(\.completedDurationSeconds)
            .reduce(0, +)
    }

    func finalizeTrackedWorkoutSession(completedAt: Date = .now) -> PendingTrackedWorkoutMerge? {
        guard let session = trackedWorkoutSession else { return nil }

        let completedExerciseDetails = session.exercises
            .filter(\.isCompleted)
            .map(makeCompletedExerciseDetail(from:))

        guard !completedExerciseDetails.isEmpty else { return nil }

        let totalSeconds = session.exercises
            .filter(\.isCompleted)
            .compactMap(\.completedDurationSeconds)
            .reduce(0, +)
        let durationMinutes = max(
            totalSeconds > 0 ? Int(totalSeconds.rounded() / 60) : Int(completedAt.timeIntervalSince(session.startedAt).rounded() / 60),
            1
        )
        let pendingWorkout = PendingTrackedWorkoutMerge(
            id: UUID(),
            startedAt: session.startedAt,
            completedAt: completedAt,
            durationMinutes: durationMinutes,
            locationName: session.locationName,
            activityType: session.activityType,
            summary: session.title,
            exerciseDetails: completedExerciseDetails
        )

        trackedWorkoutSession = nil
        return pendingWorkout
    }

    /// Builds a pending merge from the current tracked session without clearing it.
    /// Returns a value even when there are no completed exercises (empty exerciseDetails).
    func buildPendingTrackedWorkoutMerge(completedAt: Date = .now) -> PendingTrackedWorkoutMerge? {
        guard let session = trackedWorkoutSession else { return nil }

        let completedExerciseDetails = session.exercises
            .filter(\.isCompleted)
            .map(makeCompletedExerciseDetail(from:))

        let totalSeconds = session.exercises
            .filter(\.isCompleted)
            .compactMap(\.completedDurationSeconds)
            .reduce(0, +)
        let durationMinutes = max(
            totalSeconds > 0 ? Int(totalSeconds.rounded() / 60) : Int(completedAt.timeIntervalSince(session.startedAt).rounded() / 60),
            1
        )
        return PendingTrackedWorkoutMerge(
            id: UUID(),
            startedAt: session.startedAt,
            completedAt: completedAt,
            durationMinutes: durationMinutes,
            locationName: session.locationName,
            activityType: session.activityType,
            summary: session.title,
            exerciseDetails: completedExerciseDetails
        )
    }

    func addPendingTrackedWorkout(_ pending: PendingTrackedWorkoutMerge) {
        pendingTrackedWorkouts.append(pending)
    }

    func upsertCompletedWorkout(_ workout: CompletedWorkoutSummary) {
        if let index = history.firstIndex(where: { $0.id == workout.id }) {
            history[index] = workout
        } else {
            history.append(workout)
        }

        history.sort { $0.date > $1.date }
    }

    func containsGoal(titled title: String) -> Bool {
        goals.contains {
            $0.title.caseInsensitiveCompare(title.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame
        }
    }

    @discardableResult
    func addManualGoal(title: String, emphasis: GoalEmphasis) -> Bool {
        addRecurringActivityGoal(
            activityType: title,
            emphasis: emphasis,
            isDetectedFromHealth: false
        )
    }

    @discardableResult
    func addGoalFromHistory(activityType: String) -> Bool {
        addRecurringActivityGoal(
            activityType: activityType,
            emphasis: .maintain,
            isDetectedFromHealth: true
        )
    }

    func upsertLocation(_ location: LocationItem) {
        if let index = locations.firstIndex(where: { $0.id == location.id }) {
            locations[index] = location
        } else {
            locations.append(location)
        }

        locations.sort {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    func removeLocation(id: UUID) {
        locations.removeAll { $0.id == id }

        for index in routineActivities.indices where routineActivities[index].defaultLocationID == id {
            routineActivities[index].defaultLocationID = nil
        }

        if currentWorkout.locationID == id {
            currentWorkout.locationID = nil
        }
    }

    func upsertEquipmentItem(_ equipment: EquipmentItem) {
        if let index = equipmentCatalog.firstIndex(where: { $0.id == equipment.id }) {
            equipmentCatalog[index] = equipment
        } else {
            equipmentCatalog.append(equipment)
        }

        equipmentCatalog.sort {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    func removeEquipmentItem(id: UUID) {
        equipmentCatalog.removeAll { $0.id == id }

        for index in locations.indices where locations[index].equipmentIDs.contains(id) {
            locations[index].equipmentIDs.removeAll { $0 == id }
            locations[index].equipmentSummary = equipmentSummary(for: locations[index].equipmentIDs)
        }
    }

    func upsertExerciseLibraryItem(_ exercise: ExerciseLibraryItem) {
        if let index = exerciseLibrary.firstIndex(where: { $0.id == exercise.id }) {
            exerciseLibrary[index] = exercise
        } else {
            exerciseLibrary.append(exercise)
        }

        exerciseLibrary.sort {
            if $0.source != $1.source {
                return $0.source == .seeded
            }

            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    func removeExerciseLibraryItem(id: UUID) {
        exerciseLibrary.removeAll { $0.id == id }
    }

    func equipmentSummary(for ids: [UUID]) -> String {
        let names = equipmentCatalog
            .filter { ids.contains($0.id) }
            .map(\.name)
            .sorted()
        return names.joined(separator: ", ")
    }

    func applyHealthRefresh(
        completedWorkouts: [CompletedWorkoutSummary],
        detectedActivityTypes: [String]
    ) {
        if !completedWorkouts.isEmpty {
            let existingDetailsByID = Dictionary(uniqueKeysWithValues: history.map { ($0.id, $0.exerciseDetails) })
            var mergedHistory = completedWorkouts.map { workout in
                var mergedWorkout = workout
                mergedWorkout.exerciseDetails = existingDetailsByID[workout.id] ?? workout.exerciseDetails
                return mergedWorkout
            }
            let mergeResult = mergePendingTrackedWorkouts(into: mergedHistory)
            mergedHistory = mergeResult.workouts
            pendingTrackedWorkouts = mergeResult.remainingPending
            history = mergedHistory.sorted { $0.date > $1.date }
        }

        let trimmedTypes = detectedActivityTypes
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        for activityType in trimmedTypes {
            let existingActivity = recurringActivities.contains {
                $0.activityType.caseInsensitiveCompare(activityType) == .orderedSame
            }

            if !existingActivity {
                let activity = RecurringActivityItem(
                    id: UUID(),
                    activityType: activityType,
                    emphasis: .maintain,
                    isDetectedFromHealth: true
                )
                recurringActivities.append(activity)
            }
        }
    }

    @discardableResult
    private func addRecurringActivityGoal(
        activityType: String,
        emphasis: GoalEmphasis,
        isDetectedFromHealth: Bool
    ) -> Bool {
        let trimmedActivityType = activityType.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedActivityType.isEmpty else { return false }

        if let existingActivityIndex = recurringActivities.firstIndex(where: {
            $0.activityType.caseInsensitiveCompare(trimmedActivityType) == .orderedSame
        }) {
            recurringActivities[existingActivityIndex].emphasis = emphasis
        } else {
            recurringActivities.append(
                RecurringActivityItem(
                    id: UUID(),
                    activityType: trimmedActivityType,
                    emphasis: emphasis,
                    isDetectedFromHealth: isDetectedFromHealth
                )
            )
        }

        guard !containsGoal(titled: trimmedActivityType) else { return false }

        goals.append(
            GoalItem(
                id: UUID(),
                title: trimmedActivityType,
                sourceKind: .recurringActivity,
                emphasis: emphasis
            )
        )
        return true
    }

    func plannedExercises(
        for routineActivity: RoutineActivity,
        targetDate: Date = .now,
        locationID: UUID? = nil,
        desiredCount: Int? = nil,
        priorPlannedExerciseTitles: [String] = []
    ) -> [PlannedExercise] {
        let resolvedLocationID = locationID ?? routineActivity.defaultLocationID
        let relevantWorkouts = relevantCompletedWorkouts(for: routineActivity, locationID: resolvedLocationID)

        return recommendedExercises(
            for: routineActivity,
            targetDate: targetDate,
            locationID: resolvedLocationID,
            desiredCount: desiredCount,
            priorPlannedExerciseTitles: priorPlannedExerciseTitles
        )
        .map { exercise in
            PlannedExercise(
                id: UUID(),
                title: exercise.name,
                reason: plannedReason(for: exercise, relevantWorkouts: relevantWorkouts)
            )
        }
    }

    func recommendedExercises(
        for routineActivity: RoutineActivity,
        targetDate: Date = .now,
        locationID: UUID? = nil,
        desiredCount: Int? = nil,
        priorPlannedExerciseTitles: [String] = []
    ) -> [ExerciseLibraryItem] {
        let candidates = candidateExercises(for: routineActivity, locationID: locationID)
        let selectionLimit = min(max(desiredCount ?? 4, 1), candidates.count)
        guard selectionLimit > 0 else { return [] }

        let focusTag = normalizedActivityTag(selectedFocusActivityType)
        let relevantWorkouts = relevantCompletedWorkouts(for: routineActivity, locationID: locationID)
        let priorPlannedTitleSet = Set(priorPlannedExerciseTitles.map(normalizedExerciseTitle))
        let recentWorkoutTitleSets = recentWorkoutTitleSets(from: relevantWorkouts, limit: 2)
        let recentTitleUsage = recentExerciseUsage(from: relevantWorkouts, limit: 6)

        let anchors = anchorExercises(
            from: candidates,
            relevantWorkouts: relevantWorkouts,
            selectionLimit: selectionLimit
        )
        var selectedExercises = anchors

        while selectedExercises.count < selectionLimit {
            let selectedTitleSet = Set(selectedExercises.map(\.id))
            let remainingCandidates = candidates.filter { !selectedTitleSet.contains($0.id) }
            guard
                let nextExercise = bestVarietyExercise(
                    from: remainingCandidates,
                    selectedExercises: selectedExercises,
                    routineActivity: routineActivity,
                    recentWorkoutTitleSets: recentWorkoutTitleSets,
                    recentTitleUsage: recentTitleUsage,
                    priorPlannedTitleSet: priorPlannedTitleSet,
                    focusTag: focusTag
                )
            else {
                break
            }

            selectedExercises.append(nextExercise)
        }

        if selectedExercises.count < selectionLimit {
            let selectedIDs = Set(selectedExercises.map(\.id))
            selectedExercises.append(contentsOf: candidates.filter { !selectedIDs.contains($0.id) })
        }

        return Array(selectedExercises.prefix(selectionLimit).shuffled())
    }

    private func candidateExercises(for routineActivity: RoutineActivity, locationID: UUID? = nil) -> [ExerciseLibraryItem] {
        exerciseLibrary
            .filter { exercise in
                isRelevantCandidate(exercise, for: routineActivity)
            }
            .filter { exercise in
                supports(exercise: exercise, at: locationID ?? routineActivity.defaultLocationID)
            }
            .sorted { lhs, rhs in
                lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
    }

    private func isRelevantCandidate(_ exercise: ExerciseLibraryItem, for routineActivity: RoutineActivity) -> Bool {
        let focusAreas = Set(routineActivity.focusAreas)
        let primaryMuscles = Set(exercise.primaryMuscles)
        let matchingFocusCount = focusAreas.intersection(primaryMuscles).count

        guard matchingFocusCount > 0 else { return false }

        // For single-focus days, allow any exercise that meaningfully trains that area.
        guard focusAreas.count > 1 else { return true }

        // For multi-focus days, prefer exercises that either stay fully inside the
        // requested focus areas or cover at least two of them.
        return primaryMuscles.isSubset(of: focusAreas) || matchingFocusCount >= 2
    }

    private func relevantCompletedWorkouts(for routineActivity: RoutineActivity, locationID: UUID? = nil) -> [CompletedWorkoutSummary] {
        let candidateTitleSet = Set(candidateExercises(for: routineActivity, locationID: locationID).map { normalizedExerciseTitle($0.name) })
        guard !candidateTitleSet.isEmpty else { return [] }

        return historyExcludingLast7Days
            .filter { !$0.exerciseDetails.isEmpty }
            .filter { workout in
                workout.exerciseDetails.contains { exercise in
                    candidateTitleSet.contains(normalizedExerciseTitle(exercise.title))
                }
            }
            .sorted { $0.date > $1.date }
    }

    private func anchorExercises(
        from candidates: [ExerciseLibraryItem],
        relevantWorkouts: [CompletedWorkoutSummary],
        selectionLimit: Int
    ) -> [ExerciseLibraryItem] {
        let mostRecentTitles = recentWorkoutTitleSets(from: relevantWorkouts, limit: 1).first ?? []

        let scoredCandidates = candidates.compactMap { exercise -> (ExerciseLibraryItem, Int)? in
            let normalizedTitle = normalizedExerciseTitle(exercise.name)
            let workoutIndexes = relevantWorkouts.enumerated().compactMap { index, workout in
                containsLoggedExercise(named: normalizedTitle, in: workout) ? index : nil
            }

            guard !workoutIndexes.isEmpty else { return nil }

            let usageCount = workoutIndexes.count
            let lastSeenIndex = workoutIndexes.min() ?? 0
            let score =
                (usageCount * 100) +
                max(0, 40 - (lastSeenIndex * 12)) -
                (mostRecentTitles.contains(normalizedTitle) ? 10 : 0)

            return (exercise, score)
        }
        .sorted { lhs, rhs in
            if lhs.1 != rhs.1 {
                return lhs.1 > rhs.1
            }

            return lhs.0.name.localizedCaseInsensitiveCompare(rhs.0.name) == .orderedAscending
        }

        let anchorLimit: Int
        switch (selectionLimit, scoredCandidates.count) {
        case let (limit, count) where limit >= 4 && count >= 2:
            anchorLimit = 2
        case (_, 0):
            anchorLimit = 0
        default:
            anchorLimit = 1
        }

        return Array(scoredCandidates.prefix(anchorLimit).map(\.0))
    }

    private func bestVarietyExercise(
        from candidates: [ExerciseLibraryItem],
        selectedExercises: [ExerciseLibraryItem],
        routineActivity: RoutineActivity,
        recentWorkoutTitleSets: [Set<String>],
        recentTitleUsage: [String: Int],
        priorPlannedTitleSet: Set<String>,
        focusTag: String?
    ) -> ExerciseLibraryItem? {
        let selectedPatterns = Dictionary(selectedExercises.map { ($0.movementPattern, 1) }, uniquingKeysWith: +)
        let selectedFamilies = Dictionary(selectedExercises.map { (exerciseVarietyFamilyKey(for: $0), 1) }, uniquingKeysWith: +)

        return candidates.max { lhs, rhs in
            let lhsScore = varietyScore(
                for: lhs,
                selectedPatterns: selectedPatterns,
                selectedFamilies: selectedFamilies,
                routineActivity: routineActivity,
                recentWorkoutTitleSets: recentWorkoutTitleSets,
                recentTitleUsage: recentTitleUsage,
                priorPlannedTitleSet: priorPlannedTitleSet,
                focusTag: focusTag
            )
            let rhsScore = varietyScore(
                for: rhs,
                selectedPatterns: selectedPatterns,
                selectedFamilies: selectedFamilies,
                routineActivity: routineActivity,
                recentWorkoutTitleSets: recentWorkoutTitleSets,
                recentTitleUsage: recentTitleUsage,
                priorPlannedTitleSet: priorPlannedTitleSet,
                focusTag: focusTag
            )

            if lhsScore != rhsScore {
                return lhsScore < rhsScore
            }
            // Break ties randomly so suggested exercises vary when many candidates have similar scores
            return Bool.random()
        }
    }

    private func varietyScore(
        for exercise: ExerciseLibraryItem,
        selectedPatterns: [ExerciseMovementPattern: Int],
        selectedFamilies: [String: Int],
        routineActivity: RoutineActivity,
        recentWorkoutTitleSets: [Set<String>],
        recentTitleUsage: [String: Int],
        priorPlannedTitleSet: Set<String>,
        focusTag: String?
    ) -> Int {
        let normalizedTitle = normalizedExerciseTitle(exercise.name)
        let recentUsageCount = recentTitleUsage[normalizedTitle] ?? 0
        let mostRecentTitles = recentWorkoutTitleSets.first ?? []
        let secondRecentTitles = recentWorkoutTitleSets.dropFirst().first ?? []
        let matchingFocusCount = Set(exercise.primaryMuscles).intersection(Set(routineActivity.focusAreas)).count
        let selectedPatternCount = selectedPatterns[exercise.movementPattern] ?? 0
        let selectedFamilyCount = selectedFamilies[exerciseVarietyFamilyKey(for: exercise)] ?? 0

        var score = 0
        score += recentUsageCount == 0 ? 45 : max(0, 30 - (recentUsageCount * 10))
        score += mostRecentTitles.contains(normalizedTitle) ? -45 : 25
        score += secondRecentTitles.contains(normalizedTitle) ? -20 : 10
        score += priorPlannedTitleSet.contains(normalizedTitle) ? -25 : 8
        score += selectedPatternCount == 0 ? 25 : -(selectedPatternCount * 20)
        score += selectedFamilyCount == 0 ? 18 : -(selectedFamilyCount * 35)
        score += matchingFocusCount * 6
        score += focusSupportScore(for: exercise, focusTag: focusTag)

        // Small boost when this exercise's body part is typically trained on today's weekday
        if let todayBoost = bodyPartScheduleBoost(for: exercise, in: routineActivity) {
            score += todayBoost
        }

        return score
    }

    private func bodyPartScheduleBoost(
        for exercise: ExerciseLibraryItem,
        in routineActivity: RoutineActivity
    ) -> Int? {
        guard !routineActivity.bodyPartSchedules.isEmpty else { return nil }

        let today = weekday(for: .now)
        let scheduleByBodyPart: [ExerciseBodyArea: Set<Weekday>] = Dictionary(
            uniqueKeysWithValues: routineActivity.bodyPartSchedules.map { pref in
                (pref.bodyPart, Set(pref.weekdays))
            }
        )

        let primaryMuscles = Set(exercise.primaryMuscles)
        let matchesToday = primaryMuscles.contains { area in
            scheduleByBodyPart[area]?.contains(today) == true
        }

        return matchesToday ? 6 : 0
    }

    private func recentWorkoutTitleSets(
        from workouts: [CompletedWorkoutSummary],
        limit: Int
    ) -> [Set<String>] {
        Array(workouts.prefix(limit)).map { workout in
            Set(workout.exerciseDetails.map { normalizedExerciseTitle($0.title) })
        }
    }

    private func recentExerciseUsage(
        from workouts: [CompletedWorkoutSummary],
        limit: Int
    ) -> [String: Int] {
        Dictionary(
            Array(workouts.prefix(limit))
                .flatMap { workout in
                    workout.exerciseDetails.map { normalizedExerciseTitle($0.title) }
                }
                .map { ($0, 1) },
            uniquingKeysWith: +
        )
    }

    private func containsLoggedExercise(named normalizedTitle: String, in workout: CompletedWorkoutSummary) -> Bool {
        workout.exerciseDetails.contains { exercise in
            normalizedExerciseTitle(exercise.title) == normalizedTitle
        }
    }

    private func normalizedExerciseTitle(_ title: String) -> String {
        let allowedCharacters = CharacterSet.alphanumerics.union(.whitespaces)
        let cleanedTitle = title
            .lowercased()
            .components(separatedBy: allowedCharacters.inverted)
            .joined(separator: " ")

        return cleanedTitle
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    private func exerciseVarietyFamilyKey(for exercise: ExerciseLibraryItem) -> String {
        let normalizedTitle = normalizedExerciseTitle(exercise.name)
        let filteredWords = normalizedTitle
            .split(separator: " ")
            .filter { word in
                ![
                    "flat",
                    "incline",
                    "decline",
                    "barbell",
                    "dumbbell",
                    "machine",
                    "cable",
                    "single",
                    "arm",
                    "standing",
                    "seated",
                    "supported",
                    "chest"
                ].contains(String(word))
            }
            .map(String.init)

        let familyKey = filteredWords.joined(separator: " ")
        return familyKey.isEmpty ? normalizedTitle : familyKey
    }

    private func plannedReason(
        for exercise: ExerciseLibraryItem,
        relevantWorkouts: [CompletedWorkoutSummary]
    ) -> String {
        let normalizedTitle = normalizedExerciseTitle(exercise.name)
        let usageCount = relevantWorkouts.reduce(into: 0) { count, workout in
            if containsLoggedExercise(named: normalizedTitle, in: workout) {
                count += 1
            }
        }

        let baseReason: String
        switch usageCount {
        case 2...:
            baseReason = "Builds on recent progress."
        case 1:
            baseReason = "Keeps a familiar lift in the mix."
        default:
            baseReason = "Adds variety for this session."
        }

        if focusSupportScore(for: exercise, focusTag: normalizedActivityTag(selectedFocusActivityType)) > 0 {
            return "\(baseReason) Supports your \(selectedFocusActivityType?.lowercased() ?? "current") focus. \(exercise.notes)"
        }

        return "\(baseReason) \(exercise.notes)"
    }

    private func focusSupportScore(for exercise: ExerciseLibraryItem, focusTag: String?) -> Int {
        guard let focusTag else { return 0 }

        let normalizedTags = exercise.goalSupportTags.map(normalizedActivityTag)
        return normalizedTags.contains(focusTag) ? 30 : 0
    }

    private func normalizedActivityTag(_ tag: String?) -> String? {
        guard let tag else { return nil }
        let normalizedTag = normalizedExerciseTitle(tag)
        return normalizedTag.isEmpty ? nil : normalizedTag
    }

    private func supports(exercise: ExerciseLibraryItem, at locationID: UUID?) -> Bool {
        guard
            let locationID,
            let location = locations.first(where: { $0.id == locationID })
        else {
            return true
        }

        let availableEquipmentStrings = equipmentSummary(for: location.equipmentIDs)
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        let availableSet = Set(availableEquipmentStrings)

        return exercise.requiredEquipment.allSatisfy { requirement in
            guard requirement != .bodyweight else { return true }
            let key = requirement.title.lowercased()
            // Exact match (e.g. "dumbbells") or catalog name contains requirement (e.g. "cable machine" for "cable")
            return availableSet.contains(key)
                || availableEquipmentStrings.contains { $0.contains(key) }
        }
    }

    private func workoutPlan(
        for routineActivity: RoutineActivity,
        targetDate: Date,
        locationID: UUID?,
        durationMinutes: Int? = nil
    ) -> WorkoutPlan {
        let resolvedDuration = durationMinutes ?? routineActivity.defaultDurationMinutes ?? currentWorkout.plannedDurationMinutes
        return WorkoutPlan(
            id: UUID(),
            summary: "Planned strength session",
            plannedDurationMinutes: resolvedDuration,
            locationID: locationID ?? routineActivity.defaultLocationID,
            exercises: plannedExercises(
                for: routineActivity,
                targetDate: targetDate,
                locationID: locationID ?? routineActivity.defaultLocationID,
                desiredCount: suggestedExerciseCount(for: resolvedDuration)
            )
        )
    }

    private func suggestedExerciseCount(for durationMinutes: Int) -> Int {
        let normalizedDuration = max(durationMinutes, 5)
        return max((normalizedDuration / 5) * 2, 2)
    }

    private func combinedTrackedWorkoutActivityType(for routineActivities: [RoutineActivity]) -> String {
        let normalizedActivityTypes = Array(
            Set(
                routineActivities.map {
                    $0.activityType.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                .filter { !$0.isEmpty }
            )
        )

        if normalizedActivityTypes.count == 1, let onlyActivityType = normalizedActivityTypes.first {
            return onlyActivityType
        }

        if normalizedActivityTypes.contains(where: {
            $0.caseInsensitiveCompare("Traditional Strength Training") == .orderedSame
        }) {
            return "Traditional Strength Training"
        }

        return normalizedActivityTypes.first ?? "Traditional Strength Training"
    }

    private func plannedExerciseCounts(
        for routineActivities: [RoutineActivity],
        totalDesiredCount: Int,
        routineWeights: [UUID: Int]
    ) -> [UUID: Int] {
        let recommendedWeights = recommendedRoutineWeights(for: routineActivities)
        let mergedWeights = Dictionary(uniqueKeysWithValues: routineActivities.map { routineActivity in
            let explicitWeight = routineWeights[routineActivity.id]
            let resolvedWeight = explicitWeight ?? recommendedWeights[routineActivity.id] ?? 1
            return (routineActivity.id, max(resolvedWeight, 0))
        })

        return allocatedUnits(
            for: routineActivities,
            totalUnits: max(totalDesiredCount, 1),
            rawWeights: mergedWeights
        )
    }

    private func allocatedUnits(
        for routineActivities: [RoutineActivity],
        totalUnits: Int,
        rawWeights: [UUID: Int]
    ) -> [UUID: Int] {
        guard !routineActivities.isEmpty else { return [:] }

        let positiveWeights = routineActivities.map { routineActivity in
            (routineActivity.id, max(rawWeights[routineActivity.id] ?? 0, 0))
        }
        let totalWeight = positiveWeights.reduce(0) { $0 + $1.1 }
        let fallbackWeight = totalWeight == 0 ? 1 : 0
        let normalizedWeights = positiveWeights.map { id, weight in
            (id, totalWeight == 0 ? fallbackWeight : weight)
        }
        let denominator = max(normalizedWeights.reduce(0) { $0 + $1.1 }, 1)

        var baseAllocations: [UUID: Int] = [:]
        var remainders: [(UUID, Double)] = []
        var usedUnits = 0

        for (id, weight) in normalizedWeights {
            let exactAllocation = (Double(weight) / Double(denominator)) * Double(totalUnits)
            let baseAllocation = Int(exactAllocation.rounded(.down))
            baseAllocations[id] = baseAllocation
            usedUnits += baseAllocation
            remainders.append((id, exactAllocation - Double(baseAllocation)))
        }

        let remainingUnits = max(totalUnits - usedUnits, 0)
        for (id, _) in remainders.sorted(by: { lhs, rhs in
            if lhs.1 != rhs.1 {
                return lhs.1 > rhs.1
            }

            return lhs.0.uuidString < rhs.0.uuidString
        }).prefix(remainingUnits) {
            baseAllocations[id, default: 0] += 1
        }

        return baseAllocations
    }

    private func makeCompletedExerciseDetail(from trackedExercise: TrackedExerciseState) -> CompletedExerciseDetail {
        let libraryItem = exerciseLibrary.first {
            normalizedExerciseTitle($0.name) == normalizedExerciseTitle(trackedExercise.plannedExercise.title)
        }

        return CompletedExerciseDetail(
            id: UUID(),
            title: trackedExercise.plannedExercise.title,
            bodyPart: libraryItem?.primaryMuscles.first,
            sets: nil,
            reps: nil,
            notes: ""
        )
    }

    private func mergePendingTrackedWorkouts(
        into workouts: [CompletedWorkoutSummary]
    ) -> (workouts: [CompletedWorkoutSummary], remainingPending: [PendingTrackedWorkoutMerge]) {
        var mergedWorkouts = workouts
        var remainingPending: [PendingTrackedWorkoutMerge] = []

        for pendingWorkout in pendingTrackedWorkouts {
            guard let matchIndex = bestPendingWorkoutMatchIndex(for: pendingWorkout, in: mergedWorkouts) else {
                remainingPending.append(pendingWorkout)
                continue
            }

            let existingDetails = mergedWorkouts[matchIndex].exerciseDetails
            if existingDetails.isEmpty {
                mergedWorkouts[matchIndex].exerciseDetails = pendingWorkout.exerciseDetails
            } else {
                let existingTitles = Set(existingDetails.map { normalizedExerciseTitle($0.title) })
                let appendedDetails = pendingWorkout.exerciseDetails.filter {
                    !existingTitles.contains(normalizedExerciseTitle($0.title))
                }
                mergedWorkouts[matchIndex].exerciseDetails.append(contentsOf: appendedDetails)
            }

            if mergedWorkouts[matchIndex].locationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                mergedWorkouts[matchIndex].locationName = pendingWorkout.locationName
            }
        }

        return (mergedWorkouts, remainingPending)
    }

    private func bestPendingWorkoutMatchIndex(
        for pendingWorkout: PendingTrackedWorkoutMerge,
        in workouts: [CompletedWorkoutSummary]
    ) -> Int? {
        workouts.enumerated()
            .compactMap { index, workout -> (Int, TimeInterval)? in
                guard
                    workout.activityType.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare(pendingWorkout.activityType.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame,
                    Calendar.current.isDate(workout.date, inSameDayAs: pendingWorkout.startedAt)
                else {
                    return nil
                }

                let timeDifference = abs(workout.date.timeIntervalSince(pendingWorkout.startedAt))
                let durationDifference = abs(workout.durationMinutes - pendingWorkout.durationMinutes)

                guard timeDifference <= 4 * 60 * 60, durationDifference <= 45 else {
                    return nil
                }

                let score = timeDifference + TimeInterval(durationDifference * 60)
                return (index, score)
            }
            .min { lhs, rhs in
                lhs.1 < rhs.1
            }?
            .0
    }
}
