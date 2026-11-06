"""Import the publisher's PNG and create this app's separate upload key.

Passwords are entered in a native masked dialog (or a real interactive terminal),
passed to keytool through its child environment, and never written or printed.
This tool never builds, installs, uploads, or publishes an Android app.
"""

import argparse
import base64
from datetime import datetime, timezone
import getpass
import hashlib
import json
import os
from pathlib import Path
import re
import secrets
import shutil
import struct
import subprocess
import sys
from tempfile import TemporaryDirectory
import zlib

ROOT = Path(__file__).resolve().parent.parent
ICON_SOURCE = ROOT / "assets/branding/icon_source.png"
KEY_DIRECTORY = ROOT / ".local-signing"
KEYSTORE = KEY_DIRECTORY / "findit-hidden-objects-upload.p12"
KEY_ALIAS = "findit-hidden-upload"
KEY_SUBJECT = "CN=FindIt Hidden Upload, OU=Android Upload, O=FindIt Hidden"
CERTIFICATE = ROOT / "verification/signing/production-upload-certificate.pem"
CERTIFICATE_REPORT = CERTIFICATE.with_suffix(".json")
DIRECTORY_MARKER = "Private upload signing for abiral.mobile.findithiddenobjects\n"
PASSWORD_VARIABLE = "FINDIT_HIDDEN_STORE_PASSWORD"


def validate_icon_png(data):
    if len(data) > 10 * 1024 * 1024 or data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError("Choose the original PNG, no larger than 10 MiB.")
    offset, dimensions, ended = 8, None, False
    while offset + 12 <= len(data):
        length = struct.unpack_from(">I", data, offset)[0]
        end = offset + 12 + length
        if end > len(data):
            raise ValueError("The PNG is truncated.")
        kind = data[offset + 4:offset + 8]
        payload = data[offset + 8:end - 4]
        if zlib.crc32(kind + payload) & 0xFFFFFFFF != struct.unpack_from(">I", data, end - 4)[0]:
            raise ValueError("The PNG failed its checksum check.")
        if dimensions is None:
            if kind != b"IHDR" or length != 13:
                raise ValueError("The PNG has no valid image header.")
            width, height = struct.unpack_from(">II", payload)[0:2]
            if width != height or not 512 <= width <= 4096:
                raise ValueError("Use the square original PNG, between 512 and 4096 pixels.")
            dimensions = {"width": width, "height": height}
        if kind == b"acTL":
            raise ValueError("Use a static PNG, not an animated icon.")
        offset = end
        if kind == b"IEND":
            ended = length == 0 and offset == len(data)
            break
    if not ended:
        raise ValueError("The PNG has no valid end marker.")
    return dimensions


def import_icon(source):
    source = Path(source).resolve()
    if not source.is_file() or source.stat().st_size > 10 * 1024 * 1024:
        raise ValueError("The selected original PNG does not exist or is too large.")
    data = source.read_bytes()
    dimensions = validate_icon_png(data)
    if ICON_SOURCE.exists():
        if ICON_SOURCE.read_bytes() != data:
            raise ValueError("icon_source.png already contains a different image; it was not overwritten.")
    else:
        ICON_SOURCE.parent.mkdir(parents=True, exist_ok=True)
        with ICON_SOURCE.open("xb") as output:
            output.write(data)
    report = ROOT / "verification/branding/icon-source.json"
    value = {
        "file": ICON_SOURCE.relative_to(ROOT).as_posix(),
        "sha256": hashlib.sha256(data).hexdigest(),
        "bytes": len(data), **dimensions,
        "provenance": "Original PNG supplied and selected by the publisher; distribution rights require publisher review.",
    }
    report.parent.mkdir(parents=True, exist_ok=True)
    if report.exists():
        if json.loads(report.read_text(encoding="utf-8")) != value:
            raise ValueError("An existing icon-source report differs; it was not overwritten.")
    else:
        with report.open("x", encoding="utf-8") as output:
            output.write(json.dumps(value, indent=2) + "\n")
    return value


def _keytool():
    executable = shutil.which("keytool")
    if executable:
        return executable
    for home in (os.environ.get("JAVA_HOME"),
                 str(Path(os.environ.get("ProgramFiles", "C:/Program Files")) / "Android/Android Studio/jbr")):
        if home:
            candidate = Path(home) / "bin" / ("keytool.exe" if os.name == "nt" else "keytool")
            if candidate.is_file():
                return str(candidate)
    raise ValueError("JDK keytool is unavailable. Install/configure the JDK before creating the key.")


def _sensitive_command(arguments, environment):
    try:
        result = subprocess.run(arguments, env=environment, capture_output=True,
                                text=True, timeout=180, check=False)
    except (OSError, subprocess.SubprocessError):
        raise ValueError("The local signing command could not complete; no credentials were logged.") from None
    if result.returncode != 0:
        # Deliberately do not propagate command output from a credential-bearing
        # subprocess. The command line itself contains only environment names.
        raise ValueError(f"Local keytool operation failed (exit {result.returncode}); no credentials were logged.")
    return result.stdout


def _restrict_directory(directory):
    if os.name != "nt":
        directory.chmod(0o700)
        return
    account = subprocess.run(["whoami"], capture_output=True, text=True,
                             timeout=20, check=True).stdout.strip()
    result = subprocess.run([
        "icacls", str(directory), "/inheritance:r", "/grant:r",
        f"{account}:(OI)(CI)F", "*S-1-5-18:(OI)(CI)F", "*S-1-5-32-544:(OI)(CI)F",
    ], capture_output=True, text=True, timeout=20, check=False)
    if result.returncode:
        raise ValueError("Could not restrict the new private key directory. No key was generated.")


def _private_directory():
    if KEY_DIRECTORY.resolve() != KEY_DIRECTORY.absolute():
        raise ValueError("The private key directory must not redirect outside this project.")
    marker = KEY_DIRECTORY / ".findit-hidden-signing"
    if KEY_DIRECTORY.exists():
        if not marker.is_file() or marker.read_text(encoding="utf-8") != DIRECTORY_MARKER:
            raise ValueError("An unfamiliar .local-signing directory exists; it was not changed.")
        return
    KEY_DIRECTORY.mkdir()
    _restrict_directory(KEY_DIRECTORY)
    marker.write_text(DIRECTORY_MARKER, encoding="utf-8")


def create_upload_key(password):
    gradle = (ROOT / "android/app/build.gradle.kts").read_text(encoding="utf-8")
    if 'applicationId = "abiral.mobile.findithiddenobjects"' not in gradle:
        raise ValueError("This helper is only for the independent hidden-object app.")
    if len(password) < 8:
        raise ValueError("Use an upload-key password with at least eight characters.")
    for path in (KEYSTORE, CERTIFICATE, CERTIFICATE_REPORT):
        if path.exists():
            raise ValueError("An upload key or its public certificate record already exists; nothing was overwritten.")
    executable = _keytool()
    _private_directory()
    environment = dict(os.environ)
    environment[PASSWORD_VARIABLE] = password
    environment["FINDIT_HIDDEN_KEY_PASSWORD"] = password
    try:
        with TemporaryDirectory(prefix=".create-", dir=KEY_DIRECTORY) as temporary:
            staged = Path(temporary) / "upload.p12"
            _sensitive_command([
                executable, "-genkeypair", "-keystore", str(staged),
                "-storetype", "PKCS12", "-alias", KEY_ALIAS,
                "-keyalg", "RSA", "-keysize", "3072", "-sigalg", "SHA256withRSA",
                "-validity", "10000", "-dname", KEY_SUBJECT,
                "-storepass:env", PASSWORD_VARIABLE,
                "-keypass:env", "FINDIT_HIDDEN_KEY_PASSWORD", "-noprompt",
            ], environment)
            pem_output = _sensitive_command([
                executable, "-exportcert", "-rfc", "-keystore", str(staged),
                "-storetype", "PKCS12", "-alias", KEY_ALIAS,
                "-storepass:env", PASSWORD_VARIABLE,
            ], environment)
            match = re.search(r"-----BEGIN CERTIFICATE-----\s+([A-Za-z0-9+/=\s]+?)\s+-----END CERTIFICATE-----", pem_output)
            if not match:
                raise ValueError("The new key's public certificate could not be exported.")
            encoded = re.sub(r"\s", "", match.group(1))
            certificate = base64.b64decode(encoded, validate=True)
            pem = "-----BEGIN CERTIFICATE-----\n" + "\n".join(
                encoded[index:index + 64] for index in range(0, len(encoded), 64)
            ) + "\n-----END CERTIFICATE-----\n"
            # A hard link publishes without replacing any existing destination,
            # even if another process created it after the preflight check.
            os.link(staged, KEYSTORE)
        report = {
            "createdAt": datetime.now(timezone.utc).isoformat(),
            "applicationId": "abiral.mobile.findithiddenobjects",
            "keystore": KEYSTORE.relative_to(ROOT).as_posix(),
            "storeType": "PKCS12", "keyAlias": KEY_ALIAS,
            "certificateSha256": hashlib.sha256(certificate).hexdigest(),
            "certificateSubject": KEY_SUBJECT,
            "keyAlgorithm": "RSA", "keySize": 3072,
            "signatureAlgorithm": "SHA256withRSA", "validityDays": 10000,
            "scope": "New dedicated upload key only. No original key used; no AAB built, uploaded or published.",
        }
        CERTIFICATE.parent.mkdir(parents=True, exist_ok=True)
        with CERTIFICATE.open("x", encoding="ascii") as output:
            output.write(pem)
        with CERTIFICATE_REPORT.open("x", encoding="utf-8") as output:
            output.write(json.dumps(report, indent=2) + "\n")
        (KEY_DIRECTORY / "BACKUP-INSTRUCTIONS.txt").write_text(
            "Back up findit-hidden-objects-upload.p12 securely before distribution.\n"
            "Keep its password in a separate password manager; it is not stored here.\n"
            "Alias: findit-hidden-upload. Store type: PKCS12.\n"
            "This is an upload key for abiral.mobile.findithiddenobjects only.\n"
            "Use Google Play App Signing for the new listing. Never upload/share the private keystore.\n"
            "Only verification/signing/production-upload-certificate.pem is a public certificate.\n",
            encoding="utf-8",
        )
        return report
    finally:
        environment.pop(PASSWORD_VARIABLE, None)
        environment.pop("FINDIT_HIDDEN_KEY_PASSWORD", None)


def prepare(icon_path, password):
    # Validate the image before generating a long-lived signing credential.
    icon = import_icon(icon_path)
    key = create_upload_key(password)
    return {"icon": icon, "uploadKey": key}


def native_dialog():
    import tkinter as tk
    from tkinter import filedialog, messagebox, ttk

    if KEYSTORE.exists():
        raise ValueError("The dedicated key already exists; this helper will not replace it.")
    root = tk.Tk()
    root.title("FindIt Hidden — private local release setup")
    root.resizable(False, False)
    frame = ttk.Frame(root, padding=24)
    frame.grid()
    ttk.Label(frame, text="New app: abiral.mobile.findithiddenobjects",
              font=("Segoe UI", 12, "bold")).grid(row=0, column=0, columnspan=2, sticky="w")
    ttk.Label(frame, text="Choose your original PNG and enter the signing password privately.\n"
              "No password is printed, stored in a config file, or transmitted.\n"
              "This creates a separate upload key; it does not build or publish an app.",
              justify="left").grid(row=1, column=0, columnspan=2, sticky="w", pady=(10, 18))
    icon = tk.StringVar(value=str(ICON_SOURCE) if ICON_SOURCE.exists() else "")
    password = tk.StringVar()
    confirmation = tk.StringVar()
    ttk.Label(frame, text="Original square PNG").grid(row=2, column=0, sticky="w")
    ttk.Entry(frame, textvariable=icon, width=66).grid(row=3, column=0, sticky="w", pady=(4, 12))

    def browse():
        path = filedialog.askopenfilename(parent=root, title="Choose the icon you supplied",
                                         filetypes=[("PNG image", "*.png")])
        if path:
            icon.set(path)

    ttk.Button(frame, text="Browse…", command=browse).grid(row=3, column=1, padx=(8, 0), pady=(4, 12))
    ttk.Label(frame, text="Upload-key password").grid(row=4, column=0, sticky="w")
    password_entry = ttk.Entry(frame, textvariable=password, show="•", width=42)
    password_entry.grid(row=5, column=0, sticky="w", pady=(4, 12))
    ttk.Label(frame, text="Confirm password").grid(row=6, column=0, sticky="w")
    ttk.Entry(frame, textvariable=confirmation, show="•", width=42).grid(row=7, column=0, sticky="w", pady=(4, 16))
    status = tk.StringVar(value="The original FindIt app and its keys will not be changed.")
    ttk.Label(frame, textvariable=status, wraplength=520).grid(row=8, column=0, columnspan=2, sticky="w")
    completed = []

    def submit():
        value = password.get()
        if not secrets.compare_digest(value.encode("utf-8"), confirmation.get().encode("utf-8")):
            messagebox.showerror("Passwords differ", "Please enter matching passwords.", parent=root)
            return
        button.state(["disabled"])
        status.set("Validating the PNG and generating the dedicated upload key…")
        root.update_idletasks()
        try:
            result = prepare(icon.get(), value)
        except (ValueError, OSError, subprocess.SubprocessError) as error:
            status.set("Setup did not complete. Existing files were not overwritten.")
            messagebox.showerror("Release setup", str(error), parent=root)
            button.state(["!disabled"])
        else:
            completed.append(result)
            messagebox.showinfo("Local setup complete",
                                "The original PNG was imported and a separate upload key was created.\n\n"
                                "Back up .local-signing/findit-hidden-objects-upload.p12 securely.\n"
                                "Keep its password separately. The public privacy-policy URL is still\n"
                                "required before the final signed AAB can be built.", parent=root)
            password.set("")
            confirmation.set("")
            root.destroy()
        finally:
            if not completed:
                password.set("")
                confirmation.set("")
            value = ""

    button = ttk.Button(frame, text="Import icon & create upload key", command=submit)
    button.grid(row=9, column=0, columnspan=2, sticky="w", pady=(20, 0))
    root.lift()
    password_entry.focus_set()
    root.mainloop()
    if not completed:
        raise ValueError("Private setup was cancelled; no successful setup is claimed.")
    return completed[0]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dialog", action="store_true", help="Use a native masked password and file-picker dialog")
    parser.add_argument("--icon", type=Path, help="Original square PNG for an interactive terminal setup")
    args = parser.parse_args()
    try:
        if args.dialog:
            result = native_dialog()
        else:
            if not args.icon or not sys.stdin.isatty():
                parser.error("Use --dialog, or --icon PATH from a real interactive terminal. Never put a password in the command.")
            password = getpass.getpass("Upload-key password (not stored): ")
            confirmation = getpass.getpass("Confirm password: ")
            if not secrets.compare_digest(password.encode("utf-8"), confirmation.encode("utf-8")):
                raise ValueError("Passwords differ; nothing was generated.")
            result = prepare(args.icon, password)
            password = confirmation = ""
        print("Imported the publisher's original PNG into assets/branding/icon_source.png.")
        print("Created the dedicated private upload keystore in .local-signing/ (back it up securely).")
        print(f"Public upload-certificate SHA-256: {result['uploadKey']['certificateSha256']}")
        print("No AAB was built, uploaded or published; the live privacy-policy URL is still required.")
    except (ValueError, OSError, subprocess.SubprocessError) as error:
        print(f"Setup not completed: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
