#!/usr/bin/env python3
"""Build a small, deterministic BeamNG.drive mod ZIP using only Python stdlib."""

from __future__ import annotations

import argparse
import hashlib
import json
import struct
import zlib
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile, ZipInfo

ROOT = Path(__file__).resolve().parents[1]
APP_DIR = ROOT / "ui" / "modules" / "apps" / "perekup"
PACKAGE_ROOTS = ("lua", "scripts", "ui")
EXPECTED_FILES = (
    "lua/ge/extensions/perekup_core.lua",
    "lua/ge/extensions/perekup/career.lua",
    "lua/ge/extensions/perekup/economy.lua",
    "lua/ge/extensions/perekup/garage.lua",
    "lua/ge/extensions/perekup/listings.lua",
    "lua/ge/extensions/perekup/persistence.lua",
    "lua/ge/extensions/perekup/progression.lua",
    "lua/ge/extensions/perekup/repair.lua",
    "lua/ge/extensions/perekup/vehicles.lua",
    "scripts/perekup/modScript.lua",
    "ui/modules/apps/perekup/app.json",
    "ui/modules/apps/perekup/app.js",
    "ui/modules/apps/perekup/app.css",
    "ui/modules/apps/perekup/app.png",
    "LICENSE",
)


def _png_chunk(kind: bytes, payload: bytes) -> bytes:
    checksum = zlib.crc32(kind + payload) & 0xFFFFFFFF
    return struct.pack(">I", len(payload)) + kind + payload + struct.pack(">I", checksum)


def make_app_icon(path: Path) -> None:
    """Write a small original UI tile; no external artwork or imaging library."""
    width, height = 250, 120
    background = (18, 24, 32)
    pixels = [[background for _ in range(width)] for _ in range(height)]

    def rect(left: int, top: int, right: int, bottom: int, color: tuple[int, int, int]) -> None:
        for y in range(max(0, top), min(height, bottom)):
            for x in range(max(0, left), min(width, right)):
                pixels[y][x] = color

    def circle(cx: int, cy: int, radius: int, color: tuple[int, int, int]) -> None:
        for y in range(max(0, cy - radius), min(height, cy + radius + 1)):
            for x in range(max(0, cx - radius), min(width, cx + radius + 1)):
                if (x - cx) ** 2 + (y - cy) ** 2 <= radius**2:
                    pixels[y][x] = color

    amber = (239, 180, 93)
    body = (226, 233, 240)
    glass = (72, 94, 113)
    tire = (9, 12, 16)
    rect(0, 0, width, 7, amber)
    rect(45, 69, 202, 87, body)
    rect(61, 62, 91, 70, body)
    rect(78, 51, 159, 70, body)
    rect(84, 55, 116, 67, glass)
    rect(120, 55, 153, 67, glass)
    rect(193, 73, 216, 81, body)
    circle(80, 87, 12, tire)
    circle(174, 87, 12, tire)
    circle(80, 87, 5, amber)
    circle(174, 87, 5, amber)
    rect(49, 91, 207, 94, amber)

    raw = bytearray()
    for row in pixels:
        raw.append(0)
        for red, green, blue in row:
            raw.extend((red, green, blue))
    png = (
        b"\x89PNG\r\n\x1a\n"
        + _png_chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
        + _png_chunk(b"IDAT", zlib.compress(bytes(raw), level=9))
        + _png_chunk(b"IEND", b"")
    )
    path.write_bytes(png)


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
    make_app_icon(APP_DIR / "app.png")
    files = collect_package_files()
    validate_sources(files)
    output.parent.mkdir(parents=True, exist_ok=True)
    temp = output.with_name(output.name + ".tmp")
    if temp.exists():
        temp.unlink()

    with ZipFile(temp, "w", compression=ZIP_DEFLATED, compresslevel=9) as archive:
        for path in files:
            name = path.relative_to(ROOT).as_posix()
            info = ZipInfo(name, date_time=(2024, 1, 1, 0, 0, 0))
            info.compress_type = ZIP_DEFLATED
            info.external_attr = 0o100644 << 16
            archive.writestr(info, path.read_bytes())

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
