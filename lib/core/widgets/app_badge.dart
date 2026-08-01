import 'package:flutter/material.dart';

import '../../app/constants/app_colors.dart';
import '../../app/constants/app_spacing.dart';

enum AppBadgeTone { neutral, success, warning, danger, info }

class AppBadge extends StatelessWidget {
  const AppBadge({
    super.key,
    required this.label,
    this.tone = AppBadgeTone.neutral,
  });

  final String label;
  final AppBadgeTone tone;

  factory AppBadge.status(String status) {
    final normalized = status.replaceAll('_', ' ').toUpperCase();
    final upper = status.toUpperCase();
    if (upper == 'PRESENT' || upper == 'IN_PROGRESS' || upper.contains('SUCCESS')) {
      return AppBadge(label: normalized, tone: AppBadgeTone.success);
    }
    if (upper == 'WRONG_VENUE' || upper == 'SCHEDULED' || upper == 'MAJOR') {
      return AppBadge(label: normalized, tone: AppBadgeTone.warning);
    }
    if (upper == 'ABSENT' || upper == 'CRITICAL' || upper == 'COMPLETED' || upper.contains('FAIL')) {
      return AppBadge(label: normalized, tone: AppBadgeTone.danger);
    }
    return AppBadge(label: normalized, tone: AppBadgeTone.neutral);
  }

  @override
  Widget build(BuildContext context) {
    late final Color background;
    late final Color foreground;

    switch (tone) {
      case AppBadgeTone.success:
        background = AppColors.brandGreen.withValues(alpha: 0.10);
        foreground = AppColors.brandGreen;
      case AppBadgeTone.warning:
        background = AppColors.brandGold.withValues(alpha: 0.15);
        foreground = const Color(0xFF92400E);
      case AppBadgeTone.danger:
        background = AppColors.brandRed.withValues(alpha: 0.10);
        foreground = AppColors.brandRed;
      case AppBadgeTone.info:
        background = AppColors.ink.withValues(alpha: 0.05);
        foreground = AppColors.ink;
      case AppBadgeTone.neutral:
        background = AppColors.surfaceMuted;
        foreground = AppColors.muted;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppSpacing.radius),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.4,
          height: 1.2,
          color: foreground,
        ),
      ),
    );
  }
}
