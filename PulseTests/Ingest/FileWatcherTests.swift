import Darwin
import XCTest
@testable import Pulse

/// FSEvents-backed FileWatcher tests.
///
/// These tests are inherently slow: FSEventStream coalescing latency is 0.5s
/// and FileWatcher debounce is 1s on top, so each callback takes ~1.5s minimum.
/// Generous timeouts (5s) tolerate the natural latency.
final class FileWatcherTests: XCTestCase {

    // MARK: - Tempdir helper

    private func makeTempDir() throws -> URL {
        // Resolve symlinks (macOS /tmp -> /private/tmp); FSEvents emits resolved paths.
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("PulseTests-FileWatcher-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return URL(fileURLWithPath: dir.resolvingSymlinksInPath().path)
    }

    private func writeFile(_ content: String, to url: URL) throws {
        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    /// FSEventStream needs a brief moment after `start()` for the kernel
    /// stream to attach before file writes will be reported. 0.3s is empirically
    /// enough on macOS 14.
    private func waitForStreamAttach() async {
        try? await Task.sleep(nanoseconds: 300_000_000)
    }

    // MARK: - 1. Single write fires callback

    func testWriteToFileFiresCallback() async throws {
        let dir = try makeTempDir()
        let target = dir.appendingPathComponent("target.md")
        try writeFile("initial", to: target)

        let exp = expectation(description: "change fires")
        let watcher = FileWatcher(fileURL: target) {
            exp.fulfill()
        }
        watcher.start()
        await waitForStreamAttach()

        try writeFile("new content", to: target)

        await fulfillment(of: [exp], timeout: 5)
        watcher.stop()
    }

    // MARK: - 2. Multiple writes coalesce into a single callback (1s debounce)

    func testMultipleWritesCoalesceIntoOneCall() async throws {
        let dir = try makeTempDir()
        let target = dir.appendingPathComponent("target.md")
        try writeFile("initial", to: target)

        let exp = expectation(description: "coalesced change fires once")
        exp.expectedFulfillmentCount = 1
        exp.assertForOverFulfill = true

        actor Counter {
            private(set) var count = 0
            func bump() { count += 1 }
        }
        let counter = Counter()

        let watcher = FileWatcher(fileURL: target) {
            Task {
                await counter.bump()
                exp.fulfill()
            }
        }
        watcher.start()
        await waitForStreamAttach()

        // 3 writes within ~100ms — all should land inside the 1s debounce window.
        try writeFile("v1", to: target)
        try await Task.sleep(nanoseconds: 30_000_000)
        try writeFile("v2", to: target)
        try await Task.sleep(nanoseconds: 30_000_000)
        try writeFile("v3", to: target)

        await fulfillment(of: [exp], timeout: 5)

        // Wait a bit longer to make sure no late second callback arrives.
        try await Task.sleep(nanoseconds: 1_500_000_000)
        let final = await counter.count
        XCTAssertEqual(final, 1, "3 quick writes must coalesce into 1 callback (debounce)")

        watcher.stop()
    }

    // MARK: - 3. Atomic-rename save (vim/VSCode/BBEdit) — THE point of FSEventStream

    func testAtomicRenameStillFires() async throws {
        let dir = try makeTempDir()
        let target = dir.appendingPathComponent("target.md")
        try writeFile("initial", to: target)

        let exp = expectation(description: "atomic-rename fires callback")
        let watcher = FileWatcher(fileURL: target) {
            exp.fulfill()
        }
        watcher.start()
        await waitForStreamAttach()

        // Simulate vim's atomic save: write tmp file, then POSIX rename(2)
        // it over the original. DispatchSource on the original fd would die here;
        // FSEventStream watching the parent dir + filtering by filename survives.
        let tmp = dir.appendingPathComponent("target.md.tmp")
        try writeFile("rewritten via atomic rename", to: tmp)
        let rc = rename(tmp.path, target.path)
        XCTAssertEqual(rc, 0, "rename(2) must succeed (errno=\(errno))")

        await fulfillment(of: [exp], timeout: 5)
        watcher.stop()
    }

    // MARK: - 4. stop() halts further callbacks

    func testStopStopsCallbacks() async throws {
        let dir = try makeTempDir()
        let target = dir.appendingPathComponent("target.md")
        try writeFile("initial", to: target)

        let firstFire = expectation(description: "first write fires")
        actor Counter {
            private(set) var count = 0
            func bump() { count += 1 }
        }
        let counter = Counter()

        let watcher = FileWatcher(fileURL: target) {
            Task {
                await counter.bump()
                firstFire.fulfill()
            }
        }
        watcher.start()
        await waitForStreamAttach()

        try writeFile("v1", to: target)
        await fulfillment(of: [firstFire], timeout: 5)

        watcher.stop()

        // Write again post-stop; must not re-fire.
        try writeFile("v2-after-stop", to: target)
        try await Task.sleep(nanoseconds: 2_500_000_000)   // > debounce window

        let final = await counter.count
        XCTAssertEqual(final, 1, "stop() must prevent further callbacks")
    }

    // MARK: - 5. start() is idempotent

    func testStartIsIdempotent() async throws {
        let dir = try makeTempDir()
        let target = dir.appendingPathComponent("target.md")
        try writeFile("initial", to: target)

        actor Counter {
            private(set) var count = 0
            func bump() { count += 1 }
        }
        let counter = Counter()

        let watcher = FileWatcher(fileURL: target) {
            Task { await counter.bump() }
        }
        watcher.start()
        watcher.start()   // second call must be a no-op (no crash, no double fire)
        await waitForStreamAttach()

        try writeFile("v1", to: target)
        try await Task.sleep(nanoseconds: 2_500_000_000)   // > debounce window

        let final = await counter.count
        XCTAssertEqual(final, 1, "double-start must not produce double callbacks")

        watcher.stop()
    }
}
