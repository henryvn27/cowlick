import Foundation
import XCTest

@testable import NotchRelay

private final class FakeCapsLockController: CapsLockControlling, @unchecked Sendable {
  private let lock = NSLock()
  private var value: Bool
  private(set) var writes: [Bool] = []

  init(initialState: Bool) { value = initialState }

  func readState() -> Bool { lock.withLock { value } }

  func setState(_ state: Bool) {
    lock.withLock {
      value = state
      writes.append(state)
    }
  }

  var state: Bool { lock.withLock { value } }
  var recordedWrites: [Bool] { lock.withLock { writes } }
}

final class CapsLockSignalTests: XCTestCase {
  func testCompletionRestoresOriginalOffState() async {
    let controller = FakeCapsLockController(initialState: false)
    let service = NativeCapsLockSignalService(controller: controller)
    await service.start(.completion)
    try? await Task.sleep(for: .milliseconds(300))

    XCTAssertFalse(controller.state)
    XCTAssertEqual(controller.recordedWrites.prefix(2), [true, false])
  }

  func testCancellationRestoresOriginalOnState() async {
    let controller = FakeCapsLockController(initialState: true)
    let service = NativeCapsLockSignalService(controller: controller)
    await service.start(.approval)
    try? await Task.sleep(for: .milliseconds(40))
    await service.cancelAndRestore()

    XCTAssertTrue(controller.state)
    XCTAssertEqual(controller.recordedWrites.last, true)
  }

  func testFailureUsesTwoPulsesAndRestores() async {
    let controller = FakeCapsLockController(initialState: false)
    let service = NativeCapsLockSignalService(controller: controller)
    await service.start(.failure)
    try? await Task.sleep(for: .milliseconds(500))

    XCTAssertFalse(controller.state)
    XCTAssertGreaterThanOrEqual(controller.recordedWrites.filter { $0 }.count, 2)
  }
}
