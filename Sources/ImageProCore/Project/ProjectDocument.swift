import Foundation

public struct ProjectDocument: Codable, Hashable, Sendable {
    public static let currentSchemaVersion = 3

    public var schemaVersion: Int
    public var id: UUID
    public var sourceRelativePath: String
    public var sourceSHA256: String
    public var editingBaseRelativePath: String?
    public var activeRelativePath: String?
    public var operationGraph: OperationGraph
    public var maskDocument: MaskDocument?
    public var renderedUndoRelativePaths: [String]?
    public var renderedRedoRelativePaths: [String]?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        sourceRelativePath: String,
        sourceSHA256: String,
        editingBaseRelativePath: String? = nil,
        activeRelativePath: String? = nil,
        operationGraph: OperationGraph = OperationGraph(),
        maskDocument: MaskDocument? = nil,
        renderedUndoRelativePaths: [String]? = nil,
        renderedRedoRelativePaths: [String]? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.schemaVersion = Self.currentSchemaVersion
        self.id = id
        self.sourceRelativePath = sourceRelativePath
        self.sourceSHA256 = sourceSHA256
        self.editingBaseRelativePath = editingBaseRelativePath
        self.activeRelativePath = activeRelativePath
        self.operationGraph = operationGraph
        self.maskDocument = maskDocument
        self.renderedUndoRelativePaths = renderedUndoRelativePaths
        self.renderedRedoRelativePaths = renderedRedoRelativePaths
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct ProjectSnapshot: Sendable {
    public var document: ProjectDocument
    public var sourceData: Data
    public var editingBaseData: Data
    public var activeData: Data
    public var renderedUndoData: [Data]
    public var renderedRedoData: [Data]

    public init(
        document: ProjectDocument,
        sourceData: Data,
        editingBaseData: Data,
        activeData: Data,
        renderedUndoData: [Data] = [],
        renderedRedoData: [Data] = []
    ) {
        self.document = document
        self.sourceData = sourceData
        self.editingBaseData = editingBaseData
        self.activeData = activeData
        self.renderedUndoData = renderedUndoData
        self.renderedRedoData = renderedRedoData
    }
}

public enum ProjectStoreError: Error, Equatable {
    case unsupportedSchema(Int)
}
