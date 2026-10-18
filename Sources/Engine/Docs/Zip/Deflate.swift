import Compression
import Foundation

/// Raw DEFLATE (RFC 1951) through Apple's Compression framework.
/// `COMPRESSION_ZLIB` is raw deflate without a zlib header, which is exactly what
/// ZIP (method 8) and gzip need.
public enum Deflate {
    public enum Failure: Error, Sendable { case streamInit, stream, tooLarge }

    /// Compresses `data` in one go.
    public static func compress(_ data: Data) throws -> Data {
        var out = Data()
        let stream = try DeflateStream(.encode)
        try stream.process(data, final: true) { out.append($0) }
        return out
    }

    /// Decompresses raw deflate. `limit` caps the output (zip-bomb guard).
    public static func decompress(_ data: Data, expectedSize: Int? = nil, limit: Int = 1 << 31) throws -> Data {
        var out = Data()
        if let expectedSize, expectedSize > 0, expectedSize < limit { out.reserveCapacity(expectedSize) }
        let stream = try DeflateStream(.decode)
        try stream.process(data, final: true) { chunk in
            out.append(chunk)
            if out.count > limit { throw Failure.tooLarge }
        }
        return out
    }
}

/// Incremental deflate/inflate. Feed chunks with `process`; the sink receives output chunks.
public final class DeflateStream {
    public enum Direction { case encode, decode }
    private let pointer: UnsafeMutablePointer<compression_stream>
    private let bufferSize = 1 << 16
    private let buffer: UnsafeMutablePointer<UInt8>
    private var finished = false

    public init(_ direction: Direction) throws {
        pointer = UnsafeMutablePointer<compression_stream>.allocate(capacity: 1)
        buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        let op = direction == .encode ? COMPRESSION_STREAM_ENCODE : COMPRESSION_STREAM_DECODE
        guard compression_stream_init(pointer, op, COMPRESSION_ZLIB) == COMPRESSION_STATUS_OK else {
            buffer.deallocate()
            pointer.deallocate()
            throw Deflate.Failure.streamInit
        }
    }

    deinit {
        compression_stream_destroy(pointer)
        buffer.deallocate()
        pointer.deallocate()
    }

    /// Processes one chunk. Pass `final: true` with the last chunk (may be empty).
    public func process(_ input: Data, final: Bool, sink: (Data) throws -> Void) throws {
        guard !finished else { return }
        try input.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
            let base = raw.bindMemory(to: UInt8.self).baseAddress
            // An empty Data may have a nil base address; the framework still needs a valid pointer.
            var dummy: UInt8 = 0
            try withUnsafeMutablePointer(to: &dummy) { dummyPtr in
                pointer.pointee.src_ptr = UnsafePointer(base ?? UnsafePointer(dummyPtr))
                pointer.pointee.src_size = raw.count
                let flags = final ? Int32(COMPRESSION_STREAM_FINALIZE.rawValue) : 0
                while true {
                    let srcBefore = pointer.pointee.src_size
                    pointer.pointee.dst_ptr = buffer
                    pointer.pointee.dst_size = bufferSize
                    let status = compression_stream_process(pointer, flags)
                    let produced = bufferSize - pointer.pointee.dst_size
                    if produced > 0 { try sink(Data(bytes: buffer, count: produced)) }
                    switch status {
                    case COMPRESSION_STATUS_OK:
                        let stalled = produced == 0 && pointer.pointee.src_size == srcBefore
                        if final {
                            // Finalising: keep draining until END. No progress = truncated input.
                            if stalled { throw Deflate.Failure.stream }
                        } else if pointer.pointee.src_size == 0 && produced < bufferSize {
                            return // all input consumed; wait for the next chunk
                        } else if stalled {
                            return
                        }
                    case COMPRESSION_STATUS_END:
                        finished = true
                        return
                    default:
                        throw Deflate.Failure.stream
                    }
                }
            }
        }
    }
}
