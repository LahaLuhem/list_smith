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

## Architecture

Feature-first MVVM on the maintainer's platform-adaptive stack, mirroring the sibling examples
(`platform_adaptive_widgets`, `better_internet_connectivity_checker`):

- **State**: `pmvvm` (`MVVM.builder` + `ViewModel`). See [`CODESTYLE.md`](CODESTYLE.md) for the
  reactivity rule (scoped `ValueNotifier` vs `notifyListeners`) and the view / view-model shape.
- **Surfaces**: `platform_adaptive_widgets` (Material on Android, Cupertino on iOS), with
  `material_ui` / `cupertino_ui` for the design libraries and `platform_icons` for icons. This
  doubles as a showcase: list_smith's neutral surfaces drop into both shells unchanged.
- **Layout**: `lib/main.dart` (app shell) + `lib/app/` (scopes) + `lib/features/` (one folder per
  demo, plus `features/core/` for shared pieces). Full layout in [`CODESTYLE.md`](CODESTYLE.md).

The app is a hub (`features/core/views/home_view.dart`) linking to each demo: **Basic feed**
(`ListSmith.async` + pull-to-refresh, neutral defaults), **Custom surfaces** (every surface
overridden, plus an inject-failure toggle), and **Playground** (live config knobs).

**Adding a demo:** create `lib/features/<name>/<name>_view.dart` + `_view_model.dart`, add a
`_DemoTile` to the home hub, and a smoke scenario to `test/widget_test.dart`. Reuse `DemoScaffold`
for the shell and the `core` fake sources.

## Mobile-targeted

The stack is Android/iOS only: `platformValue` (and `context.platformIcon`) throw on desktop/web.
Run on a mobile device or simulator.
