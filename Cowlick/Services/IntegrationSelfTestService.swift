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
  case outputReadFailed
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
    case .outputReadFailed:
      "Cowlick could not read the helper's self-test response."
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

  func sendDemo(_ event: IntegrationDemoEvent, sessionID: String) async throws {
    let helperURL = helperURL
    let timeout = timeout
    try await Task.detached(priority: .utility) {
      let response = try Self.run(
        helperURL: helperURL,
        arguments: ["demo", event.rawValue],
        timeout: timeout,
        environment: ["COWLICK_DEMO_SESSION_ID": sessionID]
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

  private static func run(
    helperURL: URL,
    arguments: [String],
    timeout: TimeInterval,
    environment: [String: String] = [:]
  ) throws -> Data {
    guard FileManager.default.isExecutableFile(atPath: helperURL.path) else {
      throw IntegrationSelfTestError.helperUnavailable
    }

    let process = Process()
    let output = Pipe()
    process.executableURL = helperURL
    process.arguments = arguments
    if !environment.isEmpty {
      process.environment = ProcessInfo.processInfo.environment.merging(environment) { _, new in
        new
      }
    }
    process.standardOutput = output
    process.standardError = FileHandle.nullDevice
    defer {
      try? output.fileHandleForReading.close()
      try? output.fileHandleForWriting.close()
    }
    do {
      try process.run()
    } catch {
      throw IntegrationSelfTestError.launchFailed
    }
    try? output.fileHandleForWriting.close()

    let descriptor = output.fileHandleForReading.fileDescriptor
    let flags = Darwin.fcntl(descriptor, F_GETFL)
    guard flags >= 0, Darwin.fcntl(descriptor, F_SETFL, flags | O_NONBLOCK) >= 0 else {
      stop(process)
      throw IntegrationSelfTestError.outputReadFailed
    }

    var response = Data()
    var reachedEndOfFile = false
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
      do {
        reachedEndOfFile = try drainAvailableOutput(
          from: descriptor,
          into: &response
        )
      } catch {
        stop(process)
        throw error
      }
      if !process.isRunning, reachedEndOfFile { break }
      Thread.sleep(forTimeInterval: 0.01)
    }

    if !reachedEndOfFile {
      do {
        reachedEndOfFile = try drainAvailableOutput(from: descriptor, into: &response)
      } catch {
        stop(process)
        throw error
      }
    }
    guard !process.isRunning, reachedEndOfFile else {
      stop(process)
      throw IntegrationSelfTestError.timedOut
    }
    guard process.terminationStatus == 0 else {
      throw IntegrationSelfTestError.processFailed(process.terminationStatus)
    }
    return response
  }

  private static func drainAvailableOutput(
    from descriptor: Int32,
    into response: inout Data
  ) throws -> Bool {
    var buffer = [UInt8](repeating: 0, count: 16_384)
    while true {
      let byteCount = buffer.withUnsafeMutableBytes { bytes in
        Darwin.read(descriptor, bytes.baseAddress, bytes.count)
      }
      if byteCount > 0 {
        guard byteCount <= maximumResponseSize - response.count else {
          throw IntegrationSelfTestError.responseTooLarge
        }
        response.append(contentsOf: buffer.prefix(byteCount))
      } else if byteCount == 0 {
        return true
      } else if errno == EINTR {
        continue
      } else if errno == EAGAIN || errno == EWOULDBLOCK {
        return false
      } else {
        throw IntegrationSelfTestError.outputReadFailed
      }
    }
  }

  private static func stop(_ process: Process) {
    guard process.isRunning else { return }
    process.terminate()
    let deadline = Date().addingTimeInterval(0.05)
    while process.isRunning, Date() < deadline {
      Thread.sleep(forTimeInterval: 0.005)
    }
    if process.isRunning { Darwin.kill(process.processIdentifier, SIGKILL) }
    process.waitUntilExit()
  }
}
