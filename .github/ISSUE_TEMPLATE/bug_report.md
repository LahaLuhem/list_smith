---
name: Bug report
about: The list widget misbehaves (wrong items, a broken load/refresh/search, a crash, a glitch)
title: "[BUG]"
labels: ''
assignees: ''

---

**What happened**
A clear and concise description of the bug. Which behaviour is involved: pagination,
pull-to-refresh, or search (sync or async)?

**Minimal reproduction**
The smallest widget setup that shows the problem: the data source (sync list or async loader),
the relevant params, and what you did (scrolled to the end, pulled to refresh, typed a query).

```dart
// A stripped-down build() or a small runnable snippet.
```

**Expected behaviour**
What should have happened instead?

**Actual behaviour**
What happened instead: duplicated items, a page that never loads, a search that returns stale
results, an exception + stack trace, and so on.

**Environment**
 - `list_smith` version: [e.g. 0.1.0]
 - Flutter: [`flutter --version`]
 - Platform(s): [Android / iOS / web / desktop]

**Additional context**
Anything else worth knowing: screenshots, a GIF of the glitch, related issues.
