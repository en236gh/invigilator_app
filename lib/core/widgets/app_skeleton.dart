import 'package:flutter/material.dart';

import '../../app/constants/app_colors.dart';
import '../../app/constants/app_spacing.dart';

/// Soft shimmer skeleton block used while page data loads.
class AppSkeleton extends StatefulWidget {
  const AppSkeleton({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius = AppSpacing.radius,
  });

  final double? width;
  final double height;
  final double borderRadius;

  @override
  State<AppSkeleton> createState() => _AppSkeletonState();
}

class _AppSkeletonState extends State<AppSkeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  late final Animation<double> _opacity = Tween<double>(begin: 0.45, end: 0.9).animate(
    CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(widget.borderRadius),
        ),
      ),
    );
  }
}

class AppSkeletonTile extends StatelessWidget {
  const AppSkeletonTile({super.key, this.minHeight = 148});

  /// Retained for call-site compatibility; grid cells set the actual height.
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minHeight: minHeight),
      padding: const EdgeInsets.all(AppSpacing.panel),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radius),
        border: Border.all(color: AppColors.ink.withValues(alpha: 0.04)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSkeleton(width: 88, height: 12),
          Spacer(),
          AppSkeleton(width: 64, height: 32),
        ],
      ),
    );
  }
}

/// Standard dashboard / list loading layout.
class AppPageSkeleton extends StatelessWidget {
  const AppPageSkeleton({
    super.key,
    this.showMetrics = true,
    this.metricCount = 4,
    this.showPanel = true,
  });

  final bool showMetrics;
  final int metricCount;
  final bool showPanel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showMetrics)
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 900
                  ? 4
                  : constraints.maxWidth >= 600
                      ? 2
                      : 1;
              return GridView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: AppSpacing.grid,
                  mainAxisSpacing: AppSpacing.grid,
                  mainAxisExtent: 148,
                ),
                children: List.generate(metricCount, (_) => const AppSkeletonTile()),
              );
            },
          ),
        if (showMetrics && showPanel) const SizedBox(height: AppSpacing.xl),
        if (showPanel)
          Container(
            padding: const EdgeInsets.all(AppSpacing.panel),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppSpacing.radius),
              border: Border.all(color: AppColors.ink.withValues(alpha: 0.04)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppSkeleton(width: 160, height: 18),
                SizedBox(height: AppSpacing.lg),
                AppSkeleton(height: 14),
                SizedBox(height: AppSpacing.sm),
                AppSkeleton(width: 220, height: 14),
                SizedBox(height: AppSpacing.xl),
                AppSkeleton(height: 48),
                SizedBox(height: AppSpacing.md),
                AppSkeleton(height: 48),
                SizedBox(height: AppSpacing.md),
                AppSkeleton(width: 180, height: 48),
              ],
            ),
          ),
      ],
    );
  }
}

class AppListSkeleton extends StatelessWidget {
  const AppListSkeleton({super.key, this.rows = 5});

  final int rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(rows, (index) {
        return Padding(
          padding: EdgeInsets.only(bottom: index == rows - 1 ? 0 : AppSpacing.md),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppSpacing.radius),
              border: Border.all(color: AppColors.ink.withValues(alpha: 0.04)),
            ),
            child: const Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppSkeleton(width: 140, height: 14),
                      SizedBox(height: AppSpacing.sm),
                      AppSkeleton(width: 100, height: 12),
                    ],
                  ),
                ),
                SizedBox(width: AppSpacing.lg),
                Expanded(child: AppSkeleton(height: 14)),
                SizedBox(width: AppSpacing.lg),
                AppSkeleton(width: 72, height: 28),
              ],
            ),
          ),
        );
      }),
    );
  }
}
