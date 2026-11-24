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
        serve_web.run(web_dir=d, port=8099)
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
        os.environ["WEB_DIR"] = d
        with mock.patch("http.server.test"):
            runpy.run_module("serve_web", run_name="__main__")
        os.environ.pop("WEB_DIR", None)

if __name__ == '__main__':
    unittest.main()
