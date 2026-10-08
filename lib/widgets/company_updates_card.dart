import 'package:flutter/material.dart';

import '../models/home_models.dart';
import '../theme/app_theme.dart';

/// The "Company updates" card shared by the Employee and Admin Home screens: what is happening today
/// (birthdays, holidays, events), live notices and what is coming up. Tapping "View all" opens the full screen.
class CompanyUpdatesCard extends StatelessWidget {
  const CompanyUpdatesCard({
    super.key,
    required this.updates,
    required this.onViewAll,
    this.loading = false,
    this.title = 'Company updates',
    this.maxItems = 4,
  });

  final List<CompanyUpdate> updates;
  final VoidCallback onViewAll;
  final bool loading;
  final String title;
  final int maxItems;

  @override
  Widget build(BuildContext context) {
    final shown = CompanyUpdate.pick(updates, maxItems);
    final newCount = updates.where((u) => u.isNew).length;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 5, color: AppColors.primary),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                        if (newCount > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(10)),
                            child: Text('$newCount new', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                          ),
                        ],
                        const Spacer(),
                        InkWell(
                          onTap: onViewAll,
                          borderRadius: BorderRadius.circular(8),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            child: Text('View all', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (loading && updates.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
                      )
                    else if (shown.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text('No notices or events right now.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                      )
                    else
                      for (var i = 0; i < shown.length; i++) ...[
                        if (i > 0) const Divider(height: 18, color: AppColors.border),
                        UpdateRow(update: shown[i], onTap: onViewAll),
                      ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One compact line of the card: tinted icon, title, grey subtitle and an unread dot.
class UpdateRow extends StatelessWidget {
  const UpdateRow({super.key, required this.update, this.onTap});

  final CompanyUpdate update;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = update.color;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)),
            child: Icon(update.icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(update.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(update.subtitle(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          if (update.isNew) Container(width: 9, height: 9, decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
        ],
      ),
    );
  }
}
