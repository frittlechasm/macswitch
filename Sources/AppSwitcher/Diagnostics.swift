import Foundation
import OSLog

enum Diagnostics {
    enum FailureStage: String {
        case sessionPermissionDenied = "session-permission-denied"
        case activationPermissionDenied = "activation-permission-denied"
        case activationWindowUnavailable = "activation-window-unavailable"
        case activationValidationIndeterminate = "activation-validation-indeterminate"
        case activationAppActivateFailed = "activation-app-activate-failed"
        case activationAppNotFound = "activation-app-not-found"
        case activationRaiseFailed = "activation-raise-failed"
        case activationSetMainFailed = "activation-set-main-failed"
        case activationSetFocusedFailed = "activation-set-focused-failed"
        case hotKeyInstallHandlerFailed = "hotkey-install-handler-failed"
        case hotKeyRegisterFailed = "hotkey-register-failed"
        case hotKeyRestoreFailed = "hotkey-restore-failed"
        case hotKeyRegisterUnknownError = "hotkey-register-unknown-error"
        case hotKeyNoneRegistered = "hotkey-none-registered"
    }

    private static let reliabilityLogger = Logger(
        subsystem: "com.frittlechasm.mac-workspace-switcher",
        category: "reliability"
    )

    private static let overlayLatencyLogger = Logger(
        subsystem: "com.frittlechasm.mac-workspace-switcher",
        category: "overlay-latency"
    )

    static func log(_ message: String) {
        NSLog("[AppSwitcher] %@", message)
    }

    /// Persists an allowlisted failure stage and numeric code while keeping descriptive context private.
    static func logFailure(
        _ stage: FailureStage,
        errorCode: Int32? = nil,
        privateContext: String? = nil
    ) {
        let context = privateContext ?? ""

        if let errorCode {
            reliabilityLogger.error(
                "Reliability failure: stage=\(stage.rawValue, privacy: .public), errorCode=\(errorCode, privacy: .public), context=\(context, privacy: .private)"
            )
        } else {
            reliabilityLogger.error(
                "Reliability failure: stage=\(stage.rawValue, privacy: .public), context=\(context, privacy: .private)"
            )
        }
    }

    static func logCandidateCounts(raw: Int, currentWorkspace: Int) {
        reliabilityLogger.log(
            "Candidate counts: raw=\(raw, privacy: .public), currentWorkspace=\(currentWorkspace, privacy: .public)"
        )
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
