import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../app/theme/naroo_colors.dart';
import '../../../app/theme/naroo_spacing.dart';
import '../../../app/theme/naroo_text.dart';
import '../../../app/theme/naroo_widgets.dart';
import '../../../core/money_format.dart';
import '../../../core/seoul_date.dart';
import '../../../data/models/category.dart';
import '../../../data/models/transaction.dart';
import '../transaction_editor_controller.dart';

Future<void> showTransactionDetailSheet(
  BuildContext context,
  TransactionListItem item,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: NarooColors.surface,
    barrierColor: NarooColors.barrier,
    builder: (_) => TransactionDetailSheet(item: item),
  );
}

class TransactionDetailSheet extends ConsumerStatefulWidget {
  const TransactionDetailSheet({super.key, required this.item});

  final TransactionListItem item;

  @override
  ConsumerState<TransactionDetailSheet> createState() =>
      _TransactionDetailSheetState();
}

class _TransactionDetailSheetState
    extends ConsumerState<TransactionDetailSheet> {
  String get _id => widget.item.transaction.id;

  @override
  void initState() {
    super.initState();
    // Deleting requires the editor to confirm the record still exists.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(transactionEditorProvider(_id).notifier).loadExisting();
      }
    });
  }

  void _edit() {
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.push(AppRoutes.transactionEdit(_id));
  }

  Future<void> _confirmDelete() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('기록을 삭제할까요?'),
        content: const Text('삭제한 기록은 되돌릴 수 없습니다.'),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: NarooColors.error,
              minimumSize: const Size(64, 52),
            ),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (shouldDelete != true || !mounted) return;
    final deleted = await ref
        .read(transactionEditorProvider(_id).notifier)
        .delete();
    if (mounted && deleted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final editor = ref.watch(transactionEditorProvider(_id));
    final item = widget.item;
    final transaction = item.transaction;
    final isIncome = transaction.type == CategoryType.income;
    final isDeleting = editor.action == TransactionEditorAction.deleting;

    return NarooBottomSheet(
      title: item.categoryLabel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${MoneyFormat.signed(transaction.type, transaction.amount)}원',
            style: NarooText.money(
              NarooText.hero,
              isIncome ? NarooColors.income : NarooColors.expense,
            ),
          ),
          const SizedBox(height: NarooSpacing.space16),
          _row('날짜', SeoulDate.display(transaction.occurredOn)),
          _row('구성원', item.attributionLabel),
          if (!isIncome)
            _row('결제 수단', transaction.paymentMethod?.label ?? '미지정'),
          if (item.memoText case final memo?) _row('메모', memo),
          if (editor.errorMessage case final message?) ...[
            const SizedBox(height: NarooSpacing.space8),
            Text(message, style: NarooText.errorCaption),
          ],
          const SizedBox(height: NarooSpacing.space24),
          Row(
            children: [
              TextButton(
                onPressed: editor.isBusy || !editor.canWrite
                    ? null
                    : _confirmDelete,
                style: TextButton.styleFrom(
                  foregroundColor: NarooColors.error,
                  minimumSize: const Size(64, 52),
                ),
                child: isDeleting
                    ? const NarooButtonProgress(color: NarooColors.error)
                    : const Text('삭제'),
              ),
              const SizedBox(width: NarooSpacing.space12),
              Expanded(
                child: FilledButton(
                  onPressed: isDeleting ? null : _edit,
                  child: const Text('수정'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: NarooSpacing.space8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 72, child: Text(label, style: NarooText.bodySecondary)),
        Expanded(child: Text(value, style: NarooText.body)),
      ],
    ),
  );
}
