import 'package:flutter/material.dart';

import '../../app/constants/app_colors.dart';
import '../../app/constants/app_spacing.dart';

class AppErrorBanner extends StatelessWidget {
  const AppErrorBanner({
    super.key,
    required this.message,
    this.onRetry,
  });

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.brandRed.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppSpacing.radius),
        border: Border.all(color: AppColors.brandRed.withValues(alpha: 0.14)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, size: 20, color: AppColors.brandRed),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 14, color: AppColors.brandRed, height: 1.4),
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(width: AppSpacing.md),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.ink,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              child: const Text('Retry'),
            ),
          ],
        ],
      ),
    );
  }
}

class AppInfoBanner extends StatelessWidget {
  const AppInfoBanner({
    super.key,
    required this.message,
    this.tone = AppInfoBannerTone.neutral,
  });

  final String message;
  final AppInfoBannerTone tone;

  @override
  Widget build(BuildContext context) {
    final Color background;
    final Color border;
    final Color foreground;

    switch (tone) {
      case AppInfoBannerTone.warning:
        background = AppColors.brandGold.withValues(alpha: 0.10);
        border = AppColors.brandGold.withValues(alpha: 0.18);
        foreground = AppColors.ink;
      case AppInfoBannerTone.success:
        background = AppColors.brandGreen.withValues(alpha: 0.08);
        border = AppColors.brandGreen.withValues(alpha: 0.16);
        foreground = AppColors.ink;
      case AppInfoBannerTone.live:
        background = AppColors.ink;
        border = AppColors.ink;
        foreground = Colors.white;
      case AppInfoBannerTone.neutral:
        background = AppColors.surfaceMuted;
        border = AppColors.ink.withValues(alpha: 0.06);
        foreground = AppColors.ink;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppSpacing.radius),
        border: Border.all(color: border),
      ),
      child: Text(message, style: TextStyle(fontSize: 14, color: foreground, height: 1.4)),
    );
  }
}

enum AppInfoBannerTone { neutral, warning, success, live }
