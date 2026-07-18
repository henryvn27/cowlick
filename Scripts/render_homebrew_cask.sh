#!/bin/zsh
set -euo pipefail

version="${1:?usage: render_homebrew_cask.sh VERSION DMG_PATH [OUTPUT]}"
dmg="${2:?usage: render_homebrew_cask.sh VERSION DMG_PATH [OUTPUT]}"
output="${3:-Config/Homebrew/notchrelay.rb}"
[[ -f "$dmg" ]] || { print -u2 "DMG not found: $dmg"; exit 1; }
sha="$(shasum -a 256 "$dmg" | awk '{print $1}')"

temporary="$(mktemp)"
sed -e "s/__VERSION__/$version/g" -e "s/__SHA256__/$sha/g" Config/Homebrew/notchrelay.rb.template > "$temporary"
mv "$temporary" "$output"
ruby -c "$output"
print "$output"
