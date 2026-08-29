import importlib.util
import unittest
from pathlib import Path

SCRIPT = Path(__file__).parents[1] / "render_release.py"
SPEC = importlib.util.spec_from_file_location("render_release", SCRIPT)
render_release = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(render_release)


class RenderReleaseTest(unittest.TestCase):
    def test_release_values(self):
        self.assertEqual(
            render_release.release_values("v7.7.0"),
            {"release_version": "7.7.0", "family_version": "7-7"},
        )

    def test_invalid_version_is_rejected(self):
        with self.assertRaises(ValueError):
            render_release.release_values("7.7")

    def test_unknown_template_variable_is_rejected(self):
        with self.assertRaises(ValueError):
            render_release.render("{{ unknown }}", {})


if __name__ == "__main__":
    unittest.main()
