import os

/// One `Logger` per module. Shipping code never uses `print`.
public enum Log {
    public static let app = Logger(subsystem: Brand.bundleID, category: "app")
    public static let engine = Logger(subsystem: Brand.bundleID, category: "engine")
    public static let router = Logger(subsystem: Brand.bundleID, category: "router")
    public static let jobs = Logger(subsystem: Brand.bundleID, category: "jobs")
    public static let wheel = Logger(subsystem: Brand.bundleID, category: "wheel")
    public static let tools = Logger(subsystem: Brand.bundleID, category: "tools")
    public static let actions = Logger(subsystem: Brand.bundleID, category: "actions")
    public static let cloud = Logger(subsystem: Brand.bundleID, category: "cloud")
    public static let settings = Logger(subsystem: Brand.bundleID, category: "settings")

    public static func make(_ category: String) -> Logger {
        Logger(subsystem: Brand.bundleID, category: category)
    }
}
