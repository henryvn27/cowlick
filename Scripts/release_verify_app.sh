#!/bin/zsh
set -euo pipefail

script_dir="${0:A:h}"
source "$script_dir/release_common.sh"

app="${1:?usage: release_verify_app.sh APP VERSION}"
version="${2:?usage: release_verify_app.sh APP VERSION}"
expected_identity="${DEVELOPER_ID_APPLICATION:-}"
expected_team="${DEVELOPMENT_TEAM:-}"

validate_release_version "$version"
[[ -n "$expected_identity" ]] || release_error "DEVELOPER_ID_APPLICATION is required"
[[ -n "$expected_team" ]] || release_error "DEVELOPMENT_TEAM is required"
verify_cowlick_app "$app" "$version" "$expected_identity" "$expected_team"
print "Cowlick $version app identity verified."
