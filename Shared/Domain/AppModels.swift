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
        guard !focusAreas.isEmpty else { return "No targets selected" }
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

struct CompletedWorkoutSummary: Identifiable, Hashable, Codable {
    let id: UUID
    var date: Date
    var durationMinutes: Int
    var locationName: String
    var summary: String
}

struct AppSnapshot: Codable {
    var events: [EventItem]
    var recurringActivities: [RecurringActivityItem]
    var goals: [GoalItem]
    var equipmentCatalog: [EquipmentItem]
    var locations: [LocationItem]
    var routineDays: [RoutineDay]
    var exerciseLibrary: [ExerciseLibraryItem]
    var currentWorkout: WorkoutPlan
    var history: [CompletedWorkoutSummary]

    init(
        events: [EventItem],
        recurringActivities: [RecurringActivityItem],
        goals: [GoalItem],
        equipmentCatalog: [EquipmentItem],
        locations: [LocationItem],
        routineDays: [RoutineDay],
        exerciseLibrary: [ExerciseLibraryItem],
        currentWorkout: WorkoutPlan,
        history: [CompletedWorkoutSummary]
    ) {
        self.events = events
        self.recurringActivities = recurringActivities
        self.goals = goals
        self.equipmentCatalog = equipmentCatalog
        self.locations = locations
        self.routineDays = routineDays
        self.exerciseLibrary = exerciseLibrary
        self.currentWorkout = currentWorkout
        self.history = history
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        events = try container.decode([EventItem].self, forKey: .events)
        recurringActivities = try container.decode([RecurringActivityItem].self, forKey: .recurringActivities)
        goals = try container.decode([GoalItem].self, forKey: .goals)
        equipmentCatalog = try container.decodeIfPresent([EquipmentItem].self, forKey: .equipmentCatalog) ?? []
        locations = try container.decode([LocationItem].self, forKey: .locations)
        routineDays = try container.decode([RoutineDay].self, forKey: .routineDays)
        exerciseLibrary = try container.decodeIfPresent([ExerciseLibraryItem].self, forKey: .exerciseLibrary) ?? []
        currentWorkout = try container.decode(WorkoutPlan.self, forKey: .currentWorkout)
        history = try container.decode([CompletedWorkoutSummary].self, forKey: .history)
    }
}

@MainActor
final class AppStore: ObservableObject {
    @Published var events: [EventItem]
    @Published var recurringActivities: [RecurringActivityItem]
    @Published var goals: [GoalItem]
    @Published var equipmentCatalog: [EquipmentItem]
    @Published var locations: [LocationItem]
    @Published var routineDays: [RoutineDay]
    @Published var exerciseLibrary: [ExerciseLibraryItem]
    @Published var currentWorkout: WorkoutPlan
    @Published var history: [CompletedWorkoutSummary]
    @Published var healthSyncState: HealthSyncState = .notConnected

    init() {
        let snapshot = Self.defaultSnapshot()
        events = snapshot.events
        recurringActivities = snapshot.recurringActivities
        goals = snapshot.goals
        equipmentCatalog = snapshot.equipmentCatalog
        locations = snapshot.locations
        routineDays = snapshot.routineDays
        exerciseLibrary = snapshot.exerciseLibrary
        currentWorkout = snapshot.currentWorkout
        history = snapshot.history
    }

    var snapshot: AppSnapshot {
        AppSnapshot(
            events: events,
            recurringActivities: recurringActivities,
            goals: goals,
            equipmentCatalog: equipmentCatalog,
            locations: locations,
            routineDays: routineDays,
            exerciseLibrary: exerciseLibrary,
            currentWorkout: currentWorkout,
            history: history
        )
    }

    func apply(snapshot: AppSnapshot) {
        events = snapshot.events
        recurringActivities = snapshot.recurringActivities
        goals = snapshot.goals
        equipmentCatalog = snapshot.equipmentCatalog.isEmpty ? Self.defaultEquipmentCatalog() : snapshot.equipmentCatalog
        locations = snapshot.locations
        routineDays = snapshot.routineDays
        exerciseLibrary = snapshot.exerciseLibrary.isEmpty ? Self.defaultExerciseLibrary() : snapshot.exerciseLibrary
        currentWorkout = snapshot.currentWorkout
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

        let events = [
            EventItem(
                id: UUID(),
                title: "Spring 5K",
                eventType: "5K",
                targetDate: Calendar.current.date(byAdding: .day, value: 45, to: .now) ?? .now,
                notes: "Keep this at the top until race day."
            )
        ]

        let recurringActivities: [RecurringActivityItem] = []

        let goals = [
            GoalItem(id: UUID(), title: "Spring 5K", sourceKind: .event, emphasis: nil)
        ]

        let routineDays = [
            RoutineDay(id: UUID(), weekday: .monday, focusAreas: [.legs, .glutes, .abs], defaultLocationID: eosID, defaultDurationMinutes: 20),
            RoutineDay(id: UUID(), weekday: .wednesday, focusAreas: [.chest, .back, .shoulders, .biceps, .triceps], defaultLocationID: eosID, defaultDurationMinutes: 20),
            RoutineDay(id: UUID(), weekday: .friday, focusAreas: [.legs, .chest, .back, .shoulders, .abs], defaultLocationID: eosID, defaultDurationMinutes: 20)
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

        let history = [
            CompletedWorkoutSummary(id: UUID(), date: .now.addingTimeInterval(-86_400), durationMinutes: 21, locationName: "Eos", summary: "Lower-body support workout"),
            CompletedWorkoutSummary(id: UUID(), date: .now.addingTimeInterval(-172_800), durationMinutes: 18, locationName: "Home Gym", summary: "Upper-body support workout")
        ]

        return AppSnapshot(
            events: events,
            recurringActivities: recurringActivities,
            goals: goals,
            equipmentCatalog: equipmentCatalog,
            locations: locations,
            routineDays: routineDays,
            exerciseLibrary: exerciseLibrary,
            currentWorkout: currentWorkout,
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
            exercise("Goblet Squat", .squat, [.dumbbells], [.legs, .glutes, .abs], ["running", "hiking", "skiing"], .beginner, false, "Simple lower-body squat pattern that fits most gyms and home setups."),
            exercise("Front Squat", .squat, [.barbell], [.legs, .glutes, .abs], ["running", "cycling", "skiing"], .intermediate, false, "Quad-dominant squat with strong trunk demand."),
            exercise("Back Squat", .squat, [.barbell], [.legs, .glutes], ["running", "cycling", "field sports"], .intermediate, false, "Classic bilateral lower-body strength builder."),
            exercise("Bulgarian Split Squat", .singleLeg, [.dumbbells, .bench], [.legs, .glutes], ["running", "surfing", "hiking"], .intermediate, true, "Single-leg strength and balance support."),
            exercise("Step-Up", .singleLeg, [.dumbbells, .bench], [.legs, .glutes], ["running", "hiking", "skiing"], .beginner, true, "Low-complexity single-leg option with clear carryover to climbing and hiking."),
            exercise("Reverse Lunge", .singleLeg, [.dumbbells], [.legs, .glutes], ["running", "court sports", "surfing"], .beginner, true, "Accessible unilateral lower-body work."),
            exercise("Romanian Deadlift", .hinge, [.barbell], [.legs, .glutes], ["running", "surfing", "cycling"], .intermediate, false, "Posterior-chain hinge without floor pull setup."),
            exercise("Trap Bar Deadlift", .hinge, [.trapBar], [.legs, .glutes], ["running", "hiking", "field sports"], .intermediate, false, "Heavy total-body hinge that is easier to teach than a straight-bar deadlift."),
            exercise("Hip Thrust", .hinge, [.barbell, .bench], [.glutes, .legs], ["running", "cycling", "surfing"], .intermediate, false, "Glute-focused bridge pattern."),
            exercise("Leg Curl", .hinge, [.machine], [.legs], ["running", "field sports"], .beginner, false, "Simple machine posterior-chain accessory."),
            exercise("Push-Up", .horizontalPush, [.bodyweight], [.chest, .triceps, .shoulders], ["general", "surfing"], .beginner, false, "Scalable upper-body push that works almost anywhere."),
            exercise("Dumbbell Bench Press", .horizontalPush, [.dumbbells, .bench], [.chest, .triceps], ["general", "surfing"], .beginner, false, "Simple press option for commercial gyms and home gyms."),
            exercise("Incline Dumbbell Press", .horizontalPush, [.dumbbells, .bench], [.chest, .shoulders, .triceps], ["general", "surfing"], .beginner, false, "Upper push variation with shoulder-friendly setup."),
            exercise("Cable Chest Press", .horizontalPush, [.cable], [.chest, .triceps], ["general"], .beginner, false, "Stable pressing alternative when free weights are limited."),
            exercise("Single-Arm Dumbbell Row", .horizontalPull, [.dumbbells, .bench], [.back], ["running", "surfing", "general"], .beginner, true, "Easy horizontal pull that fits almost any program."),
            exercise("Seated Cable Row", .horizontalPull, [.cable], [.back], ["surfing", "general"], .beginner, false, "Low-skill row with controllable loading."),
            exercise("Chest-Supported Row", .horizontalPull, [.dumbbells, .bench], [.back], ["surfing", "general"], .beginner, false, "Pulling volume without much lower-back fatigue."),
            exercise("Face Pull", .horizontalPull, [.cable], [.back, .shoulders], ["swimming", "surfing", "general"], .beginner, false, "Shoulder-friendly upper-back accessory."),
            exercise("Standing Overhead Press", .verticalPush, [.barbell], [.shoulders, .triceps, .abs], ["general", "surfing"], .intermediate, false, "Vertical press with trunk demand."),
            exercise("Dumbbell Shoulder Press", .verticalPush, [.dumbbells], [.shoulders, .triceps], ["general", "surfing"], .beginner, false, "Accessible vertical push alternative."),
            exercise("Pull-Up", .verticalPull, [.pullUpBar], [.back, .biceps], ["surfing", "climbing", "general"], .intermediate, false, "High-value vertical pull for upper-body strength."),
            exercise("Lat Pulldown", .verticalPull, [.machine], [.back, .biceps], ["surfing", "swimming", "general"], .beginner, false, "Simple substitute for pull-ups when needed."),
            exercise("Farmer Carry", .carry, [.dumbbells], [.back, .abs], ["hiking", "running", "general"], .beginner, false, "Loaded carry that builds trunk stiffness and work capacity."),
            exercise("Suitcase Carry", .carry, [.dumbbells], [.abs, .back], ["running", "surfing", "general"], .beginner, true, "Anti-lateral-flexion carry with unilateral loading."),
            exercise("Pallof Press", .core, [.cable], [.abs], ["running", "surfing", "golf"], .beginner, false, "Anti-rotation trunk work that is easy to dose."),
            exercise("Dead Bug", .core, [.bodyweight], [.abs], ["running", "general"], .beginner, false, "Foundational trunk-control pattern."),
            exercise("Side Plank", .core, [.bodyweight], [.abs, .glutes], ["running", "surfing", "general"], .beginner, false, "Simple anti-lateral-flexion core work."),
            exercise("Cable Chop", .core, [.cable], [.abs], ["surfing", "golf", "field sports"], .beginner, false, "Controlled rotational accessory for sport support.")
        ]
    }

    private static func exercise(
        _ name: String,
        _ movementPattern: ExerciseMovementPattern,
        _ requiredEquipment: [ExerciseEquipmentKind],
        _ primaryMuscles: [ExerciseBodyArea],
        _ goalSupportTags: [String],
        _ skillLevel: ExerciseSkillLevel,
        _ isUnilateral: Bool,
        _ notes: String
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
            source: .seeded
        )
    }

    var todayRoutineDay: RoutineDay? {
        let weekdayIndex = Calendar.current.component(.weekday, from: .now)
        let mappedWeekday = Weekday(rawValue: ((weekdayIndex + 5) % 7) + 1)
        return routineDays.first { $0.weekday == mappedWeekday }
    }

    var defaultLocation: LocationItem? {
        guard let locationID = todayRoutineDay?.defaultLocationID else { return nil }
        return locations.first { $0.id == locationID }
    }

    func setHealthSyncState(_ state: HealthSyncState) {
        healthSyncState = state
    }

    func upsertRoutineDay(_ routineDay: RoutineDay) {
        if let index = routineDays.firstIndex(where: { $0.id == routineDay.id }) {
            routineDays[index] = routineDay
        } else {
            routineDays.append(routineDay)
        }

        routineDays.sort { $0.weekday.rawValue < $1.weekday.rawValue }
    }

    func removeRoutineDay(id: UUID) {
        routineDays.removeAll { $0.id == id }
    }

    func moveGoals(fromOffsets: IndexSet, toOffset: Int) {
        goals.move(fromOffsets: fromOffsets, toOffset: toOffset)
    }

    func addGoalForRecurringActivity(_ activity: RecurringActivityItem) {
        let alreadyExists = goals.contains {
            $0.sourceKind == .recurringActivity &&
            $0.title.caseInsensitiveCompare(activity.activityType) == .orderedSame
        }

        guard !alreadyExists else { return }

        goals.append(
            GoalItem(
                id: UUID(),
                title: activity.activityType,
                sourceKind: .recurringActivity,
                emphasis: activity.emphasis
            )
        )
    }

    func removeRecurringActivity(id: UUID) {
        recurringActivities.removeAll { $0.id == id }
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

        for index in routineDays.indices where routineDays[index].defaultLocationID == id {
            routineDays[index].defaultLocationID = nil
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
            history = completedWorkouts
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
}
