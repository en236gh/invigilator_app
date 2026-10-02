import 'package:flutter/material.dart';

class AttendanceStatusSummary extends StatelessWidget {
  const AttendanceStatusSummary({
    super.key,
    required this.connection,
    required this.pending,
    required this.completed,
    required this.review,
    required this.onPending,
    required this.onCompleted,
    required this.onReview,
  });

  final String connection;
  final int pending, completed, review;
  final VoidCallback onPending, onCompleted, onReview;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Connection: $connection',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _StatusAction(
              count: review,
              title: 'Needs review',
              description: review == 0
                  ? 'No rejected scans.'
                  : 'Rejected scans need your attention.',
              action: 'Review rejected scans',
              icon: Icons.error_outline,
              emphasized: review > 0,
              onPressed: onReview,
            ),
            _StatusAction(
              count: pending,
              title: 'Pending',
              description: 'Waiting for server verification.',
              action: 'View pending scans',
              icon: Icons.schedule,
              onPressed: onPending,
            ),
            _StatusAction(
              count: completed,
              title: 'Completed',
              description: 'Server confirmed attendance exists.',
              action: 'View completed scans',
              icon: Icons.check_circle_outline,
              onPressed: onCompleted,
            ),
          ],
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _StatusAction extends StatelessWidget {
  const _StatusAction({
    required this.count,
    required this.title,
    required this.description,
    required this.action,
    required this.icon,
    required this.onPressed,
    this.emphasized = false,
  });

  final int count;
  final String title, description, action;
  final IconData icon;
  final VoidCallback onPressed;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      width: 240,
      child: Card(
        margin: EdgeInsets.zero,
        color: emphasized ? colors.errorContainer : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: DefaultTextStyle.merge(
            style: emphasized
                ? TextStyle(color: colors.onErrorContainer)
                : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count $title',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(description),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  style: emphasized
                      ? OutlinedButton.styleFrom(
                          foregroundColor: colors.onErrorContainer,
                          side: BorderSide(color: colors.onErrorContainer),
                        )
                      : null,
                  onPressed: onPressed,
                  icon: Icon(icon),
                  label: Text(action),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
