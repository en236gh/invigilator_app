import '../../features/offline/presentation/offline_download_popup.dart';
import '../../features/examinations/application/session_flow_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/constants/app_colors.dart';
import '../../app/constants/app_spacing.dart';
import '../../app/constants/app_typography.dart';
import '../../features/auth/application/auth_providers.dart';
import '../../features/auth/data/auth_repository.dart';
import '../widgets/app_canvas.dart';
import 'app_sidebar.dart';

/// Authenticated app chrome: fixed sidebar + soft canvas main column.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionFlowProvider);
    final sessionActive = session.loading || session.flow != null;
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
                                  onPressed: () =>
                                      Scaffold.of(context).openDrawer(),
                                  icon: const Icon(
                                    Icons.menu,
                                    color: AppColors.ink,
                                  ),
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
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        child,
                        if (path == '/' && !sessionActive)
                          const DashboardDownloadOverlay(),
                      ],
                    ),
                  ),
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
    return PopupMenuButton<String>(
      tooltip: 'Account options',
      onSelected: (value) async {
        if (value == 'sign-out') {
          await AuthRepository().logout();
          ref.read(currentUserProvider.notifier).clear();
          if (context.mounted) context.go('/login');
        } else {
          if (!context.mounted) return;
          showModalBottomSheet<void>(
            context: context,
            showDragHandle: true,
            builder: (_) => SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Account', style: AppTypography.cardTitle),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      user?.name ?? 'Invigilator',
                      style: AppTypography.bodyStrong,
                    ),
                    if (user?.email != null)
                      Text(user!.email!, style: AppTypography.description),
                    const SizedBox(height: AppSpacing.sm),
                    const Text(
                      'Role: Invigilator',
                      style: AppTypography.description,
                    ),
                  ],
                ),
              ),
            ),
          );
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'account', child: Text('Account details')),
        PopupMenuItem(value: 'sign-out', child: Text('Sign out')),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radius),
          border: Border.all(color: AppColors.ink.withValues(alpha: 0.05)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: AppColors.surfaceMuted,
              child: Text(
                'I',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
            ),
            SizedBox(width: 8),
            Text('Invigilator', style: AppTypography.captionStrong),
            SizedBox(width: 4),
            Icon(Icons.expand_more, size: 16, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}
