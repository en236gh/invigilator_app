import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/constants/app_colors.dart';
import '../../../app/constants/app_spacing.dart';
import '../../../app/constants/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_canvas.dart';
import '../../../core/widgets/app_error_banner.dart';
import '../../../core/widgets/app_metric_tile.dart';
import '../../../core/widgets/app_page_header.dart';
import '../../../core/widgets/app_panel.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../attendance/data/attendance_repository.dart';
import '../application/exam_providers.dart';
import '../domain/exam_assignment.dart';
import 'widgets/exam_assignment_carousel.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final AttendanceRepository _attendanceRepo = AttendanceRepository();
  final TextEditingController _scriptsCollectedController =
      TextEditingController();

  bool _sessionActionInProgress = false;
  bool _savingScripts = false;
  bool _loadingScripts = false;
  String? _error;
  Map<String, dynamic> _summary = {};
  int _scriptsCollected = 0;
  int? _scriptsExamSessionId;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadSummary);
  }

  @override
  void dispose() {
    _scriptsCollectedController.dispose();
    super.dispose();
  }

  Future<void> _loadSummary() async {
    try {
      final summary = await ref
          .read(examRepositoryProvider)
          .getDashboardSummary();
      if (!mounted) return;
      setState(() {
        _summary = summary;
      });
    } catch (_) {
      // Summary is secondary; assignments drive the main UI.
    }
  }

  Future<void> _loadScriptsFor(ExamAssignment? assignment) async {
    if (assignment == null) {
      setState(() {
        _scriptsCollected = 0;
        _scriptsExamSessionId = null;
        _scriptsCollectedController.text = '';
        _loadingScripts = false;
      });
      return;
    }

    setState(() {
      _loadingScripts = true;
    });

    try {
      final attendanceSummary = await _attendanceRepo.fetchAttendanceSummary(
        examSessionId: assignment.examSessionId,
      );
      if (!mounted) return;
      final selected = ref.read(selectedExamProvider);
      if (selected?.examSessionId != assignment.examSessionId) return;
      setState(() {
        _scriptsCollected = attendanceSummary.scriptsCollected;
        _scriptsExamSessionId = assignment.examSessionId;
        _scriptsCollectedController.text =
            '${attendanceSummary.scriptsCollected}';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _scriptsCollected = 0;
        _scriptsExamSessionId = assignment.examSessionId;
        _scriptsCollectedController.text = '0';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingScripts = false;
        });
      }
    }
  }

  Future<void> _refreshDashboard() async {
    setState(() {
      _error = null;
    });
    await Future.wait([
      ref.read(examAssignmentsProvider.notifier).refresh(),
      _loadSummary(),
    ]);
    if (!mounted) return;
    await _loadScriptsFor(ref.read(selectedExamProvider));
  }

  Future<void> _saveScriptsCollected() async {
    final assignment = ref.read(selectedExamProvider);
    if (assignment == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select an exam before updating scripts.'),
        ),
      );
      return;
    }

    final count = int.tryParse(_scriptsCollectedController.text.trim()) ?? 0;
    if (count < 0) {
      setState(() {
        _error = 'Scripts collected must be zero or higher.';
      });
      return;
    }

    setState(() {
      _savingScripts = true;
      _error = null;
    });

    try {
      await _attendanceRepo.markScriptsCollected(
        examSessionId: assignment.examSessionId,
        count: count,
      );
      if (!mounted) return;
      setState(() {
        _scriptsCollected = count;
        _scriptsCollectedController.text = '$count';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Scripts collected updated.')),
      );
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = _friendlyError(error);
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _savingScripts = false;
        });
      }
    }
  }

  Future<void> _startSelectedSession() async {
    final assignment = ref.read(selectedExamProvider);
    if (assignment == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select an exam before starting a session.'),
        ),
      );
      return;
    }

    if (assignment.isInProgress) {
      context.go('/verification');
      return;
    }

    if (!assignment.isScheduled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${assignment.courseCode} is ${assignment.statusLabel.toLowerCase()} and cannot be started.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _sessionActionInProgress = true;
      _error = null;
    });

    try {
      await ref
          .read(examRepositoryProvider)
          .startSession(
            examSessionId: assignment.examSessionId,
            venueId: assignment.venueId,
          );
      await ref.read(examAssignmentsProvider.notifier).refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${assignment.courseCode} at ${assignment.venueName} is now in progress.',
          ),
        ),
      );
      context.go('/verification');
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = _friendlyError(error);
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _sessionActionInProgress = false;
        });
      }
    }
  }

  Future<void> _endSelectedSession() async {
    final assignment = ref.read(selectedExamProvider);
    if (assignment == null || !assignment.isInProgress) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End examination session?'),
        content: Text(
          'End ${assignment.courseCode} at ${assignment.venueName}? Allocated students without attendance will be marked ABSENT, and check-in will be blocked.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('End session'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _sessionActionInProgress = true;
      _error = null;
    });

    try {
      await ref
          .read(examRepositoryProvider)
          .endSession(
            examSessionId: assignment.examSessionId,
            venueId: assignment.venueId,
          );
      await ref.read(examAssignmentsProvider.notifier).refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${assignment.courseCode} session ended.')),
      );
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = _friendlyError(error);
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _sessionActionInProgress = false;
        });
      }
    }
  }

  String _friendlyError(Object error) {
    if (error is DioException) {
      if (error.response?.statusCode == 401) {
        return 'Please sign in again to refresh your session.';
      }
      if (error.response?.statusCode == 400 ||
          error.response?.statusCode == 409) {
        final serverMessage = error.response?.data is Map
            ? '${(error.response!.data as Map)['message'] ?? (error.response!.data as Map)['error'] ?? ''}'
            : '';
        if (serverMessage.isNotEmpty) return serverMessage;
        return 'We could not update the exam session right now. Please try again.';
      }
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout) {
        return 'Connection timed out. Check your network and tap retry.';
      }
      if (error.type == DioExceptionType.badResponse) {
        return 'Server returned an unexpected response. Please try again later.';
      }
      return 'Unable to load the dashboard. Please refresh to try again.';
    }

    return 'Something went wrong. Please refresh the screen.';
  }

  String get _startActionTitle {
    final assignment = ref.read(selectedExamProvider);
    if (assignment == null) return 'Start session';
    if (assignment.isInProgress) return 'Continue session';
    if (assignment.isScheduled) return 'Start session';
    return 'Open verification';
  }

  String get _startActionSubtitle {
    final assignment = ref.read(selectedExamProvider);
    if (assignment == null) return 'Select an exam first';
    if (assignment.isInProgress) return 'Resume student verification';
    if (assignment.isScheduled)
      return 'Mark ${assignment.courseCode} in progress';
    return 'Review verification for this venue';
  }

  Widget _buildScriptsPanel(ExamAssignment? assignment) {
    final enabled = assignment != null && !_savingScripts && !_loadingScripts;

    return Opacity(
      opacity: assignment == null ? 0.45 : 1,
      child: IgnorePointer(
        ignoring: assignment == null,
        child: AppPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Scripts collected',
                      style: AppTypography.bodyStrong,
                    ),
                  ),
                  Text(
                    assignment == null ? '—' : '$_scriptsCollected',
                    style: AppTypography.metricValue.copyWith(
                      fontSize: 44,
                      letterSpacing: -0.8,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                assignment == null
                    ? 'Select an assigned exam above to record scripts for that session.'
                    : 'Update collected scripts for ${assignment.courseCode} at ${assignment.venueName}.',
                style: AppTypography.description,
              ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _scriptsCollectedController,
                keyboardType: TextInputType.number,
                enabled: enabled,
                decoration: const InputDecoration(
                  labelText: 'Number of collected scripts',
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: 'Save scripts count',
                loading: _savingScripts,
                onPressed: enabled ? _saveScriptsCollected : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActions(ExamAssignment? selected) {
    final tiles = <Widget>[
      AppActionTile(
        title: _startActionTitle,
        subtitle: _startActionSubtitle,
        icon: Icons.play_circle_outline,
        enabled: selected != null && !_sessionActionInProgress,
        onTap: () {
          if (selected == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Select an exam first.')),
            );
            return;
          }
          if (selected.isScheduled) {
            _startSelectedSession();
            return;
          }
          context.go('/verification');
        },
      ),
      if (selected?.isInProgress == true)
        AppActionTile(
          title: 'End session',
          subtitle: 'Close check-in and mark remaining absences',
          icon: Icons.stop_circle_outlined,
          enabled: !_sessionActionInProgress,
          onTap: _endSelectedSession,
        ),
      AppActionTile(
        title: 'Attendance register',
        subtitle: selected == null
            ? 'Select an exam first'
            : 'Open the attendance list',
        icon: Icons.list_alt_outlined,
        enabled: selected != null,
        onTap: () => context.go('/attendance'),
      ),
      AppActionTile(
        title: 'Report incident',
        subtitle: selected == null
            ? 'Select an exam first'
            : 'Record an issue quickly',
        icon: Icons.report_outlined,
        enabled: selected != null,
        onTap: () => context.go('/incidents'),
      ),
    ];

    return SizedBox(
      height: 168,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: tiles.length,
        separatorBuilder: (context, index) =>
            const SizedBox(width: AppSpacing.grid),
        itemBuilder: (context, index) {
          return SizedBox(width: 240, child: tiles[index]);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final assignmentsAsync = ref.watch(examAssignmentsProvider);
    final selected = ref.watch(selectedExamProvider);

    ref.listen<ExamAssignment?>(selectedExamProvider, (previous, next) {
      if (previous?.examSessionId == next?.examSessionId &&
          previous?.venueId == next?.venueId &&
          _scriptsExamSessionId == next?.examSessionId) {
        return;
      }
      _loadScriptsFor(next);
    });

    return RefreshIndicator(
      onRefresh: _refreshDashboard,
      child: AppPageBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppPageHeader(
              title: 'Dashboard',
              subtitle:
                  'Select your assigned exam, then manage scripts and the session.',
              trailing: IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _refreshDashboard,
                tooltip: 'Refresh',
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            assignmentsAsync.when(
              loading: () => const AppPageSkeleton(showMetrics: false),
              error: (error, _) => AppPanel(
                minHeight: 280,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _friendlyError(error),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppColors.brandRed,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    SizedBox(
                      width: 160,
                      child: AppButton(
                        label: 'Retry',
                        expanded: true,
                        onPressed: _refreshDashboard,
                      ),
                    ),
                  ],
                ),
              ),
              data: (assignments) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_error != null) ...[
                      AppErrorBanner(
                        message: _error!,
                        onRetry: _refreshDashboard,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                    const AppSectionHeader(
                      title: 'Assigned exams',
                      subtitle: 'Choose the exam you are invigilating now.',
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    ExamAssignmentCarousel(
                      assignments: assignments,
                      selected: selected,
                      onSelect: (assignment) {
                        ref
                            .read(selectedExamProvider.notifier)
                            .select(assignment);
                      },
                    ),
                    const SizedBox(height: AppSpacing.section),
                    _buildScriptsPanel(selected),
                    const SizedBox(height: AppSpacing.section),
                    const AppSectionHeader(
                      title: 'Quick actions',
                      subtitle:
                          'Start the exam before verifying students. Ending a session closes check-in.',
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _buildQuickActions(selected),
                    const SizedBox(height: AppSpacing.section),
                    AppPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Current selection',
                            style: AppTypography.bodyStrong,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            selected == null
                                ? '${_summary['currentSession'] ?? 'No exam selected'}'
                                : '${selected.courseCode} · ${selected.venueName} · ${selected.statusLabel}',
                            style: AppTypography.description,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          const Text(
                            'Next step',
                            style: AppTypography.bodyStrong,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            selected == null
                                ? 'Select an assigned exam to unlock scripts and the rest of the workflow.'
                                : selected.isScheduled
                                ? 'Start the session, then open verification to check students in.'
                                : selected.isInProgress
                                ? 'Continue verification, or open the attendance register to review check-ins.'
                                : 'Open the attendance register for the latest student list and check-in status.',
                            style: AppTypography.description,
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
