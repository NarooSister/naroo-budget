#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-$ROOT_DIR/env/supabase.json}"
EXAMPLE_FILE="$ROOT_DIR/env/supabase.example.json"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing env file: $ENV_FILE"
  echo "Copy the example and fill in your Supabase values:"
  echo "  cp \"$EXAMPLE_FILE\" \"$ENV_FILE\""
  exit 1
fi

cd "$ROOT_DIR"
flutter run -d chrome --dart-define-from-file="$ENV_FILE" "$@"
