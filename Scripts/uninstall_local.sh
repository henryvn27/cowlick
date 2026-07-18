#!/bin/zsh
set -euo pipefail

script_dir="${0:A:h}"
purge=false
[[ "${1:-}" == "--purge" ]] && purge=true
[[ $# -le 1 ]] || { print -u2 "usage: $0 [--purge]"; exit 2; }

existing_pids=(${(f)"$(pgrep -x NotchRelay 2>/dev/null || true)"})
stopped_pids=()
for process_id in $existing_pids; do
  process_path="$(ps -p "$process_id" -o command= 2>/dev/null || true)"
  if [[ "$process_path" == *"/NotchRelay.app/Contents/MacOS/NotchRelay"* ]]; then
    kill "$process_id"
    stopped_pids+=("$process_id")
  fi
done
for process_id in $stopped_pids; do
  for _ in {1..50}; do
    kill -0 "$process_id" 2>/dev/null || break
    sleep 0.1
  done
  kill -0 "$process_id" 2>/dev/null && {
    print -u2 "NotchRelay process $process_id did not stop cleanly."
    exit 1
  }
done

swift "$script_dir/install_hooks.swift" remove

app_path="$HOME/Applications/NotchRelay.app"
helper_path="$HOME/Library/Application Support/NotchRelay/bin/notchrelay-hook"
shim_path="$HOME/.local/bin/notchrelay-hook"
runtime_socket="${TMPDIR%/}/NotchRelay-$(id -u)/bridge.sock"

[[ -L "$shim_path" && "$(readlink "$shim_path")" == "$helper_path" ]] && rm "$shim_path"
[[ -f "$helper_path" ]] && rm "$helper_path"
[[ -d "$app_path" ]] && rm -rf "$app_path"
[[ -S "$runtime_socket" ]] && rm "$runtime_socket"

if $purge; then
  rm -rf "$HOME/Library/Application Support/NotchRelay"
  defaults delete com.henryvn27.NotchRelay 2>/dev/null || true
  print "Removed NotchRelay, its integration, settings, and runtime data."
else
  print "Removed NotchRelay and its integration. Preferences and diagnostics were preserved."
fi
