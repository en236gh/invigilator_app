import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../app/constants/app_colors.dart';
import '../../../core/widgets/app_panel.dart';
import '../application/offline_controller.dart';
import 'offline_typography.dart';

/// Reads the student identifier for local lookup; server verification still
/// receives the original pass when the saved attendance entry is uploaded.
String? offlinePassComputerNumber(String token) {
  try {
    final parts = token.trim().split('.');
    if (parts.length != 3) return null;
    final claims = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
    );
    if (claims is! Map || claims['sub'] is! String) return null;
    final number = claims['sub'] as String;
    return RegExp(r'^\d{10}$').hasMatch(number) ? number : null;
  } catch (_) {
    return null;
  }
}

class OfflineVerificationFlow extends ConsumerStatefulWidget {
  const OfflineVerificationFlow({
    super.key,
    required this.assignment,
    required this.method,
    this.cameraBuilder,
  });
  final Map<String, dynamic> assignment;
  final String method;
  final Widget Function(ValueChanged<String> onScan)? cameraBuilder;

  @override
  ConsumerState<OfflineVerificationFlow> createState() =>
      _OfflineVerificationFlowState();
}

class _OfflineVerificationFlowState
    extends ConsumerState<OfflineVerificationFlow> {
  final _number = TextEditingController();
  Map<String, dynamic>? _student;
  Uint8List? _photo;
  String _token = '';
  String? _error;
  bool _processing = false;
  bool _saving = false;
  bool _photoLoading = false;
  int _cameraSession = 0;
  bool get _qr => widget.method == 'QR_CODE';

  Future<void> _findStudent(String number, {String token = ''}) async {
    if (_processing || _saving || _student != null) return;
    setState(() {
      _processing = true;
      _error = null;
    });
    final state = ref.read(offlineProvider);
    final student = state.snapshot?.lookup(
      widget.assignment['examSessionId'] as int,
      widget.assignment['venueId'] as int,
      number,
    );
    if (student == null) {
      setState(() {
        _processing = false;
        _error =
            'Student not found for this exam and venue. Please check the examination pass.';
      });
      return;
    }
    setState(() {
      _student = student;
      _token = token;
      _photoLoading = true;
    });
    Uint8List? photo;
    try {
      if (state.owner != null) {
        photo = await state.repository.photo(
          state.owner!,
          '${student['photoPath'] ?? ''}',
        );
      }
    } catch (_) {
      // Identification can still be checked when no downloaded photo exists.
    }
    if (!mounted || !identical(_student, student)) return;
    setState(() {
      _photo = photo;
      _photoLoading = false;
      _processing = false;
    });
  }

  void _scan(String token) {
    if (_processing || _student != null || _error != null) return;
    final number = offlinePassComputerNumber(token);
    if (number == null) {
      setState(
        () =>
            _error = 'Could not read this examination pass. Please try again.',
      );
      return;
    }
    _findStudent(number, token: token);
  }

  void _reset() {
    setState(() {
      _student = null;
      _photo = null;
      _token = '';
      _error = null;
      _processing = false;
      _photoLoading = false;
      _cameraSession++;
      _number.clear();
    });
  }

  Future<void> _accept() async {
    if (_student == null || _saving) return;
    setState(() => _saving = true);
    try {
      final state = ref.read(offlineProvider);
      final number = '${_student!['computerNumber']}';
      final previouslyRejected = state.scans.any((scan) {
        if (scan['outcome'] != 'REJECTED') return false;
        final payload = jsonDecode(scan['payload'] as String) as Map;
        return payload['examSessionId'] == widget.assignment['examSessionId'] &&
            payload['computerNumber'] == number;
      });
      if (previouslyRejected) {
        throw StateError(
          'A previous attendance entry needs follow-up. Resolve it with examination staff before trying again.',
        );
      }
      await state.capture(widget.assignment, number, widget.method, _token);
      if (!mounted) return;
      _reset();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Attendance saved'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is StateError
              ? error.message.toString()
              : 'Could not save attendance. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _number.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Router.maybeOf(context) == null
      ? _buildContent(context)
      : BackButtonListener(
          onBackButtonPressed: () async {
            if (_student == null && _error == null) return false;
            if (!_saving) _reset();
            return true;
          },
          child: _buildContent(context),
        );

  Widget _buildContent(BuildContext context) {
    if (_student != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: AppPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        '${_student!['fullName']}',
                        style: OfflineTypography.pageTitle,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 240,
                      child: _photoLoading
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: AppColors.brandGold,
                              ),
                            )
                          : _photo != null
                          ? Image.memory(_photo!, fit: BoxFit.contain)
                          : const Icon(
                              Icons.person_outline,
                              size: 120,
                              color: AppColors.muted,
                            ),
                    ),
                    const SizedBox(height: 20),
                    _detail(
                      'Computer number',
                      '${_student!['computerNumber']}',
                    ),
                    if (_student!['program'] != null)
                      _detail('Programme', '${_student!['program']}'),
                    _detail('Exam', '${widget.assignment['courseCode']}'),
                    _detail('Venue', '${widget.assignment['venueName']}'),
                    const SizedBox(height: 16),
                    const Text(
                      'Confirm that these details match the student.',
                      style: OfflineTypography.supporting,
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(_error!),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SafeArea(
            top: false,
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving ? null : _reset,
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton(
                    onPressed: _saving || _photoLoading ? null : _accept,
                    child: Text(_saving ? 'Saving…' : 'Accept'),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }
    if (_qr) {
      Widget camera;
      if (_error != null) {
        camera = Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _reset,
                  child: const Text('Scan again'),
                ),
              ],
            ),
          ),
        );
      } else if (_processing) {
        camera = const Center(
          child: CircularProgressIndicator(color: AppColors.brandGold),
        );
      } else {
        camera =
            widget.cameraBuilder?.call(_scan) ??
            MobileScanner(
              key: ValueKey(_cameraSession),
              onDetect: (capture) {
                for (final barcode in capture.barcodes) {
                  final token = barcode.rawValue;
                  if (token != null && token.isNotEmpty) {
                    _scan(token);
                    break;
                  }
                }
              },
              errorBuilder: (context, error) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Camera unavailable. Allow camera access and try again.',
                    ),
                    TextButton(
                      onPressed: _reset,
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Scan the student’s QR code',
            style: OfflineTypography.heading,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: camera,
            ),
          ),
        ],
      );
    }
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: AppPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Enter computer number', style: OfflineTypography.heading),
            const SizedBox(height: 20),
            TextField(
              controller: _number,
              enabled: !_processing,
              keyboardType: TextInputType.number,
              maxLength: 10,
              decoration: const InputDecoration(labelText: 'Computer number'),
              onSubmitted: (_) => _lookupNumber(),
            ),
            if (_error != null) Text(_error!),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _processing ? null : _lookupNumber,
              child: const Text('Find student'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detail(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: OfflineTypography.supporting),
        const SizedBox(height: 4),
        Text(value, style: OfflineTypography.action),
      ],
    ),
  );

  void _lookupNumber() {
    if (!RegExp(r'^\d{10}$').hasMatch(_number.text.trim())) {
      setState(() => _error = 'Enter the student’s 10-digit computer number.');
      return;
    }
    _findStudent(_number.text.trim());
  }
}
