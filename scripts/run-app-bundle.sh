#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
bundle_path="$("$repo_root/scripts/build-app-bundle.sh")"

open -n "$bundle_path"
