#!/usr/bin/env python3
"""Build a small, deterministic BeamNG.drive mod ZIP using only Python stdlib."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from zipfile import ZIP_STORED, ZipFile, ZipInfo

ROOT = Path(__file__).resolve().parents[1]
APP_DIR = ROOT / "ui" / "modules" / "apps" / "perekup"
PACKAGE_ROOTS = ("lua", "scripts", "ui")
TEXT_SUFFIXES = {".css", ".html", ".js", ".json", ".lua", ".md", ".txt"}
EXPECTED_FILES = (
    "lua/ge/extensions/perekup_core.lua",
    "lua/ge/extensions/perekup/career.lua",
    "lua/ge/extensions/perekup/diagnostics.lua",
    "lua/ge/extensions/perekup/economy.lua",
    "lua/ge/extensions/perekup/garage.lua",
    "lua/ge/extensions/perekup/listings.lua",
    "lua/ge/extensions/perekup/persistence.lua",
    "lua/ge/extensions/perekup/progression.lua",
    "lua/ge/extensions/perekup/repair.lua",
    "lua/ge/extensions/perekup/vehicles.lua",
    "lua/ge/extensions/perekup/world.lua",
    "lua/vehicle/extensions/perekup_vehicle_state.lua",
    "scripts/perekup/modScript.lua",
    "ui/modules/apps/perekup/app.json",
    "ui/modules/apps/perekup/app.js",
    "ui/modules/apps/perekup/app.css",
    "ui/modules/apps/perekup/app.png",
    "LICENSE",
)


def collect_package_files() -> list[Path]:
    files: list[Path] = []
    for root_name in PACKAGE_ROOTS:
        root = ROOT / root_name
        if not root.is_dir():
            raise SystemExit(f"Missing package folder: {root_name}/")
        for path in root.rglob("*"):
            if path.is_symlink():
                raise SystemExit(f"Refusing to package a symlink: {path.relative_to(ROOT)}")
            if path.is_file():
                files.append(path)
    ordered = sorted(files, key=lambda path: path.relative_to(ROOT).as_posix())
    license_file = ROOT / "LICENSE"
    if not license_file.is_file():
        raise SystemExit("Missing project LICENSE")
    # Keep valid BeamNG content folders at the beginning of the ZIP entry list.
    ordered.append(license_file)
    return ordered


def package_bytes(path: Path) -> bytes:
    """Normalize text payloads so Windows and Linux produce identical ZIPs."""
    content = path.read_bytes()
    if path.suffix.lower() in TEXT_SUFFIXES or path.name == "LICENSE":
        return content.replace(b"\r\n", b"\n").replace(b"\r", b"\n")
    return content


def validate_sources(files: list[Path]) -> None:
    relative = {path.relative_to(ROOT).as_posix() for path in files}
    missing = [name for name in EXPECTED_FILES if name not in relative]
    if missing:
        raise SystemExit("Missing required mod files: " + ", ".join(missing))
    metadata = json.loads((APP_DIR / "app.json").read_text(encoding="utf-8"))
    for field in ("name", "author", "version", "description", "directive", "domElement", "css"):
        if field not in metadata:
            raise SystemExit(f"UI app metadata is missing {field!r}")
    if metadata["directive"] != "perekupApp" or metadata["domElement"] != "<perekup-app></perekup-app>":
        raise SystemExit("UI app directive and DOM element do not match app.js")


def build(output: Path) -> tuple[str, int]:
    files = collect_package_files()
    validate_sources(files)
    output.parent.mkdir(parents=True, exist_ok=True)
    temp = output.with_name(output.name + ".tmp")
    if temp.exists():
        temp.unlink()

    # ZIP_STORED avoids zlib-version differences that change the package hash
    # between Windows and Linux. The install payload is small enough for this.
    with ZipFile(temp, "w", compression=ZIP_STORED) as archive:
        for path in files:
            name = path.relative_to(ROOT).as_posix()
            info = ZipInfo(name, date_time=(2024, 1, 1, 0, 0, 0))
            info.create_system = 3
            info.compress_type = ZIP_STORED
            info.external_attr = 0o100644 << 16
            archive.writestr(info, package_bytes(path))

    with ZipFile(temp, "r") as archive:
        corrupt = archive.testzip()
        names = archive.namelist()
        top_level = {name.split("/", 1)[0] for name in names}
        if corrupt:
            temp.unlink(missing_ok=True)
            raise SystemExit(f"ZIP CRC check failed at {corrupt}")
        if top_level != set(PACKAGE_ROOTS) | {"LICENSE"}:
            temp.unlink(missing_ok=True)
            raise SystemExit(f"Unexpected top-level ZIP entries: {sorted(top_level)}")
        if not set(EXPECTED_FILES).issubset(names):
            temp.unlink(missing_ok=True)
            raise SystemExit("ZIP is missing required content")
        if any(name.startswith(("vehicles/", "levels/", "art/")) for name in names):
            temp.unlink(missing_ok=True)
            raise SystemExit("ZIP unexpectedly contains game or third-party vehicle assets")

    temp.replace(output)
    digest = hashlib.sha256(output.read_bytes()).hexdigest()
    return digest, len(files)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--output",
        type=Path,
        default=ROOT / "dist" / "perekup-v0.0.1.zip",
        help="ZIP output path (default: dist/perekup-v0.0.1.zip)",
    )
    args = parser.parse_args()
    output = args.output if args.output.is_absolute() else ROOT / args.output
    digest, count = build(output)
    print(f"Built {output}")
    print(f"Files: {count}")
    print(f"SHA-256: {digest}")


if __name__ == "__main__":
    main()
