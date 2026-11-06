"""Recheck recorded source hashes without changing anything in the original app.

Run from the new project root: python tool/verify_source_reuse.py
Scope is the files recorded when copied, not an unrecorded whole-folder baseline.
"""

import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path, PurePosixPath
import re

ROOT = Path(__file__).resolve().parent.parent


def digest(path):
    with path.open("rb") as source:
        return hashlib.file_digest(source, "sha256").hexdigest()


def original_release_checksums(source):
    """Read the original checksum list and artifacts, never rebaseline or write them."""
    directory = source / "release/production/revisions/final"
    checksum_file = directory / "SHA256SUMS.txt"
    if not checksum_file.is_file():
        return {"status": "failed", "checksumFile": str(checksum_file),
                "error": "Original release checksum list is missing.", "files": []}
    files = []
    for line in checksum_file.read_text(encoding="utf-8-sig").splitlines():
        if not line.strip():
            continue
        match = re.fullmatch(r"([a-fA-F0-9]{64})\s+\*?(.+)", line)
        if match is None:
            raise ValueError("Malformed original release checksum entry.")
        expected, filename = match.groups()
        relative = PurePosixPath(filename.replace("\\", "/"))
        artifact = directory.joinpath(*relative.parts).resolve()
        if relative.is_absolute() or ".." in relative.parts or not artifact.is_relative_to(directory.resolve()):
            raise ValueError("Unsafe original release checksum path.")
        actual = digest(artifact) if artifact.is_file() else None
        files.append({"file": str(relative), "expectedSha256": expected.lower(),
                      "actualSha256": actual, "status": "passed" if actual == expected.lower() else "failed"})
    if not files or len({item["file"] for item in files}) != len(files):
        raise ValueError("Original release checksum list is empty or contains duplicate files.")
    return {"status": "passed" if all(item["status"] == "passed" for item in files) else "failed",
            "checksumFile": str(checksum_file),
            "scope": "Matches the original APKs against their existing checksum list; does not rewrite the list or artifacts.",
            "files": files}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", default="verification/source-preservation.json")
    args = parser.parse_args()
    output = Path(args.output).resolve()
    if not output.is_relative_to(ROOT):
        parser.error("The report must stay inside this new project.")
    manifest = json.loads((ROOT / "verification/source-reuse.json").read_text(encoding="utf-8-sig"))
    source = Path(manifest["source"])
    if source.resolve() == ROOT or Path(manifest["destination"]).resolve() != ROOT:
        parser.error("The reuse manifest does not describe two independent project folders.")
    differences, unchanged, adapted, absent = [], [], [], []
    for item in manifest["files"]:
        relative = PurePosixPath(item["path"].replace("\\", "/"))
        if relative.is_absolute() or ".." in relative.parts:
            parser.error("Unsafe recorded path.")
        original = source.joinpath(*relative.parts)
        copied = ROOT.joinpath(*relative.parts)
        expected = item["sourceSha256"]
        actual = digest(original) if original.is_file() else None
        if actual != expected:
            differences.append({"path": str(relative), "expected": expected, "actual": actual})
        if not copied.is_file():
            absent.append(str(relative))
        elif digest(copied) == expected:
            unchanged.append(str(relative))
        else:
            adapted.append(str(relative))
    releases = original_release_checksums(source)
    report = {
        "createdAtUtc": datetime.now(timezone.utc).isoformat(),
        "source": str(source),
        "destination": str(ROOT),
        "scope": "Original hashes of every reused file recorded at copy time. Non-copied files were not baselined by this manifest.",
        "checkedSourceFiles": len(manifest["files"]),
        "sourceMatches": len(manifest["files"]) - len(differences),
        "sourceDifferences": differences,
        "destinationUnchangedCopies": unchanged,
        "destinationAdaptedFiles": adapted,
        "destinationAbsentOrRenamedPaths": absent,
        "originalReleases": releases,
        "status": "passed" if not differences and releases["status"] == "passed" else "failed",
    }
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(f"Original source hashes: {report['sourceMatches']}/{report['checkedSourceFiles']} match. Report: {output.relative_to(ROOT)}")
    print(f"Original release checksums: {releases['status']} ({len(releases['files'])} artifacts).")
    if report["status"] != "passed":
        raise SystemExit(1)


if __name__ == "__main__":
    main()
