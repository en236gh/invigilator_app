import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:invigilator_app/app/constants/app_colors.dart';
import 'package:invigilator_app/app/constants/app_spacing.dart';
import 'package:invigilator_app/core/widgets/app_badge.dart';
import 'package:invigilator_app/core/widgets/app_button.dart';
import 'package:invigilator_app/core/widgets/app_canvas.dart';
import 'package:invigilator_app/core/widgets/app_empty_state.dart';
import 'package:invigilator_app/core/widgets/app_error_banner.dart';
import 'package:invigilator_app/core/widgets/app_page_header.dart';
import 'package:invigilator_app/core/widgets/app_panel.dart';
import 'package:invigilator_app/core/widgets/app_skeleton.dart';
import 'package:invigilator_app/features/examinations/application/exam_providers.dart';
import 'package:invigilator_app/features/examinations/domain/exam_assignment.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../data/verification_repository.dart';
import '../domain/verification_models.dart';
import 'widgets/qr_scanner_panel.dart';

enum VerificationMode { computerNumber, qrCode }

class VerificationScreen extends ConsumerStatefulWidget {
  const VerificationScreen({super.key});

  @override
  ConsumerState<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends ConsumerState<VerificationScreen> {
  final VerificationRepository _repo = VerificationRepository();
  final TextEditingController _computerNumberController = TextEditingController();
  final TextEditingController _qrTokenController = TextEditingController();

  late final MobileScannerController _scannerController = MobileScannerController(
    autoStart: false,
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    formats: const [BarcodeFormat.qrCode],
  );

  bool _actionInProgress = false;
  bool _sessionActionInProgress = false;
  bool _scannerPaused = false;
  VerificationMode _mode = VerificationMode.computerNumber;
  StudentPreview? _studentPreview;
  VerificationResult? _verificationResult;
  String? _feedbackMessage;
  String? _errorMessage;

  ExamAssignment? get _selectedAssignment => ref.read(selectedExamProvider);

  bool get _attendanceAvailable {
    final selected = _selectedAssignment;
    return selected != null && !selected.isCompleted;
  }

  bool get _canStartSession => _selectedAssignment?.isScheduled == true;
  bool get _canEndSession => _selectedAssignment?.isInProgress == true;
  bool get _canCheckIn =>
      _attendanceAvailable &&
      _studentPreview != null &&
      !_studentPreview!.alreadyCheckedIn &&
      !_actionInProgress;

  @override
  void dispose() {
    _computerNumberController.dispose();
    _qrTokenController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _startSession() async {
    final assignment = _selectedAssignment;
    if (assignment == null || !_canStartSession || _sessionActionInProgress) return;

    setState(() {
      _sessionActionInProgress = true;
      _errorMessage = null;
      _feedbackMessage = null;
    });

    try {
      final status = await ref.read(examRepositoryProvider).startSession(
            examSessionId: assignment.examSessionId,
            venueId: assignment.venueId,
          );
      await ref.read(examAssignmentsProvider.notifier).refresh();
      if (!mounted) return;
      setState(() {
        _feedbackMessage = status == 'IN_PROGRESS'
            ? 'Session started. You can now look up and check in students.'
            : 'Session updated to ${status.replaceAll('_', ' ')}.';
        _studentPreview = null;
        _verificationResult = null;
      });
      if (_mode == VerificationMode.qrCode) {
        await _resumeScanner();
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = _friendlyError(error);
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

  Future<void> _endSession() async {
    final assignment = _selectedAssignment;
    if (assignment == null || !_canEndSession || _sessionActionInProgress) return;

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
      _sessionActionInProgress = true;
      _errorMessage = null;
      _feedbackMessage = null;
    });

    try {
      final status = await ref.read(examRepositoryProvider).endSession(
            examSessionId: assignment.examSessionId,
            venueId: assignment.venueId,
          );
      await ref.read(examAssignmentsProvider.notifier).refresh();
      if (!mounted) return;
      setState(() {
        _feedbackMessage = 'Session ended (${status.replaceAll('_', ' ')}). Check-in is now closed for this venue.';
        _studentPreview = null;
        _verificationResult = null;
      });
      if (_mode == VerificationMode.qrCode) {
        await _scannerController.stop();
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = _friendlyError(error);
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

  Future<void> _lookupComputerNumber() async {
    if (_selectedAssignment == null || !_attendanceAvailable) {
      _showError('Check-in is closed for this exam because it has already been completed.');
      return;
    }
    final computerNumber = _computerNumberController.text.trim();
    if (computerNumber.isEmpty) {
      _showError('Enter the student computer number to continue.');
      return;
    }

    await _runAction(() async {
      final preview = await _repo.lookupByComputerNumber(
        computerNumber: computerNumber,
        examSessionId: _selectedAssignment!.examSessionId,
      );
      if (!mounted) return;
      setState(() {
        _studentPreview = preview;
        _verificationResult = null;
        _feedbackMessage = 'Student lookup succeeded. Confirm before check-in.';
        _errorMessage = null;
      });
    });
  }

  Future<void> _checkInComputerNumber() async {
    if (_selectedAssignment == null || !_attendanceAvailable) {
      _showError('Check-in is closed for this exam because it has already been completed.');
      return;
    }
    if (_studentPreview == null) {
      _showError('Look up the student first, then confirm check-in.');
      return;
    }
    if (_studentPreview!.alreadyCheckedIn) {
      _showError('This student is already checked in for this exam.');
      return;
    }
    final computerNumber = _computerNumberController.text.trim();
    if (computerNumber.isEmpty) {
      _showError('Enter the student computer number before checking in.');
      return;
    }

    await _runAction(() async {
      final result = await _repo.checkInByComputerNumber(
        computerNumber: computerNumber,
        examSessionId: _selectedAssignment!.examSessionId,
        venueId: _selectedAssignment!.venueId,
      );
      if (!mounted) return;
      _applyCheckInResult(result);
    });
  }

  Future<void> _lookupByQr({bool fromScan = false}) async {
    if (_selectedAssignment == null || !_attendanceAvailable) {
      _showError('Check-in is closed for this exam because it has already been completed.');
      if (fromScan) {
        await _resumeScanner();
      }
      return;
    }
    final qrToken = _qrTokenController.text.trim();
    if (qrToken.isEmpty) {
      _showError('Scan an examination pass QR code to continue.');
      if (fromScan) {
        await _resumeScanner();
      }
      return;
    }

    await _runAction(() async {
      final preview = await _repo.lookupByQrToken(
        qrToken: qrToken,
        examSessionId: _selectedAssignment!.examSessionId,
      );
      if (!mounted) return;
      setState(() {
        _studentPreview = preview;
        _verificationResult = null;
        _feedbackMessage = 'QR validated. Confirm student details before check-in.';
        _errorMessage = null;
      });
    });

    if (_errorMessage != null && fromScan) {
      await _resumeScanner();
    }
  }

  Future<void> _checkInByQr() async {
    if (_selectedAssignment == null || !_attendanceAvailable) {
      _showError('Check-in is closed for this exam because it has already been completed.');
      return;
    }
    if (_studentPreview == null) {
      _showError('Look up the student from the QR first, then confirm check-in.');
      return;
    }
    if (_studentPreview!.alreadyCheckedIn) {
      _showError('This student is already checked in for this exam.');
      return;
    }
    final qrToken = _qrTokenController.text.trim();
    if (qrToken.isEmpty) {
      _showError('Scan an examination pass QR code before checking in.');
      return;
    }

    await _runAction(() async {
      final result = await _repo.checkInByQrToken(
        qrToken: qrToken,
        examSessionId: _selectedAssignment!.examSessionId,
        venueId: _selectedAssignment!.venueId,
      );
      if (!mounted) return;
      _applyCheckInResult(result);
    });
  }

  void _applyCheckInResult(VerificationResult result) {
    setState(() {
      _verificationResult = result;
      if (result.success && result.studentPreview != null) {
        _studentPreview = StudentPreview(
          computerNumber: result.studentPreview!.computerNumber,
          fullName: result.studentPreview!.fullName,
          program: result.studentPreview!.program,
          photoPath: result.studentPreview!.photoPath,
          allocatedVenueId: result.studentPreview!.allocatedVenueId,
          allocatedVenueName: result.studentPreview!.allocatedVenueName,
          seatNumber: result.studentPreview!.seatNumber,
          alreadyCheckedIn: true,
        );
      } else {
        _studentPreview = result.studentPreview ?? _studentPreview;
      }
      _feedbackMessage = result.success
          ? 'Check-in recorded successfully.'
          : 'Unable to complete check-in. ${result.message.isNotEmpty ? result.message : ''}';
      _errorMessage = result.success ? null : _friendlyError(result.message);
    });
    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Student verified successfully.')),
      );
    }
  }

  Future<void> _onQrDetected(BarcodeCapture capture) async {
    if (!_attendanceAvailable || _mode != VerificationMode.qrCode || _scannerPaused || _actionInProgress) {
      return;
    }

    final rawValue = capture.barcodes
        .map((barcode) => barcode.rawValue?.trim())
        .firstWhere((value) => value != null && value.isNotEmpty, orElse: () => null);
    if (rawValue == null) return;

    setState(() {
      _scannerPaused = true;
      _qrTokenController.text = rawValue;
      _studentPreview = null;
      _verificationResult = null;
      _feedbackMessage = null;
      _errorMessage = null;
    });

    await _scannerController.stop();
    await _lookupByQr(fromScan: true);
  }

  Future<void> _resumeScanner() async {
    setState(() {
      _scannerPaused = false;
    });
    try {
      await _scannerController.start();
    } catch (_) {
      // Camera may already be running or unavailable on this platform.
    }
  }

  Future<void> _resetQrScan() async {
    setState(() {
      _qrTokenController.clear();
      _studentPreview = null;
      _verificationResult = null;
      _feedbackMessage = null;
      _errorMessage = null;
    });
    await _resumeScanner();
  }

  void _selectMode(VerificationMode mode) {
    if (_mode == mode) return;
    setState(() {
      _mode = mode;
      _studentPreview = null;
      _verificationResult = null;
      _feedbackMessage = null;
      _errorMessage = null;
      _scannerPaused = false;
    });

    if (mode == VerificationMode.qrCode && _attendanceAvailable) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _mode == VerificationMode.qrCode && _attendanceAvailable) {
          _resumeScanner();
        }
      });
    } else {
      _scannerController.stop();
    }
  }

  Future<void> _runAction(Future<void> Function() action) async {
    setState(() {
      _actionInProgress = true;
      _feedbackMessage = null;
      _errorMessage = null;
    });

    try {
      await action();
    } catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = _friendlyError(error);
          _feedbackMessage = null;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _actionInProgress = false;
        });
      }
    }
  }

  void _showError(String message) {
    setState(() {
      _errorMessage = message;
      _feedbackMessage = null;
    });
  }

  String _friendlyError(Object error) {
    if (error is String && error.isNotEmpty) {
      return error;
    }

    if (error is DioException) {
      if (error.response?.statusCode == 401) {
        return 'Your session has expired. Please sign in again.';
      }
      if (error.response?.statusCode == 409) {
        final serverMessage = error.response?.data is Map
            ? '${(error.response!.data as Map)['message'] ?? (error.response!.data as Map)['error'] ?? ''}'
            : '';
        if (serverMessage.isNotEmpty) {
          return serverMessage;
        }
        return 'Check-in was blocked. The session may still be scheduled, or this student may already be checked in.';
      }
      if (error.response?.statusCode == 400) {
        final serverMessage = error.response?.data is Map<String, dynamic>
            ? '${(error.response!.data as Map<String, dynamic>)['message'] ?? (error.response!.data as Map<String, dynamic>)['error'] ?? ''}'
            : '';
        if (serverMessage.isNotEmpty) {
          return serverMessage;
        }
        return 'The QR code looks invalid or expired. Ask the student for a fresh examination pass.';
      }
      if (error.type == DioExceptionType.connectionTimeout || error.type == DioExceptionType.receiveTimeout) {
        return 'Unable to reach the server. Check your connection and try again.';
      }
      if (error.type == DioExceptionType.badResponse) {
        return 'The server responded with unexpected data. Please try again later.';
      }
      return 'Unable to complete the request. Please try again.';
    }

    return 'Something went wrong. Please try again.';
  }

  Widget _buildModeTile(VerificationMode mode, String title, String subtitle, IconData icon) {
    final selected = _mode == mode;
    return AppPanel(
      onTap: () => _selectMode(mode),
      padding: const EdgeInsets.all(AppSpacing.lg),
      borderColor: selected ? AppColors.ink : null,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(AppSpacing.radius),
            ),
            child: Icon(icon, size: 22, color: AppColors.ink),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.ink)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    if (_errorMessage != null) {
      return AppErrorBanner(message: _errorMessage!);
    }
    if (_feedbackMessage != null) {
      return AppInfoBanner(message: _feedbackMessage!, tone: AppInfoBannerTone.warning);
    }
    return const SizedBox.shrink();
  }

  Widget _buildStudentSummary() {
    final preview = _studentPreview;
    if (preview == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: AppPanel(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(AppSpacing.radius),
                  ),
                  child: Text(
                    preview.initials,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        preview.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.ink),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        preview.program,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: AppBadge(
                      label: preview.alreadyCheckedIn ? 'Already checked in' : 'Ready to verify',
                      tone: preview.alreadyCheckedIn ? AppBadgeTone.danger : AppBadgeTone.success,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.sm,
              children: [
                _labelValue('Computer', preview.computerNumber),
                _labelValue('Venue', preview.allocatedVenueName),
                _labelValue('Seat', preview.seatNumber),
                if (_verificationResult != null && _verificationResult!.attendanceStatus.isNotEmpty)
                  _labelValue('Status', _verificationResult!.attendanceStatus.replaceAll('_', ' ')),
                if (_verificationResult != null && _verificationResult!.verificationMethod.isNotEmpty)
                  _labelValue('Method', _verificationResult!.verificationMethod.replaceAll('_', ' ')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _labelValue(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppSpacing.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.6, color: AppColors.muted)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink)),
        ],
      ),
    );
  }

  Widget _buildActionSection(ExamAssignment assignment) {
    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  assignment.shortLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.ink),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              AppBadge.status(assignment.examStatus),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            assignment.isCompleted
                ? 'This session is closed. Check-in is blocked for this venue.'
                : 'Attendance can be recorded for students allocated to this exam while it is not completed.',
            style: const TextStyle(fontSize: 13, color: AppColors.muted, height: 1.4),
          ),
          if (_canStartSession || _canEndSession) ...[
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                if (_canStartSession)
                  Expanded(
                    child: AppButton(
                      label: 'Start session',
                      icon: Icons.play_arrow,
                      loading: _sessionActionInProgress,
                      onPressed: _startSession,
                    ),
                  ),
                if (_canStartSession && _canEndSession) const SizedBox(width: AppSpacing.md),
                if (_canEndSession)
                  Expanded(
                    child: AppButton(
                      label: 'End session',
                      variant: AppButtonVariant.danger,
                      icon: Icons.stop_circle_outlined,
                      loading: _sessionActionInProgress,
                      onPressed: _endSession,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQrMethodForm() {
    final lookupEnabled = _attendanceAvailable && !_actionInProgress;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_selectedAssignment != null && _selectedAssignment!.isCompleted)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Text(
              'This session is completed, so QR check-in is closed.',
              style: const TextStyle(fontSize: 13, color: AppColors.brandRed),
            ),
          ),
        QrScannerPanel(
          controller: _scannerController,
          onDetect: _onQrDetected,
          isPaused: _scannerPaused,
        ),
        const SizedBox(height: AppSpacing.lg),
        TextFormField(
          controller: _qrTokenController,
          maxLines: 2,
          readOnly: true,
          decoration: const InputDecoration(
            labelText: 'Scanned QR token',
            hintText: 'Token appears here after a successful scan',
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: 'Lookup student',
                variant: AppButtonVariant.secondary,
                loading: _actionInProgress,
                onPressed: lookupEnabled ? () => _lookupByQr() : null,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: AppButton(
                label: 'Check in',
                onPressed: _canCheckIn ? _checkInByQr : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        AppButton(
          label: 'Scan another pass',
          variant: AppButtonVariant.secondary,
          icon: Icons.qr_code_scanner,
          onPressed: _actionInProgress ? null : _resetQrScan,
        ),
        const SizedBox(height: AppSpacing.sm),
        const Text(
          'Scan the examination pass QR, confirm the student identity card, then check in.',
          style: TextStyle(fontSize: 13, color: AppColors.muted),
        ),
      ],
    );
  }

  Widget _buildComputerNumberForm() {
    final lookupEnabled = _attendanceAvailable && !_actionInProgress;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_selectedAssignment != null && _selectedAssignment!.isCompleted)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Text(
              'This session is completed, so computer-number check-in is closed.',
              style: const TextStyle(fontSize: 13, color: AppColors.brandRed),
            ),
          ),
        TextFormField(
          controller: _computerNumberController,
          keyboardType: TextInputType.number,
          enabled: _attendanceAvailable,
          decoration: const InputDecoration(labelText: 'Student computer number'),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: 'Lookup student',
                variant: AppButtonVariant.secondary,
                loading: _actionInProgress,
                onPressed: lookupEnabled ? _lookupComputerNumber : null,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: AppButton(
                label: 'Check in',
                onPressed: _canCheckIn ? _checkInComputerNumber : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        const Text(
          'Enter the student computer number to look up allocation details, then confirm check-in.',
          style: TextStyle(fontSize: 13, color: AppColors.muted),
        ),
      ],
    );
  }

  Widget _buildMethodForm() {
    if (_mode == VerificationMode.qrCode) return _buildQrMethodForm();
    return _buildComputerNumberForm();
  }

  @override
  Widget build(BuildContext context) {
    final selected = ref.watch(selectedExamProvider);
    final assignmentsAsync = ref.watch(examAssignmentsProvider);

    ref.listen<ExamAssignment?>(selectedExamProvider, (previous, next) {
      if (previous?.examSessionId == next?.examSessionId && previous?.venueId == next?.venueId) {
        return;
      }
      setState(() {
        _studentPreview = null;
        _verificationResult = null;
        _feedbackMessage = null;
        _errorMessage = null;
      });
      if (_mode == VerificationMode.qrCode) {
        _scannerController.stop();
      }
    });

    return AppPageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppPageHeader(
            title: 'Student verification',
            subtitle: 'Confirm identity using computer number or examination pass QR code.',
          ),
          const SizedBox(height: AppSpacing.xl),
          if (assignmentsAsync.isLoading && selected == null)
            const AppPageSkeleton(showMetrics: false)
          else if (selected == null) ...[
            const AppEmptyState(
              title: 'No exam selected',
              message: 'Choose an assigned exam on the dashboard. Verification stays scoped to that exam.',
              icon: Icons.fact_check_outlined,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'Go to dashboard',
              onPressed: () => context.go('/'),
            ),
          ] else ...[
            _buildActionSection(selected),
            const SizedBox(height: AppSpacing.section),
            const AppSectionHeader(
              title: 'Verification methods',
              subtitle: 'Both methods record attendance for the exam selected on the dashboard.',
            ),
            const SizedBox(height: AppSpacing.lg),
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth > 700) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildModeTile(
                          VerificationMode.computerNumber,
                          'Computer number',
                          'Lookup and check in by student computer number.',
                          Icons.keyboard_alt_outlined,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.grid),
                      Expanded(
                        child: _buildModeTile(
                          VerificationMode.qrCode,
                          'QR code',
                          'Scan an examination pass QR to verify and check in.',
                          Icons.qr_code_2_outlined,
                        ),
                      ),
                    ],
                  );
                }

                return Column(
                  children: [
                    _buildModeTile(
                      VerificationMode.computerNumber,
                      'Computer number',
                      'Lookup and check in by student computer number.',
                      Icons.keyboard_alt_outlined,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _buildModeTile(
                      VerificationMode.qrCode,
                      'QR code',
                      'Scan an examination pass QR to verify and check in.',
                      Icons.qr_code_2_outlined,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: AppSpacing.xl),
            AppPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _mode == VerificationMode.computerNumber ? 'Computer number verification' : 'QR code verification',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.ink),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _buildMethodForm(),
                  if (_errorMessage != null || _feedbackMessage != null) ...[
                    const SizedBox(height: AppSpacing.lg),
                    _buildStatusCard(),
                  ],
                  _buildStudentSummary(),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
