<!-- TOC start (generated with https://github.com/derlin/bitdowntoc) -->

- [Usage](#usage)
   * [Tag mode](#tag-mode)
- [What's pipeline-owned vs. hand-editable](#whats-pipeline-owned-vs-hand-editable)
- [Tag format](#tag-format)
- [Preflight](#preflight)
- [FVM note](#fvm-note)

<!-- TOC end -->

Audience: maintainers and contributors who want to understand or invoke the release
flow. End users of the package don't need anything in this directory.

Cuts a versioned release of `list_smith`. Bumps the `version:` field in `pubspec.yaml`
via `cider`, finalises the `## Unreleased` block in `CHANGELOG.md` into a dated section,
regenerates `example/pubspec.lock` (once the example app exists) so its `path: ../`
parent entry tracks the new version, commits the changed files, creates a SemVer tag,
and pushes commit + tag atomically. The tag push triggers
[`../.github/workflows/publish.yml`](../.github/workflows/publish.yml), which then
publishes to pub.dev via OIDC.

Laptop-only, does not run inside CI.

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

By default, `git tag <version>` produces a **lightweight tag**, a bare ref pointer with no
body, message, or signature. Pass `-m "MSG"` / `--tag-message "MSG"` to produce an
**annotated tag** with that message; if your git config has `tag.gpgSign=true`, the
annotated tag is also signed.

The lightweight default is independent of your `tag.gpgSign` setting, for the
no-`-m` path the script runs `git tag` with `-c tag.gpgSign=false` applied to that one
invocation, so plain `release.sh minor` never opens an editor or demands a message.
Lightweight tags can't be signed (there's no body to sign), so the bypass is
mechanically necessary, not a stylistic choice.

## What's pipeline-owned vs. hand-editable

`CHANGELOG.md`, the `version:` field in `pubspec.yaml`, and `example/pubspec.lock` are
**pipeline-owned**: the script reorders or overwrites manual edits to them. Hand-edits
will not survive the next release.

`example/pubspec.lock` is regenerated automatically because `example/pubspec.yaml`
declares its parent via `path: ../`, when the parent version changes, the lockfile
needs to follow. The release script runs `(cd example && flutter pub get)` after the
bump and stages the refreshed lockfile in the prep commit, so the tree is consistent
before pub.dev sees it. Without this, the next `flutter pub get` *anywhere* (CI's
publish step, pana on pub.dev, an IDE on a contributor's machine) would rewrite it
and `flutter pub publish` would complain that a checked-in file is modified. This step
is skipped until the example app is scaffolded (a later pass).

The `## Unreleased` block in `CHANGELOG.md` is the script's **input**, populated
incrementally between releases by
[`../.github/workflows/changelog.yml`](../.github/workflows/changelog.yml) (which
appends each merged PR's title under the appropriate `sem-*` bucket). The script
bails if it's empty.

The `cider:` block in `pubspec.yaml` is static configuration (link templates, URLs)
and sits outside the pipeline-owned set, hand-editable.

## Tag format

`<MAJOR>.<MINOR>.<PATCH>`, no `v` prefix. Matches the trigger pattern in
[`../.github/workflows/publish.yml`](../.github/workflows/publish.yml)
(`[0-9]+.[0-9]+.[0-9]+`) and pub.dev's canonical `{{version}}` convention.

## Preflight

The script refuses to proceed unless every check passes:

- `flutter` resolvable (prefers `.fvm/flutter_sdk/bin/flutter` if present, else PATH).
  Also gives us `dart` from the same SDK directory for `dart format`.
- `cider` on PATH.
- `jq` on PATH (reads the lint manifest, `.github/lint-checks.json`).
- `docker` on PATH with the daemon running. The lint checks from
  `.github/lint-checks.json` (`shellcheck`, `actionlint`, `rumdl`, `ryl`) run via the
  linterpol image (`ghcr.io/lahaluhem/linterpol:latest`), not local installs; a
  stopped daemon fails preflight fast with a clear message.
- Working tree clean, on `main`, in sync with `origin/main` (fetches first).
- `CHANGELOG.md` has a non-empty `## Unreleased` (or `## [Unreleased]`) section.
- `dart format`, `flutter analyze`, and `flutter test` all clean.
- The target tag does not already exist locally or on the remote.

`flutter pub publish --dry-run` is *not* in preflight. It cross-checks three things
that must be satisfied simultaneously:

1. `pubspec.yaml`'s `version:` matches a CHANGELOG header.
2. No checked-in files are modified in the working tree.
3. The tarball builds and validates against pub.dev rules.

(1) only holds *after* `cider bump` + `cider release`. (2) only holds *after*
`git commit`, running the dry-run against the working tree mid-execute would
trip on the bump/release modifications. So the dry-run runs as step 6, after
the prep commit lands. The `ERR` trap handles failure in two phases:

- **Pre-commit failure** (bump, release, or `example/` resync errored, no commit yet):
  restore `pubspec.yaml` + `CHANGELOG.md` + `example/pubspec.lock` from `HEAD`.
- **Post-commit, pre-tag failure** (dry-run rejected the prep commit):
  `git reset --hard HEAD~1` to drop the prep commit, leaving the working tree
  exactly as it was before `release.sh` started. No remote tag is ever created
  in this case, the validation gate sits between commit and tag, so there's
  nothing to clean up on `origin`.

After the dry-run passes, the trap clears, `git tag` / `git push` failures
require manual recovery (the script prints the recipe).

## FVM note

If `.fvm/flutter_sdk/bin/flutter` exists, the script prepends `.fvm/flutter_sdk/bin/`
to `PATH` so plain `flutter` and `dart` resolve to the `.fvmrc`-pinned SDK.
Otherwise, it falls back to whatever's on `PATH`, a non-FVM contributor can run
the script unchanged. SDK-version compatibility is enforced indirectly via
`flutter pub publish --dry-run` in the execute phase.
