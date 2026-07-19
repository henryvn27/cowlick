import XCTest

@testable import Cowlick

final class IntegrationSelfTestServiceTests: XCTestCase {
  func testPingAndDemoUseInstalledHelperProtocol() async throws {
    let fixture = try HelperFixture()
    defer { fixture.remove() }
    let service = IntegrationSelfTestService(helperURL: fixture.url)

    try await service.ping()
    try await service.sendDemo(.working, sessionID: "self-test-session")
    try await service.sendDemo(.completed, sessionID: "self-test-session")
  }

  func testMissingHelperFailsWithoutPretendingSuccess() async {
    let service = IntegrationSelfTestService(
      helperURL: FileManager.default.temporaryDirectory
        .appendingPathComponent("missing-cowlick-helper-\(UUID().uuidString)"))

    do {
      try await service.ping()
      XCTFail("Expected the unavailable helper to fail")
    } catch {
      XCTAssertEqual(error as? IntegrationSelfTestError, .helperUnavailable)
    }
  }

  func testMalformedHelperResponseFailsClosed() async throws {
    let fixture = try HelperFixture(response: "not-json")
    defer { fixture.remove() }
    let service = IntegrationSelfTestService(helperURL: fixture.url)

    do {
      try await service.ping()
      XCTFail("Expected malformed output to fail")
    } catch {
      XCTAssertEqual(error as? IntegrationSelfTestError, .malformedResponse)
    }
  }

  func testOversizedResponseFailsAtBoundWhileHelperIsRunning() async throws {
    let fixture = try HelperFixture(
      script: "#!/bin/sh\ndd if=/dev/zero bs=1048577 count=1 2>/dev/null\n")
    defer { fixture.remove() }
    let service = IntegrationSelfTestService(helperURL: fixture.url, timeout: 2)

    do {
      try await service.ping()
      XCTFail("Expected oversized output to fail")
    } catch {
      XCTAssertEqual(error as? IntegrationSelfTestError, .responseTooLarge)
    }
  }

  func testRetainedOutputPipeCannotOutliveTimeout() async throws {
    let fixture = try HelperFixture(
      script: "#!/bin/sh\n(sleep 1) &\nprintf '%s' '{\"ok\":true}'\n")
    defer { fixture.remove() }
    let service = IntegrationSelfTestService(helperURL: fixture.url, timeout: 0.1)

    do {
      try await service.ping()
      XCTFail("Expected inherited output pipe to time out")
    } catch {
      XCTAssertEqual(error as? IntegrationSelfTestError, .timedOut)
    }
  }

  private struct HelperFixture {
    let url: URL

    init(response: String? = nil, script customScript: String? = nil) throws {
      url = FileManager.default.temporaryDirectory
        .appendingPathComponent("cowlick-helper-fixture-\(UUID().uuidString)")
      let script: String
      if let customScript {
        script = customScript
      } else if let response {
        script = "#!/bin/sh\nprintf '%s' '\(response)'\n"
      } else {
        script = """
          #!/bin/sh
          if [ "$1" = "ping" ]; then
            printf '%s' '{"ok":true}'
          elif [ "$1" = "demo" ] && [ "$COWLICK_DEMO_SESSION_ID" = "self-test-session" ] && { [ "$2" = "working" ] || [ "$2" = "completed" ]; }; then
            printf '%s' '{"sent":true}'
          else
            exit 2
          fi
          """
      }
      try Data(script.utf8).write(to: url, options: .atomic)
      try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: url.path)
    }

    func remove() {
      try? FileManager.default.removeItem(at: url)
    }
  }
}
