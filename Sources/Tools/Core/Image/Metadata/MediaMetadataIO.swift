import Foundation

/// Audio/video tags through the bundled ffmpeg/ffprobe. Streams are always
/// copied (`-c copy`), so editing or stripping never re-encodes media.
/// ffmpeg maps the generic keys onto each container's native tags (ID3v2 for
/// MP3, iTunes atoms for MP4/M4A/MOV, Vorbis comments, RIFF INFO, Matroska tags).
enum MediaMetadataIO {
    /// Editable key → ffmpeg metadata key.
    static let keys: [(key: String, tag: String, label: String)] = [
        ("title", "title", L("Title")), ("artist", "artist", L("Artist")), ("album", "album", L("Album")),
        ("albumArtist", "album_artist", L("Album artist")), ("date", "date", L("Year / date")), ("genre", "genre", L("Genre")),
        ("track", "track", L("Track")), ("composer", "composer", L("Composer")), ("comment", "comment", L("Comment")),
        ("description", "description", L("Description")), ("copyright", "copyright", L("Copyright")),
    ]

    // MARK: Read

    static func read(_ url: URL, ffmpeg: FFmpeg) async throws -> MetadataSnapshot {
        let probe = try await ffmpeg.probe(url)
        var tags: [String: String] = [:]
        // Container tags win; stream tags (Ogg/Opus keep them per stream) fill gaps.
        for s in probe.streams { for (k, v) in s.tags ?? [:] where tags[k.lowercased()] == nil { tags[k.lowercased()] = v } }
        for (k, v) in probe.format?.tags ?? [:] { tags[k.lowercased()] = v }
        var fields: [MetadataField] = []
        for k in keys {
            fields.append(MetadataField(key: k.key, label: k.label, group: L("Tags"), value: tags[k.tag] ?? "", editable: true))
        }
        func info(_ key: String, _ label: String, _ group: String, _ value: String?) {
            guard let value, !value.isEmpty else { return }
            fields.append(MetadataField(key: key, label: label, group: group, value: value, editable: false))
        }
        let location = tags["location"] ?? tags["com.apple.quicktime.location.iso6709"]
        info("tag.location", L("Location"), L("Tags"), location)
        info("tag.creationTime", L("Created"), L("Tags"), tags["creation_time"])
        info("tag.encoder", L("Encoder"), L("Tags"), tags["encoder"])
        if let d = probe.duration { info("media.duration", L("Duration"), L("Media"), Self.duration(d)) }
        info("media.container", L("Container"), L("Media"), probe.format?.format_name)
        if let v = probe.video {
            var s = v.codec_name?.uppercased() ?? ""
            if let w = v.width, let h = v.height { s += " · \(w) × \(h)" }
            if let fps = Self.rate(v.avg_frame_rate ?? v.r_frame_rate) { s += String(format: " · %.3g fps", fps) }
            info("media.video", L("Video"), L("Media"), s)
        }
        if let a = probe.audio {
            var s = a.codec_name?.uppercased() ?? ""
            if let sr = a.sample_rate.flatMap(Double.init) { s += String(format: " · %.1f kHz", sr / 1000) }
            if let ch = a.channels { s += ch == 1 ? " · mono" : ch == 2 ? " · stereo" : " · \(ch) ch" }
            info("media.audio", L("Audio"), L("Media"), s)
        }
        if let br = probe.format?.bit_rate.flatMap(Double.init) { info("media.bitrate", L("Bit rate"), L("Media"), "\(Int(br / 1000)) kbps") }
        if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize {
            info("file.size", L("Size"), L("File"), ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file))
        }
        return MetadataSnapshot(container: .media, fields: fields)
    }

    // MARK: Write

    static func write(_ input: URL, changes: [String: String?], output: ToolOutput, ffmpeg: FFmpeg) async throws -> URL {
        var args = ["-i", input.path, "-map", "0", "-c", "copy", "-map_metadata", "0"]
        for (key, value) in changes.sorted(by: { $0.key < $1.key }) {
            guard let tag = keys.first(where: { $0.key == key })?.tag else { throw ConversionError.invalidOption("fields.\(key)") }
            // An empty value deletes the tag in ffmpeg.
            args += ["-metadata", "\(tag)=\(value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "")"]
        }
        return try await run(args, input: input, output: output, ffmpeg: ffmpeg)
    }

    // MARK: Strip

    /// Drops global, stream and chapter metadata, cover art, and data streams
    /// (GPS tracks, timecode); bit-exact flags keep ffmpeg from adding its own tags.
    static func strip(_ input: URL, output: ToolOutput, ffmpeg: FFmpeg) async throws -> URL {
        let args = ["-i", input.path, "-map", "0", "-map", "-0:disp:attached_pic", "-dn",
                    "-map_metadata", "-1", "-map_metadata:s", "-1", "-map_chapters", "-1", "-c", "copy"]
        return try await run(args, input: input, output: output, ffmpeg: ffmpeg)
    }

    private static func run(_ args: [String], input: URL, output: ToolOutput, ffmpeg: FFmpeg) async throws -> URL {
        guard ffmpeg.isAvailable else { throw ConversionError.engineMissing("ffmpeg", detail: "metadata") }
        let ext = input.pathExtension.lowercased()
        let url = try output.url(ext: ext)
        var full = args + ["-fflags", "+bitexact", "-flags:v", "+bitexact", "-flags:a", "+bitexact"]
        if ext == "mp3" { full += ["-id3v2_version", "3", "-write_id3v1", "0"] }
        if ["mp4", "m4a", "m4v", "mov"].contains(ext) { full += ["-movflags", "+faststart"] }
        full.append(url.path)
        do {
            try await ffmpeg.run(full)
        } catch {
            try? FileManager.default.removeItem(at: url)
            throw error
        }
        return url
    }

    private static func duration(_ s: Double) -> String {
        let t = Int(s.rounded())
        return t >= 3600 ? String(format: "%d:%02d:%02d", t / 3600, t / 60 % 60, t % 60) : String(format: "%d:%02d", t / 60, t % 60)
    }

    private static func rate(_ s: String?) -> Double? {
        guard let s else { return nil }
        let p = s.split(separator: "/").compactMap { Double($0) }
        if p.count == 2, p[1] > 0 { return p[0] / p[1] > 0 ? p[0] / p[1] : nil }
        return Double(s)
    }
}
