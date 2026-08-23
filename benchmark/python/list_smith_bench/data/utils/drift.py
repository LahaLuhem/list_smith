"""Measures *when* each side of a comparison was sampled — the gate's actual failure mode.

The regression gate's false positives come from run order, not from the statistics (issue #43):
under the fixed candidate-then-baseline order the two sides occupy different halves of the job, so
any drift over the job (page cache warming, CPU frequency, a noisy neighbour) lands on one side.
Every record already carries `started_at`, so that coupling is measurable directly rather than
inferred from a flake caught in the act.
"""

from __future__ import annotations

from datetime import datetime

from list_smith_bench.data.dtos.result_record import ResultRecord


def _timestamps(records: list[ResultRecord]) -> list[datetime]:
    """Parseable `started_at` values of `records`; unparseable or missing ones are skipped."""
    stamps: list[datetime] = []
    for record in records:
        raw = record.get("started_at")
        if not isinstance(raw, str):
            continue
        try:
            stamps.append(datetime.fromisoformat(raw))
        except ValueError:
            continue

    return stamps


def side_timing_separation(
    baseline_records: list[ResultRecord],
    current_records: list[ResultRecord],
) -> float:
    """How far apart in time the two sides were sampled, as a fraction of the whole job's span.

    `0.5` is the fixed-order worst case (each side confined to its own half), `0.0` is perfect
    interleaving. Returns `0.0` when either side has no usable timestamp or the job took no
    measurable time, so a missing clock reads as "nothing to report" rather than a false alarm.
    """
    base = _timestamps(baseline_records)
    curr = _timestamps(current_records)
    if not base or not curr:
        return 0.0

    span_start = min(min(base), min(curr))
    span_seconds = (max(max(base), max(curr)) - span_start).total_seconds()
    if span_seconds <= 0:
        return 0.0

    def mean_offset(stamps: list[datetime]) -> float:
        return sum((stamp - span_start).total_seconds() for stamp in stamps) / len(stamps)

    return abs(mean_offset(curr) - mean_offset(base)) / span_seconds
