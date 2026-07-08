Example-app code style. Package (library) style lives in [`../CODESTYLE.md`](../CODESTYLE.md);
example scope and facts live in [`.ai/AGENTS.md`](.ai/AGENTS.md).

The example inherits the package's strict lint set (via `include: ../analysis_options.yaml`),
relaxing only `public_member_api_docs`. So everything in the package style guide applies here:
explicit types, `final` by default, static dot shorthands, the collection-`for` and pipeline
idioms, `Row`/`Column` `spacing:` over interleaved gaps, and so on.

## Example-specific conventions

**TODO (example build-out pass).** State management, feature and folder layout, and demo-widget
composition conventions are decided when the demo is actually built, once `list_smith`'s public
API exists. Until then, keep the placeholder app minimal and lint-clean and follow the
package-level style above.
