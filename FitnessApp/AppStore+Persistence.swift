import Foundation

@MainActor
extension AppStore {
    func bootstrapFromPersistence(using persistenceController: PersistenceController = .shared) {
        do {
            if let snapshot = try persistenceController.loadSnapshot() {
                apply(snapshot: snapshot)
            } else {
                try persistenceController.saveSnapshot(snapshot)
            }
        } catch {
            print("Failed to bootstrap persisted app state: \(error.localizedDescription)")
        }
    }

    func persist(using persistenceController: PersistenceController = .shared) {
        do {
            try persistenceController.saveSnapshot(snapshot)
        } catch {
            print("Failed to persist app state: \(error.localizedDescription)")
        }
    }
}
