#!/usr/bin/env bash
set -euo pipefail

# Reapply app branding in ARB values while preserving keys and metadata keys.
# Default replacement:
#   Fluffy Chat / FluffyChat -> JuMiKK-Chat

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ $# -gt 0 ]]; then
  files=("$@")
else
  mapfile -t files < <(find lib/l10n -maxdepth 1 -type f -name 'intl_*.arb' | sort)
fi

if [[ ${#files[@]} -eq 0 ]]; then
  echo "No ARB files found."
  exit 0
fi

for file in "${files[@]}"; do
  if [[ ! -f "$file" ]]; then
    echo "Skipping missing file: $file"
    continue
  fi

  # Only replace inside JSON value content after the key/value separator,
  # so keys like "newMessageInFluffyChat" remain unchanged.
  perl -i -pe '
    if (/^(\s*"[^"]+"\s*:\s*")(.*)$/) {
      my $prefix = $1;
      my $rest = $2;
      $rest =~ s/Fluffy Chat/JuMiKK-Chat/g;
      $rest =~ s/FluffyChat/JuMiKK-Chat/g;
      $_ = $prefix . $rest;
    }
  ' "$file"
done

echo "Branding reapplied in ${#files[@]} file(s)."
