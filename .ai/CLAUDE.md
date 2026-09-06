# CLAUDE.md for `list_smith`

Claude-Code-specific guidance. Project facts, stack, hard rules and AI-agent guidelines live in
[AGENTS.md](AGENTS.md), the code-style guide in [`CODESTYLE.md`](CODESTYLE.md), design rationale in
[`APPENDIX.md`](APPENDIX.md). Read AGENTS.md and CODESTYLE.md first.

## Role & context

You're assisting with **list_smith**, whose scope [AGENTS.md](AGENTS.md) describes. Treat the user
as technical and direct.

It is live on pub.dev, so a change is visible to every downstream user the moment it ships, and
breakage is expensive to walk back: a retracted version stays reserved for 7 days, and a tag push
publishes automatically.

## Communication

- **Concise.** No "here's what I just did" recap. The diff speaks.
- **Explain the *why*** when recommending. The *what* is in the diff.
- Reference code as `file.dart:42` (markdown links where you can).
- Flag breaking-API or lint-violation implications loudly and early.

## Technical choices, always ask first

- **Never silently pick between reasonable alternatives.** Stop and ask: the options with their
  trade-offs, the one you'd pick and why, then wait. Mark your pick `★` so the user can reply by
  echoing or overriding it.
- **"Small" choices count.** The bar isn't "is this architecturally significant", it's "could a
  reasonable maintainer disagree with my pick". If yes, ask.
- **Exception:** obvious single-answer fixes (a typo, a clear bug with one correct patch, a lint
  error). Just do them.

## Tool preferences

- **Read / Edit / Grep / Glob** over `cat` / `sed` / `grep` / `find`. Always.
- **Bash** only for what has no dedicated tool: `flutter`, `dart`, `git`. Invoke plain `flutter` /
  `dart`, which the user's shell aliases to whatever serves the `.fvmrc`-pinned channel, never the
  toolchain manager directly.
- **Lint with `flutter analyze`.** The lints promoted to `error:` are the contract, not
  suggestions.
- **Clear lints with `dart fix --apply` first**, then hand-fix what has no automated fix, then
  `dart format`. Never hand-edit a lint the tool would fix. Run it per package, so repo root and
  `example/`. DCM findings need hand-fixing, `dart fix` doesn't touch them.
- **Agent tool** for wide or open-ended searches, or to keep large output out of context. Not for
  trivial lookups.

## Scope, and when to plan first

| Touching | Blast radius | Plan first? |
|---|---|---|
| `lib/list_smith.dart`, or anything re-exported | pub.dev-visible. Flag patch / minor / major | yes, even for an addition |
| `lib/src/` | private. Refactor freely while the re-exports hold | no, for one file and one concern |
| `test/` | local | no |
| `pubspec.yaml` dependencies | every downstream user's transitive closure | yes |
| `analysis_options.yaml` | every file. Surface the posture change loudly | yes, with a written reason in `APPENDIX.md` |

The release flow (`CHANGELOG.md`, `version:`) is not on this list because it is pipeline-owned. See
*Forbidden* below, and don't plan or make a CHANGELOG edit or a version bump at all.

## Auto-memory conventions for this project

- **`project`**: scope and constraints the user states aloud ("ship v0.1 with just the async
  path"). Convert relative dates to absolute.
- **`feedback`**: corrections and validated non-obvious choices, with **Why** and **How to apply**.
- **`reference`**: external pointers (the pub.dev page, the context7 project, a related Flutter
  issue), not internal code paths.
- **Don't save** Dart file paths, lint-rule lists, or the API surface. All derivable from the repo.
  Verify a memory's named file or symbol still exists before acting on it.

## Commit / PR etiquette

- **Never commit without being asked.** Not after a fix, not as a "checkpoint". Leave the changes
  in the working tree, suggest a message, let the user land it.
- **Never push without being asked.** Least of all to `main`, and least of all a semver tag, which
  triggers the pub.dev publish.
- **Never `--amend`** unless asked. Make a new commit.
- **Never `--no-verify`**, **never `git add -A`**. Stage named paths.
- When asked for a commit: show `git status` and `git diff`, draft the message, wait. Match the
  existing style, a short imperative subject.

## Forbidden / confirm-first actions

- **Never** `flutter pub publish` or `dart pub publish`. Publishing is effectively one-way, since
  pub.dev reserves the version for 7 days after a retraction. Releases go through the tag-triggered
  [`publish.yml`](.github/workflows/publish.yml).
- **Never** push a semver tag without being told to. The tag authenticates to pub.dev over OIDC
  with no confirmation step on their side.
- **Never** run `cider` or hand-edit `CHANGELOG.md` / `version:` (hard rule 7 has the why). If the
  user wants a release, suggest `scripts/release.sh <bump>` but don't run it: it pushes to
  `origin/main` and triggers the publish.
- **Never** edit `pubspec.lock`, which is `flutter pub get`'s output.
- **Never** delete anything under `.fvm/` or `.dart_tool/` without approval.
- **Destructive git** (`reset --hard`, `push --force`, `branch -D`, `clean -fd`): ask first.

## Definition of done

- `flutter analyze` clean. Non-negotiable.
- `dcm analyze` clean where the CLI is there. Otherwise apply the DCM rules by hand, since
  `flutter analyze` surfaces none of them. See [`CODESTYLE.md`](CODESTYLE.md#dcm-rules).
- `dart format --output=none --set-exit-if-changed .` clean.
- `flutter test` green.
- Lint clean via the linterpol image for whatever changed, per
  [`lint-checks.json`](.github/lint-checks.json).
- `flutter pub publish --dry-run` clean if the change is publish-relevant. Never bump the version or
  edit the CHANGELOG to make it pass, `scripts/release.sh` owns those.
- Public API additions carry `///` dartdoc and show up in the README.
- **Explicitly call out what you did NOT verify.**
