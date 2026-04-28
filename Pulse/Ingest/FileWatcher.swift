import CoreServices
import Foundation

/// Watches a single file for changes by monitoring its parent directory via FSEventStream.
///
/// **Why parent dir + FSEventStream rather than the file itself + DispatchSource?**
/// vim / VSCode / BBEdit / Sublime save with atomic-rename: write tmp file, then
/// `rename(2)` over the original. A `DispatchSourceFileSystemObject` watching the
/// original file's fd becomes stale after the rename and the watcher silently dies.
/// FSEventStream watching the parent dir + filtering by filename survives this
/// pattern (Apple-recommended).
///
/// `onChange` is invoked after a 1-second debounce — multiple writes within the
/// window coalesce into a single call.
final class FileWatcher {

    private let parentDir: URL
    private let targetFilename: String
    private let onChange: () -> Void

    private var stream: FSEventStreamRef?
    private var debounceTask: Task<Void, Never>?

    init(fileURL: URL, onChange: @escaping () -> Void) {
        self.parentDir = fileURL.deletingLastPathComponent()
        self.targetFilename = fileURL.lastPathComponent
        self.onChange = onChange
    }

    /// Start watching. Idempotent — calling twice is a no-op on the second call.
    func start() {
        guard stream == nil else { return }

        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )
        let pathsToWatch = [parentDir.path] as CFArray
        let flags = UInt32(
            kFSEventStreamCreateFlagFileEvents |
            kFSEventStreamCreateFlagUseCFTypes
        )
        let callback: FSEventStreamCallback = { _, info, _, eventPaths, _, _ in
            guard let info = info else { return }
            let watcher = Unmanaged<FileWatcher>.fromOpaque(info).takeUnretainedValue()
            // With kFSEventStreamCreateFlagUseCFTypes, eventPaths is a CFArray of CFString.
            let paths = unsafeBitCast(eventPaths, to: NSArray.self) as? [String] ?? []
            for path in paths where (path as NSString).lastPathComponent == watcher.targetFilename {
                watcher.scheduleDebounce()
                return
            }
        }
        stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            callback,
            &context,
            pathsToWatch,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.5,                                   // FSEvents coalescing window
            flags
        )
        if let s = stream {
            FSEventStreamSetDispatchQueue(s, DispatchQueue.main)
            FSEventStreamStart(s)
        }
    }

    /// Stop watching. Cancels any pending debounce. Safe to call multiple times.
    func stop() {
        if let s = stream {
            FSEventStreamStop(s)
            FSEventStreamInvalidate(s)
            FSEventStreamRelease(s)
            stream = nil
        }
        debounceTask?.cancel()
        debounceTask = nil
    }

    deinit {
        stop()
    }

    // MARK: - Debounce

    private func scheduleDebounce() {
        debounceTask?.cancel()
        let onChange = self.onChange
        debounceTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_000_000_000)   // 1 sec
            if Task.isCancelled { return }
            onChange()
        }
    }
}
