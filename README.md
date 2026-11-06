# FindIt - Search Hidden Objects

<img src="assets/branding/app_icon.png" alt="FindIt magnifying-glass, star, and leaf app icon" width="96" height="96" />

*Little things. Wonderful places. Look closer.*

FindIt is a Flutter hidden-object game with colorful illustrated scenes, offline puzzles, and saved progress. Players explore detailed locations, find items, and earn rewards at their own pace. The app requires no account and includes no advertising, analytics, or in-app purchases.

Android is the distribution target. A web preview is available for development and gameplay verification.

## Features

- **60 bundled levels:** featured Home, Garden, and Café scenes, plus 57 additional hidden-object levels. All included puzzles work offline.
- **Interactive searching:** pan, pinch to zoom, use zoom controls, and reset the scene view while the object checklist stays pinned outside the artwork.
- **Two-stage hints:** spend 20 earned coins to highlight a broad area, then reveal that same object's exact position for free. Both stages are saved; the second stage adds no hint count. Players must still tap the object to find it.
- **Relaxed or timed play:** relaxed searching is the default; Settings can enable timed searching for new sessions.
- **Progression and rewards:** sequential unlocking, scores, stars, personal bests, an earned-coin wallet, and a three-scene Daily Challenge with one completion bonus per day.
- **Save and resume:** gameplay pauses and saves when a search is left or the app is backgrounded, with transactional progress and hint updates.
- **Player controls:** configurable sound, music, volume, and vibration, with responsive phone, landscape, wide-screen, and large-text layouts.
- **Offline privacy information:** the complete policy is bundled in the app and maintained from the same source as the public policy page.

## Application identity

- **Version:** `1.0.0+1` — Android version name `1.0.0`, version code `1`.
- **Production package:** `abiral.mobile.findithiddenobjects`; launcher name **FindIt Hidden**.
- **QA package:** `abiral.mobile.findithiddenobjects.qa`; launcher name **FindIt Hidden QA**.
- **Development package:** `abiral.mobile.findithiddenobjects.dev`; launcher name **FindIt Hidden Dev**.
- **Dart package:** `findit`.
- **Storage namespace:** `findit_hidden_objects`.
- **Android support:** Android 7.0 / API 24 and above; target SDK 36.

## Requirements

- Flutter **3.47+** with Dart **3.13+**, below Dart 4.0.
- JDK **17**, Android SDK platform/build tools **36**, and Android NDK **`28.2.13676358`**.
- Python **3.11+** for policy generation, artifact inspection, and release tooling. The desktop signing dialog also requires Tkinter.
- Optional: Node.js **22+** and Chrome for the isolated web smoke test.

Make the required command-line tools available on `PATH`. Dependencies are recorded in `pubspec.yaml` and locked in `pubspec.lock`. All commands below run from the project root and use project-relative paths.

## Getting started

Check the Flutter installation and resolve dependencies:

```sh
flutter doctor
flutter pub get
```

Run the Android development flavor on a selected development target:

```sh
flutter run --no-pub --flavor dev
```

Use `dev` or `qa` for testing. The `prod` Android identity is release-only and rejects debug/profile builds.

## Quality checks

```sh
flutter analyze --no-pub
dart format --output=none --set-exit-if-changed lib test tool
flutter test --no-pub --reporter expanded
python -m unittest discover -s tool -p "test_*.py"
python tool/generate_privacy_policy.py --check
```

The suites cover content validation, hidden-object gameplay, saved-state safety, transactional persistence, hints, progression, Daily Challenge rewards, responsive layouts, privacy parity, release gates, and artifact verification. Signature regressions use disposable test keys, not the production upload key.

Run Flutter tests, capture tasks, analysis, and builds sequentially in the same working copy to avoid generated-file and native-asset contention.

For isolated widget captures:

```sh
flutter test --no-pub tool/capture_hidden_app_test.dart
flutter test --no-pub tool/capture_privacy_policy_test.dart
```

These tasks use test-owned storage. Gameplay captures are written to `verification/screenshots/`; policy captures and parity metadata are written to `verification/privacy-policy/`.

## Android build profiles

### QA APK

```sh
flutter build apk --release --no-pub --flavor qa --dart-define-from-file=config/qa.json
```

- APK: `build/app/outputs/flutter-apk/app-qa-release.apk`.
- R8 evidence: `build/app/outputs/mapping/qaRelease/`.
- Uses the QA package and a development certificate. **Not suitable for Google Play publication.**

### Unsigned production APK

This profile is for packaging inspection only. Both the Gradle property and the `unsigned-candidate` configuration are required:

```sh
flutter build apk --release --no-pub --flavor prod --android-project-arg=unsignedProductionCandidate=true --dart-define-from-file=config/unsigned-production.json
```

- APK: `build/app/outputs/flutter-apk/app-prod-release.apk`.
- R8 evidence: `build/app/outputs/mapping/prodRelease/`.
- Genuinely unsigned, with no development-signing fallback. It cannot be installed normally or published. Unsigned AAB builds are blocked.

`tool/verify_android_artifacts.py` provides the `qa-candidate`, `production-candidate`, and `signed-production-aab` inspection profiles. Supply each artifact's matching R8 mapping; QA inspection also requires its independently verified development-certificate fingerprint. See `python tool/verify_android_artifacts.py --help` for usage.

### Signed production AAB

Use the existing dedicated upload key. Production validation pins its public certificate and rejects development keys. **Do not recreate or replace the upload key.** Keep a secure backup, with the password stored separately.

After publishing the policy and approving the release inputs, use the private build workflow:

```sh
python tool/build_signed_aab.py --check-only
python tool/build_signed_aab.py --dialog
```

- `--check-only` checks the expected key's presence, public certificate pin, and generated-policy parity. It does not read a password, open the keystore, fetch the hosted policy, or build an AAB.
- `--dialog` requests the actual public HTTPS policy URL, masked entry of the existing key's password, and explicit secure-backup and publisher-review confirmations.
- The build verifies the complete live policy HTML and the actual upload certificate, creates `config/production.json` only if absent, rejects conflicting configuration, builds the signed AAB, and strictly inspects it.
- Successful output is retained with matching R8 files, inspection evidence, and checksums under a timestamped directory in `release/local/`. The build output is `build/app/outputs/bundle/prodRelease/app-prod-release.aab`.

Passwords must never appear in commands, source, logs, signing properties, or saved configuration. The helper passes credentials through child-process environments, discards raw credential-bearing subprocess output, and does not install, upload, or publish the app. Additional interactive/environment modes are described by `python tool/build_signed_aab.py --help`.

**A final signed production AAB has not yet been generated.** A verified live policy URL, fresh private credential entry, secure-backup confirmation, and publisher review remain required. Automated inspection does not replace real-device QA or Play Console review.

## Privacy policy

`assets/legal/privacy-policy.json` is the sole editable policy source. The app loads it offline; `privacy-policy.html` is generated from the same complete content. Both policy presentations are link-free, with the developer email shown as plain text.

After an approved policy change:

```sh
python tool/generate_privacy_policy.py --write
python tool/generate_privacy_policy.py --check --output verification/privacy-policy-parity.json
```

Follow the [GitHub Pages hosting guide](release/PRIVACY-POLICY-HOSTING.md) to publish the generated HTML. Use the actual rendered HTTPS page URL in release configuration and Play Console, not in the policy's content. Hosting only the policy file does not require publishing the Flutter source.

Final configuration is defined by `config/production.example.json`: `APP_ENV=production`, `BUILD_STAGE=final`, an empty `PACK_INDEX_URL`, and the verified `PRIVACY_POLICY_URL`. The actual `config/production.json` is ignored by Git. Placeholder, private, or non-HTTPS policy URLs are rejected.

Gameplay data remains in local storage, with no account-based recovery or cloud sync. Android configuration disables cloud/device-transfer backup of game data. Internet permission supports optional content capabilities; no remote pack server is configured for this release. Vibration permission supports optional haptic feedback.

## Release checklist

Before Google Play publication:

1. Approve package ownership, developer/contact details, asset distribution rights, policy commitments, and applicable legal obligations.
2. Publish and verify the complete HTTPS privacy policy, and confirm the existing upload key's secure backup.
3. Build and inspect the signed production AAB using final configuration and its matching R8 evidence.
4. Complete Android-device checks for gameplay, lifecycle/resume, audio, haptics, accessibility, large text, launcher/splash, storage/backup behavior, and 16 KB runtime compatibility.
5. Complete the Play Console listing, content rating, target-audience and Data safety declarations, app signing setup, and applicable testing/review requirements.

QA APKs, unsigned candidates, widget tests, and static packaging checks are not proof of complete store readiness. Upload and publication are separate release actions. The [Android validation record](release/local/2026-11-06/README.md) documents available artifacts and current verification coverage.

## Repository security

Keep `.gitignore` in place before staging files. It excludes Android binaries, private signing keys and backups, signing-properties files, environment files, SDK-local configuration, and final production configuration.

The allowlisted `verification/signing/production-upload-certificate.pem` is a **public certificate**, not a private key. `android/key.properties.example` contains placeholders only. Never put real passwords in that example or publish private signing material with the policy.

Before committing, review `git status --short` and `git diff --cached --name-only`. Ignore rules do not remove already tracked secrets; any exposure must be addressed separately. Check the exclusions with:

```sh
python -m unittest discover -s tool -p "test_gitignore.py"
```

## Web development preview

```sh
flutter build web --release --no-pub --no-web-resources-cdn --dart-define-from-file=config/qa.json
python tool/serve_preview.py --port 8771
```

Open `http://127.0.0.1:8771/` in a dedicated test browser profile. The loopback-only server supplies cross-origin isolation headers for durable Drift storage; it is not a public hosting service. Keep `sqlite3.wasm` and `drift_worker.js` beside `index.html`, and serve the app over HTTP rather than opening a file directly. Browser audio may require user interaction.

With the server running, execute the isolated smoke test:

```sh
node tool/verify_web_preview.mjs http://127.0.0.1:8771/
```

The test creates its own Chrome profile, checks hints, manual finds, resume, completion rewards, and unlocking across reloads, and records results under `verification/web-preview/runs/`. It does not clear unrelated browser storage.

## Content tooling

Optional puzzle packs accept hidden-object scenes only. `config/packs/example-v1.json` illustrates three expansion levels; it is not installed automatically. Packs cannot contain executable payloads, remote artwork, or Daily Challenge IDs.

```sh
dart run tool/pack_tool.dart validate config/packs/example-v1.json
```

Scene export and branding utilities are in `tool/`. Review target visibility and launcher/splash presentation whenever generated artwork changes.

## Project structure

- `lib/app/`: application setup and navigation.
- `lib/core/`: configuration, artwork, content validation, game rules, progression, and persistence.
- `lib/features/` and `lib/ui/`: gameplay, Home, Levels, Daily Challenge, Progress, Settings, and shared widgets.
- `assets/`: bundled levels, scenes, branding, audio, fonts, and legal notices.
- `android/`: Android identities, platform resources, signing checks, and release gates.
- `config/`: QA/inspection inputs, the final-config template, and optional pack examples.
- `test/` and `tool/`: automated tests, capture tasks, generators, policy tooling, and release inspectors.
- `release/` and `verification/`: listing assets, release documentation, checksums, and validation evidence. Android binaries remain excluded from Git.

## Licensing and contact

Third-party license notices and asset provenance are maintained in `assets/legal/`; in-app notices are available through **Settings → About → Open-source licenses**. A repository-wide distribution license is not currently specified. Confirm the applicable rights before redistributing code, artwork, audio, or branding.

- **Developer:** Abiral Acharya.
- **Support and privacy contact:** `abiralacharya80@gmail.com`.
