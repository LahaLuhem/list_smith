# CLAUDE.md for `list_smith`

Claude-Code-specific guidance. Project facts, stack, hard rules, and AI-agent guidelines live in
[AGENTS.md](AGENTS.md); the full code-style guide lives in [`CODESTYLE.md`](CODESTYLE.md); design
rationale lives in [`APPENDIX.md`](APPENDIX.md). Read AGENTS.md and CODESTYLE.md first.

> **Setup-phase note.** The infra is in place; the public API and internal architecture are not
> designed yet. Where a rule below depends on architecture that doesn't exist, it's marked
> **TODO (design pass)**. Surface design questions rather than guessing.

## Role & context

You're assisting with **list_smith**: a developer-first Flutter package that wraps
`ListView.builder` to handle async pagination, pull-to-refresh, and sync-or-async search. It's a
ground-up replacement for the older `smart_search_list` package. Treat the user as technical and
direct. The package is intended for pub.dev, so once published, changes are visible to every
downstream user; breakage is expensive and slow to walk back (unpublished versions stay reserved
for 7 days, and a tag push triggers an automated publish).

## Communication

- **Concise.** No "here's what I just did" recap; the diff speaks.
- **Explain the *why*** when recommending. The *what* is in the diff.
- Reference code as `file.dart:42` (markdown links where you can).
- Flag breaking-API or lint-violation implications loudly and early.

## Technical choices, always ask first

- **Do not silently pick between reasonable alternatives.** Whenever a task admits more than one
  defensible approach (a widget's parameter model, whether a helper is public or stays under
  `lib/src/`, the search/cache policy shape, whether to add a dependency), **stop and ask.** List
  the options with trade-offs, say which you'd pick and why, then wait.
- **"Small" choices count.** The bar isn't "is this architecturally significant"; it's "could a
  reasonable maintainer disagree with my pick". If yes, ask.
- **Mark your recommendation with `★`** so the user can scan and reply by echoing or overriding.
- **Exception:** obvious single-answer fixes (typo, clear bug with one correct patch, lint
  error). Just do them.

## Tool preferences

- **Read / Edit / Grep / Glob** over `cat` / `sed` / `grep` / `find`. Always.
- **Bash** only for things without a dedicated tool: `flutter`, `dart`, `git`. The user's shell
  aliases `flutter` / `dart` to whatever toolchain manager serves the `.fvmrc`-pinned channel;
  invoke plain `flutter` / `dart`, not the manager directly.
- **Lint with `flutter analyze`** (or `dart analyze` for a pure-Dart subset). The project promotes
  many lints to `error:` in `analysis_options.yaml`; those are the contract, not suggestions.
- **Clear lints with `dart fix --apply` first**, then hand-fix only what has no automated fix,
  then `dart format`. Don't hand-edit a lint the tool would fix for you. Run it per package (repo
  root and `example/`). DCM (`dart_code_metrics`) findings aren't fixed by `dart fix`; hand-fix
  those.
- **Agent tool** for wide or open-ended searches, or to keep large output out of context. Not for
  trivial lookups.

## Scope awareness

- **Public-API edits** (anything in `lib/list_smith.dart`, or re-exported from it) are
  pub.dev-visible. Flag whether the change is patch / minor / major under semver before it lands.
- **`lib/src/` edits** are private; refactor freely as long as the public re-exports stay stable.
- **`test/` edits** are local, no publish impact.
- **`analysis_options.yaml` edits** affect every file; surface lint-posture changes loudly and add
  a written reason in `APPENDIX.md`.
- **`pubspec.yaml` dependency edits** add to every downstream user's transitive closure; treat as
  public-API-class.

## Auto-memory conventions for this project

- **`project` memories**: scope/constraints the user states aloud (e.g. "ship v0.1 with just the
  async path", "raising the Flutter floor on date Y"). Convert relative dates to absolute.
- **`feedback` memories**: corrections and validated non-obvious choices. Include **Why** and
  **How to apply**.
- **`reference` memories**: external pointers (the pub.dev page, the context7 project, the old
  `smart_search_list` package, related Flutter issues). Not internal code paths, which live in
  AGENTS.md or are derivable from the repo.
- **Do NOT save** Dart file paths, lint-rule lists, or the API surface; all derivable from the
  repo or APPENDIX.md. Before acting on a memory, verify the named file / symbol still exists.

## Plan before editing when

- The change touches the public API (anything re-exported from `lib/list_smith.dart`); even adding
  a new widget or method affects semver and downstream users.
- You're adding or removing a dependency in `pubspec.yaml`.
- You're changing `analysis_options.yaml`; lint posture is project-wide and any toggle deserves a
  written reason in APPENDIX.
- **TODO (design pass):** once the widget pattern exists, adding to it will likely warrant a plan
  step too. Record that here when it lands.

For a single-file, single-concern change inside `lib/src/`, just do it.

The release flow (`CHANGELOG.md`, `version:` in `pubspec.yaml`) is **not** in this list: both are
pipeline-owned (see *Forbidden* below). Don't plan or make a CHANGELOG edit or a version bump.

## Commit / PR etiquette

- **Never commit without being asked.** Not after a fix, not as a "checkpoint". Leave changes in
  the working tree; suggest a message, let the user land it.
- **Never push without being asked.** Especially not to `main`, and especially not a semver tag
  (which triggers the pub.dev publish via `.github/workflows/publish.yml`).
- **Never `--amend`** unless asked; create a new commit instead.
- **Never `--no-verify`**, **never `git add -A`**; stage named paths.
- When asked for a commit: show `git status` + `git diff`, draft the message, wait for approval.
  Match existing commit style (short imperative subject).

## Forbidden / confirm-first actions

- **Never** `flutter pub publish` or `dart pub publish`. Publishing is effectively one-way
  (pub.dev reserves the version for 7 days after retraction). Releases go through the
  tag-triggered [`.github/workflows/publish.yml`](.github/workflows/publish.yml); pushing a
  matching `X.Y.Z` tag is the trigger and is itself a confirm-first action.
- **Never** push a semver tag without explicit instruction. The tag authenticates to pub.dev via
  OIDC with no manual confirmation step on the pub.dev side.
- **Never** run `cider` commands or manually edit `CHANGELOG.md` (including `## [Unreleased]`) or
  the `version:` field. Those are owned by `scripts/release.sh` and the changelog automation;
  manual edits get reordered or overwritten. If the user wants a release, suggest
  `scripts/release.sh <bump>`; don't run it (it pushes to `origin/main` and triggers publish). The
  `cider:` block in `pubspec.yaml` is static config, hand-editable.
- **Never** edit `pubspec.lock` directly (it's `flutter pub get`'s output).
- **Never** delete files under `.fvm/`, `.dart_tool/`, or `pubspec.lock` without approval.
- **Destructive git** (`reset --hard`, `push --force`, `branch -D`, `clean -fd`): ask first.

## Definition of done

- `flutter analyze` clean (the `errors:` block promotes many lints to errors; non-negotiable).
- `dcm analyze` clean where the DCM CLI is available; otherwise apply the DCM rules by hand
  (`no-empty-block`, `newline-before-return`, `prefer-commenting-analyzer-ignores`,
  `avoid-returning-widgets`). `flutter analyze` does not surface these. See
  [`CODESTYLE.md`](CODESTYLE.md).
- `dart format --output=none --set-exit-if-changed .` clean (100-column width matches
  `analysis_options.yaml`).
- `flutter test` green (where tests exist).
- Lint clean via the linterpol image for whatever changed: `shellcheck` (shell), `actionlint`
  (workflows), `rumdl` (Markdown), `ryl` (YAML). The check set and per-tool config live in
  [`.github/lint-checks.json`](.github/lint-checks.json), `.rumdl.toml`, and `.yamllint.yaml`.
- `flutter pub publish --dry-run` clean if the change is publish-relevant. Do not bump the version
  or edit the CHANGELOG to make it pass; `scripts/release.sh` owns those.
- Public API additions carry `///` dartdoc and are reflected in the README.
- Explicitly call out what you did NOT verify.
- **TODO (design pass):** add the package-specific done criteria (the widget contract, any
  behavioural guards) once the architecture is designed.
