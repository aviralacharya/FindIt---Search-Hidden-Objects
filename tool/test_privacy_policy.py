"""The public HTML and in-app asset must describe the exact same policy."""

import copy
import hashlib
from html.parser import HTMLParser
import json
import unittest
from xml.etree import ElementTree

from generate_privacy_policy import HTML, POLICY, ROOT, URL_PATTERN, check_html, render_html, validate_policy


class PolicyHtmlParser(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.tags = []
        self.text = []
        self.links = []
        self.active = []
        self.blocks = []

    def handle_starttag(self, tag, attrs):
        self.tags.append((tag, dict(attrs)))
        if tag == "a":
            self.links.append(dict(attrs).get("href"))
        if tag in ("h1", "h2", "p", "li", "footer"):
            self.active.append((tag, []))

    def handle_data(self, data):
        self.text.append(data)
        for _, contents in self.active:
            contents.append(data)

    def handle_endtag(self, tag):
        if self.active and self.active[-1][0] == tag:
            kind, contents = self.active.pop()
            self.blocks.append((kind, "".join(contents)))


class PrivacyPolicyParityTests(unittest.TestCase):
    def setUp(self):
        self.data = POLICY.read_bytes()
        self.policy = json.loads(self.data)

    def test_checked_in_html_is_exactly_the_single_source_render(self):
        report = check_html()
        self.assertEqual(report["sourceSha256"], hashlib.sha256(self.data).hexdigest())
        self.assertEqual(report["sections"], 11)
        self.assertEqual(HTML.read_text(encoding="utf-8"), render_html(self.policy, report["sourceSha256"]))

    def test_every_legal_heading_paragraph_and_bullet_is_identical(self):
        parser = PolicyHtmlParser()
        parser.feed(HTML.read_text(encoding="utf-8"))
        self.assertIn(("h1", "Privacy Policy"), parser.blocks)
        for section in self.policy["sections"]:
            self.assertIn(("h2", section["title"]), parser.blocks)
            for paragraph in section["paragraphs"]:
                self.assertIn(("p", paragraph), parser.blocks)
            for bullet in section["bullets"]:
                self.assertIn(("li", bullet), parser.blocks)
            self.assertEqual(section["links"], [])
        app_model = (ROOT / "lib/core/config/privacy_policy.dart").read_text(encoding="utf-8")
        app_screen = (ROOT / "lib/features/settings/privacy_screen.dart").read_text(encoding="utf-8")
        self.assertIn("assets/legal/privacy-policy.json", app_model)
        self.assertIn("PrivacyPolicyDocument.load(bundle:", app_screen)
        self.assertIn("Text(paragraph)", app_screen)
        self.assertIn("Text(bullet)", app_screen)

    def test_policy_has_no_urls_links_scripts_external_assets_or_password_fields(self):
        parser = PolicyHtmlParser()
        parser.feed(HTML.read_text(encoding="utf-8"))
        self.assertFalse(any(tag in ("a", "script", "iframe", "img", "form", "input", "link") for tag, _ in parser.tags))
        self.assertFalse(any("src" in attrs for _, attrs in parser.tags))
        self.assertEqual(parser.links, [])
        self.assertIsNone(URL_PATTERN.search(HTML.read_text(encoding="utf-8")))
        self.assertIsNone(URL_PATTERN.search(self.data.decode("utf-8")))
        self.assertIn(("p", "Email: abiralacharya80@gmail.com."), parser.blocks)
        self.assertIn(("html", {"lang": "en"}), parser.tags)
        self.assertIn(("meta", {"name": "viewport", "content": "width=device-width, initial-scale=1"}), parser.tags)

    def test_missing_disclosures_duplicate_sections_or_wrong_identity_fail(self):
        for mutation in ("identity", "schema", "duplicate", "missing-security", "bad-date"):
            value = copy.deepcopy(self.policy)
            if mutation == "identity":
                value["appName"] = "Original FindIt"
            elif mutation == "schema":
                value["schemaVersion"] = 2
            elif mutation == "duplicate":
                value["sections"].append(value["sections"][0])
            elif mutation == "missing-security":
                value["sections"] = [section for section in value["sections"] if section["id"] != "security"]
            else:
                value["updated"] = "2026-02-30"
            with self.subTest(mutation=mutation), self.assertRaises(ValueError):
                validate_policy(value)

    def test_all_links_and_urls_are_rejected_and_body_markup_is_escaped(self):
        for url in ("https://policies.google.com/privacy", "mailto:abiralacharya80@gmail.com", "javascript:alert(1)", "http://example.com", "https://user:password@example.com", "mailto:someone-else@example.com"):
            value = copy.deepcopy(self.policy)
            value["sections"][0]["links"] = [{"label": "test", "url": url}]
            with self.subTest(url=url), self.assertRaises(ValueError):
                validate_policy(value)
        for key in ("intro", "footer"):
            value = copy.deepcopy(self.policy)
            value[key] += " https://example.com"
            with self.subTest(key=key), self.assertRaises(ValueError):
                validate_policy(value)
        value = copy.deepcopy(self.policy)
        value["sections"][0]["paragraphs"].append("See www.example.com")
        with self.assertRaises(ValueError):
            validate_policy(value)
        value = copy.deepcopy(self.policy)
        value["sections"][0]["paragraphs"] = ['<script>alert("test")</script>']
        rendered = render_html(value, "0" * 64)
        self.assertNotIn('<script>alert("test")</script>', rendered)
        self.assertIn("&lt;script&gt;", rendered)

    def test_policy_names_the_actual_android_permissions_and_explains_them(self):
        sections = {section["id"]: section for section in self.policy["sections"]}
        permissions = sections["permissions_backups"]
        text = "\n".join(permissions["paragraphs"] + permissions["bullets"])
        manifest = ElementTree.parse(ROOT / "android/app/src/main/AndroidManifest.xml")
        attribute = "{http://schemas.android.com/apk/res/android}name"
        requested = {entry.attrib[attribute] for entry in manifest.findall("uses-permission")}
        self.assertEqual(requested, {"android.permission.INTERNET", "android.permission.VIBRATE"})
        for permission in requested:
            self.assertIn(permission, text)
        self.assertIn(self.policy["androidPackage"] + ".DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION", text)
        self.assertIn("normal permissions", text)
        self.assertIn("signature-protected", text)
        self.assertIn("does not record audio", text)

    def test_policy_discloses_local_metadata_and_user_triggered_clipboard_use(self):
        sections = {section["id"]: section for section in self.policy["sections"]}
        local = "\n".join(sections["local_data"]["paragraphs"] + sections["local_data"]["bullets"])
        sharing = "\n".join(sections["collection_sharing"]["paragraphs"])
        self.assertIn("completion dates", local)
        self.assertIn("Local puzzle/session identifiers", local)
        self.assertIn("unused compatibility fields", local)
        self.assertIn("Copy developer email", sharing)
        self.assertIn("Android clipboard", sharing)
        self.assertIn("does not automatically read clipboard contents", sharing)
        self.assertIn("Clipboard.setData", (ROOT / "lib/features/settings/developer_details.dart").read_text(encoding="utf-8"))

    def test_policy_distinguishes_offline_gameplay_from_github_pages_requests(self):
        section = next(section for section in self.policy["sections"] if section["id"] == "network_services")
        text = "\n".join(section["paragraphs"])
        for disclosure in ("using its local date", "download form is unavailable", "hosted on GitHub Pages", "IP address", "request timestamps", "does not contact GitHub"):
            self.assertIn(disclosure, text)

    def test_policy_reset_disclosure_matches_retained_preferences_and_packs(self):
        sections = {section["id"]: section for section in self.policy["sections"]}
        text = "\n".join(sections["retention"]["paragraphs"] + sections["choices_deletion"]["bullets"])
        for disclosure in ("started-playing flag", "compatibility preferences", "installed packs", "completion receipts", "logical deletion", "does not delete emails"):
            self.assertIn(disclosure, text)
        repository = (ROOT / "lib/core/storage/progress_repository.dart").read_text(encoding="utf-8")
        self.assertIn("t.key.like('pack:%').not()", repository)
        services = (ROOT / "lib/app/app_services.dart").read_text(encoding="utf-8")
        self.assertIn("await progress.resetProgress();", services)
        self.assertIn("$storageNamespace-has-played", services)


if __name__ == "__main__":
    unittest.main()
