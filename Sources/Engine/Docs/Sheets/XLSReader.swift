import Foundation

/// Microsoft Compound File Binary (OLE2) container: just enough to read named
/// streams (the "Workbook" stream of an .xls). Version 3 (512-byte sectors) and
/// 4 (4096-byte sectors), FAT via DIFAT, mini stream for small streams.
struct CompoundFile {
    enum Failure: Error { case notCFB, corrupt(String) }

    struct Entry {
        let name: String
        let type: UInt8
        let start: UInt32
        let size: UInt64
    }

    private let data: Data
    private let sectorSize: Int
    private let miniSectorSize: Int
    private let miniCutoff: UInt32
    private let fat: [UInt32]
    private let miniFAT: [UInt32]
    private let miniStream: Data
    let entries: [Entry]

    static let endOfChain: UInt32 = 0xFFFF_FFFE
    static let free: UInt32 = 0xFFFF_FFFF

    init(data: Data) throws {
        let b = ByteView(data)
        guard data.count >= 512, data.prefix(8) == Data([0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1]) else { throw Failure.notCFB }
        self.data = data
        let sectorShift = Int(b.u16(30)), miniShift = Int(b.u16(32))
        guard (9...12).contains(sectorShift), (6...6).contains(miniShift) else { throw Failure.corrupt("sector size") }
        sectorSize = 1 << sectorShift
        miniSectorSize = 1 << miniShift
        let numFAT = Int(b.u32(44))
        let firstDir = b.u32(48)
        miniCutoff = b.u32(56)
        let firstMiniFAT = b.u32(60), numMiniFAT = Int(b.u32(64))
        var difatSector = b.u32(68)
        let numDIFAT = Int(b.u32(72))
        guard numFAT < 1 << 20, numMiniFAT < 1 << 20, numDIFAT < 1 << 20 else { throw Failure.corrupt("counts") }
        // FAT sector locations: 109 in the header, the rest in DIFAT sectors.
        var fatSectors: [UInt32] = []
        for k in 0..<109 where fatSectors.count < numFAT {
            let s = b.u32(76 + k * 4)
            if s != Self.free { fatSectors.append(s) }
        }
        let perDIFAT = sectorSize / 4 - 1
        var guardCount = 0
        while fatSectors.count < numFAT, difatSector != Self.endOfChain, difatSector != Self.free, guardCount < numDIFAT + 1 {
            let off = (Int(difatSector) + 1) * sectorSize
            guard off + sectorSize <= data.count else { throw Failure.corrupt("DIFAT") }
            for k in 0..<perDIFAT where fatSectors.count < numFAT {
                let s = b.u32(off + k * 4)
                if s != Self.free { fatSectors.append(s) }
            }
            difatSector = b.u32(off + perDIFAT * 4)
            guardCount += 1
        }
        var fat: [UInt32] = []
        fat.reserveCapacity(fatSectors.count * sectorSize / 4)
        for s in fatSectors {
            let off = (Int(s) + 1) * sectorSize
            guard off + sectorSize <= data.count else { throw Failure.corrupt("FAT") }
            for k in 0..<(sectorSize / 4) { fat.append(b.u32(off + k * 4)) }
        }
        self.fat = fat
        // Directory.
        let dir = try Self.chain(data, fat: fat, start: firstDir, sectorSize: sectorSize, limit: 1 << 26)
        var entries: [Entry] = []
        let db = ByteView(dir)
        var p = 0
        while p + 128 <= dir.count {
            let nameLen = min(Int(db.u16(p + 64)), 64)
            let nameData = dir.subdata(in: dir.startIndex + p ..< dir.startIndex + p + max(0, nameLen - 2))
            let name = String(data: nameData, encoding: .utf16LittleEndian) ?? ""
            let size = sectorSize == 512 ? UInt64(db.u32(p + 120)) : db.u64(p + 120)
            entries.append(Entry(name: name, type: db.u8(p + 66), start: db.u32(p + 116), size: size))
            p += 128
        }
        self.entries = entries
        // Mini FAT + mini stream (held by the root entry).
        var miniFAT: [UInt32] = []
        if numMiniFAT > 0 {
            let m = try Self.chain(data, fat: fat, start: firstMiniFAT, sectorSize: sectorSize, limit: 1 << 26)
            let mb = ByteView(m)
            for k in 0..<(m.count / 4) { miniFAT.append(mb.u32(k * 4)) }
        }
        self.miniFAT = miniFAT
        if let root = entries.first(where: { $0.type == 5 }), root.start != Self.endOfChain, root.size > 0 {
            miniStream = try Self.chain(data, fat: fat, start: root.start, sectorSize: sectorSize, limit: Int(min(root.size, 1 << 30)))
        } else {
            miniStream = Data()
        }
    }

    /// Follows a sector chain; `limit` bounds the bytes read (and loops).
    static func chain(_ data: Data, fat: [UInt32], start: UInt32, sectorSize: Int, limit: Int) throws -> Data {
        var out = Data()
        var s = start
        var steps = 0
        let maxSteps = data.count / sectorSize + 1
        while s != endOfChain, s != free, out.count < limit {
            let off = (Int(s) + 1) * sectorSize
            guard Int(s) < fat.count, off + sectorSize <= data.count, steps <= maxSteps else { throw Failure.corrupt("chain") }
            out.append(data.subdata(in: data.startIndex + off ..< data.startIndex + off + sectorSize))
            s = fat[Int(s)]
            steps += 1
        }
        return out.count > limit ? out.prefix(limit) : out
    }

    func stream(_ name: String) throws -> Data? {
        guard let e = entries.first(where: { $0.type == 2 && $0.name.caseInsensitiveCompare(name) == .orderedSame }) else { return nil }
        let size = Int(min(e.size, 1 << 31))
        if e.size < UInt64(miniCutoff) {
            var out = Data()
            var s = e.start
            var steps = 0
            while s != Self.endOfChain, s != Self.free, out.count < size {
                let off = Int(s) * miniSectorSize
                guard Int(s) < miniFAT.count, off + miniSectorSize <= miniStream.count, steps <= miniFAT.count else { throw Failure.corrupt("mini chain") }
                out.append(miniStream.subdata(in: miniStream.startIndex + off ..< miniStream.startIndex + off + miniSectorSize))
                s = miniFAT[Int(s)]
                steps += 1
            }
            return out.prefix(size)
        }
        return try Self.chain(data, fat: fat, start: e.start, sectorSize: sectorSize, limit: size)
    }
}

/// Excel 97–2003 (.xls, BIFF8) → `Workbook`: shared strings (with CONTINUE
/// splits), LABEL/LABELSST, NUMBER, RK/MULRK, BOOLERR, cached FORMULA results
/// (incl. string results), date formats via XF → FORMAT, the 1904 date system.
/// Files saved as ".xls" that are really HTML tables are read as HTML.
public enum XLSReader {
    public enum Failure: Error, Sendable { case notXLS, unsupportedBIFF(Int), encrypted }

    public static func read(_ url: URL) throws -> Workbook {
        let data = try Data(contentsOf: url, options: .alwaysMapped)
        // "Excel" exports from web apps are often HTML with an .xls name.
        if let first = data.first(where: { $0 != 0x20 && $0 != 0x0A && $0 != 0x0D && $0 != 0x09 && $0 != 0xEF && $0 != 0xBB && $0 != 0xBF }), first == 0x3C {
            return htmlWorkbook(TextDecoding.decode(data), name: url.deletingPathExtension().lastPathComponent)
        }
        let cfb = try CompoundFile(data: data)
        guard let stream = try cfb.stream("Workbook") ?? cfb.stream("Book") else { throw Failure.notXLS }
        return try parse(stream)
    }

    static func htmlWorkbook(_ html: String, name: String) -> Workbook {
        let doc = HTMLReader.read(html, baseURL: nil)
        var sheets: [Sheet] = []
        for b in doc.blocks {
            guard case .table(let t) = b else { continue }
            let rows = t.rows.map { r in r.cells.map { c in Cell.infer(c.blocks.map(\.plainText).joined(separator: "\n")) } }
            sheets.append(Sheet(name: sheets.isEmpty ? name : "\(name) \(sheets.count + 1)", rows: rows).trimmed)
        }
        return Workbook(sheets: sheets)
    }

    struct Record { let type: UInt16; let data: Data }

    static func records(_ s: Data, from start: Int) -> [Record] {
        var out: [Record] = []
        let b = ByteView(s)
        var p = start
        while p + 4 <= s.count {
            let type = b.u16(p), len = Int(b.u16(p + 2))
            guard p + 4 + len <= s.count else { break }
            out.append(Record(type: type, data: s.subdata(in: s.startIndex + p + 4 ..< s.startIndex + p + 4 + len)))
            p += 4 + len
            if type == 0x000A { break } // EOF of this substream
        }
        return out
    }

    static func parse(_ stream: Data) throws -> Workbook {
        let globals = records(stream, from: 0)
        guard let bof = globals.first, bof.type == 0x0809, bof.data.count >= 4 else { throw Failure.notXLS }
        let version = Int(ByteView(bof.data).u16(0))
        guard version == 0x0600 else { throw Failure.unsupportedBIFF(version) }
        var date1904 = false
        var formats: [Int: String] = [:]
        var xfFormat: [Int] = []
        var sheets: [(name: String, offset: Int, visible: Bool)] = []
        var sst: [String] = []
        var k = 0
        while k < globals.count {
            let r = globals[k]
            let b = ByteView(r.data)
            switch r.type {
            case 0x002F: throw Failure.encrypted       // FILEPASS
            case 0x0022: if r.data.count >= 2 { date1904 = b.u16(0) == 1 }
            case 0x041E:
                if r.data.count >= 5 {
                    var c = StringCursor(segments: [r.data.subdata(in: r.data.startIndex + 2 ..< r.data.endIndex)])
                    formats[Int(b.u16(0))] = c.unicodeString(lengthBytes: 2)
                }
            case 0x00E0: if r.data.count >= 4 { xfFormat.append(Int(b.u16(2))) }
            case 0x0085:
                if r.data.count >= 8 {
                    var c = StringCursor(segments: [r.data.subdata(in: r.data.startIndex + 6 ..< r.data.endIndex)])
                    let name = c.unicodeString(lengthBytes: 1)
                    // Only worksheets (dt 0); visible state in the low byte.
                    if b.u8(5) == 0 { sheets.append((name, Int(b.u32(0)), b.u8(4) == 0)) }
                }
            case 0x00FC:
                var segments = [r.data]
                while k + 1 < globals.count, globals[k + 1].type == 0x003C { k += 1; segments.append(globals[k].data) }
                sst = sharedStrings(segments)
            default: break
            }
            k += 1
        }
        var dateXF = Set<Int>(), timeXF = Set<Int>()
        for (i, f) in xfFormat.enumerated() {
            let (isDate, hasTime) = XLSXReader.dateKind(f, code: formats[f])
            if isDate { dateXF.insert(i) }
            if hasTime { timeXF.insert(i) }
        }
        var out: [Sheet] = []
        for s in sheets where s.offset >= 0 && s.offset < stream.count {
            out.append(sheet(records(stream, from: s.offset), name: s.name, sst: sst, dateXF: dateXF, timeXF: timeXF, date1904: date1904).trimmed)
        }
        return Workbook(sheets: out)
    }

    static func sharedStrings(_ segments: [Data]) -> [String] {
        guard let first = segments.first, first.count >= 8 else { return [] }
        let unique = Int(ByteView(first).u32(4))
        var c = StringCursor(segments: [first.subdata(in: first.startIndex + 8 ..< first.endIndex)] + segments.dropFirst())
        var out: [String] = []
        out.reserveCapacity(min(unique, 1 << 20))
        while out.count < unique, !c.atEnd { out.append(c.unicodeString(lengthBytes: 2)) }
        return out
    }

    static func rk(_ v: UInt32) -> Double {
        var d: Double
        if v & 0x02 != 0 {
            d = Double(Int32(bitPattern: v) >> 2)
        } else {
            d = Double(bitPattern: UInt64(v & 0xFFFF_FFFC) << 32)
        }
        if v & 0x01 != 0 { d /= 100 }
        return d
    }

    static func sheet(_ recs: [Record], name: String, sst: [String], dateXF: Set<Int>, timeXF: Set<Int>, date1904: Bool) -> Sheet {
        var grid: [Int: [Int: Cell]] = [:]
        var maxRow = -1
        func put(_ r: Int, _ c: Int, _ cell: Cell) {
            guard r >= 0, r < 65536, c >= 0, c < 256 else { return }
            grid[r, default: [:]][c] = cell
            maxRow = max(maxRow, r)
        }
        func numeric(_ v: Double, xf: Int) -> Cell {
            if dateXF.contains(xf) { return .date(Cell.date(fromExcelSerial: v, date1904: date1904), time: timeXF.contains(xf) || v != v.rounded()) }
            return .number(v)
        }
        var pendingString: (Int, Int)?
        for r in recs {
            let b = ByteView(r.data)
            let n = r.data.count
            switch r.type {
            case 0x00FD where n >= 10: // LABELSST
                let i = Int(b.u32(6))
                put(Int(b.u16(0)), Int(b.u16(2)), i < sst.count ? .string(sst[i]) : .empty)
            case 0x0204 where n >= 8: // LABEL
                var c = StringCursor(segments: [r.data.subdata(in: r.data.startIndex + 6 ..< r.data.endIndex)])
                put(Int(b.u16(0)), Int(b.u16(2)), .string(c.unicodeString(lengthBytes: 2)))
            case 0x0203 where n >= 14: // NUMBER
                put(Int(b.u16(0)), Int(b.u16(2)), numeric(Double(bitPattern: b.u64(6)), xf: Int(b.u16(4))))
            case 0x027E where n >= 10: // RK
                put(Int(b.u16(0)), Int(b.u16(2)), numeric(rk(b.u32(6)), xf: Int(b.u16(4))))
            case 0x00BD where n >= 6: // MULRK
                let row = Int(b.u16(0)), first = Int(b.u16(2))
                let count = (n - 6) / 6
                for j in 0..<count {
                    let o = 4 + j * 6
                    put(row, first + j, numeric(rk(b.u32(o + 2)), xf: Int(b.u16(o))))
                }
            case 0x0205 where n >= 8: // BOOLERR
                let row = Int(b.u16(0)), col = Int(b.u16(2))
                if b.u8(7) == 0 { put(row, col, .bool(b.u8(6) != 0)) } else { put(row, col, .string(errorText(b.u8(6)))) }
            case 0x0006 where n >= 14: // FORMULA: cached result
                let row = Int(b.u16(0)), col = Int(b.u16(2)), xf = Int(b.u16(4))
                if b.u16(12) == 0xFFFF {
                    switch b.u8(6) {
                    case 0: pendingString = (row, col)          // value follows in a STRING record
                    case 1: put(row, col, .bool(b.u8(8) != 0))
                    case 2: put(row, col, .string(errorText(b.u8(8))))
                    default: break
                    }
                } else {
                    put(row, col, numeric(Double(bitPattern: b.u64(6)), xf: xf))
                }
            case 0x0207: // STRING (formula string result)
                if let (row, col) = pendingString {
                    var c = StringCursor(segments: [r.data])
                    put(row, col, .string(c.unicodeString(lengthBytes: 2)))
                    pendingString = nil
                }
            case 0x00D6 where n >= 8: // RSTRING (BIFF5-style rich label)
                var c = StringCursor(segments: [r.data.subdata(in: r.data.startIndex + 6 ..< r.data.endIndex)])
                put(Int(b.u16(0)), Int(b.u16(2)), .string(c.unicodeString(lengthBytes: 2)))
            default:
                break
            }
        }
        guard maxRow >= 0 else { return Sheet(name: name, rows: []) }
        var rows: [[Cell]] = []
        rows.reserveCapacity(maxRow + 1)
        for r in 0...maxRow {
            guard let cols = grid[r], let maxCol = cols.keys.max() else { rows.append([]); continue }
            rows.append((0...maxCol).map { cols[$0] ?? .empty })
        }
        return Sheet(name: name, rows: rows)
    }

    static func errorText(_ code: UInt8) -> String {
        switch code {
        case 0x00: "#NULL!"
        case 0x07: "#DIV/0!"
        case 0x0F: "#VALUE!"
        case 0x17: "#REF!"
        case 0x1D: "#NAME?"
        case 0x24: "#NUM!"
        case 0x2A: "#N/A"
        default: "#ERR"
        }
    }
}

/// Reads BIFF8 unicode strings across record (CONTINUE) boundaries: when the
/// character data is split, the next segment starts with a fresh option byte.
struct StringCursor {
    var segments: [Data]
    var seg = 0
    var off = 0

    init(segments: [Data]) { self.segments = segments }

    var atEnd: Bool {
        var s = seg, o = off
        while s < segments.count {
            if o < segments[s].count { return false }
            s += 1
            o = 0
        }
        return true
    }

    private mutating func normalise() {
        while seg < segments.count, off >= segments[seg].count { seg += 1; off = 0 }
    }

    mutating func byte() -> UInt8? {
        normalise()
        guard seg < segments.count else { return nil }
        let v = segments[seg][segments[seg].startIndex + off]
        off += 1
        return v
    }

    mutating func u16() -> Int { Int(byte() ?? 0) | Int(byte() ?? 0) << 8 }
    mutating func u32() -> Int { u16() | u16() << 16 }

    mutating func skip(_ n: Int) {
        var left = n
        while left > 0 {
            normalise()
            guard seg < segments.count else { return }
            let take = min(left, segments[seg].count - off)
            off += take
            left -= take
        }
    }

    /// XLUnicodeString / ShortXLUnicodeString with optional rich-text runs and phonetic data.
    mutating func unicodeString(lengthBytes: Int) -> String {
        let cch = lengthBytes == 1 ? Int(byte() ?? 0) : u16()
        guard let flags = byte() else { return "" }
        var high = flags & 0x01 != 0
        let runs = flags & 0x08 != 0 ? u16() : 0
        let ext = flags & 0x04 != 0 ? u32() : 0
        var units: [UInt16] = []
        units.reserveCapacity(cch)
        while units.count < cch {
            normalise()
            guard seg < segments.count else { break }
            if off == 0, !units.isEmpty {
                // Continued in a new record: re-read the high-byte flag.
                guard let f = byte() else { break }
                high = f & 0x01 != 0
                continue
            }
            if high {
                guard off + 1 < segments[seg].count else {
                    // A two-byte char never straddles; treat leftovers as corrupt and move on.
                    off = segments[seg].count
                    continue
                }
                let lo = UInt16(segments[seg][segments[seg].startIndex + off]), hi = UInt16(segments[seg][segments[seg].startIndex + off + 1])
                units.append(lo | hi << 8)
                off += 2
            } else {
                units.append(UInt16(segments[seg][segments[seg].startIndex + off]))
                off += 1
            }
        }
        skip(runs * 4 + ext)
        return String(decoding: units, as: UTF16.self)
    }
}
