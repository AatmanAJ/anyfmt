import AppKit

/// Copy and Copy Path.
///
/// Copy writes one pasteboard item per file carrying `public.file-url`, so ⌘V
/// in Finder pastes copies and apps that accept file drops accept the paste.
/// The first item also carries a plain-text fallback with every POSIX path
/// (newline-separated), so pasting into a text field gives the paths rather
/// than nothing. Only the first item has it because text views read the first
/// string on the pasteboard.
@MainActor
public enum FileClipboard {
    @discardableResult
    public static func copyFiles(_ urls: [URL], to pasteboard: NSPasteboard = .general) -> Bool {
        guard !urls.isEmpty else { return false }
        let items: [NSPasteboardItem] = urls.enumerated().map { index, url in
            let item = NSPasteboardItem()
            item.setString(url.standardizedFileURL.absoluteString, forType: .fileURL)
            if index == 0 {
                item.setString(PathFormatter.posixPaths(urls), forType: .string)
            }
            return item
        }
        pasteboard.clearContents()
        return pasteboard.writeObjects(items)
    }

    @discardableResult
    public static func copyText(_ text: String, to pasteboard: NSPasteboard = .general) -> Bool {
        pasteboard.clearContents()
        return pasteboard.setString(text, forType: .string)
    }
}

/// Formats file paths for Copy Path.
///
/// - Plain (default): POSIX paths, one per line, no trailing newline, no
///   trailing slash on folders, Unicode kept as-is.
/// - Shell (Option held when the action fires): each path quoted for a POSIX
///   shell only when it needs it, joined by spaces, so it can be pasted
///   straight into a command line (the same shape Terminal uses when you drop
///   several files on it).
public enum PathFormatter {
    /// File URLs carry decomposed (NFD) Unicode from the file system
    /// representation; text is friendlier precomposed (NFC), and APFS/HFS+
    /// resolve either form to the same file.
    public static func posixPath(_ url: URL) -> String {
        url.standardizedFileURL.path.precomposedStringWithCanonicalMapping
    }

    public static func posixPaths(_ urls: [URL]) -> String {
        urls.map(posixPath).joined(separator: "\n")
    }

    public static func shellEscapedPaths(_ urls: [URL]) -> String {
        urls.map { shellQuote(posixPath($0)) }.joined(separator: " ")
    }

    /// Characters that never need quoting in sh, bash or zsh.
    private static let shellSafe = CharacterSet(charactersIn:
        "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_@%+=:,./-")

    /// `/tmp/a b` → `'/tmp/a b'`; `it's` → `'it'\''s'`; safe paths are left bare.
    public static func shellQuote(_ s: String) -> String {
        if s.isEmpty { return "''" }
        if s.unicodeScalars.allSatisfy(shellSafe.contains) { return s }
        return "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
