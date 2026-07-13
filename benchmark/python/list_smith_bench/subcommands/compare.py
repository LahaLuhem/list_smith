"""`cmd_compare` — pivot-aware Mann-Whitney diff of two runs + a forest chart + COMPARE.md.

Prints the significance table to stdout for interactive use, then (best-effort) writes a forest-plot
PNG and COMPARE.md to the output dir. Chart rendering is best-effort: a missing analysis stack still
prints the table, so the maintainer gets the answer even without seaborn installed.
"""

from __future__ import annotations

import argparse
import importlib.util
import sys
from pathlib import Path

from list_smith_bench.data.dtos.compare_row import CompareRow
from list_smith_bench.data.utils.io import load_aggregated, resolve_outdir
from list_smith_bench.data.utils.stats import compute_compare_rows, regressions


def cmd_compare(args: argparse.Namespace) -> int:
    """Diff two aggregated.json result sets with a pivot-aware Mann-Whitney U test.

    Writes to `<out>/` (default `benchmark/reports/`):
      - compare_forest.png — % deltas, coloured by significance + direction
      - COMPARE.md         — the forest embed + the significance table
    """
    try:
        # Imported here only so a missing-dep failure points at `uv sync` rather than a stack trace
        # deep inside stats.py.
        from scipy import stats as _scipy_stats  # noqa: F401
    except ImportError:
        print("scipy required — run `uv sync` from benchmark/python/", file=sys.stderr)
        return 1

    baseline_records = load_aggregated(args.baseline)
    current_records = load_aggregated(args.current)
    rows = compute_compare_rows(baseline_records, current_records)
    _print_compare_table(rows)

    # The regression gate is the CI-facing verdict; compute it up front so every return path (even
    # the missing-charts one) honours it.
    exit_code = _regression_exit_code(rows, args)

    # The text table + verdict above are the deliverable, so a missing chart stack does not change
    # the outcome — the user still gets the answer.
    missing = [
        name
        for name in ("matplotlib", "polars", "seaborn", "pandas")
        if importlib.util.find_spec(name) is None
    ]
    if missing:
        print(f"\nskipping charts — missing deps: {', '.join(missing)}", file=sys.stderr)
        print("  run `uv sync` from benchmark/python/", file=sys.stderr)
        return exit_code

    # Local imports so cmd_compare stays importable without the chart stack.
    from list_smith_bench.data.utils import charts, markdown

    out_dir = resolve_outdir(args)
    out_dir.mkdir(parents=True, exist_ok=True)

    charts.set_default_theme()
    chart_paths: list[Path] = [charts.plot_compare_forest(rows, out_dir / "compare_forest.png")]

    compare_path = out_dir / "COMPARE.md"
    compare_path.write_text(
        markdown.render_compare_markdown(
            rows,
            chart_paths=chart_paths,
            baseline_records=baseline_records,
            current_records=current_records,
        )
    )

    print(f"\nwrote compare artifacts to: {out_dir}")
    for path in chart_paths:
        print(f"  {path.name}")
    print(f"  {compare_path.name}")

    return exit_code


def _regression_exit_code(rows: list[CompareRow], args: argparse.Namespace) -> int:
    """0 normally; 1 when `--fail-on-regression` is set and a metric regressed past threshold."""
    if not getattr(args, "fail_on_regression", False):
        return 0

    threshold = args.regression_threshold
    regressed = regressions(rows, threshold)
    if not regressed:
        print(f"\nno regression beyond {threshold:.0f}% (--fail-on-regression)")
        return 0

    print(
        f"\nREGRESSION: {len(regressed)} metric(s) slower beyond {threshold:.0f}%:",
        file=sys.stderr,
    )
    for row in regressed:
        print(
            f"  {row.scenario} / {row.metric}: +{row.delta_pct:.1f}% (p={row.p_value:.4f})",
            file=sys.stderr,
        )
    return 1


def _print_compare_table(rows: list[CompareRow]) -> None:
    """Print the Mann-Whitney significance table to stdout for interactive use."""
    header = (
        f"{'scenario':<40} {'metric':<28} "
        f"{'baseline':>12} {'current':>12} {'delta':>10} {'p-value':>10} {'sig?':<5}"
    )
    print(header)
    print("-" * 122)

    if not rows:
        print("(no comparable (scenario, metric) pairs in the two inputs)")
        return

    any_significant = False
    for row in rows:
        any_significant = any_significant or row.significant
        sig_marker = "*" if row.significant else ""
        delta_str = f"{row.delta_pct:>+9.1f}%" if row.delta_finite else "       inf"
        print(
            f"{row.scenario:<40} {row.metric:<28} "
            f"{row.baseline_median:>12.3f} {row.current_median:>12.3f} "
            f"{delta_str} {row.p_value:>10.4f} {sig_marker:<5}"
        )

    print()
    if any_significant:
        print("* = statistically significant at p < 0.05 (Mann-Whitney U)")
    else:
        print("no significant differences detected")
