import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/constants/app_spacing.dart';
import '../../../app/constants/app_typography.dart';
import '../../../core/widgets/app_canvas.dart';
import '../../../core/widgets/app_error_banner.dart';
import '../../../core/widgets/app_panel.dart';
import '../../../app/constants/app_colors.dart';
import '../domain/exam_assignment.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../application/exam_providers.dart';
import '../application/session_flow_controller.dart';
import 'widgets/dashboard_exam_card.dart';
import 'widgets/session_flow_view.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flow = ref.watch(sessionFlowProvider);
    if (flow.loading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.black),
      );
    }
    if (flow.flow != null) {
      return RefreshIndicator(
        onRefresh: () => ref.read(examAssignmentsProvider.notifier).refresh(),
        child: SessionFlowView(
          key: ValueKey(
            '${flow.owner}/${flow.flow!.assignment.examSessionId}/${flow.flow!.assignment.venueId}',
          ),
          controller: flow,
          onFinished: () {
            if (!context.mounted) return;
            ref.read(selectedExamProvider.notifier).clear();
            ref.read(examAssignmentsProvider.notifier).refresh();
          },
        ),
      );
    }
    if (flow.error != null) {
      return AppPageBody(
        onRefresh: flow.restore,
        child: AppErrorBanner(message: flow.error!, onRetry: flow.restore),
      );
    }
    final assignments = ref.watch(examAssignmentsProvider);

    Future<void> refresh() =>
        ref.read(examAssignmentsProvider.notifier).refresh();
    return AppPageBody(
      onRefresh: refresh,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _greeting(DateTime.now()),
                  style: AppTypography.cardTitle.copyWith(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  "Here's your examination schedule for today.",
                  style: AppTypography.description,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          assignments.when(
            loading: () => const AppPageSkeleton(showMetrics: false),
            error: (_, _) => AppErrorBanner(
              message:
                  'Could not load assigned exams. Check your connection and retry.',
              onRetry: refresh,
            ),
            data: (exams) {
              final now = DateTime.now();
              final ordered = [...exams]
                ..sort((a, b) {
                  final priority = _priority(
                    a,
                    now,
                  ).compareTo(_priority(b, now));
                  if (priority != 0) return priority;
                  return '${a.examDate} ${a.startTime}'.compareTo(
                    '${b.examDate} ${b.startTime}',
                  );
                });
              final next = ordered.isEmpty ? null : ordered.first;
              final todayCount = exams
                  .where((exam) => _isToday(exam, now))
                  .length;
              void open(ExamAssignment exam) {
                ref.read(selectedExamProvider.notifier).select(exam);
                context.push(
                  exam.isCompleted ? '/attendance' : '/verification',
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text("Today's Exams", style: AppTypography.cardTitle),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    todayCount == 0
                        ? 'No exams scheduled for today.'
                        : '$todayCount ${todayCount == 1 ? 'exam' : 'exams'} on your schedule today.',
                    style: AppTypography.description,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (next == null)
                    const AppPanel(
                      child: Column(
                        children: [
                          Icon(
                            Icons.event_available_outlined,
                            size: 32,
                            color: AppColors.muted,
                          ),
                          SizedBox(height: AppSpacing.md),
                          Text(
                            'No exams assigned',
                            style: AppTypography.bodyStrong,
                          ),
                          SizedBox(height: AppSpacing.xs),
                          Text(
                            'Your assigned exams will appear here.',
                            style: AppTypography.description,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  else
                    DashboardExamCard(exam: next, onOpen: () => open(next)),
                  const SizedBox(height: AppSpacing.xl),
                  AppPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Quick Actions',
                          style: AppTypography.cardTitle,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final actions = [
                              _QuickAction(
                                icon: Icons.report_problem_outlined,
                                label: 'Incidents',
                                description: 'Report or view incidents',
                                onTap: () {
                                  if (next != null) {
                                    ref
                                        .read(selectedExamProvider.notifier)
                                        .select(next);
                                  }
                                  context.push('/incidents');
                                },
                              ),
                              _QuickAction(
                                icon: Icons.play_arrow_rounded,
                                label: 'Start Exam Session',
                                description:
                                    next != null && _readyToStart(next, now)
                                    ? 'Confirm attendance and start'
                                    : 'Available for a scheduled exam today',
                                onTap:
                                    next != null &&
                                        _readyToStart(next, now) &&
                                        !flow.busy
                                    ? () => _startSession(context, ref, next)
                                    : null,
                              ),
                            ];
                            if (constraints.maxWidth < 280 ||
                                MediaQuery.textScalerOf(context).scale(14) >
                                    21) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  actions[0],
                                  const SizedBox(height: AppSpacing.md),
                                  actions[1],
                                ],
                              );
                            }
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: actions[0]),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(child: actions[1]),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  if (ordered.length > 1) ...[
                    const SizedBox(height: AppSpacing.xl),
                    const Text(
                      'More Assigned Exams',
                      style: AppTypography.cardTitle,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    for (final exam in ordered.skip(1)) ...[
                      DashboardExamCard(
                        exam: exam,
                        prominent: false,
                        onOpen: () => open(exam),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

String _greeting(DateTime now) => now.hour < 12
    ? 'Good morning 👋'
    : now.hour < 17
    ? 'Good afternoon 👋'
    : 'Good evening 👋';

bool _isToday(ExamAssignment exam, DateTime now) {
  final date = DateTime.tryParse(exam.examDate);
  return date != null &&
      date.year == now.year &&
      date.month == now.month &&
      date.day == now.day;
}

bool _readyToStart(ExamAssignment exam, DateTime now) {
  if (!exam.isScheduled || !_isToday(exam, now)) return false;
  final end = DateTime.tryParse(
    '${exam.examDate.split('T').first}T${exam.endTime}',
  );
  return end == null || now.isBefore(end);
}

int _priority(ExamAssignment exam, DateTime now) {
  if (exam.isInProgress) return 0;
  if (exam.isCompleted) return 4;
  if (_isToday(exam, now) && (!exam.isScheduled || _readyToStart(exam, now))) {
    return 1;
  }
  final date = DateTime.tryParse(exam.examDate);
  if (date != null && date.isAfter(now)) return 2;
  return 3;
}

Future<void> _startSession(
  BuildContext context,
  WidgetRef ref,
  ExamAssignment exam,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Start exam session?'),
      content: Text(
        'Have you finished recording attendance for all students in ${exam.courseCode} at ${exam.venueName}?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('No'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Yes, start session'),
        ),
      ],
    ),
  );
  if (!context.mounted) return;
  if (confirmed != true) {
    if (confirmed == false) {
      ref.read(selectedExamProvider.notifier).select(exam);
      context.push('/verification');
    }
    return;
  }
  final assignments = ref.read(examAssignmentsProvider).asData?.value;
  final current = assignments?.where((item) => item.sameAs(exam)).firstOrNull;
  final flow = ref.read(sessionFlowProvider);
  if (current == null ||
      !_readyToStart(current, DateTime.now()) ||
      flow.flow != null ||
      flow.busy) {
    return;
  }
  ref.read(selectedExamProvider.notifier).select(current);
  await flow.start(current);
  if (!context.mounted) return;
  if (flow.flow?.step == SessionStep.running) {
    ref
        .read(selectedExamProvider.notifier)
        .select(current.copyWith(examStatus: 'IN_PROGRESS'));
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.description,
    this.onTap,
  });
  final IconData icon;
  final String label;
  final String description;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onTap != null,
    child: Material(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(AppSpacing.radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radius),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                size: 26,
                color: onTap == null ? AppColors.muted : AppColors.ink,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                label,
                style: AppTypography.bodyStrong.copyWith(
                  color: onTap == null ? AppColors.muted : AppColors.ink,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(description, style: AppTypography.caption),
            ],
          ),
        ),
      ),
    ),
  );
}
