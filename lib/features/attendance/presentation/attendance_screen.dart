import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/constants/app_colors.dart';
import '../../../app/constants/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_canvas.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_banner.dart';
import '../../../core/widgets/app_page_header.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../examinations/application/exam_providers.dart';
import '../../examinations/domain/exam_assignment.dart';
import '../../examinations/application/session_flow_controller.dart';
import '../data/attendance_repository.dart';
import '../domain/attendance_models.dart';

class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({super.key});

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen> {
  final AttendanceRepository _attendanceRepository = AttendanceRepository();

  String _searchQuery = '';
  bool _loading = false;
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
    final selected = ref.read(selectedExamProvider);
    final flow = ref.read(sessionFlowProvider);
    await flow.ready;
    if (!mounted) return;
    if (flow.flow?.assignment.sameAs(selected) == true) {
      await flow.requestScripts();
    }
    if (mounted) context.go('/');
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
      if (error.response?.statusCode == 400 ||
          error.response?.statusCode == 409) {
        final serverMessage = error.response?.data is Map
            ? '${(error.response!.data as Map)['message'] ?? (error.response!.data as Map)['error'] ?? ''}'
            : '';
        if (serverMessage.isNotEmpty) return serverMessage;
        return 'Unable to update the exam session. Please try again.';
      }
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout) {
        return 'Connection timed out. Check your network and tap retry.';
      }
      if (error.type == DioExceptionType.badResponse) {
        return 'Server returned an unexpected response. Please try again later.';
      }
      return 'Unable to load attendance data. Please try again.';
    }

    return 'Something went wrong while loading attendance.';
  }

  Widget _surface(Widget child) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.ink.withValues(alpha: 0.06)),
    ),
    child: child,
  );

  Widget _action({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
    bool primary = false,
  }) => ElevatedButton(
    onPressed: onPressed,
    style: ElevatedButton.styleFrom(
      elevation: 0,
      backgroundColor: primary ? AppColors.ink : Colors.white,
      foregroundColor: primary ? Colors.white : AppColors.ink,
      minimumSize: const Size(double.infinity, 48),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      side: primary
          ? BorderSide.none
          : BorderSide(color: AppColors.ink.withValues(alpha: 0.12)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 10),
        Flexible(child: Text(label, textAlign: TextAlign.center)),
      ],
    ),
  );

  Widget _buildSessionActions(ExamAssignment assignment) {
    return _surface(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _action(
            label: 'Verify Students',
            icon: Icons.verified_user_outlined,
            primary: true,
            onPressed: () async {
              await context.push('/verification');
              if (mounted) {
                await _refreshAttendance(ref.read(selectedExamProvider));
              }
            },
          ),
          const SizedBox(height: 12),
          _action(
            label: 'Refresh Attendance',
            icon: Icons.refresh,
            onPressed: _loading ? null : () => _refreshAttendance(assignment),
          ),
          if (assignment.isInProgress) ...[
            const SizedBox(height: 12),
            _action(
              label: 'End examination session',
              icon: Icons.stop_circle_outlined,
              onPressed: _endSession,
            ),
            const SizedBox(height: 8),
            const Text(
              'Enter the scripts count on the dashboard before ending this session.',
              style: TextStyle(fontSize: 13, color: AppColors.muted),
            ),
          ],
        ],
      ),
    );
  }

  String _statusLabel(AttendanceRecord record) {
    switch (record.attendanceStatus.trim().toUpperCase()) {
      case 'PRESENT':
        return 'Present';
      case 'ABSENT':
        return 'Absent';
      default:
        return 'Pending';
    }
  }

  Widget _statusBadge(String status, {int? count}) {
    final color = switch (status) {
      'Present' => AppColors.brandGreen,
      'Absent' => AppColors.brandRed,
      _ => const Color(0xFF92400E),
    };
    final icon = switch (status) {
      'Present' => Icons.check_circle_outline,
      'Absent' => Icons.error_outline,
      _ => Icons.schedule,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              count == null ? status : '$status: $count',
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _methodLabel(String method) {
    final normalized = method.trim().replaceAll('_', ' ').toUpperCase();
    switch (normalized) {
      case 'QR':
      case 'QR CODE':
        return 'QR Code';
      case 'MANUAL':
        return 'Manual';
      case 'BIOMETRIC':
        return 'Biometric';
      case '':
        return 'Not recorded';
      default:
        return normalized
            .split(' ')
            .map(
              (word) => word.isEmpty
                  ? word
                  : '${word[0]}${word.substring(1).toLowerCase()}',
            )
            .join(' ');
    }
  }

  Widget _buildExamInformation(ExamAssignment assignment) => _surface(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          assignment.courseCode,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 8),
        Text(assignment.venueName),
        const SizedBox(height: 4),
        Text(
          assignment.timeRangeLabel,
          style: const TextStyle(color: AppColors.muted),
        ),
      ],
    ),
  );

  Widget _buildSummary() => _surface(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Attendance summary',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final status in ['Present', 'Absent', 'Pending'])
              _statusBadge(
                status,
                count: _attendanceRecords
                    .where((record) => _statusLabel(record) == status)
                    .length,
              ),
          ],
        ),
      ],
    ),
  );

  Widget _buildAttendanceList() {
    final query = _searchQuery.trim().toLowerCase();
    final records = _attendanceRecords
        .where(
          (record) =>
              record.computerNumber.toLowerCase().contains(query) ||
              record.fullName.toLowerCase().contains(query) ||
              record.seatNumber.toLowerCase().contains(query),
        )
        .toList();
    if (records.isEmpty) {
      return _surface(
        AppEmptyState(
          title: query.isEmpty
              ? 'No attendance records'
              : 'No matching students',
          message: query.isEmpty
              ? 'No attendance records are available for this session yet.'
              : 'Try a different student number, name, or seat number.',
          icon: Icons.person_search_outlined,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [for (final record in records) _buildAttendanceRow(record)],
    );
  }

  Widget _buildAttendanceRow(AttendanceRecord record) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: _surface(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            record.computerNumber,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          if (record.fullName.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(record.fullName, style: const TextStyle(fontSize: 14)),
          ],
          const SizedBox(height: 4),
          Text(
            'Seat ${record.seatNumber.isEmpty ? 'not allocated' : record.seatNumber}',
            style: const TextStyle(fontSize: 13, color: AppColors.muted),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _statusBadge(_statusLabel(record)),
              Text(
                _methodLabel(record.verificationMethod),
                style: const TextStyle(fontSize: 13, color: AppColors.muted),
              ),
            ],
          ),
        ],
      ),
    ),
  );

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
      onRefresh: () => _refreshAttendance(ref.read(selectedExamProvider)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppPageHeader(
            title: 'Attendance',
            subtitle: 'Review and record attendance for this examination.',
          ),
          const SizedBox(height: AppSpacing.xl),
          if (selected == null) ...[
            const AppEmptyState(
              title: 'No exam selected',
              message:
                  'Choose an assigned exam on the dashboard to load its attendance register.',
              icon: Icons.list_alt_outlined,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'Go to dashboard',
              onPressed: () => context.go('/'),
            ),
          ] else ...[
            _buildExamInformation(selected),
            const SizedBox(height: 16),
            if (!_loading) ...[_buildSummary(), const SizedBox(height: 16)],
            _buildSessionActions(selected),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.lg),
              AppErrorBanner(
                message: _error!,
                onRetry: () => _refreshAttendance(selected),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            if (_loading)
              const AppPageSkeleton(showMetrics: false)
            else ...[
              TextField(
                onChanged: (value) => setState(() => _searchQuery = value),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  labelText: 'Search student',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide(
                      color: AppColors.ink.withValues(alpha: 0.1),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              AppSectionHeader(
                title: 'Students (${_attendanceRecords.length})',
                subtitle: 'Students allocated to this examination.',
              ),
              const SizedBox(height: 12),
              _buildAttendanceList(),
            ],
          ],
        ],
      ),
    );
  }
}
