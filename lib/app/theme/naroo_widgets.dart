import 'package:flutter/material.dart';

import 'naroo_colors.dart';
import 'naroo_icons.dart';
import 'naroo_spacing.dart';
import 'naroo_text.dart';

/// App wordmark. The period uses the warm terracotta already used for expenses.
class NarooWordmark extends StatelessWidget {
  const NarooWordmark({super.key, this.style = NarooText.display});

  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          const TextSpan(text: 'NAROO'),
          TextSpan(
            text: '.',
            style: style.copyWith(color: NarooColors.expense),
          ),
        ],
      ),
    );
  }
}

/// 20dp spinner used inside a button while an action is in progress.
class NarooButtonProgress extends StatelessWidget {
  const NarooButtonProgress({super.key, this.color = NarooColors.onPrimary});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 20,
      child: CircularProgressIndicator(strokeWidth: 2, color: color),
    );
  }
}

class NarooGrabHandle extends StatelessWidget {
  const NarooGrabHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 36,
        height: 4,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: NarooColors.surfaceSubtle,
            borderRadius: BorderRadius.all(Radius.circular(2)),
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet chrome: grab handle, title, and close button.
class NarooBottomSheet extends StatelessWidget {
  const NarooBottomSheet({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        NarooSpacing.space20,
        NarooSpacing.space12,
        NarooSpacing.space20,
        bottomInset + NarooSpacing.space16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const NarooGrabHandle(),
            const SizedBox(height: NarooSpacing.space12),
            Row(
              children: [
                Expanded(child: Text(title, style: NarooText.display)),
                IconButton(
                  tooltip: '닫기',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(NarooIcons.close, size: NarooIcons.action),
                ),
              ],
            ),
            const SizedBox(height: NarooSpacing.space16),
            child,
          ],
        ),
      ),
    );
  }
}

class NarooEmptyState extends StatelessWidget {
  const NarooEmptyState({
    super.key,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          NarooIcons.transactions,
          size: NarooIcons.action,
          color: NarooColors.textTertiary,
        ),
        const SizedBox(height: NarooSpacing.space8),
        Text(
          message,
          style: NarooText.bodySecondary,
          textAlign: TextAlign.center,
        ),
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: NarooSpacing.space4),
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ],
    );
  }
}

/// 4-column category tile: 72dp tall, 16 radius, icon above 13sp label.
class NarooCategoryChip extends StatelessWidget {
  const NarooCategoryChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? NarooColors.primary : NarooColors.textPrimary;

    return Material(
      color: selected ? NarooColors.primaryLight : NarooColors.surfaceMuted,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(NarooRadius.chip),
        side: selected
            ? const BorderSide(color: NarooColors.primary, width: 1.5)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NarooRadius.chip),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: NarooSpacing.space4,
            vertical: NarooSpacing.space8,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                NarooIcons.categoryIcon(label),
                size: NarooIcons.category,
                color: color,
              ),
              const SizedBox(height: NarooSpacing.space4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: NarooText.body.copyWith(
                  fontSize: 13,
                  height: 16 / 13,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Category mark shown beside a transaction row.
class NarooCategoryBadge extends StatelessWidget {
  const NarooCategoryBadge({super.key, required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: NarooColors.surfaceMuted,
        shape: BoxShape.circle,
      ),
      child: Icon(
        NarooIcons.categoryIcon(name),
        size: NarooIcons.list,
        color: NarooColors.textSecondary,
      ),
    );
  }
}
