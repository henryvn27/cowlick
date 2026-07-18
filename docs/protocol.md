# Bridge protocol

Protocol version 1 uses one newline-delimited JSON object per private Unix-domain socket connection, limited to 1 MiB.

```json
{
  "version": 1,
  "requestId": "UUID",
  "event": "sessionStart | working | approvalRequested | completed | failed | ping",
  "timestamp": "ISO-8601",
  "sessionId": "string",
  "turnId": "string-or-null",
  "cwd": "string",
  "toolName": "string-or-null",
  "toolInput": {},
  "authToken": "random-token"
}
```

Approval responses contain version 1, the same UUID, and `allow`, `deny`, or `defer`. The app rejects unsupported versions, invalid tokens, different peer users, malformed JSON, over-limit messages, and stale timestamps. The helper rejects malformed, version-mismatched, and request-mismatched responses.

`defer`, no response, timeout, and bridge errors produce no Codex permission decision. Stop prints neutral `{}` and never requests another turn.
