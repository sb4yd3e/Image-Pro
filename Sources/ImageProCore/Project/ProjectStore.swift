import Foundation

public actor ProjectStore {
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init() {
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    public func save(_ project: ProjectDocument, to packageURL: URL) throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: packageURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: packageURL.appendingPathComponent("assets/masks"), withIntermediateDirectories: true)
        try fileManager.createDirectory(at: packageURL.appendingPathComponent("renders/previews"), withIntermediateDirectories: true)
        try fileManager.createDirectory(at: packageURL.appendingPathComponent("renders/ai-results"), withIntermediateDirectories: true)

        var updated = project
        updated.updatedAt = Date()
        let data = try encoder.encode(updated)
        try data.write(to: packageURL.appendingPathComponent("project.json"), options: .atomic)
    }

    public func load(from packageURL: URL) throws -> ProjectDocument {
        let data = try Data(contentsOf: packageURL.appendingPathComponent("project.json"))
        let project = try decoder.decode(ProjectDocument.self, from: data)
        guard project.schemaVersion <= ProjectDocument.currentSchemaVersion else {
            throw ProjectStoreError.unsupportedSchema(project.schemaVersion)
        }
        return project
    }

    public func saveSnapshot(_ snapshot: ProjectSnapshot, to packageURL: URL) throws {
        var project = snapshot.document
        project.sourceRelativePath = "assets/original.image"
        project.editingBaseRelativePath = "assets/editing-base.image"
        project.activeRelativePath = "renders/previews/current.image"
        let historyDirectory = packageURL.appendingPathComponent("renders/history", isDirectory: true)
        try? FileManager.default.removeItem(at: historyDirectory)
        try FileManager.default.createDirectory(at: historyDirectory, withIntermediateDirectories: true)
        project.renderedUndoRelativePaths = try writeHistory(
            snapshot.renderedUndoData,
            prefix: "undo",
            packageURL: packageURL
        )
        project.renderedRedoRelativePaths = try writeHistory(
            snapshot.renderedRedoData,
            prefix: "redo",
            packageURL: packageURL
        )

        try FileManager.default.createDirectory(
            at: packageURL.appendingPathComponent("assets", isDirectory: true),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: packageURL.appendingPathComponent("renders/previews", isDirectory: true),
            withIntermediateDirectories: true
        )
        try snapshot.sourceData.write(
            to: packageURL.appendingPathComponent(project.sourceRelativePath),
            options: .atomic
        )
        try snapshot.editingBaseData.write(
            to: packageURL.appendingPathComponent(project.editingBaseRelativePath!),
            options: .atomic
        )
        try snapshot.activeData.write(
            to: packageURL.appendingPathComponent(project.activeRelativePath!),
            options: .atomic
        )
        try save(project, to: packageURL)
    }

    public func loadSnapshot(from packageURL: URL) throws -> ProjectSnapshot {
        let project = try load(from: packageURL)
        let source = try Data(contentsOf: packageURL.appendingPathComponent(project.sourceRelativePath))
        let editingBasePath = project.editingBaseRelativePath ?? project.sourceRelativePath
        let activePath = project.activeRelativePath ?? editingBasePath
        return ProjectSnapshot(
            document: project,
            sourceData: source,
            editingBaseData: try Data(contentsOf: packageURL.appendingPathComponent(editingBasePath)),
            activeData: try Data(contentsOf: packageURL.appendingPathComponent(activePath)),
            renderedUndoData: readHistory(project.renderedUndoRelativePaths, packageURL: packageURL),
            renderedRedoData: readHistory(project.renderedRedoRelativePaths, packageURL: packageURL)
        )
    }

    private func writeHistory(_ items: [Data], prefix: String, packageURL: URL) throws -> [String] {
        try items.enumerated().map { index, data in
            let path = "renders/history/\(prefix)-\(index).image"
            try data.write(to: packageURL.appendingPathComponent(path), options: .atomic)
            return path
        }
    }

    private func readHistory(_ paths: [String]?, packageURL: URL) -> [Data] {
        (paths ?? []).compactMap { try? Data(contentsOf: packageURL.appendingPathComponent($0)) }
    }
}
