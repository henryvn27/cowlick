# Security and threat model

The sensitive asset is authority to approve a Codex operation. Codex and the helper cross into NotchRelay over local IPC. Tool names, prompts, descriptions, and tool input are untrusted display data. Releases cross the update boundary.

| Threat | Control |
|---|---|
| Local process spoofs approval | Random owner-only token, current-UID peer check, private socket mode, UUID, expiration |
| One request gets another answer | Exact UUID match in app and helper; queue-head-only, single-use decisions |
| Failure approves | Every malformed, unavailable, stale, timeout, auth, and socket path emits no decision |
| Tool input executes | Decode, truncate/render, optionally copy; never execute |
| Hook output injects behavior | No stdout for status, `{}` for Stop, fixed official permission dictionaries |
| Installer destroys config | Locked merge/validate, optimistic re-read, unknown-field preservation, private backup, atomic replace, exact marker/command ownership |
| Update is replaced | HTTPS, Sparkle EdDSA, Developer ID, Hardened Runtime, notarization, stapling |
| Diagnostics disclose data | Bounded sanitized metadata; secret and home-component redaction; no full values logged |

NotchRelay defends against accidental messages and other users. A process already running as the same user can generally read that user's files or drive granted UI; the app does not claim to withstand a fully compromised account.

Core features need no Accessibility permission. Caps Lock may require Input Monitoring or Accessibility and stays off until explicitly enabled and tested. See [SECURITY.md](../SECURITY.md).

## v1.0 security review

The launch review traced the shipped IPC, approval, hook-output, installer, diagnostics, update, and script boundaries. The review found and fixed five issues before release packaging:

- Socket acceptance and client processing were separated so a synchronous approval cannot block the listener.
- Approval request UUIDs are single-use for fifteen minutes, preventing a repeated identifier from aliasing a pending continuation.
- Both sides enforce the 1 MiB bound while reading, including newline-terminated overflow cases; hook stdin is read incrementally.
- Hook removal requires NotchRelay's explicit marker or the exact configured command. Installation uses a private lock, private backups, validation, optimistic conflict detection, and an atomic rename.
- Diagnostics remove home-directory components, credentials, authorization headers, control characters, and complete untrusted values before retention or logging.

Focused regression tests cover each control. A same-user process with access to the token file remains inside the documented local-account trust boundary; NotchRelay does not claim isolation from a compromised user account.
