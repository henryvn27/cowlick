#!/bin/zsh
set -euo pipefail

script_dir="${0:A:h}"
project_root="${script_dir:h}"
derived_data="$project_root/DerivedData"
configuration="Debug"
run_verify=false
show_logs=false
local_telemetry=false

for argument in "$@"; do
  case "$argument" in
    --verify) run_verify=true ;;
    --logs) show_logs=true ;;
    --telemetry) local_telemetry=true ;;
    --debug) configuration="Debug" ;;
    *) print -u2 "Unknown option: $argument"; exit 2 ;;
  esac
done

cd "$project_root"

existing_pids=(${(f)"$(pgrep -x NotchRelay 2>/dev/null || true)"})
for process_id in $existing_pids; do
  process_path="$(ps -p "$process_id" -o command= 2>/dev/null || true)"
  if [[ "$process_path" == *"/NotchRelay.app/Contents/MacOS/NotchRelay"* ]]; then
    kill "$process_id"
  fi
done
for _ in {1..50}; do
  pgrep -x NotchRelay >/dev/null 2>&1 || break
  sleep 0.1
done

if ! command -v xcodegen >/dev/null 2>&1; then
  print -u2 "XcodeGen is required for contributor builds: brew install xcodegen"
  exit 1
fi

xcodegen generate
xcodebuild \
  -project NotchRelay.xcodeproj \
  -scheme NotchRelay \
  -configuration "$configuration" \
  -derivedDataPath "$derived_data" \
  -destination 'platform=macOS,arch=arm64' \
  build

app_path="$derived_data/Build/Products/$configuration/NotchRelay.app"
[[ -d "$app_path" ]] || { print -u2 "Fresh app bundle not found at $app_path"; exit 1; }

if $local_telemetry; then
  NOTCHRELAY_LOCAL_TELEMETRY=1 "$app_path/Contents/MacOS/NotchRelay" >/dev/null 2>&1 &!
else
  open -n "$app_path"
fi

helper="$app_path/Contents/Helpers/notchrelay-hook"
bridge_ready=false
for _ in {1..100}; do
  if [[ -x "$helper" ]] && "$helper" ping >/dev/null 2>&1; then
    bridge_ready=true
    break
  fi
  sleep 0.1
done
$bridge_ready || { print -u2 "NotchRelay launched but its authenticated bridge did not become ready"; exit 1; }

if $run_verify; then
  "$script_dir/verify_installation.sh" --app "$app_path" --development
fi

if $show_logs; then
  log stream --style compact --level info --predicate 'subsystem == "com.henryvn27.NotchRelay"'
fi

print "NotchRelay launched from $app_path"
