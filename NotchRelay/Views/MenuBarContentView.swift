import AppKit
import SwiftUI

struct MenuBarLabelView: View {
  let store: SessionStore

  var body: some View {
    Label {
      Text(store.activeSessionCount > 0 ? "\(store.activeSessionCount)" : "")
    } icon: {
      Image(systemName: menuIcon)
    }
    .accessibilityLabel("NotchRelay, \(store.displaySession?.status.shortLabel ?? "Idle")")
  }

  private var menuIcon: String {
    guard let status = store.displaySession?.status else { return "waveform.path" }
    return switch status {
    case .working: "waveform.path"
    case .awaitingApproval: "exclamationmark.shield"
    case .completed: "checkmark.circle"
    case .failed: "xmark.circle"
    case .idle: "waveform.path"
    }
  }
}

struct MenuBarContentView: View {
  let services: AppServices

  var body: some View {
    let store = services.sessionStore
    Text(store.displaySession?.status.shortLabel ?? "Idle")
    if store.activeSessionCount > 0 {
      Text("\(store.activeSessionCount) active")
    }

    if !store.sessionSummaries.isEmpty {
      Divider()
      ForEach(store.sessionSummaries.prefix(5)) { session in
        Button(shortLabel("\(session.projectName) · \(session.status.shortLabel)")) {
          WindowCoordinator.shared.openIsland()
        }
      }
    }

    Divider()
    Button("Open Island") { WindowCoordinator.shared.openIsland() }
    Button("Open Codex") {
      CodexActivationService.openCodex(fallbackDirectory: store.displaySession?.workingDirectory)
    }
    Menu("Test State") {
      Button("Working") { store.testState(.working) }
      Button("Approval") { store.testState(.approvalRequested) }
      Button("Completed") { store.testState(.completed) }
      Button("Failed") { store.testState(.failed) }
      Button("Reset") { store.reset() }
    }
    SettingsLink { Text("Settings…") }
    Button("Diagnostics…") { WindowCoordinator.shared.openDiagnostics() }
    Button("Check for Updates…") { services.updateService.checkForUpdates() }
      .disabled(!services.updateService.canCheckForUpdates)
    Divider()
    Button("Quit NotchRelay") { NSApplication.shared.terminate(nil) }
      .keyboardShortcut("q")
  }

  private func shortLabel(_ value: String) -> String {
    guard value.count > 30 else { return value }
    return String(value.prefix(27)) + "…"
  }
}
