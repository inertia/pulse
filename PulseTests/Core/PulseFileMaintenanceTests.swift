import XCTest
@testable import Pulse

final class PulseFileMaintenanceTests: XCTestCase {

    // MARK: - cleanLines (pure helper)

    func test_keepsLines_withoutDoneMarker() {
        let now = date("2026-04-28")
        let input = """
        - [ ] (2026-04-01) open todo A
        - [x] legacy bootstrap done line (no marker)
        - [x] (2026-04-01) old format check (treated as no marker)
        plain text line
        """
        let (out, removed) = PulseFileMaintenance.cleanLines(input, now: now, ageDays: 30)
        XCTAssertEqual(out, input)
        XCTAssertEqual(removed, 0)
    }

    func test_keepsLines_withinAgeWindow() {
        let now = date("2026-04-28")
        // 27 days ago — under cutoff (30 days), keep.
        let input = "- [x] (done 2026-04-01) recent done\n"
        let (out, removed) = PulseFileMaintenance.cleanLines(input, now: now, ageDays: 30)
        XCTAssertEqual(out, input)
        XCTAssertEqual(removed, 0)
    }

    func test_removesLines_pastAgeWindow() {
        let now = date("2026-04-28")
        // 38 days ago — past cutoff, drop.
        let input = """
        keep me
        - [x] (done 2026-03-21) aged out
        keep me too
        """
        let (out, removed) = PulseFileMaintenance.cleanLines(input, now: now, ageDays: 30)
        XCTAssertEqual(out, "keep me\nkeep me too")
        XCTAssertEqual(removed, 1)
    }

    func test_preservesFileStructure_aroundRemovedLines() {
        let now = date("2026-04-28")
        let input = """
        # Header

        ## To Do

        - [ ] (2026-04-15) keep open A
        - [x] (done 2026-03-15) drop me 1
        - [ ] (2026-04-20) keep open B
        - [x] (done 2026-03-10) drop me 2

        ## Notes
        text
        """
        let (out, removed) = PulseFileMaintenance.cleanLines(input, now: now, ageDays: 30)
        XCTAssertEqual(removed, 2)
        XCTAssertFalse(out.contains("drop me 1"))
        XCTAssertFalse(out.contains("drop me 2"))
        XCTAssertTrue(out.contains("keep open A"))
        XCTAssertTrue(out.contains("keep open B"))
        XCTAssertTrue(out.contains("# Header"))
        XCTAssertTrue(out.contains("## Notes"))
    }

    func test_handlesMalformedDoneDate_gracefully() {
        let now = date("2026-04-28")
        let input = """
        - [x] (done not-a-date) malformed
        - [x] (done 2026/03/01) wrong separator
        - [x] (done 26-03-01) two-digit year
        - [x] (done 2026-03-21) valid old
        """
        let (out, removed) = PulseFileMaintenance.cleanLines(input, now: now, ageDays: 30)
        XCTAssertEqual(removed, 1)
        XCTAssertTrue(out.contains("malformed"))
        XCTAssertTrue(out.contains("wrong separator"))
        XCTAssertTrue(out.contains("two-digit year"))
        XCTAssertFalse(out.contains("valid old"))
    }

    func test_preservesTrailingNewline() {
        let now = date("2026-04-28")
        let withNewline = "- [x] (done 2026-03-01) old\nkeep\n"
        let (out1, _) = PulseFileMaintenance.cleanLines(withNewline, now: now, ageDays: 30)
        XCTAssertEqual(out1, "keep\n")

        let withoutNewline = "- [x] (done 2026-03-01) old\nkeep"
        let (out2, _) = PulseFileMaintenance.cleanLines(withoutNewline, now: now, ageDays: 30)
        XCTAssertEqual(out2, "keep")
    }

    // MARK: - cleanAgedDoneItems (file IO)

    func test_emptyPulseURLs_noop() {
        let count = PulseFileMaintenance.cleanAgedDoneItems(pulseURLs: [])
        XCTAssertEqual(count, 0)
    }

    func test_cleanAgedDoneItems_writesOnlyChangedFiles() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("pulse-maintenance-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let agedURL = tmp.appendingPathComponent("aged.md")
        let cleanURL = tmp.appendingPathComponent("clean.md")
        let agedContent = "- [ ] keep\n- [x] (done 2026-03-01) drop\n"
        let cleanContent = "- [ ] only opens\n- [ ] (2026-04-15) recent\n"
        try agedContent.write(to: agedURL, atomically: true, encoding: .utf8)
        try cleanContent.write(to: cleanURL, atomically: true, encoding: .utf8)

        let cleanMtimeBefore = try mtime(of: cleanURL)
        Thread.sleep(forTimeInterval: 0.05)

        let removed = PulseFileMaintenance.cleanAgedDoneItems(
            pulseURLs: [agedURL, cleanURL],
            now: date("2026-04-28"),
            ageDays: 30
        )
        XCTAssertEqual(removed, 1)

        let aged = try String(contentsOf: agedURL, encoding: .utf8)
        XCTAssertEqual(aged, "- [ ] keep\n")

        let clean = try String(contentsOf: cleanURL, encoding: .utf8)
        XCTAssertEqual(clean, cleanContent)
        let cleanMtimeAfter = try mtime(of: cleanURL)
        XCTAssertEqual(cleanMtimeBefore, cleanMtimeAfter, "unchanged file should not be rewritten")
    }

    // MARK: - helpers

    private func date(_ iso: String) -> Date {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.date(from: iso)!
    }

    private func mtime(of url: URL) throws -> Date {
        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        return attrs[.modificationDate] as! Date
    }
}
