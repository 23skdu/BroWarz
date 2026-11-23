import unittest
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '..', 'scripts'))
import bw_util

class TestBwUtil(unittest.TestCase):
    def test_clamp(self):
        self.assertEqual(bw_util.clamp(5, 0, 10), 5)
        self.assertEqual(bw_util.clamp(-1, 0, 10), 0)
        self.assertEqual(bw_util.clamp(11, 0, 10), 10)

if __name__ == '__main__':
    unittest.main()
