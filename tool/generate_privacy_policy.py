"""Render/check the public HTML from the same JSON the offline app reads.

Edit assets/legal/privacy-policy.json, never maintain a second policy by hand.
Run --write to regenerate, and --check before builds or GitHub Pages deployment.
"""

import argparse
from datetime import date
import hashlib
from html import escape
import json
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parent.parent
POLICY = ROOT / "assets/legal/privacy-policy.json"
HTML = ROOT / "privacy-policy.html"
MARKER = "<!-- Generated from assets/legal/privacy-policy.json by tool/generate_privacy_policy.py. -->"
REQUIRED_SECTIONS = {
    "scope", "local_data", "collection_sharing", "network_services",
    "permissions_backups", "security", "retention", "choices_deletion",
    "children", "changes", "contact",
}
URL_PATTERN = re.compile(r"\b(?:[a-z][a-z0-9+.-]*://|mailto:|www\.)", re.IGNORECASE)
STYLE = """    :root { color-scheme: light; --ink: #183c34; --muted: #4f625b; --forest: #176750; --cream: #fbf7ee; }
    * { box-sizing: border-box; }
    body { margin: 0; background: var(--cream); color: var(--ink); font: 17px/1.75 system-ui, -apple-system, "Segoe UI", sans-serif; }
    main { max-width: 860px; margin: 0 auto; padding: 54px 24px 64px; }
    .eyebrow { margin: 0 0 8px; color: var(--forest); font-size: 13px; font-weight: 750; letter-spacing: .12em; text-transform: uppercase; }
    h1 { margin: 0; font-size: clamp(34px, 6vw, 52px); line-height: 1.15; letter-spacing: -.035em; }
    .app-name { margin: 16px 0 4px; font-size: 22px; font-weight: 650; }
    .date, footer { color: var(--muted); font-size: 14px; }
    .summary { margin: 28px 0 34px; padding: 24px; border: 1px solid #cedacf; border-radius: 20px; background: #eff5e9; }
    .summary p { margin: 0; }
    .badges { display: flex; flex-wrap: wrap; gap: 8px; margin-top: 16px; }
    .badge { padding: 4px 12px; border-radius: 100px; background: #fffdf7; color: var(--forest); font-size: 13px; font-weight: 650; }
    section { padding: 12px 0; }
    h2 { margin: 0 0 8px; font-size: 23px; line-height: 1.4; letter-spacing: -.015em; }
    p { margin: 0 0 16px; }
    ul { margin: 0 0 16px; padding-left: 24px; }
    li { margin: 5px 0; }
    .contact { padding: 24px; margin-top: 20px; background: #fffdf7; border: 1px solid #e2e2d6; border-radius: 20px; }
    footer { border-top: 1px solid #dddfd2; margin-top: 36px; padding-top: 20px; overflow-wrap: anywhere; }
    @media (max-width: 480px) { main { padding: 36px 20px 40px; } .summary, .contact { padding: 20px; } }
    @media print { body { background: #fff; font-size: 11pt; } main { max-width: none; padding: 0; } section { break-inside: avoid; } }"""


def validate_policy(value):
    if not isinstance(value, dict) or value.get("schemaVersion") != 1:
        raise ValueError("Unsupported privacy policy document/schema.")
    config = dict(re.findall(r"static const (\w+) = '([^']*)';", (ROOT / "lib/core/config/app_config.dart").read_text(encoding="utf-8")))
    identity = {"appName": "name", "launcherName": "launcherName", "androidPackage": "androidPackage",
                "developerName": "developerName", "developerEmail": "developerEmail"}
    if any(value.get(key) != config.get(constant) for key, constant in identity.items()):
        raise ValueError("Privacy policy identity differs from AppConfig.")
    if value.get("policyTitle") != "Privacy Policy":
        raise ValueError("The document must be clearly labeled Privacy Policy.")
    for key in ("policyVersion", "updated", "eyebrow", "intro", "footer"):
        if not isinstance(value.get(key), str) or not value[key].strip():
            raise ValueError(f"Missing privacy policy {key}.")
    if not re.fullmatch(r"\d{4}-\d{2}-\d{2}", value["updated"]):
        raise ValueError("Invalid privacy policy date.")
    date.fromisoformat(value["updated"])

    def texts(items):
        if not isinstance(items, list) or any(not isinstance(text, str) or not text.strip() or URL_PATTERN.search(text) for text in items):
            raise ValueError("Invalid privacy policy text list.")

    for key, text in value.items():
        if isinstance(text, str) and URL_PATTERN.search(text):
            raise ValueError(f"Privacy policy {key} must not contain URLs.")

    texts(value.get("summaryBadges"))
    sections = value.get("sections")
    if not isinstance(sections, list) or not sections:
        raise ValueError("Missing privacy policy sections.")
    identifiers = set()
    for section in sections:
        if not isinstance(section, dict) or not re.fullmatch(r"[a-z][a-z_]*", section.get("id", "")):
            raise ValueError("Invalid privacy policy section.")
        if section["id"] in identifiers:
            raise ValueError("Duplicate privacy policy section.")
        identifiers.add(section["id"])
        if not isinstance(section.get("title"), str) or not section["title"].strip():
            raise ValueError("Missing privacy policy section title.")
        if URL_PATTERN.search(section["title"]):
            raise ValueError("Privacy policy headings must not contain URLs.")
        texts(section.get("paragraphs"))
        texts(section.get("bullets"))
        if not section["paragraphs"] and not section["bullets"]:
            raise ValueError("Empty privacy policy section.")
        if section.get("links") != []:
            raise ValueError("The privacy policy must not contain links.")
    if not REQUIRED_SECTIONS.issubset(identifiers):
        raise ValueError("Privacy policy is missing required disclosures.")
    return value


def render_html(value, source_sha256):
    validate_policy(value)
    revision = date.fromisoformat(value["updated"])
    updated = f"{revision.day} {revision:%B %Y}"
    sections = []
    for section in value["sections"]:
        class_attribute = ' class="contact"' if section["id"] == "contact" else ""
        lines = [f'    <section{class_attribute} aria-labelledby="{escape(section["id"], quote=True)}">',
                 f'      <h2 id="{escape(section["id"], quote=True)}">{escape(section["title"])}</h2>']
        lines.extend(f"      <p>{escape(paragraph)}</p>" for paragraph in section["paragraphs"])
        if section["bullets"]:
            lines.append("      <ul>")
            lines.extend(f"        <li>{escape(bullet)}</li>" for bullet in section["bullets"])
            lines.append("      </ul>")
        lines.append("    </section>")
        sections.append("\n".join(lines))
    badges = "".join(f'<span class="badge">{escape(text)}</span>' for text in value["summaryBadges"])
    content = "\n\n".join(sections)
    return f'''<!doctype html>
{MARKER}
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="description" content="Privacy policy for {escape(value['appName'], quote=True)}: offline puzzles, local saves, no accounts, and no advertising.">
  <meta name="color-scheme" content="light">
  <meta name="findit-privacy-policy-source-sha256" content="{source_sha256}">
  <title>{escape(value['policyTitle'])} · {escape(value['appName'])}</title>
  <style>
{STYLE}
  </style>
</head>
<body>
  <main id="policy">
    <header>
      <p class="eyebrow">{escape(value['eyebrow'])}</p>
      <h1>{escape(value['policyTitle'])}</h1>
      <p class="app-name">{escape(value['appName'])}</p>
      <p class="date">Last updated: <time datetime="{value['updated']}">{updated}</time> · Policy version {escape(value['policyVersion'])}</p>
    </header>

    <div class="summary">
      <p>{escape(value['intro'])}</p>
      <div class="badges" aria-label="Privacy summary">{badges}</div>
    </div>

{content}

    <footer>{escape(value['footer'])}</footer>
  </main>
</body>
</html>
'''


def expected_html():
    data = POLICY.read_bytes()
    return render_html(json.loads(data), hashlib.sha256(data).hexdigest())


def check_html():
    expected = expected_html()
    if not HTML.is_file() or HTML.read_text(encoding="utf-8") != expected:
        raise ValueError("HTML policy is stale or missing. Run python tool/generate_privacy_policy.py --write.")
    return {"source": POLICY.relative_to(ROOT).as_posix(),
            "sourceSha256": hashlib.sha256(POLICY.read_bytes()).hexdigest(),
            "html": HTML.relative_to(ROOT).as_posix(),
            "htmlSha256": hashlib.sha256(HTML.read_bytes()).hexdigest(),
            "sections": len(json.loads(POLICY.read_bytes())["sections"]), "status": "passed"}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--write", action="store_true")
    mode.add_argument("--check", action="store_true")
    parser.add_argument("--output", type=Path, help="Optional public parity report")
    args = parser.parse_args()
    try:
        if args.write:
            if HTML.exists() and MARKER not in HTML.read_text(encoding="utf-8"):
                raise ValueError("The existing HTML is not generator-managed; it was not overwritten.")
            HTML.write_text(expected_html(), encoding="utf-8", newline="\n")
        report = check_html()
        if args.output:
            args.output.parent.mkdir(parents=True, exist_ok=True)
            args.output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
        print(f"Privacy policy parity: passed; {report['sections']} shared sections.")
    except (ValueError, OSError, KeyError, TypeError) as error:
        print(f"Privacy policy check failed: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
