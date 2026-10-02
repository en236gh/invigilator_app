import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/constants/app_colors.dart';
import '../../../app/constants/app_spacing.dart';
import '../../../core/widgets/app_canvas.dart';
import '../../../core/widgets/app_panel.dart';
import '../../offline/application/offline_controller.dart';
import '../../offline/presentation/offline_verification_flow.dart';
import '../../offline/presentation/offline_typography.dart';

class OfflineAttendanceScreen extends ConsumerStatefulWidget {
  const OfflineAttendanceScreen({super.key});

  @override
  ConsumerState<OfflineAttendanceScreen> createState() =>
      _OfflineAttendanceScreenState();
}

class _OfflineAttendanceScreenState
    extends ConsumerState<OfflineAttendanceScreen> {
  String? _method;
  Map<String, dynamic>? _assignment;
  int _page = 0;

  Widget _methodTile(String method, String title, IconData icon) {
    return AppPanel(
      onTap: () => setState(() => _method = method),
      padding: const EdgeInsets.all(AppSpacing.lg),
      borderColor: _method == method ? AppColors.ink : null,
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
              children: [Text(title, style: OfflineTypography.heading)],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: OfflineTypography.theme(Theme.of(context)),
    child: PopScope(
      canPop: _assignment == null,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || _assignment == null) return;
        setState(() {
          if (_method != null) {
            _method = null;
          } else {
            _assignment = null;
          }
        });
      },
      child: Builder(builder: _buildFlow),
    ),
  );

  Widget _buildFlow(BuildContext context) {
    final state = ref.watch(offlineProvider);
    final assignments =
        state.snapshot?.assignments
            .where(
              (a) => a['status'] != 'COMPLETED' && a['status'] != 'CANCELLED',
            )
            .toList() ??
        [];
    if (_assignment != null &&
        !assignments.any(
          (a) =>
              a['examSessionId'] == _assignment!['examSessionId'] &&
              a['venueId'] == _assignment!['venueId'],
        )) {
      _assignment = null;
      _method = null;
    }
    if (_method != null && _assignment != null) {
      return AppPageBody(
        scrollable: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: state.load,
                child: OfflineVerificationFlow(
                  key: ValueKey((
                    state.owner,
                    state.snapshot?.id,
                    _assignment!['examSessionId'],
                    _assignment!['venueId'],
                    _method,
                  )),
                  assignment: _assignment!,
                  method: _method!,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _backButton(() => setState(() => _method = null)),
          ],
        ),
      );
    }
    return Column(
      children: [
        Expanded(
          child: AppPageBody(
            onRefresh: state.load,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    'Offline attendance',
                    style: OfflineTypography.pageTitle,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                if (_assignment == null) ...[
                  Semantics(
                    header: true,
                    child: Text(
                      'Select exam or venue',
                      style: OfflineTypography.heading,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (state.loading)
                    const LinearProgressIndicator(color: AppColors.brandGold)
                  else if (assignments.isNotEmpty) ...[
                    SizedBox(
                      height:
                          280 * MediaQuery.textScalerOf(context).scale(16) / 16,
                      child: PageView.builder(
                        itemCount: assignments.length,
                        onPageChanged: (page) => setState(() => _page = page),
                        itemBuilder: (context, index) {
                          final exam = assignments[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: AppPanel(
                              onTap: () => setState(() => _assignment = exam),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const Icon(
                                    Icons.event_note_outlined,
                                    color: AppColors.ink,
                                    size: 32,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    '${exam['courseCode']}',
                                    style: OfflineTypography.heading,
                                  ),
                                  Text(
                                    '${exam['venueName']}',
                                    style: OfflineTypography.body,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${exam['examDate']}',
                                    style: OfflineTypography.supporting,
                                  ),
                                  Text(
                                    '${exam['startTime']}–${exam['endTime']}',
                                    style: OfflineTypography.supporting,
                                  ),
                                  const Spacer(),
                                  FilledButton(
                                    onPressed: () =>
                                        setState(() => _assignment = exam),
                                    child: const Text('Select exam and venue'),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    if (assignments.length > 1) ...[
                      const SizedBox(height: AppSpacing.md),
                      Semantics(
                        label: 'Exam ${_page + 1} of ${assignments.length}',
                        liveRegion: true,
                        child: Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (
                              var index = 0;
                              index < assignments.length;
                              index++
                            )
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeInOut,
                                width: index == _page ? 24 : 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: index == _page
                                      ? AppColors.ink
                                      : AppColors.ink.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ] else
                    AppPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'No exams available. Download your assigned exam data while online.',
                          ),
                          const SizedBox(height: AppSpacing.md),
                          FilledButton.icon(
                            onPressed: !state.authenticated || state.downloading
                                ? null
                                : state.download,
                            icon: const Icon(Icons.download),
                            label: Text(
                              state.downloading
                                  ? 'Downloading exam data…'
                                  : 'Download exam data',
                            ),
                          ),
                          if (state.downloadError != null)
                            Text(state.downloadError!),
                        ],
                      ),
                    ),
                ] else ...[
                  Text(
                    '${_assignment!['courseCode']} · ${_assignment!['venueName']}',
                    style: OfflineTypography.supporting,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Semantics(
                    header: true,
                    child: Text(
                      'Verification methods',
                      style: OfflineTypography.heading,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final computer = _methodTile(
                        'COMPUTER',
                        'Computer number',
                        Icons.keyboard_alt_outlined,
                      );
                      final qr = _methodTile(
                        'QR_CODE',
                        'QR code',
                        Icons.qr_code_2_outlined,
                      );
                      if (constraints.maxWidth > 700) {
                        return Row(
                          children: [
                            Expanded(child: computer),
                            const SizedBox(width: AppSpacing.grid),
                            Expanded(child: qr),
                          ],
                        );
                      }
                      return Column(
                        children: [
                          qr,
                          const SizedBox(height: AppSpacing.md),
                          computer,
                        ],
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
        if (_assignment != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageHorizontal,
              0,
              AppSpacing.pageHorizontal,
              AppSpacing.pageVertical,
            ),
            child: _backButton(
              () => setState(() {
                _assignment = null;
                _method = null;
                _page = 0;
              }),
            ),
          ),
      ],
    );
  }

  Widget _backButton(VoidCallback onPressed) => SafeArea(
    top: false,
    child: Align(
      alignment: Alignment.centerLeft,
      child: IconButton.filled(
        onPressed: onPressed,
        tooltip: 'Back',
        style: IconButton.styleFrom(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          minimumSize: const Size(48, 48),
        ),
        icon: const Icon(Icons.arrow_back),
      ),
    ),
  );
}
