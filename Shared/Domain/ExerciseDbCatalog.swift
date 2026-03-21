import Foundation

/// Rich metadata from ExerciseDB (bundled JSON), keyed by `catalogSlug` matching `exercise-mapping.json` `app_id`.
struct ExerciseDbCatalogEntry: Equatable, Hashable, Codable {
    var matched: Bool
    var exerciseDbId: String?
    var exerciseDbName: String?
    var gifURL: String?
    var targetMuscles: [String]
    var bodyParts: [String]
    var equipments: [String]
    var secondaryMuscles: [String]
    var instructions: [String]

    enum CodingKeys: String, CodingKey {
        case matched
        case exerciseDbId
        case exerciseDbName
        case gifURL = "gifUrl"
        case targetMuscles
        case bodyParts
        case equipments
        case secondaryMuscles
        case instructions
    }

    /// Turns API "Step:1 …" lines into numbered steps for display.
    static func formattedInstructions(_ steps: [String]) -> String {
        steps.enumerated().map { index, raw in
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            let body: String
            if let range = trimmed.range(of: #"^Step:\d+\s*"#, options: .regularExpression) {
                body = String(trimmed[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                body = trimmed
            }
            return "\(index + 1). \(body)"
        }.joined(separator: "\n")
    }
}

private struct ExerciseDbCatalogFile: Codable {
    var version: Int
    var exercises: [ExerciseDbCatalogFileRow]
}

private struct ExerciseDbCatalogFileRow: Codable {
    var id: String
    var matched: Bool?
    var exerciseDbId: String?
    var exerciseDbName: String?
    var gifUrl: String?
    var targetMuscles: [String]?
    var bodyParts: [String]?
    var equipments: [String]?
    var secondaryMuscles: [String]?
    var instructions: [String]?

    func asEntry() -> ExerciseDbCatalogEntry {
        ExerciseDbCatalogEntry(
            matched: matched ?? false,
            exerciseDbId: exerciseDbId,
            exerciseDbName: exerciseDbName,
            gifURL: gifUrl,
            targetMuscles: targetMuscles ?? [],
            bodyParts: bodyParts ?? [],
            equipments: equipments ?? [],
            secondaryMuscles: secondaryMuscles ?? [],
            instructions: instructions ?? []
        )
    }
}

enum ExerciseDbCatalog {
    private static let entriesBySlug: [String: ExerciseDbCatalogEntry] = {
        guard let url = Bundle.main.url(forResource: "exercise-db-catalog", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(ExerciseDbCatalogFile.self, from: data)
        else {
            return [:]
        }
        var map: [String: ExerciseDbCatalogEntry] = [:]
        map.reserveCapacity(file.exercises.count)
        for row in file.exercises {
            map[row.id] = row.asEntry()
        }
        return map
    }()

    static func entry(forCatalogSlug slug: String?) -> ExerciseDbCatalogEntry? {
        guard let slug else { return nil }
        return entriesBySlug[slug]
    }
}
