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
  String _incidentType = 'PHONE_FOUND';
  String _severity = 'MAJOR';
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
    if (_descriptionController.text.trim().isEmpty) {
      setState(() {
        _error = 'Describe the incident before submitting.';
      });
      return;
    }

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
        incidentType: _incidentType,
        description: _descriptionController.text.trim(),
        evidencePath: _evidencePathController.text.trim().isNotEmpty
            ? _evidencePathController.text.trim()
            : null,
      );
      if (!mounted) return;
      _computerNumberController.clear();
      _descriptionController.clear();
      _evidencePathController.clear();
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

  Widget _buildIncidentForm() {
    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Report a new incident',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: _buildDropdownField(
                  'Type',
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
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _buildDropdownField('Severity', _severity, [
                  'MINOR',
                  'MAJOR',
                  'CRITICAL',
                ], (value) => setState(() => _severity = value)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _computerNumberController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Student computer number (optional)',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _descriptionController,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Description'),
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _evidencePathController,
            decoration: const InputDecoration(
              labelText: 'Evidence path (optional)',
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: 'Report incident',
            loading: _savingIncident,
            onPressed: _reportIncident,
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Incidents are recorded against the exam selected on the dashboard.',
            style: TextStyle(fontSize: 13, color: AppColors.muted),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownField(
    String label,
    String currentValue,
    List<String> options,
    ValueChanged<String> onChanged,
  ) {
    return DropdownButtonFormField<String>(
      initialValue: currentValue,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: options
          .map(
            (value) => DropdownMenuItem(
              value: value,
              child: Text(
                value.replaceAll('_', ' '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
    );
  }

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
      child: AppPanel(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
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
            const AppSectionHeader(
              title: 'Recent incidents',
              subtitle: 'Reports for the selected exam session.',
            ),
            const SizedBox(height: AppSpacing.lg),
            _buildIncidentList(),
          ],
        );

        if (!wide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              form,
              const SizedBox(height: AppSpacing.xl),
              list,
            ],
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppPageHeader(
            title: 'Incident reporting',
            subtitle:
                'Log exam incidents against the exam selected on the dashboard.',
          ),
          const SizedBox(height: AppSpacing.xl),
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
            if (_error != null) ...[
              AppErrorBanner(
                message: _error!,
                onRetry: () => _refreshIncidents(selected),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            if (_loading)
              const AppPageSkeleton(showMetrics: false)
            else
              _buildWorkspace(),
          ],
        ],
      ),
    );
  }
}
