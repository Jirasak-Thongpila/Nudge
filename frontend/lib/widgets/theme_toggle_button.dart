import 'package:flutter/material.dart';
import '../services/theme_controller.dart';
import '../theme/app_theme.dart';

/// Interactive button to toggle between Light Mode and Dark Mode with smooth micro-animation.
class ThemeToggleButton extends StatelessWidget {
  final EdgeInsetsGeometry? margin;

  const ThemeToggleButton({
    super.key,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.instance,
      builder: (context, mode, _) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final colors = context.colors;

        return Container(
          margin: margin ?? const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: colors.cardSurface,
            shape: BoxShape.circle,
            border: Border.all(color: colors.cardBorder),
            boxShadow: isDark
                ? [
                    BoxShadow(
                      color: Colors.amber.withValues(alpha: 0.12),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ]
                : [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: IconButton(
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) {
                return RotationTransition(
                  turns: animation,
                  child: FadeTransition(
                    opacity: animation,
                    child: child,
                  ),
                );
              },
              child: isDark
                  ? const Icon(
                      Icons.light_mode_rounded,
                      key: ValueKey('light_mode_icon'),
                      color: AppColors.amberLight,
                      size: 20,
                    )
                  : const Icon(
                      Icons.dark_mode_rounded,
                      key: ValueKey('dark_mode_icon'),
                      color: AppColors.primary,
                      size: 20,
                    ),
            ),
            tooltip: isDark
                ? 'สลับเป็นโหมดสว่าง (Light Mode)'
                : 'สลับเป็นโหมดมืด (Dark Mode)',
            onPressed: () {
              ThemeController.instance.toggleTheme();
            },
          ),
        );
      },
    );
  }
}
