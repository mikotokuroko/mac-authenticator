import AuthenticatorCore
import SwiftUI

struct ContentView: View {
  @ObservedObject var model: AppModel
  @State private var removal: OTPAccount?
  @AppStorage("simplifiedView") private var simplified = true
  @AppStorage("minimalDefaultApplied") private var minimalDefaultApplied = false
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  private let blue = Color.accentColor
  private var compact: Bool { simplified && model.unlocked && !model.accounts.isEmpty }
  private var visibleAccounts: [OTPAccount] { compact ? model.accounts : model.filteredAccounts }
  var body: some View {
    VStack(spacing: 0) {
      if !compact {
        HStack(spacing: 12) {
          Text(model.demo ? "Sample Codes" : "Authenticator")
            .font(.headline)
          Spacer()
          if model.unlocked {
            Menu {
              Button("Import QR Image…", action: model.importFile)
              Button("Paste QR", action: model.importClipboard)
            } label: {
              Image(systemName: "plus").frame(width: 28, height: 28)
            }
            .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
            .disabled(model.demo).accessibilityLabel("Add Account").help("Add Account")
          }
        }.padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 12)
      }
      if model.unlocked { codes } else { locked }
      if let error = model.error {
        Text(error).font(.callout).foregroundStyle(.red).frame(
          maxWidth: .infinity, alignment: .leading
        ).padding(.horizontal, 20).padding(.bottom, 14)
      }
      if !compact, let message = model.message {
        Text(message).font(.caption).foregroundStyle(.secondary).frame(
          maxWidth: .infinity, alignment: .leading
        ).padding(.horizontal, 20).padding(.bottom, 14)
      }

    }
    .frame(width: compact ? 300 : 340)
    // NSPopover owns the material; avoid a second glass surface.
    .modifier(AccessiblePopoverSurface())
    .animation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 1), value: compact)
    .onAppear {
      if !minimalDefaultApplied {
        simplified = true
        minimalDefaultApplied = true
      }
    }
    .contextMenu { options }
    .onChange(of: simplified) { _, _ in model.search = "" }
    .confirmationDialog(
      "Remove this account from your Mac?",
      isPresented: Binding(get: { removal != nil }, set: { if !$0 { removal = nil } }),
      titleVisibility: .visible
    ) {
      Button("Remove account", role: .destructive) {
        if let account = removal { model.remove(account) }
        removal = nil
      }
      Button("Cancel", role: .cancel) { removal = nil }
    } message: {
      Text("It will remain in Google Authenticator on your iPhone.")
    }
  }
  @ViewBuilder private var options: some View {
    Toggle("Simplified View", isOn: $simplified)
    Divider()
    if model.unlocked {
      Button("Lock Codes", action: model.lock)
      Button("Import QR Image…", action: model.importFile).disabled(model.demo)
      Button("Paste QR", action: model.importClipboard).disabled(model.demo)
      Divider()
    }
    Button("Quit Authenticator") {
      model.lock()
      NSApplication.shared.terminate(nil)
    }
  }
  private var locked: some View {
    VStack(spacing: 16) {
      Image(systemName: "touchid").font(.system(size: 36, weight: .regular)).foregroundStyle(
        blue
      ).padding(.top, 14)
      VStack(spacing: 7) {
        Text("Unlock Your Codes").font(.title3.weight(.semibold))
        Text("Unlock with Touch ID or your Mac password.").font(.callout).foregroundStyle(
          .secondary)
      }
      Button(action: model.unlock) {
        HStack {
          if model.busy { ProgressView().controlSize(.small) }
          Text(model.busy ? "Unlocking…" : "Unlock Codes")
        }.frame(width: 180)
      }.buttonStyle(.borderedProminent).tint(blue).controlSize(.large).disabled(model.busy)
        .keyboardShortcut(.defaultAction).padding(.bottom, 12)
    }.frame(maxWidth: .infinity).padding(20)
  }
  private var codes: some View {
    VStack(spacing: 12) {
      if model.accounts.isEmpty {
        VStack(spacing: 12) {
          Image(systemName: "qrcode.viewfinder").font(.system(size: 42, weight: .light))
            .foregroundStyle(blue)
          Text("Add Your First Account").font(.title3.weight(.semibold))
          Text(
            "On your iPhone, open Google Authenticator → Transfer accounts → Export accounts. Import each QR image here once."
          )
          .font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center).fixedSize(
            horizontal: false, vertical: true)
          Text("Your iPhone keeps working as usual.").font(.caption).foregroundStyle(.secondary)
        }.padding(.vertical, 18)
      } else {
        if !compact {
          HStack {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Find an account", text: $model.search).textFieldStyle(.plain)
          }.padding(10).background(
            .quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
        }
        ScrollView {
          LazyVStack(spacing: 0) {
            ForEach(visibleAccounts) { account in
              TimelineView(.periodic(from: .now, by: 1)) { timeline in
                accountRow(account, date: timeline.date)
              }
              .contextMenu {
                options
                Divider()
                Button("Remove from Mac…", role: .destructive) { removal = account }
                  .disabled(model.demo)
              }
              if account.id != visibleAccounts.last?.id {
                Divider().frame(height: 1).padding(.horizontal, 12)
              }
            }
            if visibleAccounts.isEmpty {
              Text("No matching accounts").foregroundStyle(.secondary).padding(24)
            }
          }
        }.frame(
          height: min(
            compact ? 380 : 330,
            CGFloat(max(1, visibleAccounts.count)) * (compact ? 78 : 112)
              + CGFloat(max(0, visibleAccounts.count - 1))))
      }
      if model.accounts.isEmpty {
        HStack(spacing: 10) {
          Button(action: model.importFile) {
            Label("Import QR Image…", systemImage: "plus").frame(maxWidth: .infinity)
          }
          Button(action: model.importClipboard) {
            Label("Paste QR", systemImage: "doc.on.clipboard").frame(maxWidth: .infinity)
          }
        }.controlSize(.large).disabled(model.demo)
      }
    }.padding(.horizontal, compact ? 4 : 20)
      .padding(.vertical, compact ? 4 : 0)
      .padding(.bottom, compact ? 0 : 12)
  }
  private func accountRow(_ account: OTPAccount, date: Date) -> some View {
    let code = account.code(at: date)
    let middle = code.index(code.startIndex, offsetBy: code.count / 2)
    let display = String(code[..<middle]) + " " + String(code[middle...])
    let remaining = account.remaining(at: date)
    return Button {
      model.copy(account)
    } label: {
      VStack(alignment: .leading, spacing: 9) {
        HStack(alignment: .top) {
          VStack(alignment: .leading, spacing: 3) {
            Text(
              account.issuer.isEmpty
                ? account.name : compact ? "\(account.issuer) · \(account.name)" : account.issuer
            )
            .font(.system(size: 13, weight: .medium)).lineLimit(1)
            if !compact && !account.issuer.isEmpty {
              Text(account.name).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
            }
          }
          Spacer()
          if model.copiedID == account.id {
            Label("Copied", systemImage: "checkmark")
              .font(.system(size: 11)).foregroundStyle(.secondary)
          }
        }
        HStack(alignment: .center) {
          Text(display).font(.system(size: compact ? 28 : 30, weight: .medium, design: .default))
            .monospacedDigit().foregroundStyle(.primary)
          Spacer()
          ZStack {
            Circle().stroke(blue.opacity(0.12), lineWidth: 2)
            Circle().trim(from: 0, to: Double(remaining) / Double(account.period)).stroke(
              remaining <= 5 ? Color.orange : blue,
              style: StrokeStyle(lineWidth: 2, lineCap: .round)
            ).rotationEffect(.degrees(-90))
            Text("\(remaining)").font(.system(size: 11, weight: .medium, design: .default))
              .foregroundStyle(.secondary)
          }.frame(width: 28, height: 28)
        }
      }.padding(.horizontal, compact ? 8 : 14)
        .padding(.vertical, compact ? 6 : 14)
        .frame(height: compact ? 78 : nil, alignment: .center)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(RoundedRectangle(cornerRadius: 14))
    }.buttonStyle(CodeButtonStyle()).help(account.name + " — Click to copy").accessibilityLabel(
      "\(account.issuer) \(account.name), code \(code), \(remaining) seconds remaining. Copy code.")
  }
}

private struct AccessiblePopoverSurface: ViewModifier {
  @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
  @Environment(\.colorSchemeContrast) private var contrast
  func body(content: Content) -> some View {
    content.background {
      if reduceTransparency || contrast == .increased {
        Color(nsColor: .windowBackgroundColor)
      }
    }
  }
}

private struct CodeButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    CodeButtonBody(configuration: configuration)
  }
  private struct CodeButtonBody: View {
    let configuration: Configuration
    @State private var hovered = false
    @Environment(\.colorSchemeContrast) private var contrast
    var body: some View {
      configuration.label
        .background {
          RoundedRectangle(cornerRadius: 8)
            .fill(Color.primary.opacity(configuration.isPressed ? 0.12 : hovered ? 0.06 : 0))
        }
        .overlay {
          if hovered && contrast == .increased {
            RoundedRectangle(cornerRadius: 8).stroke(.primary, lineWidth: 1)
          }
        }
        .onHover { hovered = $0 }
    }
  }
}
