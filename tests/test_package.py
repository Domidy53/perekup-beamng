from __future__ import annotations

import json
import unittest
from pathlib import Path
from zipfile import ZIP_STORED, ZipFile

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
            self.assertTrue(all(item.compress_type == ZIP_STORED for item in archive.infolist()))
            self.assertTrue(all(item.create_system == 3 for item in archive.infolist()))

    def test_package_uses_the_committed_icon_without_regenerating_it(self) -> None:
        source_icon = ROOT / "ui" / "modules" / "apps" / "perekup" / "app.png"
        with ZipFile(ARCHIVE) as archive:
            self.assertEqual(archive.read("ui/modules/apps/perekup/app.png"), source_icon.read_bytes())

    def test_text_payloads_use_canonical_lf_line_endings(self) -> None:
        with ZipFile(ARCHIVE) as archive:
            for name in archive.namelist():
                if name.lower().endswith((".css", ".html", ".js", ".json", ".lua", ".md", ".txt")) or name == "LICENSE":
                    self.assertNotIn(b"\r", archive.read(name), f"non-canonical line endings in {name}")

    def test_zip_contains_real_core_ui_and_mod_loader(self) -> None:
        with ZipFile(ARCHIVE) as archive:
            names = set(archive.namelist())
            for expected in (
                "scripts/perekup/modScript.lua",
                "lua/ge/extensions/perekup_core.lua",
                "lua/ge/extensions/perekup/career.lua",
                "lua/ge/extensions/perekup/diagnostics.lua",
                "lua/ge/extensions/perekup/persistence.lua",
                "lua/ge/extensions/perekup/listings.lua",
                "lua/ge/extensions/perekup/garage.lua",
                "lua/ge/extensions/perekup/repair.lua",
                "lua/ge/extensions/perekup/progression.lua",
                "lua/ge/extensions/perekup/world.lua",
                "lua/vehicle/extensions/perekup_vehicle_state.lua",
                "ui/modules/apps/perekup/app.json",
                "ui/modules/apps/perekup/app.js",
                "ui/modules/apps/perekup/app.css",
                "ui/modules/apps/perekup/app.png",
                "LICENSE",
            ):
                self.assertIn(expected, names)
            self.assertNotIn("lua/vehicle/extensions/perekup_repair.lua", names)

    def test_app_metadata_matches_the_directive(self) -> None:
        with ZipFile(ARCHIVE) as archive:
            app = json.loads(archive.read("ui/modules/apps/perekup/app.json"))
            script = archive.read("ui/modules/apps/perekup/app.js").decode("utf-8")
            vehicle_state = archive.read("lua/vehicle/extensions/perekup_vehicle_state.lua").decode("utf-8")
            self.assertEqual(app["directive"], "perekupApp")
            self.assertEqual(app["domElement"], "<perekup-app></perekup-app>")
            self.assertIn("directive('perekupApp'", script)
            self.assertIn("track by car.id", script)
            self.assertNotIn("track by car.key", script)
            self.assertIn("цена остаются оценками карьеры", script)
            self.assertIn("retrieveVehicle", script)
            self.assertIn("returnVehicle", script)
            self.assertIn("onVehicleStateRestored", vehicle_state)
            self.assertIn("scope.tr = function", script)
            self.assertIn("Русский", script)
            self.assertIn("English", script)

    def test_world_binding_uses_a_runtime_name_not_lua_wrapper_equality(self) -> None:
        with ZipFile(ARCHIVE) as archive:
            world = archive.read("lua/ge/extensions/perekup/world.lua").decode("utf-8")
            self.assertNotIn("rawequal", world)
            self.assertIn('readMember(object, "setName")', world)
            self.assertIn('readMember(tree, "findObject")', world)
            self.assertIn("verifiedNamedObject", world)

    def test_diagnostics_export_does_not_include_object_ids_or_configs(self) -> None:
        with ZipFile(ARCHIVE) as archive:
            diagnostics = archive.read("lua/ge/extensions/perekup/diagnostics.lua").decode("utf-8")
            core = archive.read("lua/ge/extensions/perekup_core.lua").decode("utf-8")
            self.assertIn('"settings/perekup_diagnostics.json"', diagnostics)
            self.assertIn("function M.exportDiagnostics()", core)
            self.assertNotIn("objectId =", core[core.index("function M.exportDiagnostics()"):core.index("function M.startCareer")])


if __name__ == "__main__":
    unittest.main()
