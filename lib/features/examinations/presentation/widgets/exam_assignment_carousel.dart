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
        minHeight: 180,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.event_busy_outlined, size: 28, color: AppColors.muted),
              SizedBox(height: AppSpacing.md),
              Text('No exams assigned', style: AppTypography.bodyStrong),
              SizedBox(height: AppSpacing.xs),
              Text(
                'Contact your administrator for an assignment.',
                textAlign: TextAlign.center,
                style: AppTypography.description,
              ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600) {
          return _PhoneExamPager(
            assignments: assignments,
            selected: selected,
            onSelect: onSelect,
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 192,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: assignments.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: AppSpacing.grid),
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
          ],
        );
      },
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
    return AppPanel(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
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
          _ExamDetailRow(
            icon: Icons.place_outlined,
            label: assignment.venueName,
            maxLines: 1,
          ),
          if (assignment.building.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            _ExamDetailRow(
              icon: Icons.apartment_outlined,
              label: assignment.building,
              maxLines: 1,
            ),
          ],
          const SizedBox(height: AppSpacing.xs),
          _ExamDetailRow(
            icon: Icons.schedule_outlined,
            label: assignment.timeRangeLabel,
            maxLines: 1,
          ),
          const SizedBox(height: AppSpacing.xs),
          _ExamDetailRow(
            icon: Icons.people_outline,
            label: assignment.studentCount == null
                ? 'Expected attendance: Not available'
                : 'Expected attendance: ${assignment.studentCount}',
            maxLines: 1,
          ),
          const Spacer(),
          Row(
            children: [
              Icon(
                selected ? Icons.check_circle : Icons.touch_app_outlined,
                size: 16,
                color: selected ? AppColors.ink : AppColors.muted,
              ),
              const SizedBox(width: 6),
              Text(
                'Select exam',
                style: AppTypography.caption.copyWith(
                  color: AppColors.muted,
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

/// Natural-height pages keep long details and larger text fully readable.
class _PhoneExamPager extends StatefulWidget {
  const _PhoneExamPager({
    required this.assignments,
    required this.selected,
    required this.onSelect,
  });
  final List<ExamAssignment> assignments;
  final ExamAssignment? selected;
  final ValueChanged<ExamAssignment> onSelect;

  @override
  State<_PhoneExamPager> createState() => _PhoneExamPagerState();
}

class _PhoneExamPagerState extends State<_PhoneExamPager> {
  late int _page;
  late final ScrollController _controller;
  double? _pageWidth;

  @override
  void initState() {
    super.initState();
    final selectedIndex = widget.assignments.indexWhere(
      (exam) => exam.sameAs(widget.selected),
    );
    _page = selectedIndex < 0 ? 0 : selectedIndex;
    _controller = ScrollController();
  }

  @override
  void didUpdateWidget(covariant _PhoneExamPager oldWidget) {
    super.didUpdateWidget(oldWidget);
    final visible =
        oldWidget.assignments[_page.clamp(0, oldWidget.assignments.length - 1)];
    final index = widget.assignments.indexWhere((exam) => exam.sameAs(visible));
    final next = index < 0 ? 0 : index;
    if (next != _page) {
      _page = next;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _controller.hasClients) {
          _controller.jumpTo(_page * _pageWidth!);
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (_pageWidth != constraints.maxWidth) {
          _pageWidth = constraints.maxWidth;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _controller.hasClients) {
              _controller.jumpTo(_page * _pageWidth!);
            }
          });
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            NotificationListener<ScrollEndNotification>(
              onNotification: (notification) {
                if (notification.depth == 0 &&
                    notification.metrics.axis == Axis.horizontal) {
                  final page =
                      (notification.metrics.pixels / constraints.maxWidth)
                          .round()
                          .clamp(0, widget.assignments.length - 1);
                  if (page != _page) setState(() => _page = page);
                }
                return false;
              },
              child: SingleChildScrollView(
                controller: _controller,
                scrollDirection: Axis.horizontal,
                physics: const PageScrollPhysics(),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final exam in widget.assignments)
                      SizedBox(
                        width: constraints.maxWidth,
                        child: _PhoneExamCard(
                          assignment: exam,
                          selected: exam.sameAs(widget.selected),
                          onTap: () => widget.onSelect(exam),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (widget.assignments.length > 1) ...[
              const SizedBox(height: 8),
              Semantics(
                label: 'Exam ${_page + 1} of ${widget.assignments.length}',
                liveRegion: true,
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (
                      var index = 0;
                      index < widget.assignments.length;
                      index++
                    )
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                        width: index == _page ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: index == _page
                              ? AppColors.ink
                              : AppColors.ink.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _PhoneExamCard extends StatelessWidget {
  const _PhoneExamCard({
    required this.assignment,
    required this.selected,
    required this.onTap,
  });
  final ExamAssignment assignment;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: AppPanel(
        padding: const EdgeInsets.all(AppSpacing.lg),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                Text(assignment.courseCode, style: AppTypography.cardTitle),
                AppBadge.status(assignment.examStatus),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            _ExamDetailRow(
              icon: Icons.place_outlined,
              label: assignment.venueName,
              emphasized: true,
            ),
            if (assignment.building.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              _ExamDetailRow(
                icon: Icons.apartment_outlined,
                label: assignment.building,
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            _ExamDetailRow(
              icon: Icons.schedule_outlined,
              label: assignment.timeRangeLabel,
              emphasized: true,
            ),
            const SizedBox(height: AppSpacing.sm),
            _ExamDetailRow(
              icon: Icons.people_outline,
              label: assignment.studentCount == null
                  ? 'Expected attendance: Not available'
                  : 'Expected attendance: ${assignment.studentCount}',
            ),
            const SizedBox(height: AppSpacing.lg),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    selected ? Icons.check_circle : Icons.touch_app_outlined,
                    size: 18,
                    color: AppColors.ink,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Tap to select',
                      style: AppTypography.captionStrong,
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

class _ExamDetailRow extends StatelessWidget {
  const _ExamDetailRow({
    required this.icon,
    required this.label,
    this.maxLines,
    this.emphasized = false,
  });

  final IconData icon;
  final String label;
  final int? maxLines;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 16, color: AppColors.muted),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            label,
            maxLines: maxLines,
            overflow: maxLines == null ? null : TextOverflow.ellipsis,
            style: emphasized
                ? AppTypography.captionStrong
                : AppTypography.caption,
          ),
        ),
      ],
    );
  }
}
