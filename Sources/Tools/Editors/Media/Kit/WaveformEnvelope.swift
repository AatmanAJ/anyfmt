import AVFoundation
import Foundation
import HaloCore

/// Min/max peak envelope of an audio file: one (min, max) pair per bin of
/// `samplesPerBin` frames, channels folded together. Built in one streaming
/// pass and reduced on the fly to whatever the view's zoom needs.
struct WaveformEnvelope: Sendable, Equatable {
    let sampleRate: Double
    let samplesPerBin: Int
    var mins: [Float]
    var maxs: [Float]

    var binCount: Int { mins.count }
    var binDuration: Double { Double(samplesPerBin) / sampleRate }
    var duration: Double { Double(binCount) * binDuration }

    /// Peaks for `columns` equal slices of [start, end) seconds. Columns past
    /// the decoded data come back as (0, 0).
    func columns(from start: Double, to end: Double, count: Int) -> [(min: Float, max: Float)] {
        guard count > 0, end > start, binCount > 0 else { return [] }
        var out: [(min: Float, max: Float)] = []
        out.reserveCapacity(count)
        let binsPerSecond = 1 / binDuration
        for c in 0..<count {
            let t0 = start + (end - start) * Double(c) / Double(count)
            let t1 = start + (end - start) * Double(c + 1) / Double(count)
            var b0 = Int((t0 * binsPerSecond).rounded(.down))
            var b1 = Int((t1 * binsPerSecond).rounded(.up))
            b0 = max(0, b0)
            b1 = min(binCount, max(b1, b0 + 1))
            guard b0 < binCount else { out.append((0, 0)); continue }
            var lo: Float = 0, hi: Float = 0
            for b in b0..<b1 {
                lo = Swift.min(lo, mins[b])
                hi = Swift.max(hi, maxs[b])
            }
            out.append((lo, hi))
        }
        return out
    }

    /// Streaming builder. Feed interleaved float frames in any chunk sizes.
    struct Builder {
        let sampleRate: Double
        let samplesPerBin: Int
        private(set) var mins: [Float] = []
        private(set) var maxs: [Float] = []
        private var count = 0
        private var lo: Float = .greatestFiniteMagnitude
        private var hi: Float = -.greatestFiniteMagnitude

        init(sampleRate: Double, samplesPerBin: Int) {
            self.sampleRate = sampleRate
            self.samplesPerBin = max(1, samplesPerBin)
        }

        /// Bins of ~5 ms: plenty for zooming in, ~200 bins per second.
        static func defaultSamplesPerBin(sampleRate: Double) -> Int { max(16, Int(sampleRate / 200)) }

        mutating func append(_ samples: UnsafeBufferPointer<Float>, channels: Int) {
            let ch = max(1, channels)
            let frames = samples.count / ch
            var i = 0
            for _ in 0..<frames {
                for _ in 0..<ch {
                    let s = samples[i]
                    if s < lo { lo = s }
                    if s > hi { hi = s }
                    i += 1
                }
                count += 1
                if count == samplesPerBin { flush() }
            }
        }

        mutating func append(_ samples: [Float], channels: Int) {
            samples.withUnsafeBufferPointer { append($0, channels: channels) }
        }

        private mutating func flush() {
            mins.append(lo)
            maxs.append(hi)
            count = 0
            lo = .greatestFiniteMagnitude
            hi = -.greatestFiniteMagnitude
        }

        /// Envelope so far (the partial bin included).
        func snapshot() -> WaveformEnvelope {
            var e = WaveformEnvelope(sampleRate: sampleRate, samplesPerBin: samplesPerBin, mins: mins, maxs: maxs)
            if count > 0 { e.mins.append(lo); e.maxs.append(hi) }
            return e
        }
    }
}

/// Decodes audio with AVAssetReader into an envelope, publishing progress so
/// the waveform draws while it loads. Results are cached per file for the session.
enum WaveformLoader {
    private final class Cache: @unchecked Sendable {
        private let lock = NSLock()
        private var items: [String: WaveformEnvelope] = [:]
        func get(_ k: String) -> WaveformEnvelope? { lock.withLock { items[k] } }
        func set(_ k: String, _ v: WaveformEnvelope) { lock.withLock { items[k] = v } }
    }

    private static let cache = Cache()

    static func cacheKey(_ url: URL) -> String {
        let mod = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)?.timeIntervalSince1970 ?? 0
        return "\(url.path)#\(mod)"
    }

    /// Streams an envelope for `url` (an AVFoundation-readable file). `update`
    /// gets partial envelopes, then the final one.
    static func load(_ url: URL, update: @escaping @Sendable (WaveformEnvelope, Bool) -> Void) async throws {
        let key = cacheKey(url)
        if let hit = cache.get(key) { update(hit, true); return }
        let asset = AVURLAsset(url: url)
        guard let track = try await asset.loadTracks(withMediaType: .audio).first else { throw ConversionError.noAudio(url) }
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsNonInterleaved: false,
            AVLinearPCMIsBigEndianKey: false,
        ])
        output.alwaysCopiesSampleData = false
        reader.add(output)
        guard reader.startReading() else { throw reader.error ?? ConversionError.unreadable(url, detail: "AVAssetReader") }
        var builder: WaveformEnvelope.Builder?
        var channels = 1
        var lastPublish = Date()
        while let buffer = output.copyNextSampleBuffer() {
            try Task.checkCancellation()
            if builder == nil, let desc = CMSampleBufferGetFormatDescription(buffer),
               let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(desc)?.pointee {
                channels = Int(asbd.mChannelsPerFrame)
                builder = WaveformEnvelope.Builder(sampleRate: asbd.mSampleRate,
                                                   samplesPerBin: WaveformEnvelope.Builder.defaultSamplesPerBin(sampleRate: asbd.mSampleRate))
            }
            guard let block = CMSampleBufferGetDataBuffer(buffer) else { continue }
            var length = 0
            var pointer: UnsafeMutablePointer<CChar>?
            guard CMBlockBufferGetDataPointer(block, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: &length, dataPointerOut: &pointer) == noErr,
                  let pointer else { continue }
            let total = CMBlockBufferGetDataLength(block)
            if length == total {
                pointer.withMemoryRebound(to: Float.self, capacity: length / 4) { p in
                    builder?.append(UnsafeBufferPointer(start: p, count: length / 4), channels: channels)
                }
            } else {
                // Non-contiguous block: copy out.
                var data = [Float](repeating: 0, count: total / 4)
                data.withUnsafeMutableBytes { raw in
                    guard let base = raw.baseAddress else { return }
                    _ = CMBlockBufferCopyDataBytes(block, atOffset: 0, dataLength: total, destination: base)
                }
                builder?.append(data, channels: channels)
            }
            if Date().timeIntervalSince(lastPublish) > 0.2, let b = builder {
                update(b.snapshot(), false)
                lastPublish = Date()
            }
        }
        if reader.status == .failed { throw reader.error ?? ConversionError.unreadable(url, detail: "AVAssetReader failed") }
        let final = builder?.snapshot() ?? WaveformEnvelope(sampleRate: 44100, samplesPerBin: 220, mins: [], maxs: [])
        cache.set(key, final)
        update(final, true)
    }
}
