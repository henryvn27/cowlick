# 009 — Show Codex usage in the compact notch

- **Status**: DONE
- **Commit**: pending closeout commit
- **Severity**: MEDIUM
- **Category**: Missed opportunity
- **Estimated scope**: 7 files, small

## Problem

Usage is already enabled by default and refreshed at launch, but only the menu-bar label receives
`UsageStore` and formats its percentage:

```swift
// Cowlick/Stores/SettingsStore.swift:173 — current
Key.showCodexUsage: true,
```

```swift
// Cowlick/Views/MenuBarContentView.swift:129 — current
private var percentageText: String? {
  guard settings.showCodexUsage, let percent = usageStore.primaryDisplayedPercent else {
    return nil
  }
  return "\(Int(percent.rounded()))%"
}
```

The notch controller constructs `NotchRootView` with only `SessionStore`, so the compact notch has
no way to render the already-loaded quota:

```swift
// Cowlick/Windowing/NotchPanelController.swift:97 — current
let hostingView = NotchHostingView(
  rootView: NotchRootView(store: store, presentation: presentation))
```

## Target

- Inject the existing `UsageStore` into the notch presentation path; do not create a second usage
  service or fetch.
- When `settings.showCodexUsage` is true and `primaryDisplayedPercent` exists, show the rounded
  percentage as a compact monospaced value beside the status symbol.
- When no session is active but a real percentage is available, keep the attached compact surface
  visible with a restrained usage-only header. Do not require fake session data.
- Use the existing metric preference, so the value remains "remaining" by default and follows the
  user's used/remaining choice.
- Hide the percentage cleanly while loading or unavailable; do not show placeholders in the
  34-point compact surface.
- Include the existing `primaryMetricAccessibilityLabel` in the compact button's accessibility
  label.
- Existing explicit `showCodexUsage = false` remains respected. Do not migrate or overwrite stored
  user choices.

## Repo conventions to follow

- `WindowCoordinator` injects dependencies into `NotchPanelController`.
- `MenuBarLabelView` is the formatting and accessibility exemplar.
- Notch compact typography uses SF Pro with monospaced digits and restrained secondary opacity.
- `SettingsStoreTests` already proves the fresh default is true and reset restores true.

## Steps

1. Pass `services.usageStore` from `WindowCoordinator` into `NotchPanelController`, then into
   `NotchRootView`, `CollapsedIslandView`, and `IslandHeaderView` as the minimal dependency chain.
2. Make `NotchPanelController` consider a real available usage percentage a valid compact
   presentation reason even when `SessionStore.shouldShowOverlay` is false. Observe usage changes
   through the existing observable view dependency or one bounded callback; do not poll.
3. Compute one optional percentage string from `showCodexUsage` and
   `usageStore.primaryDisplayedPercent`, formatted as `Int(percent.rounded())` plus `%`.
4. Render that value in `IslandHeaderView.statusGroup` with `.monospacedDigit()`, 10-point semibold
   type, and the existing secondary text color. Keep the status symbol first.
5. Add a compact usage-only header for the no-session case using the same wing geometry and
   typography. Keep it nonactivating and nonexpandable.
6. Add the usage accessibility label to `CollapsedIslandView.accessibilityLabel` when available.
7. Add focused tests for visible percentage formatting, disabled/unavailable omission, idle
   usage-only presentation, and
   accessibility copy. Reuse existing usage fixtures rather than adding a network path.

## Boundaries

- Do NOT add a second fetch, timer, store, setting, progress ring, graph, or expanded quota card.
- Do NOT change the default value; it is already correct.
- Do NOT show API-cost estimates or third-party reset forecasts in the compact notch.
- Do NOT widen the physical camera gap, fabricate a notch on non-notch displays, or move the top
  anchor.
- Do NOT overwrite an existing user's explicit off preference.

## Verification

- **Mechanical**: run the focused settings/usage/header tests, full macOS unit suite,
  `xcodebuild build-for-testing`, and `git diff --check`.
- **Feel check**: launch with `--ui-testing --usage-demo --simulate-notch --state=working`, capture
  the compact notch, and confirm the percentage is readable without crowding the project label or
  status. Launch the usage-only idle state and confirm the percentage remains visible without a
  fake task label. Repeat with usage disabled and confirm no idle Cowlick surface remains.
- Verify VoiceOver/accessibility inspection reports the usage metric and its used/remaining
  meaning.
- **Done when**: fresh/default Cowlick shows a real available Codex percentage in the compact notch
  during activity and while idle, while explicit-off and unavailable states remain clean.

## Result

Implemented on July 22, 2026. The notch now consumes the existing `UsageStore`, shows the rounded
primary usage percentage during activity and in an idle usage-only header, and observes usage
availability without polling. Explicit-off and unavailable states remain hidden. The deterministic
usage fixture now refreshes like production so the idle state can be rendered; visual inspection
confirmed a readable 22% value with no fake hover or button affordance. Focused notch tests passed
19/19 and the full macOS unit suite passed 436/436.
