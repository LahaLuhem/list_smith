# AGENTS.md for `example/`

Brief for the demo app. The package's rules are in the root [`AGENTS.md`](../../AGENTS.md), the
example's code style in [`CODESTYLE.md`](../CODESTYLE.md). Read both.

## Scope

- A runnable demo, depending on the package by `path: ../`.
- Unpublished, so no semver, and it may depend on any package it likes.
- It builds and analyses clean under the lints it inherits, which dartender's CI, called from
  [`ci.yml`](../../.github/workflows/ci.yml), checks along with the package.

## Architecture

Feature-first MVVM on the maintainer's platform-adaptive stack:

- **State:** `pmvvm` (`MVVM.builder` + `ViewModel`), shaped as [`CODESTYLE.md`](../CODESTYLE.md)
  says.
- **Surfaces:** `platform_adaptive_widgets`, Material on Android and Cupertino on iOS, with
  `platform_icons`. It doubles as the showcase: list_smith's neutral surfaces drop into both shells
  unchanged.

The app is a hub, and `features/core/views/home_view.dart` *is* the list of demos, which the README
points at rather than copying.

**Adding a demo:** `lib/features/<name>/` with its view and view-model, a `_DemoTile` on the hub,
and a scenario in `test/widget_test.dart` for what the demo adds itself. Reuse `DemoScaffold`,
`DemoItemTile` and the `core` fake sources and mixins.

**Where a demo's explanation goes:** each knob explains itself in a one-line `subtitle`, and a
screen adds a hint line only for a gesture nothing else shows. The hub tile's `description` is its
one-line pitch, and the view's dartdoc names the list_smith API it exercises. Anything more lands in
3 places and drifts, and a preamble pushes the list off a phone's screen.

## Mobile-targeted

`platformValue` throws anywhere but Android and iOS, and `PlatformIcon` throws on web, so run it on
a phone or a simulator.
