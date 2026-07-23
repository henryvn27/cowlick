# 008 — Tighten the notch morph

- **Status**: DONE
- **Commit**: pending closeout commit
- **Severity**: HIGH
- **Category**: Purpose and frequency; easing and duration; interruptibility
- **Estimated scope**: 3 files, small

## Problem

Cowlick's fixed-shell architecture is correct, but the frequent hover path waits 200 ms before
opening and 400 ms before closing, then starts a 420–450 ms spring:

```swift
// Cowlick/Support/NotchTheme.swift:28 — current
static let hoverOpenDelay = 0.20
static let hoverCloseDelay = 0.40
static let surfaceOpen = Animation.spring(
  response: 0.42, dampingFraction: 0.8, blendDuration: 0)
static let surfaceClose = Animation.spring(
  response: 0.45, dampingFraction: 1.0, blendDuration: 0)
```

The shell also grows while the body independently scales from 0.96. That compounds the same
spatial change and makes the content look rubbery inside the already-morphing shell:

```swift
// Cowlick/Views/NotchRootView.swift:111 — current
private var expandedTransition: AnyTransition {
  motionReduced
    ? .opacity
    : .asymmetric(
      insertion: .opacity.combined(with: .scale(scale: 0.96, anchor: .top)),
      removal: .opacity.combined(with: .scale(scale: 0.98, anchor: .top))
    )
}
```

## Target

- Preserve plan 007's fixed AppKit host and top-centered SwiftUI surface ownership.
- Shorten hover intent to 80 ms on entry and 160 ms on exit.
- Keep the existing interruptible surface springs; they already retarget from the current state.
- Let the shell provide all spatial motion. Expanded content uses opacity only, clipped by the
  growing shell, so it cannot visibly outrun the surface.
- Use a 160 ms strong ease-out content fade:

```swift
static let contentReveal = Animation.timingCurve(
  0.23, 1.00, 0.32, 1.00, duration: 0.16)
```

- Reduce Motion remains a 120 ms opacity transition with no spatial movement.

## Repo conventions to follow

- Motion values remain centralized in `Cowlick/Support/NotchTheme.swift`.
- `NotchRootView` combines system Reduce Motion with Cowlick's own reduced-animation setting.
- AppKit retains a stable maximum host; do not animate `NSPanel.frame`.
- `hoverIntent` remains the single cancellable task deciding hover expansion and collapse.

## Steps

1. In `NotchTheme.swift`, change `hoverOpenDelay` to `0.08`, `hoverCloseDelay` to `0.16`, and
   add the exact `contentReveal` animation above.
2. In `NotchRootView.swift`, change `expandedTransition` to `.opacity` for both insertion and
   removal and apply `contentReveal` only to expanded-content presence, not the whole surface.
3. Keep `.animation(surfaceAnimation, value: presentation.state)` as the sole surface morph.
   Do not add delayed tasks or a second geometry animation.
4. Add a focused UI interaction test or deterministic presentation test proving rapid
   hover-enter → leave → enter resolves to expanded with no stale close.

## Boundaries

- Do NOT change panel geometry, hit testing, approval focus, or presentation routing.
- Do NOT animate the AppKit window frame.
- Do NOT add dependencies, blur, bounce, glow, or scale effects to expanded content.
- Do NOT change the existing drag-release spring.
- If the fixed-shell architecture no longer matches plan 007, stop and report instead of
  inventing another animation owner.

## Verification

- **Mechanical**: run Swift format/lint if configured, targeted notch tests, the full macOS unit
  suite, `xcodebuild build-for-testing`, and `git diff --check`.
- **Feel check**: launch `--ui-testing --simulate-notch --state=working --demo-sequence`, record
  compact → expanded → collapsed plus rapid hover reversal, and inspect at 25% playback.
  Confirm the top edge stays fixed, content never scales inside the shell, and no stale delayed
  task wins after the pointer reverses.
- Toggle Reduce Motion and confirm the shell snaps while content keeps only a short fade.
- **Done when**: hover response begins promptly, collapse does not feel sticky, and the shell and
  body no longer visibly double-ease.

## Result

Implemented on July 22, 2026. Hover intent is now 80/160 ms, expanded content uses a 160 ms
opacity-only reveal, and the fixed AppKit shell remains the sole spatial animation owner. The
12-second compact → expanded → collapsed recording was inspected at extracted compact, expanded,
and collapsed frames; the top anchor remains fixed and no inner scale animation is present. The
full macOS unit suite passed 436/436 and the Debug app build succeeded.
