# FindIt

<img src="assets/branding/app_icon.png" alt="FindIt magnifying-glass and golden-leaf app icon" width="96" height="96" />

*Little things. Wonderful places. Look closer.*

FindIt is an offline hidden-object game for Android. Explore colorful scenes, find hidden items, and earn rewards at your own pace.

- **Version:** 1.0.0 (unreleased).
- **Android:** 7.0 and later.

## Features

- 60 bundled levels that work offline.
- Pan, zoom, and follow the object checklist.
- Relaxed or timed gameplay.
- Earned coins, two-stage hints, scores, and stars.
- Daily Challenges with bonus rewards.
- Save and resume progress, with adjustable sound, music, and vibration.

## Branding

The original logo is preserved in `assets/branding/icon_source.png`. The app, Android launcher and splash screens, web icons, and Play Store icon are generated from that image without stretching it.

To regenerate the branding assets:

```sh
flutter test --no-pub tool/prepare_branding_test.dart
```

The in-app logo retains transparency. `release/play-store/graphics/icon-512.png` is the opaque 512-pixel Play Store icon. Existing APKs must be rebuilt and reinstalled to show updated branding.

## Privacy

No accounts, ads, analytics, or in-app purchases. Game progress and settings are stored locally on your device. The complete policy is also available offline in the app.

[Read the privacy policy](https://aviralacharya.github.io/FindIt-Search-Hidden-Objects/privacy-policy)

## Support

- **Developer:** Abiral Acharya.
- **Email:** `abiralacharya80@gmail.com`.
