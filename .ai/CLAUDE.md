# CLAUDE.md for `list_smith`

Claude Code's extras. Read [AGENTS.md](AGENTS.md) and [`CODESTYLE.md`](../CODESTYLE.md) first, and
[`doc/how-it-works.md`](../doc/how-it-works.md) before changing the async engine. Rationale lives in
[`APPENDIX.md`](../APPENDIX.md).

## Communication

- **Concise.** No recap of what you just did: the diff speaks. Explain the *why* when recommending.
- Reference code as `file.dart:42`, linked where you can.
- The user is technical and direct.

## Tool preferences

- **Read / Edit / Grep / Glob** over `cat` / `sed` / `grep` / `find`. Bash only for `flutter`,
  `dart` and `git`, called plain, since the user's shell routes them to the `.fvmrc` channel.
- **Clear lints with `dart fix --apply` first,** then hand-fix the rest, then `dart format`, per
  package: the root, `example/` and `benchmark/app/`. DCM findings are always by hand.
- **Infos from `ci.yml`'s `ignored-lints` are expected locally,** since only CI drops them.
- **The Agent tool** for wide searches or big output, not quick lookups.

## Scope, and when to plan first

| Touching                                         | Blast radius                         | Plan first?                      |
|--------------------------------------------------|--------------------------------------|----------------------------------|
| `lib/list_smith.dart`, or anything it re-exports | pub.dev. Flag patch / minor / major  | yes, even an addition            |
| `lib/src/`                                       | private while the re-exports hold    | no, for one file and one concern |
| `test/`                                          | local                                | no                               |
| `pubspec.yaml` dependencies                      | every user's dependency tree         | yes                              |
| An override of the shared lints                  | every file                           | yes, with its reason in APPENDIX |

## Auto-memory conventions for this project

- **`project`**: scope and constraints the user states, with absolute dates.
- **`feedback`**: corrections and validated non-obvious choices, with **Why** and **How to apply**.
- **`reference`**: external pointers, like the pub.dev page or a Flutter issue.
- **Never** file paths, lint lists or the API surface, which the repo already holds. Check that a
  memory's file or symbol still exists before acting on it.

## Commit / PR etiquette

- **Never commit or push unless asked,** least of all to `main` or a semver tag. Leave the changes
  in the tree and suggest a message: a short imperative subject, in the existing style.
- **Never `--amend`, `--no-verify` or `git add -A`** unless asked. Stage named paths.

## Forbidden / confirm-first actions

- **Never publish** (`flutter pub publish`, `dart pub publish`) **or push a semver tag** unasked. A
  tag publishes over OIDC with no confirmation, and pub.dev never unpublishes: a version can only be
  retracted within 7 days. Releases go through the **Release** run, which you point at, never start.
- **Never run `cider` or touch `CHANGELOG.md` or `version:`** ([hard rule 7](AGENTS.md#hard-rules)).
- **Never edit `pubspec.lock`,** which is `pub get`'s output.
- **Ask first** before deleting under `.fvm/` or `.dart_tool/`, and before destructive git
  (`reset --hard`, `push --force`, `branch -D`, `clean -fd`).

## Definition of done

- Every check `ci / ok` waits on passes on your tree: the `needs:` of `ok` in
  [dartender's `ci.yml`](https://github.com/LahaLuhem/dartender/blob/main/.github/workflows/ci.yml),
  with this repo's inputs from [`ci.yml`](../.github/workflows/ci.yml), plus
  [`bench-app.yml`](../.github/workflows/bench-app.yml).
- `dcm analyze` clean, or its rules applied by hand where the CLI is missing
  ([DCM rules](../CODESTYLE.md#dcm-rules)), since CI runs no DCM.
- `flutter pub publish --dry-run` clean for a publish-relevant change, bar its uncommitted-files
  warning.
- **Say what you didn't verify.**
