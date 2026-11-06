"""Private AAB-workflow regressions; fake keys/builds only, never the real key."""

from contextlib import redirect_stderr, redirect_stdout
from email.message import Message
import hashlib
import io
import json
import os
from pathlib import Path
import subprocess
import sys
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import MagicMock, patch
from urllib.error import URLError
from urllib.request import Request

import build_signed_aab as signed

URL = "https://findit-hidden-policy-fixture.github.io/privacy-policy.html"
SECRET = "disposable-unit-test-password-not-a-real-key"
CERTIFICATE = b"disposable public certificate fixture"
PIN = hashlib.sha256(CERTIFICATE).hexdigest()
HTML = "<!doctype html>\n<html><body>Complete generated policy fixture</body></html>\n"
BUNDLE = b"disposable synthetic bundle, not a runnable app"
MAPPING = b"fixture.Type -> a:\n"


class SignedWorkflowTests(unittest.TestCase):
    def setUp(self):
        parent = signed.ROOT / "build/verification-tests"
        parent.mkdir(parents=True, exist_ok=True)
        temporary = TemporaryDirectory(prefix="findit-signed-workflow-", dir=parent)
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        (self.root / "android/app").mkdir(parents=True)
        (self.root / "android/app/build.gradle.kts").write_text(
            'applicationId = "abiral.mobile.findithiddenobjects"', encoding="utf-8")
        (self.root / "config").mkdir()
        (self.root / ".local-signing").mkdir()
        self.key = self.root / ".local-signing/findit-hidden-objects-upload.p12"
        self.key.write_bytes(b"test-owned encrypted-key fixture")
        (self.key.parent / ".findit-hidden-signing").write_text(signed.key_setup.DIRECTORY_MARKER, encoding="utf-8")
        self.flutter = self.root / "sdk/bin/flutter.bat"
        self.flutter.parent.mkdir(parents=True)
        self.flutter.write_bytes(b"test-owned executable fixture")
        patches = [patch.object(signed, "ROOT", self.root),
                   patch.object(signed.inspector, "production_certificate_pin", return_value=PIN),
                   patch.object(signed.policy, "check_html", return_value={"status": "passed"}),
                   patch.object(signed.policy, "expected_html", return_value=HTML),
                   patch.object(signed, "flutter_executable", return_value=self.flutter),
                   patch.object(signed.key_setup, "_keytool", return_value="keytool"),
                   patch.dict(os.environ, {"PATH": "test-only-path", "FINDIT_ORIGINAL_STORE_PASSWORD": "unrelated-fixture"}, clear=True)]
        for replacement in patches:
            replacement.start()
            self.addCleanup(replacement.stop)

    def build(self):
        return signed.build_signed_aab(URL, SECRET, backup_confirmed=True, publisher_review_confirmed=True)

    def fake_command(self, arguments, *, cwd, env, capture_output, check):
        self.assertEqual(cwd, self.root)
        self.assertTrue(capture_output)
        self.assertFalse(check)
        self.assertNotIn(SECRET, " ".join(arguments))
        self.assertNotIn("FINDIT_ORIGINAL_STORE_PASSWORD", env)
        self.calls.append((list(arguments), dict(env)))
        if arguments[0] == "keytool":
            self.assertIn("-exportcert", arguments)
            self.assertNotIn("-genkeypair", arguments)
            self.assertEqual(env["FINDIT_HIDDEN_STORE_PASSWORD"], SECRET)
            return subprocess.CompletedProcess(arguments, 0, CERTIFICATE, SECRET.encode())
        if arguments[1:3] == ["build", "appbundle"]:
            self.assertEqual(env["FINDIT_HIDDEN_KEY_ALIAS"], "findit-hidden-upload")
            self.assertEqual(Path(env["FINDIT_HIDDEN_STORE_FILE"]), self.key)
            self.assertIn("-Dorg.gradle.daemon=false", env["GRADLE_OPTS"])
            self.assertNotIn("unsignedProductionCandidate", " ".join(arguments))
            bundle = self.root / "build/app/outputs/bundle/prodRelease/app-prod-release.aab"
            bundle.parent.mkdir(parents=True, exist_ok=True)
            bundle.write_bytes(BUNDLE)
            mapping = self.root / "build/app/outputs/mapping/prodRelease"
            mapping.mkdir(parents=True, exist_ok=True)
            for name in signed.R8_FILES:
                (mapping / name).write_bytes(MAPPING if name == "mapping.txt" else b"test-owned R8 evidence")
        else:
            self.assertEqual(arguments[0], sys.executable)
            self.assertIn("signed-production-aab", arguments)
            self.assertTrue(all(name not in env for name in signed.SIGNING_VARIABLES))
            artifact = {"status": "passed", "type": "aab", "profile": "signed-production-aab",
                        "sha256": hashlib.sha256(BUNDLE).hexdigest(), "jarSignatureVerified": True,
                        "certificateSha256": [PIN],
                        "bundledR8MappingMatch": {"status": "passed", "sha256": hashlib.sha256(MAPPING).hexdigest()}}
            output = Path(arguments[arguments.index("--output") + 1])
            signed.write_json(output, {"profile": "signed-production-aab", "artifacts": [artifact]})
        return subprocess.CompletedProcess(arguments, 0, SECRET.encode(), SECRET.encode())

    def assert_no_saved_secret(self):
        for path in self.root.rglob("*"):
            if path.is_file():
                self.assertNotIn(SECRET.encode(), path.read_bytes(), str(path.relative_to(self.root)))

    def test_complete_fake_workflow_reuses_key_checks_signature_retains_mapping_and_never_logs_password(self):
        self.calls = []
        output = io.StringIO()
        before = dict(os.environ)
        with patch.object(signed, "verify_live_policy", return_value={"status": "passed", "completeCanonicalHtmlMatches": True}), \
                patch.object(signed.subprocess, "run", side_effect=self.fake_command), \
                patch.object(signed.key_setup, "create_upload_key") as create, \
                redirect_stdout(output), redirect_stderr(output):
            directory = self.build()
        create.assert_not_called()
        self.assertEqual(len(self.calls), 3)
        self.assertEqual(dict(os.environ), before)
        self.assertEqual(self.key.read_bytes(), b"test-owned encrypted-key fixture")
        self.assertEqual((directory / "FindIt-Hidden-Objects-1.0.0.aab").read_bytes(), BUNDLE)
        self.assertEqual((directory / "r8/mapping.txt").read_bytes(), MAPPING)
        self.assertEqual(json.loads((directory / "build-status.json").read_text())["status"], "passed")
        for line in (directory / "SHA256SUMS.txt").read_text().splitlines():
            digest, name = line.split("  ", 1)
            self.assertEqual(hashlib.sha256((directory / name).read_bytes()).hexdigest(), digest)
        self.assertFalse((self.key.parent / ".signed-aab-build.lock").exists())
        self.assertNotIn(SECRET, output.getvalue())
        self.assert_no_saved_secret()

    def test_failed_build_does_not_inspect_or_retain_existing_stale_bundle(self):
        self.calls = []
        bundle = self.root / "build/app/outputs/bundle/prodRelease/app-prod-release.aab"
        bundle.parent.mkdir(parents=True)
        bundle.write_bytes(b"older publisher output")

        def command(arguments, **kwargs):
            if arguments[1:3] == ["build", "appbundle"]:
                self.calls.append((list(arguments), dict(kwargs["env"])))
                return subprocess.CompletedProcess(arguments, 1, SECRET.encode(), SECRET.encode())
            return self.fake_command(arguments, **kwargs)

        with patch.object(signed, "verify_live_policy", return_value={"status": "passed"}), \
                patch.object(signed.subprocess, "run", side_effect=command):
            with self.assertRaisesRegex(ValueError, "no credentials") as failure:
                self.build()
        self.assertNotIn(SECRET, str(failure.exception))
        self.assertEqual(len(self.calls), 2)
        self.assertEqual(bundle.read_bytes(), b"older publisher output")
        self.assertEqual(list((self.root / "release").rglob("*.aab")), [])
        statuses = list((self.root / "release").rglob("build-status.json"))
        self.assertEqual(json.loads(statuses[0].read_text())["status"], "failed")
        self.assertFalse((self.key.parent / ".signed-aab-build.lock").exists())
        self.assert_no_saved_secret()

    def test_wrong_certificate_fails_before_config_or_build_and_never_recreates_key(self):
        with patch.object(signed, "verify_live_policy", return_value={"status": "passed"}), \
                patch.object(signed.subprocess, "run", return_value=subprocess.CompletedProcess(["keytool"], 0, b"wrong certificate", b"")) as command, \
                patch.object(signed.key_setup, "create_upload_key") as create:
            with self.assertRaisesRegex(ValueError, "pinned public"):
                self.build()
        self.assertEqual(command.call_count, 1)
        create.assert_not_called()
        self.assertFalse((self.root / "config/production.json").exists())
        self.assertEqual(self.key.read_bytes(), b"test-owned encrypted-key fixture")

    def test_missing_approvals_empty_password_and_invalid_url_do_not_open_key_or_build(self):
        with patch.object(signed.subprocess, "run") as command:
            for kwargs in ({}, {"backup_confirmed": True}, {"publisher_review_confirmed": True}):
                with self.assertRaises(ValueError):
                    signed.build_signed_aab(URL, SECRET, **kwargs)
            for url, password in (("", SECRET), ("http://publisher.github.io/policy", SECRET), (URL, ""), (URL + "/" + SECRET, SECRET)):
                with self.assertRaises(ValueError):
                    signed.build_signed_aab(url, password, backup_confirmed=True, publisher_review_confirmed=True)
        command.assert_not_called()
        self.assertFalse((self.root / "config/production.json").exists())

    def test_local_preflight_rejects_missing_unfamiliar_or_original_key_configuration(self):
        with patch.dict(os.environ, {"FINDIT_HIDDEN_KEY_ALIAS": "androiddebugkey"}):
            with self.assertRaises(ValueError):
                signed.local_preflight()
        with patch.dict(os.environ, {"FINDIT_HIDDEN_STORE_FILE": str(self.root / "original-app/old-key.p12")}):
            with self.assertRaises(ValueError):
                signed.local_preflight()
        marker = self.key.parent / ".findit-hidden-signing"
        marker.write_text("publisher-owned unfamiliar directory", encoding="utf-8")
        with self.assertRaises(ValueError):
            signed.local_preflight()
        self.assertEqual(marker.read_text(), "publisher-owned unfamiliar directory")
        self.key.unlink()  # This test's disposable fake key only.
        with self.assertRaises(ValueError):
            signed.local_preflight()

    def test_existing_config_and_active_build_lock_are_not_overwritten(self):
        path, value = signed.production_config(URL)
        signed.persist_config(path, value)
        original = path.read_bytes()
        with self.assertRaisesRegex(ValueError, "not overwritten"):
            signed.production_config("https://publisher.github.io/different-policy.html")
        self.assertEqual(path.read_bytes(), original)
        lock = self.key.parent / ".signed-aab-build.lock"
        lock.write_text("publisher-owned active lock", encoding="ascii")
        with self.assertRaisesRegex(ValueError, "lock already exists"):
            with signed.build_lock():
                self.fail("An active lock was ignored")
        self.assertEqual(lock.read_text(), "publisher-owned active lock")

    def test_check_only_reads_no_password_does_not_open_key_build_or_use_network(self):
        with patch.object(sys, "argv", ["build_signed_aab.py", "--check-only"]), \
                patch.object(signed, "private_command") as command, \
                patch.object(signed, "verify_live_policy") as network, \
                patch.object(signed.getpass, "getpass") as prompt, \
                redirect_stdout(io.StringIO()):
            self.assertEqual(signed.main(), 0)
        command.assert_not_called()
        network.assert_not_called()
        prompt.assert_not_called()

    def test_private_command_errors_never_echo_secret_output(self):
        result = subprocess.CompletedProcess(["keytool"], 1, SECRET.encode(), SECRET.encode())
        with patch.object(signed.subprocess, "run", return_value=result):
            with self.assertRaises(ValueError) as failure:
                signed.private_command(["keytool"], {"FINDIT_HIDDEN_STORE_PASSWORD": SECRET}, "Existing key verification")
        self.assertNotIn(SECRET, str(failure.exception))

    def response(self, content, *, content_type="text/html", status=200, disposition=""):
        response = MagicMock()
        response.__enter__.return_value = response
        response.geturl.return_value = URL
        response.status = status
        response.headers = Message()
        response.headers["Content-Type"] = content_type
        response.headers["Content-Disposition"] = disposition
        response.read.side_effect = io.BytesIO(content).read
        opener = MagicMock()
        opener.open.return_value = response
        return opener

    def test_hosted_policy_is_exact_html_with_only_bom_crlf_normalization(self):
        content = b"\xef\xbb\xbf" + HTML.replace("\n", "\r\n").encode()
        with patch.object(signed, "require_public_endpoint"), \
                patch.object(signed, "build_opener", return_value=self.response(content)):
            result = signed.verify_live_policy(URL)
        self.assertTrue(result["completeCanonicalHtmlMatches"])
        self.assertEqual(result["downloadSha256"], hashlib.sha256(content).hexdigest())

    def test_incomplete_changed_download_or_login_policy_is_not_accepted(self):
        for content, kwargs in ((b"login page", {}), (HTML.replace("Complete", "Changed").encode(), {}),
                                (HTML.encode(), {"content_type": "application/octet-stream"}),
                                (HTML.encode(), {"status": 401}), (HTML.encode(), {"disposition": "attachment"}),
                                (b"x" * (signed.MAX_POLICY_BYTES + 1), {})):
            with self.subTest(kwargs=kwargs), patch.object(signed, "require_public_endpoint"), \
                    patch.object(signed, "build_opener", return_value=self.response(content, **kwargs)), self.assertRaises(ValueError):
                signed.verify_live_policy(URL)

    def test_network_failure_does_not_print_or_serialize_response_or_secrets(self):
        opener = MagicMock()
        opener.open.side_effect = URLError(SECRET)
        with patch.object(signed, "require_public_endpoint"), patch.object(signed, "build_opener", return_value=opener):
            with self.assertRaises(ValueError) as failure:
                signed.verify_live_policy(URL)
        self.assertNotIn(SECRET, str(failure.exception))

    def test_private_dns_and_non_https_redirects_are_rejected(self):
        address = [(2, 1, 6, "", ("127.0.0.1", 443))]
        with patch.object(signed.socket, "getaddrinfo", return_value=address), self.assertRaisesRegex(ValueError, "private or reserved"):
            signed.require_public_endpoint(URL)
        with self.assertRaises(ValueError):
            signed.PublicHttpsRedirects().redirect_request(Request(URL), None, 302, "redirect", {}, "http://publisher.github.io/policy")
        for url in (URL + "#contact", "https://user:password@publisher.github.io/policy", "https://localhost/policy", "https://example.com/policy", URL + "\nother"):
            with self.subTest(url=url), self.assertRaises(ValueError):
                signed.validate_policy_url(url)


if __name__ == "__main__":
    unittest.main()
