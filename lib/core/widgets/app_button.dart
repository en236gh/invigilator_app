import 'package:flutter/material.dart';

import '../../app/constants/app_colors.dart';
import '../../app/constants/app_spacing.dart';

enum AppButtonVariant { primary, secondary, ghost, danger }
enum AppButtonSize { sm, md, lg }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.md,
    this.icon,
    this.loading = false,
    this.expanded = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final IconData? icon;
  final bool loading;
  final bool expanded;

  double get _height {
    switch (size) {
      case AppButtonSize.sm:
        return 36;
      case AppButtonSize.md:
        return 44;
      case AppButtonSize.lg:
        return 48;
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;

    late final Color background;
    late final Color foreground;
    late final BorderSide side;

    switch (variant) {
      case AppButtonVariant.primary:
        background = AppColors.ink;
        foreground = Colors.white;
        side = BorderSide.none;
      case AppButtonVariant.secondary:
        background = AppColors.surface;
        foreground = AppColors.ink;
        side = BorderSide(color: AppColors.ink.withValues(alpha: 0.08));
      case AppButtonVariant.ghost:
        background = Colors.transparent;
        foreground = AppColors.ink;
        side = BorderSide.none;
      case AppButtonVariant.danger:
        background = const Color(0xFFB91C1C);
        foreground = Colors.white;
        side = BorderSide.none;
    }

    final labelStyle = TextStyle(
      fontWeight: FontWeight.w600,
      fontSize: size == AppButtonSize.sm ? 13 : 14,
      height: 1.2,
      color: foreground,
    );

    final child = loading
        ? SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: foreground,
            ),
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: foreground),
                const SizedBox(width: 8),
              ],
              if (expanded)
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: labelStyle,
                  ),
                )
              else
                Text(label, style: labelStyle),
            ],
          );

    final button = SizedBox(
      height: _height,
      width: expanded ? double.infinity : null,
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: background,
          foregroundColor: foreground,
          disabledBackgroundColor: background.withValues(alpha: 0.55),
          disabledForegroundColor: foreground.withValues(alpha: 0.7),
          side: side,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radius),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        child: child,
      ),
    );

    return button;
  }
}
