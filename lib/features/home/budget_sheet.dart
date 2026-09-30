import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/naroo_colors.dart';
import '../../app/theme/naroo_spacing.dart';
import '../../app/theme/naroo_text.dart';
import '../../app/theme/naroo_widgets.dart';
import '../../core/amount_rules.dart';
import '../../core/seoul_date.dart';
import 'home_controller.dart';

class BudgetSheet extends ConsumerStatefulWidget {
  const BudgetSheet({super.key, required this.month, this.amount});
  final DateTime month;
  final int? amount;
  @override
  ConsumerState<BudgetSheet> createState() => _BudgetSheetState();
}

class _BudgetSheetState extends ConsumerState<BudgetSheet> {
  late final _amount = TextEditingController(
    text: widget.amount?.toString() ?? '',
  );
  String? _error;
  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = AmountRules.parseBudget(_amount.text);
    if (amount == null || !AmountRules.isValidBudget(amount)) {
      setState(() => _error = '0~2,147,483,647 사이의 정수를 입력해 주세요.');
      return;
    }
    final saved = await ref
        .read(budgetEditorProvider.notifier)
        .save(widget.month, amount);
    if (!mounted) return;
    if (saved) {
      Navigator.of(context).pop();
    } else {
      setState(() => _error = '예산을 저장하지 못했습니다. 다시 시도해 주세요.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(budgetEditorProvider);
    return NarooBottomSheet(
      title: '${SeoulDate.monthLabel(widget.month)} 예산',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _amount,
            autofocus: true,
            enabled: !busy,
            keyboardType: TextInputType.number,
            style: NarooText.money(NarooText.body, NarooColors.textPrimary),
            decoration: InputDecoration(
              labelText: '월 예산',
              suffixText: '원',
              errorText: _error,
            ),
            onSubmitted: busy ? null : (_) => _save(),
          ),
          const SizedBox(height: NarooSpacing.space16),
          FilledButton(
            onPressed: busy ? null : _save,
            child: busy ? const NarooButtonProgress() : const Text('저장'),
          ),
        ],
      ),
    );
  }
}
