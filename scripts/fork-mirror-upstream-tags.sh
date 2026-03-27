#!/usr/bin/env bash
set -euo pipefail

if ! git remote get-url upstream >/dev/null 2>&1; then
  echo "Remote 'upstream' is missing."
  exit 1
fi

if ! git remote get-url origin >/dev/null 2>&1; then
  echo "Remote 'origin' is missing."
  exit 1
fi

echo "Fetching upstream tags..."
git fetch upstream --tags

echo "Comparing upstream and origin tags..."
upstream_tags="$(git ls-remote --tags --refs upstream | awk '{print $2}' | sed 's#refs/tags/##' | sort)"
origin_tags="$(git ls-remote --tags --refs origin | awk '{print $2}' | sed 's#refs/tags/##' | sort)"

missing_tags="$(comm -23 <(printf '%s\n' "${upstream_tags}") <(printf '%s\n' "${origin_tags}"))"

if [[ -z "${missing_tags}" ]]; then
  echo "No upstream tags missing on origin."
  exit 0
fi

echo "Pushing missing tags to origin..."
while IFS= read -r tag; do
  [[ -z "${tag}" ]] && continue
  echo "  -> ${tag}"
  git push origin "refs/tags/${tag}:refs/tags/${tag}"
done <<< "${missing_tags}"

echo "Done. Missing upstream tags have been mirrored to origin."
