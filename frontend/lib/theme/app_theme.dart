import 'package:flutter/material.dart';

/// Resolved dynamic color tokens based on active brightness/theme mode.
class AppColorTokens {
  final bool isDark;
  final Color bgCanvas;
  final Color cardSurface;
  final Color cardSurfaceElevated;
  final Color cardBorder;
  final Color cardBorderGlow;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color primaryContainer;
  final Color inputFill;
  final Color chipBg;
  final Color chipBorder;
  final List<BoxShadow> cardShadow;

  const AppColorTokens({
    required this.isDark,
    required this.bgCanvas,
    required this.cardSurface,
    required this.cardSurfaceElevated,
    required this.cardBorder,
    required this.cardBorderGlow,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.primaryContainer,
    required this.inputFill,
    required this.chipBg,
    required this.chipBorder,
    required this.cardShadow,
  });

  // Fixed Brand Accents
  Color get primary => AppColors.primary;
  Color get teal => AppColors.teal;
  Color get amber => AppColors.amber;
  Color get rose => AppColors.rose;
  Color get lineGreen => AppColors.lineGreen;

  static const AppColorTokens dark = AppColorTokens(
    isDark: true,
    bgCanvas: Color(0xFF090D16), // Deep space obsidian
    cardSurface: Color(0xFF111726), // Layered dark glass
    cardSurfaceElevated: Color(0xFF161F32), // Highlighted dark card
    cardBorder: Color(0xFF1E293B), // Slate 800 subtle border
    cardBorderGlow: Color(0xFF313D56), // Glow border
    textPrimary: Color(0xFFF8FAFC), // Crisp Slate 50
    textSecondary: Color(0xFF94A3B8), // Slate 400
    textMuted: Color(0xFF64748B), // Slate 500
    primaryContainer: Color(0xFF1E1B4B), // Indigo 950
    inputFill: Color(0xFF111726),
    chipBg: Color(0xFF161F32),
    chipBorder: Color(0xFF1E293B),
    cardShadow: [
      BoxShadow(
        color: Color(0x40000000),
        blurRadius: 16,
        offset: Offset(0, 4),
      ),
    ],
  );

  static const AppColorTokens light = AppColorTokens(
    isDark: false,
    bgCanvas: Color(0xFFF8FAFC), // Off-white clean canvas (Slate 50)
    cardSurface: Color(0xFFFFFFFF), // Pure crisp white
    cardSurfaceElevated: Color(0xFFF1F5F9), // Slate 100
    cardBorder: Color(0xFFE2E8F0), // Crisp Slate 200
    cardBorderGlow: Color(0xFFCBD5E1), // Slate 300
    textPrimary: Color(0xFF0F172A), // Slate 900 high-contrast
    textSecondary: Color(0xFF475569), // Slate 600
    textMuted: Color(0xFF94A3B8), // Slate 400
    primaryContainer: Color(0xFFEEF2FF), // Indigo 50
    inputFill: Color(0xFFFFFFFF),
    chipBg: Color(0xFFF1F5F9),
    chipBorder: Color(0xFFE2E8F0),
    cardShadow: [
      BoxShadow(
        color: Color(0x0A0F172A),
        blurRadius: 12,
        offset: Offset(0, 2),
      ),
    ],
  );
}

/// Central Design System tokens for Nudge App based on ui-ux-pro-max guidelines.
class AppColors {
  /// Context-aware token resolver that provides the appropriate tokens for Light or Dark mode.
  static AppColorTokens of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? AppColorTokens.dark : AppColorTokens.light;
  }

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

  // Static Fallback Canvas & Surfaces (Defaulting to Cyber-Zen Dark)
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

/// Helper extension on BuildContext for effortless access to active theme tokens.
extension ThemeContextExtension on BuildContext {
  AppColorTokens get colors => AppColors.of(this);
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;
}

class AppShadows {
  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x40000000),
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
  ];

  static const List<BoxShadow> cardLight = [
    BoxShadow(
      color: Color(0x0A0F172A),
      blurRadius: 12,
      offset: Offset(0, 2),
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
  /// Cyber-Zen Dark Theme
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColorTokens.dark.bgCanvas,
      fontFamily: 'Prompt',
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        onPrimary: Colors.white,
        primaryContainer: Color(0xFF1E1B4B),
        onPrimaryContainer: Colors.white,
        secondary: AppColors.teal,
        onSecondary: Colors.white,
        surface: Color(0xFF111726),
        onSurface: Color(0xFFF8FAFC),
        error: AppColors.rose,
        onError: Colors.white,
        outline: Color(0xFF1E293B),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: Color(0xFFF8FAFC),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Color(0xFFF8FAFC),
          fontSize: 18,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
          fontFamily: 'Prompt',
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColorTokens.dark.cardSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.lgRadius,
          side: BorderSide(color: AppColorTokens.dark.cardBorder, width: 1.0),
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
            fontFamily: 'Prompt',
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColorTokens.dark.cardSurfaceElevated,
          foregroundColor: AppColorTokens.dark.textPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.mdRadius,
            side: BorderSide(color: AppColorTokens.dark.cardBorder),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            fontFamily: 'Prompt',
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColorTokens.dark.textSecondary,
          side: BorderSide(color: AppColorTokens.dark.cardBorder),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.mdRadius),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            fontFamily: 'Prompt',
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColorTokens.dark.inputFill,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: AppRadius.mdRadius,
          borderSide: BorderSide(color: AppColorTokens.dark.cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdRadius,
          borderSide: BorderSide(color: AppColorTokens.dark.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdRadius,
          borderSide: const BorderSide(color: AppColors.primary, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdRadius,
          borderSide: const BorderSide(color: AppColors.rose),
        ),
        hintStyle: TextStyle(
          color: AppColorTokens.dark.textMuted,
          fontSize: 14,
          fontFamily: 'Prompt',
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.mdRadius),
        backgroundColor: AppColors.slate900,
        contentTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        elevation: 6,
      ),
      dividerTheme: DividerThemeData(
        color: AppColorTokens.dark.cardBorder,
        thickness: 1,
        space: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColorTokens.dark.cardSurface,
        indicatorColor: AppColors.primary.withValues(alpha: 0.25),
        elevation: 0,
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryLight,
              fontFamily: 'Prompt',
            );
          }
          return TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColorTokens.dark.textSecondary,
            fontFamily: 'Prompt',
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.primaryLight, size: 22);
          }
          return IconThemeData(color: AppColorTokens.dark.textSecondary, size: 22);
        }),
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: AppColorTokens.dark.bgCanvas,
        surfaceTintColor: Colors.transparent,
        elevation: 16,
      ),
    );
  }

  /// Crisp Linear Light Theme
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColorTokens.light.bgCanvas,
      fontFamily: 'Prompt',
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        onPrimary: Colors.white,
        primaryContainer: Color(0xFFEEF2FF),
        onPrimaryContainer: AppColors.primaryDark,
        secondary: AppColors.teal,
        onSecondary: Colors.white,
        surface: Color(0xFFFFFFFF),
        onSurface: Color(0xFF0F172A),
        error: AppColors.rose,
        onError: Colors.white,
        outline: Color(0xFFE2E8F0),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: Color(0xFF0F172A),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Color(0xFF0F172A),
          fontSize: 18,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
          fontFamily: 'Prompt',
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColorTokens.light.cardSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.lgRadius,
          side: BorderSide(color: AppColorTokens.light.cardBorder, width: 1.0),
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
            fontFamily: 'Prompt',
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColorTokens.light.cardSurface,
          foregroundColor: AppColorTokens.light.textPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.mdRadius,
            side: BorderSide(color: AppColorTokens.light.cardBorder),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            fontFamily: 'Prompt',
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColorTokens.light.textSecondary,
          side: BorderSide(color: AppColorTokens.light.cardBorder),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.mdRadius),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            fontFamily: 'Prompt',
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColorTokens.light.inputFill,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: AppRadius.mdRadius,
          borderSide: BorderSide(color: AppColorTokens.light.cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdRadius,
          borderSide: BorderSide(color: AppColorTokens.light.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdRadius,
          borderSide: const BorderSide(color: AppColors.primary, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdRadius,
          borderSide: const BorderSide(color: AppColors.rose),
        ),
        hintStyle: TextStyle(
          color: AppColorTokens.light.textMuted,
          fontSize: 14,
          fontFamily: 'Prompt',
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.mdRadius),
        backgroundColor: const Color(0xFF0F172A),
        contentTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        elevation: 6,
      ),
      dividerTheme: DividerThemeData(
        color: AppColorTokens.light.cardBorder,
        thickness: 1,
        space: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: AppColors.primary.withValues(alpha: 0.15),
        elevation: 0,
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
              fontFamily: 'Prompt',
            );
          }
          return TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColorTokens.light.textSecondary,
            fontFamily: 'Prompt',
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.primary, size: 22);
          }
          return IconThemeData(color: AppColorTokens.light.textSecondary, size: 22);
        }),
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: AppColorTokens.light.bgCanvas,
        surfaceTintColor: Colors.transparent,
        elevation: 16,
      ),
    );
  }
}
