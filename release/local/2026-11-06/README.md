# FindIt - Search Hidden Objects — Android validation record

**Version `1.0.0+1` · 6 November 2026 · release validation, not a published release**

FindIt provides 60 offline hidden-object levels in a colorful illustrated style, with pan/zoom controls, a pinned checklist, saved two-stage hints, relaxed or timed searching, earned coins, progression, and a three-scene Daily Challenge.

This record describes the available Android candidates and their automated validation. Artifact paths below are relative to this directory; verification references are relative to the project root.

## Android artifacts

### QA APK

- File: `revisions/policy-branding/qa/FindIt-Hidden-Objects-1.0.0-QA.apk`.
- Package: `abiral.mobile.findithiddenobjects.qa`.
- Launcher: **FindIt Hidden QA**.
- Version: `1.0.0-qa`; version code: `1`.
- Development-signed; strict artifact inspection passed. Not suitable for Google Play publication.

### Unsigned production APK

- File: `revisions/policy-branding/production-unsigned/FindIt-Hidden-Objects-1.0.0-UNSIGNED.apk`.
- Package: `abiral.mobile.findithiddenobjects`.
- Launcher: **FindIt Hidden**.
- Version: `1.0.0`; version code: `1`.
- Genuinely unsigned; strict artifact inspection passed. It cannot be installed normally or published as a release.

Both include the magnifying-glass/star/leaf branding, shared offline policy, and responsive layouts. Each artifact is retained with its own `inspection.json`, six R8 evidence files, and `SHA256SUMS.txt`. See the [candidate documentation](revisions/policy-branding/README.md) and retain each artifact's matching evidence.

Inspection reports: `verification/android-qa-policy-branding.json` and `verification/android-production-unsigned-policy-branding.json`.

**No final signed production AAB is available.** Final generation requires the actual hosted HTTPS policy URL, fresh private entry of the existing upload key's password, secure-backup confirmation, and publisher review.

## Automated validation

- **513 Flutter tests passed:** hidden-only routes/catalog boundaries, saved-state safety, transactional hint/save failures and races, pointer-driven gameplay, Daily Challenge rewards, privacy presentation, and seven responsive-layout profiles, including `320×568` with 2× text. Evidence: `verification/flutter-tests-policy-branding.txt`.
- **Flutter analysis passed with no issues.** Formatting checked 72 Dart files with no changes. Evidence: `verification/analyze-policy-branding.txt` and `verification/format-policy-branding.txt`.
- **80 Python tooling tests passed:** artifact and release-gate validation, real JDK signature verification, repository exclusions, privacy parity, and private-build workflow checks. Evidence: `verification/python-tests-policy-branding.txt`. Signature fixtures use disposable test keys, not the production key.
- **Privacy parity passed:** 11 complete sections, no URLs/hyperlinks, and plain-text developer email. Evidence: `verification/privacy-policy-parity.json`; nine phone, large-text, and wide actual-widget captures are indexed in `verification/privacy-policy/captures.json`.
- **Branding preparation passed:** 52 generated assets, source provenance, and adaptive/themed safe-zone checks are recorded under `verification/branding/`. The opaque `512×512` Play icon is `release/play-store/graphics/icon-512.png`.
- **Both APK inspections passed:** package/label, 60-level hidden-only catalog, source-asset and policy bytes, all 15 compiled launcher PNG variants and adaptive/themed layers, backup/transfer XML, expected signature state, restricted permissions, absent advertising/test-plugin references, and native ELF/ZIP alignment. Each APK contains 15 native libraries across `armeabi-v7a`, `arm64-v8a`, and `x86_64`; applicable 64-bit 16 KB packaging checks passed.
- **Existing-key preflight passed:** key presence, public certificate pin, and generated-policy parity. The check read no password, did not open the keystore, and did not build an AAB.

The Flutter validation toolchain was Flutter **3.47.9**, Dart **3.13.7**, Android build tools **36.0.0**, and NDK **28.2.13676358**. Flutter version metadata is recorded in `verification/flutter-version.json`.

## Publication prerequisites

1. Approve package ownership, developer/contact details, asset distribution rights, policy commitments, and applicable legal obligations.
2. Publish the generated `privacy-policy.html` using the [GitHub Pages hosting guide](../../PRIVACY-POLICY-HOSTING.md). Verify the actual rendered HTTPS URL; keep the policy content link-free.
3. Confirm the existing dedicated upload key's secure backup. Never recreate or replace it, save its password in configuration, or publish private signing material.
4. Run `python tool/build_signed_aab.py --dialog` from the project root for masked private entry, live-policy verification, signed AAB generation, and strict inspection. The helper retains matching R8 evidence and checksums and does not install, upload, or publish.
5. Complete real Android-device QA for gameplay/resume, audio, haptics, accessibility, launcher/splash, storage/backup behavior, and 16 KB runtime compatibility. These checks remain outstanding; static inspection and widget tests do not replace them.
6. Complete Play Console listing, app signing setup, content rating, target-audience and Data safety declarations, and applicable testing/review requirements before upload and publication.

Keep `.gitignore` in place and review staged files before committing. Android binaries, private keys/backups, signing properties, environment files, and final configuration are excluded. The known public upload certificate and generated policy page are publishable; the private keystore is not.

See the [project README](../../../README.md) for setup, validation, build profiles, privacy maintenance, and repository-security instructions.
