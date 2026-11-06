import 'package:flutter/material.dart';

import '../core/domain/puzzle.dart';

abstract final class FindItColors {
  static const cream = Color(0xFFFBF7EE);
  static const paper = Color(0xFFFFFDF8);
  static const forest = Color(0xFF237A68);
  static const ink = Color(0xFF293E38);
  static const muted = Color(0xFF718078);
  static const line = Color(0xFFE5E6DB);
  static const sage = Color(0xFFE8EFE0);
  static const gold = Color(0xFFE8B75C);
  static const coral = Color(0xFFBF6754);

  static Color modeBackground(GameMode mode) => switch (mode) {
    GameMode.differences => const Color(0xFFE7EDDE),
    GameMode.hidden => const Color(0xFFF2E7D8),
    GameMode.odd => const Color(0xFFF4E2D9),
    GameMode.memory => const Color(0xFFE7E5F0),
    GameMode.quick => const Color(0xFFDDECEF),
    GameMode.daily => const Color(0xFFF4EDD5),
  };

  static Color modeInk(GameMode mode) => switch (mode) {
    GameMode.differences => forest,
    GameMode.hidden => const Color(0xFF876947),
    GameMode.odd => const Color(0xFFA55F47),
    GameMode.memory => const Color(0xFF726489),
    GameMode.quick => const Color(0xFF497E8D),
    GameMode.daily => const Color(0xFF8E7134),
  };
}

ThemeData buildFindItTheme() {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: FindItColors.forest,
        brightness: Brightness.light,
      ).copyWith(
        primary: FindItColors.forest,
        onPrimary: Colors.white,
        surface: FindItColors.paper,
        onSurface: FindItColors.ink,
        onSurfaceVariant: FindItColors.muted,
        outline: FindItColors.line,
        outlineVariant: FindItColors.line,
        error: FindItColors.coral,
      );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: 'Nunito',
    scaffoldBackgroundColor: FindItColors.cream,
  );
  final text = base.textTheme
      .copyWith(
        displaySmall: const TextStyle(
          fontFamily: 'Outfit',
          fontSize: 44,
          height: 1.10,
          letterSpacing: -1.3,
          fontWeight: FontWeight.w600,
        ),
        headlineLarge: const TextStyle(
          fontFamily: 'Outfit',
          fontSize: 36,
          height: 1.12,
          letterSpacing: -.9,
          fontWeight: FontWeight.w600,
        ),
        headlineMedium: const TextStyle(
          fontFamily: 'Outfit',
          fontSize: 28,
          height: 1.2,
          letterSpacing: -.6,
          fontWeight: FontWeight.w600,
        ),
        headlineSmall: const TextStyle(
          fontFamily: 'Outfit',
          fontSize: 24,
          height: 1.25,
          letterSpacing: -.4,
          fontWeight: FontWeight.w600,
        ),
        titleLarge: const TextStyle(
          fontFamily: 'Outfit',
          fontSize: 21,
          height: 1.25,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: const TextStyle(
          fontFamily: 'Outfit',
          fontSize: 17,
          height: 1.3,
          fontWeight: FontWeight.w500,
        ),
        titleSmall: const TextStyle(
          fontFamily: 'Outfit',
          fontSize: 15,
          height: 1.3,
          fontWeight: FontWeight.w500,
        ),
        bodyLarge: const TextStyle(
          fontFamily: 'Nunito',
          fontSize: 16,
          height: 1.45,
          fontWeight: FontWeight.w500,
        ),
        bodyMedium: const TextStyle(
          fontFamily: 'Nunito',
          fontSize: 14,
          height: 1.45,
          fontWeight: FontWeight.w500,
        ),
        bodySmall: const TextStyle(
          fontFamily: 'Nunito',
          fontSize: 12,
          height: 1.4,
          fontWeight: FontWeight.w500,
        ),
        labelLarge: const TextStyle(
          fontFamily: 'Nunito',
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
        labelMedium: const TextStyle(
          fontFamily: 'Nunito',
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      )
      // Apply colors after replacing typography so custom styles do not inherit
      // platform/test-renderer defaults (including white on the cream surface).
      .apply(bodyColor: FindItColors.ink, displayColor: FindItColors.ink);
  return base.copyWith(
    textTheme: text,
    appBarTheme: const AppBarTheme(
      backgroundColor: FindItColors.cream,
      foregroundColor: FindItColors.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 50),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        textStyle: text.labelLarge,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 50),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        side: const BorderSide(color: FindItColors.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        textStyle: text.labelLarge,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
    cardTheme: CardThemeData(
      color: FindItColors.paper,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: FindItColors.line),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: FindItColors.paper,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: FindItColors.paper,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: FindItColors.paper,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: FindItColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: FindItColors.line),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: FindItColors.ink,
      contentTextStyle: text.bodyMedium?.copyWith(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    dividerTheme: const DividerThemeData(
      color: FindItColors.line,
      thickness: 1,
      space: 24,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: FindItColors.forest,
      linearTrackColor: FindItColors.sage,
      borderRadius: BorderRadius.all(Radius.circular(8)),
    ),
    tooltipTheme: const TooltipThemeData(
      waitDuration: Duration(milliseconds: 500),
    ),
  );
}
