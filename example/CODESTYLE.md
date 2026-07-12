Example-app code style. Package (library) style lives in [`../CODESTYLE.md`](../CODESTYLE.md);
example scope and facts live in [`.ai/AGENTS.md`](.ai/AGENTS.md).

The example inherits the package's strict lint set (via `include: ../analysis_options.yaml`),
relaxing only `public_member_api_docs`. So everything in the package style guide applies here:
explicit types, `final` by default, static dot shorthands, the collection-`for` and pipeline
idioms, `Row`/`Column` `spacing:` over interleaved gaps, and so on.

## Example-specific conventions

### State management (pmvvm)

Use a scoped `ValueNotifier` (exposed as a `ValueListenable` getter) + `ValueListenableBuilder` for
state that rebuilds a **small** part of a view. Only call `notifyListeners()` on the `ViewModel`
(which rebuilds the whole `MVVM.builder` subtree) when **many** sites must update together.

- **Why:** `notifyListeners()` rebuilds everything under the view's `Consumer`; if a control only
  changes its own widget, rebuilding the whole screen (a `ListSmith` list included) is wasteful. The
  flip side: one `ValueListenableBuilder` per field is O(n) subscriptions, so when a single change
  touches many places at once, one `notifyListeners()` beats many builders.
- **How to apply:** back the field with a private `ValueNotifier<T>`, expose a `ValueListenable<T>`
  getter, wrap only the dependent widget in a `ValueListenableBuilder`, write through a small setter
  that assigns `.value`, and dispose the notifier in the VM's `dispose()`.

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
  forces you to rebuild a fresh `List` on every mutation (`value = [x, ...value]`) just to fire a
  notification, which is boilerplate and easy to get wrong. `ListNotifier<T>` is itself a
  `ValueListenable<List<T>>` you mutate in place (`insert`, `removeLast`, `clear`) with a
  notification per change, so the getter and `ValueListenableBuilder` are the same while the writes
  read as ordinary list ops. The Observer demo's event log uses it.

### Directory layout

Feature-first MVVM, mirroring the sibling examples:

- `lib/main.dart`: the app shell (`PlatformApp` + the app-wide theme-mode notifier).
- `lib/app/`: app-wide scopes (e.g. `theme_scope.dart`).
- `lib/features/<feature>/`: one folder per demo, holding `<feature>_view.dart` +
  `<feature>_view_model.dart`, plus a `widgets/` subfolder for widgets used only by that feature.
- `lib/features/core/`: shared building blocks: `data/models/` (immutable models), `data/constants/`
  (theme), `repos/` (fake data sources), `views/` (the home hub), `widgets/` (`DemoScaffold`,
  `DemoIntro`).

One primary public class per file, file name matching (as in the package). Cross-feature imports use
the package-root form (`/features/...`); same-feature imports stay relative.

### Views and view-models

- A view is a `StatelessWidget` whose `build` returns
  `MVVM.builder(viewModel: XxxViewModel(), viewBuilder: ...)`, wrapping its body in a
  `DemoScaffold(title: ...)`.
- A view-model is a `final class XxxViewModel extends ViewModel`. Expose state through getters; name
  mutation handlers `on<Thing>Changed` / `on<Thing>Toggled`. A boolean handler takes a named
  `{required bool value}` (per `avoid_positional_boolean_parameters`); the view adapts it:
  `onChanged: (value) => viewModel.onThingToggled(value: value)`.

### Widget composition

- **No `Widget _buildX()` helpers** (DCM `avoid-returning-widgets`): extract a private
  `StatelessWidget` instead. A `switch` that yields a widget goes in a local inside `build`, not a
  helper method.
- Let generic type arguments infer when the arguments pin them: `ListSmith.async(...)`, not
  `ListSmith<DemoItem>.async(...)`.

### Icons

Prefer `platform_icons` (`PlatformIcon(PlatformIcons.x)`); reach for
`platformValue(material:, cupertino:)` only when the glyph isn't in the library. The stack is
mobile-adaptive: `platformValue` throws on desktop/web, so the example targets Android and iOS.

### Tests

Widget tests use the local Gherkin helper (`test/support/bdd.dart`: `feature`, `scenarioWidgets`,
`scenarioOutlineWidgets`) with `checks` for assertions. `checks` has no finder API, so bridge a
`flutter_test` finder by evaluating it: `check(find.text('...').evaluate()).length.equals(1)`. The
neutral spinner animates forever, so drive fixed `pump()`s, never `pumpAndSettle`. Rationale in the
package [`CODESTYLE.md`](../CODESTYLE.md#test-style).
