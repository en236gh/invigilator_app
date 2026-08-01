import 'package:flutter/material.dart';

import '../../../app/constants/app_colors.dart';
import '../../../app/constants/app_spacing.dart';
import '../../../core/widgets/app_canvas.dart';
import '../../../core/widgets/app_metric_tile.dart';
import '../../../core/widgets/app_page_header.dart';
import '../../../core/widgets/app_panel.dart';

class SyncStatusScreen extends StatelessWidget {
  const SyncStatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppPageHeader(
            title: 'Sync status',
            subtitle: 'Review offline queue health and recent upload activity.',
          ),
          const SizedBox(height: AppSpacing.xl),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 900 ? 3 : 1;
              return GridView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: AppSpacing.grid,
                  mainAxisSpacing: AppSpacing.grid,
                  mainAxisExtent: 148,
                ),
                children: const [
                  AppMetricTile(label: 'Queued uploads', value: '12'),
                  AppMetricTile(label: 'Synced today', value: '84', valueColor: AppColors.brandGreen),
                  AppMetricTile(label: 'Failed items', value: '2', valueColor: AppColors.brandRed),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.xl),
          const AppPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sync guidance',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.ink),
                ),
                SizedBox(height: AppSpacing.md),
                Text(
                  'Queued items upload automatically when connectivity returns. Failed items need attention before the next examination block.',
                  style: TextStyle(fontSize: 14, color: AppColors.muted, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
