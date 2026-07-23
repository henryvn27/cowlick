# Control Studios website asset handoff

These assets were captured on July 22, 2026 from the installed Cowlick 1.0.0
binary whose embedded source identity is
`287afff0391b2c4a7fa172acc5558ab68b2766e2` (`main`). The 2x PNG captures ran
on a MacBook display with a measured 32-point top safe-area inset. They are
physical-notch-display evidence, not fallback-island mockups.

## Recommended website screenshots

- `Screenshots/approval.png` (760 x 356): the current request-matched Bash
  approval surface with Deny, Open Codex, Copy, and Allow once. The operation
  and 22% quota wing are deterministic fixture data.
- `Screenshots/multi-session.png` (538 x 338): the current expanded notch with
  two independent fixture sessions, ActivityPilot and Scoutly, plus the
  deterministic 22% quota wing. Capture-only switches hide unrelated usage and
  integration sections so the image is focused on session arbitration.
- `Screenshots/usage.png` (800 x 1040): the deterministic current usage fixture
  with 5-hour and weekly quota, time-to-empty warnings, the partial API-price
  equivalent, and the explicitly unofficial third-party reset forecast.

The following are useful supplementary surfaces, but are not the first choices
for a public product page:

- `Screenshots/failed-expanded.png`: the current failed/integration-repair
  state.
- `Screenshots/onboarding.png`, `Screenshots/settings.png`, and
  `Screenshots/diagnostics.png`: current system-window surfaces.

Live-runtime screenshots are intentionally excluded from this public-repo
artifact because they contain local session and usage details.

The compact `working.png`, `completed.png`, and `failed.png` captures are
intentionally very quiet on physical-notch hardware and should not be used as
standalone website proof.

## Canonical icon and logo

- Editable master: `../AppIcon/cowlick-icon.svg`
- 1024 px raster master: `../AppIcon/cowlick-icon-1024.png`
- Shipping app-catalog raster:
  `../../Cowlick/Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png`
- Press-kit copies: `../PressKit/cowlick-icon.svg` and
  `../PressKit/cowlick-icon-1024.png`

The editable, press-kit, and shipping copies are byte- or pixel-identical for
their respective formats. The mark is the whole upper-edge silhouette: a
graphite notch/cowlick over a warm paper tile. Do not redraw it.

SVG stops:

- Paper: `#F0EFEA` to `#D8D4CB`
- Graphite: `#1C1B19` to `#090909`

## Authoritative native product tokens

Source: `../../Cowlick/Support/NotchTheme.swift`

The source describes the product as quiet, physical, and attached to the Mac.
Use SF Pro for interface text, SF Mono only for operations and diagnostics, a
4-point density grid, continuous pill geometry, no ornamental cards, and
restrained top-down motion that respects Reduce Motion.

Exact Swift values and their practical 8-bit web translations:

- Island: `Color.black` / `#000000`
- Raised island: `Color(white: 0.075)` / approximately `#131313`
- Neutral control accent: `(0.79, 0.78, 0.74)` / `#C9C7BD`
- Success: `(0.53, 0.76, 0.62)` / `#87C29E`
- Warning: `(0.88, 0.68, 0.38)` / `#E0AD61`
- Failure: `(0.84, 0.47, 0.43)` / `#D6786E`
- Hairline: white at 12% opacity
- Floating windows: dynamic macOS `windowBackgroundColor`; do not replace this
  with a fixed light or dark color

Key geometry:

- Compact surface: `170 x 34`
- Approval maximum: `380 x 170`
- Attached wing: `42`
- Expanded information width: `332`
- Expanded surface maximum height: `400`
- Radii: `14` compact, `22` expanded bottom, `12` floating

## Authoritative Cowlick website tokens

Source: `../../Website/styles.css`

- Paper: `#E9E6DE`
- Raised paper: `#F1EEE7`
- Deep paper: `#D9D5CC`
- Ink: `#11110F`
- Raised ink: `#1B1B18`
- Island: `#000000`
- Muted: `#68665F`
- Muted on dark: `#9B9992`
- Focus: `#A65C16`
- Selection: `#C8B495`
- Display stack: `ui-rounded`, SF Pro Rounded, SF Pro Display, Apple system
- Body stack: SF Pro Text, Apple system, Helvetica Neue
- Monospace stack: SF Mono, Menlo, Consolas
- Spacing scale: `0.25rem`, `0.5rem`, `0.75rem`, `1rem`, `1.5rem`,
  `2rem`, `3rem`, `4rem`, `6rem`, `8rem`
- Motion: `cubic-bezier(0.16, 0.84, 0.24, 1)` for ease-out and
  `cubic-bezier(0.22, 1, 0.36, 1)` for spring-like transitions

The warm paper/ink system is the current Cowlick website frame. The app itself
remains a black, hardware-attached notch surface with dynamic native windows.
