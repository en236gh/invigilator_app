import 'package:flutter/material.dart';

import '../../../../app/constants/app_colors.dart';
import '../../../../app/constants/app_spacing.dart';
import '../../../../app/constants/app_typography.dart';
import '../../../../core/widgets/app_badge.dart';
import '../../../../core/widgets/app_panel.dart';
import '../../domain/exam_assignment.dart';

String examScheduleLabel(ExamAssignment exam) {
  final date = DateTime.tryParse(exam.examDate);
  const weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  final day = date == null
      ? exam.examDate
      : '${weekdays[date.weekday - 1]}, ${date.day} ${months[date.month - 1]}';
  String time(String value) =>
      value.length >= 5 ? value.substring(0, 5) : value;
  if (exam.startTime.isEmpty) return day;
  return '$day • ${time(exam.startTime)}${exam.endTime.isEmpty ? '' : '–${time(exam.endTime)}'}';
}

class DashboardExamCard extends StatelessWidget {
  const DashboardExamCard({
    super.key,
    required this.exam,
    required this.onOpen,
    this.prominent = true,
  });

  final ExamAssignment exam;
  final VoidCallback onOpen;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    final scheduledEnd = DateTime.tryParse(
      '${exam.examDate.split('T').first}T${exam.endTime.isEmpty ? '23:59:59' : exam.endTime}',
    );
    final needsAttention =
        exam.isScheduled &&
        scheduledEnd != null &&
        DateTime.now().isAfter(scheduledEnd);
    final action = exam.isInProgress
        ? 'Continue Exam'
        : exam.isCompleted
        ? 'View Exam'
        : 'Open Exam';
    return AppPanel(
      padding: const EdgeInsets.all(AppSpacing.lg),
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (prominent) ...[
            Text(
              exam.isInProgress
                  ? 'CURRENT EXAM'
                  : exam.isCompleted
                  ? 'COMPLETED EXAM'
                  : 'NEXT EXAM',
              style: AppTypography.metricLabel,
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                exam.courseCode,
                style: AppTypography.cardTitle.copyWith(
                  fontSize: prominent ? 28 : 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              AppBadge.status(exam.examStatus),
              if (needsAttention)
                const AppBadge(
                  label: 'REQUIRES ATTENTION',
                  tone: AppBadgeTone.warning,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(AppSpacing.radius),
              border: Border.all(color: AppColors.surfaceMuted),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Detail(
                  icon: Icons.location_on_outlined,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(exam.venueName, style: AppTypography.bodyStrong),
                      if ((exam.campus ?? exam.building).isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          exam.campus ?? exam.building,
                          style: AppTypography.description,
                        ),
                      ],
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Divider(height: 1, color: AppColors.surfaceMuted),
                ),
                _Detail(
                  icon: Icons.schedule_outlined,
                  child: Text(
                    examScheduleLabel(exam),
                    style: AppTypography.description.copyWith(
                      color: AppColors.ink,
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Divider(height: 1, color: AppColors.surfaceMuted),
                ),
                _Detail(
                  icon: Icons.people_outline,
                  child: Text(
                    exam.studentCount != null
                        ? 'Students expected to attend: ${exam.studentCount}'
                        : 'Students expected to attend: Not available',
                    style: AppTypography.description.copyWith(
                      color: AppColors.ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (needsAttention) ...[
            const SizedBox(height: AppSpacing.md),
            const Text(
              'The scheduled time has passed. Open the exam to review its status.',
              style: AppTypography.description,
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: onOpen,
            style: FilledButton.styleFrom(
              backgroundColor: prominent
                  ? Colors.black
                  : AppColors.surfaceMuted,
              foregroundColor: prominent ? Colors.white : AppColors.ink,
              minimumSize: const Size.fromHeight(48),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radius),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(child: Text(action, textAlign: TextAlign.center)),
                const SizedBox(width: AppSpacing.sm),
                const Icon(Icons.arrow_forward, size: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.icon, required this.child});
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Icon(icon, size: 20, color: AppColors.muted),
      ),
      const SizedBox(width: AppSpacing.md),
      Expanded(child: child),
    ],
  );
}
