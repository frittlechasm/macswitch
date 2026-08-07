import Foundation
import OSLog

enum Diagnostics {
    private static let overlayLatencyLogger = Logger(
        subsystem: "com.frittlechasm.mac-workspace-switcher",
        category: "overlay-latency"
    )

    static func log(_ message: String) {
        NSLog("[AppSwitcher] %@", message)
    }

    /// Logs only numeric overlay timings as public values so persisted samples remain queryable.
    static func logOverlayLatency(
        totalMilliseconds: Double,
        inventoryMilliseconds: Double,
        filteringMilliseconds: Double,
        presentationMilliseconds: Double
    ) {
        overlayLatencyLogger.log(
            "Overlay latency: total=\(totalMilliseconds, format: .fixed(precision: 1), privacy: .public)ms, inventory=\(inventoryMilliseconds, format: .fixed(precision: 1), privacy: .public)ms, filtering=\(filteringMilliseconds, format: .fixed(precision: 1), privacy: .public)ms, presentation=\(presentationMilliseconds, format: .fixed(precision: 1), privacy: .public)ms"
        )
    }
}
