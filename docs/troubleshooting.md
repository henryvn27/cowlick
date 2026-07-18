# Troubleshooting

## The island does not appear

Use the menu-bar icon and choose Test State → Working. Enable “Show on displays without a notch” when using a desktop or external display. Diagnostics should report the socket as listening.

## Codex events do not arrive

In Settings → Integration, choose Install or Repair. Then open `/hooks` in Codex and review or trust the NotchRelay command if prompted. Codex may need a restart after a new command hook is installed.

## Approval also appears in Codex

This is the safe fallback when NotchRelay is unavailable, expired, malformed, mismatched, or disconnected. It never turns that condition into Allow.

## Caps Lock is unavailable

The island works independently. If Settings reports a permission error, grant Input Monitoring or Accessibility to NotchRelay, reopen it, and run the safe test. Support varies by keyboard and macOS policy.

## Sharing diagnostics

Export from Diagnostics and review before sharing. Reports omit full prompts, commands, tokens, and home-directory usernames.
