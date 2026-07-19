import XCTest

@testable import Cowlick

final class HookInstallerTests: XCTestCase {
  private let command = "/Users/test/.local/bin/cowlick-hook hook"
  private let legacyCommand = "/Users/test/.local/bin/notchrelay-hook hook"

  func testMergeIsIdempotent() throws {
    let first = try HookInstaller.merging(Data("{}".utf8), command: command)
    let second = try HookInstaller.merging(first, command: command)
    XCTAssertEqual(first, second)
  }

  func testMergePreservesUnrelatedHooksAndUnknownFields() throws {
    let original = Data(
      #"{"future":{"enabled":true},"hooks":{"Stop":[{"matcher":"keep","hooks":[{"type":"command","command":"/usr/local/bin/other"}]}]}}"#
        .utf8)
    let merged = try HookInstaller.merging(original, command: command)
    let root = try XCTUnwrap(JSONSerialization.jsonObject(with: merged) as? [String: Any])
    let future = try XCTUnwrap(root["future"] as? [String: Any])
    let hooks = try XCTUnwrap(root["hooks"] as? [String: Any])
    let stopGroups = try XCTUnwrap(hooks["Stop"] as? [[String: Any]])

    XCTAssertEqual(future["enabled"] as? Bool, true)
    XCTAssertEqual(stopGroups.first?["matcher"] as? String, "keep")
    XCTAssertEqual(stopGroups.count, 2)
  }

  func testRemovalPreservesUnrelatedHandlersAndFields() throws {
    let original = Data(
      #"{"unknown":42,"hooks":{"Stop":[{"hooks":[{"type":"command","command":"/Users/test/.local/bin/cowlick-hook hook"},{"type":"command","command":"/usr/local/bin/other"}]}]}}"#
        .utf8)
    let removed = try HookInstaller.removing(original, command: command)
    let root = try XCTUnwrap(JSONSerialization.jsonObject(with: removed) as? [String: Any])
    let hooks = try XCTUnwrap(root["hooks"] as? [String: Any])
    let groups = try XCTUnwrap(hooks["Stop"] as? [[String: Any]])
    let handlers = try XCTUnwrap(groups.first?["hooks"] as? [[String: Any]])

    XCTAssertEqual(root["unknown"] as? Int, 42)
    XCTAssertEqual(handlers.count, 1)
    XCTAssertEqual(handlers.first?["command"] as? String, "/usr/local/bin/other")
  }

  func testRemovalAfterMergeRestoresSemanticOriginal() throws {
    let original = Data(
      #"{"hooks":{"SessionStart":[{"hooks":[{"type":"command","command":"/usr/local/bin/existing"}]}]},"custom":"value"}"#
        .utf8)
    let merged = try HookInstaller.merging(original, command: command)
    let removed = try HookInstaller.removing(merged)
    let root = try XCTUnwrap(JSONSerialization.jsonObject(with: removed) as? NSDictionary)
    let expected = try XCTUnwrap(JSONSerialization.jsonObject(with: original) as? NSDictionary)
    XCTAssertEqual(root, expected)
  }

  func testRejectsNonObjectRoot() {
    XCTAssertThrowsError(try HookInstaller.merging(Data("[]".utf8), command: command))
  }

  func testRemovalDoesNotClaimCompoundForeignCommand() throws {
    let original = Data(
      """
      {"hooks":{"Stop":[{"hooks":[{"type":"command","command":"printf foreign && \(command)"}]}]}}
      """.utf8)

    let removed = try HookInstaller.removing(original, command: command)

    XCTAssertEqual(
      try JSONSerialization.jsonObject(with: removed) as? NSDictionary,
      try JSONSerialization.jsonObject(with: original) as? NSDictionary)
  }

  func testMergeReplacesLegacyHandlersExactlyOnce() throws {
    let original = Data(
      """
      {"hooks":{"Stop":[{"hooks":[{"type":"command","command":"\(legacyCommand)","notchRelay":{"product":"NotchRelay","protocol":1}}]}]}}
      """.utf8)

    let merged = try HookInstaller.merging(
      original, command: command, legacyCommands: [legacyCommand])
    let mergedAgain = try HookInstaller.merging(
      merged, command: command, legacyCommands: [legacyCommand])
    let root = try XCTUnwrap(JSONSerialization.jsonObject(with: mergedAgain) as? [String: Any])
    let hooks = try XCTUnwrap(root["hooks"] as? [String: Any])

    for event in HookInstaller.supportedEvents {
      let groups = try XCTUnwrap(hooks[event] as? [[String: Any]])
      let handlers = groups.flatMap { $0["hooks"] as? [[String: Any]] ?? [] }
      XCTAssertEqual(handlers.count, 1)
      XCTAssertEqual(handlers.first?["command"] as? String, command)
      XCTAssertNil(handlers.first?["notchRelay"])
    }
  }

  func testRemovalRemovesBothCurrentAndLegacyHandlers() throws {
    let original = Data(
      """
      {"future":true,"hooks":{"Stop":[{"hooks":[{"type":"command","command":"\(command)"},{"type":"command","command":"\(legacyCommand)"},{"type":"command","command":"/usr/local/bin/other"}]}]}}
      """.utf8)

    let removed = try HookInstaller.removing(
      original, command: command, legacyCommands: [legacyCommand])
    let root = try XCTUnwrap(JSONSerialization.jsonObject(with: removed) as? [String: Any])
    let hooks = try XCTUnwrap(root["hooks"] as? [String: Any])
    let groups = try XCTUnwrap(hooks["Stop"] as? [[String: Any]])
    let handlers = try XCTUnwrap(groups.first?["hooks"] as? [[String: Any]])

    XCTAssertEqual(root["future"] as? Bool, true)
    XCTAssertEqual(handlers.map { $0["command"] as? String }, ["/usr/local/bin/other"])
  }

  func testStatusRejectsOwnedButOutdatedHelper() throws {
    let fixture = try makeInstaller(bundledContents: "current-helper")
    defer { try? FileManager.default.removeItem(at: fixture.home) }
    try installOwnedHelper(fixture.installer, contents: "pre-ack-helper")

    XCTAssertFalse(fixture.installer.status().helperInstalled)
  }

  func testRefreshAtomicallyUpgradesHelperWithoutChangingHooksOrSettings() throws {
    let fixture = try makeInstaller(bundledContents: "current-helper")
    defer { try? FileManager.default.removeItem(at: fixture.home) }
    try installOwnedHelper(fixture.installer, contents: "pre-ack-helper")
    let oldHandle = try FileHandle(forReadingFrom: fixture.installer.installedHelperURL)
    defer { try? oldHandle.close() }

    let hooks = Data(#"{"future":{"enabled":true},"hooks":{"Stop":[]}}"#.utf8)
    let settings = Data("model = \"gpt-5.6\"\n".utf8)
    try FileManager.default.createDirectory(
      at: fixture.installer.hooksURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try hooks.write(to: fixture.installer.hooksURL)
    let settingsURL = fixture.installer.hooksURL.deletingLastPathComponent()
      .appendingPathComponent("settings.toml")
    try settings.write(to: settingsURL)

    try fixture.installer.refreshInstalledHelperIfNeeded()

    XCTAssertEqual(
      try Data(contentsOf: fixture.installer.installedHelperURL), Data("current-helper".utf8))
    XCTAssertEqual(try oldHandle.readToEnd(), Data("pre-ack-helper".utf8))
    XCTAssertEqual(try Data(contentsOf: fixture.installer.hooksURL), hooks)
    XCTAssertEqual(try Data(contentsOf: settingsURL), settings)
    XCTAssertTrue(fixture.installer.status().helperInstalled)
  }

  func testFailedAtomicRefreshPreservesPreviousInstallHooksAndSettings() throws {
    let fixture = try makeInstaller(bundledContents: "current-helper")
    defer { try? FileManager.default.removeItem(at: fixture.home) }
    try FileManager.default.createDirectory(
      at: fixture.installer.installedHelperURL, withIntermediateDirectories: true)
    let marker = fixture.installer.installedHelperURL.appendingPathComponent("old-helper-marker")
    try Data("pre-ack-helper".utf8).write(to: marker)
    try FileManager.default.createDirectory(
      at: fixture.installer.shimURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try FileManager.default.createSymbolicLink(
      at: fixture.installer.shimURL, withDestinationURL: fixture.installer.installedHelperURL)

    let hooks = Data(#"{"custom":"preserve","hooks":{}}"#.utf8)
    let settings = Data("approval_timeout = 60\n".utf8)
    try FileManager.default.createDirectory(
      at: fixture.installer.hooksURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try hooks.write(to: fixture.installer.hooksURL)
    let settingsURL = fixture.installer.hooksURL.deletingLastPathComponent()
      .appendingPathComponent("settings.toml")
    try settings.write(to: settingsURL)

    XCTAssertThrowsError(try fixture.installer.refreshInstalledHelperIfNeeded()) { error in
      guard case HookInstallerError.helperReplacementFailed = error else {
        return XCTFail("Expected atomic replacement failure, got \(error)")
      }
    }
    XCTAssertEqual(try Data(contentsOf: marker), Data("pre-ack-helper".utf8))
    XCTAssertEqual(try Data(contentsOf: fixture.installer.hooksURL), hooks)
    XCTAssertEqual(try Data(contentsOf: settingsURL), settings)
  }

  func testDeveloperBuildRequiresExplicitRepairBeforeReplacingPersistentHelper() throws {
    let fixture = try makeInstaller(
      bundledContents: "developer-helper", installedApplication: false)
    defer { try? FileManager.default.removeItem(at: fixture.home) }
    try installOwnedHelper(fixture.installer, contents: "installed-helper")

    try fixture.installer.refreshInstalledHelperIfNeeded()
    XCTAssertEqual(
      try Data(contentsOf: fixture.installer.installedHelperURL), Data("installed-helper".utf8))
    XCTAssertThrowsError(try fixture.installer.currentInstalledHelperURL()) { error in
      guard case HookInstallerError.automaticHelperRefreshUnavailable = error else {
        return XCTFail("Expected developer-location rejection, got \(error)")
      }
    }

    try fixture.installer.installOrRepair()
    XCTAssertEqual(
      try Data(contentsOf: fixture.installer.installedHelperURL), Data("developer-helper".utf8))
    XCTAssertEqual(
      try fixture.installer.installedHelperURLForExplicitSelfTest(),
      fixture.installer.installedHelperURL)
  }

  func testUITestBuildNeverRefreshesPersistentHelper() throws {
    let fixture = try makeInstaller(bundledContents: "ui-test-helper", arguments: ["--ui-testing"])
    defer { try? FileManager.default.removeItem(at: fixture.home) }
    try installOwnedHelper(fixture.installer, contents: "installed-helper")
    let hooks = Data(#"{"custom":"preserve","hooks":{}}"#.utf8)
    try FileManager.default.createDirectory(
      at: fixture.installer.hooksURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try hooks.write(to: fixture.installer.hooksURL)

    try fixture.installer.refreshInstalledHelperIfNeeded()

    XCTAssertEqual(
      try Data(contentsOf: fixture.installer.installedHelperURL), Data("installed-helper".utf8))
    XCTAssertThrowsError(try fixture.installer.currentInstalledHelperURL())
    XCTAssertThrowsError(try fixture.installer.installedHelperURLForExplicitSelfTest())
    XCTAssertThrowsError(try fixture.installer.installOrRepair())
    XCTAssertThrowsError(try fixture.installer.removeHooks())
    XCTAssertThrowsError(try fixture.installer.removeIntegration())
    XCTAssertEqual(try Data(contentsOf: fixture.installer.hooksURL), hooks)
    XCTAssertEqual(
      try Data(contentsOf: fixture.installer.installedHelperURL), Data("installed-helper".utf8))
    XCTAssertEqual(
      try FileManager.default.destinationOfSymbolicLink(atPath: fixture.installer.shimURL.path),
      fixture.installer.installedHelperURL.path)
  }

  func testAutomaticRefreshPolicyAcceptsOnlyCanonicalNonSymlinkedInstallLocations() throws {
    let home = FileManager.default.temporaryDirectory
      .appendingPathComponent("CowlickInstaller-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: home) }
    let userInstall = home.appendingPathComponent("Applications/Cowlick.app", isDirectory: true)
    let developerBuild = home.appendingPathComponent(
      "DerivedData/Build/Products/Debug/Cowlick.app", isDirectory: true)

    XCTAssertTrue(
      HookInstaller.allowsAutomaticHelperRefresh(
        applicationBundleURL: userInstall, homeDirectory: home, arguments: []))
    XCTAssertTrue(
      HookInstaller.allowsAutomaticHelperRefresh(
        applicationBundleURL: URL(fileURLWithPath: "/Applications/Cowlick.app"),
        homeDirectory: home,
        arguments: []))
    XCTAssertFalse(
      HookInstaller.allowsAutomaticHelperRefresh(
        applicationBundleURL: developerBuild, homeDirectory: home, arguments: []))
    XCTAssertFalse(
      HookInstaller.allowsAutomaticHelperRefresh(
        applicationBundleURL: userInstall, homeDirectory: home, arguments: ["--ui-testing"]))

    try FileManager.default.createDirectory(
      at: developerBuild, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(
      at: userInstall.deletingLastPathComponent(), withIntermediateDirectories: true)
    try FileManager.default.createSymbolicLink(at: userInstall, withDestinationURL: developerBuild)
    XCTAssertFalse(
      HookInstaller.allowsAutomaticHelperRefresh(
        applicationBundleURL: userInstall, homeDirectory: home, arguments: []))
  }

  func testRefreshReplacesSymlinkedHelperWithoutChangingItsTarget() throws {
    let fixture = try makeInstaller(bundledContents: "current-helper")
    defer { try? FileManager.default.removeItem(at: fixture.home) }
    let externalHelper = fixture.home.appendingPathComponent("external-helper")
    try Data("current-helper".utf8).write(to: externalHelper)
    try FileManager.default.setAttributes(
      [.posixPermissions: 0o755], ofItemAtPath: externalHelper.path)
    try FileManager.default.createDirectory(
      at: fixture.installer.installedHelperURL.deletingLastPathComponent(),
      withIntermediateDirectories: true)
    try FileManager.default.createSymbolicLink(
      at: fixture.installer.installedHelperURL, withDestinationURL: externalHelper)
    try FileManager.default.createDirectory(
      at: fixture.installer.shimURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try FileManager.default.createSymbolicLink(
      at: fixture.installer.shimURL, withDestinationURL: fixture.installer.installedHelperURL)

    XCTAssertFalse(fixture.installer.status().helperInstalled)
    try fixture.installer.refreshInstalledHelperIfNeeded()

    XCTAssertThrowsError(
      try FileManager.default.destinationOfSymbolicLink(
        atPath: fixture.installer.installedHelperURL.path))
    XCTAssertEqual(try Data(contentsOf: externalHelper), Data("current-helper".utf8))
    XCTAssertTrue(fixture.installer.status().helperInstalled)
  }

  func testRemoveIntegrationPreservesUnrelatedHooksAndSettings() throws {
    let fixture = try makeInstaller(bundledContents: "current-helper")
    defer { try? FileManager.default.removeItem(at: fixture.home) }
    let originalHooks = Data(
      #"{"future":{"enabled":true},"hooks":{"Stop":[{"matcher":"keep","hooks":[{"type":"command","command":"/usr/local/bin/other"}]}]}}"#
        .utf8)
    let settings = Data("model = \"gpt-5.6\"\n".utf8)
    try FileManager.default.createDirectory(
      at: fixture.installer.hooksURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try originalHooks.write(to: fixture.installer.hooksURL)
    let settingsURL = fixture.installer.hooksURL.deletingLastPathComponent()
      .appendingPathComponent("settings.toml")
    try settings.write(to: settingsURL)
    try fixture.installer.installOrRepair()

    try fixture.installer.removeIntegration()

    XCTAssertThrowsError(
      try FileManager.default.destinationOfSymbolicLink(atPath: fixture.installer.shimURL.path))
    XCTAssertFalse(
      FileManager.default.fileExists(atPath: fixture.installer.installedHelperURL.path))
    XCTAssertEqual(
      try JSONSerialization.jsonObject(with: Data(contentsOf: fixture.installer.hooksURL))
        as? NSDictionary,
      try JSONSerialization.jsonObject(with: originalHooks) as? NSDictionary)
    XCTAssertEqual(try Data(contentsOf: settingsURL), settings)
  }

  func testRemoveIntegrationRefusesForeignShimWithoutChangingAnything() throws {
    let fixture = try makeInstaller(bundledContents: "current-helper")
    defer { try? FileManager.default.removeItem(at: fixture.home) }
    try installOwnedHelper(fixture.installer, contents: "current-helper")
    try FileManager.default.removeItem(at: fixture.installer.shimURL)
    try Data("foreign-shim".utf8).write(to: fixture.installer.shimURL)
    let hooks = try HookInstaller.merging(Data("{}".utf8), command: command)
    try FileManager.default.createDirectory(
      at: fixture.installer.hooksURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try hooks.write(to: fixture.installer.hooksURL)

    XCTAssertThrowsError(try fixture.installer.removeIntegration()) { error in
      guard case HookInstallerError.shimConflict = error else {
        return XCTFail("Expected foreign shim rejection, got \(error)")
      }
    }
    XCTAssertEqual(try Data(contentsOf: fixture.installer.shimURL), Data("foreign-shim".utf8))
    XCTAssertEqual(
      try Data(contentsOf: fixture.installer.installedHelperURL), Data("current-helper".utf8))
    XCTAssertEqual(try Data(contentsOf: fixture.installer.hooksURL), hooks)
  }

  func testRemoveIntegrationRefusesForeignHelperWithoutChangingHooks() throws {
    let fixture = try makeInstaller(bundledContents: "current-helper")
    defer { try? FileManager.default.removeItem(at: fixture.home) }
    try FileManager.default.createDirectory(
      at: fixture.installer.installedHelperURL.deletingLastPathComponent(),
      withIntermediateDirectories: true)
    try Data("foreign-helper".utf8).write(to: fixture.installer.installedHelperURL)
    try FileManager.default.setAttributes(
      [.posixPermissions: 0o755], ofItemAtPath: fixture.installer.installedHelperURL.path)
    let hooks = try HookInstaller.merging(Data("{}".utf8), command: command)
    try FileManager.default.createDirectory(
      at: fixture.installer.hooksURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try hooks.write(to: fixture.installer.hooksURL)

    XCTAssertThrowsError(try fixture.installer.removeIntegration()) { error in
      guard case HookInstallerError.helperConflict = error else {
        return XCTFail("Expected foreign helper rejection, got \(error)")
      }
    }
    XCTAssertEqual(
      try Data(contentsOf: fixture.installer.installedHelperURL), Data("foreign-helper".utf8))
    XCTAssertEqual(try Data(contentsOf: fixture.installer.hooksURL), hooks)
  }

  private func makeInstaller(
    bundledContents: String,
    installedApplication: Bool = true,
    arguments: [String] = []
  ) throws -> (
    home: URL, installer: HookInstaller
  ) {
    let home = FileManager.default.temporaryDirectory
      .appendingPathComponent("CowlickInstaller-\(UUID().uuidString)", isDirectory: true)
    let applicationBundle = home.appendingPathComponent(
      installedApplication
        ? "Applications/Cowlick.app"
        : "DerivedData/Build/Products/Debug/Cowlick.app")
    let bundledHelper = applicationBundle.appendingPathComponent("Contents/Helpers/cowlick-hook")
    try FileManager.default.createDirectory(
      at: bundledHelper.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data(bundledContents.utf8).write(to: bundledHelper)
    try FileManager.default.setAttributes(
      [.posixPermissions: 0o755], ofItemAtPath: bundledHelper.path)
    return (
      home,
      HookInstaller(
        homeDirectory: home,
        applicationBundleURL: applicationBundle,
        bundledHelperURL: bundledHelper,
        arguments: arguments)
    )
  }

  private func installOwnedHelper(_ installer: HookInstaller, contents: String) throws {
    try FileManager.default.createDirectory(
      at: installer.installedHelperURL.deletingLastPathComponent(),
      withIntermediateDirectories: true)
    try Data(contents.utf8).write(to: installer.installedHelperURL)
    try FileManager.default.setAttributes(
      [.posixPermissions: 0o755], ofItemAtPath: installer.installedHelperURL.path)
    try FileManager.default.createDirectory(
      at: installer.shimURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try FileManager.default.createSymbolicLink(
      at: installer.shimURL, withDestinationURL: installer.installedHelperURL)
  }
}
