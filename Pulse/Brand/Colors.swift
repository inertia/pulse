import AppKit
import SwiftUI

/// Brand palette adopted from designer pulse-handoff (2026-04-29).
/// Only the tokens are adopted; designer's session-monitor product positioning was rejected.
///
/// Use `Brand.amber` for URGENT accents, `Brand.amberDeep` when light text needs more contrast in dark mode,
/// `Brand.slate` for neutral surfaces, `Brand.surface2` for the elevated card background that follows
/// system control color (so it tracks light/dark automatically).
enum Brand {
    static let amber = Color(red: 1.0, green: 0.663, blue: 0.251)        // #ffa940
    static let amberDeep = Color(red: 0.78, green: 0.4, blue: 0.05)      // dark mode contrast partner
    static let slate = Color(red: 0.102, green: 0.122, blue: 0.18)       // #1a1f2e
    static let surface2 = Color(NSColor.controlBackgroundColor)
}
