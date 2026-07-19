#!/bin/zsh
set -euo pipefail

script_dir="${0:A:h}"
source "$script_dir/release_common.sh"

version="${1:-}"
artifact_directory="${2:-}"
validate_release_version "$version"
[[ -d "$artifact_directory" ]] || release_error "artifact directory is missing"

zip="$artifact_directory/Cowlick-$version.zip"
dmg="$artifact_directory/Cowlick-$version.dmg"
checksums="$artifact_directory/checksums.txt"
appcast="$artifact_directory/appcast.xml"
for artifact in "$zip" "$dmg" "$checksums" "$appcast"; do
  [[ -f "$artifact" ]] || release_error "release artifact is missing: ${artifact:t}"
done

for filename in "${zip:t}" "${dmg:t}"; do
  expected="$(awk -v filename="$filename" '$2 == filename { print $1 }' "$checksums")"
  [[ "$expected" =~ '^[0-9a-f]{64}$' ]] \
    || release_error "checksums.txt has no valid SHA-256 for $filename"
  actual="$(shasum -a 256 "$artifact_directory/$filename" | awk '{ print $1 }')"
  [[ "$actual" == "$expected" ]] || release_error "SHA-256 mismatch for $filename"
done
[[ "$(wc -l < "$checksums" | tr -d ' ')" == 2 ]] \
  || release_error "checksums.txt must contain exactly the ZIP and DMG"

xmllint --noout "$appcast"
hdiutil verify "$dmg"
xcrun stapler validate "$dmg"
spctl --assess --type open --context context:primary-signature --verbose=2 "$dmg"

expected_identity="${DEVELOPER_ID_APPLICATION:-}"
expected_team="${DEVELOPMENT_TEAM:-}"
sparkle_private_key="${SPARKLE_PRIVATE_KEY:-}"
[[ -n "$expected_identity" ]] || release_error "DEVELOPER_ID_APPLICATION is required"
[[ -n "$expected_team" ]] || release_error "DEVELOPMENT_TEAM is required"
[[ -n "$sparkle_private_key" ]] || release_error "SPARKLE_PRIVATE_KEY is required"
codesign --verify --strict --verbose=2 "$dmg"
verify_code_identity "$dmg" "release DMG" "$expected_identity" "$expected_team" false

unpacked="$(mktemp -d "${TMPDIR%/}/cowlick-release-verify.XXXXXX")"
mounted="$(mktemp -d "${TMPDIR%/}/cowlick-dmg-verify.XXXXXX")"
attached=false
cleanup() {
  if [[ "$attached" == true ]]; then
    if ! hdiutil detach "$mounted" >/dev/null 2>&1; then
      rm -rf "$unpacked"
      return
    fi
  fi
  rm -rf "$unpacked" "$mounted"
}
trap cleanup EXIT
ditto -x -k "$zip" "$unpacked"
app="$unpacked/Cowlick.app"
verify_cowlick_app "$app" "$version" "$expected_identity" "$expected_team"

hdiutil attach "$dmg" -readonly -nobrowse -mountpoint "$mounted" >/dev/null
attached=true
dmg_app="$mounted/Cowlick.app"
verify_cowlick_app "$dmg_app" "$version" "$expected_identity" "$expected_team"
zip_app_hash="$(code_directory_hash "$app")"
dmg_app_hash="$(code_directory_hash "$dmg_app")"
zip_helper_hash="$(code_directory_hash "$app/Contents/Helpers/cowlick-hook")"
dmg_helper_hash="$(code_directory_hash "$dmg_app/Contents/Helpers/cowlick-hook")"
[[ -n "$zip_app_hash" && "$zip_app_hash" == "$dmg_app_hash" ]] \
  || release_error "ZIP and DMG contain different Cowlick.app builds"
[[ -n "$zip_helper_hash" && "$zip_helper_hash" == "$dmg_helper_hash" ]] \
  || release_error "ZIP and DMG contain different cowlick-hook builds"
hdiutil detach "$mounted" >/dev/null
attached=false

sign_tool="$script_dir/../DerivedData/SourcePackages/artifacts/sparkle/Sparkle/bin/sign_update"
[[ -x "$sign_tool" ]] || release_error "Sparkle sign_update tool is unavailable"
enclosure_count="$(xmllint --xpath \
  'count(//*[local-name()="enclosure"])' "$appcast")"
[[ "$enclosure_count" == "1" ]] || release_error "appcast must contain exactly one update enclosure"
enclosure_url="$(xmllint --xpath \
  'string(//*[local-name()="enclosure"]/@url)' "$appcast")"
enclosure_length="$(xmllint --xpath \
  'string(//*[local-name()="enclosure"]/@length)' "$appcast")"
enclosure_signature="$(xmllint --xpath \
  'string(//*[local-name()="enclosure"]/@*[local-name()="edSignature"])' "$appcast")"
appcast_version="$(xmllint --xpath \
  'string(//*[local-name()="enclosure"]/@*[local-name()="version"])' "$appcast")"
appcast_short_version="$(xmllint --xpath \
  'string(//*[local-name()="enclosure"]/@*[local-name()="shortVersionString"])' "$appcast")"
expected_url="https://github.com/henryvn27/cowlick/releases/download/v$version/Cowlick-$version.zip"
expected_length="$(stat -f %z "$zip")"
expected_build="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$app/Contents/Info.plist")"
[[ "$enclosure_url" == "$expected_url" ]] || release_error "appcast enclosure URL is incorrect"
[[ "$enclosure_length" == "$expected_length" ]] || release_error "appcast enclosure length is incorrect"
[[ "$appcast_version" == "$expected_build" ]] || release_error "appcast build version is incorrect"
[[ "$appcast_short_version" == "$version" ]] || release_error "appcast marketing version is incorrect"
[[ -n "$enclosure_signature" ]] || release_error "appcast archive signature is missing"
print -r -- "$sparkle_private_key" | "$sign_tool" \
  --verify --ed-key-file - "$appcast"
print -r -- "$sparkle_private_key" | "$sign_tool" \
  --verify --ed-key-file - "$zip" "$enclosure_signature"

print "Cowlick $version release artifacts verified."
