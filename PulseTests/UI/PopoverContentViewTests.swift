import XCTest
@testable import Pulse

final class PopoverContentViewTests: XCTestCase {

    // MARK: - Fixtures

    private let sourceA = Source(
        id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
        kind: .claudeMd,
        path: URL(fileURLWithPath: "/tmp/a/CLAUDE.md"),
        label: "alpha"
    )

    private let sourceB = Source(
        id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
        kind: .claudeMd,
        path: URL(fileURLWithPath: "/tmp/b/CLAUDE.md"),
        label: "bravo"
    )

    private func makeCard(
        sourceId: UUID,
        title: String,
        status: Status,
        completedAt: Date? = nil
    ) -> Card {
        Card(
            id: Card.makeId(path: "/tmp/x.md", sectionHeading: "## h", normalizedTitle: title),
            sourceId: sourceId,
            title: title,
            body: nil,
            status: status,
            dueDate: nil,
            completedAt: completedAt,
            sourceRef: "/tmp/x.md:1",
            tags: []
        )
    }

    // MARK: - computeGroups

    func testComputeGroupsFiltersOnTodo() {
        let cards = [
            makeCard(sourceId: sourceA.id, title: "todo-1", status: .todo),
            makeCard(sourceId: sourceA.id, title: "todo-2", status: .todo),
            makeCard(sourceId: sourceA.id, title: "done-1", status: .done,
                     completedAt: Date(timeIntervalSince1970: 1_000_000)),
            makeCard(sourceId: sourceA.id, title: "done-2", status: .done,
                     completedAt: Date(timeIntervalSince1970: 2_000_000)),
        ]
        let groups = PopoverContentView.computeGroups(
            cards: cards,
            sources: [sourceA],
            filter: .todo
        )

        XCTAssertEqual(groups.count, 1, "single source label → one group")
        XCTAssertEqual(groups.first?.label, "alpha")
        XCTAssertEqual(groups.first?.cards.count, 2, "filter=.todo keeps only todo cards")
        XCTAssertTrue(groups.first?.cards.allSatisfy { $0.status == .todo } ?? false)
    }

    func testComputeGroupsSortsTodoBeforeDone() {
        // Mixed statuses in same source; verify todo first, then done by completedAt desc.
        let earlyDone = Date(timeIntervalSince1970: 1_000_000)
        let lateDone = Date(timeIntervalSince1970: 2_000_000)
        let cards = [
            makeCard(sourceId: sourceA.id, title: "done-old", status: .done, completedAt: earlyDone),
            makeCard(sourceId: sourceA.id, title: "todo-1",   status: .todo),
            makeCard(sourceId: sourceA.id, title: "done-new", status: .done, completedAt: lateDone),
            makeCard(sourceId: sourceA.id, title: "todo-2",   status: .todo),
        ]
        let groups = PopoverContentView.computeGroups(
            cards: cards,
            sources: [sourceA],
            filter: .all
        )

        XCTAssertEqual(groups.count, 1)
        let sorted = groups.first!.cards
        XCTAssertEqual(sorted.count, 4)
        // Todo first (any internal order between todos is allowed since they share status)
        XCTAssertEqual(sorted[0].status, .todo)
        XCTAssertEqual(sorted[1].status, .todo)
        // Done after, newer completedAt first
        XCTAssertEqual(sorted[2].status, .done)
        XCTAssertEqual(sorted[2].title, "done-new")
        XCTAssertEqual(sorted[3].title, "done-old")
    }

    // MARK: - computeStats

    func testComputeStatsCounts() {
        let cards = [
            makeCard(sourceId: sourceA.id, title: "t1", status: .todo),
            makeCard(sourceId: sourceA.id, title: "t2", status: .todo),
            makeCard(sourceId: sourceA.id, title: "t3", status: .todo),
            makeCard(sourceId: sourceB.id, title: "d1", status: .done,
                     completedAt: Date(timeIntervalSince1970: 1)),
            makeCard(sourceId: sourceB.id, title: "d2", status: .done,
                     completedAt: Date(timeIntervalSince1970: 2)),
        ]
        let stats = PopoverContentView.computeStats(cards: cards, sources: [sourceA, sourceB])

        XCTAssertEqual(stats.projects, 2, "2 distinct source labels in card set")
        XCTAssertEqual(stats.todos, 3)
        XCTAssertEqual(stats.dones, 2)
    }

    func testComputeStatsWithMissingSource() {
        // Card refers to a sourceId that's not in the sources list (e.g., source removed
        // but cards still in cache). Card should still be counted in todos/dones, but
        // not contribute to projects label set.
        let orphanSourceId = UUID()
        let cards = [
            makeCard(sourceId: sourceA.id,    title: "t1", status: .todo),
            makeCard(sourceId: orphanSourceId, title: "t2", status: .todo),
            makeCard(sourceId: orphanSourceId, title: "d1", status: .done,
                     completedAt: Date(timeIntervalSince1970: 1)),
        ]
        let stats = PopoverContentView.computeStats(cards: cards, sources: [sourceA])

        XCTAssertEqual(stats.projects, 1, "only 'alpha' label is in known-sources set")
        XCTAssertEqual(stats.todos, 2, "both todos counted regardless of source-id mapping")
        XCTAssertEqual(stats.dones, 1)
    }
}
