import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/constants/app_colors.dart';
import '../../../app/constants/app_spacing.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_canvas.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_banner.dart';
import '../../../core/widgets/app_page_header.dart';
import '../../../core/widgets/app_panel.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../examinations/application/exam_providers.dart';
import '../../examinations/domain/exam_assignment.dart';
import '../data/attendance_repository.dart';
import '../domain/attendance_models.dart';

class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({super.key});

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen> {
  final AttendanceRepository _attendanceRepository = AttendanceRepository();

  bool _loading = false;
  bool _endingSession = false;
  String? _error;
  List<AttendanceRecord> _attendanceRecords = [];
  int? _loadedExamSessionId;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final selected = ref.read(selectedExamProvider);
      if (selected != null) {
        _refreshAttendance(selected);
      }
    });
  }

  Future<void> _endSession() async {
    final assignment = ref.read(selectedExamProvider);
    if (assignment == null || !assignment.isInProgress || _endingSession) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End examination session?'),
        content: const Text(
          'This marks the exam as completed and records ABSENT for allocated students with no attendance. Further check-ins will be blocked.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('End session')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _endingSession = true;
      _error = null;
    });

    try {
      await ref.read(examRepositoryProvider).endSession(
            examSessionId: assignment.examSessionId,
            venueId: assignment.venueId,
          );
      await ref.read(examAssignmentsProvider.notifier).refresh();
      await _refreshAttendance(ref.read(selectedExamProvider));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${assignment.courseCode} session ended. Remaining students marked absent.')),
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
          _endingSession = false;
        });
      }
    }
  }

  Future<void> _refreshAttendance(ExamAssignment? assignment) async {
    if (assignment == null) {
      setState(() {
        _attendanceRecords = [];
        _loadedExamSessionId = null;
        _loading = false;
        _error = null;
      });
      return;
    }

    setState(() {
      _error = null;
      _loading = true;
    });

    try {
      final records = await _attendanceRepository.fetchAttendanceForExam(
        examSessionId: assignment.examSessionId,
      );
      if (!mounted) return;
      final selected = ref.read(selectedExamProvider);
      if (selected?.examSessionId != assignment.examSessionId) return;
      setState(() {
        _attendanceRecords = records;
        _loadedExamSessionId = assignment.examSessionId;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = _friendlyError(error);
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  String _friendlyError(Object error) {
    if (error is String && error.isNotEmpty) {
      return error;
    }

    if (error is DioException) {
      if (error.response?.statusCode == 401) {
        return 'Please sign in again to refresh your session.';
      }
      if (error.response?.statusCode == 400 || error.response?.statusCode == 409) {
        final serverMessage = error.response?.data is Map
            ? '${(error.response!.data as Map)['message'] ?? (error.response!.data as Map)['error'] ?? ''}'
            : '';
        if (serverMessage.isNotEmpty) return serverMessage;
        return 'Unable to update the exam session. Please try again.';
      }
      if (error.type == DioExceptionType.connectionTimeout || error.type == DioExceptionType.receiveTimeout) {
        return 'Connection timed out. Check your network and tap retry.';
      }
      if (error.type == DioExceptionType.badResponse) {
        return 'Server returned an unexpected response. Please try again later.';
      }
      return 'Unable to load attendance data. Please try again.';
    }

    return 'Something went wrong while loading attendance.';
  }

  Widget _buildSessionActions(ExamAssignment assignment) {
    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Refresh attendance',
                  variant: AppButtonVariant.secondary,
                  onPressed: () => _refreshAttendance(assignment),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: AppButton(
                  label: 'Open verification',
                  variant: AppButtonVariant.secondary,
                  onPressed: () async {
                    await context.push('/verification');
                    if (mounted) {
                      await _refreshAttendance(ref.read(selectedExamProvider));
                    }
                  },
                ),
              ),
            ],
          ),
          if (assignment.isInProgress) ...[
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: 'End examination session',
              variant: AppButtonVariant.danger,
              icon: Icons.stop_circle_outlined,
              loading: _endingSession,
              onPressed: _endSession,
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Ending the session closes check-in and marks remaining allocated students as absent.',
              style: TextStyle(fontSize: 13, color: AppColors.muted),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAttendanceList() {
    if (_attendanceRecords.isEmpty) {
      return const AppEmptyState(
        title: 'No attendance records',
        message: 'No attendance records are available for this session yet.',
        icon: Icons.fact_check_outlined,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppPanel(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
          child: const Row(
            children: [
              Expanded(flex: 2, child: Text('Student', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.muted))),
              Expanded(child: Text('Seat', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.muted))),
              Expanded(child: Text('Status', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.muted))),
              Expanded(child: Text('Method', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.muted))),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        ..._attendanceRecords.map(_buildAttendanceRow),
      ],
    );
  }

  Widget _buildAttendanceRow(AttendanceRecord record) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppPanel(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.fullName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${record.computerNumber} • ${record.program}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Text(
                record.seatNumber,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, color: AppColors.ink),
              ),
            ),
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: AppBadge.status(record.attendanceStatus),
              ),
            ),
            Expanded(
              child: Text(
                record.verificationMethod.replaceAll('_', ' '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, color: AppColors.ink),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selected = ref.watch(selectedExamProvider);

    ref.listen<ExamAssignment?>(selectedExamProvider, (previous, next) {
      if (previous?.examSessionId == next?.examSessionId &&
          previous?.venueId == next?.venueId &&
          _loadedExamSessionId == next?.examSessionId) {
        return;
      }
      _refreshAttendance(next);
    });

    return AppPageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppPageHeader(
            title: 'Attendance register',
            subtitle: 'Review students allocated to the exam selected on the dashboard.',
          ),
          const SizedBox(height: AppSpacing.xl),
          if (selected == null) ...[
            const AppEmptyState(
              title: 'No exam selected',
              message: 'Choose an assigned exam on the dashboard to load its attendance register.',
              icon: Icons.list_alt_outlined,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'Go to dashboard',
              onPressed: () => context.go('/'),
            ),
          ] else ...[
            _buildSessionActions(selected),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.lg),
              AppErrorBanner(message: _error!, onRetry: () => _refreshAttendance(selected)),
            ],
            const SizedBox(height: AppSpacing.xl),
            if (_loading)
              const AppPageSkeleton(showMetrics: false)
            else ...[
              const AppSectionHeader(
                title: 'Register',
                subtitle: 'Students allocated to the selected exam session.',
              ),
              const SizedBox(height: AppSpacing.lg),
              _buildAttendanceList(),
            ],
          ],
        ],
      ),
    );
  }
}
