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
import '../../../core/widgets/app_skeleton.dart';
import '../../examinations/application/exam_providers.dart';
import '../../examinations/domain/exam_assignment.dart';
import '../data/incident_repository.dart';
import '../domain/incident_models.dart';

class IncidentsScreen extends ConsumerStatefulWidget {
  const IncidentsScreen({super.key});

  @override
  ConsumerState<IncidentsScreen> createState() => _IncidentsScreenState();
}

class _IncidentsScreenState extends ConsumerState<IncidentsScreen> {
  final IncidentRepository _incidentRepository = IncidentRepository();

  bool _loading = false;
  bool _savingIncident = false;
  String? _error;
  List<IncidentRecord> _incidents = [];
  final TextEditingController _computerNumberController =
      TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _evidencePathController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _incidentType;
  String? _severity;
  bool _showEvidence = false;
  int? _loadedExamSessionId;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final selected = ref.read(selectedExamProvider);
      if (selected != null) {
        _refreshIncidents(selected);
      }
    });
  }

  @override
  void dispose() {
    _computerNumberController.dispose();
    _descriptionController.dispose();
    _evidencePathController.dispose();
    super.dispose();
  }

  Future<void> _refreshIncidents(ExamAssignment? assignment) async {
    if (assignment == null) {
      setState(() {
        _incidents = [];
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
      final incidents = await _incidentRepository.fetchIncidents();
      if (!mounted) return;
      final selected = ref.read(selectedExamProvider);
      if (selected?.examSessionId != assignment.examSessionId) return;
      setState(() {
        _incidents = incidents
            .where(
              (incident) =>
                  incident.examSessionId == assignment.examSessionId &&
                  incident.venueId == assignment.venueId,
            )
            .toList();
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

  Future<void> _reportIncident() async {
    final selected = ref.read(selectedExamProvider);
    if (selected == null) {
      setState(() {
        _error =
            'Select an exam on the dashboard before reporting an incident.';
      });
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _savingIncident = true;
      _error = null;
    });

    try {
      await _incidentRepository.reportIncident(
        examSessionId: selected.examSessionId,
        venueId: selected.venueId,
        computerNumber: _computerNumberController.text.trim().isNotEmpty
            ? _computerNumberController.text.trim()
            : null,
        incidentType: _incidentType!,
        severity: _severity!,
        description: _descriptionController.text.trim(),
        evidencePath: _evidencePathController.text.trim().isNotEmpty
            ? _evidencePathController.text.trim()
            : null,
      );
      if (!mounted) return;
      _computerNumberController.clear();
      _descriptionController.clear();
      _evidencePathController.clear();
      setState(() => _showEvidence = false);
      await _refreshIncidents(selected);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Incident reported successfully.')),
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
          _savingIncident = false;
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
        return 'Your session expired. Please sign in again.';
      }
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout) {
        return 'Unable to reach the server. Check your connection and try again.';
      }
      if (error.type == DioExceptionType.badResponse) {
        return 'Server returned unexpected data. Please try again later.';
      }
      return 'Unable to complete the request. Please try again.';
    }
    return 'Something went wrong while loading incidents.';
  }

  String _humanLabel(String value) => value
      .toLowerCase()
      .split('_')
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');

  Widget _surface(Widget child) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.ink.withValues(alpha: 0.06)),
    ),
    child: child,
  );

  Widget _field(String label, Widget child, {String? help}) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        label,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 6),
      child,
      if (help != null) ...[
        const SizedBox(height: 6),
        Text(
          help,
          style: const TextStyle(fontSize: 12, color: AppColors.muted),
        ),
      ],
    ],
  );

  InputDecoration _input({String? hint}) => InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: AppColors.ink.withValues(alpha: 0.2)),
    ),
    errorMaxLines: 3,
  );

  Widget _buildIncidentForm() => _surface(
    Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Report a new incident',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '* Required',
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          const SizedBox(height: 12),
          _field(
            'Incident type *',
            _buildDropdownField(
              'incident type',
              _incidentType,
              [
                'CHEATING',
                'PHONE_FOUND',
                'WRONG_VENUE',
                'MEDICAL_EMERGENCY',
                'DISTURBANCE',
                'LATE_ARRIVAL',
                'OTHER',
              ],
              (value) => setState(() => _incidentType = value),
            ),
          ),
          const SizedBox(height: 12),
          _field(
            'Severity *',
            _buildDropdownField('severity', _severity, [
              'MINOR',
              'MAJOR',
              'CRITICAL',
            ], (value) => setState(() => _severity = value)),
            help: switch (_severity) {
              'MINOR' => 'Minor: a small disruption with limited impact.',
              'MAJOR' =>
                'Major: a significant disruption or suspected misconduct.',
              'CRITICAL' =>
                'Critical: an immediate safety risk or serious emergency.',
              _ => 'Choose the level that best describes the incident.',
            },
          ),
          const SizedBox(height: 12),
          _field(
            'Student number (optional)',
            TextFormField(
              enabled: !_savingIncident,
              controller: _computerNumberController,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              decoration: _input(),
            ),
          ),
          const SizedBox(height: 12),
          _field(
            'Description *',
            TextFormField(
              enabled: !_savingIncident,
              controller: _descriptionController,
              minLines: 3,
              maxLines: 6,
              textAlignVertical: TextAlignVertical.top,
              keyboardType: TextInputType.multiline,
              decoration: _input(),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Describe the incident before submitting.'
                  : null,
            ),
            help: 'Include what happened, when, and the action taken.',
          ),
          const SizedBox(height: 12),
          if (!_showEvidence)
            OutlinedButton.icon(
              onPressed: _savingIncident
                  ? null
                  : () => setState(() => _showEvidence = true),
              icon: const Icon(Icons.link),
              label: const Text(
                'Add evidence link (optional)',
                textAlign: TextAlign.center,
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 48),
                padding: const EdgeInsets.all(12),
              ),
            )
          else ...[
            _field(
              'Evidence link (optional)',
              TextFormField(
                enabled: !_savingIncident,
                controller: _evidencePathController,
                keyboardType: TextInputType.url,
                decoration: _input(),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return null;
                  final uri = Uri.tryParse(value.trim());
                  return uri != null &&
                          ['https', 'http'].contains(uri.scheme) &&
                          uri.host.isNotEmpty
                      ? null
                      : 'Enter a valid https:// link.';
                },
              ),
              help: 'Paste a shared link to a photo or document.',
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _savingIncident
                    ? null
                    : () => setState(() {
                        _evidencePathController.clear();
                        _showEvidence = false;
                      }),
                icon: const Icon(Icons.close),
                label: const Text('Remove evidence link'),
              ),
            ),
          ],
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _savingIncident ? null : _reportIncident,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.ink,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
              padding: const EdgeInsets.all(14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              _savingIncident ? 'Reporting incident…' : 'Report incident',
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildDropdownField(
    String label,
    String? currentValue,
    List<String> options,
    ValueChanged<String> onChanged,
  ) => DropdownButtonFormField<String>(
    initialValue: currentValue,
    isExpanded: true,
    itemHeight: null,
    decoration: _input(),
    hint: Text('Select $label'),
    validator: (value) => value == null ? 'Select $label.' : null,
    items: options
        .map(
          (value) => DropdownMenuItem(
            value: value,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(_humanLabel(value)),
            ),
          ),
        )
        .toList(),
    onChanged: _savingIncident
        ? null
        : (value) {
            if (value != null) onChanged(value);
          },
  );

  Widget _buildIncidentList() {
    if (_incidents.isEmpty) {
      return const AppEmptyState(
        title: 'No incidents reported',
        message: 'No incidents have been reported for this selected exam yet.',
        icon: Icons.report_outlined,
      );
    }

    return Column(children: _incidents.map(_buildIncidentRow).toList());
  }

  Widget _buildIncidentRow(IncidentRecord incident) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: _surface(
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'ID ${incident.incidentId}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'NotoSansMono',
                      color: AppColors.ink,
                    ),
                  ),
                ),
                AppBadge.status(incident.severity),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '${incident.incidentType.replaceAll('_', ' ')} • Venue ${incident.venueId}',
              style: const TextStyle(fontSize: 13, color: AppColors.muted),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              incident.description,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.ink,
                height: 1.4,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                if (incident.computerNumber.isNotEmpty)
                  Expanded(
                    child: Text(
                      'Student: ${incident.computerNumber}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                Expanded(
                  child: Text(
                    'Reported: ${incident.createdAt}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.muted,
                    ),
                  ),
                ),
              ],
            ),
            if (incident.evidencePath.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Evidence: ${incident.evidencePath}',
                style: const TextStyle(fontSize: 13, color: AppColors.muted),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWorkspace() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 960;
        final form = _buildIncidentForm();
        final list = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppSectionHeader(title: 'Recent incidents (${_incidents.length})'),
            const SizedBox(height: AppSpacing.lg),
            if (_loading)
              const AppPageSkeleton(showMetrics: false)
            else
              _buildIncidentList(),
          ],
        );

        if (!wide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [form, const SizedBox(height: 16), list],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: form),
            const SizedBox(width: AppSpacing.grid),
            Expanded(child: list),
          ],
        );
      },
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
      _refreshIncidents(next);
    });

    return AppPageBody(
      onRefresh: () => _refreshIncidents(ref.read(selectedExamProvider)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Incident reporting',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 16),
          if (selected == null) ...[
            const AppEmptyState(
              title: 'No exam selected',
              message:
                  'Choose an assigned exam on the dashboard before reporting or reviewing incidents.',
              icon: Icons.report_outlined,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'Go to dashboard',
              onPressed: () => context.go('/'),
            ),
          ] else ...[
            _surface(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Reporting for',
                    style: TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    selected.courseCode,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(selected.venueName),
                  const SizedBox(height: 4),
                  Text(
                    selected.timeRangeLabel,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_error != null) ...[
              AppErrorBanner(
                message: _error!,
                onRetry: () => _refreshIncidents(selected),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            _buildWorkspace(),
          ],
        ],
      ),
    );
  }
}
