import AppKit
import SwiftUI
import AuthenticatorCore

@main enum MacAuthenticatorApp {
    @MainActor static func main() {
        if CommandLine.arguments.contains("--keychain-self-test") {
            AppDelegate.keychainSelfTest()
            return
        }
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private let popover = NSPopover()
    private var model: AppModel?
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let menu = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Quit Authenticator", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu; menu.addItem(appItem)
        NSApp.mainMenu = menu
        let model = AppModel(demo: CommandLine.arguments.contains("--demo"))
        self.model = model
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: ContentView(model: model))
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "key.horizontal", accessibilityDescription: "Authenticator")
        item.button?.toolTip = "Authenticator — verification codes"
        item.button?.target = self; item.button?.action = #selector(toggle)
        statusItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { self.toggle() }
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !popover.isShown { toggle() }
        return false
    }
    @objc private func toggle() {
        if popover.isShown { popover.performClose(nil) }
        else if let button = statusItem?.button {
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
    func applicationWillTerminate(_ notification: Notification) { model?.lock() }
    static func keychainSelfTest() {
        var vault = KeychainVault()
        vault.service = "local.lam.mac-authenticator.selftest.\(UUID().uuidString)"
        let result: String
        do {
            defer { try? vault.delete() }
            let account = try OTPAccount(name: "dummy", issuer: "Test", secret: Data("dummy-not-a-real-secret".utf8))
            try vault.save([account])
            guard try vault.load() == [account] else { throw OTPError.invalid("Round trip mismatch") }
            try vault.save([])
            guard try vault.load().isEmpty else { throw OTPError.invalid("Update mismatch") }
            try vault.delete()
            guard try vault.load().isEmpty else { throw OTPError.invalid("Delete mismatch") }
            result = "PASS: dummy Keychain create, read, update and delete.\n"
        } catch { result = "FAIL: \(error.localizedDescription)\n" }
        try? result.write(toFile: "/tmp/mac-authenticator-keychain-check.txt", atomically: true, encoding: .utf8)
    }
}
