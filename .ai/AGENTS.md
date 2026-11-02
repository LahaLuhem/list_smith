# AGENTS.md for `list_smith`

Brief for any coding agent. Claude Code's extras are in [CLAUDE.md](CLAUDE.md).

## Project goal

A Flutter list, built lazily like `ListView.builder`, that does 3 jobs properly: **pagination** and
**pull-to-refresh** for an async source, and **search** for either kind. A sync source holds all its
items, so it has nothing to page and refreshes by rebuilding. Async search also needs a policy for
how cached items meet new results.

No "ghost params": a parameter that silently does nothing on some path is a bug.

## Stack

- **The SDK floor is in `pubspec.yaml`'s `environment:`,** the channel in `.fvmrc`. Raise the floor
  only to use a new stable language feature, and record why in `APPENDIX.md`.
- **Analyze with `dart analyze --fatal-infos --fatal-warnings .`,** as CI does, against
  [dartender's shared lints](https://github.com/LahaLuhem/dartender/blob/main/lints/lib/analysis_options.yaml).
  Their pedantry is the contract.
- **`dart format` runs Flutter's Dart,** so a local run fixes whatever CI rejects
  ([why](../APPENDIX.md#ci-format-sdk)).
- **`dependency_validator`** guards the dependencies, skipping `example/` and `benchmark/app/`,
  which are packages of their own.
- **Container linters** run from the [`linterpol`](https://github.com/LahaLuhem/linterpol) image, so
  Docker is the only local need. Its checks are in
  [`lint-checks.json`](../.github/lint-checks.json), which dartender's setup rewrites, so a linter
  only this repo needs gets a workflow of its own.
- **Published to pub.dev.** `.pubignore` shapes the tarball, `.editorconfig` the text files.

## Repo layout

- `lib/list_smith.dart` is the only public entry, re-exporting from `lib/src/`.
- `test/` splits by kind, each mirroring `lib/src/` ([test style](../CODESTYLE.md#test-style)).
- `example/` and `benchmark/app/` are packages of their own, the example with its own CODESTYLE
  and AGENTS.
- `doc/how-it-works.md` maps the parts and their seams.
- `.ai/` holds this file and CLAUDE.md, symlinked from the root
  ([why](../APPENDIX.md#ai-files-symlinked)).

**A nested app's lockfile is opt-in.** The root `.gitignore` ignores every `pubspec.lock`, and an
app that commits its own adds `!pubspec.lock` to its **own** `.gitignore`, as `example/` does. The
release run commits `example/pubspec.lock`, so its `path: ../` pin follows each bump.

## Hard rules

1. **The public API is `lib/list_smith.dart` alone,** re-exporting from `lib/src/`. Users never
   import `package:list_smith/src/…`.
2. **No `print()` in library code.** Output is the caller's call.
3. **No `dynamic` escape hatches.** The strict modes are on, and reaching for `dynamic` or a bare
   `Object?` means rethink.
4. **Public symbols carry `///` dartdoc:** the why and the guarantee, in a line or 2
   ([dartdoc](../CODESTYLE.md#dartdoc)).
5. **Semver, strictly.** A changed public signature, a deletion or a changed documented behaviour
   is breaking. Call a change to anything `lib/list_smith.dart` exports patch, minor or major before
   the diff lands.
6. **`main` requires `ci / ok` and `conventions / ok` from the `dartender` ruleset, and
   `bench-app-ok` from this repo's `Protected`.** That one is a job id in `bench-app.yml`, and a
   required check that stops reporting blocks every PR. So renaming it, naming it or path-filtering
   its workflow changes `Protected` in the same pass ([why](../APPENDIX.md#dependabot-automerge)).
7. **`CHANGELOG.md` is bot-owned, every section.** The release run writes the headers and
   Dependabot's lines, and [`changelog.yml`](../.github/workflows/changelog.yml) adds each merged
   PR's title under its `sem-*` label. Same for `version:` and running `cider`. The `cider:` block
   in `pubspec.yaml` is plain config.
8. **Workflows spell out the action defaults they rely on.** Every `github-actions` bump
   automerges, majors too, and a major often flips a default CI stays green through
   ([why](../APPENDIX.md#dependabot-automerge)).

## PR conventions

Enforced by dartender's checks, called from
[`conventions.yml`](../.github/workflows/conventions.yml):

- **Branch:** `<type>/#<issue>-<slug>`, the type one of `feature`, `bugfix`, `chore`, `refactor`.
- **Exactly 1 `sem-*` label,** picking the changelog section
  ([the set](https://github.com/LahaLuhem/dartender/blob/main/scripts/sem-labels.json)), `sem-skip`
  for internal-only work. The PR title becomes the changelog line, so write it as one.
- **A PR body, no merge commits** (rebase onto `main`), and commit subjects under dartender's
  length limit.

A release is one run, **Release** in the Actions tab. It runs CI, moves the version, the CHANGELOG
and `example/pubspec.lock` together, and pushes the tag `publish.yml` publishes
([dartender's Releasing](https://github.com/LahaLuhem/dartender#releasing)).

## Style

Read [`CODESTYLE.md`](../CODESTYLE.md) before writing code.

## Guidelines for any AI agent

- **Read <https://noslopgrenade.com/> before writing any prose,** the page itself. It's the intent
  behind [Prose & voice](../CODESTYLE.md#prose), and skipping it is how a wall of text gets written.
- **Ask before any technical choice a reasonable maintainer could make differently:** an API shape,
  public vs `lib/src/`, a dependency, a parameter model. Small ones count. Give the options, their
  costs and your `★` pick, then wait. A single-answer fix (a typo, a lint, a bug with one patch)
  just gets done.
- **A public API's shape gets an explicit OK,** plan or no plan: signatures, types, and how a
  failure reaches the caller, each with its alternatives. A decision-table row with one answer, or
  credited to an earlier issue, isn't confirmed.
- **A report's "expected behaviour" is one user's case, not the spec.** Design what's best for the
  package, and keep that case reachable through config where it's legitimate.
- **Refactor first when a change wants a better shape,** as its own behaviour-preserving step.
  Public API and dependency changes get sign-off first, since both are slow to walk back.
- **A new user-facing feature goes in the README** in the same change, its rationale in
  `APPENDIX.md`.
- **Prefer an existing package** to custom code: pure Dart where possible, permissive licence,
  maintained.
- **Some tracked files won't show in `git status`.** The user may hide local edits with
  `--skip-worktree` or `--assume-unchanged`, so trust what you wrote and don't re-stage or "fix" it.
