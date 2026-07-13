"""`CompareRow` — one row in the `compare` significance table.

Drives the terminal table, the COMPARE.md table, and the forest plot. Frozen dataclass: a value
object, not a mutable record.
"""

from __future__ import annotations

import math
from dataclasses import dataclass

from list_smith_bench.config import SIGNIFICANCE_THRESHOLD


@dataclass(frozen=True)
class CompareRow:
    """One `(scenario, metric)` comparison between a baseline and a current run.

    `scenario` carries its pivot when it has one (e.g. `sync_filter[list_size=100000]`), so each
    size / page-count compares in its own group. `delta_pct` is `math.inf` when the baseline median
    is 0 and the delta is therefore undefined; renderers guard for that with `delta_finite`.
    """

    scenario: str
    metric: str
    baseline_median: float
    current_median: float
    delta_pct: float
    p_value: float

    @property
    def significant(self) -> bool:
        return self.p_value < SIGNIFICANCE_THRESHOLD

    @property
    def delta_finite(self) -> bool:
        return math.isfinite(self.delta_pct)
