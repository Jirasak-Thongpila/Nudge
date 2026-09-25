import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/liff_service.dart';
import '../services/theme_controller.dart';
import '../theme/app_theme.dart';

/// Premium Material 3 Drawer for Nudge Mobile app.
/// Displays user identity, navigation destinations, quick actions, theme switcher, and logout.
class NudgeDrawer extends StatelessWidget {
  final User user;
  final int currentIndex;
  final ValueChanged<int> onSelectTab;
  final VoidCallback onAddTask;
  final VoidCallback onRefresh;
  final VoidCallback onLogout;

  const NudgeDrawer({
    super.key,
    required this.user,
    required this.currentIndex,
    required this.onSelectTab,
    required this.onAddTask,
    required this.onRefresh,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final liffProfile = LiffService.instance.profile;
    final isLineConnected = user.lineUserId != null && user.lineUserId!.isNotEmpty;
    final displayName = liffProfile?.displayName ??
        (isLineConnected ? 'ผู้ใช้ LINE' : 'ผู้ใช้งาน (Guest)');

    return Drawer(
      backgroundColor: colors.bgCanvas,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Drawer Header with Modern Cyber-Zen Gradient
            _buildDrawerHeader(context, displayName, isLineConnected, liffProfile?.pictureUrl),

            // Scrollable Menu Items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                children: [
                  _buildSectionHeader('เมนูหลัก'),
                  _buildNavItem(
                    context: context,
                    index: 0,
                    icon: Icons.space_dashboard_rounded,
                    label: 'แดชบอร์ด (Dashboard)',
                    isSelected: currentIndex == 0,
                  ),
                  _buildNavItem(
                    context: context,
                    index: 1,
                    icon: Icons.checklist_rounded,
                    label: 'งานทั้งหมด (Tasks)',
                    isSelected: currentIndex == 1,
                  ),
                  _buildNavItem(
                    context: context,
                    index: 2,
                    icon: Icons.notifications_active_rounded,
                    label: 'แจ้งเตือน Nudge',
                    isSelected: currentIndex == 2,
                  ),

                  const SizedBox(height: 12),
                  const Divider(indent: 8, endIndent: 8),
                  const SizedBox(height: 8),

                  _buildSectionHeader('การดำเนินการด่วน'),
                  _buildActionTile(
                    context: context,
                    icon: Icons.add_task_rounded,
                    iconColor: AppColors.primaryLight,
                    title: 'สร้าง Task ใหม่',
                    subtitle: 'เพิ่มงานพร้อมตัวช่วย AI',
                    onTap: () {
                      Navigator.pop(context);
                      onAddTask();
                    },
                  ),
                  _buildActionTile(
                    context: context,
                    icon: Icons.sync_rounded,
                    iconColor: AppColors.teal,
                    title: 'ซิงค์และรีเฟรชข้อมูล',
                    subtitle: 'อัปเดตสถานะงานและระบบแจ้งเตือน',
                    onTap: () {
                      Navigator.pop(context);
                      onRefresh();
                    },
                  ),

                  const SizedBox(height: 12),
                  const Divider(indent: 8, endIndent: 8),
                  const SizedBox(height: 8),

                  _buildSectionHeader('การตั้งค่า'),
                  _buildThemeSwitchTile(context),
                ],
              ),
            ),

            // Footer with Logout & Version Info
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerHeader(
    BuildContext context,
    String displayName,
    bool isLineConnected,
    String? pictureUrl,
  ) {
    final topPadding = MediaQuery.of(context).padding.top;
    final uuidShort = user.deviceUuid.length > 12
        ? '${user.deviceUuid.substring(0, 8)}...${user.deviceUuid.substring(user.deviceUuid.length - 4)}'
        : user.deviceUuid;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: topPadding + 20,
        left: 20,
        right: 20,
        bottom: 20,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isLineConnected
              ? [const Color(0xFF06C755).withValues(alpha: 0.85), const Color(0xFF0F172A)]
              : [const Color(0xFF4F46E5), const Color(0xFF1E1B4B)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // User Avatar
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: pictureUrl != null
                      ? Image.network(
                          pictureUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildAvatarFallback(isLineConnected),
                        )
                      : _buildAvatarFallback(isLineConnected),
                ),
              ),
              const Spacer(),
              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (isLineConnected ? AppColors.lineGreen : Colors.white).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isLineConnected ? AppColors.lineGreen : AppColors.amberLight,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isLineConnected ? 'LINE เชื่อมต่อ' : 'โหมด Guest',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // User Name
          Text(
            displayName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          // Device UUID / User ID
          Text(
            'ID #${user.id} • UUID: $uuidShort',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 12,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarFallback(bool isLineConnected) {
    return Container(
      color: isLineConnected ? AppColors.lineGreen : const Color(0xFF6366F1),
      child: Icon(
        isLineConnected ? Icons.chat_bubble_rounded : Icons.person_rounded,
        color: Colors.white,
        size: 28,
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, top: 8, bottom: 6),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
          color: AppColors.textMuted,
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required int index,
    required IconData icon,
    required String label,
    required bool isSelected,
  }) {
    final colors = context.colors;
    final activeColor = AppColors.primary;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: isSelected ? activeColor.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.buttonRadius),
        border: isSelected
            ? Border.all(color: activeColor.withValues(alpha: 0.3))
            : null,
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.buttonRadius)),
        leading: Icon(
          icon,
          color: isSelected ? activeColor : colors.textSecondary,
          size: 22,
        ),
        title: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? activeColor : colors.textPrimary,
          ),
        ),
        dense: true,
        onTap: () {
          Navigator.pop(context);
          onSelectTab(index);
        },
      ),
    );
  }

  Widget _buildActionTile({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final colors = context.colors;

    return ListTile(
      dense: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.buttonRadius)),
      leading: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Icon(icon, color: iconColor, size: 18),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
          color: colors.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 11,
          color: colors.textSecondary,
        ),
      ),
      onTap: onTap,
    );
  }

  Widget _buildThemeSwitchTile(BuildContext context) {
    final colors = context.colors;

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.instance,
      builder: (context, mode, _) {
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return ListTile(
          dense: true,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.buttonRadius)),
          leading: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: (isDark ? AppColors.amberLight : AppColors.primary).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(
              isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
              color: isDark ? AppColors.amberLight : AppColors.primary,
              size: 18,
            ),
          ),
          title: Text(
            'โหมดมืด (Dark Mode)',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
            ),
          ),
          subtitle: Text(
            isDark ? 'เปิดใช้งานอยู่ (Cyber-Zen Dark)' : 'ปิดอยู่ (Linear Crisp Light)',
            style: TextStyle(
              fontSize: 11,
              color: colors.textSecondary,
            ),
          ),
          trailing: Switch.adaptive(
            value: isDark,
            activeTrackColor: AppColors.primary,
            onChanged: (val) {
              ThemeController.instance.toggleTheme();
            },
          ),
        );
      },
    );
  }

  Widget _buildFooter(BuildContext context) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colors.cardSurface,
        border: Border(top: BorderSide(color: colors.cardBorder)),
      ),
      child: Column(
        children: [
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppColors.rose.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: const Icon(Icons.logout_rounded, color: AppColors.rose, size: 18),
            ),
            title: const Text(
              'ออกจากระบบ',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.rose,
              ),
            ),
            onTap: () {
              Navigator.pop(context);
              onLogout();
            },
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Nudge Mobile • Cyber-Zen',
                style: TextStyle(
                  fontSize: 10.5,
                  color: colors.textMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                'v1.0.0',
                style: TextStyle(
                  fontSize: 10.5,
                  color: colors.textMuted,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
