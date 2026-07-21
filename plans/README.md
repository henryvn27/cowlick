# Cowlick presentation and motion plans

Audit baseline: `a937b39`.

| Plan | Title | Severity | Status |
| --- | --- | --- | --- |
| 001 | Route to exactly one presentation surface | HIGH | TODO |
| 002 | Prove a safe DynamicNotchKit adapter | HIGH | TODO |
| 003 | Make the notch morph as one surface | HIGH | TODO |
| 004 | Make direct manipulation feel physical | MEDIUM | TODO |

## Recommended execution order

1. **001** first. It defines whether the active surface is the notch or the menu bar and removes the current duplicate default.
2. **002** next as a bounded spike. Do not proceed to the migration unless approval focus, display selection, and Reduce Motion remain equivalent to Cowlick's current contract.
3. **003** after the shell decision. It installs Cowlick's restrained motion tokens and removes the competing AppKit/SwiftUI timelines.
4. **004** last. Gesture and press feedback should target the final shell rather than be rewritten twice.

Plans 002 and 003 are coupled: DynamicNotchKit is the recommended engine, but its stock 400 ms bouncy/blur/scale-zero effects are explicitly out of scope. Cowlick should use the MIT package's geometry and state structure behind a local adapter, then override or patch its motion and key-window behavior.
