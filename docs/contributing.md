# Contributor guide

Install Xcode 16+ and XcodeGen, clone, then run `./Scripts/build_and_run.sh --verify`. `project.yml` is the Xcode project source of truth.

## Style

- Swift 6 strict concurrency and main-actor observable state.
- No disk, socket, or Git work on the main actor.
- Focused files and narrow AppKit bridges.
- Semantic labels, keyboard-safe approval controls, Reduce Motion support.
- No core third-party runtime dependency.
- Never weaken safe fallback to simplify a test.

```sh
xcrun swift-format lint --recursive --strict NotchRelay NotchRelayHook NotchRelayTests NotchRelayUITests
xcodebuild -project NotchRelay.xcodeproj -scheme NotchRelay-UnitTests -derivedDataPath DerivedData test
xcodebuild -project NotchRelay.xcodeproj -scheme NotchRelay-UITests -derivedDataPath DerivedData test
git diff --check
```

Protocol, approval, and bridge changes require negative-path tests. Visible states require accessibility labels and rendered inspection.
