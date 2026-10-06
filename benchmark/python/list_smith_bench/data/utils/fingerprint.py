"""What a micro was built from, as one hash.

2 sides built from the same inputs the same way run the same code, so timing them can only measure
noise.
"""

from __future__ import annotations

import hashlib
import re
from collections.abc import Callable, Sequence
from pathlib import Path
from typing import Final

# `pub get` rewrites it with a timestamp, which would make every build look changed.
_IGNORED_INPUT: Final[str] = "package_config.json"


def fingerprint_path(build_dir: Path, name: str) -> Path:
    """Where micro `name`'s fingerprint sits. In a subdir, so it's never taken for a micro."""
    return build_dir / "inputs" / name


def depfile_inputs(depfile_text: str) -> list[Path]:
    """The input paths a Ninja depfile lists after its `output:` target."""
    _, _, inputs = depfile_text.replace("\\\n", " ").partition(": ")

    return [
        Path(token.replace("\\ ", " "))
        for token in re.split(r"(?<!\\)\s+", inputs.strip())
        if token
    ]


def micro_fingerprint(
    depfile_text: str,
    read_bytes: Callable[[Path], bytes],
    build_command: Sequence[str],
) -> str:
    """One hash over a micro's input contents and how it was built.

    Contents, not paths, so the same micro built in another checkout keeps its fingerprint.
    """
    input_hashes = sorted(
        hashlib.sha256(read_bytes(path)).hexdigest()
        for path in depfile_inputs(depfile_text)
        if path.name != _IGNORED_INPUT
    )
    digest = hashlib.sha256()
    for part in (*build_command, *input_hashes):
        digest.update(part.encode())
        digest.update(b"\0")

    return digest.hexdigest()
