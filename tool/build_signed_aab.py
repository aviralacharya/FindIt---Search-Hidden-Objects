"""Build and inspect a local AAB using the EXISTING dedicated upload key.

Use --dialog for native masked entry, or a real terminal for getpass. Passwords
are sent only through child environments. Raw credential-bearing subprocess
output is deliberately discarded; saved evidence contains only public inputs
and fixed status messages. This tool never creates keys, installs, or publishes.
"""

import argparse
from contextlib import contextmanager
from datetime import datetime, timezone
import getpass
import hashlib
import ipaddress
import json
import os
from pathlib import Path
import re
import shutil
import socket
import subprocess
import sys
from urllib.error import URLError
from urllib.parse import urlparse
from urllib.request import build_opener, HTTPRedirectHandler, Request
import uuid

import generate_privacy_policy as policy
import prepare_release_inputs as key_setup
import verify_android_artifacts as inspector

ROOT = Path(__file__).resolve().parent.parent
SIGNING_VARIABLES = (
    "FINDIT_HIDDEN_STORE_FILE", "FINDIT_HIDDEN_STORE_PASSWORD",
    "FINDIT_HIDDEN_KEY_ALIAS", "FINDIT_HIDDEN_KEY_PASSWORD",
)
R8_FILES = ("configuration.txt", "mapping.prt", "mapping.txt", "resources.txt", "seeds.txt", "usage.txt")
MAX_POLICY_BYTES = 512 * 1024


def project_path(relative):
    path = ROOT / relative
    if path.resolve() != path.absolute():
        raise ValueError("A release path redirects elsewhere; nothing was overwritten.")
    return path


def local_preflight():
    gradle = project_path("android/app/build.gradle.kts").read_text(encoding="utf-8")
    if 'applicationId = "abiral.mobile.findithiddenobjects"' not in gradle:
        raise ValueError("This helper is only for the independent hidden-object app.")
    key = project_path(".local-signing/findit-hidden-objects-upload.p12")
    marker = project_path(".local-signing/.findit-hidden-signing")
    if not key.is_file() or not marker.is_file() or marker.read_text(encoding="utf-8") != key_setup.DIRECTORY_MARKER:
        raise ValueError("The existing dedicated upload key/directory is missing or unfamiliar. Do not recreate the key.")
    if project_path("android/key.properties").exists():
        raise ValueError("Remove saved signing credentials from this workflow; use private masked input instead.")
    configured_key = os.environ.get("FINDIT_HIDDEN_STORE_FILE")
    configured_alias = os.environ.get("FINDIT_HIDDEN_KEY_ALIAS")
    if ((configured_key and Path(configured_key).resolve() != key) or
            (configured_alias and configured_alias != key_setup.KEY_ALIAS)):
        raise ValueError("This helper can use only the existing dedicated upload key and alias.")
    if any(name.startswith(("FINDIT_ADMOB_", "ADMOB_")) or name == "AD_PREVIEW" for name in os.environ):
        raise ValueError("Advertising environment inputs are not permitted for this app.")
    return {"certificateSha256": inspector.production_certificate_pin(), "policyParity": policy.check_html()}


def validate_policy_url(url):
    if (not inspector.is_public_https(url) or len(url) > 2048 or
            re.search(r"[\x00-\x20\x7f]", url) or urlparse(url).fragment):
        raise ValueError("Use the actual public HTTPS policy page URL, without credentials or a fragment.")


def require_public_endpoint(url):
    validate_policy_url(url)
    parsed = urlparse(url)
    try:
        addresses = socket.getaddrinfo(parsed.hostname, parsed.port or 443, type=socket.SOCK_STREAM)
        public = addresses and all(ipaddress.ip_address(item[4][0]).is_global for item in addresses)
    except (OSError, ValueError):
        raise ValueError("The policy host could not be confirmed as a public endpoint.") from None
    if not public:
        raise ValueError("The policy host resolves to a private or reserved endpoint.")


class PublicHttpsRedirects(HTTPRedirectHandler):
    def redirect_request(self, request, response, code, message, headers, newurl):
        require_public_endpoint(newurl)
        return super().redirect_request(request, response, code, message, headers, newurl)


def verify_live_policy(url):
    """Require the complete generated HTML, allowing only BOM/CRLF transport changes."""
    require_public_endpoint(url)
    request = Request(url, headers={"Accept": "text/html", "User-Agent": "FindIt-Policy-Release-Check/1.0"})
    try:
        with build_opener(PublicHttpsRedirects()).open(request, timeout=30) as response:
            final_url = response.geturl()
            require_public_endpoint(final_url)
            if (response.status != 200 or response.headers.get_content_type() != "text/html" or
                    "attachment" in response.headers.get("Content-Disposition", "").lower()):
                raise ValueError("The live policy must return a public HTML page, not a login or download.")
            content = response.read(MAX_POLICY_BYTES + 1)
    except (OSError, URLError):
        raise ValueError("The live HTTPS policy could not be loaded; no response content was logged.") from None
    try:
        rendered = content.decode("utf-8-sig").replace("\r\n", "\n")
    except UnicodeError:
        raise ValueError("The live policy is not the generated UTF-8 HTML page.") from None
    if len(content) > MAX_POLICY_BYTES or rendered != policy.expected_html():
        raise ValueError("The live policy differs from the current complete privacy-policy.html. Publish the current file first.")
    return {"status": "passed", "requestedUrl": url, "finalUrl": final_url,
            "downloadSha256": hashlib.sha256(content).hexdigest(), "completeCanonicalHtmlMatches": True,
            "checkedAtUtc": datetime.now(timezone.utc).isoformat()}


def production_config(url):
    validate_policy_url(url)
    value = {"APP_ENV": "production", "BUILD_STAGE": "final", "PACK_INDEX_URL": "", "PRIVACY_POLICY_URL": url}
    path = project_path("config/production.json")
    if path.exists() and inspector.load_production_config(path) != value:
        raise ValueError("Existing production.json differs from this URL; it was not overwritten.")
    return path, value


def persist_config(path, value):
    if path.exists():
        if inspector.load_production_config(path) != value:
            raise ValueError("Existing production.json changed; it was not overwritten.")
        return
    with path.open("x", encoding="utf-8", newline="\n") as output:
        output.write(json.dumps(value, indent=2) + "\n")


def flutter_executable():
    configured = os.environ.get("FINDIT_HIDDEN_FLUTTER")
    if configured:
        candidates = [Path(configured)]
    else:
        local = Path(os.environ.get("LOCALAPPDATA", str(Path.home())))
        candidates = [local / "Temp/opencode/flutter-sdk/bin/flutter.bat"]
        installed = shutil.which("flutter")
        if installed:
            candidates.append(Path(installed))
    for path in candidates:
        if path.is_file():
            return path.resolve()
    raise ValueError("Flutter is unavailable. Set FINDIT_HIDDEN_FLUTTER to this app's working Flutter executable.")


def child_environment(flutter, password, key_password):
    environment = inspector._java_environment()
    # Never carry the original app's signing variables into this build.
    for name in list(environment):
        if name.startswith("FINDIT_"):
            environment.pop(name)
    environment.update({
        "FINDIT_HIDDEN_STORE_FILE": str(project_path(".local-signing/findit-hidden-objects-upload.p12")),
        "FINDIT_HIDDEN_STORE_PASSWORD": password,
        "FINDIT_HIDDEN_KEY_ALIAS": key_setup.KEY_ALIAS,
        "FINDIT_HIDDEN_KEY_PASSWORD": key_password,
        # Avoid retaining credentials in a reusable Gradle daemon. A single-use
        # daemon may still be required by JVM settings and exits after the build.
        "GRADLE_OPTS": "-Dorg.gradle.daemon=false -Dorg.gradle.console=plain",
    })
    environment["PATH"] = os.pathsep.join((str(flutter.parent), str(flutter.parent / "cache/dart-sdk/bin"), environment.get("PATH", "")))
    return environment


def private_command(arguments, environment, step):
    try:
        result = subprocess.run(arguments, cwd=ROOT, env=environment, capture_output=True, check=False)
    except (OSError, subprocess.SubprocessError):
        raise ValueError(f"{step} could not complete; raw subprocess output was not logged.") from None
    if result.returncode:
        raise ValueError(f"{step} failed (exit {result.returncode}); raw subprocess output was not logged.")
    return result.stdout


@contextmanager
def build_lock():
    path = project_path(".local-signing/.signed-aab-build.lock")
    token = str(uuid.uuid4())
    try:
        with path.open("x", encoding="ascii") as output:
            output.write(token)
    except FileExistsError:
        raise ValueError("A signed-build lock already exists. Do not start concurrent Flutter builds or remove an active lock.") from None
    try:
        yield
    finally:
        if path.is_file() and path.read_text(encoding="ascii") == token:
            path.unlink()  # Only the lock created by this invocation.


def write_json(path, value):
    path.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8", newline="\n")


def retain_bundle(bundle, mapping, directory, artifact):
    with bundle.open("rb") as source:
        digest = hashlib.file_digest(source, "sha256").hexdigest()
    if artifact.get("status") != "passed" or artifact.get("sha256") != digest:
        raise ValueError("The resulting AAB does not match a passed strict inspection.")
    sources = [(bundle, directory / "FindIt-Hidden-Objects-1.0.0.aab")]
    sources.extend((mapping / name, directory / "r8" / name) for name in R8_FILES)
    if any(not source.is_file() or target.exists() for source, target in sources):
        raise ValueError("Release evidence is missing or a destination exists; nothing was overwritten.")
    (directory / "r8").mkdir()
    for source, target in sources:
        with source.open("rb") as content, target.open("xb") as output:
            shutil.copyfileobj(content, output)
    for path, expected in ((sources[0][1], artifact["sha256"]),
                           (directory / "r8/mapping.txt", artifact["bundledR8MappingMatch"]["sha256"])):
        with path.open("rb") as content:
            if hashlib.file_digest(content, "sha256").hexdigest() != expected:
                raise ValueError("Retained AAB/R8 bytes changed after inspection; no successful handoff is claimed.")
    with (directory / "SHA256SUMS.txt").open("x", encoding="utf-8", newline="\n") as output:
        for path in sorted(path for path in directory.rglob("*") if path.is_file() and path.name != "SHA256SUMS.txt"):
            with path.open("rb") as content:
                digest = hashlib.file_digest(content, "sha256").hexdigest()
            output.write(f"{digest}  {path.relative_to(directory).as_posix()}\n")


def build_signed_aab(url, password, *, key_password=None, backup_confirmed=False, publisher_review_confirmed=False):
    if not backup_confirmed or not publisher_review_confirmed:
        raise ValueError("Confirm the secure key backup and publisher's identity/asset/policy review before signing.")
    key_password = password if key_password is None else key_password
    if not all(isinstance(value, str) and value and "\0" not in value for value in (password, key_password)):
        raise ValueError("The existing key requires fresh private password entry.")
    validate_policy_url(url)
    if any(value in url for value in (password, key_password)):
        raise ValueError("A signing password must never be part of a public policy URL.")
    preflight = local_preflight()
    config_path, config = production_config(url)
    flutter = flutter_executable()
    environment = child_environment(flutter, password, key_password)
    try:
        with build_lock():
            hosted = verify_live_policy(url)
            certificate = private_command([
                key_setup._keytool(), "-exportcert", "-keystore", environment["FINDIT_HIDDEN_STORE_FILE"],
                "-storetype", "PKCS12", "-alias", key_setup.KEY_ALIAS,
                "-storepass:env", "FINDIT_HIDDEN_STORE_PASSWORD",
            ], environment, "Existing upload-key verification")
            if hashlib.sha256(certificate).hexdigest() != preflight["certificateSha256"]:
                raise ValueError("The existing keystore does not match this app's pinned public upload certificate.")
            persist_config(config_path, config)
            now = datetime.now(timezone.utc)
            directory = project_path(f"release/local/{now:%Y-%m-%d}/revisions/signed-{now:%H-%M-%S-%fZ}")
            directory.mkdir(parents=True, exist_ok=False)
            status_path = directory / "build-status.json"
            status = {"createdAtUtc": now.isoformat(), "status": "building", "certificateSha256": preflight["certificateSha256"],
                      "scope": "Local signed AAB only; no installation, device QA, upload or publication. Raw build output is not saved."}
            write_json(status_path, status)
            write_json(directory / "policy-hosting.json", hosted)
            try:
                private_command([str(flutter), "build", "appbundle", "--release", "--no-pub", "--flavor", "prod",
                                 "--dart-define-from-file=config/production.json"], environment, "Signed AAB build")
                for name in SIGNING_VARIABLES:
                    environment.pop(name, None)
                bundle = project_path("build/app/outputs/bundle/prodRelease/app-prod-release.aab")
                mapping = project_path("build/app/outputs/mapping/prodRelease")
                if not bundle.is_file() or bundle.stat().st_mtime < now.timestamp():
                    raise ValueError("No freshly produced AAB was found; existing outputs were not handed off as a new build.")
                inspection_path = directory / "inspection.json"
                private_command([sys.executable, str(ROOT / "tool/verify_android_artifacts.py"), "--profile", "signed-production-aab",
                                 "--production-config", str(config_path), "--r8-mapping", str(mapping / "mapping.txt"),
                                 "--output", str(inspection_path), str(bundle)], environment, "Strict AAB inspection")
                report = json.loads(inspection_path.read_text(encoding="utf-8"))
                if len(report["artifacts"]) != 1:
                    raise ValueError("Exactly one strictly inspected AAB is required.")
                artifact = report["artifacts"][0]
                if (report.get("profile") != "signed-production-aab" or not artifact.get("jarSignatureVerified") or
                        artifact.get("certificateSha256") != [preflight["certificateSha256"]]):
                    raise ValueError("The strict inspection did not confirm the dedicated upload signature.")
                status.update(status="passed", aabSha256=artifact["sha256"])
                write_json(status_path, status)
                retain_bundle(bundle, mapping, directory, artifact)
            except Exception:
                # Never serialize exception/child output from the signing path.
                status.update(status="failed", error="Build, inspection or retention did not complete. No store-ready handoff is claimed.")
                write_json(status_path, status)
                raise ValueError("Signed release did not complete. Public status evidence was saved; no credentials or raw build output were logged.") from None
            return directory
    finally:
        for name in SIGNING_VARIABLES:
            environment.pop(name, None)


def private_dialog(initial_url=""):
    import tkinter as tk
    from tkinter import messagebox, ttk

    root = tk.Tk()
    root.title("FindIt Hidden — build with existing upload key")
    root.resizable(False, False)
    frame = ttk.Frame(root, padding=24)
    frame.grid()
    ttk.Label(frame, text="Existing key only · abiral.mobile.findithiddenobjects", font=("Segoe UI", 12, "bold")).grid(sticky="w")
    ttk.Label(frame, text="Enter the rendered GitHub Pages HTTPS URL and the existing key's password.\n"
              "The password stays out of chat, saved configuration, commands and logs.\n"
              "This builds locally. It does not install, upload or publish anything.", justify="left").grid(sticky="w", pady=(10, 18))
    url = tk.StringVar(value=initial_url)
    password = tk.StringVar()
    backed_up = tk.BooleanVar(value=False)
    reviewed = tk.BooleanVar(value=False)
    ttk.Label(frame, text="Live HTTPS privacy-policy page").grid(sticky="w")
    ttk.Entry(frame, textvariable=url, width=76).grid(sticky="w", pady=(4, 12))
    ttk.Label(frame, text="Existing upload-key password").grid(sticky="w")
    entry = ttk.Entry(frame, textvariable=password, show="•", width=48)
    entry.grid(sticky="w", pady=(4, 14))
    ttk.Checkbutton(frame, variable=backed_up, text="The key is securely backed up; its password is kept separately.").grid(sticky="w")
    ttk.Checkbutton(frame, variable=reviewed, text="I approve the package, developer/contact details, asset rights and policy commitments.").grid(sticky="w", pady=(6, 14))
    result = []

    def submit():
        try:
            validate_policy_url(url.get())
            if not password.get() or not backed_up.get() or not reviewed.get():
                raise ValueError("Enter the existing password and confirm both review items.")
        except ValueError as error:
            messagebox.showerror("Release inputs", str(error), parent=root)
            return
        result.append((url.get(), password.get()))
        password.set("")
        root.destroy()

    def cancel():
        password.set("")
        root.destroy()

    ttk.Button(frame, text="Verify policy & build signed AAB", command=submit).grid(sticky="w")
    root.protocol("WM_DELETE_WINDOW", cancel)
    root.lift()
    entry.focus_set()
    root.mainloop()
    if not result:
        raise ValueError("Private input was cancelled; no signed build was started.")
    return result[0]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--dialog", action="store_true", help="Native masked entry; reuses the existing key")
    mode.add_argument("--from-environment", action="store_true", help="Use approved process-local signing passwords; never put values in a command")
    mode.add_argument("--check-only", action="store_true", help="Check local key paths, public pin and policy parity; no passwords, network or build")
    parser.add_argument("--policy-url", help="Actual public rendered policy URL, never a signing password")
    parser.add_argument("--confirm-backup", action="store_true")
    parser.add_argument("--confirm-publisher-review", action="store_true")
    args = parser.parse_args()
    password = key_password = ""
    try:
        local_preflight()
        if args.check_only:
            print("Local signing preflight passed: existing dedicated key path, public pin and shared policy parity.")
            print("No password was read, no keystore was opened, and no AAB was built or published.")
            return 0
        url = args.policy_url or ""
        if args.dialog:
            url, password = private_dialog(url)
            key_password = password
            backup = review = True  # Both were explicitly checked in the dialog.
        else:
            validate_policy_url(url)
            backup, review = args.confirm_backup, args.confirm_publisher_review
            if not backup or not review:
                raise ValueError("Confirm the backup and publisher review before supplying signing credentials.")
            if args.from_environment:
                password = os.environ.get("FINDIT_HIDDEN_STORE_PASSWORD", "")
                key_password = os.environ.get("FINDIT_HIDDEN_KEY_PASSWORD", password)
            else:
                if not sys.stdin.isatty():
                    raise ValueError("Use --dialog or a real interactive terminal. Never put a password in a command or chat.")
                password = getpass.getpass("Existing upload-key password (not stored): ")
                key_password = password
        print("Verifying the hosted policy, reusing the existing key, then building and inspecting the local AAB…")
        directory = build_signed_aab(url, password, key_password=key_password,
                                     backup_confirmed=backup, publisher_review_confirmed=review)
        print(f"Signed AAB and matching public evidence: {directory.relative_to(ROOT)}")
        print("Device QA and Play Console review remain required. Nothing was installed, uploaded or published.")
        return 0
    except (ValueError, OSError, KeyError, TypeError, subprocess.SubprocessError):
        print("Signed release not completed. Check the public prerequisites/status; no password or raw subprocess output was logged.", file=sys.stderr)
        return 1
    finally:
        password = key_password = ""


if __name__ == "__main__":
    sys.exit(main())
