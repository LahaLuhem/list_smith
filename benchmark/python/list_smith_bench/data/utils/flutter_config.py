"""Temporarily enable macOS desktop for a scenario run, then restore the prior flag state.

The UI scenarios drive a macOS desktop app in profile mode, which needs the `enable-macos-desktop`
feature flag. Rather than leave a global toolchain change behind, `macos_desktop_enabled()` reads
the current flag, enables it only if off, and restores the prior value on exit, so a contributor who
never used desktop keeps it disabled afterwards.
"""

from __future__ import annotations

import json
import subprocess
from collections.abc import Iterator
from contextlib import contextmanager

from list_smith_bench.config import PROJECT_ROOT, flutter_command

_MACOS_DESKTOP_FLAG = "enable-macos-desktop"


def _is_macos_desktop_enabled() -> bool:
    """Whether `enable-macos-desktop` is currently on (reads `flutter config --machine`)."""
    result = subprocess.run(
        [*flutter_command(), "config", "--machine"],
        cwd=PROJECT_ROOT,
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode != 0:
        return False
    try:
        config = json.loads(result.stdout)
    except json.JSONDecodeError:
        return False
    return bool(config.get(_MACOS_DESKTOP_FLAG, False))


def _set_macos_desktop(*, enabled: bool) -> None:
    flag = f"--{'enable' if enabled else 'no-enable'}-macos-desktop"
    subprocess.run(
        [*flutter_command(), "config", flag],
        cwd=PROJECT_ROOT,
        capture_output=True,
        text=True,
        check=False,
    )


@contextmanager
def macos_desktop_enabled() -> Iterator[None]:
    """Enable macOS desktop for the block, restoring the prior flag state on exit.

    A no-op if desktop was already enabled (leaves it enabled). If we flipped it on, we flip it back
    off in the `finally`, so a normal exit or an exception both restore the prior state.
    """
    was_enabled = _is_macos_desktop_enabled()
    if not was_enabled:
        print("enabling macOS desktop (temporary; will restore on exit)")
        _set_macos_desktop(enabled=True)
    try:
        yield
    finally:
        if not was_enabled:
            print("restoring macOS desktop to its prior (disabled) state")
            _set_macos_desktop(enabled=False)
