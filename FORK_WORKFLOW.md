# Fork Workflow (Custom FluffyChat)

This repository uses a fork workflow with upstream tag mirroring.

## Branch and remote model

- `origin`: your fork (`shoneg/fluffychat-JuMiKK-Version`)
- `upstream`: official FluffyChat repository (`krille-chan/fluffychat`)
- `custom/main`: product branch for your app
- `feature/*`: custom changes (logo, branding, behavior)
- `sync/upstream-*`: temporary integration branches for upstream merges

## Rules

- Do not commit directly to `custom/main`.
- Integrate upstream changes only through `sync/upstream-*` branches.
- Build official APKs only from tags.
- Every released custom build must have a `jumikk-*` tag.

## Initial setup

```bash
git remote add upstream git@github.com:krille-chan/fluffychat.git
git branch custom/main main
```

## Upstream sync workflow

1. Create sync branch and merge upstream reference:

```bash
./scripts/fork-sync-upstream.sh vX.Y.Z
```

2. Resolve conflicts (if any), run tests/build checks.
3. Merge `sync/upstream-*` into `custom/main`.
4. Mirror upstream tags into your fork:

```bash
./scripts/fork-mirror-upstream-tags.sh
```

## Custom feature workflow

```bash
git switch custom/main
git switch -c feature/logo
# implement changes
git switch custom/main
git merge --no-ff feature/logo
```

## Release tagging

Use an app release tag based on the upstream version:

- Format: `jumikk-v<upstream-tag>+r<n>`
- Example: `jumikk-v1.23.0+r1`

```bash
git switch custom/main
git tag -a jumikk-v1.23.0+r1 -m "Custom release based on upstream v1.23.0"
git push origin jumikk-v1.23.0+r1
```

## Release note template

- Upstream base tag: `vX.Y.Z`
- Custom release tag: `jumikk-vX.Y.Z+rN`
- Included custom commits/features:
  - `<commit-or-pr>`
  - `<commit-or-pr>`
