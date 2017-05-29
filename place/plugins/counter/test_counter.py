"""Basic testing for the Counter"""
from unittest import TestCase
import json
from place import scan


TEST_COUNTER = """
{
    "scan_type": "basic_scan",
    "updates": 25,
    "directory": "/tmp/place_test_counter",
    "comments": "test0002_basic_counter from test_counter.py",
    "instruments": [
        {
            "module_name": "counter",
            "class_name": "Counter",
            "priority": 10,
            "config": {
                "sleep_time": 0,
                "plot": false
            }
        }
    ]
}
"""

class TestCounter(TestCase):
    """Test class"""
    def test0001_basic_json(self):
        """Test that JSON is processing our string correctly"""
        dat = json.loads(TEST_COUNTER)
        self.assertEqual(dat, json.loads(json.dumps(dat)))

    def test0002_basic_counter(self):
        """Test that we can perform a scan with JSON input"""
        try:
            scan.web_main(TEST_COUNTER)
        except: #pylint: disable=bare-except
            self.fail()