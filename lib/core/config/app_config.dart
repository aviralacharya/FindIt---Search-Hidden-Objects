abstract final class AppConfig {
  static const name = 'FindIt';
  static const launcherName = 'FindIt';
  static const androidPackage = 'abiral.mobile.findit';
  static const iconAsset = 'assets/branding/app_icon.png';
  static const tagline = 'Little things. Wonderful places. Look closer.';
  static const storageNamespace = 'findit_hidden_objects';
  static const version = '1.0.0';
  static const developerName = 'Abiral Acharya';
  static const developerEmail = 'abiralacharya80@gmail.com';
  static const contentVersion = 1;
  static const hintCost = 20;
  static const initialCoins = 100;
  static const dailyBonus = 60;
  static const packIndexUrl = String.fromEnvironment('PACK_INDEX_URL');
  static const privacyPolicyUrl = String.fromEnvironment('PRIVACY_POLICY_URL');
  static const environment = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'development',
  );
  static const buildStage = String.fromEnvironment('BUILD_STAGE');
  static const production = environment == 'production';
  static const candidate =
      buildStage == 'unsigned-candidate' || buildStage == 'qa';
}
