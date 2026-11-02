Example-app code style, on top of the [package's](../CODESTYLE.md), which applies here too, bar the
lints `analysis_options.yaml` relaxes. Scope and facts live in [`.ai/AGENTS.md`](.ai/AGENTS.md).

## Example-specific conventions

### State management (pmvvm)

A **small** part of a view rebuilds through a scoped `ValueNotifier`, exposed as a `ValueListenable`
getter, and a `ValueListenableBuilder`. `notifyListeners()` on the `ViewModel` rebuilds the whole
`MVVM.builder` subtree, list and all, so it's for a change **many** places share, where one builder
per field would cost a subscription each.

Back the field with a private `_<thing>Notifier`, expose `<thing>Listenable` (a boolean `<thing>`
reads as a question), wrap only the dependent widget, write through a small handler, and dispose
the notifier in the view-model's `dispose()`:

```dart
// Prefer: only the switch rebuilds on toggle.
final _shouldInjectFailuresNotifier = ValueNotifier(false);
ValueListenable<bool> get shouldInjectFailuresListenable => _shouldInjectFailuresNotifier;
void onInjectFailuresToggled({required bool value}) =>
    _shouldInjectFailuresNotifier.value = value;

// Over: rebuilds the whole MVVM subtree for a one-widget change.
var _shouldInjectFailures = false;
void onInjectFailuresToggled({required bool value}) {
  _shouldInjectFailures = value;
  notifyListeners();
}
```

**A list is a `ListNotifier`** (`listenable_collections`), not a `ValueNotifier<List<T>>`, which
only notifies on a new identity and so needs a fresh `List` per change. A `ListNotifier` is already
a `ValueListenable<List<T>>` you edit in place, so the getter and the builder stay the same.

### Directory layout

Feature-first MVVM:

- `lib/main.dart`: the app shell. `lib/app/`: app-wide scopes.
- `lib/features/<feature>/`: one demo, as `<feature>_view.dart` plus `<feature>_view_model.dart`,
  with a `widgets/` folder for widgets only it uses.
- `lib/features/core/`: what demos share, from models and fake sources to `DemoScaffold`.

Cross-feature imports take the `/features/…` form, same-feature ones stay relative.

### Views and view-models

- **A view** is a `StatelessWidget` building
  `MVVM.builder(viewModel: XxxViewModel(), viewBuilder: ...)`, which hands its hint, controls and
  list to a `DemoScaffold(title: ...)` to space them. Its dartdoc names the list_smith API the demo
  exercises, and stops ([where explanations go](AGENTS.md)).
- **A view-model** is a `final class XxxViewModel extends ViewModel`, with state behind getters and
  handlers named `on<Thing>Changed` / `on<Thing>Toggled`. A boolean handler takes
  `{required bool value}`, and the view adapts:
  `onChanged: (value) => viewModel.onThingToggled(value: value)`.

### Widget composition

- **A `switch` yielding a widget is a local in `build`,** not a helper, which DCM's
  `avoid-returning-widgets` rules out anyway.
- **Let type arguments infer** where the arguments pin them: `ListSmith.async(...)`, not
  `ListSmith<DemoItem>.async(...)`.

### Icons

`platform_icons` (`PlatformIcon(PlatformIcons.x)`) first, and `platformValue(material:, cupertino:)`
only for a glyph it lacks.

### Tests

The package's [test style](../CODESTYLE.md#test-style) applies. `test/support/bdd.dart` is a
byte-identical copy of the package's Gherkin helper, which can't cross a package boundary, so edit
both. Import `test/support/support.dart` for the example's own harness on top, rather than
hand-rolling a demo open or a frame drain.
