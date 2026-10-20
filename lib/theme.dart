import 'package:flutter/material.dart';

/// The app's colours: emerald like the web, with a lime accent and a colour per state.
abstract final class AppColors {
  static const primary = Color(0xFF059669);
  static const primaryDark = Color(0xFF065F46);
  static const teal = Color(0xFF14B8A6);
  static const lime = Color(0xFFA3E635);
  static const mint = Color(0xFFD1FAE5);

  static const ink = Color(0xFF0F1F1A);
  static const muted = Color(0xFF66766F);
  static const background = Color(0xFFF3F7F4);
  static const line = Color(0xFFE2EAE5);

  static const blue = Color(0xFF2563EB);
  static const indigo = Color(0xFF6366F1);
  static const amber = Color(0xFFF59E0B);
  static const orange = Color(0xFFF97316);
  static const rose = Color(0xFFE11D48);
  static const violet = Color(0xFF8B5CF6);
  static const zalo = Color(0xFF0068FF);

  /// Headers, the picked cells and the main buttons.
  static const brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryDark, primary, teal],
  );

  static const limeGradient = LinearGradient(colors: [Color(0xFFD9F99D), lime]);

  /// "Waiting for your transfer": warm, so it stands out from the bookings.
  static const payGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [amber, orange],
  );

  static Color bookingStatus(String status) => switch (status) {
    'pending' => amber,
    'confirmed' => primary,
    'checked_in' => blue,
    'completed' => teal,
    'cancelled' => rose,
    _ => muted,
  };

  static Color paymentStatus(String status) => switch (status) {
    'paid' => primary,
    'refunded' => violet,
    _ => orange,
  };

  static Color skill(String level) => switch (level) {
    'beginner' => primary,
    'intermediate' => blue,
    'advanced' => orange,
    'expert' => rose,
    _ => muted,
  };
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    primary: AppColors.primary,
    surface: Colors.white,
    error: AppColors.rose,
  );
  final rounded = RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));
  final base = ThemeData(colorScheme: scheme, fontFamily: 'BeVietnamPro');

  return base.copyWith(
    scaffoldBackgroundColor: AppColors.background,
    textTheme: base.textTheme.apply(bodyColor: AppColors.ink, displayColor: AppColors.ink),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.ink,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        fontFamily: 'BeVietnamPro',
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: AppColors.ink,
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      prefixIconColor: AppColors.primary,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontFamily: 'BeVietnamPro', fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: const StadiumBorder(),
        side: const BorderSide(color: AppColors.line, width: 1.5),
        textStyle: const TextStyle(fontFamily: 'BeVietnamPro', fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        textStyle: const TextStyle(fontFamily: 'BeVietnamPro', fontWeight: FontWeight.w700),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: const StadiumBorder(),
      side: const BorderSide(color: AppColors.line),
      backgroundColor: Colors.white,
      labelStyle: const TextStyle(fontFamily: 'BeVietnamPro', fontWeight: FontWeight.w600, color: AppColors.ink),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      indicatorColor: AppColors.mint,
      height: 68,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontFamily: 'BeVietnamPro',
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
          color: states.contains(WidgetState.selected) ? AppColors.primaryDark : AppColors.muted,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) =>
            IconThemeData(color: states.contains(WidgetState.selected) ? AppColors.primaryDark : AppColors.muted),
      ),
    ),
    listTileTheme: ListTileThemeData(
      shape: rounded,
      titleTextStyle: const TextStyle(
        fontFamily: 'BeVietnamPro',
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
      ),
      subtitleTextStyle: const TextStyle(fontFamily: 'BeVietnamPro', fontSize: 13, color: AppColors.muted),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      showDragHandle: true,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.ink,
      shape: rounded,
    ),
    dividerTheme: const DividerThemeData(color: AppColors.line, space: 1),
  );
}
