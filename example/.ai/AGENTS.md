# AGENTS.md for `example/`

Tool-agnostic brief for the runnable demo app under `example/`. Package (library) conventions live
in the parent [`AGENTS.md`](../AGENTS.md); example-specific code style lives in
[`CODESTYLE.md`](CODESTYLE.md). Read both before working in this subdirectory.

## Scope

- Runnable demo of `list_smith`, wired to the parent package via `list_smith: { path: ../ }`.
- Not published to pub.dev (`publish_to: 'none'` in `pubspec.yaml`). No semver discipline; it may
  freely depend on Flutter and ecosystem packages.
- Local only, no publish impact. Keep it building and analysing clean on the strict lint set (the
  example inherits the package's `analysis_options.yaml` via `include`). The
  [`example.yml`](../.github/workflows/example.yml) workflow runs `flutter analyze` and
  `dependency_validator` here.

> **TODO (example build-out pass).** The package's public API is still being designed, so this is
> currently a placeholder app that only exercises the temporary API to keep the dependency honest.
> Once the list widgets land, this becomes a real pagination / pull-to-refresh / search showcase,
> and the structure plus state-management conventions get documented here and in `CODESTYLE.md`.
> The sibling `platform_adaptive_widgets` example is one worked reference (MVVM with a per-feature
> layout), but don't adopt an approach here without a decision.
