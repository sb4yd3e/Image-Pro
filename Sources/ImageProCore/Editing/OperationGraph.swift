import Foundation

public struct OperationGraph: Codable, Hashable, Sendable {
    public private(set) var operations: [EditOperation]
    public private(set) var cursor: Int

    public init(operations: [EditOperation] = [], cursor: Int? = nil) {
        self.operations = operations
        self.cursor = min(max(cursor ?? operations.count, 0), operations.count)
    }

    public var activeOperations: ArraySlice<EditOperation> {
        operations.prefix(cursor)
    }

    public var canUndo: Bool { cursor > 0 }
    public var canRedo: Bool { cursor < operations.count }

    public mutating func append(_ operation: EditOperation) {
        if cursor < operations.count {
            operations.removeSubrange(cursor...)
        }
        operations.append(operation)
        cursor = operations.count
    }

    @discardableResult
    public mutating func undo() -> EditOperation? {
        guard canUndo else { return nil }
        cursor -= 1
        return operations[cursor]
    }

    @discardableResult
    public mutating func redo() -> EditOperation? {
        guard canRedo else { return nil }
        let operation = operations[cursor]
        cursor += 1
        return operation
    }
}
