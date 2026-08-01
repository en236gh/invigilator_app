import 'package:flutter/material.dart';

import '../../../../app/constants/app_colors.dart';
import '../../../../app/constants/app_spacing.dart';
import '../../../../app/constants/app_typography.dart';
import '../../../../core/widgets/app_badge.dart';
import '../../../../core/widgets/app_panel.dart';
import '../../domain/exam_assignment.dart';

/// Horizontal carousel of assigned exams. Tap a card to select it.
class ExamAssignmentCarousel extends StatelessWidget {
  const ExamAssignmentCarousel({
    super.key,
    required this.assignments,
    required this.selected,
    required this.onSelect,
  });

  final List<ExamAssignment> assignments;
  final ExamAssignment? selected;
  final ValueChanged<ExamAssignment> onSelect;

  @override
  Widget build(BuildContext context) {
    if (assignments.isEmpty) {
      return const AppPanel(
        minHeight: 140,
        child: Center(
          child: Text(
            'No exam assignments yet. Ask an administrator to assign you to a venue.',
            textAlign: TextAlign.center,
            style: AppTypography.description,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 132,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: assignments.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.grid),
            itemBuilder: (context, index) {
              final assignment = assignments[index];
              final isSelected = assignment.sameAs(selected);
              return SizedBox(
                width: 260,
                child: _ExamCarouselCard(
                  assignment: assignment,
                  selected: isSelected,
                  onTap: () => onSelect(assignment),
                ),
              );
            },
          ),
        ),
        if (selected == null) ...[
          const SizedBox(height: AppSpacing.md),
          const Text(
            'Select an exam to unlock scripts, verification, attendance, and incidents.',
            style: AppTypography.caption,
          ),
        ],
      ],
    );
  }
}

class _ExamCarouselCard extends StatelessWidget {
  const _ExamCarouselCard({
    required this.assignment,
    required this.selected,
    required this.onTap,
  });

  final ExamAssignment assignment;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final meta = assignment.building.isNotEmpty
        ? '${assignment.building} · ${assignment.timeRangeLabel}'
        : assignment.timeRangeLabel;

    return AppPanel(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      borderColor: selected ? AppColors.ink : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  assignment.courseCode,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.cardTitle,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              AppBadge.status(assignment.examStatus),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            assignment.venueName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.captionStrong,
          ),
          const SizedBox(height: 2),
          Text(
            meta,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.caption,
          ),
          const Spacer(),
          Row(
            children: [
              Icon(
                selected ? Icons.check_circle : Icons.radio_button_unchecked,
                size: 15,
                color: selected ? AppColors.brandGreen : AppColors.muted,
              ),
              const SizedBox(width: 6),
              Text(
                selected ? 'Selected' : 'Tap to select',
                style: AppTypography.caption.copyWith(
                  color: selected ? AppColors.brandGreen : AppColors.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
