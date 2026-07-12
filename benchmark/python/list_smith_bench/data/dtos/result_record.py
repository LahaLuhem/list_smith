"""Result-record type alias + the record-flatten helper.

`ResultRecord` narrows `dict[str, Any]` rather than reaching for TypedDict/pydantic — the schema is
internal, stable, and we control both writer and reader end to end.
"""

from __future__ import annotations

from typing import Any

# One JSON-decoded record. See `harness/result_writer.dart` for the writer; the shape is:
#
#   {
#     "scenario": str,
#     "iteration": int,
#     "sdk_version": str,
#     "package_version": str,
#     "git_sha": str,
#     "started_at": ISO-8601 str,
#     "samples": dict[str, list[number]],   # raw per-iteration measurements
#     "summary": dict[str, number],          # pre-computed scalars (median, size, ...)
#   }
ResultRecord = dict[str, Any]


def flatten_records(records: list[ResultRecord]) -> list[dict[str, Any]]:
    """Flatten each record's `summary` block into one row, metadata columns first.

    Per-iteration raw `samples` arrays stay in the record; charts use the pre-computed summary
    scalars. Metadata columns come first so they survive a record missing its `summary`.
    """
    out: list[dict[str, Any]] = []
    for rec in records:
        flat: dict[str, Any] = {
            "scenario": rec.get("scenario", "?"),
            "iteration": rec.get("iteration", -1),
            "git_sha": rec.get("git_sha", "?"),
            "package_version": rec.get("package_version", "?"),
            "sdk_version": rec.get("sdk_version", "?"),
        }
        summary: dict[str, Any] = rec.get("summary", {})
        flat.update(summary)
        out.append(flat)
    return out
