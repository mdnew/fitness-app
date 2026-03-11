import Foundation
import SwiftData

@Model
final class PersistedAppState {
    var key: String
    var payload: Data
    var updatedAt: Date

    init(key: String, payload: Data, updatedAt: Date = .now) {
        self.key = key
        self.payload = payload
        self.updatedAt = updatedAt
    }
}

@MainActor
final class PersistenceController {
    static let shared = PersistenceController()

    private let snapshotKey = "primary-app-state"
    let container: ModelContainer

    private init() {
        do {
            container = try ModelContainer(for: PersistedAppState.self)
        } catch {
            fatalError("Failed to create SwiftData container: \(error.localizedDescription)")
        }
    }

    func loadSnapshot() throws -> AppSnapshot? {
        let descriptor = FetchDescriptor<PersistedAppState>(
            predicate: #Predicate { $0.key == "primary-app-state" }
        )

        let context = ModelContext(container)
        guard let record = try context.fetch(descriptor).first else {
            return nil
        }

        return try JSONDecoder().decode(AppSnapshot.self, from: record.payload)
    }

    func saveSnapshot(_ snapshot: AppSnapshot) throws {
        let descriptor = FetchDescriptor<PersistedAppState>(
            predicate: #Predicate { $0.key == "primary-app-state" }
        )

        let context = ModelContext(container)
        let payload = try JSONEncoder().encode(snapshot)
        let record = try context.fetch(descriptor).first ?? PersistedAppState(key: snapshotKey, payload: payload)
        record.payload = payload
        record.updatedAt = .now

        if record.modelContext == nil {
            context.insert(record)
        }

        try context.save()
    }
}
