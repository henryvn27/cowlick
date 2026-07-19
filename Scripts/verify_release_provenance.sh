#!/usr/bin/env bash
set -euo pipefail

release_ref="${1:-HEAD}"
main_ref="${2:-refs/remotes/origin/main}"

release_sha="$(git rev-parse --verify --end-of-options "${release_ref}^{commit}" 2>/dev/null)" \
  || { printf "release provenance error: cannot resolve release ref '%s'\n" "$release_ref" >&2; exit 1; }
main_sha="$(git rev-parse --verify --end-of-options "${main_ref}^{commit}" 2>/dev/null)" \
  || { printf "release provenance error: cannot resolve main ref '%s'\n" "$main_ref" >&2; exit 1; }

if [[ "$release_sha" != "$main_sha" ]]; then
  printf 'release provenance error: release commit %s does not match current main %s\n' \
    "$release_sha" "$main_sha" >&2
  exit 1
fi

printf '%s\n' "$release_sha"
