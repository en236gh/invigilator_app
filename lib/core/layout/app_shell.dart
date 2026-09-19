import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/constants/app_colors.dart';
import '../../app/constants/app_spacing.dart';
import '../../app/constants/app_typography.dart';
import '../../features/auth/application/auth_providers.dart';
import '../widgets/app_canvas.dart';
import 'app_sidebar.dart';

/// Authenticated app chrome: fixed sidebar + soft canvas main column.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    final width = MediaQuery.sizeOf(context).width;
    final showSidebar = width >= 900;
    final compactRail = width >= 720 && width < 900;

    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: showSidebar || compactRail
          ? null
          : Drawer(
              backgroundColor: AppColors.surface,
              child: AppSidebar(
                currentPath: path,
                onNavigate: () => Navigator.of(context).pop(),
              ),
            ),
      body: AppCanvas(
        child: Row(
          children: [
            if (showSidebar)
              AppSidebar(currentPath: path)
            else if (compactRail)
              AppSidebar(currentPath: path, compact: true),
            Expanded(
              child: Column(
                children: [
                  if (!showSidebar)
                    SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.pageHorizontal,
                          12,
                          AppSpacing.pageHorizontal,
                          0,
                        ),
                        child: Row(
                          children: [
                            if (!compactRail)
                              Builder(
                                builder: (context) => IconButton(
                                  onPressed: () => Scaffold.of(context).openDrawer(),
                                  icon: const Icon(Icons.menu, color: AppColors.ink),
                                  tooltip: 'Menu',
                                ),
                              ),
                            const Spacer(),
                            const _UserChip(),
                          ],
                        ),
                      ),
                    )
                  else
                    const SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          AppSpacing.pageHorizontal,
                          16,
                          AppSpacing.pageHorizontal,
                          0,
                        ),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: _UserChip(),
                        ),
                      ),
                    ),
                  Expanded(child: child),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserChip extends ConsumerWidget {
  const _UserChip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final displayName = user?.name ?? 'Invigilator';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(AppSpacing.radius),
        border: Border.all(color: AppColors.ink.withValues(alpha: 0.05)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSpacing.radius),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.brandGold, Color(0xFFF59E0B)],
              ),
            ),
            child: Text(
              displayName.isNotEmpty ? displayName[0].toUpperCase() : 'I',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            displayName,
            style: AppTypography.body.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}
