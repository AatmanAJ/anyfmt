import Foundation

// Lane F rows: folders → archives, archives → folder, archive → archive.
public enum ArchiveRoutes {
    typealias F = Formats

    static let readable: [FormatID] = [F.zip, F.tar, F.gz, F.rar, F.sevenZip]
    static let writable: [FormatID] = [F.zip, F.tar, F.gz, F.sevenZip]

    public static let rows: [Capability] = {
        let e = EngineIDs.archiveTool
        var rows: [Capability] = []
        // Folder(s) → one archive: every dragged item goes into the same archive.
        for to in writable {
            rows.append(Capability(F.folder, to, e, schema: StandardSchemas.archive, priority: 100, cost: 1, arity: .combine, flags: [.lossless]))
        }
        for from in readable {
            rows.append(Capability(from, F.folder, e, priority: 100, cost: 1, flags: [.lossless]))
            for to in writable where to != from {
                rows.append(Capability(from, to, e, schema: StandardSchemas.archive, priority: 100, cost: 1.5, flags: [.lossless]))
            }
        }
        return rows
    }()
}
