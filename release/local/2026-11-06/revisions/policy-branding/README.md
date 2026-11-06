# FindIt - Search Hidden Objects — Android candidates

**Version `1.0.0+1` · 6 November 2026 · not for Google Play publication**

Paths in this document are relative to this directory unless stated otherwise.

## Artifacts

- **QA:** `qa/FindIt-Hidden-Objects-1.0.0-QA.apk`, package `abiral.mobile.findithiddenobjects.qa`, launcher **FindIt Hidden QA**, version `1.0.0-qa` / code `1`. Uses a development certificate; not a production release.
- **Unsigned production:** `production-unsigned/FindIt-Hidden-Objects-1.0.0-UNSIGNED.apk`, package `abiral.mobile.findithiddenobjects`, launcher **FindIt Hidden**, version `1.0.0` / code `1`. Genuinely unsigned; cannot be installed normally or uploaded as a release.

Each artifact directory contains its matching `inspection.json`, six R8 evidence files, and `SHA256SUMS.txt`. The [directory checksum manifest](SHA256SUMS.txt) covers both artifacts, their retained evidence, and this README. Keep evidence paired with its artifact. Android binaries are excluded from Git.

## Verified packaging

Both APKs contain 60 offline hidden-object levels, the green magnifying-glass/star/leaf branding, the complete 11-section offline privacy policy, and responsive gameplay layouts.

Strict static inspections passed for:

- Package identity, launcher label, and expected signature state.
- Hidden-only catalog and byte-for-byte bundled asset/policy parity.
- All 15 launcher PNG variants and adaptive/themed icon layers.
- Compiled backup/transfer rules and restricted permissions.
- Absence of advertising and test-plugin references.
- Applicable 64-bit 16 KB native ELF/ZIP packaging alignment.

These results establish packaging validation, not real-device, accessibility, audio, or 16 KB runtime QA. See the [Android validation record](../../README.md) for automated-test evidence and outstanding checks.

## Final release

**No final signed production AAB is available.** Publish the generated project-root `privacy-policy.html`, verify its actual public HTTPS URL, and confirm secure key backup and publisher approval. Then run `python tool/build_signed_aab.py --dialog` from the project root for masked entry of the existing upload key's password, live-policy verification, signed generation, and strict inspection.

Never recreate or replace the dedicated key, save signing passwords, or publish private signing material. Device QA and Play Console/legal review remain required; the build workflow does not install, upload, or publish the app.
