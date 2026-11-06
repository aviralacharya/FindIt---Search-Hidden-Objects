"""Inspect FindIt APK/AAB packaging without installing or publishing.

Uses Python's standard library for ELF/ZIP/protobuf checks, plus installed
Android build-tools for APK alignment, signature and merged-manifest checks.
This is not a substitute for a real 16 KB Android runtime or network/SDK QA.
"""

import argparse
import base64
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import struct
import subprocess
import sys
from tempfile import TemporaryDirectory
import zipfile
from urllib.parse import urlparse
import xml.etree.ElementTree as ET
import zlib

ROOT = Path(__file__).resolve().parent.parent
PAGE_SIZE = 16384
CATALOG_SHA256 = hashlib.sha256((ROOT / "assets/content/catalog.json").read_bytes()).hexdigest()
CANDIDATE_PACKAGES = {
    "production-candidate": "abiral.mobile.findithiddenobjects",
    "qa-candidate": "abiral.mobile.findithiddenobjects.qa",
}
SIGNED_BUNDLE_PROFILE = "signed-production-aab"
PRODUCTION_PACKAGE = "abiral.mobile.findithiddenobjects"
ANDROID_NAMESPACE = "http://schemas.android.com/apk/res/android"
PUBLIC_CERTIFICATE = ROOT / "verification/signing/production-upload-certificate.pem"
PUBLIC_CERTIFICATE_RECORD = PUBLIC_CERTIFICATE.with_suffix(".json")
PRODUCTION_CONFIG_KEYS = {"APP_ENV", "BUILD_STAGE", "PRIVACY_POLICY_URL", "PACK_INDEX_URL"}
FORBIDDEN_CANDIDATE_CLASSES = (
    "com.google.android.gms.", "com.google.android.ump.",
    "io.flutter.plugins.googlemobileads.", "io.flutter.plugins.webviewflutter.",
    "com.google.firebase.", "androidx.work.", "androidx.room.",
    "dev.flutter.plugins.integration_test.",
)


def dex_metadata(data):
    """Read actual DEX type/class tables, not a grep of an APK's compressed bytes."""
    if len(data) < 112 or data[:4] != b"dex\n" or data[7] != 0:
        raise ValueError("Unsupported or truncated DEX header")
    if struct.unpack_from("<I", data, 32)[0] != len(data) or struct.unpack_from("<I", data, 40)[0] != 0x12345678:
        raise ValueError("Invalid DEX size or endianness")
    strings_count, strings_offset = struct.unpack_from("<II", data, 56)
    types_count, types_offset = struct.unpack_from("<II", data, 64)
    classes_count, classes_offset = struct.unpack_from("<II", data, 96)
    for count, offset, size in ((strings_count, strings_offset, 4), (types_count, types_offset, 4), (classes_count, classes_offset, 32)):
        if count and (offset < 112 or offset + count * size > len(data)):
            raise ValueError("Invalid DEX table bounds")
    strings = []
    for index in range(strings_count):
        offset = struct.unpack_from("<I", data, strings_offset + index * 4)[0]
        if offset >= len(data):
            raise ValueError("Invalid DEX string offset")
        _, start = _varint(data, offset)  # MUTF-8 UTF-16 length; descriptors are ASCII.
        end = data.find(b"\x00", start)
        if end < 0:
            raise ValueError("Unterminated DEX string")
        strings.append(data[start:end].decode("utf-8", errors="replace"))
    types = []
    for index in range(types_count):
        string_index = struct.unpack_from("<I", data, types_offset + index * 4)[0]
        if string_index >= len(strings):
            raise ValueError("Invalid DEX type index")
        types.append(strings[string_index])
    classes = []
    for index in range(classes_count):
        type_index = struct.unpack_from("<I", data, classes_offset + index * 32)[0]
        if type_index >= len(types):
            raise ValueError("Invalid DEX class index")
        classes.append(types[type_index])
    return {"strings": strings, "types": types, "classes": classes}


def ad_free_dex_summary(payloads):
    classes, types, suspicious_strings = set(), set(), set()
    details = []
    markers = ("google_mobile_ads", "googlemobileads", "consent_sdk", "com.google.android.ump", "play-services-ads")
    for name, data in payloads:
        metadata = dex_metadata(data)
        classes.update(metadata["classes"])
        types.update(metadata["types"])
        suspicious_strings.update(value for value in metadata["strings"] if any(marker in value.lower() for marker in markers))
        details.append({"entry": name, "definedClasses": len(metadata["classes"]), "referencedTypes": len(metadata["types"]), "sha256": hashlib.sha256(data).hexdigest()})
    if not details or not classes:
        raise ValueError("Candidate APK has no DEX classes")
    forbidden = sorted(value for value in types if value.lstrip("[").removeprefix("L").replace("/", ".").startswith(FORBIDDEN_CANDIDATE_CLASSES))
    if forbidden or suspicious_strings:
        raise ValueError(f"Advertising/consent/preview or test SDK remains in DEX: {forbidden[:8] or sorted(suspicious_strings)[:8]}")
    return {"status": "passed", "dexFiles": details, "definedClasses": len(classes), "referencedTypes": len(types),
            "forbiddenClassReferences": forbidden, "sdkRegistrationMarkers": sorted(suspicious_strings),
            "scope": "All DEX class/type/string tables. R8 original-name and resolved-dependency checks are also required."}


def ad_free_r8_summary(path):
    data = path.read_bytes()
    # Keep the raw-byte fingerprint, but parse lines independently of the
    # platform that wrote the mapping (Windows text writes use CRLF).
    names = [match.group(1) for line in data.decode("utf-8-sig").splitlines()
             if (match := re.fullmatch(r"([^\s#]+) -> [^\s]+:", line))]
    if not names:
        raise ValueError("R8 mapping has no original class names")
    forbidden = sorted(name for name in names if name.startswith(FORBIDDEN_CANDIDATE_CLASSES))
    if forbidden:
        raise ValueError(f"Advertising/consent/preview or test SDK remains in R8 inputs: {forbidden[:8]}")
    return {"status": "passed", "file": str(path), "sha256": hashlib.sha256(data).hexdigest(),
            "originalClassCount": len(names), "forbiddenOriginalClasses": forbidden}


def apk_signing_metadata(path):
    """Check both JAR metadata and the v2/v3 APK signing block before the ZIP directory."""
    with zipfile.ZipFile(path) as archive:
        jar = sorted(name for name in archive.namelist() if re.fullmatch(r"META-INF/[^/]+\.(?:SF|RSA|DSA|EC)", name, re.IGNORECASE))
    with path.open("rb") as source:
        source.seek(max(0, path.stat().st_size - 65557))
        tail = source.read()
        end = tail.rfind(b"PK\x05\x06")
        if end < 0 or end + 22 > len(tail) or end + 22 + struct.unpack_from("<H", tail, end + 20)[0] != len(tail):
            raise ValueError("Invalid APK end-of-central-directory record")
        directory = struct.unpack_from("<I", tail, end + 16)[0]
        if directory == 0xFFFFFFFF:
            raise ValueError("ZIP64 APK signature inspection is unsupported")
        present = False
        if directory >= 24:
            source.seek(directory - 24)
            footer = source.read(24)
            present = footer[8:] == b"APK Sig Block 42"
            if present:
                size = struct.unpack_from("<Q", footer)[0]
                if size < 24 or size + 8 > directory:
                    raise ValueError("Invalid APK signing-block size")
                source.seek(directory - size - 8)
                if struct.unpack("<Q", source.read(8))[0] != size:
                    raise ValueError("APK signing-block header/footer disagree")
    return {"jarSignatureFiles": jar, "apkSigningBlockPresent": present}


def confirm_unsigned_verifier(returncode, output):
    # Depending on AGP packaging, an unsigned APK either has no JAR signatures
    # or lacks the JAR manifest entirely. Tool/Java failures are not evidence.
    if (returncode == 0 or "DOES NOT VERIFY" not in output
            or not any(reason in output for reason in ("No JAR signatures", "Missing META-INF/MANIFEST.MF"))):
        raise ValueError("apksigner did not confirm the expected unsigned APK")


def candidate_catalog_summary(data):
    digest = hashlib.sha256(data).hexdigest()
    if digest != CATALOG_SHA256:
        raise ValueError("Candidate catalog differs from this hidden-object project's source catalog")
    puzzles = json.loads(data)["puzzles"]
    counts = {mode: sum(puzzle["mode"] == mode for puzzle in puzzles)
              for mode in sorted({puzzle["mode"] for puzzle in puzzles})}
    if len(puzzles) != 60 or len({puzzle["id"] for puzzle in puzzles}) != 60 or counts != {"hidden": 60}:
        raise ValueError("Candidate puzzle counts or unique IDs are invalid")
    if sorted(puzzle["level"] for puzzle in puzzles) != list(range(1, 61)):
        raise ValueError("Candidate hidden-object level progression is invalid")
    if any(puzzle["id"] != f"hidden-{puzzle['level']:03d}" for puzzle in puzzles):
        raise ValueError("Candidate hidden-object level IDs are invalid")
    return {"status": "passed", "sha256": digest, "puzzles": len(puzzles), "uniqueIds": 60, "puzzlesPerCoreMode": counts}


def validate_candidate_manifest(summary, profile):
    package = CANDIDATE_PACKAGES[profile]
    if summary["applicationId"] != package:
        raise ValueError(f"Wrong {profile} package: {summary['applicationId']}")
    if summary["debuggable"] or not summary["adsMetadataAbsent"]:
        raise ValueError("Candidate is debuggable or contains advertising metadata")
    allowed = {"android.permission.INTERNET", "android.permission.VIBRATE", "android.permission.WAKE_LOCK", f"{package}.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION"}
    unexpected = set(summary["permissions"]) - allowed
    if unexpected:
        raise ValueError(f"Unexpected candidate permissions: {sorted(unexpected)}")
    if summary["minSdk"] != "24" or summary["targetSdk"] != "36":
        raise ValueError("Candidate SDK levels do not match the verified release configuration")


def elf_load_segments(data):
    if len(data) < 52 or data[:4] != b"\x7fELF" or data[4] not in (1, 2) or data[5] not in (1, 2):
        raise ValueError("Unsupported or non-ELF native library")
    bits = 64 if data[4] == 2 else 32
    endian = "<" if data[5] == 1 else ">"
    if bits == 64:
        if len(data) < 64:
            raise ValueError("Truncated 64-bit ELF header")
        phoff = struct.unpack_from(endian + "Q", data, 32)[0]
        size, count = struct.unpack_from(endian + "HH", data, 54)
    else:
        phoff = struct.unpack_from(endian + "I", data, 28)[0]
        size, count = struct.unpack_from(endian + "HH", data, 42)
    segments = []
    if count and (size < (56 if bits == 64 else 32) or phoff + size * count > len(data)):
        raise ValueError("Invalid ELF program-header table")
    for index in range(count):
        offset = phoff + size * index
        if struct.unpack_from(endian + "I", data, offset)[0] != 1:  # PT_LOAD
            continue
        if bits == 64:
            file_offset, virtual_address = struct.unpack_from(endian + "QQ", data, offset + 8)
            alignment = struct.unpack_from(endian + "Q", data, offset + 48)[0]
        else:
            file_offset, virtual_address = struct.unpack_from(endian + "II", data, offset + 4)
            alignment = struct.unpack_from(endian + "I", data, offset + 28)[0]
        segments.append({"offset": file_offset, "virtualAddress": virtual_address, "alignment": alignment})
    if not segments:
        raise ValueError("Native library has no PT_LOAD segments")
    return bits, segments


def zip_data_offset(archive_path, info):
    with Path(archive_path).open("rb") as source:
        source.seek(info.header_offset)
        header = source.read(30)
    if header[:4] != b"PK\x03\x04":
        raise ValueError("Invalid ZIP local header")
    name_length, extra_length = struct.unpack_from("<HH", header, 26)
    return info.header_offset + 30 + name_length + extra_length


def _varint(data, index):
    value, shift = 0, 0
    while index < len(data) and shift < 70:
        byte = data[index]
        index += 1
        value |= (byte & 127) << shift
        if byte < 128:
            return value, index
        shift += 7
    raise ValueError("Invalid protobuf varint")


def protobuf_fields(data):
    """Read scalar/message fields needed from the standard BundleConfig proto."""
    fields, index = {}, 0
    while index < len(data):
        tag, index = _varint(data, index)
        number, wire = tag >> 3, tag & 7
        if number == 0 or number > 536870911:
            raise ValueError("Invalid protobuf field number")
        if wire == 0:
            value, index = _varint(data, index)
        elif wire == 2:
            length, index = _varint(data, index)
            end = index + length
            if end > len(data):
                raise ValueError("Truncated protobuf field")
            value, index = data[index:end], end
        elif wire in (1, 5):
            end = index + (8 if wire == 1 else 4)
            if end > len(data):
                raise ValueError("Truncated protobuf scalar")
            value, index = data[index:end], end
        else:
            raise ValueError(f"Unsupported protobuf wire type {wire}")
        fields.setdefault(number, []).append(value)
    return fields


def _proto_single(fields, number, default=None):
    values = fields.get(number, [])
    if len(values) > 1:
        raise ValueError("Duplicate scalar protobuf field")
    return values[0] if values else default


def _proto_text(fields, number, default=""):
    value = _proto_single(fields, number, default.encode("utf-8"))
    if not isinstance(value, bytes):
        raise ValueError("Protobuf string has the wrong wire type")
    return value.decode("utf-8")


def proto_item_value(data):
    """Decode the scalar Item variants used in compiled Android XML."""
    fields = protobuf_fields(data)
    kinds = [number for number in range(1, 8) if number in fields]
    if len(kinds) != 1:
        raise ValueError("Unsupported or ambiguous compiled resource Item")
    number = kinds[0]
    child = protobuf_fields(_proto_single(fields, number))
    if number == 1:
        if _proto_single(child, 1, 0) != 0:
            raise ValueError("Theme attributes are not concrete resource references")
        identifier = _proto_single(child, 2)
        if identifier:
            return f"@0x{identifier:08x}"
        name = _proto_text(child, 3)
        if not name:
            raise ValueError("Empty compiled resource reference")
        return "@" + name
    if number in (2, 3):
        return _proto_text(child, 1)
    if number == 5:
        return _proto_text(child, 1)
    if number == 7:
        primitive = list(child)
        if len(primitive) != 1:
            raise ValueError("Ambiguous compiled primitive")
        kind = primitive[0]
        value = _proto_single(child, kind)
        if kind == 8 and value in (0, 1):
            return "true" if value else "false"
        if kind in (6, 7):
            return str(value)
        if kind in (9, 10):
            return f"#{value if kind == 9 else value | 0xff000000:08x}"
    raise ValueError("Unsupported compiled XML scalar")


def bundle_xml_node(data, *, depth=0):
    """Read AAPT2 Resources.proto XmlNode without trusting a source manifest."""
    if depth > 100:
        raise ValueError("Compiled XML nesting is too deep")
    root = protobuf_fields(data)
    element_data = _proto_single(root, 1)
    if element_data is None:
        if 2 in root:
            return None  # Formatting/comment text is not an Android element.
        raise ValueError("Compiled XML has no root element")
    if 2 in root:
        raise ValueError("Ambiguous compiled XML node")
    element = protobuf_fields(element_data)
    name = _proto_text(element, 3)
    if not name:
        raise ValueError("Compiled XML has an unnamed element")
    attributes = {}
    namespaces = {}
    for value in element.get(4, []):
        attribute = protobuf_fields(value)
        key = _proto_text(attribute, 2)
        namespace = _proto_text(attribute, 1)
        if not key or key in attributes or namespace not in ("", ANDROID_NAMESPACE):
            raise ValueError("Duplicate, unnamed or unsupported compiled XML attribute")
        compiled = _proto_single(attribute, 6)
        text = proto_item_value(compiled) if compiled is not None else _proto_text(attribute, 3)
        attributes[key] = text
        namespaces[key] = namespace
    children = [node for value in element.get(5, [])
                if (node := bundle_xml_node(value, depth=depth + 1)) is not None]
    return {"name": name, "namespace": _proto_text(element, 2),
            "attributes": attributes, "attributeNamespaces": namespaces, "children": children}


def _xml_flatten(node):
    return [node, *(child for value in node["children"] for child in _xml_flatten(value))]


def bundle_manifest_summary(data):
    root = bundle_xml_node(data)
    if root is None or root["name"] != "manifest":
        raise ValueError("Bundle compiled manifest has the wrong root")
    elements = _xml_flatten(root)
    applications = [node for node in root["children"] if node["name"] == "application"]
    if len(applications) != 1:
        raise ValueError("Bundle requires exactly one application element")
    # Android attributes must have their actual namespace, not lookalike names.
    for node in elements:
        if node["namespace"]:
            raise ValueError("Android manifest elements must not have a namespace")
        for key, namespace in node["attributeNamespaces"].items():
            unqualified = node["name"] == "manifest" and key in ("package", "split", "platformBuildVersionCode", "platformBuildVersionName")
            if not unqualified and namespace != ANDROID_NAMESPACE:
                raise ValueError("An Android manifest attribute is not in the Android namespace")
    summary = _manifest_elements_summary(elements)
    app = applications[0]
    metadata = [node for node in app["children"] if node["name"] == "meta-data"]
    inputs = {}
    for node in metadata:
        key = node["attributes"].get("name", "")
        if key.startswith("findit.hidden."):
            if key in inputs or "value" not in node["attributes"]:
                raise ValueError("Duplicate or incomplete bundle release metadata")
            inputs[key] = node["attributes"]["value"]
    summary["releaseInputs"] = inputs
    return summary


def is_public_https(value):
    if not isinstance(value, str) or value != value.strip():
        return False
    try:
        parsed = urlparse(value)
        host = (parsed.hostname or "").lower()
        _ = parsed.port
    except ValueError:
        return False
    reserved = ("localhost", "invalid", "example", "test", "local", "internal",
                "example.com", "example.org", "example.net")
    return (parsed.scheme == "https" and bool(host) and "." in host
            and parsed.username is None and parsed.password is None
            and ":" not in host and not re.fullmatch(r"[0-9.]+", host)
            and not any(host == suffix or host.endswith("." + suffix) for suffix in reserved))


def load_production_config(path):
    value = json.loads(Path(path).read_text(encoding="utf-8"))
    if (not isinstance(value, dict) or set(value) != PRODUCTION_CONFIG_KEYS
            or value["APP_ENV"] != "production" or value["BUILD_STAGE"] != "final"
            or value["PACK_INDEX_URL"] != "" or not is_public_https(value["PRIVACY_POLICY_URL"])):
        raise ValueError("Final configuration requires production/final, an empty pack index and a real public HTTPS policy URL")
    return value


def production_certificate_pin(expected=None):
    record = json.loads(PUBLIC_CERTIFICATE_RECORD.read_text(encoding="utf-8"))
    pem = PUBLIC_CERTIFICATE.read_text(encoding="ascii")
    match = re.fullmatch(r"\s*-----BEGIN CERTIFICATE-----\s+([A-Za-z0-9+/=\s]+?)\s+-----END CERTIFICATE-----\s*", pem)
    if not match:
        raise ValueError("The dedicated public upload certificate is invalid")
    certificate = base64.b64decode(re.sub(r"\s", "", match.group(1)), validate=True)
    digest = hashlib.sha256(certificate).hexdigest()
    gradle = (ROOT / "android/app/build.gradle.kts").read_text(encoding="utf-8")
    pins = re.findall(r'val productionUploadCertificateSha256 = "([0-9a-f]{64})"', gradle)
    if (record.get("applicationId") != PRODUCTION_PACKAGE
            or record.get("keyAlias") != "findit-hidden-upload"
            or record.get("certificateSha256") != digest
            or pins != [digest]
            or (expected is not None and expected.lower() != digest)):
        raise ValueError("The public upload certificate/record does not match this app's dedicated pin")
    return digest


def verify_bundle_signature(path, pin):
    environment = _java_environment()
    home = environment.get("JAVA_HOME")
    java = Path(home) / "bin" / ("java.exe" if os.name == "nt" else "java") if home else None
    executable = str(java) if java and java.is_file() else shutil.which("java")
    if not executable:
        raise ValueError("Signed-bundle inspection requires JDK 17 Java")
    result = subprocess.run([executable, str(ROOT / "tool/VerifyBundleSignature.java"), str(path), pin],
                            capture_output=True, text=True, timeout=180, env=environment)
    try:
        report = json.loads(result.stdout)
    except (ValueError, TypeError):
        raise ValueError("The JDK bundle signature verifier could not complete") from None
    if not isinstance(report, dict):
        raise ValueError("The JDK bundle signature verifier returned an invalid report")
    if result.returncode or report.get("status") != "passed":
        raise ValueError(report.get("error", "Bundle cryptographic signature verification failed"))
    if report.get("certificateSha256") != pin or not report.get("signedPayloadEntries"):
        raise ValueError("The JDK verifier did not confirm the expected signer and payload")
    return report


def validate_signed_bundle_manifest(summary, config):
    validate_candidate_manifest(summary, "production-candidate")
    version = re.search(r"(?m)^version:\s*([^\s+]+)\+(\d+)\s*$", (ROOT / "pubspec.yaml").read_text(encoding="utf-8"))
    if not version or (summary.get("versionName"), summary.get("versionCode")) != version.groups():
        raise ValueError("Bundle version differs from the current initial-release version")
    if summary.get("applicationLabel") != "FindIt Hidden":
        raise ValueError("Bundle launcher label must be FindIt Hidden")
    expected = {"findit.hidden." + key: value for key, value in config.items()}
    if summary.get("releaseInputs") != expected:
        raise ValueError("Compiled bundle release inputs differ from the final production configuration")
    gates = ("automaticAdsProviderAbsent", "aaidPermissionAbsent", "adServicesPermissionsAbsent",
             "backupDisabled", "fullBackupDisabled", "cleartextDisabled")
    if any(not summary[key] for key in gates):
        raise ValueError("Bundle manifest violates the ad-free privacy/backup gates")


def source_assets_summary(archive, prefix):
    files = []
    for source in sorted((ROOT / "assets").rglob("*")):
        if not source.is_file():
            continue
        name = source.relative_to(ROOT).as_posix()
        data = source.read_bytes()
        if archive.read(prefix + name) != data:
            raise ValueError(f"Bundled asset differs from current source: {name}")
        files.append({"source": name, "sha256": hashlib.sha256(data).hexdigest(), "bytes": len(data)})
    return {"status": "passed", "matchingAssets": len(files), "files": files,
            "scope": "Exact bytes for all bundled source assets, including the canonical offline policy, supplied PNG and prepared branding."}


def bundle_resource_table(data):
    """Index AAPT2 resource IDs and variants; resolve actual compiled references."""
    entries = {}
    for package_data in protobuf_fields(data).get(2, []):
        package = protobuf_fields(package_data)
        package_id = _proto_single(protobuf_fields(_proto_single(package, 1, b"")), 1, 0)
        package_name = _proto_text(package, 2)
        if not isinstance(package_id, int) or not 1 <= package_id <= 255 or not package_name:
            raise ValueError("Invalid compiled resource package")
        for type_data in package.get(3, []):
            resource_type = protobuf_fields(type_data)
            type_id = _proto_single(protobuf_fields(_proto_single(resource_type, 1, b"")), 1, 0)
            type_name = _proto_text(resource_type, 2)
            if not isinstance(type_id, int) or not 1 <= type_id <= 255 or not type_name:
                raise ValueError("Invalid compiled resource type")
            for entry_data in resource_type.get(3, []):
                entry = protobuf_fields(entry_data)
                entry_id = _proto_single(protobuf_fields(_proto_single(entry, 1, b"")), 1, 0)
                name = _proto_text(entry, 2)
                if not isinstance(entry_id, int) or not 0 <= entry_id <= 65535 or not name:
                    raise ValueError("Invalid compiled resource entry")
                identifier = (package_id << 24) | (type_id << 16) | entry_id
                if identifier in entries:
                    raise ValueError("Duplicate compiled resource ID")
                variants = []
                for variant_data in entry.get(6, []):
                    variant = protobuf_fields(variant_data)
                    config = protobuf_fields(_proto_single(variant, 1, b""))
                    value = protobuf_fields(_proto_single(variant, 2, b""))
                    variants.append({"config": config, "item": _proto_single(value, 4),
                                     "compound": _proto_single(value, 5)})
                entries[identifier] = {"id": identifier, "package": package_name,
                                       "name": f"{type_name}/{name}", "variants": variants}
    if not entries:
        raise ValueError("The compiled resource table is empty")
    return entries


def _resource_entry(table, reference, expected=None):
    if not isinstance(reference, str) or not reference.startswith("@"):
        raise ValueError("A concrete compiled resource reference is required")
    if re.fullmatch(r"@0x[0-9a-fA-F]{8}", reference):
        entry = table.get(int(reference[1:], 16))
    else:
        name = reference[1:].split(":", 1)[-1]
        matches = [entry for entry in table.values() if entry["name"] == name]
        entry = matches[0] if len(matches) == 1 else None
    if entry is None or (expected is not None and entry["name"] != expected):
        raise ValueError(f"Compiled resource does not resolve to {expected or reference}")
    return entry


def _resource_file(variant):
    if variant["compound"] is not None or variant["item"] is None:
        raise ValueError("Expected a simple compiled resource file")
    fields = protobuf_fields(variant["item"])
    if [key for key in range(1, 8) if key in fields] != [5]:
        raise ValueError("Expected a compiled FileReference")
    reference = protobuf_fields(_proto_single(fields, 5))
    path = _proto_text(reference, 1)
    if (not path.startswith("res/") or "\\" in path or ":" in path
            or ".." in PurePosixPath(path).parts):
        raise ValueError("Invalid compiled resource file path")
    return path


def _xml_semantics(node, table=None):
    attributes = {}
    for name, value in node["attributes"].items():
        namespace = node["attributeNamespaces"][name]
        if table is not None and value.startswith("@"):
            value = "@" + _resource_entry(table, value)["name"]
        attributes[f"{{{namespace}}}{name}" if namespace else name] = value
    return {"name": f"{{{node['namespace']}}}{node['name']}" if node["namespace"] else node["name"],
            "attributes": attributes, "children": [_xml_semantics(child, table) for child in node["children"]]}


def _source_xml_semantics(path):
    def element(node):
        return {"name": node.tag, "attributes": dict(node.attrib),
                "children": [element(child) for child in node]}
    return element(ET.fromstring(Path(path).read_bytes()))


def png_rendered_rgba(data):
    """Compare PNG pixels after AAPT2 repacking, not compression/metadata bytes.

    Supports the non-interlaced 8-bit color and 1/2/4/8-bit indexed/grayscale
    PNGs used for Android icons. Fully transparent RGB is normalized to zero.
    """
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError("Launcher resource is not a PNG")
    offset, chunks, ended = 8, {}, False
    while offset + 12 <= len(data):
        length = struct.unpack_from(">I", data, offset)[0]
        end = offset + length + 12
        if end > len(data):
            raise ValueError("Truncated launcher PNG")
        kind, payload = data[offset + 4:offset + 8], data[offset + 8:end - 4]
        if zlib.crc32(kind + payload) & 0xffffffff != struct.unpack_from(">I", data, end - 4)[0]:
            raise ValueError("Launcher PNG checksum mismatch")
        chunks.setdefault(kind, []).append(payload)
        offset = end
        if kind == b"IEND":
            ended = not payload and offset == len(data)
            break
    if not ended or len(chunks.get(b"IHDR", [])) != 1 or b"acTL" in chunks:
        raise ValueError("Invalid static launcher PNG")
    header = chunks[b"IHDR"][0]
    if len(header) != 13:
        raise ValueError("Invalid launcher PNG header")
    width, height, depth, color, compression, filtering, interlace = struct.unpack(">IIBBBBB", header)
    channels = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}.get(color)
    if (not channels or not 0 < width <= 4096 or not 0 < height <= 4096
            or compression or filtering or interlace
            or depth not in ((1, 2, 4, 8) if color in (0, 3) else (8,))):
        raise ValueError("Unsupported launcher PNG encoding")
    stride = (width * channels * depth + 7) // 8
    step = max(1, (channels * depth + 7) // 8)
    decoder = zlib.decompressobj()
    raw = decoder.decompress(b"".join(chunks.get(b"IDAT", [])), (stride + 1) * height + 1)
    if len(raw) != (stride + 1) * height or not decoder.eof or decoder.unused_data:
        raise ValueError("Invalid launcher PNG image payload")
    palette = _proto_single(chunks, b"PLTE", b"")
    transparency = _proto_single(chunks, b"tRNS", b"")
    if color == 3 and (not palette or len(palette) % 3):
        raise ValueError("Invalid launcher PNG palette")
    pixels, previous = bytearray(), bytearray(stride)
    for y in range(height):
        start = y * (stride + 1)
        mode = raw[start]
        row = bytearray(raw[start + 1:start + 1 + stride])
        if mode > 4:
            raise ValueError("Invalid launcher PNG row filter")
        for x in range(stride):
            left = row[x - step] if x >= step else 0
            above = previous[x]
            corner = previous[x - step] if x >= step else 0
            if mode == 1:
                predictor = left
            elif mode == 2:
                predictor = above
            elif mode == 3:
                predictor = (left + above) // 2
            elif mode == 4:
                p = left + above - corner
                distances = [abs(p - value) for value in (left, above, corner)]
                predictor = (left, above, corner)[distances.index(min(distances))]
            else:
                predictor = 0
            row[x] = (row[x] + predictor) & 255
        for x in range(width):
            if color in (0, 3):
                sample = (row[x * depth // 8] >> (8 - depth - (x * depth % 8))) & ((1 << depth) - 1)
                if color == 3:
                    if sample * 3 + 3 > len(palette):
                        raise ValueError("Invalid launcher PNG palette index")
                    r, g, b = palette[sample * 3:sample * 3 + 3]
                    alpha = transparency[sample] if sample < len(transparency) else 255
                else:
                    r = g = b = sample * 255 // ((1 << depth) - 1)
                    alpha = 0 if transparency == struct.pack(">H", sample) else 255
            elif color == 2:
                r, g, b = row[x * 3:x * 3 + 3]
                alpha = 0 if transparency == struct.pack(">HHH", r, g, b) else 255
            elif color == 4:
                r = g = b = row[x * 2]
                alpha = row[x * 2 + 1]
            else:
                r, g, b, alpha = row[x * 4:x * 4 + 4]
            pixels.extend((r, g, b, alpha) if alpha else (0, 0, 0, 0))
        previous = row
    return width, height, bytes(pixels)


def _density_png_summary(archive, entry, source_stem, module_prefix):
    densities = {160: "mdpi", 240: "hdpi", 320: "xhdpi", 480: "xxhdpi", 640: "xxxhdpi"}
    found, files = set(), []
    for variant in entry["variants"]:
        config = variant["config"]
        density = _proto_single(config, 18, 0)
        sdk = _proto_single(config, 24, 0)
        if set(config) - {18, 24} or density not in densities or density in found or sdk not in (0, 4):
            raise ValueError(f"Unexpected density/configuration for {entry['name']}")
        found.add(density)
        source = ROOT / f"android/app/src/main/res/{source_stem.split('/')[0]}-{densities[density]}/{source_stem.split('/')[1]}.png"
        bundled_path = module_prefix + _resource_file(variant)
        bundled, original = archive.read(bundled_path), source.read_bytes()
        pixels = png_rendered_rgba(bundled)
        if pixels != png_rendered_rgba(original):
            raise ValueError(f"Launcher pixels differ from the supplied-icon preparation: {bundled_path}")
        files.append({"entry": bundled_path, "source": source.relative_to(ROOT).as_posix(),
                      "density": density, "width": pixels[0], "height": pixels[1],
                      "renderedRgbaSha256": hashlib.sha256(pixels[2]).hexdigest(),
                      "sourceSha256": hashlib.sha256(original).hexdigest(),
                      "bundledSha256": hashlib.sha256(bundled).hexdigest()})
    if found != set(densities):
        raise ValueError(f"Missing prepared launcher densities for {entry['name']}")
    return files


def bundle_launcher_summary(archive, reference, *, module_prefix="base/"):
    table = bundle_resource_table(archive.read(module_prefix + "resources.pb"))
    launcher = _resource_entry(table, reference, "mipmap/ic_launcher")
    adaptive, raster = [], []
    for variant in launcher["variants"]:
        config = variant["config"]
        if _proto_single(config, 18, 0) == 65534 and _proto_single(config, 24, 0) == 26 and set(config) <= {18, 24}:
            adaptive.append(variant)
        else:
            raster.append(variant)
    if len(adaptive) != 1:
        raise ValueError("Exactly one API-26 adaptive launcher icon is required")
    files = _density_png_summary(archive, {**launcher, "variants": raster}, "mipmap/ic_launcher", module_prefix)
    adaptive_path = module_prefix + _resource_file(adaptive[0])
    node = bundle_xml_node(archive.read(adaptive_path))
    source = ROOT / "android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml"
    if node is None or _xml_semantics(node, table) != _source_xml_semantics(source):
        raise ValueError("Compiled adaptive launcher differs from the padded foreground/themed-icon source")
    for layer, resource in (("foreground", "drawable/ic_launcher_foreground"), ("monochrome", "drawable/ic_launcher_monochrome")):
        child = next((child for child in node["children"] if child["name"] == layer), None)
        if child is None:
            raise ValueError("Adaptive launcher is missing a prepared layer")
        entry = _resource_entry(table, child["attributes"].get("drawable"), resource)
        files.extend(_density_png_summary(archive, entry, resource, module_prefix))
    background = next(child for child in node["children"] if child["name"] == "background")
    color = _resource_entry(table, background["attributes"].get("drawable"), "color/ic_launcher_background")
    if len(color["variants"]) != 1 or color["variants"][0]["config"] or color["variants"][0]["compound"] is not None:
        raise ValueError("Unexpected adaptive launcher background variants")
    if proto_item_value(color["variants"][0]["item"]) != "#fffbf7ee":
        raise ValueError("Adaptive launcher must keep the approved opaque cream background")
    return {"status": "passed", "resource": launcher["name"], "adaptiveXml": adaptive_path,
            "matchingPngVariants": len(files), "files": files,
            "scope": "All raster, adaptive foreground and monochrome density pixels match prepared source; not launcher/runtime QA."}


def bundle_backup_rules_summary(archive, reference, *, module_prefix="base/"):
    table = bundle_resource_table(archive.read(module_prefix + "resources.pb"))
    entry = _resource_entry(table, reference, "xml/data_extraction_rules")
    if len(entry["variants"]) != 1 or entry["variants"][0]["config"]:
        raise ValueError("Backup rules require exactly one unqualified resource")
    path = module_prefix + _resource_file(entry["variants"][0])
    data = archive.read(path)
    node = bundle_xml_node(data)
    source = ROOT / "android/app/src/main/res/xml/data_extraction_rules.xml"
    if node is None or _xml_semantics(node) != _source_xml_semantics(source):
        raise ValueError("Compiled backup/transfer exclusions differ from the offline privacy commitments")
    return {"status": "passed", "entry": path, "sha256": hashlib.sha256(data).hexdigest(),
            "sourceSha256": hashlib.sha256(source.read_bytes()).hexdigest(),
            "cloudBackupAndDeviceTransferExcludedDomains": ["database", "external", "file", "root", "sharedpref"],
            "scope": "Exact compiled XML semantics against source; OEM backup behavior still requires device QA."}


def inspect_apk_resources(path, build_tools):
    temporary_root = ROOT / "build/verification-tests"
    temporary_root.mkdir(parents=True, exist_ok=True)
    with TemporaryDirectory(prefix="findit-apk-resources-", dir=temporary_root) as directory:
        converted = Path(directory) / "resources.apk"
        suffix = ".exe" if os.name == "nt" else ""
        _run([str(build_tools / f"aapt2{suffix}"), "convert", "--output-format", "proto", "-o", str(converted), str(path)])
        with zipfile.ZipFile(converted) as archive:
            manifest = bundle_manifest_summary(archive.read("AndroidManifest.xml"))
            return {"launcherIconPreservation": bundle_launcher_summary(archive, manifest["applicationIconResource"], module_prefix=""),
                    "backupRules": bundle_backup_rules_summary(archive, manifest["dataExtractionRulesResource"], module_prefix=""),
                    "compiledManifest": manifest}


def bundle_native_alignment(data):
    # google/bundletool src/main/proto/config.proto:
    # BundleConfig.optimizations(2).uncompress_native_libraries(2).alignment(2)
    root = protobuf_fields(data)
    optimizations = protobuf_fields(_proto_single(root, 2, b""))
    native = protobuf_fields(_proto_single(optimizations, 2, b""))
    value = _proto_single(native, 2, 0)
    enabled = _proto_single(native, 1, 0)
    if enabled not in (0, 1) or not isinstance(value, int):
        raise ValueError("Invalid native alignment configuration")
    return {
        "uncompressNativeLibraries": bool(enabled),
        "alignmentEnum": value,
        "alignment": {0: "UNSPECIFIED", 1: "4K", 2: "16K", 3: "64K"}.get(value, "UNKNOWN"),
    }


def bundle_debug_symbol_metadata(entries):
    """Check AGP's relocated Flutter symbol files for every packaged ABI.

    This inspects the bundle directly when the SDK's apkanalyzer is unavailable;
    it is not a successful Flutter CLI post-build verification or runtime check.
    """
    names = set(entries)
    abis = sorted({name.split("/")[2] for name in names
                   if re.fullmatch(r"base/lib/[^/]+/[^/]+\.so", name)})
    if not abis:
        raise ValueError("Bundle has no native ABIs")
    metadata = []
    for abi in abis:
        for library in ("libapp.so", "libflutter.so"):
            packaged = f"base/lib/{abi}/{library}"
            if packaged not in names:
                raise ValueError(f"Bundle is missing Flutter library: {packaged}")
            prefix = f"BUNDLE-METADATA/com.android.tools.build.debugsymbols/{abi}/{library}"
            symbols = next((prefix + suffix for suffix in (".sym", ".dbg")
                            if prefix + suffix in names), None)
            if symbols is None:
                raise ValueError(f"Bundle is missing relocated debug-symbol metadata: {packaged}")
            metadata.append({"library": packaged, "metadata": symbols})
    return metadata


def native_payload_consistency(reports):
    """Compare exact native bytes across available APKs and bundles."""
    apks = [r for r in reports if r.get("type") == "apk"]
    bundles = [r for r in reports if r.get("type") == "aab"]
    if not apks or not bundles:
        return {"status": "not_checked", "reason": "Both APK and AAB reports are required."}
    comparisons = []
    for bundle in bundles:
        bundled = {item["entry"].removeprefix("base/"): item["sha256"]
                   for item in bundle["nativeLibraries"]}
        for apk in apks:
            packaged = {item["entry"]: item["sha256"] for item in apk["nativeLibraries"]}
            abis = sorted({entry.split("/")[1] for entry in packaged})
            expected = {entry: digest for entry, digest in bundled.items()
                        if entry.split("/")[1] in abis}
            if not packaged or set(packaged) != set(expected):
                raise ValueError(f"APK/AAB native library sets differ: {apk['file']} vs {bundle['file']}")
            mismatches = [entry for entry in packaged if packaged[entry] != expected[entry]]
            if mismatches:
                raise ValueError(f"APK/AAB native payload mismatch in {apk['file']}: {', '.join(mismatches)}")
            comparisons.append({"apk": apk["file"], "bundle": bundle["file"],
                                "abis": abis, "matchingLibraries": len(packaged)})
    return {"status": "passed", "scope": "Exact SHA-256 native-library matches, not a runtime or all-assets comparison.",
            "comparisons": comparisons}


def xmltree_elements(dump):
    """Read aapt2 element attributes without mistaking class names for permissions."""
    elements = []
    current = None
    for line in dump.splitlines():
        element = re.match(r"\s*E: ([^\s(]+)", line)
        if element:
            current = {"name": element.group(1), "attributes": {}}
            elements.append(current)
            continue
        attribute = re.match(r"\s*A: ([^=\s(]+)(?:\([^)]*\))?=(.*)$", line)
        if attribute and current is not None:
            name = attribute.group(1).rsplit(":", 1)[-1]
            value = attribute.group(2).strip()
            if value.startswith('"'):
                value = value.split('"', 2)[1]
            current["attributes"][name] = value
    return elements


def manifest_summary(dump):
    return _manifest_elements_summary(xmltree_elements(dump))


def _manifest_elements_summary(elements):
    def attributes(name):
        return next((e["attributes"] for e in elements if e["name"] == name), {})
    def is_false(value):
        # Modern aapt2 emits =false; older versions emit =(type 0x12)0x0.
        return value == "false" or bool(re.fullmatch(r"(?:\(type 0x12\))?0x0+", value or ""))
    permissions = sorted({e["attributes"]["name"] for e in elements
                          if e["name"] in ("uses-permission", "uses-permission-sdk-23") and "name" in e["attributes"]})
    providers = sorted({e["attributes"]["name"] for e in elements
                        if e["name"] == "provider" and "name" in e["attributes"]})
    app = attributes("application")
    sdk = attributes("uses-sdk")
    metadata = sorted({e["attributes"]["name"] for e in elements if e["name"] == "meta-data" and "name" in e["attributes"]})
    inputs = {}
    for element in elements:
        if element["name"] != "meta-data":
            continue
        key = element["attributes"].get("name", "")
        if key.startswith("findit.hidden."):
            if key in inputs:
                raise ValueError("Duplicate release-input metadata")
            inputs[key] = element["attributes"].get("value")
    return {
        "applicationId": attributes("manifest").get("package"),
        "versionName": attributes("manifest").get("versionName"),
        "versionCode": attributes("manifest").get("versionCode"),
        "applicationLabel": app.get("label"),
        "applicationIconResource": app.get("icon"),
        "releaseInputs": inputs,
        "minSdk": sdk.get("minSdkVersion"),
        "targetSdk": sdk.get("targetSdkVersion"),
        "permissions": permissions,
        "providers": providers,
        "metadataNames": metadata,
        "adsMetadataAbsent": not any(name.startswith("com.google.android.gms.ads.") for name in metadata),
        "debuggable": "debuggable" in app and not is_false(app["debuggable"]),
        "automaticAdsProviderAbsent": "com.google.android.gms.ads.MobileAdsInitProvider" not in providers,
        "aaidPermissionAbsent": "com.google.android.gms.permission.AD_ID" not in permissions,
        "adServicesPermissionsAbsent": not any(p.startswith("android.permission.ACCESS_ADSERVICES_") for p in permissions),
        "backupDisabled": is_false(app.get("allowBackup")),
        "fullBackupDisabled": is_false(app.get("fullBackupContent")),
        "cleartextDisabled": is_false(app.get("usesCleartextTraffic")),
        "dataExtractionRulesResource": app.get("dataExtractionRules"),
    }


def _sdk_root(argument):
    if argument:
        return Path(argument)
    for name in ("ANDROID_SDK_ROOT", "ANDROID_HOME"):
        if os.environ.get(name):
            return Path(os.environ[name])
    local = ROOT / "android/local.properties"
    if local.is_file():
        match = re.search(r"^sdk\.dir=(.+)$", local.read_text(), re.MULTILINE)
        if match:
            return Path(match.group(1).strip().replace("\\\\", "\\").replace("\\:", ":"))
    return Path(os.environ.get("LOCALAPPDATA", str(Path.home()))) / "Android/sdk"


def _build_tools(sdk):
    candidates = list((sdk / "build-tools").glob("*"))
    candidates.sort(key=lambda p: tuple(int(v) for v in re.findall(r"\d+", p.name)), reverse=True)
    for directory in candidates:
        if (directory / ("aapt2.exe" if os.name == "nt" else "aapt2")).is_file():
            return directory
    return None


def _java_environment():
    environment = dict(os.environ)
    if not environment.get("JAVA_HOME"):
        jbr = Path(os.environ.get("ProgramFiles", "C:/Program Files")) / "Android/Android Studio/jbr"
        if jbr.is_dir():
            environment["JAVA_HOME"] = str(jbr)
            environment["PATH"] = str(jbr / "bin") + os.pathsep + environment.get("PATH", "")
    return environment


def _run(arguments):
    result = subprocess.run(arguments, capture_output=True, text=True, timeout=90, env=_java_environment())
    if result.returncode != 0:
        raise ValueError(f"{Path(arguments[0]).name} failed ({result.returncode}): {(result.stderr or result.stdout)[-1500:]}")
    return result.stdout


def inspect_artifact(path, build_tools, *, profile="development", r8_mapping=None, expected_certificate_sha256=None, production_config=None):
    candidate = profile in CANDIDATE_PACKAGES
    signed_bundle = profile == SIGNED_BUNDLE_PROFILE
    strict = candidate or signed_bundle
    config = None
    pin = None
    if candidate and (path.suffix != ".apk" or build_tools is None or r8_mapping is None):
        raise ValueError("Candidate inspection requires an APK, installed Android build-tools and its matching R8 mapping")
    if profile == "qa-candidate" and not re.fullmatch(r"[0-9a-fA-F]{64}", expected_certificate_sha256 or ""):
        raise ValueError("QA inspection requires the pinned development-certificate SHA-256")
    if signed_bundle:
        if path.suffix != ".aab" or r8_mapping is None or production_config is None:
            raise ValueError("Signed production inspection requires an AAB, its matching R8 mapping and the final production config")
        config = load_production_config(production_config)
        pin = production_certificate_pin(expected_certificate_sha256)
    with path.open("rb") as source:
        digest = hashlib.file_digest(source, "sha256").hexdigest()
    report = {
        "file": str(path.relative_to(ROOT) if path.is_relative_to(ROOT) else path),
        "bytes": path.stat().st_size,
        "modifiedAt": datetime.fromtimestamp(path.stat().st_mtime, timezone.utc).isoformat(),
        "sha256": digest,
        "type": path.suffix.lstrip("."),
        "profile": profile,
        "nativeLibraries": [],
        "warnings": [],
    }
    with zipfile.ZipFile(path) as archive:
        if len(archive.namelist()) != len(set(archive.namelist())):
            raise ValueError("Duplicate ZIP entries are not allowed")
        if any("\\" in name or name.startswith("/") or ".." in PurePosixPath(name).parts for name in archive.namelist()):
            raise ValueError("Unsafe ZIP entry path")
        bad = archive.testzip()
        if bad:
            raise ValueError(f"ZIP CRC mismatch: {bad}")
        for info in archive.infolist():
            if not re.fullmatch(r"(?:base/)?lib/[^/]+/[^/]+\.so", info.filename):
                continue
            data = archive.read(info)
            bits, segments = elf_load_segments(data)
            required = bits == 64
            elf_ok = all(s["alignment"] >= PAGE_SIZE and
                         (s["offset"] - s["virtualAddress"]) % PAGE_SIZE == 0 for s in segments)
            stored = info.compress_type == zipfile.ZIP_STORED
            zip_offset = zip_data_offset(path, info)
            zip_ok = zip_offset % PAGE_SIZE == 0
            library = {
                "entry": info.filename, "elfBits": bits,
                "sha256": hashlib.sha256(data).hexdigest(),
                "loadSegmentAlignments": [s["alignment"] for s in segments],
                "elf16kRequired": required, "elf16kAligned": elf_ok,
                "zipStored": stored, "zipDataOffset": zip_offset,
                "apkZip16kAligned": zip_ok if stored and path.suffix == ".apk" else None,
            }
            if required and not elf_ok:
                raise ValueError(f"64-bit ELF LOAD alignment below 16 KB: {info.filename}")
            if required and stored and path.suffix == ".apk" and not zip_ok:
                raise ValueError(f"64-bit native APK ZIP offset is not 16 KB aligned: {info.filename}")
            report["nativeLibraries"].append(library)
            if strict and info.filename.endswith("/libapp.so"):
                markers = [marker.decode() for marker in (b"ca-app-pub-", b"plugins.flutter.io/google_mobile_ads", b"findit_ad_preview", b"main_ad_preview") if marker in data]
                if markers:
                    raise ValueError(f"Demo/advertising Dart markers remain in {info.filename}: {markers}")
        if not report["nativeLibraries"]:
            raise ValueError("No native libraries found in Flutter artifact")
        if strict:
            dex_pattern = r"base/dex/classes[0-9]*\.dex" if signed_bundle else r"classes[0-9]*\.dex"
            asset_prefix = "base/assets/flutter_assets/" if signed_bundle else "assets/flutter_assets/"
            report["adFreeDexScan"] = ad_free_dex_summary((name, archive.read(name)) for name in archive.namelist() if re.fullmatch(dex_pattern, name))
            report["catalogPreservation"] = candidate_catalog_summary(archive.read(asset_prefix + "assets/content/catalog.json"))
            report["adFreeR8Scan"] = ad_free_r8_summary(Path(r8_mapping))
            report["adFreeNativeDartMarkersAbsent"] = True
            report["sourceAssetPreservation"] = source_assets_summary(archive, asset_prefix)
            from generate_privacy_policy import check_html
            report["privacyPolicyParity"] = check_html()
        if path.suffix == ".aab":
            report["flutterDebugSymbolMetadata"] = bundle_debug_symbol_metadata(archive.namelist())
            alignment = bundle_native_alignment(archive.read("BundleConfig.pb"))
            report["bundleNativeConfig"] = alignment
            if alignment["uncompressNativeLibraries"] and alignment["alignmentEnum"] not in (2, 3):
                raise ValueError("Bundle requests less than 16 KB alignment for generated native APKs")
            report["jarSignaturePresent"] = any(n.endswith(".SF") for n in archive.namelist())
            if not report["jarSignaturePresent"]:
                raise ValueError("AAB has no JAR signing metadata")
            if signed_bundle:
                manifests = [name for name in archive.namelist() if re.fullmatch(r"[^/]+/manifest/AndroidManifest\.xml", name)]
                if manifests != ["base/manifest/AndroidManifest.xml"]:
                    raise ValueError("This release must contain only its base app module")
                summary = bundle_manifest_summary(archive.read(manifests[0]))
                validate_signed_bundle_manifest(summary, config)
                report["mergedManifest"] = summary
                report["applicationLabel"] = summary["applicationLabel"]
                mapping = archive.read("BUNDLE-METADATA/com.android.tools.build.obfuscation/proguard.map")
                if mapping != Path(r8_mapping).read_bytes():
                    raise ValueError("External R8 evidence does not match the bundle's embedded mapping")
                report["bundledR8MappingMatch"] = {"status": "passed", "sha256": hashlib.sha256(mapping).hexdigest()}
                if not alignment["uncompressNativeLibraries"] or alignment["alignmentEnum"] not in (2, 3):
                    raise ValueError("Final bundle must request 16 KB or greater native APK alignment")
                report["launcherIconPreservation"] = bundle_launcher_summary(archive, summary["applicationIconResource"])
                report["backupRules"] = bundle_backup_rules_summary(archive, summary["dataExtractionRulesResource"])
                for item in report["flutterDebugSymbolMetadata"]:
                    symbols = archive.read(item["metadata"])
                    if len(symbols) < 52 or not symbols.startswith(b"\x7fELF"):
                        raise ValueError("Bundle debug-symbol metadata is not a real ELF symbol payload")
                    item["bytes"] = len(symbols)
                    item["sha256"] = hashlib.sha256(symbols).hexdigest()

    if path.suffix == ".apk" and build_tools:
        suffix = ".exe" if os.name == "nt" else ""
        required = any(item["elf16kRequired"] for item in report["nativeLibraries"])
        zip_arguments = [str(build_tools / f"zipalign{suffix}"), "-c"]
        if required:
            zip_arguments += ["-P", "16"]
        output = _run(zip_arguments + ["-v", "4", str(path)])
        report["zipalignVerified"] = True
        report["zipalignOutputTail"] = output.splitlines()[-2:]
        manifest = _run([str(build_tools / f"aapt2{suffix}"), "dump", "xmltree", str(path), "--file", "AndroidManifest.xml"])
        summary = manifest_summary(manifest)
        report["mergedManifest"] = summary
        failed_gates = [key for key in (
            "automaticAdsProviderAbsent", "aaidPermissionAbsent", "adServicesPermissionsAbsent",
            "backupDisabled", "fullBackupDisabled", "cleartextDisabled",
        ) if not summary[key]]
        if failed_gates:
            raise ValueError(f"Merged APK manifest violates privacy gates: {', '.join(failed_gates)}")
        if candidate:
            validate_candidate_manifest(summary, profile)
            badging = _run([str(build_tools / f"aapt2{suffix}"), "dump", "badging", str(path)])
            label = re.search(r"(?m)^application-label:'([^']+)'", badging)
            report["applicationLabel"] = label.group(1) if label else None
            expected_label = "FindIt Hidden QA" if profile == "qa-candidate" else "FindIt Hidden"
            if report["applicationLabel"] != expected_label:
                raise ValueError(f"Wrong candidate launcher label: {report['applicationLabel']}")
            resources = inspect_apk_resources(path, build_tools)
            report["launcherIconPreservation"] = resources["launcherIconPreservation"]
            report["backupRules"] = resources["backupRules"]
            if resources["compiledManifest"]["applicationId"] != summary["applicationId"]:
                raise ValueError("Converted and binary APK manifests disagree")
        elif summary["applicationId"] != "abiral.mobile.findithiddenobjects.dev":
            report["warnings"].append("Non-development application ID; inspect publisher configuration separately.")
        signer = build_tools / ("apksigner.bat" if os.name == "nt" else "apksigner")
        if signer.is_file():
            metadata = apk_signing_metadata(path)
            report["signingMetadata"] = metadata
            if profile == "production-candidate":
                if metadata["jarSignatureFiles"] or metadata["apkSigningBlockPresent"]:
                    raise ValueError("Production candidate must be genuinely unsigned, not development-signed")
                result = subprocess.run([str(signer), "verify", "--print-certs", str(path)], capture_output=True, text=True, timeout=90, env=_java_environment())
                output = result.stdout + result.stderr
                confirm_unsigned_verifier(result.returncode, output)
                report["apkUnsignedVerified"] = True
                report["apkSignatureVerified"] = False
                report["unsignedVerifierOutput"] = output.strip()
            else:
                signed = _run([str(signer), "verify", "--print-certs", str(path)])
                report["apkSignatureVerified"] = True
                report["certificateSubjects"] = re.findall(r"Signer #\d+ certificate DN: (.+)", signed)
                digests = re.findall(r"Signer #\d+ certificate SHA-256 digest: ([0-9a-fA-F]+)", signed)
                report["certificateSha256"] = digests
                if expected_certificate_sha256 and digests != [expected_certificate_sha256.lower()]:
                    raise ValueError("APK signing certificate differs from the pinned QA certificate")
        else:
            if candidate:
                raise ValueError("Candidate signature/unsigned-state verification requires apksigner")
            report["warnings"].append("apksigner unavailable; signature unverified.")
    elif path.suffix == ".apk":
        report["warnings"].append("Android build-tools unavailable: manifest, zipalign and signature checks not run.")
    elif signed_bundle:
        report["bundleSignature"] = verify_bundle_signature(path, pin)
        report["jarSignatureVerified"] = True
        report["certificateSha256"] = [pin]
    else:
        environment = _java_environment()
        java_home = environment.get("JAVA_HOME")
        jarsigner = Path(java_home) / "bin/jarsigner.exe" if java_home and os.name == "nt" else None
        executable = str(jarsigner) if jarsigner and jarsigner.is_file() else shutil.which("jarsigner")
        if executable:
            signed = _run([executable, "-verify", str(path)])
            if "jar verified" not in signed.lower():
                raise ValueError("AAB JAR signature was not verified")
            report["jarSignatureVerified"] = True
        else:
            report["warnings"].append("jarsigner unavailable; only JAR signing metadata presence checked.")
    report["status"] = "passed" if not report["warnings"] else "passed_available_checks"
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("artifacts", nargs="*", help="APK/AAB files; defaults to local dev release outputs")
    parser.add_argument("--sdk", help="Installed Android SDK root")
    parser.add_argument("--output", default="release/verification/android-artifacts.json")
    parser.add_argument("--profile", choices=["development", *CANDIDATE_PACKAGES, SIGNED_BUNDLE_PROFILE], default="development")
    parser.add_argument("--r8-mapping", help="The matching candidate variant's R8 mapping; checks original names before obfuscation")
    parser.add_argument("--expected-certificate-sha256", help="Pinned QA certificate, or an explicit confirmation of the dedicated public upload pin")
    parser.add_argument("--production-config", help="Final production Dart defines, required by signed-production-aab")
    args = parser.parse_args()
    paths = [Path(p).resolve() for p in args.artifacts] if args.artifacts else sorted(
        list((ROOT / "build/app/outputs/flutter-apk").glob("app-*-dev-release.apk")) +
        list((ROOT / "build/app/outputs/bundle/devRelease").glob("*.aab"))
    )
    if not paths:
        parser.error("No development artifacts found. Build APKs and an AAB first.")
    if args.profile != "development" and len(paths) != 1:
        parser.error("Inspect each strict-profile artifact with its own matching R8 mapping.")
    build_tools = _build_tools(_sdk_root(args.sdk))
    reports = []
    for path in paths:
        try:
            result = inspect_artifact(path, build_tools, profile=args.profile, r8_mapping=args.r8_mapping, expected_certificate_sha256=args.expected_certificate_sha256, production_config=args.production_config)
            print(f"{path.name}: {result['status']}; {len(result['nativeLibraries'])} native libraries; {result['bytes'] / 1048576:.1f} MiB")
        except (ValueError, OSError, KeyError, struct.error, zipfile.BadZipFile, subprocess.SubprocessError) as error:
            result = {"file": str(path), "status": "failed", "error": str(error)}
            print(f"{path.name}: FAILED: {error}", file=sys.stderr)
        reports.append(result)
    consistency = {"status": "not_checked", "reason": "An artifact inspection failed."}
    if not any(r["status"] == "failed" for r in reports):
        try:
            consistency = native_payload_consistency(reports)
            print(f"APK/AAB native payload comparison: {consistency['status']}")
        except ValueError as error:
            consistency = {"status": "failed", "error": str(error)}
            print(f"APK/AAB native payload comparison: FAILED: {error}", file=sys.stderr)
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps({
        "createdAt": datetime.now(timezone.utc).isoformat(),
        "scope": "Packaging, source-policy parity and signature inspection only. No Android installation, real 16 KB runtime, live policy-hosting validation or publication.",
        "buildTools": str(build_tools) if build_tools else None,
        "profile": args.profile,
        "bundleConfigSchema": "https://github.com/google/bundletool/blob/master/src/main/proto/config.proto",
        "artifacts": reports,
        "nativePayloadConsistency": consistency,
    }, indent=2) + "\n", encoding="utf-8")
    print(f"Report: {output}")
    if any(r["status"] == "failed" for r in reports) or consistency["status"] == "failed":
        sys.exit(1)


if __name__ == "__main__":
    main()
