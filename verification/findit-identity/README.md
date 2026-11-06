# FindIt identity verification — 1.0.0 (unreleased)

This snapshot checks the requested Android package `abiral.mobile.findit`, the **FindIt** launcher/in-app name, shared `assets/branding/app_icon.png` artwork, and the player-facing About, Settings, and collection cleanup. The supplied artwork was not regenerated. The app remains `1.0.0+1`, and the shared policy remains `1.0.0`.

## Checks

- `flutter-tests-final.txt`: **527 tests passed** with `config/production.json`, including startup, home, About, licenses, Android identity, package-free privacy, and player-facing copy regressions.
- `python-tests-final.txt`: **100 local tooling tests passed**. Python source files remain ignored and local-only; synthetic workflow tests do not build the app.
- `analyze-final.txt`: no issues found.
- `format-final.txt`: 74 Dart files checked, with no formatting changes needed.
- `capture-tests-final.txt` and `capture-details-tests-final.txt`: two main capture tests and one scrolled-details capture test passed with the final production configuration.
- `privacy-policy-parity.json`: all **11 sections** share one JSON source and identical generated HTML. No app package identifier appears in either policy copy; the internal receiver permission is explained without its package prefix. Hosting/website and policy-generation explanations are omitted from both copies, with regression checks for the requested cleanup.
- `source-preservation.json`: all 227 recorded original source files and both original release artifacts still match their existing hashes. The original project was not modified.

## Reviewed captures

`production-ui/captures.json` records 26 PNGs and their hashes. They cover startup, hidden-mode artwork, and home/Settings/collection/About/licenses/offline-policy screens at phone, small-phone large-text, and wide sizes. `production-ui/details-captures.json` adds 12 scrolled views of Settings' collection/About entries, collection availability, and About's support/legal/version section. Some views are identical where the entire section already fits on screen.

All **38 PNG checksums and dimensions** were verified after the policy cleanup. The four changed capture files were reviewed: three policy views and the phone Home view with its decoded scene preview. The other 34 are byte-identical to already reviewed production captures. `production-ui/visual-review-status.json` records the review scope. Route transitions are allowed to paint, and the helper waits for the shared icon to finish decoding before scrolled captures.

These are widget-test captures, **not screenshots of an installed signed APK or device QA**. They use `APP_ENV=production`, `BUILD_STAGE=final`, isolated test-owned SQLite/preferences, and no pack server; startup is held before disk storage opens. About shows only game information, developer contact, privacy access, licenses, and plain `Version 1.0.0`. Publisher tooling, icon/reuse/provenance notes, and implementation explanations are no longer player-facing. Large-text pages remain scrollable. No existing saves, installation, upload, or app publication is involved.

Earlier development captures/logs, the first cold-decoder scrolled capture attempt, and the pre-policy-sync production snapshot remain preserved locally and excluded from the public tree. Original legal/provenance records and downloaded-pack license display are retained.

For another capture, use a new directory so existing snapshots cannot be overwritten:

```powershell
flutter test --no-pub --dart-define-from-file=config/production.json --dart-define=FINDIT_IDENTITY_CAPTURE_DIRECTORY=verification/findit-identity/new-review tool/capture_findit_identity_test.dart
```

The existing upload key, alias, and pinned public certificate are retained. Its actual certificate subject is unchanged; only the package-assignment metadata changed. Signed-APK inspection is recorded separately in a new local release revision after the current policy is hosted and fresh masked signing input plus backup/publisher-review confirmations are supplied. Earlier APKs and validation snapshots are preserved, not rebaselined or presented as the corrected build.

The top-level public checksum manifest preserves four older local CRLF hashes whose unchanged Git content uses LF endings, including the public certificate PEM. Those original local bytes still match their saved hashes. Current identity evidence uses LF, so its hashes also match the published Git bytes.
