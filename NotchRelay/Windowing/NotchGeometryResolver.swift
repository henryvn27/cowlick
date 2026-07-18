import AppKit
import CoreGraphics

struct ResolvedNotchGeometry: Equatable, Sendable {
  let panelFrame: CGRect
  let hasNotch: Bool
  let displayID: CGDirectDisplayID
}

enum NotchGeometryResolver {
  static func resolve(
    screenFrame: CGRect,
    visibleFrame: CGRect,
    safeAreaTop: CGFloat,
    auxiliaryTopLeftArea: CGRect?,
    auxiliaryTopRightArea: CGRect?,
    requestedContentSize: CGSize,
    displayID: CGDirectDisplayID,
    showOnNonNotch: Bool
  ) -> ResolvedNotchGeometry? {
    let notchGap = notchGapWidth(left: auxiliaryTopLeftArea, right: auxiliaryTopRightArea)
    let hasNotch = safeAreaTop > 0 && notchGap != nil
    guard hasNotch || showOnNonNotch else { return nil }

    let width =
      hasNotch ? max(requestedContentSize.width, notchGap ?? 0) : requestedContentSize.width
    let height = max(requestedContentSize.height, hasNotch ? safeAreaTop : 0)
    let x = screenFrame.midX - width / 2
    let y =
      hasNotch
      ? screenFrame.maxY - height
      : visibleFrame.maxY - height - 6
    return ResolvedNotchGeometry(
      panelFrame: CGRect(
        x: x.rounded(.toNearestOrAwayFromZero), y: y.rounded(.toNearestOrAwayFromZero),
        width: width, height: height),
      hasNotch: hasNotch,
      displayID: displayID
    )
  }

  static func resolve(screen: NSScreen, contentSize: CGSize, showOnNonNotch: Bool)
    -> ResolvedNotchGeometry?
  {
    resolve(
      screenFrame: screen.frame,
      visibleFrame: screen.visibleFrame,
      safeAreaTop: screen.safeAreaInsets.top,
      auxiliaryTopLeftArea: screen.auxiliaryTopLeftArea,
      auxiliaryTopRightArea: screen.auxiliaryTopRightArea,
      requestedContentSize: contentSize,
      displayID: screen.displayID,
      showOnNonNotch: showOnNonNotch
    )
  }

  static func preferredScreen(
    _ preference: PreferredDisplay, screens: [NSScreen] = NSScreen.screens
  ) -> NSScreen? {
    guard !screens.isEmpty else { return nil }
    switch preference {
    case .builtIn:
      return screens.first(where: { CGDisplayIsBuiltin($0.displayID) != 0 }) ?? NSScreen.main
        ?? screens.first
    case .main:
      return NSScreen.main ?? screens.first
    case .automatic:
      return screens.first(where: {
        CGDisplayIsBuiltin($0.displayID) != 0
          && $0.safeAreaInsets.top > 0
          && notchGapWidth(left: $0.auxiliaryTopLeftArea, right: $0.auxiliaryTopRightArea) != nil
      }) ?? NSScreen.main ?? screens.first
    }
  }

  private static func notchGapWidth(left: CGRect?, right: CGRect?) -> CGFloat? {
    guard let left, let right, !left.isEmpty, !right.isEmpty else { return nil }
    let gap = right.minX - left.maxX
    return gap >= 20 ? gap : nil
  }
}

extension NSScreen {
  var displayID: CGDirectDisplayID {
    (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
  }
}
