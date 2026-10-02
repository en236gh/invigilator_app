import 'package:flutter/material.dart';
import '../../../core/widgets/app_panel.dart';
import '../../offline/domain/offline_snapshot.dart';

class RosterDetailsPanel extends StatelessWidget {
  const RosterDetailsPanel({
    super.key,
    required this.snapshot,
    required this.metadata,
    required this.now,
  });

  final OfflineSnapshot snapshot;
  final Map<String, Object?>? metadata;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final downloaded = DateTime.tryParse(
      '${metadata?['downloadedAt']}',
    )?.toLocal();
    final localNow = now.toLocal();
    String timestamp(DateTime value) {
      final local = value.toLocal();
      final day = DateUtils.isSameDay(local, localNow)
          ? 'today'
          : DateUtils.isSameDay(
              local,
              DateTime(localNow.year, localNow.month, localNow.day - 1),
            )
          ? 'yesterday'
          : localizations.formatMediumDate(local);
      return '$day, ${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(local), alwaysUse24HourFormat: true)}';
    }

    final failureValue = metadata?['photoFailures'];
    final failures = failureValue is int ? failureValue : null;
    final photoReferences = snapshot.students
        .map((s) => '${s['photoPath'] ?? ''}')
        .toSet()
        .length;
    final colors = Theme.of(context).colorScheme;
    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Downloaded roster',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.download_done),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  downloaded == null
                      ? 'Download time unavailable'
                      : 'Downloaded ${timestamp(downloaded)}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 24,
            runSpacing: 16,
            children: [
              _RosterField(
                label: 'Roster generated',
                value: timestamp(snapshot.generatedAt),
              ),
              _RosterField(
                label: 'Student entries',
                value: '${snapshot.students.length}',
              ),
              _RosterField(
                label: 'Photo downloads',
                value: failures == null
                    ? 'Download status unavailable'
                    : '${(photoReferences - failures).clamp(0, photoReferences)} downloaded · $failures unavailable',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.tertiaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: colors.onTertiaryContainer,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Roster may have changed since download. Refresh before each examination. Assignments, eligibility and attendance are checked again during sync.',
                    style: TextStyle(color: colors.onTertiaryContainer),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Assigned exams and venues (${snapshot.assignments.length})',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (snapshot.assignments.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('No assigned exams in this download.'),
            ),
          for (final assignment in snapshot.assignments) ...[
            const Divider(height: 24),
            Text(
              '${assignment['courseCode'] ?? 'Course unavailable'}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 24,
              runSpacing: 12,
              children: [
                _RosterField(
                  label: 'Venue',
                  value: '${assignment['venueName'] ?? 'Unavailable'}',
                ),
                _RosterField(
                  label: 'Exam date',
                  value: _examDate(localizations, assignment['examDate']),
                ),
                _RosterField(
                  label: 'Time',
                  value:
                      '${_examTime(assignment['startTime'])}–${_examTime(assignment['endTime'])}',
                ),
                _RosterField(
                  label: 'Downloaded status',
                  value: '${assignment['status'] ?? 'Unavailable'}'
                      .replaceAll('_', ' ')
                      .toLowerCase(),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _examDate(MaterialLocalizations localizations, Object? value) {
    final date = DateTime.tryParse('$value');
    return date == null ? 'Unavailable' : localizations.formatMediumDate(date);
  }

  String _examTime(Object? value) {
    final match = RegExp(
      r'^(\d{2}:\d{2})(?::\d{2}(?:\.\d+)?)?$',
    ).firstMatch('$value');
    return match?.group(1) ?? 'Unavailable';
  }
}

class _RosterField extends StatelessWidget {
  const _RosterField({required this.label, required this.value});
  final String label, value;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 220,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 4),
        Text(value, style: Theme.of(context).textTheme.bodyLarge),
      ],
    ),
  );
}
