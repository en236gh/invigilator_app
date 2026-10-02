import 'dart:convert';
import 'package:flutter/material.dart';

enum ScanHistoryFilter { all, pending, review, completed }

class ScanHistoryPanel extends StatefulWidget {
  const ScanHistoryPanel({
    super.key,
    required this.scans,
    this.initialFilter = ScanHistoryFilter.all,
  });
  final ScanHistoryFilter initialFilter;
  final List<Map<String, Object?>> scans;

  @override
  State<ScanHistoryPanel> createState() => _ScanHistoryPanelState();
}

class _ScanHistoryPanelState extends State<ScanHistoryPanel> {
  static const _pageSize = 20;
  final _search = TextEditingController();
  late ScanHistoryFilter _filter = widget.initialFilter;
  int _page = 0;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final matches = widget.scans.where((scan) {
      final outcome = scan['outcome'];
      final included = switch (_filter) {
        ScanHistoryFilter.all => true,
        ScanHistoryFilter.pending => outcome == null,
        ScanHistoryFilter.review => outcome == 'REJECTED',
        ScanHistoryFilter.completed =>
          outcome == 'ACCEPTED' || outcome == 'ALREADY_RECORDED',
      };
      if (!included) return false;
      if (query.isEmpty) return true;
      final payload = jsonDecode(scan['payload'] as String) as Map;
      return [
            scan['student'],
            scan['assignment'],
            payload['computerNumber'],
            scan['reason'],
            scan['message'],
          ]
          .where((value) => value != null)
          .any((value) => value.toString().toLowerCase().contains(query));
    }).toList();
    final pages = (matches.length / _pageSize).ceil();
    // Sync may move rows between filters while this page is open.
    final page = pages == 0 ? 0 : _page.clamp(0, pages - 1);
    final start = page * _pageSize;
    final visible = matches.skip(start).take(_pageSize);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Scan history', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        TextField(
          controller: _search,
          decoration: InputDecoration(
            labelText: 'Search scans',
            hintText: 'Student, computer number, exam or rejection',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: query.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    icon: const Icon(Icons.clear),
                    onPressed: () => setState(() {
                      _search.clear();
                      _page = 0;
                    }),
                  ),
          ),
          onChanged: (_) => setState(() => _page = 0),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final filter in ScanHistoryFilter.values)
              ChoiceChip(
                label: Text(switch (filter) {
                  ScanHistoryFilter.all => 'All',
                  ScanHistoryFilter.pending => 'Pending',
                  ScanHistoryFilter.review => 'Needs review',
                  ScanHistoryFilter.completed => 'Completed',
                }),
                selected: _filter == filter,
                onSelected: (_) => setState(() {
                  _filter = filter;
                  _page = 0;
                }),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (matches.isEmpty)
          Text(
            widget.scans.isEmpty
                ? 'No scans saved on this device for this account.'
                : 'No scans match this search and filter.',
          )
        else ...[
          Text(
            'Showing ${start + 1}–${(start + _pageSize).clamp(0, matches.length)} of ${matches.length} scans',
          ),
          for (final scan in visible)
            Builder(
              builder: (context) {
                final payload = jsonDecode(scan['payload'] as String) as Map;
                final outcome = scan['outcome'];
                final capturedAt = payload['capturedAt']?.toString() ?? '';
                final captured = DateTime.tryParse(capturedAt)?.toLocal();
                final time = captured == null
                    ? 'Capture time unavailable'
                    : 'Captured ${captured.hour.toString().padLeft(2, '0')}:${captured.minute.toString().padLeft(2, '0')}';
                final summary = switch (outcome) {
                  null => 'Pending server verification',
                  'ACCEPTED' => 'New attendance recorded',
                  'ALREADY_RECORDED' =>
                    'Already recorded · no new attendance added',
                  'REJECTED' => 'Needs review · attendance not recorded',
                  _ => 'Result unavailable · check details',
                };
                return Card(
                  child: ExpansionTile(
                    key: ValueKey(scan['scanId'] ?? scan['payload']),
                    leading: Icon(switch (outcome) {
                      null => Icons.schedule,
                      'ACCEPTED' => Icons.check_circle_outline,
                      'ALREADY_RECORDED' => Icons.task_alt,
                      _ => Icons.warning_amber_rounded,
                    }),
                    title: Text(
                      '${scan['student']} · ${payload['computerNumber']}',
                    ),
                    subtitle: Text('${scan['assignment']}\n$time\n$summary'),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    expandedCrossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Captured at: ${capturedAt.isEmpty ? "Unavailable" : capturedAt}',
                      ),
                      if (outcome == 'ALREADY_RECORDED')
                        const Text(
                          'The server already has attendance for this student. This scan did not create another attendance record.',
                        ),
                      if (scan['reason'] != null)
                        Text('Reason: ${scan['reason']}'),
                      if (scan['message'] != null)
                        Text('Server message: ${scan['message']}'),
                      if (outcome == 'REJECTED') ...[
                        const SizedBox(height: 8),
                        const Text(
                          'Next steps: Resolve the issue with examination staff, refresh the roster, then capture a new scan if appropriate. This history is retained.',
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),

          Wrap(
            spacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: page == 0
                    ? null
                    : () => setState(() => _page = page - 1),
                icon: const Icon(Icons.chevron_left),
                label: const Text('Previous'),
              ),
              Text('Page ${page + 1} of $pages'),
              OutlinedButton.icon(
                onPressed: page + 1 >= pages
                    ? null
                    : () => setState(() => _page = page + 1),
                icon: const Icon(Icons.chevron_right),
                label: const Text('Next'),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
