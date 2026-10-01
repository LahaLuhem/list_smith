#!/usr/bin/env bash
# ===========================================================================
# release.sh
#
# Cuts a versioned release, whose tag push triggers publish.yml. Laptop-only, never CI. How it
# works is in scripts/README.md, and `--help` lists the checks and the steps.
# ===========================================================================
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

# The `.fvmrc`-pinned SDK when FVM has one, else PATH. Set first, so every later `flutter` and
# `dart` resolves to it.
if [ -x "${REPO_ROOT}/.fvm/flutter_sdk/bin/flutter" ]; then
    PATH="${REPO_ROOT}/.fvm/flutter_sdk/bin:${PATH}"
    SDK_SOURCE="${REPO_ROOT}/.fvm/flutter_sdk/bin (.fvmrc-pinned via FVM)"
elif command -v flutter >/dev/null 2>&1; then
    SDK_SOURCE="$(command -v flutter) (host PATH, no .fvm/flutter_sdk symlink)"
else
    printf "[release] ERROR: no 'flutter' on PATH and no .fvm/flutter_sdk/bin/flutter found.\n" >&2
    printf "[release] Install Flutter (see pubspec.yaml), or run 'fvm install' from the project root.\n" >&2
    exit 1
fi

MAIN_BRANCH="main"

# The lint checks and the linterpol image tag come from the manifest dartender's CI reads too, so
# this preflight and CI can't drift.
LINT_MANIFEST="${REPO_ROOT}/.github/lint-checks.json"

BUMP=""
YES=0
DRY_RUN=0
TAG_MESSAGE=""

usage() {
    cat <<'USAGE'
release.sh: bump version, finalise CHANGELOG, commit, tag, push to origin.

Usage:
  scripts/release.sh [BUMP] [OPTIONS]

Arguments:
  BUMP            one of: major, minor, patch  (prompted if omitted on a TTY)

Options:
  -y, --yes               skip the confirmation prompt (required for non-TTY)
  -n, --dry-run           run full preflight + print the plan, no side effects
  -m, --tag-message MSG   attach MSG as the tag message (creates an annotated,
                          signed-if-configured tag). Without this flag the tag
                          is lightweight.
  -h, --help              show this message

Preflight (all must pass):
  - `flutter` resolvable (via `.fvm/flutter_sdk/bin/` if FVM is set up, else PATH)
  - cider on PATH
  - jq on PATH (reads the lint manifest, .github/lint-checks.json)
  - docker on PATH + daemon running (runs the lint checks via linterpol)
  - working tree clean, on `main`, in sync with origin/main (fetches first)
  - CHANGELOG.md has a non-empty `## Unreleased` (or `## [Unreleased]`) section
  - every check in .github/lint-checks.json clean (via linterpol image)
  - `dart format --output=none --set-exit-if-changed .` clean
  - `flutter --no-version-check analyze lib test` clean
  - `flutter --no-version-check test` green
  - computed tag unused locally and on origin

Sequence:
  cider bump <BUMP>                                (pubspec.yaml version → new)
  cider release                                    (CHANGELOG.md ## Unreleased → ## <new> dated today)
  (cd example && flutter pub get)                  (resync example/pubspec.lock, if example/ exists)
  git add  pubspec.yaml CHANGELOG.md [example/pubspec.lock]
  git commit -m "Prep for release <new>"
  flutter pub publish --dry-run                    (validates clean committed state, resets HEAD~1 on fail)
  git tag <new>                                    (lightweight by default, annotated when -m given)
  git push --atomic origin HEAD:main <new>         (triggers publish.yml)

Non-interactive example:
  scripts/release.sh patch --yes
USAGE
}

while (($#)); do
    case "$1" in
        major|minor|patch) BUMP="$1" ;;
        -y|--yes)          YES=1 ;;
        -n|--dry-run)      DRY_RUN=1 ;;
        -m|--tag-message)
            shift
            if [ $# -eq 0 ] || [ -z "${1}" ]; then
                printf '%s requires a non-empty MSG argument\n' "${0##*/} -m/--tag-message" >&2
                exit 2
            fi
            TAG_MESSAGE="$1"
            ;;
        -h|--help)         usage; exit 0 ;;
        *)                 printf 'unknown arg: %s (use --help)\n' "$1" >&2; exit 2 ;;
    esac
    shift
done

log()  { printf '[release] %s\n' "$*"; }
step() { printf '\n[release] == %s ==\n' "$*"; }
err()  { printf '[release] ERROR: %s\n' "$*" >&2; }

is_tty() { [ -t 0 ]; }

prompt_bump() {
    local reply
    while :; do
        printf 'Bump type [major/minor/patch] (default: patch): ' >&2
        read -r reply
        reply="${reply:-patch}"
        case "$reply" in
            major|minor|patch) echo "$reply"; return 0 ;;
            *) printf 'Please enter major, minor, or patch.\n' >&2 ;;
        esac
    done
}

# ---------------------------------------------------------------------------
# Resolve BUMP
# ---------------------------------------------------------------------------
if [ -z "$BUMP" ]; then
    if is_tty; then
        BUMP="$(prompt_bump)"
    else
        err 'BUMP argument required in non-interactive mode (one of: major, minor, patch).'
        exit 2
    fi
fi

# ---------------------------------------------------------------------------
# Preflight: tooling (fail fast, cheapest checks first)
# ---------------------------------------------------------------------------
step 'Preflight: tooling'
log "Using Flutter SDK from: ${SDK_SOURCE}"
if ! command -v cider >/dev/null 2>&1; then
    err 'cider not on PATH. Install: dart pub global activate cider'
    exit 1
fi
log 'cider available.'
if ! command -v jq >/dev/null 2>&1; then
    err 'jq not on PATH. The preflight reads the lint manifest'
    err '(.github/lint-checks.json) with jq. Install jq and retry.'
    exit 1
fi
log 'jq available.'
if ! command -v docker >/dev/null 2>&1; then
    err 'docker not on PATH. The preflight runs the lint checks (from'
    err '.github/lint-checks.json) via the linterpol image. Install Docker and retry.'
    exit 1
fi
if ! docker info >/dev/null 2>&1; then
    err 'docker is on PATH but the daemon is not responding. Start Docker and retry.'
    exit 1
fi
log 'docker available (lint checks run via linterpol).'

# ---------------------------------------------------------------------------
# Preflight: git state
# ---------------------------------------------------------------------------
step 'Preflight: git state'
log 'Fetching origin (with tag prune)...'
git fetch origin --quiet --tags --prune --prune-tags

# Set up front, or `set -u` trips the later check when every branch below passes.
fail=0

if [ -n "$(git status --porcelain)" ]; then
    err 'Working tree is dirty. Commit or stash first.'
    fail=1
else
    log 'Working tree clean.'
fi

current_branch="$(git rev-parse --abbrev-ref HEAD)"
if [ "$current_branch" != "$MAIN_BRANCH" ]; then
    err "Current branch is '$current_branch', expected '$MAIN_BRANCH'."
    fail=1
else
    log "On branch '$MAIN_BRANCH'."
fi

local_head="$(git rev-parse HEAD)"
remote_head="$(git rev-parse "origin/${MAIN_BRANCH}" 2>/dev/null || echo '')"
if [ -z "$remote_head" ]; then
    err "origin/${MAIN_BRANCH} not found."
    fail=1
elif [ "$local_head" != "$remote_head" ]; then
    err "HEAD ($local_head) is not at origin/${MAIN_BRANCH} ($remote_head). Pull / push first."
    fail=1
else
    log "In sync with origin/${MAIN_BRANCH}."
fi

[ "$fail" -eq 1 ] && { err 'Git-state preflight failed, aborting.'; exit 1; }

# ---------------------------------------------------------------------------
# Compute new version from pubspec.yaml (via cider)
# ---------------------------------------------------------------------------
step 'Compute new version'
current_version="$(cider version)"
log "Current version: ${current_version}"

# Pre-release and build metadata are stripped, giving the same clean X.Y.Z cider would.
IFS='.' read -r cur_major cur_minor cur_patch <<< "${current_version%%[+-]*}"
case "$BUMP" in
    major) new_version="$((cur_major + 1)).0.0" ;;
    minor) new_version="${cur_major}.$((cur_minor + 1)).0" ;;
    patch) new_version="${cur_major}.${cur_minor}.$((cur_patch + 1))" ;;
esac
log "New version:     ${new_version}  (${BUMP} bump)"

# ---------------------------------------------------------------------------
# Preflight: tag collision (no `v` prefix, matches publish.yml + pub.dev)
# ---------------------------------------------------------------------------
step 'Preflight: tag collision'
if git rev-parse "refs/tags/${new_version}" >/dev/null 2>&1; then
    err "Tag '${new_version}' already exists locally."
    exit 1
elif git ls-remote --tags origin "refs/tags/${new_version}" | grep -q .; then
    err "Tag '${new_version}' already exists on origin."
    exit 1
else
    log "Tag '${new_version}' is unused locally and on origin."
fi

# ---------------------------------------------------------------------------
# Preflight: `## Unreleased` populated in CHANGELOG.md
# ---------------------------------------------------------------------------
step 'Preflight: CHANGELOG'
if ! grep -qiE '^## \[?Unreleased\]?' CHANGELOG.md 2>/dev/null; then
    err "CHANGELOG.md is missing a '## Unreleased' section."
    err 'Add notes for this release first, e.g.:'
    err '  ## Unreleased'
    err '  - Describe the change.'
    exit 1
fi

unreleased_block="$(awk '
    BEGIN{found=0}
    tolower($0) ~ /^## \[?unreleased\]?/{found=1; next}
    found && /^## /{exit}
    found{print}
' CHANGELOG.md)"

if [ -z "$(printf '%s' "$unreleased_block" | tr -d '[:space:]-')" ]; then
    err "CHANGELOG.md has '## Unreleased' but no entries beneath it."
    err 'Populate the section before re-running.'
    exit 1
fi
log "'## Unreleased' populated."

# ---------------------------------------------------------------------------
# Preflight: lint / format / analyze / test (cheapest to slowest)
# ---------------------------------------------------------------------------
step 'Preflight: lint checks (via linterpol)'
# An unreadable manifest must fail loudly here, not silently skip every lint.
if ! jq -e '.image and (.checks | length > 0)' "$LINT_MANIFEST" >/dev/null 2>&1; then
    err '.github/lint-checks.json is missing, malformed, or has no checks.'
    exit 1
fi
lint_image="$(jq -r '.image' "$LINT_MANIFEST")"
while IFS=$'\t' read -r lint_name lint_cmd; do
    log "lint: ${lint_name}"
    # Left unquoted so it splits into the tool plus its args, and so globs like scripts/*.sh expand.
    # dartender's lint job runs it the same way.
    # shellcheck disable=SC2086
    if ! docker run --rm -v "${REPO_ROOT}:/work:ro" "$lint_image" $lint_cmd; then
        err "${lint_name} failed (via linterpol)."
        exit 1
    fi
done < <(jq -r '.checks[] | [.name, .cmd] | @tsv' "$LINT_MANIFEST")

step 'Preflight: dart format'
if ! dart format --output=none --set-exit-if-changed .; then
    err "Formatting check failed. Run 'dart format .' and commit."
    exit 1
fi

step 'Preflight: flutter --no-version-check analyze'
if ! flutter --no-version-check analyze lib test; then
    err 'Static analysis failed.'
    exit 1
fi

step 'Preflight: flutter --no-version-check test'
if ! flutter --no-version-check test; then
    err 'Test suite failed.'
    exit 1
fi

# `flutter pub publish --dry-run` runs after the prep commit instead. scripts/README.md#preflight
# has why.

# ---------------------------------------------------------------------------
# Resolve which files a release commit touches
# ---------------------------------------------------------------------------
# example/ pins the parent with `path: ../`, so its lockfile records the version and ships too.
RELEASE_FILES=(pubspec.yaml CHANGELOG.md)
if [ -d example ]; then
    RELEASE_FILES+=(example/pubspec.lock)
fi

# ---------------------------------------------------------------------------
# Plan
# ---------------------------------------------------------------------------
step 'Plan'
if [ -n "${TAG_MESSAGE}" ]; then
    tag_kind_note="(annotated, message: \"${TAG_MESSAGE}\")"
else
    tag_kind_note="(lightweight, pass -m \"MSG\" to annotate)"
fi
if [ -d example ]; then
    example_note="3. (cd example && flutter pub get)                       (resync example/pubspec.lock to ${new_version})"
else
    example_note="3. (example/ resync skipped, no example app yet)"
fi
cat <<PLAN
Will execute, in order:
  1. cider bump ${BUMP}                                    (pubspec.yaml: ${current_version} → ${new_version})
  2. cider release                                         (CHANGELOG.md: ## Unreleased → ## ${new_version} [dated today])
  ${example_note}
  4. git add  ${RELEASE_FILES[*]}
  5. git commit -m "Prep for release ${new_version}"
  6. flutter pub publish --dry-run                         (validate clean committed state; reset HEAD~1 on failure)
  7. git tag ${new_version}                                ${tag_kind_note}
  8. git push --atomic origin HEAD:${MAIN_BRANCH} ${new_version}   (triggers .github/workflows/publish.yml)

publish.yml will then build & publish ${new_version} to pub.dev via OIDC.
PLAN

if [ "$DRY_RUN" -eq 1 ]; then
    log 'Dry-run mode: preflight passed, nothing executed.'
    exit 0
fi

# ---------------------------------------------------------------------------
# Confirm
# ---------------------------------------------------------------------------
if [ "$YES" -eq 0 ]; then
    if is_tty; then
        printf '\nProceed with release? [y/N] '
        read -r reply
        case "$reply" in
            y|Y|yes|YES) ;;
            *) log 'Aborted.'; exit 0 ;;
        esac
    else
        err 'Refusing to proceed without --yes in non-interactive mode.'
        exit 2
    fi
fi

# ---------------------------------------------------------------------------
# Execute
# ---------------------------------------------------------------------------
# Auto-revert pipeline-owned files if anything fails between the `cider bump`
# step and the `flutter pub publish --dry-run` validation. The revert strategy
# depends on how far we got:
#
#   cider_phase=1, bump/release/example-resync ran, no commit yet → restore from HEAD
#   cider_phase=2, prep commit landed, dry-run pending → reset --hard HEAD~1
#   cider_phase=0, past dry-run (tag/push window) OR before bump → no auto-revert
#
# Back to 0 after the dry-run, so a failed tag or push never has its commit cleaned up for it.
cider_phase=0
# ShellCheck's flow analysis doesn't follow assignments across a quoted trap string.
# shellcheck disable=SC2154
trap '
    rc=$?
    case "$cider_phase" in
        1)
            printf "[release] failure mid-release, restoring pubspec.yaml + CHANGELOG.md (+ example/pubspec.lock) from HEAD\n" >&2
            git checkout HEAD -- pubspec.yaml CHANGELOG.md 2>/dev/null || true
            [ -f example/pubspec.lock ] && git checkout HEAD -- example/pubspec.lock 2>/dev/null || true
            ;;
        2)
            printf "[release] failure post-commit, git reset --hard HEAD~1 to drop the prep commit\n" >&2
            git reset --hard HEAD~1 2>/dev/null || true
            ;;
    esac
    exit $rc
' ERR

cider_phase=1

step "cider bump ${BUMP}"
bumped_version="$(cider bump "$BUMP")"
if [ "$bumped_version" != "$new_version" ]; then
    err "cider produced '${bumped_version}' but expected '${new_version}'."
    err 'Aborting. The trap reverts pubspec.yaml.'
    exit 1
fi

step 'cider release'
cider release

# Without the resync, the next `flutter pub get` anywhere rewrites the lockfile, and
# `flutter pub publish` fails on a modified checked-in file.
if [ -d example ]; then
    step 'flutter pub get (example/), resync example/pubspec.lock to new parent version'
    (cd example && flutter pub get)
else
    log 'No example/ directory yet, skipping example lockfile resync.'
fi

step "git add ${RELEASE_FILES[*]}"
git add "${RELEASE_FILES[@]}"

step "git commit -m \"Prep for release ${new_version}\""
git commit -m "Prep for release ${new_version}"

# Commit landed. Trap switches to "reset HEAD~1" mode for the dry-run window.
cider_phase=2

# Only after the commit can all 3 of the dry-run's checks hold. On failure the ERR trap resets
# HEAD~1, so there's no remote tag to delete.
step 'flutter pub publish --dry-run'
flutter pub publish --dry-run

# Past this point: trap no longer auto-reverts. Manual recovery if the
# tag/push fails:
#   git tag -d ${new_version} 2>/dev/null
#   git reset --hard HEAD~1
cider_phase=0

step "git tag ${new_version}"
if [ -n "${TAG_MESSAGE}" ]; then
    # Annotated tag. `git tag -m` produces an annotated object, which is what a
    # signature can attach to, so the user's `tag.gpgSign` config is honoured.
    git tag -m "${TAG_MESSAGE}" "${new_version}"
else
    # Without `-c tag.gpgSign=false`, a global `tag.gpgSign=true` turns this into a signed
    # annotated tag that opens the editor for a message.
    git -c tag.gpgSign=false tag "${new_version}"
fi

step "git push --atomic origin HEAD:${MAIN_BRANCH} ${new_version}"
git push --atomic origin "HEAD:${MAIN_BRANCH}" "${new_version}"

step "Released ${new_version}"
log "Pushed commit + tag '${new_version}' to origin/${MAIN_BRANCH}."
log "Watch .github/workflows/publish.yml for the pub.dev upload."
