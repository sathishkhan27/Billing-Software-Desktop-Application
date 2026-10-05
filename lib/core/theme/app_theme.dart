import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Deep enterprise navy/slate palette matching modern desktop billing apps
  static const Color darkBg = Color(0xFF0B1120); // Darkest canvas
  static const Color sidebarBg = Color(0xFF0F172A); // Slate 900
  static const Color sidebarActiveBg = Color(0xFF1E3A8A); // Blue 900 active highlight
  static const Color cardBg = Color(0xFF1E293B); // Slate 800
  static const Color cardBorder = Color(0xFF334155); // Slate 700
  static const Color cardSubtleBg = Color(0xFF141F32);
  
  // Brand & Action Accents
  static const Color primaryBlue = Color(0xFF2563EB); // Royal Blue (Save & Send, active tabs)
  static const Color primaryBlueDark = Color(0xFF1D4ED8);
  static const Color primaryEmerald = Color(0xFF10B981); // Emerald 500 (GST Ready, Success)
  static const Color primaryEmeraldDark = Color(0xFF059669);
  static const Color accentCyan = Color(0xFF06B6D4); // Cyan (Today's sales card)
  static const Color accentRose = Color(0xFFEF4444); // Crimson (Expenses, Delete)
  static const Color accentAmber = Color(0xFFF59E0B); // Amber (Stock status, Warnings)
  static const Color accentPurple = Color(0xFF8B5CF6);

  // Typography
  static const Color textLight = Color(0xFFF8FAFC);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color activeRowBg = Color(0xFF1E3A8A);
  static const Color hotkeyBg = Color(0xFF334155);

  // ---- Responsive Breakpoints ----
  /// < 600px  → mobile (bottom navigation bar)
  static const double breakpointMobile = 600;
  /// 600–959px → tablet (navigation rail)
  static const double breakpointTablet = 960;
  /// ≥ 960px   → desktop (extended sidebar)

  static bool isMobile(BuildContext ctx) =>
      MediaQuery.sizeOf(ctx).width < breakpointMobile;

  static bool isTablet(BuildContext ctx) {
    final w = MediaQuery.sizeOf(ctx).width;
    return w >= breakpointMobile && w < breakpointTablet;
  }

  static bool isDesktop(BuildContext ctx) =>
      MediaQuery.sizeOf(ctx).width >= breakpointTablet;

  static TextStyle font({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
    FontStyle? fontStyle,
    double? letterSpacing,
  }) {
    return GoogleFonts.poppins(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      fontStyle: fontStyle,
      letterSpacing: letterSpacing,
    );
  }

  static ThemeData get darkTheme {
    final poppinsTextTheme = GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme).apply(
      bodyColor: textLight,
      displayColor: textLight,
      decorationColor: textLight,
    );

    final baseTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBg,
      fontFamily: 'Poppins',
      fontFamilyFallback: const ['Segoe UI', 'Roboto', 'Helvetica Neue', 'Arial', 'sans-serif'],
      colorScheme: const ColorScheme.dark(
        primary: primaryBlue,
        secondary: primaryEmerald,
        surface: cardBg,
        onSurface: textLight,
      ),
      textTheme: poppinsTextTheme,
      primaryTextTheme: poppinsTextTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: darkBg,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.poppins(
          color: textLight,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        color: cardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: cardBorder, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF0F172A),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: primaryBlue, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        hintStyle: GoogleFonts.poppins(color: textMuted, fontSize: 13),
        labelStyle: GoogleFonts.poppins(color: textMuted, fontSize: 13),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
        unselectedLabelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w400, fontSize: 13),
      ),
    );

    return baseTheme;
  }
}
