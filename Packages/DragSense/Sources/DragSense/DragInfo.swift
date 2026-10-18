// DragSense: MIT licence, see LICENSE.
import CoreGraphics
import Foundation

/// What DragSense knows about the drag in progress.
///
/// Read once per drag, at drag start, from the system drag pasteboard.
public struct DragInfo: Sendable, Equatable, Identifiable {
    /// The drag pasteboard's `changeCount` for this drag. Unique per drag
    /// session; equal to ``DragSenseState/dragging(dragID:)``.
    public var id: Int { changeCount }

    /// File URLs on the drag pasteboard (path URLs; Finder's file-reference
    /// URLs are resolved). Empty for promise-only drags (Mail, Photos, many
    /// browsers): those files only exist after the drop.
    public var fileURLs: [URL]

    /// Uniform type identifiers from file-promise metadata
    /// (`com.apple.pasteboard.promised-file-content-type`), de-duplicated, in
    /// pasteboard order. Enough to choose formats before the drop.
    public var promisedTypes: [String]

    /// Every type on the drag pasteboard, as raw strings.
    public var pasteboardTypes: [String]

    /// Number of pasteboard items (dragged things), including promises.
    public var itemCount: Int

    /// The drag pasteboard's change count when the drag was detected.
    public var changeCount: Int

    /// Pointer position, in global AppKit coordinates (origin bottom-left of
    /// the primary screen, y up), when DragSense first saw the button down.
    public var startLocation: CGPoint

    /// Monotonic time (`ProcessInfo.systemUptime` seconds) when DragSense
    /// first saw the button down.
    public var startTime: TimeInterval

    /// True when the pasteboard contents couldn't be read within
    /// ``DragSenseConfiguration/pasteboardReadTimeout``. `fileURLs` and
    /// `promisedTypes` may then be empty; read the dragging pasteboard on drop.
    /// If the read finishes later, later events carry the complete info.
    public var isPartial: Bool

    public init(
        fileURLs: [URL],
        promisedTypes: [String],
        pasteboardTypes: [String],
        itemCount: Int,
        changeCount: Int,
        startLocation: CGPoint,
        startTime: TimeInterval,
        isPartial: Bool = false
    ) {
        self.fileURLs = fileURLs
        self.promisedTypes = promisedTypes
        self.pasteboardTypes = pasteboardTypes
        self.itemCount = itemCount
        self.changeCount = changeCount
        self.startLocation = startLocation
        self.startTime = startTime
        self.isPartial = isPartial
    }

    /// True when the drag carries promised files but no file URLs yet.
    public var isPromiseOnly: Bool { fileURLs.isEmpty && !promisedTypes.isEmpty }
}

/// The contents an ``InputSource`` reads off the drag pasteboard.
public struct DragPasteboardContents: Sendable, Equatable {
    public var fileURLs: [URL]
    public var promisedTypes: [String]
    public var itemCount: Int

    public init(fileURLs: [URL] = [], promisedTypes: [String] = [], itemCount: Int = 0) {
        self.fileURLs = fileURLs
        self.promisedTypes = promisedTypes
        self.itemCount = itemCount
    }
}

/// Pasteboard type strings that mark a drag as a file drag.
public enum DragPasteboardType {
    /// `NSPasteboard.PasteboardType.fileURL`.
    public static let fileURL = "public.file-url"
    /// Modern file promise: the URL the receiver will get (`kPasteboardTypeFileURLPromise`).
    public static let promisedFileURL = "com.apple.pasteboard.promised-file-url"
    /// Modern file promise: the promised file's UTI (`kPasteboardTypeFilePromiseContent`).
    public static let promisedContentType = "com.apple.pasteboard.promised-file-content-type"
    /// `NSFilePromiseProvider` metadata.
    public static let filePromiseMetadata = "com.apple.NSFilePromiseItemMetaData"
    /// Legacy `NSFilesPromisePboardType`.
    public static let legacyFilesPromise = "Apple files promise pasteboard type"
    /// Legacy `NSFilenamesPboardType`.
    public static let legacyFilenames = "NSFilenamesPboardType"

    /// The built-in set. ``SystemInputSource`` adds
    /// `NSFilePromiseReceiver.readableDraggedTypes` at runtime, so new promise
    /// types Apple adds are picked up without a package update.
    public static let fileTypes: Set<String> = [
        fileURL, promisedFileURL, promisedContentType, filePromiseMetadata, legacyFilesPromise, legacyFilenames,
    ]

    /// True when `types` contains at least one of `fileTypes`.
    public static func isFileDrag(_ types: [String], fileTypes: Set<String> = DragPasteboardType.fileTypes) -> Bool {
        types.contains(where: fileTypes.contains)
    }
}
