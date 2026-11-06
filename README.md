# FindIt - Search Hidden Objects

An independent Flutter hidden-object game with colorful illustrated scenes, local progress, and no advertising or purchases. This project lives at `E:\Google Apps\FindIt - Search Hidden Objects`; it is not an update to the original app at `E:\Google Apps\Find It`.

## What is included

- **60 offline hidden-object levels:** three enhanced Home, Garden, and Café compositions followed by 57 classic FindIt hidden scenes.
- **Scene-first searching:** pan, pinch or use zoom buttons, reset the view, and keep the object checklist pinned outside the scene.
- **Two-stage hints:** spend 20 earned coins to highlight a broad search area; revealing that same object's exact position is free and does not count another hint. Both stages are saved. Neither automatically finds an object—you still tap it.
- **Relaxed play by default:** Settings can enable timed searching for new sessions. Leaving or backgrounding pauses and saves the current search.
- Sequential level unlocking, scores, stars, a local coin wallet, and a three-scene Daily Challenge with an idempotent completion bonus.
- Reused audio, fonts, art utilities, transactional storage, pinned dependencies, and Android scaffolding. Generic puzzle models and regression tests remain internal; other puzzle modes are not offered by this app.
- The supplied green magnifying-glass/star/leaf icon is prepared for the launcher, adaptive/themed icons, splash, web, and Play listing. Source provenance and safe-zone evidence are under `verification/branding/`.
- One complete, offline privacy policy: the app reads `assets/legal/privacy-policy.json`, and `privacy-policy.html` is generated from that same source. Neither policy page contains URLs or hyperlinks; the contact email stays plain text.

## Separation from the original app

- Production Android ID: `abiral.mobile.findithiddenobjects`.
- QA Android ID: `abiral.mobile.findithiddenobjects.qa`; development ID: `abiral.mobile.findithiddenobjects.dev`.
- Storage namespace: `findit_hidden_objects`. Android uses its own app sandbox and `findit_hidden_objects.sqlite`; web uses `findit_hidden_objects_v1` plus independently prefixed settings keys.
- The Dart package stays named `findit` only to preserve reusable imports; it does not determine the installed Android identity.
- Signing variables use **`FINDIT_HIDDEN_`**, not the original app's variables. No private signing credentials, original releases, Git history, or Ads Preview project were copied.
- Local build outputs and verification reports stay in this project. No installation, update, device reset, ordinary-browser storage reset, live ads, upload, or publication is part of this handoff.

`verification/source-reuse.json` records the 227 reused files, their original hashes, and copying exclusions. `tool/verify_source_reuse.py` rechecks those original files and the original final APKs against their existing checksum list, without writing to the original folder. Its assurance is limited to those recorded files and APKs—not an unrecorded whole-folder baseline.

## Toolchain and local development

Requirements: Flutter 3.47+ / Dart 3.13+, JDK 17, Android SDK 36, NDK `28.2.13676358`, and Python 3.11+ for the inspectors. Dependencies are pinned in `pubspec.lock`.

The unused `integration_test` development plugin was removed from this independent project: its native registration broke release compilation on this toolchain. The actual widget/domain/storage suite uses `flutter_test`; no generated Android registration file is maintained by hand.

The local validation toolchain is Flutter **3.47.9** with Dart **3.13.7**; its full version metadata is recorded in `verification/flutter-version.json`.

Run commands from **this project's root**, never the original folder:

```powershell
flutter pub get
flutter analyze --no-pub
flutter test --no-pub --reporter expanded
python -m unittest discover -s tool -p "test_*.py"
python tool/verify_source_reuse.py
```

On this workstation, the working Flutter executable is `C:\Users\Lenovo\AppData\Local\Temp\opencode\flutter-sdk\bin\flutter.bat`. PowerShell can invoke it with `& 'full path'`. The checked-in examples do not contain publisher secrets; `android/local.properties` is local SDK configuration and must not be committed.

Prepend this SDK's `bin` and `bin\cache\dart-sdk\bin` directories to the process `PATH` before Flutter commands on this workstation; otherwise the inherited `E:\Flutter` path can break native-asset subprocesses. Do not change the original app's SDK configuration.

Run Flutter tests, captures, analysis, and builds **one at a time** on this workstation; overlapping commands can lock native assets or conflict while regenerating plugin registration.

If a `dart run` utility encounters the workstation's inherited `E:\Flutter` path/native-asset error, invoke the SDK's Dart executable directly after `flutter pub get`:

```powershell
& 'C:\Users\Lenovo\AppData\Local\Temp\opencode\flutter-sdk\bin\cache\dart-sdk\bin\dart.exe' tool/build_catalog.dart
& 'C:\Users\Lenovo\AppData\Local\Temp\opencode\flutter-sdk\bin\cache\dart-sdk\bin\dart.exe' tool/pack_tool.dart validate config/packs/example-v1.json
```

### Isolated screen review

```powershell
flutter test --no-pub tool/capture_hidden_app_test.dart
```

This captures real app widgets under `verification/screenshots/` using test-owned SQLite and mocked preferences, not installed or browser saves. It covers phone, wide, landscape, large text, hints, resume, and completion. It is separate from the normal `test/` suite. Artwork can be regenerated with `flutter test --no-pub tool/export_hidden_art_test.dart`; review target visibility before accepting regenerated assets.

The separate privacy-screen review is `flutter test --no-pub tool/capture_privacy_policy_test.dart`. It records nine phone, large-text, and wide captures plus source/HTML hashes under `verification/privacy-policy/`.

### Shared privacy policy

Edit only `assets/legal/privacy-policy.json`, then run:

```powershell
python tool/generate_privacy_policy.py --write
python tool/generate_privacy_policy.py --check --output verification/privacy-policy-parity.json
```

Publish the generated HTML through GitHub Pages using `release/PRIVACY-POLICY-HOSTING.md`. The **actual live HTTPS URL** belongs only in release configuration and Play Console, not in the policy's text. No URL has been invented or configured for the final build.

## Local build profiles

### QA APK (development certificate, separate package)

```powershell
flutter build apk --release --no-pub --flavor qa --dart-define-from-file=config/qa.json
```

Expected output: `build/app/outputs/flutter-apk/app-qa-release.apk`. This is a local testing build, **not** a production/store release. Its matching R8 evidence is under `build/app/outputs/mapping/qaRelease/`.

### Unsigned production APK candidate (inspection only)

Both explicit candidate gates are required; there is no debug-signing fallback:

```powershell
flutter build apk --release --no-pub --flavor prod --android-project-arg=unsignedProductionCandidate=true --dart-define-from-file=config/unsigned-production.json
```

Pass the property directly through Flutter's `--android-project-arg`; the environment-only `ORG_GRADLE_PROJECT_...` attempt did not reach the gate on this workstation. The `BUILD_STAGE=unsigned-candidate` configuration is still required, and the production flavor remains genuinely unsigned.

Expected output: `build/app/outputs/flutter-apk/app-prod-release.apk`, with matching R8 evidence in `build/app/outputs/mapping/prodRelease/`. An unsigned APK cannot be installed normally and must not be uploaded as a store release. Unsigned AAB builds are deliberately blocked.

The artifact inspector checks the exact package, current launcher label, hidden-only catalog, signature expectations, permissions, absent advertising classes/components, source assets/policy parity, prepared launcher pixels and backup rules, and 16 KB native ELF/ZIP alignment. Use each APK's own R8 mapping; do not reuse the other flavor's or the original app's mapping:

```powershell
$qaCertificateSha256 = 'b08451266f6a68fa07cc2cf4da0112d0c755b77a671a46b2c7980bc8b920b594'
python tool/verify_android_artifacts.py --profile qa-candidate --expected-certificate-sha256 $qaCertificateSha256 --r8-mapping build/app/outputs/mapping/qaRelease/mapping.txt --output verification/android-qa.json build/app/outputs/flutter-apk/app-qa-release.apk
python tool/verify_android_artifacts.py --profile production-candidate --r8-mapping build/app/outputs/mapping/prodRelease/mapping.txt --output verification/android-production-unsigned.json build/app/outputs/flutter-apk/app-prod-release.apk
```

The QA certificate above is this workstation's development certificate, independently checked with `keytool`; public certificate details are in `verification/qa-development-certificate.txt`. On another workstation, independently verify and pin its intended development certificate before inspecting an APK. Never use a development certificate for a signed production release.

Static packaging checks are **not** Android runtime, audio, accessibility, Play Console, or real 16 KB device QA.

### Web preview

```powershell
flutter build web --release --no-pub --no-web-resources-cdn --dart-define-from-file=config/qa.json
python tool/serve_preview.py --port 8771
```

Open `http://127.0.0.1:8771/` in an isolated review browser. Use a distinct origin/port from the original app's preview and never clear unrelated browser data. The server binds only to loopback and sends cross-origin isolation headers required by durable Drift web storage. Keep `sqlite3.wasm` and `drift_worker.js` beside `index.html`; do not open the app as `file://`. This local server is not public hosting. Audio may require the first user interaction in a browser.

With the preview server running, Node 22+ and Chrome can run the isolated gameplay smoke test without external packages:

```powershell
node tool/verify_web_preview.mjs http://127.0.0.1:8771/
```

It creates a fresh test-only Chrome profile, checks paid/free hints and manual finds across full Home-page reloads, verifies completion rewards and unlocking, and captures wide/phone screens. It closes only its own Chrome instance and does not clear any storage. Set `FINDIT_HIDDEN_CHROME` to an alternate Chrome executable if needed. Results stay in timestamped `verification/web-preview/runs/` folders; `verification/web-preview/report.json` contains the latest result. Historical failures and the initial Home-only smoke evidence are not final gameplay-validation evidence.

## Optional content authoring

`config/packs/example-v1.json` contains three unique hidden-object expansion scenes for levels 61–63, alongside its checksum and `pack-v1.schema.json`. It is a publisher example, not automatically installed content. The app has no configured remote pack index and works without one.

```powershell
dart run tool/pack_tool.dart example
dart run tool/pack_tool.dart schema
dart run tool/pack_tool.dart validate config/packs/example-v1.json
```

Publisher tools and repository installation accept hidden-object scenes only. No remote artwork, executable payloads, or daily IDs are permitted. The internal generic `PackFormat` decoder remains reusable; the app boundary enforces the hidden-only restriction.

## Store-release gates (not completed by a local candidate build)

1. Confirm ownership of the new package and that the reused artwork, fonts, audio, and developer/contact details are appropriate for this independent app. Provenance is in `assets/legal/`.
2. Host the generated, truthful public HTTPS privacy policy for **FindIt - Search Hidden Objects**. Verify that the live HTML matches the canonical policy. Fill `PRIVACY_POLICY_URL` in the ignored local `config/production.json`; keep `APP_ENV=production`, `BUILD_STAGE=final`, and `PACK_INDEX_URL` empty for this release.
3. The user confirmed this is a **new Play listing** and authorized the dedicated key already created at `.local-signing/findit-hidden-objects-upload.p12`, alias `findit-hidden-upload`. **Do not recreate it or use the original app's key.** Back it up securely, with its password stored separately in a password manager. Supply credentials only through private masked input/process-local `FINDIT_HIDDEN_STORE_FILE`, `FINDIT_HIDDEN_STORE_PASSWORD`, `FINDIT_HIDDEN_KEY_ALIAS`, and `FINDIT_HIDDEN_KEY_PASSWORD`. Never put an actual password in a command, source, log, `key.properties`, or other saved configuration. Remove the unsigned-candidate flag. Gradle pins the actual certificate to `e4d765e9c1676c9acfa95560b78177754e35fafc77dcb990dbf2e7ac2c999114`.
4. Complete real Android/device QA, accessibility and audio checks, backup/storage behavior, and 16 KB runtime QA, then prepare the separate Play listing and policy declarations.
5. The user has requested a signed AAB, but the live policy URL and fresh private password entry are still required. Once those inputs and release approvals are ready, build with `flutter build appbundle --release --no-pub --flavor prod --dart-define-from-file=config/production.json`. Inspect it before handoff using its own R8 mapping. **Uploading or publishing requires separate authorization.**

#### Private, repeatable final build

The safer local command is:

```powershell
python tool/build_signed_aab.py --check-only
python tool/build_signed_aab.py --dialog
```

`--check-only` checks local paths, the public certificate pin and shared-policy parity. It does **not** read a password or open the keystore. `--dialog` asks for the actual rendered HTTPS policy URL, the **existing** key's password through native masked input, and explicit backup/publisher-review confirmations. It verifies the live HTML against the complete generated policy, verifies the existing keystore's public certificate, creates `config/production.json` only if absent (never overwrites different existing inputs), builds the signed production AAB, and runs the strict inspector below. Successful output is retained with its own R8 files and checksums in a new timestamped `release/local/<date>/revisions/signed-<time>/` directory.

Raw output from credential-bearing subprocesses is deliberately discarded, rather than risking a password in a log. Only fixed build status and public hosting/inspection evidence are saved. Credentials are held in process/child memory, never saved in configuration or command arguments. Reusable Gradle daemons are disabled for this workflow. For approved automation, `--from-environment --policy-url $policyPageUrl --confirm-backup --confirm-publisher-review` reads process-local signing passwords; clear them from the originating terminal when finished. Never type an actual password into a command or chat.

This helper **never creates or replaces a key**. Do not rerun the earlier key-creation setup to recreate `.local-signing/findit-hidden-objects-upload.p12`. Run Flutter commands one at a time; a signed-build lock prevents concurrent invocations of this helper. Real-device QA and Play Console/legal review still remain separate prerequisites to publication, even after a successful signed build.

```powershell
python tool/verify_android_artifacts.py --profile signed-production-aab --production-config config/production.json --r8-mapping build/app/outputs/mapping/prodRelease/mapping.txt --output verification/android-signed-production.json build/app/outputs/bundle/prodRelease/app-prod-release.aab
```

This profile checks the compiled bundle manifest and final inputs, embedded/external R8 mapping equality, source assets and policy, launcher/backup resources, native alignment and Flutter symbol metadata, and a real JDK verification of **every signed payload** against the dedicated upload-certificate pin. Regression tests use disposable synthetic bundles and test-only keys, never the production key. Separate workflow regressions confirm password-safe failure handling, existing-key reuse, live-policy parity, and non-overwriting retention. Passing those tests is not a claim that a final signed production AAB has already been built or that live hosting/device/Play checks are complete.

### Safe GitHub publication

`privacy-policy.html` and its canonical source `assets/legal/privacy-policy.json` are intentionally publishable. `.gitignore` excludes AAB/APK/APKS outputs at any depth, the private `.local-signing/` directory, common private-key formats and backups, signing-properties files, environment files, and `config/production.json`.

The single allowlisted PEM, `verification/signing/production-upload-certificate.pem`, contains only the **public certificate**, never a private key or password. Release inspection requires it. All other PEM files are ignored.

Before committing, review `git status --short` and `git diff --cached --name-only`. Ignore rules do not remove files that Git already tracks. If a private key or password was previously committed or published, stop and address the exposure; merely adding an ignore rule is not enough. Never copy private signing material into the GitHub Pages repository. Validate the exclusions with `python -m unittest discover -s tool -p test_gitignore.py`.

For this project's **first push**, keep `.gitignore` in place before `git add .`; then review the staged file list. The assistant has not initialized, staged, committed, or pushed a repository. Only hosting the policy file is necessary for Pages—you do not need to make the entire Flutter source public.

## Code map

- `lib/core/content/`: hidden-only catalog and install boundary, authored scenes, reusable generators/validators.
- `lib/core/domain/`: game engine, saved-state validation, progression, and Daily Challenge rules.
- `lib/core/storage/`: isolated database/settings and transactional wallet/session writes.
- `lib/features/` and `lib/ui/widgets/`: routes, pages, illustrated scene viewport, pinned checklist, and responsive controls.
- `test/`: content, rules, platform guards, storage isolation, real-pointer gameplay, failure/race, and responsive-layout regressions.
- `tool/`: catalog/art generators, isolated screen exporter, pack authoring, preview server, and read-only/static inspectors.
- `verification/`: logs and evidence for this project. Earlier failing logs remain historical; use the final dated handoff and final logs for completed validation claims.
