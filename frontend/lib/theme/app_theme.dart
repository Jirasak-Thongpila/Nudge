import 'package:flutter/material.dart';

/// Central Design System tokens for Nudge App based on ui-ux-pro-max guidelines.
/// Cyber-Zen / Linear Dark Mode Aesthetic.
class AppColors {
  // Brand & Accent Colors (Neon & Cyber Glow)
  static const Color primary = Color(0xFF6366F1); // Electric Indigo 500
  static const Color primaryDark = Color(0xFF4F46E5); // Indigo 600
  static const Color primaryLight = Color(0xFF818CF8); // Indigo 400
  static const Color primaryContainer = Color(0xFF1E1B4B); // Indigo 950

  static const Color teal = Color(0xFF10B981); // Cyber Mint / Emerald 500
  static const Color tealLight = Color(0xFF34D399); // Mint 400
  static const Color tealDark = Color(0xFF064E3B); // Emerald 950

  static const Color amber = Color(0xFFF59E0B); // Luminous Amber 500
  static const Color amberLight = Color(0xFFFBBF24); // Amber 400
  static const Color amberDark = Color(0xFF78350F); // Amber 900

  static const Color rose = Color(0xFFF43F5E); // Electric Rose 500
  static const Color roseLight = Color(0xFFFB7185); // Rose 400

  static const Color emerald = Color(0xFF10B981); // Emerald 500
  static const Color emeraldLight = Color(0xFF34D399);

  // Cyber-Zen Dark Canvas & Surfaces (Obsidian & Midnight Glass)
  static const Color bgCanvas = Color(0xFF090D16); // Deep space obsidian
  static const Color cardSurface = Color(0xFF111726); // Layered dark glass
  static const Color cardSurfaceElevated = Color(0xFF161F32); // Highlighted card
  static const Color cardBorder = Color(0xFF1E293B); // Subtle border
  static const Color cardBorderGlow = Color(0xFF313D56); // Highlight border

  // Text Hierarchy
  static const Color textPrimary = Color(0xFFF8FAFC); // Crisp white
  static const Color textSecondary = Color(0xFF94A3B8); // Slate 400
  static const Color textMuted = Color(0xFF64748B); // Slate 500

  // Slate Palette
  static const Color slate950 = Color(0xFF040711);
  static const Color slate900 = Color(0xFF0F172A);
  static const Color slate800 = Color(0xFF1E293B);
  static const Color slate700 = Color(0xFF334155);
  static const Color slate600 = Color(0xFF475569);
  static const Color slate500 = Color(0xFF64748B);
  static const Color slate400 = Color(0xFF94A3B8);
  static const Color slate300 = Color(0xFFCBD5E1);
  static const Color slate200 = Color(0xFFE2E8F0);
  static const Color slate100 = Color(0xFFF1F5F9);
  static const Color slate50 = Color(0xFFF8FAFC);
  static const Color white = Colors.white;

  // LINE brand color
  static const Color lineGreen = Color(0xFF06C755);

  // Semantic & Convenient Aliases
  static const Color primaryIndigo = primary;
  static const Color mindfulTeal = teal;
  static const Color avoidedAmber = amber;
  static const Color urgentRose = rose;
  static const Color completedEmerald = emerald;

  static const Color indigo50 = Color(0x1F6366F1); // Translucent glow tint
  static const Color amber50 = Color(0x1FF59E0B);
  static const Color amber200 = Color(0xFFFCD34D);
  static const Color amber300 = Color(0xFFFBBF24);
  static const Color amber700 = Color(0xFFB45309);
  static const Color amber800 = amberDark;

  static const Color rose50 = Color(0x1FF43F5E);
  static const Color rose600 = rose;

  static const Color emerald50 = Color(0x1F10B981);
  static const Color emerald200 = Color(0xFFA7F3D0);
  static const Color emerald700 = Color(0xFF047857);
}

class AppShadows {
  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x40000000),
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
  ];

  static const List<BoxShadow> cardHover = [
    BoxShadow(
      color: Color(0x60000000),
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
  ];

  static const List<BoxShadow> primaryGlow = [
    BoxShadow(
      color: Color(0x506366F1),
      blurRadius: 22,
      spreadRadius: 1,
      offset: Offset(0, 4),
    ),
  ];

  static const List<BoxShadow> lineGlow = [
    BoxShadow(
      color: Color(0x5006C755),
      blurRadius: 20,
      spreadRadius: 1,
      offset: Offset(0, 4),
    ),
  ];

  static const List<BoxShadow> amberGlow = [
    BoxShadow(
      color: Color(0x40F59E0B),
      blurRadius: 18,
      spreadRadius: 1,
      offset: Offset(0, 4),
    ),
  ];

  static const List<BoxShadow> mintGlow = [
    BoxShadow(
      color: Color(0x4010B981),
      blurRadius: 18,
      spreadRadius: 1,
      offset: Offset(0, 4),
    ),
  ];
}

class AppRadius {
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double pill = 999.0;

  static const double cardRadius = lg;
  static const double chipRadius = sm;
  static const double buttonRadius = md;

  static const BorderRadius smRadius = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdRadius = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgRadius = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius xlRadius = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius xxlRadius = BorderRadius.all(Radius.circular(xxl));
  static const BorderRadius pillRadius = BorderRadius.all(Radius.circular(pill));
}

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.bgCanvas,
      fontFamily: 'Prompt',
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        onPrimary: Colors.white,
        primaryContainer: AppColors.primaryContainer,
        secondary: AppColors.teal,
        onSecondary: Colors.white,
        surface: AppColors.cardSurface,
        onSurface: AppColors.textPrimary,
        error: AppColors.rose,
        onError: Colors.white,
        outline: AppColors.cardBorder,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.cardSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.lgRadius,
          side: const BorderSide(color: AppColors.cardBorder, width: 1.0),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.mdRadius),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.1,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.cardSurfaceElevated,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.mdRadius,
            side: const BorderSide(color: AppColors.cardBorder),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textSecondary,
          side: const BorderSide(color: AppColors.cardBorder),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.mdRadius),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.cardSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: AppRadius.mdRadius,
          borderSide: const BorderSide(color: AppColors.cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdRadius,
          borderSide: const BorderSide(color: AppColors.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdRadius,
          borderSide: const BorderSide(color: AppColors.primary, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdRadius,
          borderSide: const BorderSide(color: AppColors.rose),
        ),
        hintStyle: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 14,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.mdRadius),
        backgroundColor: AppColors.slate900,
        contentTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        elevation: 6,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.cardBorder,
        thickness: 1,
        space: 1,
      ),
    );
  }

  static ThemeData get lightTheme => darkTheme; // Default to signature dark mode
}
