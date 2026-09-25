import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nudge_app/services/theme_controller.dart';
import 'package:nudge_app/theme/app_theme.dart';
import 'package:nudge_app/widgets/theme_toggle_button.dart';

void main() {
  group('ThemeController & AppTheme Tests', () {
    test('ThemeController toggles between dark and light mode', () {
      final controller = ThemeController.instance;

      // Set explicit dark
      controller.setThemeMode(ThemeMode.dark);
      expect(controller.value, ThemeMode.dark);
      expect(controller.isDarkMode, isTrue);

      // Toggle to light
      controller.toggleTheme();
      expect(controller.value, ThemeMode.light);
      expect(controller.isDarkMode, isFalse);

      // Toggle back to dark
      controller.toggleTheme();
      expect(controller.value, ThemeMode.dark);
      expect(controller.isDarkMode, isTrue);
    });

    testWidgets('ThemeToggleButton animates and toggles theme on tap', (tester) async {
      final controller = ThemeController.instance;
      controller.setThemeMode(ThemeMode.dark);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.dark,
          home: const Scaffold(
            appBar: PreferredSize(
              preferredSize: Size.fromHeight(56),
              child: ThemeToggleButton(),
            ),
          ),
        ),
      );

      // Expect to find ThemeToggleButton widget
      expect(find.byType(ThemeToggleButton), findsOneWidget);

      // Tap toggle button
      await tester.tap(find.byType(ThemeToggleButton));
      await tester.pumpAndSettle();

      // Controller should now be light
      expect(controller.value, ThemeMode.light);

      // Tap again to switch back
      await tester.tap(find.byType(ThemeToggleButton));
      await tester.pumpAndSettle();

      expect(controller.value, ThemeMode.dark);
    });

    testWidgets('context.colors dynamically resolves tokens based on theme brightness', (tester) async {
      late AppColorTokens lightColors;
      late AppColorTokens darkColors;

      await tester.pumpWidget(
        Theme(
          data: AppTheme.lightTheme,
          child: Builder(
            builder: (context) {
              lightColors = context.colors;
              return const SizedBox();
            },
          ),
        ),
      );

      expect(lightColors.isDark, isFalse);
      expect(lightColors.bgCanvas, const Color(0xFFF8FAFC));
      expect(lightColors.textPrimary, const Color(0xFF0F172A));

      await tester.pumpWidget(
        Theme(
          data: AppTheme.darkTheme,
          child: Builder(
            builder: (context) {
              darkColors = context.colors;
              return const SizedBox();
            },
          ),
        ),
      );

      expect(darkColors.isDark, isTrue);
      expect(darkColors.bgCanvas, const Color(0xFF090D16));
      expect(darkColors.textPrimary, const Color(0xFFF8FAFC));
    });
  });
}
