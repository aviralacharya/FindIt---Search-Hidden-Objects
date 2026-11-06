"""Unit checks for the dependency-free packaging inspector.

Run: python -m unittest discover -s tool -p test_android_artifacts.py
"""

import hashlib
import json
import struct
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch
import zipfile

from verify_android_artifacts import (
    ROOT, ad_free_dex_summary, ad_free_r8_summary, apk_signing_metadata,
    bundle_debug_symbol_metadata, bundle_native_alignment, candidate_catalog_summary, confirm_unsigned_verifier,
    dex_metadata, elf_load_segments, inspect_artifact, manifest_summary,
    native_payload_consistency, protobuf_fields, validate_candidate_manifest,
    zip_data_offset,
)


def dex_fixture(descriptors, extra_strings=()):
    strings = list(descriptors) + list(extra_strings)
    strings_offset = 112
    types_offset = strings_offset + len(strings) * 4
    classes_offset = types_offset + len(descriptors) * 4
    data = bytearray(classes_offset + len(descriptors) * 32)
    data[:8] = b"dex\n035\x00"
    struct.pack_into("<II", data, 36, 112, 0x12345678)
    struct.pack_into("<II", data, 56, len(strings), strings_offset)
    struct.pack_into("<II", data, 64, len(descriptors), types_offset)
    struct.pack_into("<II", data, 96, len(descriptors), classes_offset)
    for index, value in enumerate(strings):
        struct.pack_into("<I", data, strings_offset + index * 4, len(data))
        size = len(value)
        while size >= 128:
            data.append((size & 127) | 128)
            size >>= 7
        data.append(size)
        data.extend(value.encode("ascii") + b"\x00")
    for index in range(len(descriptors)):
        struct.pack_into("<I", data, types_offset + index * 4, index)
        struct.pack_into("<I", data, classes_offset + index * 32, index)
    struct.pack_into("<I", data, 32, len(data))
    return bytes(data)


class ArtifactInspectorTests(unittest.TestCase):
    def test_64_bit_elf_load_alignment(self):
        data = bytearray(64 + 56)
        data[:6] = b"\x7fELF\x02\x01"
        struct.pack_into("<Q", data, 32, 64)
        struct.pack_into("<HH", data, 54, 56, 1)
        struct.pack_into("<I", data, 64, 1)
        struct.pack_into("<QQ", data, 72, 16384, 32768)
        struct.pack_into("<Q", data, 112, 16384)
        bits, segments = elf_load_segments(data)
        self.assertEqual(bits, 64)
        self.assertEqual(segments, [{"offset": 16384, "virtualAddress": 32768, "alignment": 16384}])

    def test_32_bit_big_endian_elf(self):
        data = bytearray(52 + 32)
        data[:6] = b"\x7fELF\x01\x02"
        struct.pack_into(">I", data, 28, 52)
        struct.pack_into(">HH", data, 42, 32, 1)
        struct.pack_into(">I", data, 52, 1)
        struct.pack_into(">II", data, 56, 4096, 8192)
        struct.pack_into(">I", data, 80, 4096)
        bits, segments = elf_load_segments(data)
        self.assertEqual(bits, 32)
        self.assertEqual(segments[0]["alignment"], 4096)

    def test_rejects_non_elf_and_missing_loads(self):
        with self.assertRaises(ValueError):
            elf_load_segments(b"not an ELF")
        data = bytearray(64)
        data[:6] = b"\x7fELF\x02\x01"
        with self.assertRaises(ValueError):
            elf_load_segments(data)

    def test_standard_bundle_config_16k_and_default(self):
        # Optimizations(2) -> uncompress_native_libraries(2) -> enabled(1), alignment(2).
        self.assertEqual(bundle_native_alignment(b"\x12\x06\x12\x04\x08\x01\x10\x02"), {
            "uncompressNativeLibraries": True, "alignmentEnum": 2, "alignment": "16K",
        })
        self.assertEqual(bundle_native_alignment(b"")["alignment"], "UNSPECIFIED")
        self.assertEqual(protobuf_fields(b"\x08\x96\x01"), {1: [150]})
        with self.assertRaises(ValueError):
            protobuf_fields(b"\x12\x04\x00")

    def test_zip_offset_uses_local_filename_and_extra_fields(self):
        temporary_root = ROOT / "build/verification-tests"
        temporary_root.mkdir(parents=True, exist_ok=True)
        with TemporaryDirectory(prefix="findit-inspector-", dir=temporary_root) as directory:
            path = Path(directory) / "sample.apk"
            with zipfile.ZipFile(path, "w") as archive:
                info = zipfile.ZipInfo("lib/arm64-v8a/example.so")
                info.extra = b"\xfe\xca\x02\x00\x00\x00"
                archive.writestr(info, b"payload")
            with zipfile.ZipFile(path) as archive:
                offset = zip_data_offset(path, archive.infolist()[0])
            with path.open("rb") as source:
                source.seek(offset)
                self.assertEqual(source.read(7), b"payload")

    def test_bundle_symbol_metadata_accepts_sym_and_dbg_for_all_abis(self):
        entries = []
        for abi in ("arm64-v8a", "x86_64"):
            for library in ("libapp.so", "libflutter.so"):
                entries.append(f"base/lib/{abi}/{library}")
                suffix = ".sym" if library == "libapp.so" else ".dbg"
                entries.append(f"BUNDLE-METADATA/com.android.tools.build.debugsymbols/{abi}/{library}{suffix}")
        result = bundle_debug_symbol_metadata(entries)
        self.assertEqual(len(result), 4)
        self.assertTrue(all(item["metadata"] in entries for item in result))

    def test_bundle_symbol_metadata_rejects_partial_architecture(self):
        entries = ["base/lib/arm64-v8a/libapp.so", "base/lib/arm64-v8a/libflutter.so",
                   "BUNDLE-METADATA/com.android.tools.build.debugsymbols/arm64-v8a/libapp.so.sym"]
        with self.assertRaisesRegex(ValueError, "missing relocated debug-symbol metadata"):
            bundle_debug_symbol_metadata(entries)

    def test_bundle_symbol_metadata_rejects_missing_flutter_library_or_abis(self):
        for entries in ([], ["base/lib/arm64-v8a/libsqlite3.so"]):
            with self.subTest(entries=entries), self.assertRaises(ValueError):
                bundle_debug_symbol_metadata(entries)

    def test_native_payload_comparison_matches_each_split_abi(self):
        reports = [{"file": "dev.aab", "type": "aab", "nativeLibraries": [
            {"entry": f"base/lib/{abi}/{library}", "sha256": f"{abi}:{library}"}
            for abi in ("arm64-v8a", "x86_64") for library in ("libapp.so", "libflutter.so")
        ]}]
        for abi in ("arm64-v8a", "x86_64"):
            reports.append({"file": f"{abi}.apk", "type": "apk", "nativeLibraries": [
                {"entry": f"lib/{abi}/{library}", "sha256": f"{abi}:{library}"}
                for library in ("libapp.so", "libflutter.so")
            ]})
        result = native_payload_consistency(reports)
        self.assertEqual(result["status"], "passed")
        self.assertEqual([r["matchingLibraries"] for r in result["comparisons"]], [2, 2])

    def test_native_payload_comparison_rejects_stale_bundle_and_missing_libraries(self):
        apk = {"file": "dev.apk", "type": "apk", "nativeLibraries": [
            {"entry": "lib/arm64-v8a/libapp.so", "sha256": "current"},
        ]}
        bundle = {"file": "dev.aab", "type": "aab", "nativeLibraries": [
            {"entry": "base/lib/arm64-v8a/libapp.so", "sha256": "stale"},
        ]}
        with self.assertRaisesRegex(ValueError, "native payload mismatch"):
            native_payload_consistency([apk, bundle])
        bundle["nativeLibraries"].clear()
        with self.assertRaisesRegex(ValueError, "native library sets differ"):
            native_payload_consistency([apk, bundle])

    def test_native_payload_comparison_requires_both_artifact_types(self):
        result = native_payload_consistency([{"type": "apk"}])
        self.assertEqual(result["status"], "not_checked")

    def test_modern_aapt_booleans_and_actual_permission_nodes(self):
        summary = manifest_summary('''
  E: manifest (line=2)
    A: package="com.finditgame.findit.dev" (Raw: "com.finditgame.findit.dev")
    E: uses-sdk (line=7)
      A: http://schemas.android.com/apk/res/android:minSdkVersion(0x0101020c)=24
      A: http://schemas.android.com/apk/res/android:targetSdkVersion(0x01010270)=36
    E: uses-permission (line=11)
      A: http://schemas.android.com/apk/res/android:name(0x01010003)="android.permission.INTERNET" (Raw: "android.permission.INTERNET")
    E: application (line=20)
      A: http://schemas.android.com/apk/res/android:allowBackup(0x01010280)=false
      A: http://schemas.android.com/apk/res/android:fullBackupContent(0x010104eb)=false
      A: http://schemas.android.com/apk/res/android:usesCleartextTraffic(0x010104ec)=false
      E: activity (line=21)
        A: http://schemas.android.com/apk/res/android:name(0x01010003)="com.finditgame.findit.MainActivity" (Raw: "com.finditgame.findit.MainActivity")
''')
        self.assertEqual(summary["permissions"], ["android.permission.INTERNET"])
        self.assertEqual(summary["applicationId"], "com.finditgame.findit.dev")
        self.assertEqual(summary["minSdk"], "24")
        self.assertEqual(summary["targetSdk"], "36")
        self.assertTrue(summary["backupDisabled"])
        self.assertTrue(summary["fullBackupDisabled"])
        self.assertTrue(summary["cleartextDisabled"])

    def test_older_aapt_hex_booleans_and_transitive_ads_detection(self):
        summary = manifest_summary('''
  E: uses-permission (line=1)
    A: android:name(0x01010003)="com.google.android.gms.permission.AD_ID"
  E: uses-permission-sdk-23 (line=2)
    A: android:name(0x01010003)="android.permission.ACCESS_ADSERVICES_TOPICS"
  E: application (line=3)
    A: android:allowBackup(0x01010280)=(type 0x12)0x0
    A: android:fullBackupContent(0x010104eb)=0x00000000
    A: android:usesCleartextTraffic(0x010104ec)=true
    E: provider (line=4)
      A: android:name(0x01010003)="com.google.android.gms.ads.MobileAdsInitProvider"
''')
        self.assertTrue(summary["backupDisabled"])
        self.assertTrue(summary["fullBackupDisabled"])
        self.assertFalse(summary["cleartextDisabled"])
        self.assertFalse(summary["automaticAdsProviderAbsent"])
        self.assertFalse(summary["aaidPermissionAbsent"])
        self.assertFalse(summary["adServicesPermissionsAbsent"])

    def test_dex_reads_defined_classes_and_referenced_types(self):
        names = ["Labiral/mobile/playit/MainActivity;", "Lio/flutter/Flutter;", "Landroidx/datastore/Preferences;"]
        data = dex_fixture(names, ["hello", "x" * 150])
        metadata = dex_metadata(data)
        self.assertEqual(metadata["classes"], names)
        self.assertEqual(metadata["types"], names)
        self.assertIn("x" * 150, metadata["strings"])
        report = ad_free_dex_summary([("classes.dex", data), ("classes10.dex", data)])
        self.assertEqual(report["status"], "passed")
        self.assertEqual(report["definedClasses"], 3)
        self.assertEqual(len(report["dexFiles"]), 2)

    def test_dex_rejects_ads_ump_webview_work_and_test_plugins(self):
        for name in ["Lcom/google/android/gms/ads/MobileAds;", "Lcom/google/android/ump/ConsentInformation;", "Lcom/google/android/gms/internal/consent_sdk/a;", "Lio/flutter/plugins/googlemobileads/GoogleMobileAdsPlugin;", "Lio/flutter/plugins/webviewflutter/WebViewFlutterPlugin;", "Landroidx/work/impl/WorkDatabase_Impl;", "Lcom/google/firebase/analytics/FirebaseAnalytics;", "Ldev/flutter/plugins/integration_test/IntegrationTestPlugin;"]:
            with self.subTest(name=name), self.assertRaisesRegex(ValueError, "remains in DEX"):
                ad_free_dex_summary([("classes.dex", dex_fixture([name]))])

    def test_dex_detects_obfuscated_sdk_registration_strings(self):
        for marker in ["Error registering plugin google_mobile_ads", "plugins.flutter.io/google_mobile_ads/ump", "com.google.android.ump.ConsentInformation", "consent_sdk"]:
            with self.subTest(marker=marker), self.assertRaisesRegex(ValueError, "remains in DEX"):
                ad_free_dex_summary([("classes.dex", dex_fixture(["La/a;"], [marker]))])

    def test_dex_rejects_malformed_headers_bounds_and_indices(self):
        original = dex_fixture(["Lcom/example/App;"])
        variants = [b"not dex", original[:80]]
        for offset, value in [(32, 1), (40, 0), (60, 0xFFFFFFFF), (68, 0xFFFFFFFF), (100, 0xFFFFFFFF), (112, 0xFFFFFFFF), (116, 99), (120, 99)]:
            data = bytearray(original)
            struct.pack_into("<I", data, offset, value)
            variants.append(data)
        for data in variants:
            with self.subTest(length=len(data)), self.assertRaises(ValueError):
                dex_metadata(data)

    def test_ad_free_scan_requires_real_class_tables(self):
        for payloads in ([], [("classes.dex", dex_fixture([]))]):
            with self.assertRaisesRegex(ValueError, "no DEX classes"):
                ad_free_dex_summary(payloads)

    def test_r8_original_names_prevent_an_obfuscation_false_negative(self):
        temporary_root = ROOT / "build/verification-tests"
        temporary_root.mkdir(parents=True, exist_ok=True)
        with TemporaryDirectory(prefix="findit-r8-", dir=temporary_root) as directory:
            path = Path(directory) / "mapping.txt"
            path.write_text("abiral.mobile.playit.MainActivity -> a.a:\n    1:2:void onCreate() -> a\n", encoding="utf-8")
            self.assertEqual(ad_free_r8_summary(path)["originalClassCount"], 1)
            for name in ["com.google.android.gms.internal.ads.zz", "com.google.android.ump.ConsentInformation", "io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin", "androidx.work.impl.WorkDatabase_Impl"]:
                path.write_text(f"{name} -> a.a:\n", encoding="utf-8")
                with self.assertRaisesRegex(ValueError, "remains in R8 inputs"):
                    ad_free_r8_summary(path)
            path.write_text("# no mappings\n", encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "no original class names"):
                ad_free_r8_summary(path)

    def test_unsigned_metadata_checks_jar_and_v2_signatures(self):
        temporary_root = ROOT / "build/verification-tests"
        temporary_root.mkdir(parents=True, exist_ok=True)
        with TemporaryDirectory(prefix="findit-signatures-", dir=temporary_root) as directory:
            path = Path(directory) / "sample.apk"
            with zipfile.ZipFile(path, "w") as archive:
                archive.writestr("AndroidManifest.xml", b"manifest")
            self.assertEqual(apk_signing_metadata(path), {"jarSignatureFiles": [], "apkSigningBlockPresent": False})
            with zipfile.ZipFile(path, "a") as archive:
                archive.writestr("META-INF/CERT.SF", b"signature")
                archive.writestr("META-INF/CERT.RSA", b"certificate")
            self.assertEqual(len(apk_signing_metadata(path)["jarSignatureFiles"]), 2)
            original = bytearray(path.read_bytes())
            end = original.rfind(b"PK\x05\x06")
            directory_offset = struct.unpack_from("<I", original, end + 16)[0]
            block = struct.pack("<QQ", 24, 24) + b"APK Sig Block 42"
            signed = original[:directory_offset] + block + original[directory_offset:]
            struct.pack_into("<I", signed, end + len(block) + 16, directory_offset + len(block))
            path.write_bytes(signed)
            self.assertTrue(apk_signing_metadata(path)["apkSigningBlockPresent"])
            struct.pack_into("<Q", signed, directory_offset, 1)
            path.write_bytes(signed)
            with self.assertRaisesRegex(ValueError, "header/footer disagree"):
                apk_signing_metadata(path)

    def test_r8_mapping_line_endings_and_bom_do_not_skip_original_names(self):
        temporary_root = ROOT / "build/verification-tests"
        temporary_root.mkdir(parents=True, exist_ok=True)
        with TemporaryDirectory(prefix="findit-r8-lines-", dir=temporary_root) as directory:
            path = Path(directory) / "mapping.txt"
            for ending in ("\n", "\r\n", "\r"):
                for prefix in (b"", b"\xef\xbb\xbf"):
                    with self.subTest(ending=repr(ending), bom=bool(prefix)):
                        path.write_bytes(prefix + ending.join([
                            "# compiler: R8",
                            "abiral.mobile.playit.MainActivity -> a.a:",
                            "    1:2:void onCreate() -> a",
                            "io.flutter.Flutter -> a.b:",
                            "",
                        ]).encode("utf-8"))
                        self.assertEqual(ad_free_r8_summary(path)["originalClassCount"], 2)
                        path.write_bytes(prefix + ("com.google.android.ump.ConsentInformation -> a.a:" + ending).encode("utf-8"))
                        with self.assertRaisesRegex(ValueError, "remains in R8 inputs"):
                            ad_free_r8_summary(path)

    def test_unsigned_verifier_rejects_tool_errors_and_accepts_known_unsigned_reasons(self):
        for reason in ("No JAR signatures", "Missing META-INF/MANIFEST.MF"):
            confirm_unsigned_verifier(1, f"DOES NOT VERIFY\nERROR: {reason}")
        for code, output in [(0, "Verifies"), (1, "Java not found"), (1, "DOES NOT VERIFY\nPermission denied"), (0, "DOES NOT VERIFY\nNo JAR signatures")]:
            with self.subTest(code=code, output=output), self.assertRaisesRegex(ValueError, "did not confirm"):
                confirm_unsigned_verifier(code, output)

    def test_catalog_check_rejects_changed_bytes(self):
        data = (ROOT / "assets/content/catalog.json").read_bytes()
        report = candidate_catalog_summary(data)
        self.assertEqual(report["uniqueIds"], 60)
        self.assertEqual(report["puzzlesPerCoreMode"], {"hidden": 60})
        with self.assertRaisesRegex(ValueError, "differs from this hidden-object"):
            candidate_catalog_summary(data + b"\n")

    def test_catalog_rejects_other_modes_duplicate_ids_and_missing_levels(self):
        source = json.loads((ROOT / "assets/content/catalog.json").read_bytes())
        for mutation in ("other-mode", "duplicate-id", "missing-level"):
            value = json.loads(json.dumps(source))
            if mutation == "other-mode":
                value["puzzles"][0]["mode"] = "memory"
            elif mutation == "duplicate-id":
                value["puzzles"][0]["id"] = value["puzzles"][1]["id"]
            else:
                value["puzzles"].pop()
            data = json.dumps(value).encode("utf-8")
            with self.subTest(mutation=mutation), patch(
                    "verify_android_artifacts.CATALOG_SHA256", hashlib.sha256(data).hexdigest()):
                with self.assertRaisesRegex(ValueError, "counts or unique IDs"):
                    candidate_catalog_summary(data)

    def test_candidate_manifest_identity_sdk_permissions_and_release_flag(self):
        original = {"applicationId": "abiral.mobile.findithiddenobjects.qa", "debuggable": False, "adsMetadataAbsent": True, "minSdk": "24", "targetSdk": "36", "permissions": ["android.permission.INTERNET", "android.permission.VIBRATE", "android.permission.WAKE_LOCK", "abiral.mobile.findithiddenobjects.qa.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION"]}
        validate_candidate_manifest(original, "qa-candidate")
        for key, value in [("applicationId", "com.finditgame.findit.dev"), ("debuggable", True), ("adsMetadataAbsent", False), ("minSdk", "23"), ("targetSdk", "35"), ("permissions", ["android.permission.CAMERA"]), ("permissions", ["android.permission.ACCESS_NETWORK_STATE"])]:
            with self.subTest(key=key, value=value), self.assertRaises(ValueError):
                validate_candidate_manifest({**original, key: value}, "qa-candidate")

    def test_catalog_requires_complete_progression_and_matching_level_ids(self):
        source = json.loads((ROOT / "assets/content/catalog.json").read_bytes())
        for mutation in ("duplicate-level", "mismatched-id"):
            value = json.loads(json.dumps(source))
            if mutation == "duplicate-level":
                value["puzzles"][0]["level"] = 2
            else:
                value["puzzles"][0]["id"] = "hidden-unexpected"
            data = json.dumps(value).encode("utf-8")
            with self.subTest(mutation=mutation), patch(
                    "verify_android_artifacts.CATALOG_SHA256", hashlib.sha256(data).hexdigest()):
                with self.assertRaisesRegex(ValueError, "level progression|level IDs"):
                    candidate_catalog_summary(data)

    def test_candidate_inspection_cannot_skip_tools_mapping_or_certificate(self):
        with self.assertRaisesRegex(ValueError, "installed Android build-tools"):
            inspect_artifact(Path("nonexistent.apk"), None, profile="production-candidate")
        with self.assertRaisesRegex(ValueError, "pinned development-certificate"):
            inspect_artifact(Path("nonexistent.apk"), Path("tools"), profile="qa-candidate", r8_mapping=Path("mapping.txt"))

    def test_manifest_metadata_detects_ads_and_implicit_nondebuggable_release(self):
        summary = manifest_summary('''
  E: application (line=1)
    E: meta-data (line=2)
      A: android:name="com.google.android.gms.ads.APPLICATION_ID"
''')
        self.assertFalse(summary["adsMetadataAbsent"])
        self.assertFalse(summary["debuggable"])
        summary = manifest_summary('''
  E: application (line=1)
    A: android:debuggable=true
''')
        self.assertTrue(summary["debuggable"])


if __name__ == "__main__":
    unittest.main()
