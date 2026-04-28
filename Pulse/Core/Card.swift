import CryptoKit
import Foundation

enum Status: String, Codable { case todo, done }

struct Card: Identifiable, Codable, Equatable {
    let id: String
    let sourceId: UUID
    let title: String           // 已 normalize（去日期、去 #tag、trim）
    let body: String?
    let status: Status
    let dueDate: Date?
    let completedAt: Date?
    let sourceRef: String       // "file.md:42" 或 commit SHA（顯示用，非 identity）
    let tags: [String]

    /// Identity = SHA256(path + sectionHeading + normalizedTitle).
    /// 不含 lineNumber：避免 user 在檔案上方插一行 → cards id 全變 → cache 失效。
    /// sourceRef 帶 lineNumber 是給 UI 顯示用，不參與 hash。
    static func makeId(path: String, sectionHeading: String, normalizedTitle: String) -> String {
        let joined = [path, sectionHeading, normalizedTitle].joined(separator: "\n")
        let hash = SHA256.hash(data: Data(joined.utf8))
        return String(hash.compactMap { String(format: "%02x", $0) }.joined().prefix(16))
    }
}
