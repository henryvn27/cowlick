import XCTest

@testable import NotchRelay

@MainActor
final class SettingsStoreTests: XCTestCase {
  func testPrivacyDefaultsAndPersistence() {
    let suite = "com.henryvn27.NotchRelayTests.Settings.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.removePersistentDomain(forName: suite)

    let first = SettingsStore(defaults: defaults)
    XCTAssertFalse(first.showPromptPreviews)
    XCTAssertFalse(first.showResultPreviews)
    XCTAssertFalse(first.capsLockEnabled)
    XCTAssertTrue(first.automaticUpdateChecks)
    first.showPromptPreviews = true
    first.approvalTimeout = 35

    let second = SettingsStore(defaults: defaults)
    XCTAssertTrue(second.showPromptPreviews)
    XCTAssertEqual(second.approvalTimeout, 35)
  }

  func testResetRestoresSafeDefaults() {
    let settings = makeTestSettings()
    settings.showPromptPreviews = true
    settings.showResultPreviews = true
    settings.capsLockEnabled = true
    settings.reset()

    XCTAssertFalse(settings.showPromptPreviews)
    XCTAssertFalse(settings.showResultPreviews)
    XCTAssertFalse(settings.capsLockEnabled)
  }
}
