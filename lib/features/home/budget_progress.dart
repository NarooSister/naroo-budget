import 'package:flutter/material.dart';

import '../../app/theme/naroo_colors.dart';
import '../../app/theme/naroo_spacing.dart';
import '../../app/theme/naroo_text.dart';
import '../../core/money_format.dart';

/// Spent / budget line, progress bar and remaining or exceeded amount.
class BudgetProgress extends StatelessWidget {
  const BudgetProgress({super.key, required this.spent, required this.budget});

  final int spent;
  final int budget;

  @override
  Widget build(BuildContext context) {
    final remaining = budget - spent;
    final over = remaining < 0;
    final ratio = budget == 0 ? (spent > 0 ? 1.0 : 0.0) : spent / budget;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${MoneyFormat.krw(spent)} / ${MoneyFormat.krw(budget)}원',
                style: NarooText.money(NarooText.body, NarooColors.textPrimary),
              ),
            ),
            Text(
              over
                  ? '${MoneyFormat.krw(remaining)}원 초과'
                  : '${MoneyFormat.krw(remaining)}원 남음',
              style: NarooText.bodySecondary.copyWith(
                color: over ? NarooColors.expense : NarooColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: NarooSpacing.space8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio.clamp(0.0, 1.0),
            minHeight: 8,
            backgroundColor: NarooColors.surfaceSubtle,
            color: over ? NarooColors.expense : NarooColors.primary,
          ),
        ),
      ],
    );
  }
}
