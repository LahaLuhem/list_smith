"""Metadata helpers — capture run context (git, package version, duration).

Read from the working environment (git, pubspec.yaml) or transform CLI inputs. Deterministic for a
given environment.
"""

from __future__ import annotations

import subprocess
import sys
from datetime import UTC, datetime

from list_smith_bench.config import FALLBACK_DURATION, PROJECT_ROOT
from list_smith_bench.data.dtos.result_record import ResultRecord
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


def summary_metadata(records: list[ResultRecord]) -> dict[str, str]:
    """Header metadata pulled from the first record; all values stringified for f-strings."""
    first = records[0] if records else {}
    return {
        "date": datetime.now(UTC).strftime("%Y-%m-%d"),
        "git_sha": str(first.get("git_sha", "unknown")),
        "package_version": str(first.get("package_version", "unknown")),
        "sdk_version": str(first.get("sdk_version", "unknown")),
        "iterations": str(records_per_scenario(records)),
    }


def parse_duration_overrides(raw: list[str] | None) -> dict[str, int]:
    """Parse `--duration scenario=N` values to `{scenario: seconds}`; exit on bad input."""
    if not raw:
        return {}
    out: dict[str, int] = {}
    for entry in raw:
        if "=" not in entry:
            print(f"--duration expects scenario=N, got: {entry}", file=sys.stderr)
            sys.exit(64)
        scenario, value = entry.split("=", 1)
        try:
            out[scenario.strip()] = int(value)
        except ValueError:
            print(f"--duration value must be int, got: {value}", file=sys.stderr)
            sys.exit(64)
    return out


def resolve_duration(
    scenario: str,
    *,
    global_override: int | None,
    per_scenario: dict[str, int],
) -> int:
    """Per-scenario duration: per-scenario > global > fallback. Micros ignore the value."""
    if scenario in per_scenario:
        return per_scenario[scenario]
    if global_override is not None:
        return global_override
    return FALLBACK_DURATION
