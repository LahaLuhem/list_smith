Package code style. Project facts (goal, stack, repo layout, hard rules) live in
[`.ai/AGENTS.md`](.ai/AGENTS.md); design rationale lives in [`APPENDIX.md`](APPENDIX.md).

The lint posture is deliberately strict (see [`analysis_options.yaml`](analysis_options.yaml);
the `errors:` block promotes many lints to errors). The house style values explicit types, no
ambient mutability, and small focused classes.

Each heading below carries an explicit `<a id="…">` anchor. Link by anchor, not by heading text,
so renames don't break callers.

<!-- TOC start -->

- [Type safety & nullability](#type-safety)
- [Naming](#naming)
- [Directory layout](#directory-layout)
- [Imports](#imports)
- [Formatting](#formatting)
- [Constants & magic numbers](#constants)
- [Class structure](#class-structure)
- [Package-specific patterns](#package-patterns)
- [Idioms](#idioms)
- [Comments & dartdoc](#dartdoc)
- [DCM rules (applied by hand)](#dcm-rules)
- [Test style](#test-style)
- [Documentation conventions (Markdown)](#documentation-conventions)
- [Shell scripts](#shell-scripts)

<!-- TOC end -->

<a id="type-safety"></a>
## Type safety & nullability

- **Type-annotate every public symbol.** Inference is fine on locals
  (`omit_local_variable_types` is on); public surfaces are not the place to rely on it.
- **`final` by default for fields and locals.** `prefer_final_fields`, `prefer_final_locals`,
  `prefer_final_in_for_each` are all on. Parameters are not required to be `final`, consistent
  with `avoid_final_parameters`; `parameter_assignments` forbids the actual bad behaviour
  (mutating a parameter inside the body).
- **Nullability is explicit.** Use `T?` everywhere a value can be missing.
  `cast_nullable_to_non_nullable` is on, so `as T` on a `T?` fails lint. Never reach for a cast
  to launder nullability away.
- **Constrain generic type parameters to `<T extends Object>` by default.** Unbounded `<T>` lets
  `null` and `dynamic` satisfy `T`, the same failure modes the explicit-nullability rule and the
  [`dynamic`-escape-hatch ban](.ai/AGENTS.md#hard-rules) guard against elsewhere. Bind to `Object`
  so the type system enforces "some real value, not null"; if a particular call site needs `null`,
  it spells it as `T?` and the binding stays put.

  ```dart
  // Prefer:
  class PagedList<T extends Object> extends StatefulWidget { … }

  // Over:
  class PagedList<T> extends StatefulWidget { … }
  ```

  Exception: when `T` flows directly into an external API that itself uses unbounded `<T>` *and*
  relies on `null` as a sentinel `T` value. Don't reach for the exception speculatively; bind by
  default, loosen only when a real call site demands it. A bounded `T` is a subtype of unbounded
  `T` in parameter positions, so wrapping a raw-`<T>` upstream widget with a
  `<T extends Object>`-bound one stays type-safe.
- **No Java ceremony.** No getter-only abstract base classes, no `AbstractFooFactory`, no
  interface-per-class. Use mixins, sealed classes, records, extension types, and enums where they
  add clarity, not weight.

The `dynamic`-escape-hatch ban and the `print()`-in-library ban are contracts, not style; they
live under [*Hard rules* in `.ai/AGENTS.md`](.ai/AGENTS.md#hard-rules).

---

<a id="naming"></a>
## Naming

- **Prefer abbreviations over initialisms for domain terms.** In code, comments, dartdocs, and log
  messages alike, expand. Widely-known protocol initialisms (HTTP, DNS, TCP, TLS) and
  platform-name initialisms (iOS, OS) stay as-is; novel project terms get spelt out. The
  general-programming initialisms below also expand: shorthand that's "obvious" to the author is
  opaque to the next reader and indistinguishable from a typo.

  | Don't write            | Write instead                                                     |
  |------------------------|-------------------------------------------------------------------|
  | `cb`                   | `callback` (or the semantic role: `onRefresh`, `onQueryChanged`)  |
  | `fn`                   | `function` / `handler` / spell out the role                       |
  | `cfg`                  | `config`                                                          |
  | `idx`                  | `index` (loop counters keep `i` / `j` per genre convention)       |
  | `tmp`                  | `temporary`, or a name describing what it holds                   |
  | `req` / `res` / `resp` | `request` / `response`                                            |
  | `ctx`                  | `context` (Flutter's `BuildContext` arg stays `context`)          |
  | `evt`                  | `event`                                                          |

  This binds *every* identifier: fields, locals, parameters, pattern bindings. The only carve-outs
  are the genre conventions: single-letter loop counters (`i`, `j`), `e` in `catch (e)`, `(a, b)`
  in symmetric comparator pairs, `x`/`y` for coordinates.
- **Local-variable names carry a concise type-suffix.** A reader without IDE inlay-hints can't see
  an inferred type; the *name* has to do that work. When a domain type exists, the suffix is the
  type name (`pageResult`, not `result`; `filteredItems`, not `filtered`). Callback parameters are
  exempt and stay single-word (`value`, `query`, `items`), because the enclosing call site already
  pins the type. Generic suffixes (`Data`, `Info`, `Result`) lose the disambiguation the rule is
  meant to provide.
- **Unused closure parameters take the discard `_`, not a real name.** Don't declare an identifier
  you don't reference; `_` makes the unused-ness immediate.

  ```dart
  // Prefer:
  builder: (_) => const SizedBox.shrink()
  builder: (_, index) => itemBuilder(index)   // two-arg builder, first unused

  // Over:
  builder: (context) => const SizedBox.shrink()   // context never referenced
  ```

  Applies in dartdoc examples too. Multiple discards in one signature are each written as `_`.
  Doesn't apply to genre-conventional single letters (`i`, `e`) that stay their letter even when
  unused.
- **Don't rename callback params to disambiguate from a same-named outer-scope variable.** Dart's
  lexical scoping always picks the innermost binding; there's no ambiguity for the compiler, and a
  reader who knows the rule sees the intent immediately. Renaming the inner parameter signals a
  distinction that doesn't exist. The legitimate exception is when the body needs *both* the inner
  and outer same-named variable; then rename the inner and document which-is-which in the
  callback's dartdoc, not the parameter name.
- **Files mirror the primary public class name.** `PagedListView` lives in
  `paged_list_view.dart`; `PagedListController` in `paged_list_controller.dart`. `file_names` is
  enforced by the linter; one primary public class per file (private `_helper` classes may share
  it). Directory placement follows [Directory layout](#directory-layout).

---

<a id="directory-layout"></a>
## Directory layout

`lib/src/` is organised **by kind at the top level, then by feature, then by kind again within each
feature**:

- **`data/`** holds pure vocabulary, sub-grouped by feature (`data/pagination/`, `data/search/`,
  `data/refresh/`, `data/presentation/`, `data/source/`). Within a feature, files are grouped by
  kind: `models/` (classes: sealed types, immutable data, policy objects), `typedefs/` (standalone
  function-type aliases), `enums/`, `extensions/`, and `utils/` (pure functions). Sealed cases nest
  one level under the base's kind and stay `part`s of the base: `models/policies/` for the policy
  cases, `source/sources/` for the source cases.
- **`widgets/`** holds everything that is a `Widget`; the neutral default surfaces live under
  `widgets/defaults/`.
- **`utils/`** (top level) holds cross-cutting helpers tied to no single feature
  (`utils/neutral_theme.dart`, `utils/query_debouncer.dart`).

Two placement rules earn their keep:

- **A typedef with a single home type stays in that type's file**; only a standalone typedef with no
  such home gets its own file under the feature's `typedefs/`. So `RefreshBuilder` sits with
  `ListSmithRefreshState` in `refresh/models/`, while `PageFetcher` and `ItemBuilder` stand alone in
  their features' `typedefs/`.
- **A resolver is an unexported `extension` in `<feature>/extensions/`**, named
  `<thing>_resolver_extension.dart`; a pure top-level *function* resolver instead goes in
  `<feature>/utils/` (like `resolveSyncSearch`). Either way the public type stays pure data and its
  decision logic gets a widget-free, unit-testable home. Rationale in
  [`APPENDIX.md`](APPENDIX.md#src-directory-layout).

---

<a id="imports"></a>
## Imports

**Relative within a feature, root-relative across features.** An import whose target is in the same
feature subtree uses a path relative to the importing file. One that crosses into another feature or
top-level area uses a **root-relative** path with a leading `/` (Dart resolves it from the package's
`lib/`, so `/src/data/…` is `package:list_smith/src/data/…`). The leading `/` is a deliberate visual
cue: a file's own-feature imports read as bare relatives, and its cross-feature ones stand out.

```dart
// in widgets/async_list_view.dart
import '/src/data/pagination/models/pagination_end_policy.dart'; // other feature: leading /
import '/src/utils/query_debouncer.dart';                        // other area: leading /
import 'paged_view.dart';                                        // same folder: relative
import 'refresh_binding.dart';                                   // same folder: relative
```

The split holds inside a feature too: `search/extensions/…_extension.dart` reaches its own model as
`../models/search_cache_policy.dart` (relative), never root-relative. `@docImport` follows the same
rule; `part` / `part of` are always same-feature, so always relative. The example app applies the
identical convention with `/features/…` for its cross-feature imports (see
[`example/CODESTYLE.md`](example/CODESTYLE.md)).

---

<a id="formatting"></a>
## Formatting

- **Wrap text-file content at 100 columns.** `formatter.page_width: 100` in
  `analysis_options.yaml` is authoritative for Dart; [`.editorconfig`](.editorconfig) matches it
  for Markdown and YAML. Keep them aligned if either moves. `dart format` does *not* reflow
  doc-comment prose, so a `///` block hand-wrapped narrow stays narrow forever. Default to ~95
  columns of content in `///` blocks (the leading `///` plus its space counts toward the limit)
  so a trailing word doesn't push over. Reflow opportunistically when touching a doc block; don't
  churn unrelated files to widen them.
- **Blank lines separate logical chunks within a method.** Group the guard checks, the setup, the
  main action, and the return with one blank line between groups, so a reader can scan past chunks
  they don't need.
- **Prefer expression bodies** (`prefer_expression_function_bodies`) and **single quotes**
  (`prefer_single_quotes`).

---

<a id="constants"></a>
## Constants & magic numbers

- **No magic numbers in `lib/` code.** Pull constants to named `static const`s with a descriptive
  identifier (a default page size, a debounce duration, a scroll threshold). Keep a type's own
  constants on that type, close to where they're read. Genuinely cross-cutting constants go in a
  shared location; before introducing a new one, check whether a shared constant already exists.
- **Inline single-use defaults; don't promote to a named `kDefault…` constant.** A `kDefaultXxx`
  declaration earns its name only when the value is read from **more than one place**, typically a
  field default *and* a build-method substitution (`foo ?? kDefaultFoo`). When the value appears
  only as one constructor's parameter default, leave it a literal and skip the constant. Two
  reasons:
  1. **API pollution.** Top-level `kDefaultXxx` constants (and public `static const` defaults on
     data classes) show up in auto-complete and rendered dartdoc; each one is noise a downstream
     user skims past.
  2. **No drift risk.** Constants exist partly to keep two readers from diverging on a value. With
     one reader, there's nothing to diverge from.

  A dartdoc reference (`Defaults to [kDefaultXxx]`) does not count as a second use; once inlined,
  the dartdoc just spells out the literal (`Defaults to \`20\``).

---

<a id="class-structure"></a>
## Class structure

- **Fields, then constructors, then other members.** A reader scans the state shape first, then
  how to construct it, then how to use it. Unnamed constructor first, then named / factory
  (`sort_unnamed_constructors_first`); static members after the instance members. Applies wherever
  a class has both state and a constructor.
- **`assert` for dev-time errors, `throw` for runtime ones.** A constraint a caller can see
  violated during development (a negative page size, an empty required list) belongs in `assert`:
  stripped in release, zero runtime cost. Reserve `throw` for genuine runtime conditions the caller
  can't guarantee at compile time. Prefer init-list asserts
  (`prefer_asserts_in_initializer_lists`, `prefer_asserts_with_message` are both on).
- **Enforce constructor invariants with `assert(condition, message)` in the initializer list, not
  by silently accepting params and ignoring them downstream.** When two parameters are mutually
  exclusive, or one is only meaningful when another is set, say so loudly at construction time:

  ```dart
  const PagedListView({
    this.itemsPerPage,
    this.pageLoader,
  }) : assert(
         pageLoader != null || itemsPerPage == null,
         'itemsPerPage only applies when a pageLoader drives pagination.',
       );
  ```

  A silently-dropped param is a footgun: the user sets it, confirms it exists in the dartdoc, and
  never realises it does nothing (this is precisely the "ghost param" mistake `list_smith` exists
  to avoid). Prefer compile-time exclusivity when feasible: if the invariant can be encoded by
  splitting into two constructors, do that. Reach for `assert` when the invariant can't be
  expressed in the signature (cross-parameter conditions, value ranges, length constraints).
- **Value types override `toString`.** Immutable data classes implement `toString()` returning
  `'ClassName(field1: value1, field2: value2)'`; the default `Instance of 'ClassName'` is hostile
  in logs and test failures. Include every field with a meaningful representation, as an
  expression-bodied one-liner after the constructors. Omit opaque fields (controllers,
  listenables, builder callbacks) whose `.toString()` is just `Closure: …`; they add noise, and
  bare interpolation of a callable trips DCM's `avoid-missed-calls`. `StatelessWidget` /
  `StatefulWidget` subclasses are exempt; Flutter's diagnostics already wire their `toString`.

---

<a id="package-patterns"></a>
## Package-specific patterns

**TODO (design pass).** The load-bearing structural patterns specific to `list_smith` (the public
widget's constructor shape, how sync vs async sources are modelled, the search/cache policy, any
controller contract) are defined once the architecture is designed. This section will hold those
rules and their "prefer / over" examples, with rationale cross-linked to `APPENDIX.md`. Until
then, follow the general rules above and ask when a structural choice comes up.

---

<a id="idioms"></a>
## Idioms

<a id="idioms-dot-shorthands"></a>
### Static dot shorthands (Dart 3.10+)

Where the context type is known, drop the leading type name; the analyzer resolves the member from
the parameter, return, or variable type. Use it in all of these positions, not just the obvious
enum case:

- Enum values in patterns and arg slots: `crossAxisAlignment: .start`, `mainAxisSize: .min`,
  `case .android => …`.
- `EdgeInsets`-typed slots: `padding: const .all(16)`,
  `padding: const .symmetric(horizontal: 12)`, `margin: .zero`.
- Named constructors / static factories when the return or context type pins them.
- **Constructor field defaults** whose declared type pins the context:

  ```dart
  final Axis scrollDirection;
  const Foo({this.scrollDirection = .vertical});   // not Axis.vertical
  ```

  Top-level / `static const` initialisers are the exception: without an explicit LHS type, Dart
  infers the constant's type from the RHS, so the prefix stays.

Skip it where the surrounding context type isn't obvious without re-reading. After a prefix
disappears from a file entirely, drop it from any `show` clauses too (`unused_shown_name` flags
orphans).

<a id="idioms-drop-redundant-type-args"></a>
### Drop redundant `<Type>` on collection literals

When the surrounding context already pins the element / key / value type (a parameter slot or
assignment target), the explicit `<Type>` prefix is dead weight:

```dart
// Prefer:
states.resolve({WidgetState.selected, if (!enabled) WidgetState.disabled})

// Over:
states.resolve(<WidgetState>{WidgetState.selected, if (!enabled) WidgetState.disabled})
```

Keep `<Type>` when inference would otherwise fall back to `dynamic`: empty literals without a slot
(`final xs = <Foo>[];`), and top-level / `static const` initialisers without an LHS type
annotation.

<a id="idioms-flex-spacing"></a>
### `Row.spacing` / `Column.spacing` / `Wrap.spacing` over interleaved `SizedBox` gaps

Flutter's flex widgets take a `spacing` parameter (and `runSpacing` on `Wrap`) that inserts a
uniform gap between adjacent children. Use it instead of interleaving `SizedBox(width: …)` between
every pair.

```dart
// Prefer:
Row(mainAxisSize: .min, spacing: 8, children: [icon, label])

// Over:
Row(mainAxisSize: .min, children: [icon, SizedBox(width: 8), label])
```

The `spacing` form keeps `children` about content; the layout metadata lives on the parent. It's
also the only correct shape when the gap is *uniform* across all adjacencies. Doesn't apply when
gaps differ between pairs (fall back to explicit `SizedBox` for the non-uniform ones).

<a id="idioms-enhanced-enums"></a>
### Enhanced enums for per-variant config

When a variant enum's values each carry a piece of configuration that diverges per value, attach
the data to the enum via Dart 3's enhanced-enum syntax. Don't define parallel top-level
`kDefault<Variant>Xxx` constants that the build site branches on.

```dart
// Prefer:
enum LoadState {
  idle(showsSpinner: false),
  loading(showsSpinner: true),
  error(showsSpinner: false);

  final bool showsSpinner;
  const LoadState({required this.showsSpinner});
}

// Over: parallel kDefault… constants + a plain enum + per-arm lookups.
```

The default lives on the variant it describes; adding a variant forces the choice at compile time;
and every switch arm references the same expression. Don't force it: a discriminator-only enum
whose values carry no package-read config stays plain.

<a id="idioms-navigator-maybeof"></a>
### `Navigator.maybeOf` over `Navigator.of` for fire-and-forget pops

When dismissing a route from a callback whose only job is the pop, reach for
`Navigator.maybeOf(context)?.pop(value)`, not `Navigator.of(context).pop(value)`.

```dart
// Prefer:
onPressed: (context) => Navigator.maybeOf(context)?.pop(true)

// Over:
onPressed: (context) => Navigator.of(context).pop(true)   // throws if no Navigator
```

`Navigator.of` asserts in debug and throws in release when no `Navigator` exists. For
fire-and-forget pops the right behaviour is to silently no-op if the route is already gone;
`maybeOf` returns `null` and `?.pop(…)` short-circuits. The null-aware `?` costs nothing. Keep
`Navigator.of` when you need the result of `push` and a missing Navigator is a bug you want
surfaced loudly. Doesn't apply to `Navigator.maybePop` (a different concept).

<a id="idioms-collection-for"></a>
### Collection-`for` / collection-`if` over `Iterable.map(…).toList()`

When *building* a literal collection (especially a widget `children:` list), a literal with
embedded control flow reads as data; a `.map(…).toList()` reads as a pipeline that incidentally
produces data. The literal form also drops the `<T>` annotations the list-literal context already
infers.

```dart
// Prefer:
children: [
  for (final item in items) ListTile(title: Text(item.label)),
]

// Over:
children: items.map((item) => ListTile(title: Text(item.label))).toList()
```

Keep explicit generic type args when inference would fall back to `dynamic`
(`MaterialPageRoute<void>(builder: …)` stays).

**Filtering is not construction.** A predicate that keeps a subset of existing items is a *filter*,
so it belongs to the [pipeline rule](#idioms-pipeline-methods) (`items.where(pred)`), even when you
materialise the result into a list for a builder. Reserve collection-`if` for weaving optional
elements into a literal you are building (`[header, if (isX) badge, body]`), not for selecting from
a source collection.

**Flattening or mapping a source is not construction either.** A collection literal whose body is a
`for` (or nested `for`) walking a source to transform it (`{for (final p in pages) for (final x in
p) key(x)}`) is a pipeline in a literal's clothing; write `pages.expand((p) => p).map(key).toSet()`.
Collection-`for` in a literal is for laying out *known* elements (a header, a fixed set of
children), not for deriving one collection from another, no matter how the result is typed.

<a id="idioms-pipeline-methods"></a>
### Library pipeline methods over hand-rolled loops (for data manipulation)

The deliberate flip side of the [collection-`for` rule](#idioms-collection-for). That rule is about
*constructing* a literal; this one is about *transforming, filtering, flattening, or reducing*
data, where a stream-style chain reads as exactly what it is and a hand-written loop with a mutable
accumulator obscures the intent (and re-implements a method the SDK already ships).

```dart
// Prefer, set algebra states the intent directly:
final newItems = incoming.toSet().difference(seenIds);

// Over, a loop that re-derives `difference` by hand:
final newItems = <Item>{};
for (final item in incoming) {
  if (!seenIds.contains(item.id)) newItems.add(item);
}
```

A tell: if you seed an empty collection and mutate it in a loop, that's usually a pipeline wearing
a loop's clothes. **Stay lazy; materialise deliberately.** Don't end a chain with a reflexive
`.toList()`; leave it an `Iterable` and let the terminal consumer drive evaluation. Materialise
only when the result is iterated more than once or an API genuinely requires a `List`; when you do,
`.toList(growable: false)` says it won't be mutated.

<a id="idioms-async-wait"></a>
### `dart:async` `wait` extensions over static `Future.wait(...)`

The extensions (`Iterable<Future<T>>.wait` and the record forms `FutureRecord2`…`FutureRecord9`)
supersede the static call for everyday use. Fixed number of differently-typed futures uses the
record form (`(f1, f2).wait` returns `Future<(T1, T2)>` and destructures directly); a dynamic
number of same-typed futures uses the iterable form (errors surface as `ParallelWaitError` carrying
per-slot values and errors).

<a id="idioms-future-syncvalue"></a>
### `Future.syncValue(x)` over `Future.sync(() => x)` for an already-available value

When you need a completed `Future` around a value that is *already in hand*, or a synchronous
side-effecting call whose result you don't await, reach for `Future.syncValue(value)`. `Future.sync`
is for running a computation that *might* turn out async; `syncValue` states "the value is already
here, just wrap it," which reads truer at the call site.

```dart
// Prefer, refresh() is synchronous and returns nothing to await:
Future<void> _onRefresh() => Future.syncValue(_controller.refresh());

// Over, sync(...) implies a computation that could be async:
Future<void> _onRefresh() => Future.sync(_controller.refresh);
```

Keep `Future.sync` when you specifically want a *synchronous* throw from the computation captured
into the returned future instead of propagating out synchronously.

<a id="idioms-unmodifiable-collections"></a>
### `List.unmodifiable(…)` over `UnmodifiableListView(…)`

Default to `List.unmodifiable(…)` (and the `Set`/`Map` equivalents) for exposing an immutable
collection. The constructor *copies*: snapshot semantics, decoupled from what the caller passed in.
The `…View` only *wraps*: anyone still holding the underlying collection can mutate it, and
the view silently follows. Reach for `UnmodifiableListView` only when you specifically want a
read-through view of private mutable state.

<a id="idioms-uri-construction"></a>
### `Uri.https(…)` / `Uri.http(…)` over `Uri.parse(…)` for known URLs

For a compile-time-known URL, use the named constructor and pass path / query as separate
arguments. Component-wise construction makes host, path, and query visible at a glance and
short-circuits the typos `Uri.parse` silently accepts. `Uri.parse` stays right for runtime input.

<a id="idioms-parts"></a>
### `part` / `part of` only when structurally needed

Legitimate uses: sealed-class cases across files (Dart requires the same library for sealed
subtypes) and code-generation outputs (`*.g.dart`). Avoid it for general organisation; imports are
explicit, and parts leak `_private` symbols across files.

<a id="idioms-fine-grained-rebuilds"></a>
### `ValueNotifier` + `ValueListenableBuilder` over `setState`

In a `StatefulWidget`, drive rebuilds by holding the changing value in a `ValueNotifier<T>` and
wrapping only the dependent subtree in a `ValueListenableBuilder`, rather than calling `setState`.
`setState` re-runs the whole `State.build`; a `ValueListenableBuilder` rebuilds only its own builder,
and the subtree it wraps is exactly the part that depends on the value, so the rebuild scope is
visible at the call site instead of implied.

```dart
// Prefer: only the wrapped subtree rebuilds on change, and which subtree is explicit.
late final _result = ValueNotifier(_resolve());
void _onChanged() => _result.value = _resolve();
@override
Widget build(BuildContext context) => ValueListenableBuilder(
  valueListenable: _result,
  builder: (context, result, _) => /* only the part that depends on result */,
);

// Over: setState re-runs all of build, and nothing marks which part actually changed.
late var _result = _resolve();
void _onChanged() => setState(() => _result = _resolve());
```

Dispose the notifier in `State.dispose`. This is the widget side of the same reasoning the example
applies to its view-models (a scoped `ValueNotifier` for a value that rebuilds a small part; one
coarse notification only when many sites must change together): see
[`example/CODESTYLE.md`](example/CODESTYLE.md) *State management*. The coarse fallback in a widget is
`setState`; reach for it only when genuinely many independent parts of the one widget change at once,
where a single rebuild beats many builders.

---

<a id="dartdoc"></a>
## Comments & dartdoc

Public symbols carry `///` dartdoc that explains *why* and *what guarantee*, not the mechanical
*what*: the type already says that. `public_member_api_docs` is on (see
[hard rule 4 in `.ai/AGENTS.md`](.ai/AGENTS.md#hard-rules)).

### `@docImport` for dartdoc-only references

When a file needs a symbol *only* for `[Name]` references in dartdoc (not in code), do **not** add
a regular `import`; that pulls the dependency into the runtime import graph and hides intent. Use
Dart's dartdoc-only directive instead:

```dart
/// @docImport 'paged_list_view.dart';
library;

import 'page_result.dart'; // Real code import.
```

A regular `import` declares a runtime dependency; if the only reason is `comment_references`
resolution, the runtime graph lies. Put the `@docImport` directives as `///` comments directly
above the file's `library;` directive. `unnecessary_library_directive` does not fire when a
docImport is present.

---

<a id="dcm-rules"></a>
## DCM rules (applied by hand)

`flutter analyze` does not run these; the project treats them as non-negotiable and expects to be
runnable through the DCM CLI (`dcm analyze <dir>`):

- **`no-empty-block`**: every block has code or a `// TODO(handle): …` explaining the gap.
  Empty catch clauses are excused. `onRefresh: () {}` is a violation; give it work or a TODO.
- **`newline-before-return`**: separate a block-final `return` from a preceding non-return
  statement with one blank line. Inline guards (`if (cond) return;`) don't need it.
- **`prefer-commenting-analyzer-ignores`**: every `// ignore:` needs an adjacent `//` explanation
  (dartdoc `///` does not count).
- **`avoid-returning-widgets`**: building-block helpers that return a `Widget` fragment trip this.
  Prefer subclassing `StatelessWidget` for any helper reused or appearing more than once; reach for
  a `// ignore:` with a reason only for genuine one-offs.
- **`prefer-correct-edge-insets-constructor`**: always pick the simplest valid `EdgeInsets`
  constructor (`EdgeInsets.all(0)` becomes `EdgeInsets.zero`; symmetric-equal sides collapse to
  `EdgeInsets.all(v)`; and so on). Applies even when mirroring an upstream Flutter constant; if the
  upstream form is preserved for traceability, record it in the constant's dartdoc.

---

<a id="test-style"></a>
## Test style

Tests split by kind under `test/`:

- **`test/unit_tests/`** holds pure-logic units in `bdd_framework` + `checks`. Frame behaviour as a
  `BddFeature` with `Bdd(...).scenario().given().when().then()`, and keep the parameter matrix in
  one place as `.example(val(...), ...)` rows read via `ctx.example.val('name')`, not literals
  scattered through the body. Assert with `checks` (`check(x).equals(...)`, `.isA<T>()`,
  `.throws<E>()`).
- **`test/widget_tests/`** holds widget behaviour, framed with a local Gherkin helper
  (`test/support/bdd.dart`) that mirrors `minted`'s but is adapted for widgets: `feature`,
  `scenarioWidgets`, and `scenarioOutlineWidgets` (an examples `Map` looped into `testWidgets`).
  `bdd_framework` **cannot** drive widget tests (it wraps `test()`, with no `WidgetTester`, so no
  `pumpWidget`), which is why this helper is local; it fits the plugin-style tests of siblings such
  as `text_sight`, not a widget package. Assert with `checks` throughout: it has no finder API, so
  bridge a `flutter_test` finder by evaluating it, e.g. `check(find.text(...).evaluate()).length.equals(1)`
  for presence, and `checks` matchers for values.

Keep tests deterministic and exercise the failure paths, not just the happy path. The neutral
spinner animates forever, so widget tests drive fixed `pump()`s, never `pumpAndSettle`. The example
app's widget tests use their own copy of the same local helper (a local helper can't cross package
boundaries), with `flutter_test` finders and `checks` for assertions (no `bdd_framework`; the local
helper supplies the Gherkin vocabulary).

---

<a id="documentation-conventions"></a>
## Documentation conventions (Markdown)

- **APPENDIX.md is the source of truth for rationale.** Hard rules, pitfalls, and workflow stay in
  `.ai/AGENTS.md` and `.ai/CLAUDE.md`; the "why we do it this way" essays live in
  [`APPENDIX.md`](APPENDIX.md).
- **Explicit `<a id="…">` anchors** sit above every APPENDIX and CODESTYLE heading. Link via the
  anchor, not the heading text. Anchor stability is load-bearing: when renaming a heading, keep the
  existing anchor, or grep the repo and update every caller in the same change.
- **Bare `flutter` / `dart` in command examples, never `fvm flutter` / `fvm dart`.** FVM is a local
  implementation detail (`.fvmrc` pins the channel). Docs stay tool-agnostic so external
  contributors aren't forced into FVM; scripts under `scripts/` handle the FVM-vs-PATH resolution
  themselves.
- **British spelling in prose and identifiers** (`normalise`, `behaviour`, `initialise`), with one
  carve-out: names fixed by the SDK or a dependency stay as they are (`toJson`, `compareTo`,
  `hashCode`, `color`, `center`).

---

<a id="shell-scripts"></a>
## Shell scripts

- **`shellcheck` is the lint contract** for `scripts/*.sh`, mirroring `flutter analyze` for Dart.
  It runs from the [`linterpol`](https://github.com/LahaLuhem/linterpol) Docker image, so the only
  local requirement is Docker (plus `jq`). Both `scripts/release.sh` preflight and
  `.github/workflows/repo.yml` enforce it; they read the check set (shellcheck, actionlint, rumdl,
  ryl) and the image tag from one manifest, [`.github/lint-checks.json`](.github/lint-checks.json),
  so neither can drift.
- **Prefer `# shellcheck disable=SC<code>` + a one-line "why" over refactoring for simple cases.**
  Refactor when the warning points at a real bug; reach for the directive when the code is correct
  and ShellCheck is just over-conservative. Always pair the directive with a comment.
