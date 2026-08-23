"""Statistical helpers — pure math, no I/O.

`median` is hand-rolled (our sample sizes never justify numpy). `group_samples` flattens raw
`samples` arrays across records. `records_per_scenario` picks a representative iteration count for
report headers. `compute_compare_rows` is the `compare` workhorse: a pivot-aware Mann-Whitney diff
of two runs, extracted here so it is unit-testable without the chart stack.
"""

from __future__ import annotations

import math
from typing import Final

from list_smith_bench.config import MULTI_RECORD_SCENARIOS
from list_smith_bench.data.dtos.compare_row import CompareRow
from list_smith_bench.data.dtos.result_record import ResultRecord


def median(values: list[float]) -> float:
    """Median of `values`; 0.0 for an empty list."""
    sorted_vals = sorted(values)
    n = len(sorted_vals)
    if n == 0:
        return 0.0
    if n % 2 == 1:
        return float(sorted_vals[n // 2])
    return (sorted_vals[n // 2 - 1] + sorted_vals[n // 2]) / 2.0


def _coefficient_of_variation(values: list[float]) -> float:
    """Sample standard deviation as a percentage of the median; 0.0 when it cannot be computed."""
    if len(values) < 2:
        return 0.0
    centre = median(values)
    if centre == 0:
        return 0.0
    mean = sum(values) / len(values)
    variance = sum((value - mean) ** 2 for value in values) / (len(values) - 1)

    return math.sqrt(variance) / abs(centre) * 100.0


def pooled_spread_pct(baseline: list[float], current: list[float]) -> float:
    """The two sides' within-side variation, averaged: the noise a delta has to clear.

    p and Cliff's delta both saturate once the sets separate, so neither can size a gap; this can.
    Evidence in issue #43.
    """
    return (_coefficient_of_variation(baseline) + _coefficient_of_variation(current)) / 2.0


def p_value_floor(baseline_count: int, current_count: int) -> float:
    """The smallest p reachable at these sample sizes, from two perfectly separated sets.

    Printed with the table so a row sitting at the floor reads as "separated", not "large gap".
    """
    from scipy import stats as scipy_stats

    if baseline_count < 1 or current_count < 1:
        return 1.0
    low = list(range(baseline_count))
    high = [value + baseline_count for value in range(current_count)]

    return float(scipy_stats.mannwhitneyu(low, high, alternative="two-sided").pvalue)


def group_samples(records: list[ResultRecord]) -> dict[tuple[str, str], list[float]]:
    """Flatten records into `{(scenario, metric): [all samples across iterations]}`.

    Reads only the raw `samples` arrays, not the `summary` scalars — significance testing prefers
    raw data for statistical power.
    """
    groups: dict[tuple[str, str], list[float]] = {}
    for rec in records:
        scenario: str = rec.get("scenario", "?")
        samples: dict[str, object] = rec.get("samples", {})
        for metric, values in samples.items():
            if not isinstance(values, list):
                continue
            key = (scenario, metric)
            groups.setdefault(key, []).extend(
                float(v) for v in values if isinstance(v, int | float)
            )
    return groups


def records_per_scenario(records: list[ResultRecord]) -> int:
    """How many records belong to the most-emitted scalar (single-record-per-iteration) scenario.

    Multi-record scenarios emit one record per pivot value per iteration, which would inflate the
    "iterations per scenario" header, so they are ignored unless every scenario is multi-record.
    """
    counts: dict[str, int] = {}
    for r in records:
        scenario = str(r.get("scenario", "?"))
        counts[scenario] = counts.get(scenario, 0) + 1
    if not counts:
        return 0
    scalar_counts = [v for k, v in counts.items() if k not in MULTI_RECORD_SCENARIOS]
    if scalar_counts:
        return max(scalar_counts)
    return max(counts.values())


# Summary keys whose value splits a scenario into independent measurement regimes. The compare
# groups on them so a regression at one size / page-count / observer-delay is not masked by pooling
# a scenario's samples into one multi-modal distribution (this suite is a regression tripwire).
_PIVOT_KEYS: Final[tuple[str, ...]] = ("list_size", "page_count", "observer_delay_millis")


def _pivoted_scenario(record: ResultRecord) -> str:
    """The record's scenario, suffixed with its pivot when it has one.

    `sync_filter` at `list_size=100000` becomes `sync_filter[list_size=100000]`, keeping each size's
    samples in their own Mann-Whitney group. Scenarios with no pivot (frame scenarios, the observer
    micro) are returned unchanged.
    """
    scenario = str(record.get("scenario", "?"))
    summary: dict[str, object] = record.get("summary", {})
    for pivot in _PIVOT_KEYS:
        value = summary.get(pivot)
        if value is not None:
            return f"{scenario}[{pivot}={value}]"
    return scenario


def _pivoted_group_samples(records: list[ResultRecord]) -> dict[tuple[str, str], list[float]]:
    """`group_samples`, but keyed by the pivoted scenario so sizes / page-counts compare apart."""
    relabelled = [{**rec, "scenario": _pivoted_scenario(rec)} for rec in records]
    return group_samples(relabelled)


def compute_compare_rows(
    baseline_records: list[ResultRecord],
    current_records: list[ResultRecord],
) -> list[CompareRow]:
    """Build the per-(pivoted-scenario, metric) significance table diffing two runs.

    For every key present in BOTH runs, compute the baseline + current medians, the delta % (or
    `math.inf` when the baseline median is 0), and a two-sided Mann-Whitney U p-value over the raw
    samples. Keys in only one run are skipped (no fair comparison). Mann-Whitney is undefined when
    all samples are identical; that is coerced to `p = 1.0` so the row reads as "no difference".

    scipy is imported inside the function so importing the dtos / config never pulls scipy in.
    """
    from scipy import stats as scipy_stats

    base_groups = _pivoted_group_samples(baseline_records)
    curr_groups = _pivoted_group_samples(current_records)

    rows: list[CompareRow] = []
    for key in sorted(set(base_groups) | set(curr_groups)):
        scenario, metric = key
        base_samples = base_groups.get(key, [])
        curr_samples = curr_groups.get(key, [])
        if not base_samples or not curr_samples:
            continue

        base_median = median(base_samples)
        curr_median = median(curr_samples)
        delta_pct = (curr_median - base_median) / base_median * 100.0 if base_median else math.inf

        try:
            p_value = float(
                scipy_stats.mannwhitneyu(base_samples, curr_samples, alternative="two-sided").pvalue
            )
        except ValueError:
            # Older scipy raises when every value is tied. Newer scipy instead returns nan (caught
            # just below). Either way, "cannot rank" means no detectable difference.
            p_value = 1.0
        if math.isnan(p_value):
            p_value = 1.0

        rows.append(
            CompareRow(
                scenario=scenario,
                metric=metric,
                baseline_median=base_median,
                current_median=curr_median,
                delta_pct=delta_pct,
                p_value=float(p_value),
                spread_pct=pooled_spread_pct(base_samples, curr_samples),
                baseline_count=len(base_samples),
                current_count=len(curr_samples),
            )
        )

    return rows


def regressions(rows: list[CompareRow], threshold_pct: float) -> list[CompareRow]:
    """Rows that significantly regressed beyond `threshold_pct` (the `--fail-on-regression` gate).

    A row trips the gate only when it is significant (p < the significance threshold) AND slower by
    more than `threshold_pct`, so a merely noise-significant sub-threshold shift does not fail CI.
    Every metric here is lower-is-better, so a positive delta is a regression.
    """
    return [
        row
        for row in rows
        if row.significant and row.delta_finite and row.delta_pct > threshold_pct
    ]
