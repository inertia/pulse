import XCTest
@testable import Pulse

final class SourceTests: XCTestCase {

    // MARK: - Round-trip JSON

    func testRoundTripJSONPreservesAllFields() throws {
        let original = Source(
            id: UUID(uuidString: "550E8400-E29B-41D4-A716-446655440000")!,
            kind: .claudeMd,
            path: URL(fileURLWithPath: "/tmp/test/CLAUDE.md"),
            label: "Test Project",
            enabled: false
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Source.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.kind, original.kind)
        XCTAssertEqual(decoded.path, original.path)
        XCTAssertEqual(decoded.label, original.label)
        XCTAssertEqual(decoded.enabled, original.enabled)
    }

    // MARK: - Default values

    func testEnabledDefaultsToTrue() {
        let source = Source(
            kind: .gitLog,
            path: URL(fileURLWithPath: "/tmp/repo"),
            label: "Repo"
        )

        XCTAssertTrue(source.enabled)
    }

    func testInitGeneratesUniqueUUIDByDefault() {
        let s1 = Source(
            kind: .claudeMd,
            path: URL(fileURLWithPath: "/tmp/a/CLAUDE.md"),
            label: "A"
        )
        let s2 = Source(
            kind: .claudeMd,
            path: URL(fileURLWithPath: "/tmp/b/CLAUDE.md"),
            label: "B"
        )

        XCTAssertNotEqual(s1.id, s2.id)
    }

    // MARK: - SourceKind decoding

    func testAllSourceKindCasesDecodeFromLowercaseRawValue() throws {
        let decoder = JSONDecoder()

        let pairs: [(String, SourceKind)] = [
            ("claudeMd", .claudeMd),
            ("agentsMd", .agentsMd),
            ("geminiMd", .geminiMd),
            ("gitLog",   .gitLog)
        ]

        for (raw, expected) in pairs {
            let json = "\"\(raw)\"".data(using: .utf8)!
            let kind = try decoder.decode(SourceKind.self, from: json)
            XCTAssertEqual(kind, expected, "expected \(raw) to decode to \(expected)")
        }

        // sanity: confirms enum has exactly these 4 cases
        XCTAssertEqual(SourceKind.allCases.count, 4)
    }

    // MARK: - Equatable

    func testEquatableIdentifiesSameAndDifferentInstances() {
        let id = UUID()
        let path = URL(fileURLWithPath: "/tmp/CLAUDE.md")

        let a = Source(id: id, kind: .claudeMd, path: path, label: "X", enabled: true)
        let b = Source(id: id, kind: .claudeMd, path: path, label: "X", enabled: true)
        let differentLabel  = Source(id: id, kind: .claudeMd, path: path, label: "Y", enabled: true)
        let differentId     = Source(id: UUID(), kind: .claudeMd, path: path, label: "X", enabled: true)
        let differentKind   = Source(id: id, kind: .gitLog, path: path, label: "X", enabled: true)
        let differentEnable = Source(id: id, kind: .claudeMd, path: path, label: "X", enabled: false)

        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, differentLabel)
        XCTAssertNotEqual(a, differentId)
        XCTAssertNotEqual(a, differentKind)
        XCTAssertNotEqual(a, differentEnable)
    }
}
