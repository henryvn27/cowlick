import AppKit
import SwiftUI

enum NotchSurfaceLayout {
  static func interactiveRect(
    hostSize: CGSize,
    surfaceSize: CGSize,
    isFlipped: Bool = true
  ) -> CGRect {
    let boundedHeight = min(hostSize.height, surfaceSize.height)
    return CGRect(
      x: max(0, (hostSize.width - surfaceSize.width) / 2),
      y: isFlipped ? 0 : max(0, hostSize.height - surfaceSize.height),
      width: min(hostSize.width, surfaceSize.width),
      height: boundedHeight
    )
  }
}

@MainActor
final class NotchHostingView<Content: View>: NSHostingView<Content> {
  /// Adapted from Ping Island's Apache-2.0 bounded hosting view at
  /// commit c9148fc6a66a98f62dc1cac8fde415c2be9f2233.
  var interactiveRect: () -> CGRect = { .zero }
  var handlePointerDown: () -> Void = {}

  override var isOpaque: Bool { false }

  override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
    true
  }

  override func hitTest(_ point: NSPoint) -> NSView? {
    guard interactiveRect().contains(point) else { return nil }
    return super.hitTest(point)
  }

  override func mouseDown(with event: NSEvent) {
    handlePointerDown()
    super.mouseDown(with: event)
  }

}
