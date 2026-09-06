Example-app code style. Package style lives in [`../CODESTYLE.md`](../CODESTYLE.md), example scope
and facts in [`.ai/AGENTS.md`](.ai/AGENTS.md).

The example inherits the package's strict lint set via `include: ../analysis_options.yaml`,
relaxing only `public_member_api_docs`. Everything in the package guide applies here too.

## Example-specific conventions

### State management (pmvvm)

Use a scoped `ValueNotifier` (exposed as a `ValueListenable` getter) + `ValueListenableBuilder` for
state that rebuilds a **small** part of a view. Only call `notifyListeners()` on the `ViewModel`
(which rebuilds the whole `MVVM.builder` subtree) when **many** sites must update together.

- **Why:** `notifyListeners()` rebuilds everything under the view's `Consumer`, so a control that
  only changes its own widget shouldn't use it, `ListSmith` list and all. The flip side is that one
  `ValueListenableBuilder` per field is O(n) subscriptions, so a single change touching many places
  is better off with one `notifyListeners()`.
- **How to apply:** back the field with a private `ValueNotifier<T>`, expose a `ValueListenable<T>`
  getter, wrap only the dependent widget in a `ValueListenableBuilder`, write through a small setter
  assigning `.value`, and dispose the notifier in the VM's `dispose()`.

  ```dart
  // Prefer: only the switch rebuilds on toggle.
  final _injectFailures = ValueNotifier(false);
  ValueListenable<bool> get injectFailures => _injectFailures;
  void setInjectFailures({required bool value}) => _injectFailures.value = value;

  // Over: rebuilds the whole MVVM subtree for a one-widget change.
  var _injectFailures = false;
  void setInjectFailures({required bool value}) {
    _injectFailures = value;
    notifyListeners();
  }
  ```

- **List-typed reactive state uses `ListNotifier` (from `listenable_collections`), not a
  `ValueNotifier<List<T>>`.** A `ValueNotifier` only notifies on identity change, so a growing list
  forces a fresh `List` on every mutation (`value = [x, ...value]`) purely to fire the
  notification. `ListNotifier<T>` is itself a `ValueListenable<List<T>>` you mutate in place, one
  notification per change, so the getter and builder are unchanged while the writes read as
  ordinary list ops. The Observer demo's event log uses it.

### Directory layout

Feature-first MVVM, mirroring the sibling examples:

- `lib/main.dart`: the app shell (`PlatformApp` + the app-wide theme-mode notifier).
- `lib/app/`: app-wide scopes (e.g. `theme_scope.dart`).
- `lib/features/<feature>/`: one folder per demo, holding `<feature>_view.dart` +
  `<feature>_view_model.dart`, plus a `widgets/` subfolder for widgets used only by that feature.
- `lib/features/core/`: shared building blocks: `data/models/` (immutable models), `data/constants/`
  (theme), `repos/` (fake data sources), `views/` (the home hub), `widgets/` (`DemoScaffold`,
  `DemoIntro`).

One primary public class per file, file name matching, as in the package. Cross-feature imports
take the package-root form (`/features/...`), same-feature ones stay relative.

### Views and view-models

- A view is a `StatelessWidget` whose `build` returns
  `MVVM.builder(viewModel: XxxViewModel(), viewBuilder: ...)`, wrapping its body in a
  `DemoScaffold(title: ...)`. Its dartdoc names the list_smith API the demo exercises and stops
  there, since the walkthrough belongs to the screen's `DemoIntro`.
- A view-model is a `final class XxxViewModel extends ViewModel`. Expose state through getters and
  name mutation handlers `on<Thing>Changed` / `on<Thing>Toggled`. A boolean handler takes a named
  `{required bool value}`, per `avoid_positional_boolean_parameters`, and the view adapts it:
  `onChanged: (value) => viewModel.onThingToggled(value: value)`.

### Widget composition

- **No `Widget _buildX()` helpers**, per DCM's `avoid-returning-widgets`. Extract a private
  `StatelessWidget`. A `switch` yielding a widget goes in a local inside `build`, not a helper.
- Let generic type arguments infer when the arguments pin them: `ListSmith.async(...)`, not
  `ListSmith<DemoItem>.async(...)`.

### Icons

Prefer `platform_icons` (`PlatformIcon(PlatformIcons.x)`), reaching for
`platformValue(material:, cupertino:)` only when the glyph isn't in the library. `platformValue`
throws on desktop and web, which is why the example targets Android and iOS.

### Tests

Widget tests use the local Gherkin helper in `test/support/bdd.dart` (`feature`,
`scenarioWidgets`, `scenarioOutlineWidgets`) with `checks` for assertions. It has no finder API, so
bridge a `flutter_test` finder by evaluating it:
`check(find.text('...').evaluate()).length.equals(1)`. The neutral spinner animates forever, so
drive fixed `pump()`s and never `pumpAndSettle`. That file is a byte-identical copy of the
package's, since a local helper can't cross a package boundary, so edit both. Rationale in the
package [`CODESTYLE.md`](../CODESTYLE.md#test-style).
