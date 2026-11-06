# FindIt - Search Hidden Objects — local handoff

**6 November 2026 · version 1.0.0+1 · current local candidates, not a store release**

The independent app is implemented in `E:\Google Apps\FindIt - Search Hidden Objects`. Hidden-object searching is the only offered puzzle mode. It includes 60 offline levels, three enhanced colorful illustrated scenes, pan/zoom controls, a pinned checklist, durable two-stage hints, relaxed/timed searching, earned coins, sequential unlocking, and a three-scene Daily Challenge.

## Current Android outputs

- **QA APK:** `revisions/policy-branding/qa/FindIt-Hidden-Objects-1.0.0-QA.apk`, package `abiral.mobile.findithiddenobjects.qa`, launcher **FindIt Hidden QA**, version `1.0.0-qa` / code `1`. Its development signature and strict current-source inspection passed. It has not been installed on a phone.
- **Unsigned production APK:** `revisions/policy-branding/production-unsigned/FindIt-Hidden-Objects-1.0.0-UNSIGNED.apk`, package `abiral.mobile.findithiddenobjects`, launcher **FindIt Hidden**, version `1.0.0` / code `1`. The explicit APK-only unsigned build and strict inspection passed; no signing fallback is used.
- Both include the supplied magnifying-glass/star/leaf branding, complete shared offline policy, and latest responsive-layout changes. Each has a separate `inspection.json`, `r8/` directory and `SHA256SUMS.txt` beside it. Current build/inspection logs are `verification/build-qa-policy-branding.txt`, `verification/build-production-unsigned-policy-branding.txt`, `verification/android-qa-policy-branding.json`, and `verification/android-production-unsigned-policy-branding.json`.
- The older APKs directly under `qa/` and `production-unsigned/`, with their own reports/R8 evidence, remain unchanged as **historical candidates from before the latest branding, policy and layout changes**. They are not pending builds and were not compared against current source assets.

Each candidate must retain its own R8 evidence and inspection report. Neither a development-signed QA APK nor an unsigned production candidate is suitable for Play publication.

**No final signed production AAB has been built.** The actual hosted HTTPS policy URL, fresh private entry of the existing key's password, secure-backup confirmation and publisher review are still required.

## Current passed validation

- **513 Flutter tests**, including hidden-only routes/catalog boundaries, unsupported-save safety, transactional hint/save failures and races, real-pointer gameplay, Daily Challenge rewards, the shared offline privacy policy, and seven responsive-layout profiles (including `320×568` with 2× text): `verification/flutter-tests-policy-branding.txt`.
- **Flutter analysis:** no issues found: `verification/analyze-policy-branding.txt`. Formatting checked 72 Dart files with no changes: `verification/format-policy-branding.txt`.
- **80 Python tooling tests:** strict APK/AAB, real JDK signature, first-push ignore, privacy parity, preservation, and private-input/workflow regressions passed: `verification/python-tests-policy-branding.txt`. Synthetic signature fixtures are not runnable production releases and never use the production key.
- **Shared policy:** 11 complete sections, no URLs/hyperlinks, and plain-text developer email. Current HTML/source parity is in `verification/privacy-policy-parity.json`; nine current phone, large-text and wide actual-widget captures are in `verification/privacy-policy/captures.json`.
- **Prepared branding:** source provenance, launcher/adaptive/themed safe-zone checks and 52 generated assets are recorded under `verification/branding/`; the opaque `512×512` Play icon is under `release/play-store/graphics/`.
- **Both current APK inspections:** exact package/label, hidden-only 60-level catalog, source-asset/policy bytes, all 15 compiled launcher PNG variants and adaptive/themed layers, compiled backup/transfer exclusions, expected QA signature or genuinely unsigned production state, restricted permissions, absent advertising/test-plugin references, and native ELF/ZIP alignment passed. Each APK contains 15 native libraries across `armeabi-v7a`, `arm64-v8a`, and `x86_64`; applicable 64-bit 16 KB packaging checks passed.
- **Existing-key preflight:** `python tool/build_signed_aab.py --check-only` passed for the existing dedicated key path, public certificate pin and policy parity. It read no password, did not open the keystore, and did not build an AAB.

## Historical gameplay evidence

The 18 actual-widget gameplay captures in `verification/screenshots/captures.json` and the nine complete isolated release-web captures in `verification/web-preview/runs/2026-11-06T05-37-57-988Z/report.json` predate the latest branding/policy/layout revision. That web run verified paid/free hints, manual finds, completion rewards and unlocking across reloads, with no recorded app exceptions, console warnings/errors, failed page requests, or external requests. All 27 historical capture hashes/dimensions were checked in `verification/capture-checksums-final.json`. These remain historical evidence, not a claim of a latest-revision web or Android-device smoke test.

The loopback-only preview may be started at `http://127.0.0.1:8771/` with `tool/serve_preview.py --port 8771`; current availability was not rechecked. The isolated browser command is `node tool/verify_web_preview.mjs http://127.0.0.1:8771/`. It uses a fresh test-only Chrome profile, not ordinary browser saves. See the project-root `README.md` for current build, hosting and inspector commands.

## Original project protection

The original project at `E:\Google Apps\Find It` is outside the new app's build, signing, storage, and output workflow. Its independent Ads Preview was not copied or used.

The current preservation report, `verification/source-preservation-policy-branding.json`, matches **227/227** recorded original source hashes and **both original final APK checksums**. This assurance covers those recorded files/APKs, not an unrecorded whole-folder baseline. `tool/verify_source_reuse.py` is read-only with respect to the original project.

## Limits and release gates

- No phone installation/update/reset, ordinary-browser storage reset, advertising, upload, or publication was performed. All work is local; the assistant has not initialized, staged, committed or pushed a repository.
- Static APK inspection and headless/widget checks are **not** real Android runtime, audio, accessibility, physical-device, or 16 KB runtime QA.
- The toolchain emitted a Cupertino font-tree-shaking diagnostic. No Cupertino icon usage was found in the app; reviewed web/widget screens rendered their Material icons. Android runtime/icon checks remain part of device QA.
- The user confirmed a **brand-new Play listing** and authorized the existing dedicated upload key, alias `findit-hidden-upload`. Never recreate it or reuse the original app's key. The public certificate pin is documented in the root `README.md` and `verification/signing/`; the private key stays in ignored `.local-signing/`.
- Publish `privacy-policy.html` through GitHub Pages and supply its actual rendered HTTPS URL. Keep the policy pages themselves link-free. Then run `python tool/build_signed_aab.py --dialog` for fresh masked password entry, backup/publisher confirmations, live HTML validation, signed AAB build and strict inspection. It never saves a password or raw credential-bearing subprocess output; it never installs, uploads or publishes. The requested signed build is authorized, but its required inputs are not yet available. Upload/publication still require separate authorization.
- Before publication, complete real-device/audio/accessibility/backup/storage/16 KB runtime QA and approve the package ownership, asset rights, developer/contact identity, privacy commitments, legal obligations and Play Console declarations. A signed/inspected AAB alone would not establish complete store readiness.
- For the first GitHub push, `.gitignore` excludes APK/AAB/APKS files at any depth, private keys/backups/signing properties, environment files and final configuration. The known public upload certificate and `privacy-policy.html` remain publishable. Review the staged file list before committing; never publish private signing material.
- Flutter tests, captures, analysis, and builds were run sequentially to avoid native-file and generated-registration conflicts. The unused `integration_test` development plugin was removed; no generated Android registration code was maintained by hand.
- Initial failing build/smoke logs and the initial Home-only browser check remain historical. They are not evidence that the latest complete gameplay check or successful QA candidate failed.

Validated toolchain: Flutter **3.47.9**, Dart **3.13.7**, Android build-tools **36.0.0**, NDK **28.2.13676358**, and Chrome **157.0.8103.38**. Full Flutter version metadata is in `verification/flutter-version.json`.
