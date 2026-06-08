import AppKit

let application = NSApplication.shared
let delegate = AppDelegate()

application.delegate = delegate
// Run as a menu-bar accessory app instead of showing a Dock icon.
application.setActivationPolicy(.accessory)
application.run()
