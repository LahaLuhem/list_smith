"""Metadata helpers: capture run context (git, package version, duration).

Read from the working environment (git, pubspec.yaml) or transformed from CLI inputs. Deterministic
for a given environment.
"""

from __future__ import annotations

import subprocess
from datetime import UTC, datetime

from list_smith_bench.config import PROJECT_ROOT
from list_smith_bench.data.dtos.result_record import ResultRecord, platform_label
from list_smith_bench.data.utils.stats import records_per_scenario


def current_git_sha() -> str:
    """The current git HEAD short SHA, or 'unknown' if git is unavailable."""
    try:
        result = subprocess.run(
            ["git", "rev-parse", "--short", "HEAD"],
            cwd=PROJECT_ROOT,
            capture_output=True,
            text=True,
            check=True,
        )
    except (subprocess.CalledProcessError, FileNotFoundError):
        return "unknown"
    return result.stdout.strip() or "unknown"


def current_package_version() -> str:
    """The `version:` field from the root `pubspec.yaml`, or 'unknown'.

    A line-prefix scan avoids pulling in pyyaml for one field.
    """
    pubspec = PROJECT_ROOT / "pubspec.yaml"
    if not pubspec.exists():
        return "unknown"
    for line in pubspec.read_text().splitlines():
        if line.startswith("version:"):
            return line.split(":", 1)[1].strip()
    return "unknown"


def _capture_date(records: list[ResultRecord]) -> str:
    """The earliest `started_at` in [records] as a date, or today when none of them parses."""
    stamps: list[datetime] = []
    for record in records:
        raw = record.get("started_at")
        if not isinstance(raw, str):
            continue
        try:
            stamps.append(datetime.fromisoformat(raw))
        except ValueError:
            continue

    return (min(stamps) if stamps else datetime.now(UTC)).strftime("%Y-%m-%d")


def _distinct(records: list[ResultRecord], key: str) -> str:
    """Every value of `key` in [records], so a report mixing captures names them all."""
    return (
        ", ".join(dict.fromkeys(str(record.get(key, "unknown")) for record in records)) or "unknown"
    )


def _iterations(records: list[ResultRecord]) -> str:
    """The count a UI record carries, since it holds every iteration's frames. A micro writes one
    record per iteration, so those get counted."""
    carried = {record["iterations"] for record in records if "iterations" in record}
    counted = records_per_scenario([record for record in records if "iterations" not in record])
    return (
        ", ".join(str(count) for count in sorted(carried | ({counted} if counted else set())))
        or "0"
    )


def summary_metadata(records: list[ResultRecord]) -> dict[str, str]:
    """Header metadata from the records, stringified for f-strings.

    The date is when the data was captured, read off `started_at`, not when the report was
    rendered. Re-rendering an old capture therefore reproduces it rather than restamping it.
    """
    return {
        "date": _capture_date(records),
        "git_sha": _distinct(records, "git_sha"),
        "package_version": _distinct(records, "package_version"),
        "sdk_version": _distinct(records, "sdk_version"),
        "iterations": _iterations(records),
        "platforms": ", ".join(
            sorted(
                {platform_label(record["platform"]) for record in records if "platform" in record}
            )
        ),
    }
