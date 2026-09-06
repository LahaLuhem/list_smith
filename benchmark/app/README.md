# list_smith_bench_host

The host app the UI benchmark scenarios pump their widget trees into. Its own package, with its own
`analysis_options.yaml` inheriting the root posture, so the root `analyze lib test` doesn't reach it
and [`bench-app.yml`](../../.github/workflows/bench-app.yml) analyses it separately.

Nothing to run by hand. `run.py run` drives it through `flutter drive` in profile mode. See
[`../README.md`](../README.md).
