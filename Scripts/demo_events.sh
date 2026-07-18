#!/bin/zsh
set -euo pipefail

helper="${NOTCHRELAY_HOOK:-$HOME/.local/bin/notchrelay-hook}"
[[ -x "$helper" ]] || { print -u2 "NotchRelay helper is not installed: $helper"; exit 1; }

print "1/5 Working"
NOTCHRELAY_DEMO_SESSION_ID=demo-primary "$helper" demo working
sleep 2
print "2/5 Second simultaneous session"
NOTCHRELAY_DEMO_SESSION_ID=demo-secondary "$helper" demo working
sleep 2
print "3/5 Approval — choose Allow once or Deny in the island"
if ! NOTCHRELAY_DEMO_SESSION_ID=demo-primary "$helper" demo approval; then
  print "Approval returned to the safe fallback without a decision."
fi
sleep 1
print "4/5 Completion"
NOTCHRELAY_DEMO_SESSION_ID=demo-primary "$helper" demo completed
NOTCHRELAY_DEMO_SESSION_ID=demo-secondary "$helper" demo completed
sleep 5
print "5/5 Idle — both completed sessions have collapsed"
