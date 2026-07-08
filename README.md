[![Package checks](https://github.com/LahaLuhem/list_smith/actions/workflows/package.yml/badge.svg?branch=main)](https://github.com/LahaLuhem/list_smith/actions/workflows/package.yml)
[![Coverage Status](https://coveralls.io/repos/github/LahaLuhem/list_smith/badge.svg?branch=main)](https://coveralls.io/github/LahaLuhem/list_smith?branch=main)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](https://github.com/LahaLuhem/list_smith/pulls)
[![Pub Version](https://img.shields.io/pub/v/list_smith.svg)](https://pub.dev/packages/list_smith)
[![Pub Points](https://img.shields.io/pub/points/list_smith?logo=dart)](https://pub.dev/packages/list_smith/score)
[![License: BSD-3-Clause](https://img.shields.io/badge/License-BSD--3--Clause-blue.svg)](./LICENSE)
[![GitHub issues](https://img.shields.io/github/issues/LahaLuhem/list_smith.svg)](https://github.com/LahaLuhem/list_smith/issues)
[![GitHub closed issues](https://img.shields.io/github/issues-closed/LahaLuhem/list_smith.svg)](https://github.com/LahaLuhem/list_smith/issues?q=is%3Aissue+is%3Aclosed)
[![GitHub pull requests](https://img.shields.io/github/issues-pr/LahaLuhem/list_smith.svg)](https://github.com/LahaLuhem/list_smith/pulls)
[![GitHub closed pull requests](https://img.shields.io/github/issues-pr-closed/LahaLuhem/list_smith.svg)](https://github.com/LahaLuhem/list_smith/pulls?q=is%3Apr+is%3Aclosed)

# list_smith

A developer-first Flutter package that wraps `ListView.builder` for real-world lists: async
pagination, pull-to-refresh, and sync-or-async search, without the boilerplate you'd otherwise
write by hand.

> **Status: in development.** The repository infra is set up, but the public API is still being
> designed. This README is a placeholder and will grow real usage docs, examples, and a feature
> list once the API is settled. It isn't published to pub.dev yet.

## What it aims to do

- **Pagination** for async data sources, driven by scroll position.
- **Pull-to-refresh** for async data sources.
- **Search** over both sync and async sources, with a clear policy for how cached items and new
  async results interact.

It's a ground-up successor to [`smart_search_list`](https://pub.dev/packages/smart_search_list):
same good ideas, but with an honest API (no parameters that silently do nothing) and the known
correctness bugs designed out.

## Contributing

Issues and pull requests are welcome once the API stabilises. See
[`.ai/AGENTS.md`](.ai/AGENTS.md) for the contribution conventions and
[`CODESTYLE.md`](CODESTYLE.md) for the code style.
