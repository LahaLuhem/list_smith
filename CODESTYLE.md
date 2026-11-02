Package code style. Project facts live in [`.ai/AGENTS.md`](.ai/AGENTS.md), rationale in
[`APPENDIX.md`](APPENDIX.md).

The lints are strict on purpose:
[dartender's shared set](https://github.com/LahaLuhem/dartender/blob/main/lints/lib/analysis_options.yaml),
included by [`analysis_options.yaml`](analysis_options.yaml), makes many of them errors. The house
style: explicit types, no ambient mutability, small focused classes.

<!-- TOC start -->

- [Type safety & nullability](#type-safety)
- [Naming](#naming)
- [Directory layout](#directory-layout)
- [Imports](#imports)
- [Formatting](#formatting)
- [Constants & magic numbers](#constants)
- [Class structure](#class-structure)
- [Package-specific patterns](#package-patterns)
  - [Behaviour lives in the sealed type, not in an orchestrator type-switch](#patterns-behaviour-in-the-type)
  - [A consumer handle carries intents, never engine state](#patterns-controller-contract)
- [Idioms](#idioms)
  - [Static dot shorthands](#idioms-dot-shorthands)
  - [Drop redundant `<Type>` on collection literals](#idioms-drop-redundant-type-args)
  - [The SDK's callback typedefs over written-out function types](#idioms-sdk-callback-typedefs)
  - [`spacing` over interleaved `SizedBox` gaps](#idioms-flex-spacing)
  - [Enhanced enums for per-variant config](#idioms-enhanced-enums)
  - [`Navigator.maybeOf` for fire-and-forget pops](#idioms-navigator-maybeof)
  - [Collection-`for` / collection-`if` over `Iterable.map(…).toList()`](#idioms-collection-for)
  - [Library pipeline methods over hand-rolled loops](#idioms-pipeline-methods)
  - [`dart:async` `wait` extensions over `Future.wait(...)`](#idioms-async-wait)
  - [`Future.syncValue(x)` for a value already in hand](#idioms-future-syncvalue)
  - [`List.unmodifiable(…)` over `UnmodifiableListView(…)`](#idioms-unmodifiable-collections)
  - [`Uri.https(…)` / `Uri.http(…)` for known URLs](#idioms-uri-construction)
  - [`part` / `part of` only when structurally needed](#idioms-parts)
  - [`ValueNotifier` + `ValueListenableBuilder` over `setState`](#idioms-fine-grained-rebuilds)
  - [Plain `if`s over clever `switch` arms](#idioms-plain-conditionals)
  - [Catch `Exception`, let `Error` through](#idioms-catch-exceptions)
- [Prose & voice](#prose)
- [Comments & dartdoc](#dartdoc)
  - [`@docImport` for dartdoc-only references](#dartdoc-docimport)
- [DCM rules (applied by hand)](#dcm-rules)
- [Test style](#test-style)
  - [Conventions](#test-conventions)
- [Documentation conventions (Markdown)](#documentation-conventions)

<!-- TOC end -->

<a id="type-safety"></a>
## Type safety & nullability

- **Type-annotate every public symbol.** Locals infer.
- **`final` fields and locals.** Not parameters (`avoid_final_parameters`), which
  `parameter_assignments` already keeps from being reassigned.
- **Nullability is explicit.** `T?` wherever a value can be missing, and never `as T` to strip it.
- **Bound type parameters to `<T extends Object>`.** A bare `<T>` lets `null` and `dynamic` in, so a
  call site that needs `null` writes `T?`. The exception: a `T` passed straight to an unbounded
  external API that uses `null` as a sentinel.
- **No Java ceremony:** no getter-only abstract bases, factories or interface per class. Sealed
  classes, records, mixins, extension types and enums, where they add clarity.

The `dynamic` and `print()` bans are [hard rules](.ai/AGENTS.md#hard-rules), not style.

---

<a id="naming"></a>
## Naming

- **Spell terms out:** `callback`, `index`, `request`, `context`, `temporary`, never `cb`, `idx`,
  `req`, `ctx`, `tmp`. Protocol and platform initialisms (HTTP, iOS) stay, and so do the genre
  conventions: `i` / `j` counters, `e` in `catch (e)`, `(a, b)` in comparators, `x` / `y`.
- **A name ends in its type,** fields included, since nothing else shows an inferred type:
  `pageResult`, `_pagingStateNotifier`. A role goes in front (`firstLoadHoldCompleter`), a plural
  covers a collection, and `Data`, `Info` or `Result` say nothing. A public parameter keeps its API
  name (`fetchPage`), and a callback parameter stays one word (`value`, `query`).
- **A boolean reads as a question:** `isMoreAvailable`, `didFail`, `hasHeader`. A Flutter mirror
  keeps Flutter's name (`reverse`).
- **A function typedef names its job:** `ItemIdGetter`, not `ItemId`, like Flutter's `ValueGetter`.
- **An unused closure parameter is `_`,** one per slot, dartdoc examples included:
  `builder: (_, index) => …`. `i` and `e` keep their letter.
- **Don't rename a callback parameter to dodge an outer name.** The inner one wins anyway. A body
  that needs both renames the inner and says which is which in the dartdoc.
- **A file is named for its primary public class,** one per file. Private helpers, and a public
  type only that class hands out, may share it.

---

<a id="directory-layout"></a>
## Directory layout

`lib/src/` goes by kind, then feature, then kind again:

- **`data/<feature>/`** is pure vocabulary: `models/`, `typedefs/`, `enums/`, `extensions/` and
  `utils/` (pure functions). Sealed cases sit one level under their base as `part`s
  (`models/policies/`), and each feature has a barrel named after it.
- **`widgets/`** is every widget, the neutral defaults under `widgets/defaults/`.
- **`utils/`** is what no single feature owns.

Two placements earn a rule:

- **A typedef with one home type lives in its file.** Only a standalone one gets `typedefs/`. A
  callable class (`PageFetcher`) is a model.
- **A resolver is an unexported extension,** `<feature>/extensions/<thing>_resolver_extension.dart`,
  or a pure function in `utils/` (`resolveSyncSearch`). The public type stays pure data, and the
  decision tests without a widget ([why](APPENDIX.md#src-directory-layout)).

---

<a id="imports"></a>
## Imports

**Relative within a feature, the other feature's barrel across features.** A leading `/` resolves
from `lib/` and marks the cross-feature ones:

```dart
// in widgets/async_list_view.dart
import '/src/data/pagination/pagination.dart'; // other feature: its barrel
import '/src/utils/query_debouncer.dart';      // other area: the file
import 'paged_view.dart';                      // same folder: relative
```

A feature never imports its own barrel, which loops back. Tests take barrels too
(`package:list_smith/src/data/pagination/pagination.dart`). The exception is pure Dart: the
benchmark micros import the exact file where a barrel pulls in Flutter, and
[`benchmark.yml`](.github/workflows/benchmark.yml) compiles them on any `lib/` change.
`@docImport` follows the same rules, and `part` is always relative. The example app does the same
with `/features/…`.

---

<a id="formatting"></a>
## Formatting

- **100 columns, every text file.** The shared lints' `formatter.page_width` rules Dart, and
  [`.editorconfig`](.editorconfig) matches it.
- **A comment fills to 100, then wraps,** the crossing word staying on its line. `dart format`
  never reflows comments. Markdown is a hard 100, since `rumdl`'s `MD013` fails over it.
- **Blank lines between a method's chunks:** guards, setup, action, return.

---

<a id="constants"></a>
## Constants & magic numbers

- **No magic numbers in `lib/`.** Name them as a `static const` on the type that reads them.
- **A default read in one place stays inline,** not a top-level `kDefault…` cluttering autocomplete
  and dartdoc. A 2nd reader earns it a name, typically a field default plus a `foo ?? kDefaultFoo`.
  A dartdoc mention isn't a reader: write the literal (``Defaults to `20` ``).

---

<a id="class-structure"></a>
## Class structure

- **Fields, constructors, then the rest,** unnamed constructor first, statics last.
- **`assert` for wiring mistakes, `throw` for what a caller can't rule out, a report for bad data.**
  A negative page size asserts, free in release. Data list_smith can work around, like a repeated id
  or a page out of order, goes through `reportBadData` once, in debug, where it lands, and the list
  shows what release would. Asserts sit in the initializer list, with a message.
- **A parameter that does nothing in some combination asserts at construction,** never sits ignored.
  That ghost param is what this package exists to remove. Prefer 2 constructors where the signature
  can say it, and assert what it can't: cross-parameter rules, ranges, lengths.
- **Value types override `toString`** as `'ClassName(field1: value1, ...)'`, an expression body
  after the constructors, since `Instance of …` helps nobody in a log. Skip opaque fields
  (callbacks, controllers, listenables), whose text is noise and whose bare interpolation trips
  DCM's `avoid-missed-calls`. One field per line, so a new one is a one-line diff. A list of the
  app's items or pages shows as a count. Widgets are exempt.
- **Pick a public class's modifier by how an app tests with it.** One an app builds or receives (a
  config, a builder's state) is `final`, since a test makes a real one. One an app calls and stubs
  stays open, since `final` and `base` block the `implements` a mock needs (`ListSmithController`).
- **Inline a private helper with one caller,** until a 2nd caller or a test seam
  (`@visibleForTesting`) shows up. A method the
  [Code Complexity plugin](https://github.com/nikolaikopernik/code-complexity-plugin) scores over
  100% splits into its decisions instead, like `RenderScrollAnchor.performLayout`.
- **Members stay private.** One another library needs takes `@internal`, or `@visibleForTesting` if
  only tests do. A package-only type takes `@internal` itself, and a member no subclass may
  override takes `@nonVirtual`.

---

<a id="package-patterns"></a>
## Package-specific patterns

<a id="patterns-behaviour-in-the-type"></a>
### Behaviour lives in the sealed type, not in an orchestrator type-switch

An injected axis (`PaginationEndPolicy`, `EmptyPageBehaviour`, `SearchCachePolicy`, `Grouping`)
carries its logic as a method the engine calls blindly, never `is`-testing a variant. A new variant
drops in without touching the engine, and each one unit-tests alone.

- A decision takes a data context and returns a value: `shouldAdvance(EmptyPageContext)`. The
  context is exported.
- An effect takes a capability context and returns a `Future`: `Reload.run(ReloadContext)`. That
  context stays unexported, since its hooks (`fetch`, `commit`, `reset`) are the engine's.

```dart
// bad: the engine knows the variants
if (onEmptyPage is AdvanceToFirstNonEmpty) { /* advance logic lives here */ }

// good: the engine gathers facts, the type decides
if (onEmptyPage.shouldAdvance(EmptyPageContext(/* … */))) { /* just act */ }
```

The one engine-side `switch` is tree assembly: whether `Refresh` wraps the subtree in
`RefreshBinding`.

<a id="patterns-controller-contract"></a>
### A consumer handle carries intents, never engine state

`ListSmithController` exposes verbs, never paging state, since watching is the observer's job
([why](APPENDIX.md#controller-handle)).

- One verb per intent, its `Future` completing with the work. `upsert` and `remove` have none to
  wait for, so they're sync `void` ([edit layer](APPENDIX.md#edit-layer)).
- The engine implements the `@internal` `ListSmithControllerHost` and attaches itself, so the
  gesture and the handle share one entry point. A new intent is a host method plus a forwarding
  verb, nothing else.
- Attach in `initState`, swap in `didUpdateWidget`, detach in `dispose`. Detached is a no-op, and
  only never-attached, which can only be wiring, asserts.

---

<a id="idioms"></a>
## Idioms

<a id="idioms-dot-shorthands"></a>
### Static dot shorthands

Drop the type wherever the context pins it: enum values (`mainAxisSize: .min`), `EdgeInsets`
(`padding: const .all(16)`), named constructors, and field defaults
(`this.scrollDirection = .vertical`). Not in a top-level or `static const` initialiser, which has no
type to infer from, nor where a reader would have to look the type up. A prefix gone from the file
leaves its `show` clause too.

<a id="idioms-drop-redundant-type-args"></a>
### Drop redundant `<Type>` on collection literals

Skip it where the slot pins the type:
`states.resolve({WidgetState.selected, if (!enabled) WidgetState.disabled})`. Keep it where
inference would fall back to `dynamic`: an empty literal with no slot (`final xs = <Foo>[];`), or a
top-level or `static const` initialiser.

<a id="idioms-sdk-callback-typedefs"></a>
### The SDK's callback typedefs over written-out function types

The most specific one names the callback's job:

| Written out                | Typedef                                                            |
|----------------------------|--------------------------------------------------------------------|
| `void Function()`          | `VoidCallback`                                                     |
| `T Function()`             | `ValueGetter<T>`                                                   |
| `void Function(T)`         | `ValueChanged<T>` when it fires on a change, else `ValueSetter<T>` |
| `Future<void> Function()`  | `AsyncCallback`                                                    |
| `Future<void> Function(T)` | `AsyncValueSetter<T>`                                              |

Write it out where a parameter's name says what the typedef's bare `value` can't. Several
parameters, or one plus a return value, have no typedef.

<a id="idioms-flex-spacing"></a>
### `spacing` over interleaved `SizedBox` gaps

`Row(mainAxisSize: .min, spacing: 8, children: [icon, label])`, so `children` stays content. Same
for `Column` and `Wrap`. Uneven gaps keep their `SizedBox`es.

<a id="idioms-enhanced-enums"></a>
### Enhanced enums for per-variant config

Hang per-value config off the enum, not parallel `kDefault<Variant>…` constants:

```dart
enum LoadState {
  idle(showsSpinner: false),
  loading(showsSpinner: true),
  error(showsSpinner: false);

  final bool showsSpinner;
  const LoadState({required this.showsSpinner});
}
```

A new value then has to choose. An enum whose values carry nothing stays plain.

<a id="idioms-navigator-maybeof"></a>
### `Navigator.maybeOf` for fire-and-forget pops

A callback that only pops writes `Navigator.maybeOf(context)?.pop(value)`, a no-op without a route.
`Navigator.of` stays where you need `push`'s result and a missing navigator is a bug. Not
`Navigator.maybePop`, which is something else.

<a id="idioms-collection-for"></a>
### Collection-`for` / collection-`if` over `Iterable.map(…).toList()`

Building a literal, a `children:` list above all, embeds the control flow:

```dart
children: [
  for (final item in items) ListTile(title: Text(item.label)),
]
```

It lays out known elements. Filtering (`items.where(…)`) and flattening or mapping a source
(`pages.expand((p) => p).map(key).toSet()`) aren't construction, they're
[pipelines](#idioms-pipeline-methods). Collection-`if` weaves an optional element into a literal
you're building: `[header, if (isX) badge, body]`.

<a id="idioms-pipeline-methods"></a>
### Library pipeline methods over hand-rolled loops

Transforming, filtering, flattening or reducing data is a chain that says what it does:

```dart
// Prefer:
final newItems = incoming.toSet().difference(seenIds);

// Over:
final newItems = <Item>{};
for (final item in incoming) {
  if (!seenIds.contains(item.id)) newItems.add(item);
}
```

The tell is an empty collection filled in a loop. Before hand-rolling one, check the `collection`
package (`groupListsBy`, `splitBetween`, `whereIndexed`, `mapIndexed`, `foldIndexed`, `slices`).

- **Stay lazy.** Materialise only for a 2nd pass or an API that needs a `List`, and then
  `.toList(growable: false)`.
- **A per-item scan on the build path is measured first.** An iterator per element costs several
  times a loop, and there the loop is the honest form ([scan loops](APPENDIX.md#scan-loops)).
  Page-sized work stays a chain.

<a id="idioms-async-wait"></a>
### `dart:async` `wait` extensions over `Future.wait(...)`

`(f1, f2).wait` for a fixed set of differently typed futures, `futures.wait` for a list. A failure
arrives as a `ParallelWaitError` with every slot's value. Keep `Future.wait(…, eagerError: true)`
where a failure has to reach an `on Exception` handler as itself, like a failed page on its way to
the error surface, since `ParallelWaitError` is an `Error` and only arrives once every future ends.

<a id="idioms-future-syncvalue"></a>
### `Future.syncValue(x)` for a value already in hand

```dart
Future<void> _onRefresh() => Future.syncValue(_controller.refresh()); // not Future.sync(…)
```

`Future.sync` is for a computation that might turn out async, or a synchronous throw you want inside
the future.

<a id="idioms-unmodifiable-collections"></a>
### `List.unmodifiable(…)` over `UnmodifiableListView(…)`

`List.unmodifiable` (and the `Set` / `Map` ones) copies, so nobody can change it under you. A view
only wraps, which is right for a read-through view of private state and a bug elsewhere. Over data
that never changes, a view saves the copy: `UnmodifiableListView(pages.map((page) => page.items))`,
saying at the call site why it can't change. Never over a filter or anything read often, since
every read runs the mapping again.

<a id="idioms-uri-construction"></a>
### `Uri.https(…)` / `Uri.http(…)` for known URLs

Host, path and query as separate arguments, where `Uri.parse` quietly takes a typo. `Uri.parse`
stays for runtime input.

<a id="idioms-parts"></a>
### `part` / `part of` only when structurally needed

For sealed cases across files, since Dart wants sealed subtypes in one library, a class implementing
a `base` class, which only that class's own library may do, and generated code (`*.g.dart`). Never
for organising: parts leak `_private` symbols and hide imports.

<a id="idioms-fine-grained-rebuilds"></a>
### `ValueNotifier` + `ValueListenableBuilder` over `setState`

Only the wrapped subtree rebuilds, and the call site shows which:

```dart
late final _result = ValueNotifier(_resolve());
void _onChanged() => _result.value = _resolve();
@override
Widget build(BuildContext context) => ValueListenableBuilder(
  valueListenable: _result,
  builder: (context, result, _) => /* only the part that depends on result */,
);
```

Dispose the notifier in `dispose`, as the example's view-models do
([`example/CODESTYLE.md`](example/CODESTYLE.md)). `setState` is for many independent parts changing
at once.

<a id="idioms-plain-conditionals"></a>
### Plain `if`s over clever `switch` arms

A `switch` dispatches on a sealed type or an enum. A nullable check is an `if`, never an object
pattern:

```dart
// Prefer:
if (snapshot == null) observer?.onReload(.queryChanged);
final debt = snapshot?.debt;
if (debt != null) unawaited(_runReload(debt));

// Over: 2 null checks dressed as a type dispatch.
switch (snapshot) {
  case null:
    observer?.onReload(.queryChanged);
  case _Snapshot(:final debt?):
    unawaited(_runReload(debt));
  case _Snapshot(debt: null):
  // nothing to do
}
```

<a id="idioms-catch-exceptions"></a>
### Catch `Exception`, let `Error` through

An `Exception` is a failure to handle, and whatever holds one is typed as one. An `Error` is a bug,
so it reaches the app:

```dart
// Prefer:
} on Exception catch (exception) {
  state = state.failed(exception);
}

// Over: handles a bug as if it were a failure, and avoid_catching_errors misses it.
} on Object catch (error) {
  state = state.copyWith(error: error);
  if (error is! Exception) rethrow;
}
```

---

<a id="prose"></a>
## Prose & voice

**Read <https://noslopgrenade.com/> before writing any prose here,** the page itself, not a memory
of it. It covers every surface a person reads: dartdoc, comments, Markdown, commit messages, PR and
issue bodies.

- Say the thing, then stop. No over-explaining, no restating what the code or the diff shows.
- Comment at the call site, never in a preamble.
- **Point at the source, never copy the value.** An SDK floor, a version, a count or a file list
  gets referenced ("the floor in `pubspec.yaml`"), since a copy rots silently. The CHANGELOG is the
  exception: it records what was true at its release.
- Markdown structure (tables, lists, `<details>`) replaces prose, never adds to it.
- Plain words over buzzwords. Informal, light, no em-dashes, semicolons or filler (leverage, robust,
  seamless, simply, powerful, comprehensive).
- **Numerals for counts and positions:** `2 headers`, `the 1st page`. `one` stays where it means "a"
  (`one header per group`), `first` stays an adverb (`ask first`) or in a compound
  (`first-page loading`), and a `second` of time is never `2nd`. A heading change moves its GitHub
  anchor, so fix its links in the same edit.

Reflow a block you've edited ([Formatting](#formatting)).

---

<a id="dartdoc"></a>
## Comments & dartdoc

Public symbols carry `///` explaining the *why* and the guarantee, not the *what* the type already
says ([hard rule 4](.ai/AGENTS.md#hard-rules)). Where `public_member_api_docs` forces a line with
nothing to say, `Creates it.` is complete.

**1 or 2 lines.** A decision a reader would question earns a sentence. Restating the signature
doesn't, and rationale goes to [`APPENDIX.md`](APPENDIX.md) behind a one-line pointer to its anchor.
Trim the neighbours whenever you edit a file.

<a id="dartdoc-docimport"></a>
### `@docImport` for dartdoc-only references

A symbol needed only for a `[Name]` reference never gets a real `import`, which would put it in the
runtime graph:

```dart
/// @docImport 'paged_list_view.dart';
library;

import 'page_result.dart'; // Real code import.
```

The directives sit as `///` comments right above `library;`. Drop the last `[Name]` one served and
the directive goes, with its `library;`.

---

<a id="dcm-rules"></a>
## DCM rules (applied by hand)

Neither `dart analyze` nor CI runs these, and the tree stays clean under `dcm analyze <dir>`:

- **`no-empty-block`**: a block holds code or a `// TODO(handle): …`. Empty `catch`es are excused.
  A deliberately empty API (the observer's no-op defaults) takes one file-level `ignore_for_file`
  with its reason.
- **`newline-before-return`**: a blank line before a block-final `return`. Inline guards
  (`if (cond) return;`) are exempt.
- **`prefer-commenting-analyzer-ignores`**: every `// ignore:` has a `//` reason beside it. A `///`
  doesn't count.
- **`avoid-returning-widgets`**: a helper returning a `Widget` becomes a `StatelessWidget`. A
  genuine one-off takes an `// ignore:` with its reason.
- **`prefer-correct-edge-insets-constructor`**: the simplest valid constructor, `EdgeInsets.zero`
  over `.all(0)`, `.all(v)` over equal sides, even mirroring a Flutter constant.

---

<a id="test-style"></a>
## Test style

Tests split by kind under `test/` (`unit_tests/`, `widget_tests/`), each kind mirroring
`lib/src/`.

- **One test file per library,** its `part`s included. A file with no behaviour of its own (a
  typedef, an enum, a plain value) gets none.
- **A scenario goes with the file that owns the rule it pins,** so a suite spanning files splits
  along them.
- **A library too big for one file gets a folder of its name,** one file per behaviour, like
  `widgets/async_list_view/`.
- **A rule all value types share gets one file of its own,** like `data/to_string_test.dart`, which
  finds the types it covers by reading `lib/src`.

The 2 kinds:

- **`test/unit_tests/`**: pure logic in `bdd_framework`, a `BddFeature` with
  `Bdd(...).scenario().given().when().then()`. The parameter matrix sits in one place, as
  `.example(val(...))` rows read via `context.example.val('name')`.
- **`test/widget_tests/`**: widget behaviour through the local Gherkin helper in
  `test/support/bdd.dart` (`feature`, `scenarioWidgets`, `scenarioOutlineWidgets`), since
  `bdd_framework` wraps `test()` and can't hand out a `WidgetTester`.

Assert with `checks`. It has no finder API, so evaluate the finder:
`check(find.text(...).evaluate()).length.equals(1)`. Drive fixed `pump()`s, never
`pumpAndSettle`, which hides how many frames ran and skips in-between states like a loader before
its page. Cover the failure paths too.

**Widget tests share one harness** in `test/support/`, behind the `support.dart` barrel. Check it
before writing a helper, and keep a per-suite `_pump*` wrapper a thin delegation carrying only that
suite's `ListSmith` config. Observer tests extend `ListSmithObserver` with a recording double,
since mockito's generated `implements` won't compile against its `abstract base`. The example app
keeps its own copy of the Gherkin helper, which can't cross a package boundary.

<a id="test-conventions"></a>
### Conventions

- **Test the library, not its dependencies.** What Flutter or a package does by itself (an
  indicator's drag physics, a pool's queue) is its authors' to test. Test what list_smith adds, like
  the key a row gets or the order it wires things in.
- **A test pins a behaviour a user would agree with, said as a sentence.** A value that only carries
  it (a default, a log line, an enum's name) isn't one: compare against its source or the state
  before.
- **A guarantee the design rests on is a behaviour too,** with no screen to show it breaking: a
  rebuild with the same items never runs `groupBy` again.
- **One behaviour, one scenario.** A check another scenario already makes goes, one 2 scenarios
  share moves into its own, and each example row takes a branch no other row does.
- **Assert what the user gets, not the string,** unless 2 messages on one screen mean different
  things.
- **Prove a regression test fails:** break what it guards, watch it go red, put it back.
- **A scenario asserting that nothing happened needs the same in reverse:** break the mechanism
  itself, or it passes just as happily when the feature never worked.
- **`// coverage:ignore-*` marks only code no test can usefully reach:** unreachable today, guarded
  another way, or with no effect to see. Its reason goes on a `//` line above, since anything but
  plain words after the marker switches it off.

---

<a id="documentation-conventions"></a>
## Documentation conventions (Markdown)

- **[`APPENDIX.md`](APPENDIX.md) holds the rationale,** a decision and its why in a few lines.
  Rejected alternatives stay in the issue. Hard rules and workflow live in `.ai/`, what each part
  and seam does in [`doc/how-it-works.md`](doc/how-it-works.md), which an entry never restates.
- **Every APPENDIX and CODESTYLE heading has an `<a id="…">` anchor.** Link by it, never by heading
  text. A renamed heading keeps its anchor, or every link to it changes in the same edit.
- **Bare `flutter` / `dart` in commands,** never `fvm flutter`. FVM is a local detail
  (`.fvmrc`).
- **British spelling** (`normalise`, `behaviour`), except names the SDK or a dependency fixes
  (`toJson`, `hashCode`, `color`).
