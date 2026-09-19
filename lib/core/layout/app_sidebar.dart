import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/constants/app_colors.dart';
import '../../app/constants/app_shadows.dart';
import '../../app/constants/app_spacing.dart';
import '../../features/auth/application/auth_providers.dart';
import '../../features/auth/data/auth_repository.dart';

class AppNavItem {
  const AppNavItem({
    required this.label,
    required this.path,
    required this.icon,
  });

  final String label;
  final String path;
  final IconData icon;
}

const List<AppNavItem> kAppNavItems = [
  AppNavItem(label: 'dashboard', path: '/', icon: Icons.dashboard_outlined),
  AppNavItem(label: 'verification', path: '/verification', icon: Icons.verified_user_outlined),
  AppNavItem(label: 'attendance', path: '/attendance', icon: Icons.fact_check_outlined),
  AppNavItem(label: 'incidents', path: '/incidents', icon: Icons.report_outlined),
  AppNavItem(label: 'sync', path: '/sync', icon: Icons.sync_outlined),
];

class AppSidebar extends ConsumerWidget {
  const AppSidebar({
    super.key,
    required this.currentPath,
    this.compact = false,
    this.onNavigate,
  });

  final String currentPath;
  final bool compact;
  final VoidCallback? onNavigate;

  bool _isActive(String path) {
    if (path == '/') return currentPath == '/';
    return currentPath == path || currentPath.startsWith('$path/');
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    await AuthRepository().logout();
    ref.read(currentUserProvider.notifier).clear();
    if (context.mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: compact ? 88 : AppSpacing.sidebarWidth,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.horizontal(right: Radius.circular(AppSpacing.radius)),
        boxShadow: AppShadows.sidebar,
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 12 : 20,
            vertical: 20,
          ),
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.symmetric(vertical: compact ? 8 : 12),
                child: Image.asset(
                  'assets/UNZA.png',
                  width: compact ? 48 : 144,
                  height: compact ? 48 : 144,
                  fit: BoxFit.contain,
                ),
              ),
              SizedBox(height: compact ? 16 : 28),
              Expanded(
                child: ListView(
                  children: [
                    for (final item in kAppNavItems)
                      _NavTile(
                        item: item,
                        active: _isActive(item.path),
                        compact: compact,
                        onTap: () {
                          if (currentPath != item.path) {
                            context.go(item.path);
                          }
                          onNavigate?.call();
                        },
                      ),
                  ],
                ),
              ),
              Align(
                alignment: compact ? Alignment.center : Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => _signOut(context, ref),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.muted,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  child: compact
                      ? const Icon(Icons.logout, size: 20)
                      : const Text('Sign out', style: TextStyle(fontWeight: FontWeight.w500)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.item,
    required this.active,
    required this.compact,
    required this.onTap,
  });

  final AppNavItem item;
  final bool active;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final background = active ? AppColors.ink : Colors.transparent;
    final foreground = active ? Colors.white : AppColors.muted;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.radius),
          hoverColor: AppColors.surfaceMuted,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 0 : 12,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(AppSpacing.radius),
              boxShadow: active ? AppShadows.navActive : null,
            ),
            child: compact
                ? Center(child: Icon(item.icon, size: 22, color: foreground))
                : Row(
                    children: [
                      Icon(item.icon, size: 22, color: foreground),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          item.label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: foreground,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
