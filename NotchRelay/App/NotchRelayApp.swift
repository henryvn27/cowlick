import AppKit
import SwiftUI

@main
struct NotchRelayApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
  private let services = AppServices.shared

  var body: some Scene {
    MenuBarExtra {
      MenuBarContentView(services: services)
    } label: {
      MenuBarLabelView(store: services.sessionStore)
    }
    .menuBarExtraStyle(.menu)

    Settings {
      SettingsView(services: services)
    }
  }
}
