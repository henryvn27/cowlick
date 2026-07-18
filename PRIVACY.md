# Privacy

NotchRelay is local-first, has no analytics, and holds session data in memory. Prompt and result previews are disabled by default. Full approval operations are held only long enough to show or copy a pending request.

## Stored data

`~/Library/Application Support/NotchRelay/` contains the owner-only bridge token, runtime metadata, installed helper, and sanitized local logs when present. `~/.codex/hooks.json` contains four merged command handlers, with a timestamped backup before changes. `~/.local/bin/notchrelay-hook` is a symlink to the installed helper. Preferences use `com.henryvn27.NotchRelay`. There is no session-history database.

The app makes no network request except Sparkle update checks to the GitHub release feed and links the user explicitly opens. There is no cloud account, advertising, or crash-reporting SDK.

Core behavior needs no special privacy permission. Optional Caps Lock signaling may require Input Monitoring or Accessibility depending on macOS and hardware; the app asks only when that independent feature is enabled.

Reset Local State clears in-memory state and preferences. Hook removal affects only NotchRelay handlers. Homebrew users can completely remove stored data with `brew uninstall --cask --zap notchrelay`.
