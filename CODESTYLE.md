Package code style. Project facts live in [`.ai/AGENTS.md`](.ai/AGENTS.md), design rationale in
[`APPENDIX.md`](APPENDIX.md).

The lint posture is deliberately strict: [`analysis_options.yaml`](analysis_options.yaml) promotes a
long list of lints to errors. The house style wants explicit types, no ambient mutability, and small
focused classes.

Every heading carries an explicit `<a id="…">` anchor. Link by anchor, not heading text, so renames
don't break callers.

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

- **Type-annotate every public symbol.** Inference is fine on locals, per
  `omit_local_variable_types`. A public surface is not the place to lean on it.
- **`final` by default for fields and locals.** Parameters are not, per `avoid_final_parameters`.
  The actual bad behaviour, mutating a parameter inside the body, is what `parameter_assignments`
  forbids.
- **Nullability is explicit.** `T?` everywhere a value can be missing.
  `cast_nullable_to_non_nullable` means `as T` on a `T?` fails lint, and a cast is never the way to
  launder nullability away.
- **Constrain generic type parameters to `<T extends Object>` by default.** Unbounded `<T>` lets
  `null` and `dynamic` satisfy `T`, the same hole the explicit-nullability rule and the
  [`dynamic`-escape-hatch ban](.ai/AGENTS.md#hard-rules) close elsewhere. Bind to `Object` and the
  type system enforces "some real value". A call site that needs `null` spells it `T?`.

  ```dart
  // Prefer:
  class PagedList<T extends Object> extends StatefulWidget { … }

  // Over:
  class PagedList<T> extends StatefulWidget { … }
  ```

  Exception: `T` flows straight into an external API that is itself unbounded *and* uses `null` as
  a sentinel. Don't reach for it speculatively. A bounded `T` is a subtype of an unbounded one in
  parameter positions, so wrapping a raw-`<T>` upstream widget in a bound one stays type-safe.
- **No Java ceremony.** No getter-only abstract base classes, no `AbstractFooFactory`, no
  interface-per-class. Use mixins, sealed classes, records, extension types, and enums where they
  add clarity, not weight.

The `dynamic`-escape-hatch ban and the `print()`-in-library ban are contracts, not style. They live
under [*Hard rules* in `.ai/AGENTS.md`](.ai/AGENTS.md#hard-rules).

---

<a id="naming"></a>
## Naming

- **Prefer abbreviations over initialisms for domain terms.** Expand, in code, comments, dartdocs
  and log messages alike. Well-known protocol and platform initialisms (HTTP, DNS, TCP, TLS, iOS,
  OS) stay. Everything else spells out, because shorthand that's obvious to the author reads as a
  typo to the next person.

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

  This binds *every* identifier: fields, locals, parameters, pattern bindings. The carve-outs are
  the genre conventions: loop counters (`i`, `j`), `e` in `catch (e)`, `(a, b)` in comparator pairs,
  `x`/`y` for coordinates.
- **Local-variable names carry a concise type-suffix.** Without IDE inlay-hints an inferred type is
  invisible, so the name does that work. Where a domain type exists, the suffix is its name
  (`pageResult`, not `result`, `filteredItems`, not `filtered`). Callback parameters are exempt and
  stay single-word (`value`, `query`, `items`), since the call site already pins the type. Generic
  suffixes (`Data`, `Info`, `Result`) lose exactly the disambiguation the rule is for.
- **A boolean reads as a question.** `isMoreAvailable`, `didFail`, `hasHeader`, `drawsHeader`,
  `reportsSignal`, never a bare `moreAvailable` or `compact`. The exception is a Flutter mirror
  (`reverse` on `ListScrollConfig`), which keeps the framework's name.
- **Unused closure parameters take the discard `_`, not a real name.** An identifier you never
  reference is noise, and `_` makes the unused-ness immediate.

  ```dart
  // Prefer:
  builder: (_) => const SizedBox.shrink()
  builder: (_, index) => itemBuilder(index)   // two-arg builder, first unused

  // Over:
  builder: (context) => const SizedBox.shrink()   // context never referenced
  ```

  Dartdoc examples too, and each discard in a signature is its own `_`. The genre-conventional
  letters (`i`, `e`) keep their letter even when unused.
- **Don't rename callback params to dodge a same-named outer variable.** Lexical scoping always
  picks the innermost binding, so there is no ambiguity to resolve and renaming signals a
  distinction that doesn't exist. The exception is a body that needs *both*: rename the inner one
  and say which is which in the callback's dartdoc, not in the parameter name.
- **Files mirror the primary public class name.** `PagedListView` in `paged_list_view.dart`,
  `PagedListController` in `paged_list_controller.dart`, enforced by `file_names`. One primary
  public class per file, though private `_helper` classes may share it. Placement follows
  [Directory layout](#directory-layout).

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
- **`widgets/`** holds everything that is a `Widget`, with the neutral default surfaces under
  `widgets/defaults/`.
- **`utils/`** (top level) holds cross-cutting helpers tied to no single feature
  (`utils/neutral_theme.dart`, `utils/query_debouncer.dart`).

Two placement rules earn their keep:

- **A typedef with a single home type stays in that type's file.** Only a standalone typedef with
  no such home gets its own file under the feature's `typedefs/`. So `RefreshBuilder` sits with
  `ListSmithRefreshState` in `refresh/models/`, while `ItemId` and `ItemBuilder` stand alone in
  their features' `typedefs/`. A callable class is not a typedef: `PageFetcher` and
  `SearchPageFetcher` live under `models/`.
- **A resolver is an unexported `extension` in `<feature>/extensions/`**, named
  `<thing>_resolver_extension.dart`. A pure top-level *function* resolver goes in
  `<feature>/utils/` instead, like `resolveSyncSearch`. Either way the public type stays pure data
  and its decision logic gets a widget-free, unit-testable home. Rationale in
  [`APPENDIX.md`](APPENDIX.md#src-directory-layout).

---

<a id="imports"></a>
## Imports

**Relative within a feature, root-relative across features.** Same-feature targets use a path
relative to the importing file. Anything crossing into another feature or top-level area uses a
leading `/`, which Dart resolves from `lib/`, so `/src/data/…` is `package:list_smith/src/data/…`.
That slash is a deliberate visual cue: own-feature imports read as bare relatives, cross-feature
ones stand out.

```dart
// in widgets/async_list_view.dart
import '/src/data/pagination/models/pagination_end_policy.dart'; // other feature: leading /
import '/src/utils/query_debouncer.dart';                        // other area: leading /
import 'paged_view.dart';                                        // same folder: relative
import 'refresh_binding.dart';                                   // same folder: relative
```

The split holds inside a feature too: `search/extensions/…_extension.dart` reaches its own model as
`../models/search_cache_policy.dart`, never root-relative. `@docImport` follows the same rule, and
`part` / `part of` are always same-feature so always relative. The example app does the same with
`/features/…` (see [`example/CODESTYLE.md`](example/CODESTYLE.md)).

---

<a id="formatting"></a>
## Formatting

- **Wrap text-file content at 100 columns.** `formatter.page_width` in `analysis_options.yaml` is
  authoritative for Dart, [`.editorconfig`](.editorconfig) matches it for Markdown and YAML, and
  they move together. `dart format` does *not* reflow doc-comment prose, so a `///` block wrapped
  narrow stays narrow forever. Aim for ~95 columns of content in one (the `///` and its space
  count), and reflow when you're already touching the block rather than churning files to widen
  them.
- **Blank lines separate logical chunks within a method.** Guards, setup, the main action, the
  return, one blank line between, so a reader can skip the chunks they don't need.
- **Prefer expression bodies** (`prefer_expression_function_bodies`) and **single quotes**
  (`prefer_single_quotes`).

---

<a id="constants"></a>
## Constants & magic numbers

- **No magic numbers in `lib/` code.** Pull them to named `static const`s with a descriptive
  identifier: a default page size, a debounce duration, a scroll threshold. A type's own constants
  live on that type, close to where they're read. Check for an existing shared constant before
  adding a cross-cutting one.
- **Inline single-use defaults, don't promote them to a named `kDefault…` constant.** The name
  earns its place only when the value is read from **more than one place**, typically a field
  default *and* a build-method substitution (`foo ?? kDefaultFoo`). One reader means nothing to
  diverge from, and a top-level `kDefaultXxx` shows up in auto-complete and rendered dartdoc as
  noise a downstream user skims past.

  A dartdoc reference (`Defaults to [kDefaultXxx]`) is not a second use. Once inlined, the dartdoc
  spells out the literal instead (`Defaults to \`20\``).

---

<a id="class-structure"></a>
## Class structure

- **Fields, then constructors, then other members.** A reader scans the state shape, then how to
  build it, then how to use it. Unnamed constructor before named and factory
  (`sort_unnamed_constructors_first`), statics after the instance members.
- **`assert` for dev-time errors, `throw` for runtime ones.** A constraint a caller can see
  violated while developing (a negative page size, an empty required list) is an `assert`:
  stripped in release, free at runtime. `throw` is for conditions the caller genuinely can't
  guarantee at compile time. Init-list asserts, with messages, per
  `prefer_asserts_in_initializer_lists` and `prefer_asserts_with_message`.
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

  A silently-dropped param is the "ghost param" this package exists to avoid: someone sets it,
  finds it in the dartdoc, and never learns it does nothing. Prefer compile-time exclusivity where
  the invariant splits into two constructors. `assert` is for what a signature can't express:
  cross-parameter conditions, value ranges, length constraints.
- **Value types override `toString`.** The default `Instance of 'ClassName'` is hostile in logs and
  test failures, so immutable data classes return `'ClassName(field1: value1, ...)'` as an
  expression-bodied one-liner after the constructors. Skip opaque fields (controllers, listenables,
  builder callbacks) whose `.toString()` is just `Closure: …`: they add noise, and interpolating a
  callable bare trips DCM's `avoid-missed-calls`. Widget subclasses are exempt, since Flutter's
  diagnostics already wire theirs.

---

<a id="package-patterns"></a>
## Package-specific patterns

<a id="patterns-behaviour-in-the-type"></a>
### Behaviour lives in the sealed type, not in an orchestrator type-switch

An injected, sealed behaviour axis (`PaginationEndPolicy`, `EmptyPageBehaviour`,
`SearchCachePolicy`, `Grouping`) carries its own logic as a polymorphic method the engine calls
blindly. The engine must not `is`-test the concrete variant and implement each case itself.

**Why:** the engine stays a thin dispatcher, the way the framework calls `Widget.build` without
knowing the subtype, so new variants and new axes drop in without touching it and each behaviour
unit-tests on its own. Already the shape of `hasReachedEnd`, `actionFor`, `decorate`, and
`shouldAdvance`.

**How:**

- Pure decisions take a *data* context and return a value, like
  `shouldAdvance(EmptyPageContext)`. The engine gathers the facts, the type decides, and the
  context is exported.
- Effectful actions take a *capability* context, the `BuildContext` analogue, and return a
  `Future`, like `Reload.run(ReloadContext)`. That context stays unexported: it hands out mutation
  hooks (`fetch` / `commit` / `reset`) no consumer should call, and the axis is sealed so none can.

```dart
// bad: the engine knows the variants
if (onEmptyPage is AdvanceToFirstNonEmpty) { /* advance logic lives here */ }

// good: the engine gathers facts, the type decides
if (onEmptyPage.shouldAdvance(EmptyPageContext(/* … */))) { /* just act */ }
```

The one `switch` that legitimately stays engine-side is widget-tree assembly, where `Refresh`
on/off decides whether to wrap the subtree in `RefreshBinding`. No type can own that.

<a id="patterns-controller-contract"></a>
### A consumer handle carries intents, never engine state

A handle the consumer constructs and passes in (`ListSmithController`) exposes verbs, not
machinery. No `PagingController`, no `PagingState`, no read-back of paging internals.

**Why:** the pager is hidden on purpose, and a handle that hands state back re-exposes it by the
back door. Watching the list is the observer's job. Full rationale:
[`APPENDIX.md#controller-handle`](APPENDIX.md#controller-handle).

**How:**

- One verb per consumer intent, returning a `Future<void>` that completes when the work does.
- The engine implements `ListSmithControllerHost` and attaches itself, so the gesture and the handle
  run the same entry point and the handle can't carry a second implementation that drifts.
- Attach in `initState`, swap in `didUpdateWidget`, detach in `dispose`. Detached no-ops rather
  than throwing. Assert only for what can only be wiring, meaning nothing ever attached.
- A new intent is one method on the host and one forwarding verb on the handle, nothing else. The
  host is `@internal`, the `ReloadContext` shape: consumers hold the handle, never the engine.

---

<a id="idioms"></a>
## Idioms

<a id="idioms-dot-shorthands"></a>
### Static dot shorthands (Dart 3.10+)

Where the context type is known, drop the leading type name. The analyzer resolves the member from
the parameter, return, or variable type. Not just the obvious enum case:

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

  Top-level and `static const` initialisers are the exception: with no explicit LHS type, Dart
  infers from the RHS, so the prefix stays.

Skip it where the context type isn't obvious without re-reading. Once a prefix leaves a file
entirely, drop it from any `show` clause too.

<a id="idioms-drop-redundant-type-args"></a>
### Drop redundant `<Type>` on collection literals

When the context already pins the element, key or value type (a parameter slot, an assignment
target), the explicit `<Type>` prefix is dead weight:

```dart
// Prefer:
states.resolve({WidgetState.selected, if (!enabled) WidgetState.disabled})

// Over:
states.resolve(<WidgetState>{WidgetState.selected, if (!enabled) WidgetState.disabled})
```

Keep `<Type>` where inference would fall back to `dynamic`: empty literals with no slot
(`final xs = <Foo>[];`), and top-level or `static const` initialisers with no LHS type.

<a id="idioms-flex-spacing"></a>
### `Row.spacing` / `Column.spacing` / `Wrap.spacing` over interleaved `SizedBox` gaps

Flutter's flex widgets take `spacing` (and `runSpacing` on `Wrap`), inserting a uniform gap between
adjacent children. Use it instead of interleaving a `SizedBox` between every pair.

```dart
// Prefer:
Row(mainAxisSize: .min, spacing: 8, children: [icon, label])

// Over:
Row(mainAxisSize: .min, children: [icon, SizedBox(width: 8), label])
```

It keeps `children` about content and puts the layout metadata on the parent. Doesn't apply when
gaps differ between pairs, where explicit `SizedBox`es are the answer.

<a id="idioms-enhanced-enums"></a>
### Enhanced enums for per-variant config

When each of an enum's values carries config that diverges per value, hang the data off the enum
rather than defining parallel `kDefault<Variant>Xxx` constants the build site branches on.

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

The default then lives on the variant it describes, adding a variant forces the choice at compile
time, and every switch arm reads the same expression. Don't force it: a discriminator-only enum
whose values carry no config stays plain.

<a id="idioms-navigator-maybeof"></a>
### `Navigator.maybeOf` over `Navigator.of` for fire-and-forget pops

Dismissing a route from a callback whose only job is the pop? Reach for
`Navigator.maybeOf(context)?.pop(value)`, not `Navigator.of(context).pop(value)`.

```dart
// Prefer:
onPressed: (context) => Navigator.maybeOf(context)?.pop(true)

// Over:
onPressed: (context) => Navigator.of(context).pop(true)   // throws if no Navigator
```

`Navigator.of` asserts in debug and throws in release when there's no `Navigator`. For a
fire-and-forget pop the right behaviour is a silent no-op if the route is already gone, which is
what `maybeOf` plus `?.pop(…)` gives you for free. Keep `Navigator.of` where you need `push`'s
result and a missing Navigator is a bug you want loud. Not `Navigator.maybePop`, a different thing.

<a id="idioms-collection-for"></a>
### Collection-`for` / collection-`if` over `Iterable.map(…).toList()`

When *building* a literal collection, especially a widget `children:` list, a literal with embedded
control flow reads as data. A `.map(…).toList()` reads as a pipeline that incidentally produces
data. The literal form also drops the `<T>` the context already infers.

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

**Filtering is not construction.** A predicate keeping a subset of existing items is a *filter*, so
it belongs to the [pipeline rule](#idioms-pipeline-methods) (`items.where(pred)`), even when you
materialise the result for a builder. Collection-`if` is for weaving optional elements into a
literal you are building (`[header, if (isX) badge, body]`), not for selecting from a source.

**Flattening or mapping a source is not construction either.** A literal whose body is a `for`
walking a source to transform it (`{for (final p in pages) for (final x in p) key(x)}`) is a
pipeline in a literal's clothing. Write `pages.expand((p) => p).map(key).toSet()`. Collection-`for`
lays out *known* elements, a header and a fixed set of children, and never derives one collection
from another.

<a id="idioms-pipeline-methods"></a>
### Library pipeline methods over hand-rolled loops (for data manipulation)

The deliberate flip side of the [collection-`for` rule](#idioms-collection-for). That one is about
*constructing* a literal, this one about *transforming, filtering, flattening or reducing* data,
where a chain reads as exactly what it is and a loop with a mutable accumulator hides the intent
while re-implementing a method the SDK already ships.

```dart
// Prefer, set algebra states the intent directly:
final newItems = incoming.toSet().difference(seenIds);

// Over, a loop that re-derives `difference` by hand:
final newItems = <Item>{};
for (final item in incoming) {
  if (!seenIds.contains(item.id)) newItems.add(item);
}
```

The tell: seeding an empty collection and mutating it in a loop is usually a pipeline wearing a
loop's clothes. Where `dart:core` has no matching method, reach for the `collection` package
(already a dependency) before hand-rolling. `groupListsBy`, `splitBetween`, `whereIndexed`,
`mapIndexed`, `foldIndexed` and `slices` cover most grouping, adjacent-run and indexed scans.

**Stay lazy, materialise deliberately.** No reflexive `.toList()` at the end of a chain. Leave it an
`Iterable` and let the terminal consumer drive evaluation. Materialise when the result is iterated
twice or an API genuinely needs a `List`, and then `.toList(growable: false)` says it won't be
mutated.

**A per-item scan on the build path gets measured before it becomes a chain.** An iterator per
element, and a list per run with `splitBetween`, cost several times a single-pass loop
([`APPENDIX.md#scan-loops`](APPENDIX.md#scan-loops)). There, the loop is the honest form.
Page-granularity work stays a chain.

<a id="idioms-async-wait"></a>
### `dart:async` `wait` extensions over static `Future.wait(...)`

The extensions (`Iterable<Future<T>>.wait` and the record forms `FutureRecord2`…`FutureRecord9`)
supersede the static call for everyday use. A fixed number of differently-typed futures takes the
record form, so `(f1, f2).wait` returns `Future<(T1, T2)>` and destructures directly. A dynamic
number of same-typed ones takes the iterable form, where errors arrive as a `ParallelWaitError`
carrying the per-slot values and errors.

<a id="idioms-future-syncvalue"></a>
### `Future.syncValue(x)` over `Future.sync(() => x)` for an already-available value

For a completed `Future` around a value *already in hand*, or a synchronous side-effecting call you
don't await, reach for `Future.syncValue(value)`. `Future.sync` is for a computation that *might*
turn out async. `syncValue` says the value is already here, which reads truer at the call site.

```dart
// Prefer, refresh() is synchronous and returns nothing to await:
Future<void> _onRefresh() => Future.syncValue(_controller.refresh());

// Over, sync(...) implies a computation that could be async:
Future<void> _onRefresh() => Future.sync(_controller.refresh);
```

Keep `Future.sync` where you specifically want a synchronous throw captured into the returned
future rather than propagating out synchronously.

<a id="idioms-unmodifiable-collections"></a>
### `List.unmodifiable(…)` over `UnmodifiableListView(…)`

Default to `List.unmodifiable(…)`, and the `Set`/`Map` equivalents, for exposing an immutable
collection. The constructor *copies*, so you get snapshot semantics decoupled from what the caller
passed in. The `…View` only *wraps*, so anyone still holding the underlying collection can mutate it
and the view silently follows. `UnmodifiableListView` is for when you specifically want a
read-through view of private mutable state.

<a id="idioms-uri-construction"></a>
### `Uri.https(…)` / `Uri.http(…)` over `Uri.parse(…)` for known URLs

For a compile-time-known URL, use the named constructor and pass path and query as separate
arguments. Component-wise makes host, path and query visible at a glance and short-circuits the
typos `Uri.parse` silently accepts. `Uri.parse` stays right for runtime input.

<a id="idioms-parts"></a>
### `part` / `part of` only when structurally needed

Legitimate uses: sealed-class cases across files, since Dart requires one library for sealed
subtypes, and code-generation outputs (`*.g.dart`). Not for general organisation. Imports are
explicit, and parts leak `_private` symbols across files.

<a id="idioms-fine-grained-rebuilds"></a>
### `ValueNotifier` + `ValueListenableBuilder` over `setState`

In a `StatefulWidget`, hold the changing value in a `ValueNotifier<T>` and wrap only the dependent
subtree in a `ValueListenableBuilder`, rather than calling `setState`. `setState` re-runs the whole
`State.build`. A `ValueListenableBuilder` rebuilds only its own builder, and the subtree it wraps is
exactly the part that depends on the value, so the rebuild scope is visible at the call site instead
of implied.

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

Dispose the notifier in `State.dispose`. Same reasoning the example applies to its view-models, see
[`example/CODESTYLE.md`](example/CODESTYLE.md) *State management*. `setState` is the coarse
fallback, for when genuinely many independent parts of one widget change at once and a single
rebuild beats many builders.

<a id="idioms-plain-conditionals"></a>
### Plain `if`s over clever `switch` arms

A `switch` earns its place dispatching on a sealed type or an enum. Don't reach for it to branch on
a nullable value, and don't lean on object patterns (`Foo(:final bar?)`, `Foo(bar: null)`) to spell
out conditions an `if` says directly.

```dart
// Prefer:
if (snapshot == null) observer?.onReload(.queryChanged);
final debt = snapshot?.debt;
if (debt != null) unawaited(_runReload(debt));

// Over:
switch (snapshot) {
  case null:
    observer?.onReload(.queryChanged);
  case _Snapshot(:final debt?):
    unawaited(_runReload(debt));
  case _Snapshot(debt: null):
  // nothing to do
}
```

**Why:** the reader has to decode destructuring to find two null checks, and the exhaustive-arms
shape suggests a type dispatch that isn't there. It kills readability for no gain.

---

<a id="dartdoc"></a>
## Comments & dartdoc

Public symbols carry `///` dartdoc explaining *why* and *what guarantee*, not the mechanical
*what*, which the type already says. `public_member_api_docs` is on (see
[hard rule 4 in `.ai/AGENTS.md`](.ai/AGENTS.md#hard-rules)).

Keep them to a line or two. A doc that needs a paragraph is rationale, so put that in
[`APPENDIX.md`](APPENDIX.md) and leave a one-line pointer naming the anchor. Comment the surprising
thing at the call site rather than writing a preamble block above it.

### `@docImport` for dartdoc-only references

When a file needs a symbol *only* for `[Name]` references in dartdoc, never a regular `import`:
that pulls the dependency into the runtime graph and hides the intent. Use the dartdoc-only
directive:

```dart
/// @docImport 'paged_list_view.dart';
library;

import 'page_result.dart'; // Real code import.
```

A regular `import` declares a runtime dependency, so if the only reason is `comment_references`
resolution, the graph lies. The `@docImport` directives go as `///` comments directly above the
file's `library;`, which `unnecessary_library_directive` then leaves alone. Drop the last `[Name]`
a docImport served and the directive (and its `library;`) go too.

---

<a id="dcm-rules"></a>
## DCM rules (applied by hand)

`flutter analyze` does not run these. The project treats them as non-negotiable and expects to be
clean under the DCM CLI (`dcm analyze <dir>`):

- **`no-empty-block`**: every block has code or a `// TODO(handle): …` explaining the gap. Empty
  catch clauses are excused. `onRefresh: () {}` is a violation, so give it work or a TODO. A
  deliberately-empty API (an observer's no-op defaults) takes a file-level `ignore_for_file` with
  its reason, once, rather than a comment in each body.
- **`newline-before-return`**: one blank line between a block-final `return` and the non-return
  statement before it. Inline guards (`if (cond) return;`) don't need it.
- **`prefer-commenting-analyzer-ignores`**: every `// ignore:` needs an adjacent `//` explanation.
  A dartdoc `///` doesn't count.
- **`avoid-returning-widgets`**: a helper returning a `Widget` fragment trips this. Subclass
  `StatelessWidget` for anything reused or appearing twice, and reach for a `// ignore:` with a
  reason only for a genuine one-off.
- **`prefer-correct-edge-insets-constructor`**: always the simplest valid `EdgeInsets` constructor,
  so `EdgeInsets.all(0)` becomes `EdgeInsets.zero` and symmetric-equal sides collapse to
  `EdgeInsets.all(v)`. Holds even when mirroring an upstream Flutter constant. If the upstream form
  is kept for traceability, say so in the constant's dartdoc.

---

<a id="test-style"></a>
## Test style

Tests split by kind under `test/`:

- **`test/unit_tests/`** holds pure-logic units in `bdd_framework` + `checks`. Frame behaviour as a
  `BddFeature` with `Bdd(...).scenario().given().when().then()`, and keep the parameter matrix in
  one place as `.example(val(...), ...)` rows read via `ctx.example.val('name')`, never literals
  scattered through the body.
- **`test/widget_tests/`** holds widget behaviour, framed with the local Gherkin helper in
  `test/support/bdd.dart`: `feature`, `scenarioWidgets`, `scenarioOutlineWidgets`. The helper is
  local because `bdd_framework` **cannot** drive widget tests, wrapping `test()` with no
  `WidgetTester` and so no `pumpWidget`.

Assert with `checks` throughout (`check(x).equals(...)`, `.isA<T>()`, `.throws<E>()`). It has no
finder API, so bridge a `flutter_test` finder by evaluating it:
`check(find.text(...).evaluate()).length.equals(1)`.

Keep tests deterministic and exercise the failure paths, not just the happy one. The neutral spinner
animates forever, so drive fixed `pump()`s and never `pumpAndSettle`. The example app keeps its own
copy of the Gherkin helper, since a local helper can't cross a package boundary.

**Widget tests share one harness, not per-file copies.** The pieces live under `test/support/`,
re-exported by the `support.dart` barrel, so import that one file:

| Helper | What it does |
|---|---|
| `pumpListSmith(tester, child)` | wraps the list in the `Directionality` + `MediaQuery` scaffold every test needs |
| `drain(tester, {frames})` | pumps a fixed number of frames |
| `settle(tester, {debounce})` | advances past a search debounce, then drains |
| `containsIgnoreCase` | sync-search predicate |
| `pagedFetcher([...])` | multi-page or overlapping data (a single page reads clearer inline) |

A per-suite `_pump*` wrapper is fine where a file repeats a construction, as long as it stays a thin
delegation carrying only that suite's own `ListSmith` config, never a re-declared scaffold or drain
loop. For the observer, extend `ListSmithObserver` with a recording double like
`RecordingListSmithObserver`. A mock generator can't help: the observer is `abstract base`, so
mockito's generated `implements` won't compile against it, and nothing else at the test seams is
class-shaped to mock.

---

<a id="documentation-conventions"></a>
## Documentation conventions (Markdown)

- **APPENDIX.md is the source of truth for rationale.** Hard rules, pitfalls and workflow stay in
  `.ai/AGENTS.md` and `.ai/CLAUDE.md`. The "why we do it this way" lives in
  [`APPENDIX.md`](APPENDIX.md).
- **Explicit `<a id="…">` anchors** sit above every APPENDIX and CODESTYLE heading. Link via the
  anchor, never the heading text. Anchor stability is load-bearing: renaming a heading keeps the
  existing anchor, or you grep the repo and update every caller in the same change.
- **Bare `flutter` / `dart` in command examples, never `fvm flutter`.** FVM is a local detail
  (`.fvmrc` pins the channel), and docs stay tool-agnostic so an external contributor isn't forced
  into it. The scripts under `scripts/` resolve FVM-vs-PATH themselves.
- **British spelling in prose and identifiers** (`normalise`, `behaviour`, `initialise`). The one
  carve-out is names fixed by the SDK or a dependency (`toJson`, `compareTo`, `hashCode`, `color`,
  `center`).
- **No AI-tells in prose.** No em-dashes, no semicolons splicing two sentences, no filler
  vocabulary (leverage, robust, seamless, simply, powerful, comprehensive). Informal and direct,
  contractions welcome. Structure (a table, a list, a `<details>` reveal) replaces prose rather
  than getting added to it.

---

<a id="shell-scripts"></a>
## Shell scripts

- **`shellcheck` is the lint contract** for `scripts/*.sh`, mirroring `flutter analyze` for Dart.
  It runs from the [`linterpol`](https://github.com/LahaLuhem/linterpol) Docker image, so the only
  local requirement is Docker plus `jq`. The `scripts/release.sh` preflight and
  [`repo.yml`](.github/workflows/repo.yml) both read the check set and image tag from
  [`lint-checks.json`](.github/lint-checks.json), so neither can drift.
- **`# shellcheck disable=SC<code>` plus a one-line why beats refactoring for simple cases.**
  Refactor where the warning points at a real bug. Reach for the directive where the code is
  correct and ShellCheck is being over-conservative. Always pair it with a comment.
