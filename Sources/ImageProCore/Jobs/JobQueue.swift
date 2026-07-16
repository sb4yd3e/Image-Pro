import Foundation

public enum JobKind: String, Codable, Hashable, Sendable {
    case optimize
    case removeBackground
    case upscale
    case inpaint
    case generativeFill
    case export
}

public enum JobStatus: String, Codable, Hashable, Sendable {
    case queued
    case preparing
    case running
    case writing
    case completed
    case cancelled
    case failed
}

public struct JobRecord: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let kind: JobKind
    public var inputPath: String
    public var outputPath: String?
    public var status: JobStatus
    public var progress: Double?
    public var retryCount: Int
    public var errorSummary: String?
    public let createdAt: Date
    public var updatedAt: Date

    public init(id: UUID = UUID(), kind: JobKind, inputPath: String, outputPath: String? = nil) {
        self.id = id
        self.kind = kind
        self.inputPath = inputPath
        self.outputPath = outputPath
        self.status = .queued
        self.progress = 0
        self.retryCount = 0
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

public actor JobQueue {
    private var records: [JobRecord]
    private let persistenceURL: URL?

    public init(records: [JobRecord] = [], persistenceURL: URL? = nil) {
        self.persistenceURL = persistenceURL
        if
            let persistenceURL,
            let data = try? Data(contentsOf: persistenceURL),
            let restored = try? JSONDecoder().decode([JobRecord].self, from: data)
        {
            self.records = restored.map { record in
                var recovered = record
                if [.preparing, .running, .writing].contains(recovered.status) {
                    recovered.status = .queued
                    recovered.progress = 0
                    recovered.errorSummary = "Recovered after app relaunch"
                    recovered.updatedAt = Date()
                }
                return recovered
            }
        } else {
            self.records = records
        }
        Self.write(records: self.records, to: persistenceURL)
    }

    @discardableResult
    public func enqueue(kind: JobKind, inputPath: String, outputPath: String? = nil) -> JobRecord {
        let record = JobRecord(kind: kind, inputPath: inputPath, outputPath: outputPath)
        records.append(record)
        persist()
        return record
    }

    public func snapshot() -> [JobRecord] { records }

    public func record(id: UUID) -> JobRecord? {
        records.first { $0.id == id }
    }

    public func update(id: UUID, status: JobStatus, progress: Double? = nil, error: String? = nil) {
        guard let index = records.firstIndex(where: { $0.id == id }) else { return }
        records[index].status = status
        records[index].progress = progress.map { min(max($0, 0), 1) }
        records[index].errorSummary = error
        records[index].updatedAt = Date()
        persist()
    }

    public func cancel(id: UUID) {
        update(id: id, status: .cancelled, progress: nil)
    }

    public func retry(id: UUID) {
        guard let index = records.firstIndex(where: { $0.id == id }) else { return }
        records[index].retryCount += 1
        records[index].status = .queued
        records[index].progress = 0
        records[index].errorSummary = nil
        records[index].updatedAt = Date()
        persist()
    }

    public func remove(id: UUID) {
        records.removeAll { $0.id == id }
        persist()
    }

    public func clearFinished() {
        records.removeAll { [.completed, .cancelled, .failed].contains($0.status) }
        persist()
    }

    private func persist() {
        Self.write(records: records, to: persistenceURL)
    }

    private static func write(records: [JobRecord], to persistenceURL: URL?) {
        guard let persistenceURL else { return }
        do {
            try FileManager.default.createDirectory(
                at: persistenceURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(records)
            try data.write(to: persistenceURL, options: .atomic)
        } catch {
            // Queue state persistence is best effort; processing remains available.
        }
    }
}
