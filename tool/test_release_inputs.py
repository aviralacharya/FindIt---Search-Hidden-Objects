"""Checks for private local signing setup; no real key or password is used."""

import base64
import hashlib
import json
from pathlib import Path
import struct
import subprocess
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch
import zlib

import prepare_release_inputs as setup


def png_chunk(kind, data):
    return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)


def png_fixture(width=512, height=512, animated=False):
    header = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    data = b"\x89PNG\r\n\x1a\n" + png_chunk(b"IHDR", header)
    if animated:
        data += png_chunk(b"acTL", struct.pack(">II", 2, 0))
    data += png_chunk(b"IDAT", zlib.compress((b"\0" + b"\xff\xff\xff\xff" * width) * height))
    return data + png_chunk(b"IEND", b"")


class PrivateReleaseInputTests(unittest.TestCase):
    def setUp(self):
        temporary_root = setup.ROOT / "build/verification-tests"
        temporary_root.mkdir(parents=True, exist_ok=True)
        self.temporary = TemporaryDirectory(prefix="findit-private-setup-", dir=temporary_root)
        self.addCleanup(self.temporary.cleanup)
        root = Path(self.temporary.name)
        (root / "android/app").mkdir(parents=True)
        (root / "android/app/build.gradle.kts").write_text(
            'applicationId = "abiral.mobile.findithiddenobjects"', encoding="utf-8")
        key_directory = root / ".local-signing"
        certificate = root / "verification/signing/production-upload-certificate.pem"
        self.constants = patch.multiple(setup, ROOT=root,
                                        ICON_SOURCE=root / "assets/branding/icon_source.png",
                                        KEY_DIRECTORY=key_directory,
                                        KEYSTORE=key_directory / "findit-hidden-objects-upload.p12",
                                        CERTIFICATE=certificate,
                                        CERTIFICATE_REPORT=certificate.with_suffix(".json"))
        self.constants.start()
        self.addCleanup(self.constants.stop)

    def test_square_original_png_dimensions_and_checksums(self):
        self.assertEqual(setup.validate_icon_png(png_fixture()), {"width": 512, "height": 512})
        self.assertEqual(setup.validate_icon_png(png_fixture(1254, 1254))["width"], 1254)

    def test_rejects_bad_checksums_headers_dimensions_and_animation(self):
        original = png_fixture()
        corrupt = bytearray(original)
        corrupt[29] ^= 1
        for data in (b"not png", bytes(corrupt), original[:-1], original + b"extra",
                     png_fixture(512, 513), png_fixture(511, 511), png_fixture(animated=True)):
            with self.subTest(size=len(data)), self.assertRaises(ValueError):
                setup.validate_icon_png(data)

    def test_import_preserves_original_bytes_and_is_idempotent(self):
        source = setup.ROOT / "publisher.png"
        data = png_fixture()
        source.write_bytes(data)
        report = setup.import_icon(source)
        self.assertEqual(setup.ICON_SOURCE.read_bytes(), data)
        self.assertEqual(source.read_bytes(), data)
        self.assertEqual(report["sha256"], hashlib.sha256(data).hexdigest())
        self.assertEqual(setup.import_icon(source), report)

    def test_import_does_not_overwrite_an_unfamiliar_source(self):
        source = setup.ROOT / "publisher.png"
        source.write_bytes(png_fixture())
        setup.ICON_SOURCE.parent.mkdir(parents=True)
        setup.ICON_SOURCE.write_bytes(b"publisher work")
        with self.assertRaisesRegex(ValueError, "not overwritten"):
            setup.import_icon(source)
        self.assertEqual(setup.ICON_SOURCE.read_bytes(), b"publisher work")

    def test_invalid_icon_does_not_create_a_signing_key(self):
        with patch.object(setup, "create_upload_key") as generate:
            with self.assertRaises(ValueError):
                setup.prepare(setup.ROOT / "missing.png", "unit-test-password")
            generate.assert_not_called()

    def test_existing_key_and_certificate_records_cannot_be_overwritten(self):
        for path in (setup.KEYSTORE, setup.CERTIFICATE, setup.CERTIFICATE_REPORT):
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(b"publisher work")
            with self.subTest(path=path), self.assertRaisesRegex(ValueError, "nothing was overwritten"):
                setup.create_upload_key("unit-test-password")
            self.assertEqual(path.read_bytes(), b"publisher work")
            path.unlink()

    def test_unfamiliar_key_directory_is_not_changed(self):
        setup.KEY_DIRECTORY.mkdir()
        work = setup.KEY_DIRECTORY / "publisher.txt"
        work.write_text("keep me", encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "unfamiliar"):
            setup._private_directory()
        self.assertEqual(work.read_text(), "keep me")

    def test_weak_password_and_wrong_project_identity_fail_before_key_creation(self):
        with self.assertRaisesRegex(ValueError, "eight"):
            setup.create_upload_key("short")
        (setup.ROOT / "android/app/build.gradle.kts").write_text('applicationId = "original.app"', encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "independent hidden-object"):
            setup.create_upload_key("unit-test-password")
        self.assertFalse(setup.KEY_DIRECTORY.exists())

    def test_key_generation_passes_only_environment_names_to_keytool(self):
        secret = "unit-test-password"
        certificate = b"unit test public certificate fixture"
        captured = []

        def command(arguments, environment):
            captured.append(list(arguments))
            self.assertNotIn(secret, " ".join(arguments))
            self.assertEqual(environment[setup.PASSWORD_VARIABLE], secret)
            if "-genkeypair" in arguments:
                Path(arguments[arguments.index("-keystore") + 1]).write_bytes(b"unit test encrypted keystore fixture")
                return ""
            return "-----BEGIN CERTIFICATE-----\n" + base64.b64encode(certificate).decode("ascii") + "\n-----END CERTIFICATE-----\n"

        with patch.object(setup, "_keytool", return_value="keytool"), \
                patch.object(setup, "_restrict_directory"), \
                patch.object(setup, "_sensitive_command", side_effect=command):
            result = setup.create_upload_key(secret)
        self.assertEqual(len(captured), 2)
        self.assertEqual(result["certificateSha256"], hashlib.sha256(certificate).hexdigest())
        self.assertTrue(setup.KEYSTORE.exists())
        self.assertIn("3072", captured[0])
        self.assertIn("PKCS12", captured[0])
        self.assertIn("-storepass:env", captured[0])
        self.assertNotIn(secret, setup.CERTIFICATE_REPORT.read_text())
        self.assertEqual(json.loads(setup.CERTIFICATE_REPORT.read_text())["keyAlias"], setup.KEY_ALIAS)

    def test_credential_subprocess_failure_does_not_echo_output(self):
        result = subprocess.CompletedProcess(["keytool"], 1, "unit-test-secret", "unit-test-secret")
        with patch.object(setup.subprocess, "run", return_value=result):
            with self.assertRaisesRegex(ValueError, "exit 1") as failure:
                setup._sensitive_command(["keytool"], {"SECRET": "unit-test-secret"})
        self.assertNotIn("unit-test-secret", str(failure.exception))


if __name__ == "__main__":
    unittest.main()
