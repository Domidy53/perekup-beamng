from __future__ import annotations

import json
import unittest
from pathlib import Path
from zipfile import ZipFile

ROOT = Path(__file__).resolve().parents[1]
ARCHIVE = ROOT / "dist" / "perekup-v0.0.1.zip"


class PackageTests(unittest.TestCase):
    def test_zip_is_valid_and_has_only_beamng_mod_roots(self) -> None:
        self.assertTrue(ARCHIVE.is_file(), "build_mod.py should create the ZIP before package tests")
        with ZipFile(ARCHIVE) as archive:
            self.assertIsNone(archive.testzip())
            names = archive.namelist()
            self.assertEqual({name.split("/", 1)[0] for name in names}, {"lua", "scripts", "ui", "LICENSE"})
            self.assertTrue(all(not name.startswith(("vehicles/", "levels/", "art/")) for name in names))

    def test_zip_contains_real_core_ui_and_mod_loader(self) -> None:
        with ZipFile(ARCHIVE) as archive:
            names = set(archive.namelist())
            for expected in (
                "scripts/perekup/modScript.lua",
                "lua/ge/extensions/perekup_core.lua",
                "lua/ge/extensions/perekup/career.lua",
                "lua/ge/extensions/perekup/persistence.lua",
                "lua/ge/extensions/perekup/listings.lua",
                "lua/ge/extensions/perekup/garage.lua",
                "lua/ge/extensions/perekup/repair.lua",
                "lua/ge/extensions/perekup/progression.lua",
                "ui/modules/apps/perekup/app.json",
                "ui/modules/apps/perekup/app.js",
                "ui/modules/apps/perekup/app.css",
                "ui/modules/apps/perekup/app.png",
                "LICENSE",
            ):
                self.assertIn(expected, names)

    def test_app_metadata_matches_the_directive(self) -> None:
        with ZipFile(ARCHIVE) as archive:
            app = json.loads(archive.read("ui/modules/apps/perekup/app.json"))
            script = archive.read("ui/modules/apps/perekup/app.js").decode("utf-8")
            self.assertEqual(app["directive"], "perekupApp")
            self.assertEqual(app["domElement"], "<perekup-app></perekup-app>")
            self.assertIn("directive('perekupApp'", script)


if __name__ == "__main__":
    unittest.main()
