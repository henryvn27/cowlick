# 011 — Anchor and content-size notch expansion

- **Status**: DONE
- **Commit**: 45e88a0
- **Severity**: HIGH
- **Category**: Physicality and origin; interruptibility; purpose and frequency
- **Estimated scope**: 6 files, medium

## Problem

The attached notch changes its observable SwiftUI presentation before the AppKit panel moves to
the new geometry. SwiftUI therefore begins its morph inside a host that is simultaneously being
recentered and resized, which makes the expanded surface appear to pop out from its own center
instead of unfolding from the compact notch that was already visible:

```swift
// Cowlick/Windowing/NotchPanelController.swift:166 — current
currentGeometry = geometry
presentation.update(from: geometry, surfaceSize: contentSize, mode: mode)
// ...
if panel.frame != geometry.panelFrame {
  panel.setFrame(geometry.panelFrame, display: false)
}
```

The open spring adds a small overshoot to this already unstable origin. That reads as a second pop
on an interaction users may trigger dozens of times each day:

```swift
// Cowlick/Support/NotchTheme.swift:30 — current
static let surfaceOpenDuration = 0.34
static let surfaceCloseDuration = 0.28
static let surfaceOpen = Animation.timingCurve(0.42, 0, 0.58, 1, duration: surfaceOpenDuration)
static let surfaceClose = Animation.timingCurve(0.42, 0, 0.58, 1, duration: surfaceCloseDuration)
```

Expanded activity is also hard-capped to two rows when there are more than three sessions, then
uses a separate overflow label. This wastes a row of useful space and gives the panel a formulaic
fixed height instead of a content-sized height capped at three rows:

```swift
// Cowlick/Views/SessionListView.swift:18 — current
ForEach(sessions.prefix(visibleSessionLimit)) { session in
  // row
}
if sessions.count > visibleSessionLimit {
  Text(Self.overflowText(hiddenCount: sessions.count - visibleSessionLimit))
}

// Cowlick/Views/SessionListView.swift:71 — current
private var visibleSessionLimit: Int {
  sessions.count > 3 ? 2 : min(3, sessions.count)
}
```

```swift
// Cowlick/Support/NotchTheme.swift:66 — current
static func sessionListSize(sessionCount: Int) -> CGSize {
  let visibleCount = sessionCount > 3 ? 2 : min(3, sessionCount)
  let overflowHeight: CGFloat = sessionCount > visibleCount ? 20 : 0
  let controlsHeight: CGFloat = 32
  return CGSize(
    width: 360,
    height: 20 + CGFloat(visibleCount) * 28 + overflowHeight + controlsHeight
  )
}
```

## Target

- With motion enabled, opening first prepares a transparent host at the expanded top-centered
  frame, then changes the SwiftUI presentation on the next main-actor turn. The compact surface is
  therefore still present at the top center of the prepared host when the 340 ms morph begins.
- Closing changes the SwiftUI presentation immediately, keeps the larger transparent host for the
  280 ms close, then shrinks the AppKit panel to the compact frame. The live interactive rectangle
  follows the target SwiftUI surface immediately, so transparent closing space never blocks other
  apps.
- A new transition cancels any pending delayed shrink. Rapid enter/exit/enter ends in the latest
  requested state without an old close task shrinking the open panel.
- Reduce Motion performs the target panel-frame and presentation updates synchronously and keeps
  the existing 120 ms opacity feedback; it introduces no spatial interpolation.
- Use a 340 ms open and 280 ms close with a symmetric ease-in-out curve. This preserves enough
  intermediate frames to read as a top-down unfold without bounce or the front-loaded snap of a
  duration spring.
- The session viewport is content-sized for zero through three rows and capped at three rows. Four
  or more sessions render all rows in a vertical `ScrollView` whose viewport is exactly three row
  slots tall. Its heavy system scroll indicator stays hidden; trackpad and mouse-wheel scrolling
  remain available inside the expanded list.
- The bottom action bar remains a non-scrolling sibling with Open Codex, Settings, Diagnostics,
  and Quit always visible. One or two sessions produce a correspondingly shorter expanded surface.

## Repo conventions to follow

- Motion tokens remain in `Cowlick/Support/NotchTheme.swift`; no inline durations are added.
- `NotchPanelController.schedulePresentationUpdate()` remains the single coalescing path from
  store changes to panel presentation.
- `NotchSurfaceLayout.interactiveRect` remains the only AppKit hit-test boundary. Do not restore a
  persistent maximum-size host or broaden compact hit testing.
- `ExpandedIslandView` keeps `NotchActionBar` outside the session viewport, preserving the existing
  four actions and their accessibility labels.
- Session typography, row content, physical-black surface, and semantic status colors remain
  unchanged.

## Steps

1. In `Cowlick/Support/NotchTheme.swift`, define shared session viewport constants for a 28-point
   row, three visible rows, existing 20-point list chrome, and 32-point action bar. Make
   `sessionListSize(sessionCount:)` use `min(3, max(0, sessionCount))`, remove overflow-label height,
   and replace the front-loaded springs with the shared ease-in-out surface curves.
2. In `Cowlick/Views/SessionListView.swift`, extract the existing row into a private view builder.
   Render all sessions in a vertical `ScrollView` only when count exceeds three, constrain that
   viewport to the shared three-row maximum, and render a plain intrinsic-height `VStack` for three
   or fewer. Remove the hidden-count overflow label and its now-dead formatter. Remove the redundant
   failed-state `Open Diagnostics` button because the fixed action bar already exposes Diagnostics;
   this keeps list height dependent only on rows.
3. In `Cowlick/Views/ExpandedIslandView.swift`, give the session viewport layout priority while
   keeping `NotchActionBar` fixed below it. Do not place the action bar inside the scroll view.
4. In `Cowlick/Windowing/NotchPanelController.swift`, keep the current target geometry separately
   from the currently hosted frame, add one cancellable delayed-shrink task, and sequence frame and
   presentation updates asymmetrically: host-first on open, presentation-first on close. Cancel the
   task on every new update and when presentation is disabled or ordered out.
5. Add focused unit coverage in `CowlickTests/NotchGeometryTests.swift` for one-, two-, three-, and
   four-session panel heights, the three-row cap, zero open bounce token intent where mechanically
   exposed, and stable top-edge geometry. Update the overflow text test that no longer represents
   the UI.
6. Update the focused macOS UI test to create at least four deterministic sessions, assert the
   first three rows fit with the action bar visible, scroll the list to the fourth row, and confirm
   exit collapse remains available.

## Boundaries

- Do NOT add a persistent maximum-size panel, an invisible future hit region, or another window.
- Do NOT animate the AppKit frame with `NSWindow.animator()`; SwiftUI owns visible spatial motion.
- Do NOT reintroduce scroll-wheel expansion/collapse. Scroll is local to the expanded session list.
- Do NOT change compact quota content, approval behavior, menu-bar mode, usage math, or hook data.
- Do NOT add new dependencies, blur, scale-from-zero, bounce, decorative motion, or fixed empty
  space for sessions that do not exist.
- If the source no longer matches commit `45e88a0` or compact hit testing is not bounded through
  `NotchSurfaceLayout.interactiveRect`, stop and report rather than improvising.

## Verification

- **Mechanical**:
  - `xcrun swift-format lint --recursive --strict Cowlick CowlickHook CowlickTests CowlickUITests`
  - `xcodebuild -project Cowlick.xcodeproj -scheme Cowlick-UnitTests -derivedDataPath DerivedData -destination 'platform=macOS' -jobs 8 CODE_SIGNING_ALLOWED=NO test`
  - Build and run the focused notch UI tests with `--simulate-notch`.
  - `git diff --check`
- **Feel check**: launch the Debug app with deterministic one-, two-, three-, and four-session
  states and record hover-open, exit-collapse, and rapid enter/exit/enter at normal speed and 25%
  playback. Confirm:
  - the black surface grows down and outward from the exact top-center compact notch, never from the
    center of the future panel;
  - closing retracts into the same compact surface without clipping or a final frame jump;
  - one and two sessions stop higher, three sessions are immediately visible, and the fourth is
    reachable by scrolling only the rows;
  - Open Codex, Settings, Diagnostics, and Quit remain visible and clickable while rows scroll;
  - transparent areas outside the live surface do not intercept clicks during or after collapse.
- Toggle system Reduce Motion and Cowlick's reduced-animation setting separately. Confirm both use
  an immediate geometry change with the existing short opacity feedback and no spatial growth.
- Install the exact final commit, verify the physical compact frame remains bounded, and repeat the
  real background-app click-through test.
- **Done when**: the notch visibly unfolds from and retracts into its existing top edge, rapid
  reversals settle in the latest state, up to three sessions determine the panel height, overflow
  sessions scroll independently, and the action bar and outside-app hit testing remain reliable.

## Result

Implemented July 22, 2026. Cowlick now prepares the expanded AppKit host before changing the
SwiftUI presentation, morphs a dedicated animatable shape whose top edge is fixed at the host's
zero origin, and delays host shrink until the 280 ms close completes. The front-loaded spring was
replaced with a 340 ms ease-in-out opening so the surface unfolds downward over multiple frames;
expanded content fades in after the shell begins moving and conceals promptly on close. Rapid
close-to-open reversal retargets cleanly in the operated recording.

The expanded list grows through three 32-point rows, then scrolls inside a three-row viewport with
no persistent scrollbar. Open Codex, Settings, Diagnostics, and Quit remain in a fixed 32-point
action rail. Geometry coverage, the complete 430-test unit suite, website browser smoke, format
lint, and diff validation passed. A real right-wing click opened completed-session details. The
Xcode 27 beta UI-automation daemon later stopped before test execution while enabling automation;
the prior full UI run reached 21 of 22 tests, and the remaining completion interaction was exercised
manually after correcting the test to target the visible wing rather than the physical camera gap.
