import Foundation

enum SchemaVersion {
    static let current = 1

    static func migrate(_ data: Data) throws -> Data {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        struct VersionProbe: Decodable {
            var schemaVersion: Int?
        }

        let probe = try decoder.decode(VersionProbe.self, from: data)
        let version = probe.schemaVersion ?? 1

        if version == current {
            return data
        }

        if version > current {
            throw SchemaError.newerThanSupported(version)
        }

        var migrated = data
        for v in version..<current {
            migrated = try applyMigration(from: v, data: migrated)
        }
        return migrated
    }

    private static func applyMigration(from version: Int, data: Data) throws -> Data {
        switch version {
        // Future: case 1: return migrateV1toV2(data)
        default:
            throw SchemaError.noMigrationPath(from: version)
        }
    }
}

enum SchemaError: LocalizedError {
    case newerThanSupported(Int)
    case noMigrationPath(from: Int)
    case corruptedDocument(String)

    var errorDescription: String? {
        switch self {
        case .newerThanSupported(let v):
            "This document was created with a newer version of Tiza (schema \(v)). Please update the app."
        case .noMigrationPath(let v):
            "Cannot migrate document from schema version \(v)."
        case .corruptedDocument(let detail):
            "The document appears to be corrupted: \(detail)"
        }
    }
}
