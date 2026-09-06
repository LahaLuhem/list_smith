<!-- TOC start (generated with https://github.com/derlin/bitdowntoc) -->

- [Usage](#usage)
   * [Tag mode](#tag-mode)
- [What's pipeline-owned vs. hand-editable](#whats-pipeline-owned-vs-hand-editable)
- [Tag format](#tag-format)
- [Preflight](#preflight)
- [FVM note](#fvm-note)

<!-- TOC end -->

For maintainers and contributors who want to understand or invoke the release flow. End users of
the package need nothing in this directory.

`release.sh` cuts a versioned release: bump `version:` in `pubspec.yaml` via `cider`, finalise the
`## Unreleased` block in `CHANGELOG.md` into a dated section, regenerate `example/pubspec.lock` so
its `path: ../` entry tracks the new version, commit, tag, and push commit and tag together. That
tag push triggers [`publish.yml`](../.github/workflows/publish.yml), which publishes to pub.dev
over OIDC.

Laptop-only, never CI.

## Usage

```bash
scripts/release.sh                                # fully interactive
scripts/release.sh patch                          # bump type set, confirm on TTY
scripts/release.sh patch --yes                    # non-interactive (CI-style)
scripts/release.sh --dry-run                      # full preflight + plan, no side effects
scripts/release.sh minor -m "Big new feature"     # annotated tag with this message
```

`BUMP` is one of `major`, `minor`, `patch`. The script prompts on a TTY if omitted.

### Tag mode

By default `git tag <version>` produces a **lightweight tag**, a bare ref pointer with no body,
message or signature. Pass `-m "MSG"` (or `--tag-message`) for an **annotated tag**, which your
`tag.gpgSign=true` will also sign.

The lightweight default ignores your `tag.gpgSign` setting: on the no-`-m` path the script applies
`-c tag.gpgSign=false` to that one invocation, so a plain `release.sh minor` never opens an editor
or demands a message. A lightweight tag has no body to sign, so that bypass is mechanically
necessary rather than a preference.

## What's pipeline-owned vs. hand-editable

`CHANGELOG.md`, the `version:` field in `pubspec.yaml`, and `example/pubspec.lock` are
**pipeline-owned**: the script reorders or overwrites manual edits, so hand-edits don't survive the
next release.

`example/pubspec.lock` is regenerated because `example/pubspec.yaml` declares its parent via
`path: ../`, so the lockfile has to follow when the parent version changes. The script runs
`(cd example && flutter pub get)` after the bump and stages the result in the prep commit. Without
that, the next `flutter pub get` *anywhere* (CI's publish step, pana on pub.dev, an IDE on a
contributor's machine) rewrites it and `flutter pub publish` complains that a checked-in file is
modified.

The `## Unreleased` block is the script's **input**, filled in between releases by
[`changelog.yml`](../.github/workflows/changelog.yml) from each merged PR's title, under the bucket
its `sem-*` label picks. The script bails if it's empty.

The `cider:` block in `pubspec.yaml` is static config (link templates, URLs), outside the
pipeline-owned set and hand-editable.

## Tag format

`<MAJOR>.<MINOR>.<PATCH>`, no `v` prefix, matching both the trigger pattern in
[`publish.yml`](../.github/workflows/publish.yml) (`[0-9]+.[0-9]+.[0-9]+`) and pub.dev's canonical
`{{version}}` convention.

## Preflight

The script refuses to proceed unless every check passes:

- `flutter` resolvable, preferring `.fvm/flutter_sdk/bin/flutter` over PATH. That also supplies
  `dart` from the same SDK for `dart format`.
- `cider` on PATH.
- `jq` on PATH, for reading [`lint-checks.json`](../.github/lint-checks.json).
- `docker` on PATH with the daemon up, since the lint checks run via the linterpol image that
  manifest names rather than local installs. A stopped daemon fails fast with a clear message.
- Working tree clean, on `main`, in sync with `origin/main` (it fetches first).
- A non-empty `## Unreleased` (or `## [Unreleased]`) section in `CHANGELOG.md`.
- `dart format`, `flutter analyze` and `flutter test` all clean.
- The target tag doesn't already exist, locally or on the remote.

`flutter pub publish --dry-run` is *not* in preflight, because it cross-checks three things that
can only hold at the same time later:

1. `pubspec.yaml`'s `version:` matches a CHANGELOG header, true only after `cider bump` + `release`.
2. No checked-in file is modified, true only after `git commit`.
3. The tarball builds and validates against pub.dev's rules.

So it runs as step 6, after the prep commit lands. The `ERR` trap covers failure in two phases:

- **Pre-commit** (bump, release or the `example/` resync errored): restore `pubspec.yaml`,
  `CHANGELOG.md` and `example/pubspec.lock` from `HEAD`.
- **Post-commit, pre-tag** (the dry-run rejected the prep commit): `git reset --hard HEAD~1` drops
  it, leaving the tree exactly as `release.sh` found it. The gate sits between commit and tag, so
  no remote tag exists to clean up.

Past the dry-run the trap clears, and a `git tag` or `git push` failure needs manual recovery. The
script prints the recipe.

## FVM note

If `.fvm/flutter_sdk/bin/flutter` exists, the script prepends that directory to `PATH` so plain
`flutter` and `dart` resolve to the `.fvmrc`-pinned SDK. Otherwise it falls back to `PATH`, so a
non-FVM contributor runs it unchanged. SDK compatibility is enforced indirectly, by the
`flutter pub publish --dry-run` in the execute phase.
