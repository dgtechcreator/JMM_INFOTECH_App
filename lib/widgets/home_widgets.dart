import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Small building blocks shared by the redesigned Employee and Admin Home screens, so both read as one system.

/// White rounded card with an optional title row ("Today's tasks ........ View all").
class HomeCard extends StatelessWidget {
  const HomeCard({super.key, this.title, this.action, this.onAction, required this.child, this.margin = const EdgeInsets.only(bottom: 14), this.trailing});

  final String? title;

  /// Text of the small orange link on the right of the title ("View all", "Apply").
  final String? action;
  final VoidCallback? onAction;
  final Widget? trailing;
  final Widget child;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Expanded(child: Text(title!, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
                  ?trailing,
                  if (action != null)
                    InkWell(
                      onTap: onAction,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        child: Text(action!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
                      ),
                    ),
                ],
              ),
            ),
          child,
        ],
      ),
    );
  }
}

/// "2 / Present days" tile with a coloured top edge.
class HomeStatTile extends StatelessWidget {
  const HomeStatTile({super.key, required this.value, required this.label, required this.color, this.onTap});

  final String value;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(height: 4, color: color),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class QuickActionItem {
  const QuickActionItem(this.label, this.icon, this.color, this.onTap);
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
}

/// 4-column grid of rounded icon tiles with a caption underneath.
class QuickActionGrid extends StatelessWidget {
  const QuickActionGrid({super.key, required this.items, this.columns = 4});

  final List<QuickActionItem> items;
  final int columns;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      const gap = 6.0;
      final cellWidth = (constraints.maxWidth - gap * (columns - 1)) / columns;
      return Wrap(
        spacing: gap,
        runSpacing: 14,
        children: [
          for (final a in items)
            SizedBox(
              width: cellWidth,
              child: InkWell(
                onTap: a.onTap,
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Column(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(color: a.color.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(16)),
                        child: Icon(a.icon, color: a.color, size: 24),
                      ),
                      const SizedBox(height: 6),
                      Text(a.label, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, height: 1.2)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      );
    });
  }
}

/// A coloured pill like "Due soon" / "Present".
class HomePill extends StatelessWidget {
  const HomePill(this.text, this.color, {super.key});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

/// One row in a Home list: leading widget, title + grey subtitle, trailing widget.
class HomeListRow extends StatelessWidget {
  const HomeListRow({super.key, required this.leading, required this.title, required this.subtitle, this.trailing, this.onTap, this.divider = true});

  final Widget leading;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (divider) const Divider(height: 1, color: AppColors.border),
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                leading,
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: 8), trailing!],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Rounded icon box used as the leading widget of a [HomeListRow].
class IconBox extends StatelessWidget {
  const IconBox(this.icon, this.color, {super.key, this.size = 38});
  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)),
      child: Icon(icon, color: color, size: size * 0.52),
    );
  }
}

/// Round initials avatar for a person row.
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar(this.initials, this.color, {super.key, this.size = 38});
  final String initials;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
      child: Text(initials, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: size * 0.34)),
    );
  }
}
