#!/usr/bin/env bash
set -euo pipefail

# Resolve l10n merge conflicts by taking upstream versions and then
# reapplying fork branding in string values.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

mapfile -t conflicted_files < <(git diff --name-only --diff-filter=U | rg '^lib/l10n/.*\.arb$' || true)

if [[ ${#conflicted_files[@]} -eq 0 ]]; then
  echo "No conflicted ARB files found."
  exit 0
fi

for file in "${conflicted_files[@]}"; do
  git checkout --theirs -- "$file"
done

"$ROOT_DIR/scripts/fork-reapply-branding.sh" "${conflicted_files[@]}"

git add -- "${conflicted_files[@]}"

echo "Resolved and staged ${#conflicted_files[@]} l10n conflict file(s)."
