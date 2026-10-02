import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/constants/app_colors.dart';
import '../../../core/widgets/app_canvas.dart';
import '../../../core/widgets/app_panel.dart';
import '../../offline/application/offline_controller.dart';
import '../../offline/presentation/offline_typography.dart';
import '../../offline/presentation/offline_download_popup.dart';

class SyncStatusScreen extends ConsumerStatefulWidget {
  const SyncStatusScreen({super.key});
  @override
  ConsumerState<SyncStatusScreen> createState() => _SyncStatusScreenState();
}

class _SyncStatusScreenState extends ConsumerState<SyncStatusScreen> {
  bool _started = false;
  String? _owner;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(offlineProvider);
    if (_owner != state.owner) {
      _owner = state.owner;
      _started = false;
    }
    final pending = state.scans.where((s) => s['outcome'] == null).toList();
    final completed = state.scans
        .where(
          (s) =>
              s['outcome'] == 'ACCEPTED' || s['outcome'] == 'ALREADY_RECORDED',
        )
        .toList();
    final review = state.scans
        .where((s) => s['outcome'] == 'REJECTED')
        .toList();
    final finished = _started && !state.syncing;
    final successful =
        finished && pending.isEmpty && review.isEmpty && completed.isNotEmpty;
    return Theme(
      data: OfflineTypography.theme(Theme.of(context)),
      child: Stack(
        children: [
          AppPageBody(
            onRefresh: state.load,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Sync', style: OfflineTypography.pageTitle),
                const SizedBox(height: 24),
                if (state.loading && !state.syncing)
                  const LinearProgressIndicator(color: AppColors.brandGold)
                else ...[
                  if (state.syncing) ...[
                    Text(
                      '${pending.length} pending · ${completed.length} synced',
                      style: OfflineTypography.supporting,
                    ),
                  ] else if (finished) ...[
                    Icon(
                      successful ? Icons.task_alt : Icons.info_outline,
                      color: AppColors.ink,
                      size: 36,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      successful
                          ? 'Sync successful'
                          : pending.isNotEmpty
                          ? 'Sync incomplete'
                          : 'Sync finished',
                      style: OfflineTypography.heading,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      successful
                          ? 'Attendance recorded'
                          : '${pending.length} pending · ${review.length} need attention',
                      style: OfflineTypography.body,
                    ),
                  ] else
                    Text('Scanned students', style: OfflineTypography.heading),
                  if (state.requiresSignIn) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'Sign in with the same account to sync attendance.',
                      style: OfflineTypography.supporting,
                    ),
                    TextButton(
                      onPressed: () => context.go('/login'),
                      child: const Text('Sign in'),
                    ),
                  ],
                  if (finished && pending.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'Check your connection and try again. Your saved entries are kept.',
                      style: OfflineTypography.supporting,
                    ),
                  ],
                  const SizedBox(height: 20),
                  if (!state.syncing && pending.isNotEmpty)
                    FilledButton.icon(
                      onPressed: state.requiresSignIn
                          ? null
                          : () {
                              setState(() => _started = true);
                              state.sync();
                            },
                      icon: const Icon(Icons.sync),
                      label: Text(finished ? 'Retry sync' : 'Sync to server'),
                    ),
                  const SizedBox(height: 20),
                  if (state.scans.isEmpty)
                    const AppPanel(
                      child: Text(
                        'No students scanned yet.',
                        style: OfflineTypography.body,
                      ),
                    ),
                  if (pending.isNotEmpty)
                    _students('Pending (${pending.length})', pending),
                  if (completed.isNotEmpty)
                    _students('Synced (${completed.length})', completed),
                  if (review.isNotEmpty)
                    _students('Needs attention (${review.length})', review),
                ],
              ],
            ),
          ),
          if (state.syncing)
            Positioned.fill(
              child: OfflineDownloadPopup(
                progress: state.syncProgress,
                title: 'Syncing attendance',
                showPercentage: true,
              ),
            ),
        ],
      ),
    );
  }

  Widget _students(String title, List<Map<String, Object?>> scans) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(title, style: OfflineTypography.heading),
      const SizedBox(height: 12),
      for (final scan in scans)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: AppPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${scan['student']}', style: OfflineTypography.action),
                const SizedBox(height: 4),
                Text(
                  '${(jsonDecode(scan['payload'] as String) as Map)['computerNumber']} · ${scan['assignment']}',
                  style: OfflineTypography.supporting,
                ),
                const SizedBox(height: 8),
                Text(switch (scan['outcome']) {
                  'ACCEPTED' => 'Attendance recorded',
                  'ALREADY_RECORDED' => 'Attendance already recorded',
                  'REJECTED' => 'Attendance not recorded',
                  _ => 'Pending',
                }, style: OfflineTypography.body),
                if (scan['outcome'] == 'REJECTED' && scan['message'] != null)
                  Text(
                    '${scan['message']}',
                    style: OfflineTypography.supporting,
                  ),
              ],
            ),
          ),
        ),
      const SizedBox(height: 12),
    ],
  );
}
