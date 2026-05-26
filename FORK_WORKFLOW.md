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
3. Before merging, check and adjust the custom build version:
   - Update `version` / build number in `pubspec.yaml` if the custom release needs a new app version.
4. Merge `sync/upstream-*` into `custom/main`.
5. Mirror upstream tags into your fork:

```bash
./scripts/fork-mirror-upstream-tags.sh
```

6. For releases, also update the custom version tag according to [Release tagging](#release-tagging) and update the F-Droid repository according to [F-Droid repository update](#f-droid-repository-update).

### L10n conflict strategy (recommended)

To avoid losing upstream translation updates while keeping fork branding:

1. Resolve ARB conflicts by preferring upstream and then reapplying branding:

```bash
./scripts/fork-resolve-l10n-conflicts.sh
```

2. If you only need to reapply branding later (without conflict resolution):

```bash
./scripts/fork-reapply-branding.sh
```

What these scripts do:

- `fork-resolve-l10n-conflicts.sh`
  - Finds conflicted `lib/l10n/*.arb` files
  - Uses `git checkout --theirs` for those files
  - Reapplies branding (`FluffyChat`/`Fluffy Chat` -> `JuMiKK-Chat`) in values
  - Stages the resolved files
- `fork-reapply-branding.sh`
  - Reapplies branding for ARB string values only
  - Keeps ARB keys unchanged (for example `newMessageInFluffyChat`)

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

## F-Droid repository update

After building a release APK, update the separate F-Droid repository:

```bash
# 1. Copy the new APK into repo/, for example:
repo/de.jumikk.chat_1.2.30.apk

# 2. Update metadata/de.jumikk.chat.yml:
CurrentVersion: "1.2.3"
CurrentVersionCode: <new-versionCode>

# 3. Rebuild/sign the repository index:
fdroid update
```

## Release note template

- Upstream base tag: `vX.Y.Z`
- Custom release tag: `jumikk-vX.Y.Z+rN`
- Included custom commits/features:
  - `<commit-or-pr>`
  - `<commit-or-pr>`
