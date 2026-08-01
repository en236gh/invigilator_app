import 'package:flutter/material.dart';

import '../../app/constants/app_colors.dart';
import '../../app/constants/app_shadows.dart';
import '../../app/constants/app_spacing.dart';

/// White content panel with soft institutional shadow.
class AppPanel extends StatelessWidget {
  const AppPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.panel),
    this.margin,
    this.onTap,
    this.borderColor,
    this.minHeight,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? borderColor;
  final double? minHeight;

  @override
  Widget build(BuildContext context) {
    final panel = Container(
      constraints: minHeight != null ? BoxConstraints(minHeight: minHeight!) : null,
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radius),
        border: Border.all(
          color: borderColor ?? AppColors.ink.withValues(alpha: 0.04),
        ),
        boxShadow: AppShadows.panel,
      ),
      child: child,
    );

    if (onTap == null) return panel;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radius),
        child: panel,
      ),
    );
  }
}
