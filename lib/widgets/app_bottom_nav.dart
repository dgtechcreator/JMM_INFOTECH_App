import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppNavItem {
  const AppNavItem({required this.icon, required this.activeIcon, required this.label});
  final IconData icon;
  final IconData activeIcon;
  final String label;
}

/// Bottom nav with a soft pill highlight behind the active tab, instead of the plain default
/// NavigationBar look — used by both AdminShell and EmployeeShell for a consistent, more polished feel.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({super.key, required this.items, required this.currentIndex, required this.onTap});

  final List<AppNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, -4))],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(items.length, (i) {
              final active = i == currentIndex;
              final item = items[i];
              return InkWell(
                onTap: () => onTap(i),
                borderRadius: BorderRadius.circular(20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: active ? AppColors.primarySoft : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(active ? item.activeIcon : item.icon, color: active ? AppColors.primary : AppColors.textSecondary, size: 23),
                      const SizedBox(height: 3),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                          color: active ? AppColors.primary : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

/// Floating quick-actions button shown above the bottom nav (bottom-right) — opens [onTap] (typically a
/// bottom sheet of shortcuts) rather than performing an action directly.
class AppFab extends StatelessWidget {
  const AppFab({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: onTap,
      backgroundColor: AppColors.primary,
      elevation: 3,
      child: const Icon(Icons.add, color: Colors.white),
    );
  }
}

/// A row of icon+label shortcuts shown in the FAB's bottom sheet.
class QuickActionTile extends StatelessWidget {
  const QuickActionTile({super.key, required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: AppColors.primary),
      ),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      trailing: const Icon(Icons.chevron_right),
    );
  }
}

Future<void> showQuickActionsSheet(BuildContext context, List<QuickActionTile> actions) {
  return showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Align(alignment: Alignment.centerLeft, child: Text('Quick Actions', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
            ),
            ...actions,
          ],
        ),
      ),
    ),
  );
}
