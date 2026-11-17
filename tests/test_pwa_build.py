"""Release-stamp checks using tiny invented app trees, without any app startup."""
import importlib.util
from pathlib import Path
import tempfile
import shutil
import subprocess
import sys
import json
import unittest

spec = importlib.util.spec_from_file_location("prepare_pwa", Path(__file__).resolve().parents[1] / "main/tools/prepare_pwa.py")
pwa = importlib.util.module_from_spec(spec)
spec.loader.exec_module(pwa)


class ReleaseIdentity(unittest.TestCase):
    def test_content_identity_is_repeatable_and_ignores_its_generated_metadata(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            www = root / "main/www"
            www.mkdir(parents=True)
            (www / "pwa_install.js").write_text("// invented source\n")
            first = pwa.release_identity(root)
            self.assertEqual(len(first["id"]), 64)
            self.assertEqual(first, pwa.release_identity(root))
            (www / "build.json").write_text('{"id":"old generated stamp"}')
            self.assertEqual(first, pwa.release_identity(root))
            (www / "pwa_install.js").write_text("// changed invented source\n")
            self.assertNotEqual(first["id"], pwa.release_identity(root)["id"])

    def test_code_changes_change_the_release_even_if_static_assets_do_not(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / "main").mkdir()
            (root / "main/server.R").write_text("function(...) {}")
            first = pwa.release_identity(root)
            (root / "main/server.R").write_text("function(...) { invisible(NULL) }")
            self.assertNotEqual(first["id"], pwa.release_identity(root)["id"])

    def test_dot_directories_are_not_part_of_public_release_metadata(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            app = root / "main"
            (app / ".Rproj.user").mkdir(parents=True)
            (app / "ui.R").write_text("NULL")
            first = pwa.release_identity(root)
            (app / ".Rproj.user/history.R").write_text("// local development state")
            self.assertEqual(first, pwa.release_identity(root))

    def test_prepare_and_check_cli_use_the_deployed_app_bytes(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            tools = root / "main/tools"
            tools.mkdir(parents=True)
            script = tools / "prepare_pwa.py"
            shutil.copyfile(pwa.__file__, script)
            (root / "main/ui.R").write_text("NULL")
            prepare = subprocess.run([sys.executable, str(script)], capture_output=True, text=True)
            self.assertEqual(prepare.returncode, 0, prepare.stderr)
            stamp = json.loads((root / "main/www/build.json").read_text())
            self.assertEqual(stamp["id"], pwa.release_identity(root)["id"])
            self.assertIn("built_at", stamp)
            check = subprocess.run([sys.executable, str(script), "--check"], capture_output=True, text=True)
            self.assertEqual(check.returncode, 0, check.stderr)
            (root / "main/ui.R").write_text("list(NULL)")
            changed = subprocess.run([sys.executable, str(script), "--check"], capture_output=True, text=True)
            self.assertNotEqual(changed.returncode, 0)
            self.assertIn("does not match", changed.stderr)

    def test_symlinked_source_is_not_followed(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / "main").mkdir()
            (root / "main/ui.R").symlink_to(root / "outside.R")
            with self.assertRaises(ValueError):
                pwa.release_identity(root)


if __name__ == "__main__":
    unittest.main()
