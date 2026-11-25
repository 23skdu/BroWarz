import unittest
import sys, os
import http.server
import unittest.mock as mock
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '..', 'scripts'))
import bw_util
import serve_web

class TestBwUtil(unittest.TestCase):
    def test_clamp(self):
        self.assertEqual(bw_util.clamp(5, 0, 10), 5)
        self.assertEqual(bw_util.clamp(-1, 0, 10), 0)
        self.assertEqual(bw_util.clamp(11, 0, 10), 10)

class TestServeWeb(unittest.TestCase):
    @mock.patch("serve_web.http.server.test")
    def test_run(self, mock_test):
        import tempfile
        d = tempfile.mkdtemp()
        previous = os.getcwd()
        try:
            serve_web.run(web_dir=d, port=8099)
        finally:
            os.chdir(previous)
        mock_test.assert_called_once()

    def test_end_headers(self):
        handler = serve_web.COIHandler.__new__(serve_web.COIHandler)
        handler.send_header = mock.Mock()
        with mock.patch.object(http.server.SimpleHTTPRequestHandler, "end_headers", lambda self: None):
            handler.end_headers()
        self.assertEqual(handler.send_header.call_count, 2)

    def test_main_guard(self):
        import runpy
        import tempfile
        d = tempfile.mkdtemp()
        previous = os.getcwd()
        os.environ["WEB_DIR"] = d
        try:
            with mock.patch("http.server.test"):
                runpy.run_module("serve_web", run_name="__main__")
        finally:
            os.chdir(previous)
            os.environ.pop("WEB_DIR", None)

if __name__ == '__main__':
    unittest.main()

import runpy
import tempfile
from pathlib import Path

from PIL import Image

import check_bg
import check_coverage
import check_deadcode
import check_fuzz_coverage


class TestVerificationScripts(unittest.TestCase):
    def test_check_bg_real_banners(self):
        self.assertEqual(check_bg.check_banner_alpha(Path("assets/banners")), [])

    def test_check_bg_flags_bad_banners(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self.assertEqual(len(check_bg.check_banner_alpha(root)), 1)
            Image.new("RGBA", (2, 2), (0, 0, 0, 255)).save(root / "opaque.png")
            Image.new("RGB", (2, 2), (0, 0, 0)).save(root / "flat.png")
            problems = check_bg.check_banner_alpha(root)
            self.assertEqual(len(problems), 2)
            self.assertTrue(any("opaque" in problem for problem in problems))
            self.assertTrue(any("RGBA" in problem for problem in problems))

    def test_check_bg_main(self):
        self.assertEqual(check_bg.main(), 0)
        with tempfile.TemporaryDirectory() as tmp:
            self.assertEqual(check_bg.main(Path(tmp)), 1)

    def test_check_coverage_finds_missing_core_tests(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self.assertEqual(check_coverage.missing_unit_tests(root), ["no core scripts found under scripts/core/"])
            (root / "scripts" / "core").mkdir(parents=True)
            (root / "tests" / "unit").mkdir(parents=True)
            (root / "scripts" / "core" / "alpha.gd").write_text("class_name Alpha\n")
            (root / "scripts" / "core" / "beta.gd").write_text("extends RefCounted\n")
            (root / "tests" / "unit" / "test_alpha.gd").write_text("extends GutTest\nfunc test_alpha():\n\tassert_not_null(Alpha.new())\n")
            problems = check_coverage.missing_unit_tests(root)
            self.assertEqual(len(problems), 1)
            self.assertIn("beta.gd", problems[0])
            self.assertEqual(check_coverage.main(root), 1)

    def test_check_coverage_real_project(self):
        self.assertEqual(check_coverage.missing_unit_tests(), [])
        self.assertEqual(check_coverage.main(), 0)

    def test_check_fuzz_coverage(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self.assertEqual(len(check_fuzz_coverage.missing_fuzz_tests(root)), 5)
            self.assertEqual(check_fuzz_coverage.main(root), 1)
            fuzz = root / "tests" / "fuzz"
            fuzz.mkdir(parents=True)
            (fuzz / "test_fuzz.gd").write_text(" ".join(check_fuzz_coverage.FUZZ_REQUIRED))
            self.assertEqual(check_fuzz_coverage.missing_fuzz_tests(root), [])
        self.assertEqual(check_fuzz_coverage.main(), 0)

    def test_check_deadcode(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self.assertEqual(check_deadcode.scan(root), ["no GDScript files found under scripts/"])
            core = root / "scripts" / "core"
            tools = root / "scripts" / "tools"
            core.mkdir(parents=True)
            tools.mkdir(parents=True)
            (root / "tests").mkdir()
            (root / ".godot").mkdir()
            (core / "unused.gd").write_text("extends RefCounted\n")
            (core / "used.gd").write_text("class_name Used\n")
            (core / "dup_a.gd").write_text("class_name Duplicate\n")
            (core / "dup_b.gd").write_text("class_name Duplicate\n")
            (tools / "generator.gd").write_text("extends SceneTree\n")
            (root / "tests" / "test_used.gd").write_text("var value := Used.new()\n")
            (root / ".godot" / "ignored.gd").write_text("class_name Duplicate\n")
            problems = check_deadcode.scan(root)
            self.assertTrue(any("duplicate class_name" in problem for problem in problems))
            self.assertTrue(any("unused.gd" in problem for problem in problems))
            self.assertFalse(any("generator.gd" in problem for problem in problems))
            self.assertEqual(check_deadcode.main(root), 1)
        self.assertEqual(check_deadcode.main(), 0)

    def test_verification_script_main_guards(self):
        for module in ("check_bg", "check_coverage", "check_deadcode", "check_fuzz_coverage"):
            with self.assertRaises(SystemExit) as raised:
                runpy.run_module(module, run_name="__main__")
            self.assertEqual(raised.exception.code, 0)


if __name__ == '__main__':
    unittest.main()
