# AGENTS.md for `example/`

Tool-agnostic brief for the runnable demo app under `example/`. Package (library) conventions live
in the parent [`AGENTS.md`](../AGENTS.md), example-specific code style in
[`CODESTYLE.md`](CODESTYLE.md). Read both before working in this subdirectory.

## Scope

- Runnable demo of `list_smith`, wired to the parent via `list_smith: { path: ../ }`.
- Not published (`publish_to: 'none'`), so no semver discipline and it may depend on whatever
  ecosystem packages it likes.
- Local only, no publish impact, but keep it building and analysing clean on the strict lint set it
  inherits via `include`. [`example.yml`](../.github/workflows/example.yml) runs `flutter analyze`
  and `dependency_validator` here.

## Architecture

Feature-first MVVM on the maintainer's platform-adaptive stack, mirroring the sibling examples
(`platform_adaptive_widgets`, `better_internet_connectivity_checker`):

- **State**: `pmvvm` (`MVVM.builder` + `ViewModel`). [`CODESTYLE.md`](CODESTYLE.md) has the
  reactivity rule and the view / view-model shape.
- **Surfaces**: `platform_adaptive_widgets` (Material on Android, Cupertino on iOS), with
  `material_ui` / `cupertino_ui` and `platform_icons`. That doubles as the showcase: list_smith's
  neutral surfaces drop into both shells unchanged.
- **Layout**: `lib/main.dart` (app shell), `lib/app/` (scopes), `lib/features/` (one folder per
  demo, plus `features/core/` for shared pieces). Full layout in [`CODESTYLE.md`](CODESTYLE.md).

The app is a hub, `features/core/views/home_view.dart`, and that file *is* the list of demos. The
README points at it rather than copying it, so adding one leaves no stale list behind.

**Adding a demo:** create `lib/features/<name>/<name>_view.dart` plus `_view_model.dart`, add a
`_DemoTile` to the hub, and add a smoke scenario to `test/widget_test.dart`. Reuse `DemoScaffold`
for the shell and the `core` fake sources.

**Where a demo's explanation goes.** The user-facing walkthrough is the screen's own `DemoIntro`,
and the hub tile's `description` is its one-line pitch. The view's dartdoc names the list_smith API
it exercises and stops there. Otherwise the same sentence ends up in three places and drifts into
three versions of itself.

## Mobile-targeted

`platformValue` and `context.platformIcon` throw on desktop and web, so run this on a mobile
device or simulator.
