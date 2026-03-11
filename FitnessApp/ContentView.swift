import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            GoalsScreen()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .tabItem {
                    Label("Goals", systemImage: "flag.checkered")
                }

            RoutineScreen()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .tabItem {
                    Label("Routine", systemImage: "calendar")
                }

            HistoryScreen()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .tabItem {
                    Label("History", systemImage: "clock.arrow.circlepath")
                }

            SettingsScreen()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarBackground(Color(.systemBackground), for: .tabBar)
    }
}

private struct GoalsScreen: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        NavigationStack {
            ScreenScrollContainer {
                AppCard {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Current Focus")
                                    .font(.headline)
                                Text("Top-ranked goal guidance for today")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            StatusBadge(
                                title: store.healthSyncState.title,
                                tint: healthStateColor
                            )
                        }

                        Divider()

                        Text(store.currentWorkout.summary)
                            .font(.title3.weight(.bold))

                        Text("Designed around goal priority, recent workout history, and your routine defaults.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                SectionTitle(title: "Ordered Goals")
                AppCard {
                    VStack(spacing: 10) {
                        ForEach(Array(store.goals.enumerated()), id: \.element.id) { index, goal in
                            GoalRow(index: index + 1, goal: goal)
                            if index < store.goals.count - 1 {
                                Divider()
                            }
                        }
                    }
                }

                SectionTitle(title: "Detected Activities")
                AppCard {
                    if store.recurringActivities.isEmpty {
                        EmptyCardMessage(message: "No detected activities yet. Connect Apple Health and refresh to pull in recurring activity types.")
                    } else {
                        VStack(spacing: 10) {
                            ForEach(Array(store.recurringActivities.enumerated()), id: \.element.id) { index, activity in
                                ActivityRow(activity: activity)
                                if index < store.recurringActivities.count - 1 {
                                    Divider()
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Goals")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var healthStateColor: Color {
        switch store.healthSyncState {
        case .notConnected:
            .secondary
        case .connected, .refreshed:
            .green
        case .refreshing:
            .blue
        case .failed:
            .red
        }
    }
}

private struct RoutineScreen: View {
    @EnvironmentObject private var store: AppStore
    @State private var editingRoutineDay: RoutineDay?
    @State private var isAddingRoutineDay = false

    var body: some View {
        NavigationStack {
            ScreenScrollContainer {
                AppCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Weekly Training Plan")
                            .font(.headline)
                        Text("Edit your lifting days, target body parts, and default watch workout settings.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack {
                    SectionTitle(title: "Weekly Plan")
                    Spacer()
                    Button {
                        isAddingRoutineDay = true
                    } label: {
                        Label("Add Day", systemImage: "plus")
                            .font(.subheadline.weight(.semibold))
                    }
                }

                VStack(spacing: 10) {
                    if store.routineDays.isEmpty {
                        AppCard {
                            EmptyCardMessage(message: "No routine days yet. Add one to prefill workout defaults on Apple Watch.")
                        }
                    } else {
                        ForEach(store.routineDays) { routineDay in
                            AppCard {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack(alignment: .top) {
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text(routineDay.weekday.title)
                                                .font(.headline)
                                            Text(routineDay.focusSummary)
                                                .font(.subheadline.weight(.medium))
                                                .foregroundStyle(.secondary)
                                        }

                                        Spacer()

                                        HStack(spacing: 8) {
                                            SmallIconButton(systemImage: "pencil") {
                                                editingRoutineDay = routineDay
                                            }

                                            SmallIconButton(systemImage: "trash", tint: .red) {
                                                store.removeRoutineDay(id: routineDay.id)
                                                store.persist()
                                            }
                                        }
                                    }

                                    Label(routineDefaultsText(for: routineDay), systemImage: "figure.strengthtraining.traditional")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Routine")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $editingRoutineDay) { routineDay in
                RoutineDayEditorView(
                    title: "Edit Routine Day",
                    initialRoutineDay: routineDay,
                    locations: store.locations,
                    unavailableWeekdays: Set(store.routineDays.map(\.weekday))
                ) { updatedRoutineDay in
                    store.upsertRoutineDay(updatedRoutineDay)
                    store.persist()
                }
            }
            .sheet(isPresented: $isAddingRoutineDay) {
                RoutineDayEditorView(
                    title: "Add Routine Day",
                    initialRoutineDay: nil,
                    locations: store.locations,
                    unavailableWeekdays: Set(store.routineDays.map(\.weekday))
                ) { newRoutineDay in
                    store.upsertRoutineDay(newRoutineDay)
                    store.persist()
                }
            }
        }
    }

    private func routineDefaultsText(for routineDay: RoutineDay) -> String {
        let locationName = store.locations.first(where: { $0.id == routineDay.defaultLocationID })?.name ?? "No location"
        let durationText = routineDay.defaultDurationMinutes.map { "\($0) minutes" } ?? "No duration"
        return "\(durationText) at \(locationName)"
    }

}

private struct HistoryScreen: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        NavigationStack {
            ScreenScrollContainer {
                AppCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Recent Workouts")
                            .font(.headline)
                        Text("Imported Apple Health sessions and in-app history live here.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                SectionTitle(title: "Completed Sessions")
                VStack(spacing: 10) {
                    ForEach(store.history) { workout in
                        AppCard {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(alignment: .top) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(workout.summary)
                                            .font(.headline)
                                        Text(workout.date.formatted(date: .abbreviated, time: .omitted))
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text("\(workout.durationMinutes) min")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(.secondary)
                                }

                                Label(workout.locationName, systemImage: "mappin.and.ellipse")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct SettingsScreen: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var healthSyncController: HealthSyncController
    @State private var editingLocation: LocationItem?
    @State private var isAddingLocation = false
    @State private var editingEquipment: EquipmentItem?
    @State private var isAddingEquipment = false
    @State private var editingExercise: ExerciseLibraryItem?
    @State private var isAddingExercise = false

    var body: some View {
        NavigationStack {
            ScreenScrollContainer {
                AppCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Training Setup")
                            .font(.headline)

                        Text("Manage the saved data the app uses to build workouts and prefill the watch experience.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        Divider()

                        KeyValueRow(label: "Locations", value: "\(store.locations.count)")
                        Divider()
                        KeyValueRow(label: "Equipment Items", value: "\(store.equipmentCatalog.count)")
                        Divider()
                        KeyValueRow(label: "Exercises", value: "\(store.exerciseLibrary.count)")
                    }
                }

                HStack {
                    SectionTitle(title: "Exercise Library")
                    Spacer()
                    Button {
                        isAddingExercise = true
                    } label: {
                        Label("Add Exercise", systemImage: "plus")
                            .font(.subheadline.weight(.semibold))
                    }
                }

                AppCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("\(store.exerciseLibrary.count) exercises available")
                            .font(.headline)

                        Text("The recommendation engine can choose from built-in and custom lifting options with movement, equipment, and body-part metadata.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        FlexibleTagRow(tags: exerciseLibraryHighlights)
                    }
                }

                VStack(spacing: 10) {
                    ForEach(store.exerciseLibrary) { exercise in
                        AppCard {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(alignment: .top) {
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack(spacing: 8) {
                                            Text(exercise.name)
                                                .font(.headline)

                                            Text(exercise.source.title)
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(exercise.source == .custom ? .green : .secondary)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background((exercise.source == .custom ? Color.green : Color.secondary).opacity(0.12), in: Capsule())
                                        }

                                        Text(exercise.movementPattern.title)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    HStack(spacing: 8) {
                                        SmallIconButton(systemImage: "pencil") {
                                            editingExercise = exercise
                                        }

                                        if exercise.source == .custom {
                                            SmallIconButton(systemImage: "trash", tint: .red) {
                                                store.removeExerciseLibraryItem(id: exercise.id)
                                                store.persist()
                                            }
                                        }
                                    }
                                }

                                Text(exercise.notes)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)

                                FlexibleTagRow(tags: exercise.primaryMuscles.map(\.title))

                                FlexibleTagRow(tags: exercise.requiredEquipment.map(\.title))
                            }
                        }
                    }
                }

                AppCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Health Sync")
                            .font(.headline)

                        Text("Manage Apple Health permissions and keep detected activities current.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        Divider()

                        KeyValueRow(label: "Status", value: store.healthSyncState.title)

                        Divider()

                        FeatureRow(
                            title: "Refresh Apple Health on launch",
                            systemImage: "heart.text.square"
                        )

                        Divider()

                        FeatureRow(
                            title: "Append new detected activities to the bottom",
                            systemImage: "arrow.down.to.line"
                        )
                    }
                }

                AppCard {
                    VStack(spacing: 10) {
                        WideActionButton(
                            title: "Connect Apple Health",
                            tint: .blue
                        ) {
                            Task {
                                await healthSyncController.connectAndRefresh(using: store)
                            }
                        }

                        WideActionButton(
                            title: "Refresh Now",
                            tint: .green
                        ) {
                            Task {
                                await healthSyncController.refresh(using: store)
                            }
                        }
                    }
                }

                HStack {
                    SectionTitle(title: "Locations")
                    Spacer()
                    Button {
                        isAddingLocation = true
                    } label: {
                        Label("Add Location", systemImage: "plus")
                            .font(.subheadline.weight(.semibold))
                    }
                }

                VStack(spacing: 10) {
                    if store.locations.isEmpty {
                        AppCard {
                            EmptyCardMessage(message: "No saved locations yet. Add one so routines can set watch defaults.")
                        }
                    } else {
                        ForEach(store.locations) { location in
                            AppCard {
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack(alignment: .top) {
                                        Text(location.name)
                                            .font(.headline)

                                        Spacer()

                                        HStack(spacing: 8) {
                                            SmallIconButton(systemImage: "pencil") {
                                                editingLocation = location
                                            }

                                            SmallIconButton(systemImage: "trash", tint: .red) {
                                                store.removeLocation(id: location.id)
                                                store.persist()
                                            }
                                        }
                                    }

                                    Text(locationEquipmentSummary(for: location))
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                HStack {
                    SectionTitle(title: "Equipment Catalog")
                    Spacer()
                    Button {
                        isAddingEquipment = true
                    } label: {
                        Label("Add Equipment", systemImage: "plus")
                            .font(.subheadline.weight(.semibold))
                    }
                }

                VStack(spacing: 10) {
                    ForEach(store.equipmentCatalog) { equipment in
                        AppCard {
                            HStack {
                                Text(equipment.name)
                                    .font(.headline)

                                Spacer()

                                HStack(spacing: 8) {
                                    SmallIconButton(systemImage: "pencil") {
                                        editingEquipment = equipment
                                    }

                                    SmallIconButton(systemImage: "trash", tint: .red) {
                                        store.removeEquipmentItem(id: equipment.id)
                                        store.persist()
                                    }
                                }
                            }
                        }
                    }
                }

                SectionTitle(title: "Today")
                AppCard {
                    if let routineDay = store.todayRoutineDay {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Today's default")
                                .font(.headline)
                            Text("\(routineDay.weekday.title) • \(routineDay.focusSummary)")
                                .font(.subheadline)
                            Text(routineDefaultsText(for: routineDay))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        EmptyCardMessage(message: "No routine defaults configured for today.")
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $editingLocation) { location in
                LocationEditorView(
                    title: "Edit Location",
                    initialLocation: location,
                    equipmentCatalog: store.equipmentCatalog
                ) { updatedLocation in
                    store.upsertLocation(updatedLocation)
                    store.persist()
                }
            }
            .sheet(isPresented: $isAddingLocation) {
                LocationEditorView(
                    title: "Add Location",
                    initialLocation: nil,
                    equipmentCatalog: store.equipmentCatalog
                ) { newLocation in
                    store.upsertLocation(newLocation)
                    store.persist()
                }
            }
            .sheet(item: $editingEquipment) { equipment in
                EquipmentEditorView(
                    title: "Edit Equipment",
                    initialEquipment: equipment
                ) { updatedEquipment in
                    store.upsertEquipmentItem(updatedEquipment)
                    store.persist()
                }
            }
            .sheet(isPresented: $isAddingEquipment) {
                EquipmentEditorView(
                    title: "Add Equipment",
                    initialEquipment: nil
                ) { newEquipment in
                    store.upsertEquipmentItem(newEquipment)
                    store.persist()
                }
            }
            .sheet(item: $editingExercise) { exercise in
                ExerciseEditorView(
                    title: "Edit Exercise",
                    initialExercise: exercise
                ) { updatedExercise in
                    store.upsertExerciseLibraryItem(updatedExercise)
                    store.persist()
                }
            }
            .sheet(isPresented: $isAddingExercise) {
                ExerciseEditorView(
                    title: "Add Exercise",
                    initialExercise: nil
                ) { newExercise in
                    store.upsertExerciseLibraryItem(newExercise)
                    store.persist()
                }
            }
        }
    }

    private func routineDefaultsText(for routineDay: RoutineDay) -> String {
        let locationName = store.locations.first(where: { $0.id == routineDay.defaultLocationID })?.name ?? "No location"
        let durationText = routineDay.defaultDurationMinutes.map { "\($0) minutes" } ?? "No duration"
        return "\(durationText) at \(locationName)"
    }

    private func locationEquipmentSummary(for location: LocationItem) -> String {
        if !location.equipmentIDs.isEmpty {
            return store.equipmentSummary(for: location.equipmentIDs)
        }

        return location.equipmentSummary
    }

    private var exerciseLibraryHighlights: [String] {
        let patternTitles = Set(store.exerciseLibrary.map { $0.movementPattern.title })
        return Array(patternTitles).sorted()
    }
}

private struct ScreenIntro: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.title3.weight(.semibold))
            Text(subtitle)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

private struct ScreenScrollContainer<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    content
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct SectionTitle: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .tracking(0.8)
    }
}

private struct AppCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct StatusBadge: View {
    let title: String
    let tint: Color

    var body: some View {
        Text(title)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(tint.opacity(0.14), in: Capsule())
    }
}

private struct GoalRow: View {
    let index: Int
    let goal: GoalItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(index)")
                .font(.subheadline.weight(.semibold))
                .frame(width: 24, height: 24)
                .background(Color.blue.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 6) {
                Text(goal.title)
                    .font(.subheadline.weight(.semibold))

                Text(goal.sourceKind == .event ? "Event goal" : "Recurring activity")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if let emphasis = goal.emphasis {
                    Text(emphasis.rawValue.capitalized)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.12), in: Capsule())
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ActivityRow: View {
    let activity: RecurringActivityItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(activity.activityType)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(activity.emphasis.rawValue.capitalized)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.12), in: Capsule())
            }

            if activity.isDetectedFromHealth {
                Label("Detected from Apple Health", systemImage: "waveform.path.ecg")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct FeatureRow: View {
    let title: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(.blue)
                .frame(width: 24)

            Text(title)
                .font(.subheadline)
        }
    }
}

private struct KeyValueRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.headline)
            Spacer()
            Text(value)
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }
}

private struct EmptyCardMessage: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct FlexibleTagRow: View {
    let tags: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(chunkedTags, id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(row, id: \.self) { tag in
                        Text(tag)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.blue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Color.blue.opacity(0.12), in: Capsule())
                    }

                    Spacer(minLength: 0)
                }
            }
        }
    }

    private var chunkedTags: [[String]] {
        stride(from: 0, to: tags.count, by: 3).map { index in
            Array(tags[index..<min(index + 3, tags.count)])
        }
    }
}

private struct WideActionButton: View {
    let title: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(.borderedProminent)
        .tint(tint)
    }
}

private struct SmallIconButton: View {
    let systemImage: String
    var tint: Color = .blue
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .frame(width: 32, height: 32)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .foregroundStyle(tint)
        .buttonStyle(.plain)
    }
}

private struct RoutineDayEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let initialRoutineDay: RoutineDay?
    let locations: [LocationItem]
    let unavailableWeekdays: Set<Weekday>
    let onSave: (RoutineDay) -> Void

    @State private var selectedWeekday: Weekday
    @State private var selectedFocusAreas: Set<ExerciseBodyArea>
    @State private var selectedLocationID: UUID?
    @State private var selectedDurationMinutes: Int?

    init(
        title: String,
        initialRoutineDay: RoutineDay?,
        locations: [LocationItem],
        unavailableWeekdays: Set<Weekday>,
        onSave: @escaping (RoutineDay) -> Void
    ) {
        self.title = title
        self.initialRoutineDay = initialRoutineDay
        self.locations = locations
        self.unavailableWeekdays = unavailableWeekdays
        self.onSave = onSave

        _selectedWeekday = State(initialValue: initialRoutineDay?.weekday ?? .monday)
        _selectedFocusAreas = State(initialValue: Set(initialRoutineDay?.focusAreas ?? []))
        _selectedLocationID = State(initialValue: initialRoutineDay?.defaultLocationID)
        _selectedDurationMinutes = State(initialValue: initialRoutineDay?.defaultDurationMinutes)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Routine Day") {
                    Picker("Weekday", selection: $selectedWeekday) {
                        ForEach(availableWeekdays, id: \.self) { weekday in
                            Text(weekday.title).tag(weekday)
                        }
                    }
                }

                Section("Target Body Parts") {
                    ForEach(ExerciseBodyArea.allCases) { area in
                        Toggle(
                            area.title,
                            isOn: Binding(
                                get: { selectedFocusAreas.contains(area) },
                                set: { isSelected in
                                    if isSelected {
                                        selectedFocusAreas.insert(area)
                                    } else {
                                        selectedFocusAreas.remove(area)
                                    }
                                }
                            )
                        )
                    }
                }

                Section("Watch Defaults") {
                    Picker("Default Location", selection: $selectedLocationID) {
                        Text("No default").tag(UUID?.none)
                        ForEach(locations) { location in
                            Text(location.name).tag(Optional(location.id))
                        }
                    }

                    Picker("Default Duration", selection: $selectedDurationMinutes) {
                        Text("No default").tag(Int?.none)
                        ForEach([10, 15, 20, 30, 45, 60], id: \.self) { duration in
                            Text("\(duration) min").tag(Optional(duration))
                        }
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let routineDay = RoutineDay(
                            id: initialRoutineDay?.id ?? UUID(),
                            weekday: selectedWeekday,
                            focusAreas: ExerciseBodyArea.allCases.filter { selectedFocusAreas.contains($0) },
                            defaultLocationID: selectedLocationID,
                            defaultDurationMinutes: selectedDurationMinutes
                        )
                        onSave(routineDay)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private var availableWeekdays: [Weekday] {
        let currentWeekday = initialRoutineDay?.weekday
        return Weekday.allCases.filter { weekday in
            weekday == currentWeekday || !unavailableWeekdays.contains(weekday)
        }
    }

    private var canSave: Bool {
        !selectedFocusAreas.isEmpty && !availableWeekdays.isEmpty
    }
}

private struct LocationEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let initialLocation: LocationItem?
    let equipmentCatalog: [EquipmentItem]
    let onSave: (LocationItem) -> Void

    @State private var name: String
    @State private var selectedEquipmentIDs: Set<UUID>

    init(
        title: String,
        initialLocation: LocationItem?,
        equipmentCatalog: [EquipmentItem],
        onSave: @escaping (LocationItem) -> Void
    ) {
        self.title = title
        self.initialLocation = initialLocation
        self.equipmentCatalog = equipmentCatalog
        self.onSave = onSave

        _name = State(initialValue: initialLocation?.name ?? "")
        _selectedEquipmentIDs = State(initialValue: Set(initialLocation?.equipmentIDs ?? []))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Location") {
                    TextField("Name", text: $name)
                        .textInputAutocapitalization(.words)
                }

                Section("Available Equipment") {
                    if equipmentCatalog.isEmpty {
                        Text("No equipment defined yet. Add equipment from Settings first.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(equipmentCatalog) { equipment in
                            Toggle(
                                equipment.name,
                                isOn: Binding(
                                    get: { selectedEquipmentIDs.contains(equipment.id) },
                                    set: { isSelected in
                                        if isSelected {
                                            selectedEquipmentIDs.insert(equipment.id)
                                        } else {
                                            selectedEquipmentIDs.remove(equipment.id)
                                        }
                                    }
                                )
                            )
                        }
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let selectedNames = equipmentCatalog
                            .filter { selectedEquipmentIDs.contains($0.id) }
                            .map(\.name)
                            .sorted()
                        let location = LocationItem(
                            id: initialLocation?.id ?? UUID(),
                            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                            equipmentSummary: selectedNames.joined(separator: ", "),
                            equipmentIDs: Array(selectedEquipmentIDs).sorted { lhs, rhs in
                                let lhsName = equipmentCatalog.first(where: { $0.id == lhs })?.name ?? ""
                                let rhsName = equipmentCatalog.first(where: { $0.id == rhs })?.name ?? ""
                                return lhsName < rhsName
                            }
                        )
                        onSave(location)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

private struct EquipmentEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let initialEquipment: EquipmentItem?
    let onSave: (EquipmentItem) -> Void

    @State private var name: String

    init(
        title: String,
        initialEquipment: EquipmentItem?,
        onSave: @escaping (EquipmentItem) -> Void
    ) {
        self.title = title
        self.initialEquipment = initialEquipment
        self.onSave = onSave
        _name = State(initialValue: initialEquipment?.name ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Equipment") {
                    TextField("Name", text: $name)
                        .textInputAutocapitalization(.words)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(
                            EquipmentItem(
                                id: initialEquipment?.id ?? UUID(),
                                name: trimmedName
                            )
                        )
                        dismiss()
                    }
                    .disabled(trimmedName.isEmpty)
                }
            }
        }
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct ExerciseEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let initialExercise: ExerciseLibraryItem?
    let onSave: (ExerciseLibraryItem) -> Void

    @State private var name: String
    @State private var movementPattern: ExerciseMovementPattern
    @State private var skillLevel: ExerciseSkillLevel
    @State private var notes: String
    @State private var primaryMuscles: Set<ExerciseBodyArea>
    @State private var goalSupportTagsText: String
    @State private var isUnilateral: Bool
    @State private var requiredEquipment: Set<ExerciseEquipmentKind>

    init(
        title: String,
        initialExercise: ExerciseLibraryItem?,
        onSave: @escaping (ExerciseLibraryItem) -> Void
    ) {
        self.title = title
        self.initialExercise = initialExercise
        self.onSave = onSave

        _name = State(initialValue: initialExercise?.name ?? "")
        _movementPattern = State(initialValue: initialExercise?.movementPattern ?? .squat)
        _skillLevel = State(initialValue: initialExercise?.skillLevel ?? .beginner)
        _notes = State(initialValue: initialExercise?.notes ?? "")
        _primaryMuscles = State(initialValue: Set(initialExercise?.primaryMuscles ?? []))
        _goalSupportTagsText = State(initialValue: initialExercise?.goalSupportTags.joined(separator: ", ") ?? "")
        _isUnilateral = State(initialValue: initialExercise?.isUnilateral ?? false)
        _requiredEquipment = State(initialValue: Set(initialExercise?.requiredEquipment ?? []))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Exercise") {
                    TextField("Name", text: $name)
                        .textInputAutocapitalization(.words)

                    Picker("Movement Pattern", selection: $movementPattern) {
                        ForEach(ExerciseMovementPattern.allCases) { pattern in
                            Text(pattern.title).tag(pattern)
                        }
                    }

                    Picker("Skill Level", selection: $skillLevel) {
                        ForEach(ExerciseSkillLevel.allCases) { level in
                            Text(level.rawValue.capitalized).tag(level)
                        }
                    }

                    Toggle("Unilateral", isOn: $isUnilateral)
                }

                Section("Equipment") {
                    ForEach(ExerciseEquipmentKind.allCases) { equipment in
                        Toggle(
                            equipment.title,
                            isOn: Binding(
                                get: { requiredEquipment.contains(equipment) },
                                set: { isSelected in
                                    if isSelected {
                                        requiredEquipment.insert(equipment)
                                    } else {
                                        requiredEquipment.remove(equipment)
                                    }
                                }
                            )
                        )
                    }
                }

                Section("Target Body Parts") {
                    ForEach(ExerciseBodyArea.allCases) { area in
                        Toggle(
                            area.title,
                            isOn: Binding(
                                get: { primaryMuscles.contains(area) },
                                set: { isSelected in
                                    if isSelected {
                                        primaryMuscles.insert(area)
                                    } else {
                                        primaryMuscles.remove(area)
                                    }
                                }
                            )
                        )
                    }
                }

                Section("Tags") {
                    TextField("Goal Support Tags", text: $goalSupportTagsText, axis: .vertical)
                        .lineLimit(2...4)
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let exercise = ExerciseLibraryItem(
                            id: initialExercise?.id ?? UUID(),
                            name: trimmedName,
                            movementPattern: movementPattern,
                            requiredEquipment: requiredEquipment.sorted { $0.title < $1.title },
                            primaryMuscles: ExerciseBodyArea.allCases.filter { primaryMuscles.contains($0) },
                            goalSupportTags: splitList(goalSupportTagsText),
                            skillLevel: skillLevel,
                            isUnilateral: isUnilateral,
                            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
                            source: initialExercise?.source ?? .custom
                        )
                        onSave(exercise)
                        dismiss()
                    }
                    .disabled(trimmedName.isEmpty || primaryMuscles.isEmpty)
                }
            }
        }
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func splitList(_ text: String) -> [String] {
        text
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppStore())
        .environmentObject(HealthSyncController())
}
