# AGENTS.md for `list_smith`

Tool-agnostic brief for any coding agent (Copilot, Cursor, Codex, Claude Code, ...) working
in this package. Claude-Code-specific guidance lives in [CLAUDE.md](CLAUDE.md).

## Project goal

A developer-first Flutter package wrapping `ListView.builder` for real-world lists, doing three
jobs properly: **pagination** and **pull-to-refresh** for an async source, and **search** for
either kind. A sync source holds all its items, so it has nothing to page, and refreshing it means
rebuilding the widget. Async search additionally needs a policy for how cached items interact with
new results.

Built as a ground-up replacement for an older search-list package. It keeps the good ideas, fixes
the known correctness bugs, and removes the "ghost params": constructor parameters that silently do
nothing on one path. The name is a craft metaphor, a sibling in spirit to `minted`.

## Stack

- **The SDK floor lives in `pubspec.yaml`'s `environment:` block**, the channel in `.fvmrc`. Bump
  the floor only when a new stable language feature is actually consumed, and record why in
  `APPENDIX.md`.
- **`flutter analyze`** for static analysis. `analysis_options.yaml` holds the posture: strict
  language modes plus a long `errors:` block. The pedantry is intentional, not negotiable.
- **The `dart format` gate runs Flutter's Dart**, not standalone Dart stable, which runs ahead of it
  and formats differently. What CI rejects has to be what a local `dart format .` fixes. Why:
  [`APPENDIX.md#ci-format-sdk`](APPENDIX.md#ci-format-sdk).
- **`flutter_test`** for widget and unit tests.
- **`dependency_validator`** guards the dependency set, scoped by `dart_dependency_validator.yaml`
  to the published surface. It runs as a global tool, not a dev-dependency.
- **Container-based linters** run from the [`linterpol`](https://github.com/LahaLuhem/linterpol)
  Docker image, so the only local requirement is Docker plus `jq`. The check set and image tag live
  in [`lint-checks.json`](.github/lint-checks.json), which `repo.yml` fans a CI matrix out of and
  `scripts/release.sh` loops in its preflight, so the two can't drift. **Adding a linter is one
  entry in that manifest**, no workflow or script edit. Per-tool config sits in `.rumdl.toml` and
  `.yamllint.yaml`.
- **Published to pub.dev.** `.pubignore` controls the tarball, `.editorconfig` is the source of
  truth for text-file conventions (width 100, LF, UTF-8).

## Repo layout

```text
list_smith/
├── lib/
│   ├── list_smith.dart             Public entry; `export 'src/…'` only
│   └── src/                        Implementation (private by convention)
├── test/
├── example/                        Runnable Flutter demo; own pubspec, CODESTYLE and AGENTS
├── analysis_options.yaml
├── dart_dependency_validator.yaml  Scopes dependency_validator (excludes example/)
├── pubspec.yaml                    Deps + cider config + topics
├── .pubignore
├── .fvmrc / .editorconfig          Local SDK pin / text-file formatting
├── .github/workflows/
├── CHANGELOG.md                    Pipeline-owned (hard rule 7)
├── README.md                       pub.dev landing page
├── APPENDIX.md                     Design rationale (anchor-keyed)
├── CODESTYLE.md
└── .ai/                            This file + CLAUDE.md (symlinked to repo root)
```

`test/` is organised by test kind (`unit_tests/`, `widget_tests/`, `support/`), not as a mirror of
`lib/src/`.

**Nested-app lockfiles are opt-in.** The root `.gitignore` ignores `pubspec.lock` broadly, the
library following the "don't commit your own lockfile" convention. A nested app that *should* commit
one opts in with a `!pubspec.lock` negation in its **own** `.gitignore`, never by loosening the root
pattern, which would auto-commit every nested package. `example/` opts in this way: it pins the
parent via `path: ../`, and [`scripts/release.sh`](scripts/release.sh) resyncs and commits
`example/pubspec.lock` on each release so the pinned version tracks the bump. A future nested
package stays ignored until it adds its own negation.

## Hard rules

These are the general, architecture-independent rules.

1. **The public API lives only in `lib/list_smith.dart`**, which re-exports from `lib/src/`. Never
   make users import `package:list_smith/src/…`. That subtree is private by convention, and
   anything callers need goes through an explicit `export`.
2. **No `print()` in library code.** Diagnostic output is the caller's responsibility.
   `avoid_print` is a warning.
3. **No `dynamic` escape hatches.** `strict-casts`, `strict-inference` and `strict-raw-types` are
   all on. Reaching for `dynamic` or a bare `Object?` is the signal to stop and reconsider.
4. **Public symbols carry `///` dartdoc** explaining the *why* and the guarantee, not the
   mechanical *what*. A line or two, with anything longer going to `APPENDIX.md`.
   `public_member_api_docs` is on.
5. **Semver, strictly.** A public signature change, a deletion, or a behavioural change to a
   documented contract is breaking. Surface the implication before the diff lands.
6. **`repo-ok`, `package-ok`, `example-ok`, `conventions-ok`, `bench-analyzer-ok`, `bench-app-ok`
   are `main`'s required checks.** Each closes one PR workflow, and the job id *is* the context:
   renaming one, giving it a `name:`, dropping it, or path-filtering its workflow un-gates
   Dependabot automerge silently. Touch one, update the ruleset in the same pass:
   [`APPENDIX.md#dependabot-automerge`](APPENDIX.md#dependabot-automerge).
7. **`CHANGELOG.md` is bot-owned. Do not edit any section, including `## [Unreleased]`.** Release
   headers are written by [`scripts/release.sh`](scripts/release.sh), and the `## [Unreleased]`
   buffer is appended to by [`changelog.yml`](.github/workflows/changelog.yml) from the merged PR
   title, governed by its `sem-*` label. Same prohibition on the `version:` field and on running
   `cider` by hand. The `cider:` block in `pubspec.yaml` is static config, hand-editable.
8. **Workflows write out the action defaults they rely on**, even when the default is already the
   value you want. Every `github-actions` bump automerges, majors included, and an action major is
   usually a default-flip that CI stays green through, since Actions warns on an unknown input
   rather than failing: [`APPENDIX.md#dependabot-automerge`](APPENDIX.md#dependabot-automerge).

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

  The PR title becomes the changelog line verbatim, so phrase it as a release-note bullet.
- **PR body must not be empty**, **no merge commits in the PR range** (rebase to integrate `main`),
  **commit subjects <= 82 characters**.

Cutting a release is one command: `scripts/release.sh [patch|minor|major]`. Mechanics, preflight and
the pipeline-owned-files contract are in [`scripts/README.md`](scripts/README.md).

## Style

Full guide: [`CODESTYLE.md`](CODESTYLE.md), and read it before writing code. The handful that catch
people out most often:

- Bind generic type parameters to `<T extends Object>` by default, and never `as T` on a `T?`.
- 100-column width, for every text file, not just Dart.
- Static dot shorthands where the context type is known (`.center`, `.all(16)`, `.min`).
- Data-pipeline and `collection`-package methods (`groupListsBy`, `splitBetween`, `whereIndexed`)
  over hand-rolled loops for any transform or scan. Collection-`for` is for *building* a literal,
  not for deriving one collection from another.
- British spelling in prose and identifiers, except names the SDK fixes (`toJson`, `hashCode`).
- No AI-tells in prose: no em-dashes, no spliced semicolons, no filler vocabulary.

## Guidelines for any AI agent

- **Always ask before making technical choices.** Anything with more than one defensible answer
  (an API shape, public vs `lib/src/`, a new dependency, a widget's parameter model) stops and
  asks: options, trade-offs, the one you'd pick and why, then wait. Small choices compound. Mark
  your recommendation `★` so the user can reply by echoing or overriding it.
- **Refactor first when a change needs a better shape.** The enabling, behaviour-preserving
  refactor is its own step, before the feature. Get sign-off first for anything touching the public
  API or the dependency set, since both are slow to walk back once published.
- **Surface semver implications loudly.** A change to anything re-exported from
  `lib/list_smith.dart` gets called out as patch / minor / major before the diff lands.
- **Document new user-facing features in the README** in the same change. Rationale goes in
  `APPENDIX.md`.
- **Prefer an existing package over a custom solution**, vetted for pure Dart where possible, a
  permissive licence, and current maintenance. A trivial fixed algorithm belongs in `lib/src/`
  rather than a micro-dependency, so the dependency set stays honest.
- **The user manages git state, and some tracked files won't show in `git status`.** They may hide
  local edits with `git update-index --skip-worktree` / `--assume-unchanged`. Those files are
  tracked, not gitignored, so something you just edited can be genuinely changed on disk and absent
  from `git status`. Don't re-stage or "fix" it. Trust what you wrote, not `git status`.
