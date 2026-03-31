import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── Colors ────────────────────────────────────────────────
  static const Color primary = Color(0xFF3DBE7A);
  static const Color primaryDark = Color(0xFF2A8F58);
  static const Color secondary = Color(0xFF6C63FF);
  static const Color background = Color(0xFFF0F7F3);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color error = Color(0xFFE05C5C);
  static const Color textPrimary = Color(0xFF1C2E26);
  static const Color textSecondary = Color(0xFF6B8F7A);
  static const Color cardShadow = Color(0x14000000);

  // ── Category Colors ───────────────────────────────────────
  static const Color catProductive = Color(0xFF3DBE7A);
  static const Color catEntertainment = Color(0xFFFF6B6B);
  static const Color catSocial = Color(0xFF6C63FF);
  static const Color catEducation = Color(0xFF29B6F6);
  static const Color catHealth = Color(0xFFEC407A);
  static const Color catGaming = Color(0xFFFFCA28);
  static const Color catOther = Color(0xFFB0BEC5);

  // ── Fatigue Colors ────────────────────────────────────────
  static const Color fatigueFresh = Color(0xFF3DBE7A);
  static const Color fatigueMild = Color(0xFFFFD54F);
  static const Color fatigueModerate = Color(0xFFFF8A65);
  static const Color fatigueHigh = Color(0xFFE05C5C);

  // ── Light Theme ───────────────────────────────────────────
  static ThemeData get light {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      colorScheme: ColorScheme.light(
        primary: primary,
        secondary: secondary,
        surface: surface,
        background: background,
        error: error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textPrimary,
        onBackground: textPrimary,
      ),
      scaffoldBackgroundColor: background,
      textTheme: GoogleFonts.dmSansTextTheme(base.textTheme).copyWith(
        displayLarge: GoogleFonts.fraunces(
          fontSize: 48,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          height: 1.1,
        ),
        displayMedium: GoogleFonts.fraunces(
          fontSize: 36,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          height: 1.2,
        ),
        headlineLarge: GoogleFonts.fraunces(
          fontSize: 28,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        headlineMedium: GoogleFonts.dmSans(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
        headlineSmall: GoogleFonts.dmSans(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
        titleLarge: GoogleFonts.dmSans(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        bodyLarge: GoogleFonts.dmSans(
          fontSize: 16,
          color: textPrimary,
          height: 1.5,
        ),
        bodyMedium: GoogleFonts.dmSans(
          fontSize: 14,
          color: textPrimary,
          height: 1.5,
        ),
        bodySmall: GoogleFonts.dmSans(
          fontSize: 12,
          color: textSecondary,
          height: 1.4,
        ),
        labelLarge: GoogleFonts.dmSans(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          letterSpacing: 0.3,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        margin: EdgeInsets.zero,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: textPrimary),
        titleTextStyle: GoogleFonts.dmSans(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: error),
        ),
        labelStyle: GoogleFonts.dmSans(color: textSecondary),
        hintStyle: GoogleFonts.dmSans(color: textSecondary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: GoogleFonts.dmSans(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: primary.withOpacity(0.12),
        iconTheme: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return const IconThemeData(color: primary, size: 24);
          }
          return IconThemeData(color: textSecondary, size: 22);
        }),
        labelTextStyle: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return GoogleFonts.dmSans(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: primary,
            );
          }
          return GoogleFonts.dmSans(fontSize: 11, color: textSecondary);
        }),
        elevation: 0,
        height: 72,
      ),
      dividerTheme: DividerThemeData(
        color: Colors.grey.shade200,
        thickness: 1,
        space: 1,
      ),
    );
  }

  // ── Reusable Decorations ──────────────────────────────────
  static BoxDecoration get primaryGradientCard => const BoxDecoration(
    gradient: LinearGradient(
      colors: [Color(0xFF3DBE7A), Color(0xFF2A8F58)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    borderRadius: BorderRadius.all(Radius.circular(24)),
  );

  static BoxDecoration get secondaryGradientCard => const BoxDecoration(
    gradient: LinearGradient(
      colors: [Color(0xFF6C63FF), Color(0xFF4B44CC)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    borderRadius: BorderRadius.all(Radius.circular(24)),
  );

  static BoxShadow get primaryShadow => BoxShadow(
    color: primary.withOpacity(0.3),
    blurRadius: 20,
    offset: const Offset(0, 8),
  );

  static BoxShadow get cardShadowLight =>
      const BoxShadow(color: cardShadow, blurRadius: 16, offset: Offset(0, 4));
}
