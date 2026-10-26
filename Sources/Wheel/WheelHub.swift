import AppKit
import AnyfmtCore
import QuickLookThumbnailing
import RadialMenu
import UniformTypeIdentifiers

/// Builds the hub (centre disc) content: the dragged file's icon at once, its
/// QuickLook thumbnail when it arrives, a stacked look with a count for
/// multi-file drags, and the idle pill text (file size or "N files").
@MainActor
enum WheelHub {
    /// Immediate content: Finder icon + idle text. Cheap enough for the open path.
    static func immediate(for input: WheelInput) -> RadialHubContent {
        RadialHubContent(image: icon(for: input), stackCount: max(1, input.count), idleText: idleText(for: input))
    }

    static func icon(for input: WheelInput) -> NSImage? {
        if let url = input.urls.first { return NSWorkspace.shared.icon(forFile: url.path) }
        if let type = input.promisedTypes.first { return NSWorkspace.shared.icon(for: type) }
        return nil
    }

    static func idleText(for input: WheelInput) -> String {
        if input.count > 1 {
            let folders = input.urls.filter(isDirectory).count
            return folders > 0
                ? String(localized: "\(input.count) items", comment: "Hub text for a multi-item drag that includes folders")
                : String(localized: "\(input.count) files", comment: "Hub text for a multi-file drag")
        }
        if let url = input.urls.first {
            if isDirectory(url) && Formats.detect(url) == Formats.folder {
                return String(localized: "Folder", comment: "Hub text when a folder is dragged")
            }
            if let size = fileSize(url) {
                return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
            }
        }
        if let type = input.promisedTypes.first, let format = WheelInput.format(for: type) {
            return Formats.label(format)
        }
        return ""
    }

    /// The QuickLook thumbnail for the first file, or nil (keep the icon). Off the main thread.
    static func thumbnail(for url: URL, side: CGFloat, scale: CGFloat) async -> NSImage? {
        let request = QLThumbnailGenerator.Request(fileAt: url, size: CGSize(width: side, height: side), scale: scale,
                                                   representationTypes: [.thumbnail])
        request.iconMode = false
        do {
            let rep = try await QLThumbnailGenerator.shared.generateBestRepresentation(for: request)
            return rep.nsImage
        } catch {
            Log.wheel.debug("no QuickLook thumbnail for \(url.lastPathComponent, privacy: .private): \(error.localizedDescription)")
            return nil
        }
    }

    private static func isDirectory(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
    }

    private static func fileSize(_ url: URL) -> Int64? {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey, .totalFileAllocatedSizeKey, .isPackageKey])
        if let size = values?.fileSize { return Int64(size) }
        if let size = values?.totalFileAllocatedSize { return Int64(size) }
        return nil
    }
}
