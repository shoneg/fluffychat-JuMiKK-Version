#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <upstream-ref> [sync-branch-name]"
  echo "Example: $0 v1.27.0"
  echo "Example: $0 upstream/main sync/upstream-main-20260224"
  exit 1
fi

upstream_ref="$1"
custom_branch="custom/main"
default_branch_name="sync/upstream-$(echo "${upstream_ref}" | tr '/:' '--')-$(date +%Y%m%d)"
sync_branch="${2:-$default_branch_name}"

if ! git rev-parse --verify "$custom_branch" >/dev/null 2>&1; then
  echo "Branch '$custom_branch' does not exist."
  exit 1
fi

if ! git remote get-url upstream >/dev/null 2>&1; then
  echo "Remote 'upstream' is missing."
  exit 1
fi

if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "Working tree is not clean. Commit or stash your changes first."
  exit 1
fi

echo "Fetching upstream refs and tags..."
git fetch upstream --tags

if ! git rev-parse --verify "${upstream_ref}" >/dev/null 2>&1; then
  echo "Ref '${upstream_ref}' not found after fetch."
  exit 1
fi

echo "Switching to ${custom_branch}..."
git switch "${custom_branch}"

echo "Creating sync branch ${sync_branch}..."
git switch -c "${sync_branch}"

echo "Merging ${upstream_ref} into ${sync_branch}..."
set +e
git merge --no-ff "${upstream_ref}" -m "chore(sync): merge ${upstream_ref} into ${custom_branch}"
merge_exit=$?
set -e

if [[ $merge_exit -ne 0 ]]; then
  echo
  echo "Merge has conflicts. Resolve them, run tests, and continue with:"
  echo "  git add <resolved-files>"
  echo "  git commit"
  echo "Then merge this sync branch into ${custom_branch}."
  exit $merge_exit
fi

echo
echo "Sync branch created successfully: ${sync_branch}"
echo "Next steps:"
echo "  1. Run tests/build checks."
echo "  2. Merge ${sync_branch} into ${custom_branch}."
echo "  3. Mirror upstream tags to origin with scripts/fork-mirror-upstream-tags.sh."
