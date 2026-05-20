import Foundation
import ServiceManagement

/// Launch-at-login, managed via `SMAppService`. The enabled state is owned by
/// the system, so it is read/written here rather than stored in `Settings`.
enum LoginItem {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Registers/unregisters GrammarCat as a login item.
    /// Returns the resulting state (may differ from `enabled` if the call fails).
    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
        } catch {
            NSLog("GrammarCat: launch-at-login toggle failed — \(error)")
        }
        return isEnabled
    }
}
