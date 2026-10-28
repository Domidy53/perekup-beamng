#!/usr/bin/env python3
"""Run the lightweight Lua, UI syntax, and ZIP checks for PEREKUP."""

from __future__ import annotations

import importlib.util
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def run(command: list[str]) -> None:
    subprocess.run(command, cwd=ROOT, check=True)


def main() -> None:
    run([sys.executable, "tools/build_mod.py"])

    if importlib.util.find_spec("lupa") is None:
        raise SystemExit("Lua test runtime missing. Run: python -m pip install -r requirements-test.txt")
    try:
        from lupa.lua51 import LuaRuntime
    except ImportError as error:
        raise SystemExit("Lupa's Lua 5.1 runtime is unavailable. Reinstall requirements-test.txt.") from error

    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute((ROOT / "tests" / "lua" / "run.lua").read_text(encoding="utf-8"))

    run([sys.executable, "-m", "unittest", "discover", "-s", "tests", "-p", "test_*.py", "-v"])

    node_path = shutil.which("node")
    if node_path is None:
        print("SKIP JavaScript syntax check (Node.js not found)")
    else:
        node = subprocess.run([node_path, "--check", "ui/modules/apps/perekup/app.js"], cwd=ROOT, check=False)
        if node.returncode != 0:
            raise SystemExit(node.returncode)
        print("PASS JavaScript syntax (Node.js)")

    print("All available automated checks passed. In-game checks are still required.")


if __name__ == "__main__":
    main()
