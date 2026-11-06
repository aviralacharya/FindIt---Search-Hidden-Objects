"""Compiled-resource and cryptographic regressions for the final AAB inspector.

Synthetic bundles are not runnable apps. JDK crypto tests use disposable test-only
keys, with random passwords held only in child environments. The production key
is never opened, modified, or used here.
"""

import hashlib
import json
import os
from pathlib import Path
import secrets
import shutil
import struct
import subprocess
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch
import xml.etree.ElementTree as ET
import zipfile
import zlib

from test_android_artifacts import dex_fixture
import verify_android_artifacts as inspector

ROOT = inspector.ROOT
CONFIG = {"APP_ENV": "production", "BUILD_STAGE": "final", "PACK_INDEX_URL": "",
          "PRIVACY_POLICY_URL": "https://findit-hidden-policy-fixture.github.io/policy/privacy-policy.html"}
RESOURCE_IDS = {"mipmap/ic_launcher": 0x7f010000, "drawable/ic_launcher_foreground": 0x7f020000,
                "drawable/ic_launcher_monochrome": 0x7f020001, "color/ic_launcher_background": 0x7f030000,
                "xml/data_extraction_rules": 0x7f040000}


def varint(value):
    data = bytearray()
    while value >= 128:
        data.append((value & 127) | 128)
        value >>= 7
    data.append(value)
    return bytes(data)


def proto(number, value):
    if isinstance(value, str):
        value = value.encode("utf-8")
    if isinstance(value, bytes):
        return varint(number * 8 + 2) + varint(len(value)) + value
    return varint(number * 8) + varint(value)


def scalar(value):
    if isinstance(value, bool):
        return proto(7, proto(8, int(value)))
    if isinstance(value, int):
        return proto(7, proto(6, value))
    if value.startswith("@0x"):
        return proto(1, proto(2, int(value[1:], 16)))
    return proto(2, proto(1, value))


def xml_fixture(name, attributes=(), children=(), namespace=""):
    fields = proto(3, name) + (proto(2, namespace) if namespace else b"")
    for key, uri, value in attributes:
        attribute = proto(2, key) + proto(3, str(value)) + proto(6, scalar(value))
        if uri:
            attribute += proto(1, uri)
        fields += proto(4, attribute)
    fields += b"".join(proto(5, child) for child in children)
    return proto(1, fields)


def source_xml_fixture(path):
    def convert(element):
        attributes = []
        for key, value in element.attrib.items():
            uri, key = key[1:].split("}", 1) if key.startswith("{") else ("", key)
            if value.startswith("@"):
                value = f"@0x{RESOURCE_IDS[value[1:]]:08x}"
            attributes.append((key, uri, value))
        return xml_fixture(element.tag, attributes, [convert(child) for child in element])
    return convert(ET.fromstring(Path(path).read_bytes()))


def manifest_fixture(config=None, changes=None):
    config = CONFIG if config is None else config
    changes = changes or {}
    uri = inspector.ANDROID_NAMESPACE
    app = {"label": "FindIt Hidden", "icon": "@0x7f010000", "allowBackup": False,
           "fullBackupContent": False, "usesCleartextTraffic": False,
           "dataExtractionRules": "@0x7f040000", **changes.get("application", {})}
    metadata = [xml_fixture("meta-data", [("name", uri, "findit.hidden." + key), ("value", uri, value)])
                for key, value in config.items()]
    children = [xml_fixture("uses-sdk", [("minSdkVersion", uri, 24), ("targetSdkVersion", uri, 36)]),
                xml_fixture("uses-permission", [("name", uri, "android.permission.INTERNET")]),
                xml_fixture("application", [(key, uri, value) for key, value in app.items()], metadata)]
    return xml_fixture("manifest", [("package", "", changes.get("package", inspector.PRODUCTION_PACKAGE)),
                                    ("versionName", uri, changes.get("versionName", "1.0.0")),
                                    ("versionCode", uri, changes.get("versionCode", 1))], children)


def resources_fixture():
    payloads, types = {}, {}
    for name, identifier in RESOURCE_IDS.items():
        kind, basename = name.split("/")
        variants = []
        if kind in ("mipmap", "drawable"):
            for density, qualifier in ((160, "mdpi"), (240, "hdpi"), (320, "xhdpi"), (480, "xxhdpi"), (640, "xxxhdpi")):
                path = f"res/{kind}-{qualifier}-v4/{basename}.png"
                payloads["base/" + path] = (ROOT / f"android/app/src/main/res/{kind}-{qualifier}/{basename}.png").read_bytes()
                variants.append((proto(18, density) + proto(24, 4), proto(5, proto(1, path) + proto(2, 1))))
            if kind == "mipmap":
                path = "res/mipmap-anydpi-v26/ic_launcher.xml"
                payloads["base/" + path] = source_xml_fixture(ROOT / "android/app/src/main" / path)
                variants.append((proto(18, 65534) + proto(24, 26), proto(5, proto(1, path) + proto(2, 3))))
        elif kind == "color":
            variants.append((b"", proto(7, proto(9, 0xfffbf7ee))))
        else:
            path = "res/xml/data_extraction_rules.xml"
            payloads["base/" + path] = source_xml_fixture(ROOT / "android/app/src/main" / path)
            variants.append((b"", proto(5, proto(1, path) + proto(2, 3))))
        entry = proto(1, proto(1, identifier & 65535)) + proto(2, basename)
        for config, item in variants:
            entry += proto(6, proto(1, config) + proto(2, proto(4, item)))
        type_id = (identifier >> 16) & 255
        types.setdefault((type_id, kind), []).append(entry)
    package = proto(1, proto(1, 127)) + proto(2, inspector.PRODUCTION_PACKAGE)
    for (identifier, name), entries in types.items():
        package += proto(3, proto(1, proto(1, identifier)) + proto(2, name) + b"".join(proto(3, entry) for entry in entries))
    payloads["base/resources.pb"] = proto(2, package)
    return payloads


def elf_fixture():
    data = bytearray(64 + 56)
    data[:6] = b"\x7fELF\x02\x01"
    struct.pack_into("<Q", data, 32, 64)
    struct.pack_into("<HH", data, 54, 56, 1)
    struct.pack_into("<I", data, 64, 1)
    struct.pack_into("<QQ", data, 72, 16384, 32768)
    struct.pack_into("<Q", data, 112, 16384)
    return bytes(data)


def write_zip(path, entries):
    with zipfile.ZipFile(path, "w", compression=zipfile.ZIP_DEFLATED) as archive:
        for name, data in entries.items():
            archive.writestr(name, data)


class CompiledBundleTests(unittest.TestCase):
    def setUp(self):
        temporary_root = ROOT / "build/verification-tests"
        temporary_root.mkdir(parents=True, exist_ok=True)
        temporary = TemporaryDirectory(prefix="findit-bundle-tests-", dir=temporary_root)
        self.addCleanup(temporary.cleanup)
        self.directory = Path(temporary.name)

    def test_compiled_manifest_identity_version_namespace_and_release_inputs(self):
        summary = inspector.bundle_manifest_summary(manifest_fixture())
        inspector.validate_signed_bundle_manifest(summary, CONFIG)
        self.assertEqual(summary["applicationLabel"], "FindIt Hidden")
        self.assertEqual(summary["versionCode"], "1")
        self.assertEqual(summary["applicationIconResource"], "@0x7f010000")
        for changes in ({"package": "original.app"}, {"versionName": "1.0.1"}, {"versionCode": 2},
                        {"application": {"label": "Old label"}}, {"application": {"allowBackup": True}},
                        {"application": {"debuggable": True}}):
            with self.subTest(changes=changes), self.assertRaises(ValueError):
                inspector.validate_signed_bundle_manifest(inspector.bundle_manifest_summary(manifest_fixture(changes=changes)), CONFIG)
        different = {**CONFIG, "BUILD_STAGE": "unsigned-candidate"}
        with self.assertRaisesRegex(ValueError, "release inputs"):
            inspector.validate_signed_bundle_manifest(inspector.bundle_manifest_summary(manifest_fixture(different)), CONFIG)
        invalid = xml_fixture("manifest", [("package", "", inspector.PRODUCTION_PACKAGE), ("versionCode", "", 1)],
                              [xml_fixture("application")])
        with self.assertRaisesRegex(ValueError, "namespace"):
            inspector.bundle_manifest_summary(invalid)

    def test_duplicate_compiled_attributes_and_release_metadata_are_rejected(self):
        uri = inspector.ANDROID_NAMESPACE
        with self.assertRaisesRegex(ValueError, "Duplicate"):
            inspector.bundle_xml_node(xml_fixture("application", [("label", uri, "a"), ("label", uri, "b")]))
        metadata = xml_fixture("meta-data", [("name", uri, "findit.hidden.APP_ENV"), ("value", uri, "production")])
        manifest = xml_fixture("manifest", [("package", "", inspector.PRODUCTION_PACKAGE)],
                               [xml_fixture("application", children=[metadata, metadata])])
        with self.assertRaisesRegex(ValueError, "Duplicate"):
            inspector.bundle_manifest_summary(manifest)

    def test_protobuf_scalars_reject_theme_references_ambiguity_and_invalid_alignment(self):
        for data in (proto(2, b"") + proto(7, proto(8, 1)), proto(1, proto(1, 1) + proto(2, 0x7f010000)), proto(7, proto(8, 2))):
            with self.subTest(data=data), self.assertRaises(ValueError):
                inspector.proto_item_value(data)
        for data in (b"\x00", b"\x12\x01", proto(2, b"") + proto(2, b""), proto(2, proto(2, proto(1, 2)))):
            with self.subTest(data=data), self.assertRaises(ValueError):
                inspector.bundle_native_alignment(data)

    def test_final_config_rejects_missing_or_extra_inputs_placeholders_and_remote_packs(self):
        path = self.directory / "config.json"
        path.write_text(json.dumps(CONFIG), encoding="utf-8")
        self.assertEqual(inspector.load_production_config(path), CONFIG)
        variants = [{key: value for key, value in CONFIG.items() if key != "BUILD_STAGE"}, {**CONFIG, "PASSWORD": "not-a-real-secret"},
                    {**CONFIG, "BUILD_STAGE": "qa"}, {**CONFIG, "PACK_INDEX_URL": "remote"}]
        for url in ("", "http://publisher.github.io/policy.html", "https://example.com", "https://127.0.0.1/", "https://localhost/", "https://user:pass@publisher.github.io/", " https://publisher.github.io/"):
            variants.append({**CONFIG, "PRIVACY_POLICY_URL": url})
        for value in variants:
            path.write_text(json.dumps(value), encoding="utf-8")
            with self.subTest(value=value), self.assertRaises(ValueError):
                inspector.load_production_config(path)

    def test_public_pin_matches_certificate_record_and_gradle_and_rejects_qa_pin(self):
        pin = inspector.production_certificate_pin()
        self.assertEqual(pin, "e4d765e9c1676c9acfa95560b78177754e35fafc77dcb990dbf2e7ac2c999114")
        self.assertEqual(inspector.production_certificate_pin(pin.upper()), pin)
        with self.assertRaises(ValueError):
            inspector.production_certificate_pin("b08451266f6a68fa07cc2cf4da0112d0c755b77a671a46b2c7980bc8b920b594")

    def test_every_compiled_launcher_density_and_backup_xml_matches_current_source(self):
        path = self.directory / "resources.aab"
        write_zip(path, resources_fixture())
        with zipfile.ZipFile(path) as archive:
            self.assertEqual(inspector.bundle_launcher_summary(archive, "@0x7f010000")["matchingPngVariants"], 15)
            self.assertEqual(len(inspector.bundle_backup_rules_summary(archive, "@0x7f040000")["cloudBackupAndDeviceTransferExcludedDomains"]), 5)

    def test_launcher_rejects_wrong_reference_changed_pixels_and_missing_themed_icon(self):
        original = resources_fixture()
        path = self.directory / "resources.aab"
        write_zip(path, original)
        with zipfile.ZipFile(path) as archive, self.assertRaises(ValueError):
            inspector.bundle_launcher_summary(archive, "@0x7f040000")
        for entry, value in (("base/res/drawable-mdpi-v4/ic_launcher_foreground.png", original["base/res/drawable-mdpi-v4/ic_launcher_monochrome.png"]),
                             ("base/res/mipmap-anydpi-v26/ic_launcher.xml", xml_fixture("adaptive-icon"))):
            write_zip(path, {**original, entry: value})
            with zipfile.ZipFile(path) as archive, self.assertRaises(ValueError):
                inspector.bundle_launcher_summary(archive, "@0x7f010000")

    def test_compiled_backup_rules_reject_removed_exclusions_and_added_transfer_includes(self):
        original = resources_fixture()
        path = self.directory / "resources.aab"
        for xml in (xml_fixture("data-extraction-rules"), xml_fixture("data-extraction-rules", children=[xml_fixture("device-transfer", children=[xml_fixture("include", [("domain", "", "database"), ("path", "", ".")])])])):
            write_zip(path, {**original, "base/res/xml/data_extraction_rules.xml": xml})
            with zipfile.ZipFile(path) as archive, self.assertRaisesRegex(ValueError, "backup/transfer exclusions"):
                inspector.bundle_backup_rules_summary(archive, "@0x7f040000")

    def test_source_assets_are_byte_exact_and_missing_or_changed_policy_fails(self):
        source = self.directory / "assets/legal"
        source.mkdir(parents=True)
        (source / "privacy-policy.json").write_bytes(b"canonical fixture")
        path = self.directory / "assets.aab"
        for value in (b"canonical fixture", b"changed fixture"):
            write_zip(path, {"base/assets/flutter_assets/assets/legal/privacy-policy.json": value})
            with patch.object(inspector, "ROOT", self.directory), zipfile.ZipFile(path) as archive:
                if value == b"canonical fixture":
                    self.assertEqual(inspector.source_assets_summary(archive, "base/assets/flutter_assets/")["matchingAssets"], 1)
                else:
                    with self.assertRaises(ValueError):
                        inspector.source_assets_summary(archive, "base/assets/flutter_assets/")

    def test_png_decoder_handles_all_filters_and_transparent_pixel_repacking(self):
        def chunk(kind, data):
            return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xffffffff)
        def png(raw):
            return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", 2, 1, 8, 6, 0, 0, 0))
                    + chunk(b"IDAT", zlib.compress(raw)) + chunk(b"IEND", b""))
        expected = b"\x03\x05\x07\xff\0\0\0\0"
        for mode in range(5):
            row = b"\x03\x05\x07\xff\x0b\x0d\x11\0"
            filtered = bytearray(row)
            for x in range(4, 8):
                left = row[x - 4]
                filtered[x] = (row[x] - (left if mode in (1, 4) else left // 2 if mode == 3 else 0)) & 255
            self.assertEqual(inspector.png_rendered_rgba(png(bytes([mode]) + filtered)), (2, 1, expected))
        with self.assertRaises(ValueError):
            inspector.png_rendered_rgba(png(b"\5" + row))

    def test_signed_profile_cannot_skip_final_inputs_or_matching_mapping(self):
        for arguments in ({}, {"r8_mapping": "mapping.txt"}, {"production_config": "config.json"}):
            with self.assertRaisesRegex(ValueError, "matching R8 mapping"):
                inspector.inspect_artifact(Path("nonexistent.aab"), None, profile="signed-production-aab", **arguments)


@unittest.skipUnless(all(shutil.which(tool) for tool in ("java", "javac", "keytool", "jarsigner")), "JDK 17 tools are required for cryptographic regressions")
class CryptographicBundleTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        temporary_root = ROOT / "build/verification-tests"
        temporary_root.mkdir(parents=True, exist_ok=True)
        temporary = TemporaryDirectory(prefix="findit-signature-tests-", dir=temporary_root)
        cls.addClassCleanup(temporary.cleanup)
        cls.directory = Path(temporary.name)
        cls.environment = dict(os.environ)
        cls.environment["FINDIT_SIGNATURE_TEST_PASSWORD"] = secrets.token_urlsafe(32)
        cls.addClassCleanup(cls.environment.pop, "FINDIT_SIGNATURE_TEST_PASSWORD", None)
        cls._command([shutil.which("javac"), "-d", str(cls.directory), str(ROOT / "tool/VerifyBundleSignature.java")])
        cls.pin = cls._key("fixture", "CN=FindIt Signature Regression Fixture")
        cls.debug_pin = cls._key("debug-fixture", "CN=Android Debug, O=Android, C=US")
        cls.weak_pin = cls._key("weak-fixture", "CN=Weak Regression Fixture", size=1024)
        cls.expired_pin = cls._key("expired-fixture", "CN=Expired Regression Fixture", startdate="-400d", validity=1)
        cls.payloads = {"BundleConfig.pb": b"fixture", "base/manifest/AndroidManifest.xml": b"compiled fixture",
                        "base/assets/flutter_assets/policy.json": b"offline fixture", "META-INF/app-metadata.properties": b"signed metadata"}
        cls.unsigned = cls.directory / "unsigned.aab"
        write_zip(cls.unsigned, cls.payloads)
        cls.signed = cls._sign("fixture", cls.unsigned, "signed.aab")

    @classmethod
    def _command(cls, arguments):
        result = subprocess.run(arguments, env=cls.environment, capture_output=True, timeout=90)
        if result.returncode:
            raise RuntimeError("Disposable cryptographic fixture command failed; credentials were not logged")
        return result.stdout

    @classmethod
    def _key(cls, alias, subject, size=2048, startdate=None, validity=3650):
        path = cls.directory / f"{alias}.p12"
        arguments = [shutil.which("keytool"), "-genkeypair", "-keystore", str(path), "-storetype", "PKCS12", "-alias", alias,
                      "-keyalg", "RSA", "-keysize", str(size), "-sigalg", "SHA256withRSA", "-validity", "3650", "-dname", subject,
                      "-storepass:env", "FINDIT_SIGNATURE_TEST_PASSWORD", "-keypass:env", "FINDIT_SIGNATURE_TEST_PASSWORD", "-noprompt"]
        arguments[arguments.index("-validity") + 1] = str(validity)
        if startdate is not None:
            arguments += ["-startdate", startdate]
        cls._command(arguments)
        certificate = cls._command([shutil.which("keytool"), "-exportcert", "-keystore", str(path), "-alias", alias,
                                    "-storepass:env", "FINDIT_SIGNATURE_TEST_PASSWORD"])
        return hashlib.sha256(certificate).hexdigest()

    @classmethod
    def _sign(cls, alias, source, filename, digest="SHA-256"):
        target = cls.directory / filename
        cls._command([shutil.which("jarsigner"), "-keystore", str(cls.directory / f"{alias}.p12"),
                      "-storepass:env", "FINDIT_SIGNATURE_TEST_PASSWORD", "-keypass:env", "FINDIT_SIGNATURE_TEST_PASSWORD",
                      "-sigalg", "SHA256withRSA", "-digestalg", digest, "-signedjar", str(target), str(source), alias])
        return target

    def verify(self, path, pin=None):
        result = subprocess.run([shutil.which("java"), "-cp", str(self.directory), "VerifyBundleSignature", str(path), pin or self.pin],
                                env=self.environment, capture_output=True, text=True, timeout=90)
        report = json.loads(result.stdout)
        self.assertEqual(result.returncode == 0, report["status"] == "passed")
        return report

    def test_real_signature_checks_every_payload_including_non_signature_metadata(self):
        report = self.verify(self.signed)
        self.assertEqual(report["status"], "passed")
        self.assertEqual(set(report["signedEntries"]), set(self.payloads))
        self.assertEqual(report["signedPayloadEntries"], len(self.payloads))
        self.assertEqual(inspector.verify_bundle_signature(self.signed, self.pin)["certificateSha256"], self.pin)

    def test_unsigned_wrong_pin_debug_weak_and_expired_certificates_are_rejected(self):
        self.assertEqual(self.verify(self.unsigned)["status"], "failed")
        self.assertEqual(self.verify(self.signed, "0" * 64)["status"], "failed")
        for alias, pin in (("debug-fixture", self.debug_pin), ("weak-fixture", self.weak_pin), ("expired-fixture", self.expired_pin)):
            path = self._sign(alias, self.unsigned, f"{alias}.aab")
            self.assertEqual(self.verify(path, pin)["status"], "failed")

    def test_tampered_or_new_unsigned_payloads_and_incomplete_signatures_are_rejected(self):
        with zipfile.ZipFile(self.signed) as archive:
            original = {name: archive.read(name) for name in archive.namelist()}
        for name, value in (("base/assets/flutter_assets/policy.json", b"tampered content"),
                            ("base/assets/new-unsigned.json", b"unsigned addition")):
            path = self.directory / "tampered.aab"
            write_zip(path, {**original, name: value})
            self.assertEqual(self.verify(path)["status"], "failed")
        path = self.directory / "incomplete.aab"
        write_zip(path, {name: value for name, value in original.items() if not name.endswith(".RSA")})
        self.assertEqual(self.verify(path)["status"], "failed")

    def test_valid_signature_with_only_sha512_payload_digests_is_not_this_release_profile(self):
        path = self._sign("fixture", self.unsigned, "sha512.aab", digest="SHA-512")
        self.assertEqual(self.verify(path)["status"], "failed")

    def test_full_synthetic_bundle_requires_matching_mapping_assets_resources_alignment_and_symbols(self):
        entries = resources_fixture()
        entries["base/manifest/AndroidManifest.xml"] = manifest_fixture()
        entries["BundleConfig.pb"] = b"\x12\x06\x12\x04\x08\x01\x10\x02"
        entries["base/dex/classes.dex"] = dex_fixture(["Labiral/mobile/findithiddenobjects/MainActivity;"])
        mapping = b"abiral.mobile.findithiddenobjects.MainActivity -> a.a:\n"
        entries["BUNDLE-METADATA/com.android.tools.build.obfuscation/proguard.map"] = mapping
        for abi in ("arm64-v8a", "x86_64"):
            for library in ("libapp.so", "libflutter.so"):
                entries[f"base/lib/{abi}/{library}"] = elf_fixture()
                entries[f"BUNDLE-METADATA/com.android.tools.build.debugsymbols/{abi}/{library}.sym"] = elf_fixture()
        for source in (ROOT / "assets").rglob("*"):
            if source.is_file():
                entries["base/assets/flutter_assets/" + source.relative_to(ROOT).as_posix()] = source.read_bytes()
        mapping_path, config_path = self.directory / "mapping.txt", self.directory / "config.json"
        mapping_path.write_bytes(mapping)
        config_path.write_text(json.dumps(CONFIG), encoding="utf-8")
        source_path = self.directory / "synthetic-unsigned.aab"
        write_zip(source_path, entries)
        signed = self._sign("fixture", source_path, "synthetic-signed.aab")
        with zipfile.ZipFile(signed) as archive:
            signed_entries = {name: archive.read(name) for name in archive.namelist()}
        with patch.object(inspector, "production_certificate_pin", return_value=self.pin):
            result = inspector.inspect_artifact(signed, None, profile="signed-production-aab", r8_mapping=mapping_path, production_config=config_path)
            self.assertEqual(result["status"], "passed")
            self.assertEqual(result["launcherIconPreservation"]["matchingPngVariants"], 15)
            self.assertEqual(result["bundledR8MappingMatch"]["status"], "passed")
            self.assertTrue(result["jarSignatureVerified"])
            mutations = [("BUNDLE-METADATA/com.android.tools.build.obfuscation/proguard.map", b"stale mapping", "embedded mapping"),
                         ("base/assets/flutter_assets/assets/legal/privacy-policy.json", b"changed policy", "asset differs"),
                         ("BundleConfig.pb", b"\x12\x06\x12\x04\x08\x01\x10\x01", "less than 16 KB"),
                         ("BUNDLE-METADATA/com.android.tools.build.debugsymbols/arm64-v8a/libapp.so.sym", b"not ELF", "ELF symbol payload"),
                         ("feature/manifest/AndroidManifest.xml", manifest_fixture(), "only its base app module"),
                         ("base/manifest/AndroidManifest.xml", manifest_fixture({**CONFIG, "BUILD_STAGE": "qa"}), "release inputs")]
            for name, payload, error in mutations:
                write_zip(source_path, {**signed_entries, name: payload})
                with self.subTest(entry=name), self.assertRaisesRegex(ValueError, error):
                    inspector.inspect_artifact(source_path, None, profile="signed-production-aab", r8_mapping=mapping_path, production_config=config_path)


if __name__ == "__main__":
    unittest.main()
