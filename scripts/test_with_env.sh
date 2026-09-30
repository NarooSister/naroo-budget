#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-$ROOT_DIR/env/supabase.json}"

cd "$ROOT_DIR"

if [[ -f "$ENV_FILE" ]]; then
  flutter test --dart-define-from-file="$ENV_FILE" "$@"
else
  # Tests must pass without secrets; local env is optional.
  flutter test "$@"
fi
