"""Safety regressions for the read-only original release checksum check."""

import hashlib
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest

from verify_source_reuse import ROOT, original_release_checksums


class OriginalReleaseChecksTest(unittest.TestCase):
    def setUp(self):
        parent = ROOT / "build/verification-tests"
        parent.mkdir(parents=True, exist_ok=True)
        self.temporary = TemporaryDirectory(prefix="findit-hidden-checks-", dir=parent)
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.release = self.root / "release/production/revisions/final"
        self.release.mkdir(parents=True)
        self.apk = self.release / "fixture.apk"
        self.apk.write_bytes(b"test-owned original fixture")
        self.expected = hashlib.sha256(self.apk.read_bytes()).hexdigest()
        self.checksums = self.release / "SHA256SUMS.txt"
        self.checksums.write_text(f"{self.expected}  fixture.apk\n", encoding="utf-8")

    def test_matching_artifact_is_read_only(self):
        before = (self.apk.read_bytes(), self.checksums.read_bytes())
        report = original_release_checksums(self.root)
        self.assertEqual(report["status"], "passed")
        self.assertEqual(report["files"][0]["actualSha256"], self.expected)
        self.assertEqual((self.apk.read_bytes(), self.checksums.read_bytes()), before)

    def test_changed_artifact_is_not_rebaselined(self):
        self.apk.write_bytes(b"changed fixture")
        before = self.checksums.read_bytes()
        report = original_release_checksums(self.root)
        self.assertEqual(report["status"], "failed")
        self.assertNotEqual(report["files"][0]["actualSha256"], self.expected)
        self.assertEqual(self.checksums.read_bytes(), before)

    def test_missing_artifact_and_list_fail(self):
        self.apk.unlink()
        self.assertEqual(original_release_checksums(self.root)["status"], "failed")
        self.checksums.unlink()
        self.assertEqual(original_release_checksums(self.root)["status"], "failed")

    def test_unsafe_or_malformed_entries_are_rejected(self):
        for line in ("bad digest", f"{self.expected}  ../outside.apk", f"{self.expected}  /outside.apk"):
            with self.subTest(line=line):
                self.checksums.write_text(line + "\n", encoding="utf-8")
                with self.assertRaises(ValueError):
                    original_release_checksums(self.root)

    def test_empty_and_duplicate_lists_are_rejected(self):
        for value in ("", self.checksums.read_text(encoding="utf-8") * 2):
            with self.subTest(value=value):
                self.checksums.write_text(value, encoding="utf-8")
                with self.assertRaises(ValueError):
                    original_release_checksums(self.root)


if __name__ == "__main__":
    unittest.main()
