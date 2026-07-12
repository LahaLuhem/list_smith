"""Statistical helpers — pure math, no I/O.

`median` is hand-rolled (our sample sizes never justify numpy). `group_samples` flattens raw
`samples` arrays across records (the input the deferred Mann-Whitney compare will want).
`records_per_scenario` picks a representative iteration count for report headers.
"""

from __future__ import annotations

from list_smith_bench.config import MULTI_RECORD_SCENARIOS
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
