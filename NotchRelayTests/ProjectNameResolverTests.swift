import XCTest

@testable import NotchRelay

final class ProjectNameResolverTests: XCTestCase {
  func testUsesNearestGitRootName() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(
      "ProjectNameResolver-\(UUID().uuidString)")
    let nested = root.appendingPathComponent("Sources/Feature")
    try FileManager.default.createDirectory(
      at: root.appendingPathComponent(".git"), withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    XCTAssertEqual(
      ProjectNameResolver.resolve(workingDirectory: nested.path), root.lastPathComponent)
  }

  func testFallsBackToWorkingDirectoryName() {
    XCTAssertEqual(
      ProjectNameResolver.resolve(workingDirectory: "/tmp/ActivityPilot"), "ActivityPilot")
  }

  func testFallsBackToCodexForRoot() {
    XCTAssertEqual(ProjectNameResolver.resolve(workingDirectory: "/"), "Codex")
  }
}
