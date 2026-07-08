# AGENTS.md for `list_smith`

Tool-agnostic brief for any coding agent (Copilot, Cursor, Codex, Claude Code, ...) working
in this package. Claude-Code-specific guidance lives in [CLAUDE.md](CLAUDE.md).

> **Setup-phase note.** The repository scaffolding and infra are in place, but the public API
> and internal architecture have not been designed yet. Sections below marked **TODO (design
> pass)** are deliberately left open until that work lands. Don't invent architecture to fill
> them; raise the design questions instead.

## Project goal

A developer-first Flutter package that wraps `ListView.builder` for real-world lists, doing
three jobs properly:

1. **Pagination**, for an async data source (a sync source already has all its items, so there
   is nothing to paginate).
2. **Pull-to-refresh**, for an async data source (sync behaviour is usually handled by rebuilding
   the widget when the source changes).
3. **Search**, for both sync and async sources. The async case needs a policy governing how
   already-cached items interact with new results from the async search source.

`list_smith` is a ground-up replacement for the older `smart_search_list` package: it keeps the
good ideas, removes the "ghost params" (constructor parameters that silently do nothing on one
path), fixes the known correctness bugs, and puts developer experience first. The name is a
maker/craft metaphor, a sibling in spirit to the maintainer's `minted` package.

**TODO (design pass):** the public widget(s), their parameters, the search/cache policy model,
and the `lib/src/` structure are all still to be designed. This file will gain the concrete
hard rules once they exist.

## Stack

- **Flutter >= 3.44, Dart >= 3.12** (constraints in `pubspec.yaml`; the SDK is pinned to the
  `stable` channel in `.fvmrc`). Bump the floor only when a new stable language feature is
  actually consumed, and record why in `APPENDIX.md`.
- **`flutter analyze`** for pedantic static analysis (or `dart analyze` for any pure-Dart
  subset). The lint posture in `analysis_options.yaml` is deliberately strict: `strict-casts`,
  `strict-inference`, `strict-raw-types`, plus a long `errors:` block promoting many lints to
  errors. Pedantic mode is intentional, not negotiable.
- **`flutter_test`** for widget and unit tests.
- **`dependency_validator`** guards the dependency set; `dart_dependency_validator.yaml` scopes
  it to the published surface and skips the example. It runs as a global tool
  (`dart pub global activate dependency_validator`), not a dev-dependency.
- **Container-based linters** (`shellcheck` for shell, `actionlint` for workflows, `rumdl` for
  Markdown, `ryl` for YAML) run from the [`linterpol`](https://github.com/LahaLuhem/linterpol)
  Docker image, not local installs, so only Docker (plus `jq`) is needed. The check set and
  image tag live in one manifest, [`.github/lint-checks.json`](.github/lint-checks.json);
  `repo.yml` fans a CI matrix out over it and `scripts/release.sh`'s preflight loops the same
  file, so the two can't drift. **Adding a linter is one entry in that manifest**, no workflow
  or script edit. Per-tool config lives in `.rumdl.toml` and `.yamllint.yaml`.
- **CHANGELOG and the `version:` field are owned by
  [`scripts/release.sh`](scripts/release.sh)** (via `cider`). Do not run `cider` by hand and do
  not edit `CHANGELOG.md` or `version:` directly. The `cider:` block in `pubspec.yaml` is static
  config (URLs, link templates) and is hand-editable.
- **Published to pub.dev.** `.pubignore` controls the tarball; `.editorconfig` is the source of
  truth for text-file conventions (line width 100, LF, UTF-8).

## Repo layout

```text
list_smith/
├── lib/
│   ├── list_smith.dart             Public entry; `export 'src/…'` only
│   └── src/                        Implementation (private by convention). TODO (design pass)
├── test/                           `flutter test` units + widget tests
├── example/                        Runnable Flutter demo. TODO (added in a later pass)
├── analysis_options.yaml           Strict-mode + opinionated lints
├── dart_dependency_validator.yaml  Scopes dependency_validator (excludes example/)
├── pubspec.yaml                    Deps + cider config + topics
├── .pubignore                      Files excluded from `flutter pub publish`
├── .fvmrc / .editorconfig          Local SDK pin / text-file formatting
├── .github/workflows/              CI: repo, package, example, publish, changelog, pr-conventions
├── CHANGELOG.md                    Pipeline-owned; appears on pub.dev
├── README.md                       pub.dev landing page
├── APPENDIX.md                     Design rationale (anchor-keyed)
├── CODESTYLE.md                    Package code style
└── .ai/                            This file + CLAUDE.md (symlinked to repo root)
```

The internal `lib/src/` layout is **TODO (design pass)**. `test/` will mirror it.

## Hard rules

These are the general, architecture-independent rules. Package-specific rules (the widget's
contract, the search/cache policy) are **TODO (design pass)**.

1. **The public API lives only in `lib/list_smith.dart`**, which re-exports from `lib/src/`.
   Don't make users import `package:list_smith/src/…`; the `src/` subtree is private by
   convention. Anything callers need goes through an explicit `export`.
2. **No `print()` in library code.** Diagnostic output is the caller's responsibility.
   `avoid_print` is a warning in `analysis_options.yaml`.
3. **No `dynamic` escape hatches.** `strict-casts`, `strict-inference`, and `strict-raw-types`
   are all on. If you reach for `dynamic` or an unconstrained `Object?`, stop and reconsider.
4. **Public symbols carry `///` dartdoc** explaining the *why* and the guarantee, not the
   mechanical *what*. `public_member_api_docs` is on.
5. **Semver, strictly.** Any change to a public signature, a deletion, or a behavioural change
   of a documented contract is breaking. Surface the implication before the diff lands. `cider`
   enforces the version-bump discipline.
6. **`CHANGELOG.md` is bot-owned. Do not edit any section, including `## [Unreleased]`.** Release
   headers are written by [`scripts/release.sh`](scripts/release.sh); the `## [Unreleased]`
   buffer is appended to by
   [`.github/workflows/changelog.yml`](.github/workflows/changelog.yml) from the merged PR title
   (governed by its `sem-*` label). Same prohibition on the `version:` field.

## PR conventions

Enforced by [`.github/workflows/pr-conventions.yml`](.github/workflows/pr-conventions.yml).

- **Branch name**: `<type>/#<issue>-<slug>`, `<type>` one of `feature`, `bugfix`, `chore`,
  `refactor`, `acceptance-test-issues`, `hotfix`. Example: `feature/#7-paginated-listview`.
- **Exactly one `sem-*` label per PR.** Selects the changelog category for the post-merge
  automation:

  | Label           | Cider type   | When to use                                    |
  |-----------------|--------------|------------------------------------------------|
  | `sem-add`       | `added`      | New public symbol / widget / feature           |
  | `sem-change`    | `changed`    | Behavioural or signature change                |
  | `sem-deprecate` | `deprecated` | Public symbol marked for future removal        |
  | `sem-remove`    | `removed`    | Previously-public symbol dropped               |
  | `sem-bugfix`    | `fixed`      | Defect repair, no signature change             |
  | `sem-security`  | `security`   | Security-relevant fix                          |
  | `sem-skip`      | (skip)       | Internal-only change (CI, docs, tests, ...)    |

  The PR title becomes the changelog line verbatim; phrase it as a release-note bullet.
- **PR body must not be empty**, **no merge commits in the PR range** (rebase to integrate
  `main`), **commit subjects <= 82 characters**.

Cutting a release is one command: `scripts/release.sh [patch|minor|major]`. Full mechanics,
preflight, and the pipeline-owned-files contract are in
[`scripts/README.md`](scripts/README.md).

## Style

Full guide: [`CODESTYLE.md`](CODESTYLE.md). The lint posture is deliberately strict. Top rules
to keep in working memory:

- Type-annotate every public symbol; `final` by default for fields and locals.
- Nullability is explicit (no `as T` on a `T?`). Bind generic type parameters to
  `<T extends Object>` by default.
- 100-column line width (`formatter.page_width: 100` in `analysis_options.yaml`).
- No magic numbers in `lib/` code; pull them to named `static const`s.
- Public symbols carry `///` dartdoc explaining *why* and *what guarantee*.
- Prefer Dart 3.10+ static dot shorthands (`.center`, `.all(16)`, `.start`, `.min`).
- British spelling in prose and identifiers, except names fixed by the SDK (`toJson`,
  `compareTo`, `hashCode`).

## Guidelines for any AI agent

- **Always ask before making technical choices.** When a task admits more than one reasonable
  approach (an API shape, whether a symbol is public, whether to add a dependency, a widget's
  parameter model), stop and ask: present the options with trade-offs, say which you'd pick and
  why, then wait. Small choices compound.
- **Mark recommendations with `★`.** Prefix your preferred option in every set with `★` so the
  user can scan and reply by echoing or overriding (e.g. "★ for 1-4, change 5 to B").
- **Refactor first when a change needs a better shape.** Do the enabling, behaviour-preserving
  refactor as its own step before building on top. Public-API breakage is semver-significant and
  slow to walk back once published, so surface the refactor and get sign-off before anything that
  touches the public API or adds a dependency.
- **Document new user-facing features in the README** in the same change. Rationale and
  trade-offs go in `APPENDIX.md`; the README is the user-facing entry point.
- **Read `analysis_options.yaml` before writing code.** The lint posture is far stricter than the
  Dart default; code that fails lint won't pass review.
- **Surface semver implications loudly.** If a change touches anything re-exported from
  `lib/list_smith.dart`, call out whether it's patch / minor / major before the diff lands.
- **Prefer an existing package over a custom solution.** Before hand-rolling behaviour a mature
  package already provides, look for one and wrap it. Vet the candidate first: pure Dart / Flutter
  where possible, permissive licence, currently maintained. A trivial fixed algorithm belongs in
  `lib/src/`, not a micro-dependency, so the dependency set stays honest.
- **The user manages git state; some tracked files won't show in `git status`.** The user may
  mark tracked files so their local edits are hidden from `git status` (typically
  `git update-index --skip-worktree` / `--assume-unchanged`). They are tracked, not gitignored,
  so a file you just edited can be genuinely changed on disk yet absent from `git status`. Don't
  try to re-stage or "fix" it: the user handles staging and committing. Trust the file contents
  you wrote, not `git status`, as the record of your change.
