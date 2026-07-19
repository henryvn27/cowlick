#!/bin/zsh
set -euo pipefail

script_dir="${0:A:h}"
project_root="${script_dir:h}"
source "$script_dir/release_common.sh"

version="${1:-}"
validate_release_version "$version"

awk -v version="$version" '
  $1 == "##" && $2 == version {
    found = 1
    printing = 1
  }
  printing && $1 == "##" && $2 != version { exit }
  printing { print }
  END { if (!found) exit 1 }
' "$project_root/CHANGELOG.md" \
  || release_error "CHANGELOG.md has no release section for $version"
