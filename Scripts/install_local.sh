#!/bin/zsh
set -euo pipefail

script_dir="${0:A:h}"
project_root="${script_dir:h}"
derived_data="$project_root/DerivedData"
destination="$HOME/Applications/NotchRelay.app"

cd "$project_root"
command -v xcodegen >/dev/null 2>&1 || { print -u2 "Install XcodeGen first: brew install xcodegen"; exit 1; }
xcodegen generate
xcodebuild \
  -project NotchRelay.xcodeproj \
  -scheme NotchRelay \
  -configuration Release \
  -derivedDataPath "$derived_data" \
  -destination 'platform=macOS,arch=arm64' \
  ENABLE_HARDENED_RUNTIME=NO \
  build

source_app="$derived_data/Build/Products/Release/NotchRelay.app"
[[ -d "$source_app" ]] || { print -u2 "Release app was not produced"; exit 1; }

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

mkdir -p "$HOME/Applications"
backup=""
if [[ -d "$destination" ]]; then
  backup="$HOME/Applications/NotchRelay.app.backup-$(date +%Y%m%d-%H%M%S)"
  mv "$destination" "$backup"
  print "Previous local app moved to $backup"
fi
ditto "$source_app" "$destination"

swift "$script_dir/install_hooks.swift" install --helper "$destination/Contents/Helpers/notchrelay-hook"
open -n "$destination"
bridge_ready=false
for _ in {1..20}; do
  if "$HOME/.local/bin/notchrelay-hook" ping >/dev/null 2>&1; then
    bridge_ready=true
    break
  fi
  sleep 0.25
done
$bridge_ready || { print -u2 "Installed app did not start its authenticated bridge."; exit 1; }
"$script_dir/verify_installation.sh" --app "$destination" --development
if [[ -n "$backup" && "$backup" == "$HOME/Applications/NotchRelay.app.backup-"* ]]; then
  /bin/rm -rf "$backup"
fi

print "Installed NotchRelay locally at $destination"
print "Open Codex /hooks once to review and trust the four NotchRelay commands if prompted."
