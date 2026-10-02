import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/widgets/app_panel.dart';
import '../../../app/constants/app_colors.dart';
import '../application/offline_controller.dart';

class OfflineCapture extends ConsumerStatefulWidget {
  const OfflineCapture({super.key, this.initialMethod});
  final String? initialMethod;
  @override
  ConsumerState<OfflineCapture> createState() => _OfflineCaptureState();
}

class _OfflineCaptureState extends ConsumerState<OfflineCapture> {
  final number = TextEditingController();
  final token = TextEditingController();
  int? selected;
  int step = 0;
  String method = 'COMPUTER';

  @override
  void initState() {
    super.initState();
    method = widget.initialMethod ?? 'COMPUTER';
  }

  Map<String, dynamic>? student;
  Uint8List? photo;
  String? feedback;
  String? receipt;
  bool busy = false, photoLoading = false;
  bool identityConfirmed = false, facialConfirmed = false;
  bool get usesQr => method.startsWith('QR');
  bool get usesFace => method.contains('FACE') || method.contains('FACIAL');
  String? get numberError {
    final value = number.text.trim();
    if (value.isEmpty) return null;
    if (!RegExp(r'^\d+$').hasMatch(value)) {
      return 'Use numeric characters only.';
    }
    if (value.length != 10) {
      return 'Enter exactly 10 digits (${value.length}/10).';
    }
    return null;
  }

  bool get validNumber => RegExp(r'^\d{10}$').hasMatch(number.text.trim());
  static const methods = {
    'COMPUTER': (
      'Computer number and ID',
      'Use the downloaded student list and compare the student’s identification.',
    ),
    'QR_CODE': (
      'Examination pass QR',
      'Scan the examination pass and find the student by computer number.',
    ),
    'FACE_RECOGNITION': (
      'Separate facial check',
      'Use only after completing a facial comparison outside this screen.',
    ),
    'QR_AND_FACE': (
      'QR pass and separate facial check',
      'Capture the pass and complete a facial comparison outside this screen.',
    ),
  };

  void clearPreview() {
    student = null;
    photo = null;
    photoLoading = false;
    identityConfirmed = false;
    facialConfirmed = false;
    feedback = null;
  }

  Future<void> lookup() async {
    final state = ref.read(offlineProvider);
    if (selected == null || state.snapshot == null || !validNumber || busy) {
      return;
    }
    final a = state.snapshot!.assignments[selected!];
    final found = state.snapshot!.lookup(
      a['examSessionId'] as int,
      a['venueId'] as int,
      number.text.trim(),
    );
    setState(() {
      clearPreview();
      student = found;
      feedback = found == null
          ? 'Valid computer number, but no match in the downloaded student list for this exam and venue.'
          : null;
      if (found != null) {
        step = 2;
        photoLoading = true;
      }
    });
    if (found != null) {
      Uint8List? bytes;
      try {
        bytes = await state.repository.photo(
          state.owner!,
          '${found['photoPath'] ?? ''}',
        );
      } catch (_) {
        // Missing photos do not prevent roster lookup.
      }
      if (mounted && identical(student, found)) {
        setState(() {
          photo = bytes;
          photoLoading = false;
        });
      }
    }
  }

  Future<void> capture() async {
    final state = ref.read(offlineProvider);
    if (selected == null ||
        student == null ||
        busy ||
        !identityConfirmed ||
        (usesFace && !facialConfirmed) ||
        (usesQr && token.text.trim().isEmpty)) {
      return;
    }
    final assignment = state.snapshot!.assignments[selected!];
    final savedStudent =
        '${student!['fullName']} · ${student!['computerNumber']}';
    final savedAssignment =
        '${assignment['courseCode']} · ${assignment['venueName']}';
    final rejected = state.scans.where((row) {
      final payload = jsonDecode(row['payload'] as String) as Map;
      return row['outcome'] == 'REJECTED' &&
          payload['examSessionId'] == assignment['examSessionId'] &&
          payload['computerNumber'] == number.text.trim();
    });
    setState(() => busy = true);
    try {
      if (rejected.isNotEmpty) {
        var resolved = false;
        final proceed = await showDialog<bool>(
          context: context,
          builder: (context) => StatefulBuilder(
            builder: (context, update) => AlertDialog(
              title: const Text('Previous scan was rejected'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(savedStudent),
                    Text(savedAssignment),
                    for (final row in rejected) ...[
                      const SizedBox(height: 12),
                      Text('Reason: ${row['reason'] ?? 'Not supplied'}'),
                      Text(
                        'Server message: ${row['message'] ?? 'Not supplied'}',
                      ),
                    ],
                    const SizedBox(height: 12),
                    const Text(
                      'Resolve the rejection with examination staff before capturing again. The original rejection stays in history; a new scan still needs server verification.',
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: resolved,
                      onChanged: (value) => update(() => resolved = value!),
                      title: const Text(
                        'I have resolved the stated rejection with examination staff.',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                FilledButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Return to review'),
                ),
                TextButton(
                  onPressed: resolved
                      ? () => Navigator.pop(context, true)
                      : null,
                  child: const Text('Capture a new pending scan'),
                ),
              ],
            ),
          ),
        );
        if (proceed != true || !mounted) return;
      }
      await state.capture(
        assignment,
        number.text.trim(),
        method,
        token.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        clearPreview();
        number.clear();
        token.clear();
        step = 1;
        receipt =
            '$savedStudent\n$savedAssignment\nSaved on this device · Pending server verification at save time. Check History for the latest result.';
      });
    } catch (e) {
      if (mounted) {
        setState(
          () => feedback = e is StateError
              ? e.message
              : 'Could not save scan. Attendance is not recorded; try again.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> scanQr() async {
    final value = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const _OfflineQrCamera()));
    if (!mounted || value == null) return;
    setState(() {
      token.text = value;
      clearPreview();
    });
  }

  @override
  void dispose() {
    number.dispose();
    token.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(offlineProvider);
    final assignments = state.snapshot!.assignments;
    final assignment = selected == null ? null : assignments[selected!];
    final canSave =
        !busy &&
        identityConfirmed &&
        (!usesFace || facialConfirmed) &&
        (!usesQr || token.text.trim().isNotEmpty);
    return AppPanel(
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.initialMethod == 'QR_CODE'
                  ? 'QR code verification'
                  : widget.initialMethod == 'COMPUTER'
                  ? 'Computer number verification'
                  : 'Offline capture',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Text(
              'Attendance is confirmed only after server verification.',
            ),
            if (receipt != null) ...[
              const SizedBox(height: 12),
              _CaptureNotice(
                title: 'Pending scan saved',
                message: receipt!,
                icon: Icons.save_alt,
              ),
            ],
            const SizedBox(height: 12),
            Text(
              'Step ${step + 1} of 3 · ${['Choose exam and venue', 'Find student', 'Confirm identity'][step]}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (assignment != null) ...[
              const SizedBox(height: 8),
              _CaptureNotice(
                title: 'Selected exam and venue',
                message:
                    '${assignment['courseCode']} · ${assignment['venueName']}\n${assignment['examDate']}',
                icon: Icons.event,
              ),
              if (step != 0)
                TextButton(
                  onPressed: busy
                      ? null
                      : () => setState(() {
                          step = 0;
                          clearPreview();
                          number.clear();
                          token.clear();
                        }),
                  child: const Text(
                    'Change exam and venue (clears current student)',
                  ),
                ),
            ],
            const SizedBox(height: 12),
            if (step == 0) ...[
              DropdownButtonFormField<int>(
                initialValue: selected,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Exam and venue'),
                items: [
                  for (var i = 0; i < assignments.length; i++)
                    DropdownMenuItem(
                      value: i,
                      child: Text(
                        '${assignments[i]['courseCode']} · ${assignments[i]['venueName']} · ${assignments[i]['examDate']}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: busy
                    ? null
                    : (value) => setState(() {
                        selected = value;
                        clearPreview();
                        number.clear();
                        token.clear();
                      }),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: selected == null || busy
                    ? null
                    : () => setState(() => step = 1),
                child: const Text('Use this exam and venue'),
              ),
            ],
            if (step == 1) ...[
              TextField(
                controller: number,
                enabled: !busy,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: '10-digit computer number',
                  errorText: numberError,
                ),
                onChanged: (_) => setState(clearPreview),
              ),
              const SizedBox(height: 12),
              if (widget.initialMethod == null)
                DropdownButtonFormField<String>(
                  initialValue: method,
                  key: ValueKey(method),
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Identity check method',
                  ),
                  items: [
                    for (final entry in methods.entries)
                      DropdownMenuItem(
                        value: entry.key,
                        child: Text(entry.value.$1),
                      ),
                  ],
                  onChanged: busy
                      ? null
                      : (value) => setState(() {
                          method = value!;
                          token.clear();
                          clearPreview();
                        }),
                ),
              const SizedBox(height: 8),
              Text(methods[method]!.$2),
              if (usesFace)
                const _CaptureNotice(
                  title: 'No in-app facial check',
                  message:
                      'This screen does not compare faces. Complete the comparison separately before saving this method.',
                  icon: Icons.warning_amber_rounded,
                ),
              if (usesQr) ...[
                OutlinedButton.icon(
                  onPressed: busy ? null : scanQr,
                  icon: const Icon(Icons.qr_code_scanner),
                  label: Text(
                    token.text.isEmpty
                        ? 'Scan examination pass'
                        : 'Scan pass again',
                  ),
                ),
                TextField(
                  controller: token,
                  enabled: !busy,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Examination pass code',
                    helperText:
                        'Captured token or paste from the examination pass',
                  ),
                  onChanged: (_) => setState(clearPreview),
                ),
              ],
              const SizedBox(height: 12),
              FilledButton(
                onPressed:
                    validNumber &&
                        !busy &&
                        (!usesQr || token.text.trim().isNotEmpty)
                    ? lookup
                    : null,
                child: const Text('Find student locally'),
              ),
            ],
            if (step == 2 && student != null) ...[
              if (photoLoading)
                const SizedBox(
                  height: 180,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 8),
                        Text('Loading downloaded photo…'),
                      ],
                    ),
                  ),
                )
              else if (photo != null)
                Image.memory(
                  photo!,
                  height: 180,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const _PhotoUnavailable(),
                )
              else
                const _PhotoUnavailable(),
              Text(
                '${student!['fullName']} · ${student!['computerNumber']}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text('${student!['program'] ?? ''}'),
              Align(
                alignment: Alignment.centerLeft,
                child: Chip(
                  label: Text(
                    'Last downloaded status: ${student!['attendanceStatus'] ?? 'not recorded'}',
                  ),
                ),
              ),
              Text('Method: ${methods[method]!.$1}'),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: identityConfirmed,
                onChanged: busy
                    ? null
                    : (value) => setState(() => identityConfirmed = value!),
                title: const Text(
                  'I confirmed this student’s identity for the selected exam and venue.',
                ),
              ),
              if (usesFace) ...[
                const _CaptureNotice(
                  title: 'No in-app facial check',
                  message: 'This screen has not performed facial verification.',
                  icon: Icons.warning_amber_rounded,
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: facialConfirmed,
                  onChanged: busy
                      ? null
                      : (value) => setState(() => facialConfirmed = value!),
                  title: const Text(
                    'I completed a separate facial comparison.',
                  ),
                ),
              ],
              const _CaptureNotice(
                title: 'Pending server verification',
                message:
                    'Saving stores a pending scan on this device. It does not complete attendance.',
                icon: Icons.schedule,
              ),
              FilledButton.icon(
                onPressed: canSave ? capture : null,
                icon: const Icon(Icons.save_alt),
                label: Text(busy ? 'Saving…' : 'Save pending scan'),
              ),
              TextButton(
                onPressed: busy
                    ? null
                    : () => setState(() {
                        clearPreview();
                        step = 1;
                      }),
                child: const Text('Back to student lookup'),
              ),
            ],
            if (feedback != null)
              Semantics(liveRegion: true, child: Text(feedback!)),
          ],
        ),
      ),
    );
  }
}

class _CaptureNotice extends StatelessWidget {
  const _CaptureNotice({
    required this.title,
    required this.message,
    required this.icon,
  });
  final String title, message;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Card(
      color: AppColors.surfaceMuted,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(message),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _PhotoUnavailable extends StatelessWidget {
  const _PhotoUnavailable();
  @override
  Widget build(BuildContext context) => const _CaptureNotice(
    title: 'Downloaded photo unavailable',
    message: 'Use the student’s identification for visual comparison.',
    icon: Icons.person_outline,
  );
}

class _OfflineQrCamera extends StatefulWidget {
  const _OfflineQrCamera();
  @override
  State<_OfflineQrCamera> createState() => _OfflineQrCameraState();
}

class _OfflineQrCameraState extends State<_OfflineQrCamera> {
  final controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );
  bool captured = false;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Scan examination pass')),
    body: Column(
      children: [
        Expanded(
          child: MobileScanner(
            controller: controller,
            onDetect: (capture) {
              if (captured) return;
              for (final barcode in capture.barcodes) {
                final value = barcode.rawValue;
                if (value != null && value.isNotEmpty) {
                  captured = true;
                  Navigator.of(context).pop(value);
                  return;
                }
              }
            },
          ),
        ),
      ],
    ),
  );
}
