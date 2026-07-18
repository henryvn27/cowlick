import Foundation
import Observation

@MainActor
@Observable
final class AppServices {
  static let shared = AppServices()

  let settings: SettingsStore
  let eventLogger: EventLogger
  let approvalCoordinator: ApprovalCoordinator
  let capsLockService: NativeCapsLockSignalService
  let sessionStore: SessionStore
  let hookInstaller: HookInstaller
  let updateService: UpdateService

  private init() {
    settings = SettingsStore()
    eventLogger = EventLogger()
    approvalCoordinator = ApprovalCoordinator()
    capsLockService = NativeCapsLockSignalService()
    sessionStore = SessionStore(
      settings: settings,
      eventLogger: eventLogger,
      approvalCoordinator: approvalCoordinator,
      capsLockService: capsLockService
    )
    hookInstaller = HookInstaller()
    updateService = UpdateService()
    updateService.configure(
      automaticChecks: settings.automaticUpdateChecks,
      automaticDownloads: settings.automaticUpdateDownloads
    )
  }
}
