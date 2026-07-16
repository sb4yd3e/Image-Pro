import XCTest
@testable import ImageProCore

final class JobQueueTests: XCTestCase {
    func testQueueLifecycle() async {
        let queue = JobQueue()
        let job = await queue.enqueue(kind: .optimize, inputPath: "/tmp/input.jpg")
        await queue.update(id: job.id, status: .running, progress: 0.5)
        var current = await queue.record(id: job.id)
        XCTAssertEqual(current?.status, .running)
        XCTAssertEqual(current?.progress, 0.5)

        await queue.cancel(id: job.id)
        current = await queue.record(id: job.id)
        XCTAssertEqual(current?.status, .cancelled)
    }

    func testPersistentQueueRecoversInterruptedJob() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let stateURL = directory.appendingPathComponent("queue.json")
        defer { try? FileManager.default.removeItem(at: directory) }

        let firstQueue = JobQueue(persistenceURL: stateURL)
        let record = await firstQueue.enqueue(kind: .optimize, inputPath: "/tmp/input.png")
        await firstQueue.update(id: record.id, status: .running, progress: 0.6)

        let restoredQueue = JobQueue(persistenceURL: stateURL)
        let restored = await restoredQueue.record(id: record.id)
        XCTAssertEqual(restored?.status, .queued)
        XCTAssertEqual(restored?.progress, 0)
        XCTAssertEqual(restored?.errorSummary, "Recovered after app relaunch")
    }

    func testClearFinishedKeepsActiveJobs() async {
        let queue = JobQueue()
        let finished = await queue.enqueue(kind: .optimize, inputPath: "finished")
        _ = await queue.enqueue(kind: .upscale, inputPath: "active")
        await queue.update(id: finished.id, status: .completed, progress: 1)
        await queue.clearFinished()

        let records = await queue.snapshot()
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.inputPath, "active")
    }
}
