"""Check publishing exclusions with Git itself, without initializing this project.

Only a disposable test repository and path names are used. No private key is read.
"""

import os
from pathlib import Path
import shutil
import subprocess
from tempfile import TemporaryDirectory
import unittest

ROOT = Path(__file__).resolve().parent.parent


@unittest.skipUnless(shutil.which("git"), "Git is required to validate ignore patterns")
class PublishingIgnoreTests(unittest.TestCase):
    def setUp(self):
        temporary_root = ROOT / "build/verification-tests"
        temporary_root.mkdir(parents=True, exist_ok=True)
        temporary = TemporaryDirectory(prefix="findit-gitignore-", dir=temporary_root)
        self.addCleanup(temporary.cleanup)
        self.directory = Path(temporary.name)
        (self.directory / ".gitignore").write_bytes((ROOT / ".gitignore").read_bytes())
        self.environment = dict(os.environ)
        for key in list(self.environment):
            if key.startswith("GIT_"):
                self.environment.pop(key)
        self.environment["GIT_CONFIG_NOSYSTEM"] = "1"
        self.environment["GIT_CONFIG_GLOBAL"] = os.devnull
        result = subprocess.run([shutil.which("git"), "init", "--quiet"],
                                cwd=self.directory, env=self.environment,
                                capture_output=True, text=True, timeout=30)
        self.assertEqual(result.returncode, 0, result.stderr)

    def ignored(self, paths):
        result = subprocess.run([shutil.which("git"), "check-ignore", "--no-index", "--stdin", "-z"],
                                input=("\0".join(paths) + "\0").encode("utf-8"), cwd=self.directory,
                                env=self.environment, capture_output=True,
                                timeout=30)
        self.assertIn(result.returncode, (0, 1), result.stderr)
        return set(result.stdout.decode("utf-8").rstrip("\0").split("\0")) if result.stdout else set()

    def test_android_outputs_are_ignored_at_any_depth(self):
        paths = [f"{directory}{name}" for directory in ("", "release/final/", "arbitrary/nested/")
                 for name in ("app.aab", "app.apk", "app.apks")]
        self.assertEqual(self.ignored(paths), set(paths))

    def test_private_signing_files_backups_and_local_inputs_are_ignored(self):
        paths = [f"keys/nested/upload.{extension}{suffix}"
                 for extension in ("jks", "keystore", "p12", "pfx", "key", "pk8", "pem")
                 for suffix in ("", ".bak", ".old")]
        paths += [f"keys/export.der{suffix}" for suffix in ("", ".bak", ".old")]
        paths += [f"{directory}{name}{suffix}" for directory in ("android/", "keys/nested/")
                  for name in ("key.properties", "keystore.properties", "signing.properties")
                  for suffix in ("", ".bak", ".old", ".orig")]
        paths += ["android/key.properties", "keys/key.properties",
                  "keys/keystore.properties", "keys/signing.properties",
                  ".local-signing/findit-hidden-objects-upload.p12",
                  ".local-signing/BACKUP-INSTRUCTIONS.txt", "config/production.json",
                  ".env", ".env.local", "nested/.env.production"]
        self.assertEqual(self.ignored(paths), set(paths))

    def test_policy_source_html_examples_and_checked_public_certificate_remain_publishable(self):
        paths = ["privacy-policy.html", "assets/legal/privacy-policy.json", "README.md",
                 "android/key.properties.example", "config/production.example.json",
                 ".env.example", "verification/signing/production-upload-certificate.pem",
                 "verification/signing/production-upload-certificate.json"]
        self.assertEqual(self.ignored(paths), set())
        certificate = (ROOT / "verification/signing/production-upload-certificate.pem").read_text(encoding="ascii")
        self.assertTrue(certificate.startswith("-----BEGIN CERTIFICATE-----\n"))
        self.assertNotIn("PRIVATE KEY", certificate)

    def test_existing_local_binary_and_private_key_paths_are_ignored_without_reading_them(self):
        private_extensions = {".aab", ".apk", ".apks", ".jks", ".keystore", ".p12", ".pfx", ".key", ".pk8", ".der"}
        paths = [path.relative_to(ROOT).as_posix() for path in ROOT.rglob("*")
                 if path.is_file() and path.suffix.lower() in private_extensions]
        self.assertTrue(paths, "Expected the existing local APKs and dedicated upload key")
        self.assertEqual(self.ignored(paths), set(paths))


if __name__ == "__main__":
    unittest.main()
