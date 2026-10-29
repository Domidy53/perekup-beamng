#!/usr/bin/env python3
"""Verify the install ZIP structure, contents, CRCs, and SHA-256 digest."""

from __future__ import annotations

import argparse
import hashlib
from pathlib import Path, PurePosixPath
from zipfile import ZipFile

from build_mod import EXPECTED_FILES, PACKAGE_ROOTS


def verify(path: Path) -> str:
    if not path.is_file():
        raise SystemExit(f"Missing package ZIP: {path}")
    with ZipFile(path) as archive:
        names = archive.namelist()
        if len(names) != len(set(names)):
            raise SystemExit("ZIP contains duplicate entry names")
        unsafe = [name for name in names if name.startswith("/") or ".." in PurePosixPath(name).parts]
        if unsafe:
            raise SystemExit("ZIP contains unsafe paths: " + ", ".join(unsafe))
        corrupt = archive.testzip()
        if corrupt:
            raise SystemExit(f"ZIP CRC check failed at {corrupt}")
        missing = sorted(set(EXPECTED_FILES) - set(names))
        if missing:
            raise SystemExit("ZIP is missing required files: " + ", ".join(missing))
        roots = {name.split("/", 1)[0] for name in names}
        expected_roots = set(PACKAGE_ROOTS) | {"LICENSE"}
        if roots != expected_roots:
            raise SystemExit(f"Unexpected ZIP roots: {sorted(roots)}")
        if any(name.startswith(("vehicles/", "levels/", "art/")) for name in names):
            raise SystemExit("ZIP contains game or third-party vehicle assets")
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive", nargs="?", type=Path,
                        default=Path(__file__).resolve().parents[1] / "dist" / "perekup-v0.0.1.zip")
    args = parser.parse_args()
    digest = verify(args.archive)
    print(f"ZIP integrity: PASS ({args.archive.stat().st_size} bytes)")
    print(f"SHA-256: {digest}")


if __name__ == "__main__":
    main()
