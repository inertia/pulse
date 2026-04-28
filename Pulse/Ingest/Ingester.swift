import Foundation

protocol Ingester {
    func fetch(source: Source) async throws -> [Card]
}
