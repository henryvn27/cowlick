import Darwin
import Foundation

enum IntegrationDemoEvent: String, Sendable {
  case working
  case completed
}

enum IntegrationSelfTestError: LocalizedError, Equatable {
  case helperUnavailable
  case launchFailed
  case timedOut
  case processFailed(Int32)
  case responseTooLarge
  case malformedResponse

  var errorDescription: String? {
    switch self {
    case .helperUnavailable:
      "The installed Cowlick helper is unavailable. Repair Codex integration first."
    case .launchFailed:
      "Cowlick could not launch its installed helper."
    case .timedOut:
      "The helper could not reach Cowlick before the self-test timed out."
    case .processFailed:
      "The helper could not reach Cowlick. Repair the integration and try again."
    case .responseTooLarge:
      "The helper returned more self-test data than Cowlick accepts."
    case .malformedResponse:
      "The helper returned an unreadable self-test response."
    }
  }
}

struct IntegrationSelfTestService: Sendable {
  static let maximumResponseSize = 1_048_576

  let helperURL: URL
  let timeout: TimeInterval

  init(helperURL: URL, timeout: TimeInterval = 5) {
    self.helperURL = helperURL
    self.timeout = timeout
  }

  func ping() async throws {
    let helperURL = helperURL
    let timeout = timeout
    try await Task.detached(priority: .utility) {
      let response = try Self.run(helperURL: helperURL, arguments: ["ping"], timeout: timeout)
      let object = try Self.decodeObject(response)
      guard object["ok"] as? Bool == true else {
        throw IntegrationSelfTestError.malformedResponse
      }
    }.value
  }

  func sendDemo(_ event: IntegrationDemoEvent) async throws {
    let helperURL = helperURL
    let timeout = timeout
    try await Task.detached(priority: .utility) {
      let response = try Self.run(
        helperURL: helperURL,
        arguments: ["demo", event.rawValue],
        timeout: timeout
      )
      let object = try Self.decodeObject(response)
      guard object["sent"] as? Bool == true else {
        throw IntegrationSelfTestError.malformedResponse
      }
    }.value
  }

  static func decodeObject(_ data: Data) throws -> [String: Any] {
    guard data.count <= maximumResponseSize,
      let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else {
      throw data.count > maximumResponseSize
        ? IntegrationSelfTestError.responseTooLarge
        : IntegrationSelfTestError.malformedResponse
    }
    return object
  }

  private static func run(helperURL: URL, arguments: [String], timeout: TimeInterval) throws -> Data
  {
    guard FileManager.default.isExecutableFile(atPath: helperURL.path) else {
      throw IntegrationSelfTestError.helperUnavailable
    }

    let process = Process()
    let output = Pipe()
    process.executableURL = helperURL
    process.arguments = arguments
    process.standardOutput = output
    process.standardError = FileHandle.nullDevice
    do {
      try process.run()
    } catch {
      throw IntegrationSelfTestError.launchFailed
    }

    let deadline = Date().addingTimeInterval(timeout)
    while process.isRunning, Date() < deadline {
      Thread.sleep(forTimeInterval: 0.01)
    }
    guard !process.isRunning else {
      process.terminate()
      Thread.sleep(forTimeInterval: 0.05)
      if process.isRunning { Darwin.kill(process.processIdentifier, SIGKILL) }
      process.waitUntilExit()
      throw IntegrationSelfTestError.timedOut
    }
    guard process.terminationStatus == 0 else {
      throw IntegrationSelfTestError.processFailed(process.terminationStatus)
    }

    let response = output.fileHandleForReading.readDataToEndOfFile()
    guard response.count <= maximumResponseSize else {
      throw IntegrationSelfTestError.responseTooLarge
    }
    return response
  }
}
