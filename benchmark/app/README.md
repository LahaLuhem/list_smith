# list_smith_bench_host

The host app the UI benchmark scenarios pump their widget trees into. Its own package, whose
`analysis_options.yaml` includes the same shared lints as the root's. The root's analysis skips it,
so [`bench-app.yml`](../../.github/workflows/bench-app.yml) analyses it separately.

Nothing to run by hand. `run.py run` drives it through `flutter drive` in profile mode. See
[`../README.md`](../README.md).
