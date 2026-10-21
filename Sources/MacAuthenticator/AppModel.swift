import AppKit
import SwiftUI
import LocalAuthentication
import UniformTypeIdentifiers
import AuthenticatorCore

@MainActor final class AppModel: ObservableObject {
    @Published private(set) var accounts: [OTPAccount] = []
    @Published private(set) var unlocked = false
    @Published private(set) var busy = false
    @Published var search = ""
    @Published var message: String?
    @Published var error: String?
    @Published var copiedID: UUID?
    private let vault = KeychainVault()
    private var context: LAContext?
    private var session = UUID()
    private var clipboardChange: Int?
    private var clipboardTask: Task<Void, Never>?
    private var observers: [NSObjectProtocol] = []
    let demo: Bool

    init(demo: Bool = false) {
        self.demo = demo
        if demo {
            accounts = [
                try! OTPAccount(name: "lam@example.com", issuer: "Google", secret: Data("demo-google-not-a-real-account".utf8)),
                try! OTPAccount(name: "lam", issuer: "GitHub", secret: Data("demo-github-not-a-real-account".utf8))
            ]
            unlocked = true
        }
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.sessionDidResignActiveNotification, NSWorkspace.screensDidSleepNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.lock() }
            })
        }
        observers.append(DistributedNotificationCenter.default().addObserver(forName: NSNotification.Name("com.apple.screenIsLocked"), object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.lock() }
        })
    }

    var filteredAccounts: [OTPAccount] {
        accounts.filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) || $0.issuer.localizedCaseInsensitiveContains(search) }
    }
    func unlock() {
        guard !busy else { return }
        busy = true; error = nil
        let attempt = session
        let authentication = LAContext()
        context = authentication
        Task {
            do {
                let accepted = try await authentication.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Show your verification codes")
                guard accepted, session == attempt else { return }
                do {
                    let loaded = try vault.load()
                    guard session == attempt else { return }
                    accounts = loaded; unlocked = true; busy = false
                } catch {
                    busy = false
                    self.error = error.localizedDescription
                }
            } catch {
                guard session == attempt else { return }
                busy = false
                let code = (error as NSError).code
                if code != LAError.userCancel.rawValue && code != LAError.appCancel.rawValue && code != LAError.systemCancel.rawValue {
                    self.error = "Couldn’t unlock. Try again using Touch ID or your Mac password."
                }
            }
        }
    }
    func lock() {
        session = UUID(); context?.invalidate(); context = nil
        accounts = []; unlocked = false; busy = false
        search = ""; message = nil; error = nil; copiedID = nil
        clearOwnedClipboard()
    }
    func copy(_ account: OTPAccount) {
        guard unlocked, accounts.contains(where: { $0.id == account.id }) else { return }
        let board = NSPasteboard.general
        board.clearContents()
        board.setString(account.code(), forType: .string)
        board.setData(Data(), forType: NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType"))
        clipboardChange = board.changeCount; copiedID = account.id
        clipboardTask?.cancel()
        let change = board.changeCount
        clipboardTask = Task {
            try? await Task.sleep(for: .seconds(30))
            guard !Task.isCancelled, clipboardChange == change else { return }
            clearOwnedClipboard(); copiedID = nil
        }
    }
    private func clearOwnedClipboard() {
        clipboardTask?.cancel(); clipboardTask = nil
        if let count = clipboardChange, NSPasteboard.general.changeCount == count { NSPasteboard.general.clearContents() }
        clipboardChange = nil
    }
    func importFile() {
        guard unlocked, !demo else { return }
        let attempt = session
        let panel = NSOpenPanel()
        panel.title = "Import authenticator QR image"
        panel.allowedContentTypes = [.png, .jpeg, .tiff, .heic]
        panel.allowsMultipleSelection = false
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, session == attempt, unlocked, let url = panel.url else { return }
        do {
            let values = try url.resourceValues(forKeys: [.fileSizeKey])
            guard (values.fileSize ?? 0) <= 20_000_000, let image = NSImage(contentsOf: url) else { throw OTPError.invalid("Choose a QR image smaller than 20 MB.") }
            try importImage(image)
        } catch { self.error = error.localizedDescription }
    }
    func importClipboard() {
        guard unlocked, !demo else { return }
        do {
            let board = NSPasteboard.general
            if let image = NSImage(pasteboard: board) { try importImage(image) }
            else if let text = board.string(forType: .string) { try importPayloads([text]) }
            else { throw OTPError.invalid("Copy a QR image first, then choose Paste QR.") }
        } catch { self.error = error.localizedDescription }
    }
    private func importImage(_ image: NSImage) throws {
        var rect = CGRect(origin: .zero, size: image.size)
        guard let cgImage = image.cgImage(forProposedRect: &rect, context: nil, hints: nil),
              cgImage.width <= 12000, cgImage.height <= 12000 else { throw OTPError.invalid("The QR image could not be read. Try a smaller screenshot.") }
        let payloads = try QRImageReader.payloads(in: cgImage)
        try importPayloads(payloads)
    }
    private func importPayloads(_ payloads: [String]) throws {
        guard unlocked else { return }
        let results = try payloads.map(OTPImport.parse)
        var updated = accounts, added = 0
        for account in results.flatMap(\.accounts) where !updated.contains(where: { $0.isSameCredential(as: account) }) {
            updated.append(account); added += 1
        }
        if added > 0 { try vault.save(updated); accounts = updated }
        let batch = results.filter { $0.batchSize > 1 }.map { "QR \($0.batchIndex + 1) of \($0.batchSize). Import the other export images too." }.joined(separator: " ")
        message = (added == 0 ? "These accounts are already imported." : "Imported \(added) account\(added == 1 ? "" : "s").") + (batch.isEmpty ? "" : " " + batch)
        error = nil
    }
    func remove(_ account: OTPAccount) {
        guard unlocked, !demo else { return }
        let updated = accounts.filter { $0.id != account.id }
        do { try vault.save(updated); accounts = updated; message = "Removed from this Mac. The iPhone entry is unchanged." }
        catch { self.error = error.localizedDescription }
    }
}
