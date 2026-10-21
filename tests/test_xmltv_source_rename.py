"""Source-path dependency changes must not silently alter runtime identity."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]

class XmltvRenameTests(unittest.TestCase):
    def test_active_paths_use_renamed_project(self):
        for name in ['build.ps1','build.sh','stage-artifacts.sh','scripts/create-component-update.sh','tests/runtime-validation.sh']:
            with self.subTest(file=name):
                source=(ROOT/name).read_text()
                self.assertIn('opensagetv-vibe-Xmltv-Plugin',source)
                self.assertNotIn('opensagetv-vibe-xmltv-import',source)
    def test_runtime_identity_and_legacy_seed_unchanged(self):
        self.assertIn('XMLTVImportPlugin.jar',(ROOT/'stage-artifacts.sh').read_text())
        self.assertIn('org.opensagetv.vibe.xmltv-import.revision',(ROOT/'modern/Dockerfile').read_text())

if __name__=='__main__': unittest.main()
