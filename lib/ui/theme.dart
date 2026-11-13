import 'package:material_ui/material_ui.dart';

/// The only place colors and text styles are defined. Screens use these
/// names, never raw hex values.
abstract final class AppColors {
  static const Color ground = Color(0xFFE6E9E1);
  static const Color paper = Color(0xFFFBFBF7);
  static const Color ink = Color(0xFF15191E);
  static const Color muted = Color(0xFF4A5058);
  static const Color highlight = Color(0xFFFFE45C);
  static const Color action = Color(0xFF1F3BD1);
  static const Color danger = Color(0xFFA3231C);
  static const Color track = Color(0xFFDADDD3);
  static const Color leader = Color(0xFF8D928A);
  static const Color quote = Color(0xFFEEF0E9);
}

abstract final class AppText {
  static const _mono = 'monospace';
  static const _tabular = [FontFeature.tabularFigures()];

  static const TextStyle brand = TextStyle(
    fontFamily: _mono,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    letterSpacing: 2.2,
    color: AppColors.ink,
  );
  static const TextStyle title = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    color: AppColors.ink,
  );
  static const TextStyle heading = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: AppColors.ink,
  );
  static const TextStyle body = TextStyle(fontSize: 15, color: AppColors.ink);
  static const TextStyle strong = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: AppColors.ink,
  );
  static const TextStyle note = TextStyle(fontSize: 13, color: AppColors.muted);
  static const TextStyle label = TextStyle(
    fontFamily: _mono,
    fontSize: 11,
    letterSpacing: 0.9,
    color: AppColors.muted,
  );
  static const TextStyle amount = TextStyle(
    fontFamily: _mono,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    fontFeatures: _tabular,
    color: AppColors.ink,
  );
  static const TextStyle total = TextStyle(
    fontFamily: _mono,
    fontSize: 40,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.8,
    fontFeatures: _tabular,
    color: AppColors.ink,
  );
  static const TextStyle sms = TextStyle(
    fontFamily: _mono,
    fontSize: 13,
    height: 1.5,
    color: AppColors.ink,
  );
}

ThemeData buildTheme() {
  const scheme = ColorScheme.light(
    primary: AppColors.action,
    secondary: AppColors.highlight,
    onSecondary: AppColors.ink,
    surface: AppColors.paper,
    onSurface: AppColors.ink,
    error: AppColors.danger,
  );
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(4));
  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.ground,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.ground,
      foregroundColor: AppColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 52),
        shape: shape,
        textStyle: AppText.strong,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 48),
        shape: shape,
        foregroundColor: AppColors.ink,
        side: const BorderSide(color: AppColors.ink, width: 1.5),
        textStyle: AppText.strong,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: AppColors.action, width: 2),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.paper,
      shape: RoundedRectangleBorder(),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AppColors.ink,
      behavior: SnackBarBehavior.floating,
    ),
  );
}
