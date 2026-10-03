import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/naroo_colors.dart';
import '../../app/theme/naroo_spacing.dart';
import '../../app/theme/naroo_text.dart';
import '../../app/theme/naroo_widgets.dart';
import '../../core/amount_rules.dart';
import '../../core/money_format.dart';
import '../../core/seoul_date.dart';
import '../../data/models/category.dart';
import '../../data/models/monthly_budget.dart';
import 'home_controller.dart';

Future<void> showBudgetSheet(
  BuildContext context, {
  required DateTime month,
  MonthlyBudget? budget,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: NarooColors.surface,
    barrierColor: NarooColors.barrier,
    builder: (_) => BudgetSheet(month: month, budget: budget),
  );
}

class BudgetSheet extends ConsumerStatefulWidget {
  const BudgetSheet({super.key, required this.month, this.budget});
  final DateTime month;
  final MonthlyBudget? budget;
  @override
  ConsumerState<BudgetSheet> createState() => _BudgetSheetState();
}

class _BudgetSheetState extends ConsumerState<BudgetSheet> {
  late final _total = TextEditingController(
    text: widget.budget?.amount.toString() ?? '',
  );
  final _allocations = <String, TextEditingController>{};
  late Map<String, int> _initialAllocations = widget.budget?.allocations ?? {};
  late String? _version = widget.budget?.version;
  String? _error;
  bool _conflict = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _total.addListener(_changed);
  }

  @override
  void dispose() {
    _total.dispose();
    for (final controller in _allocations.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _changed() => setState(() {});

  TextEditingController _allocationFor(String categoryId) =>
      _allocations.putIfAbsent(categoryId, () {
        final controller = TextEditingController(
          text: _initialAllocations[categoryId]?.toString() ?? '',
        );
        controller.addListener(_changed);
        return controller;
      });

  void _fill(MonthlyBudget? budget) {
    _total.text = budget?.amount.toString() ?? '';
    _initialAllocations = budget?.allocations ?? {};
    for (final entry in _allocations.entries) {
      entry.value.text = _initialAllocations[entry.key]?.toString() ?? '';
    }
  }

  Future<void> _loadPrevious() async {
    setState(() => _loading = true);
    try {
      final previous = await ref
          .read(budgetEditorProvider.notifier)
          .loadPrevious(widget.month);
      if (!mounted) return;
      setState(() {
        if (previous == null) {
          _error = '지난달 예산이 없어요.';
        } else {
          _fill(previous);
          _error = null;
        }
      });
    } catch (_) {
      if (mounted) setState(() => _error = '지난달 예산을 불러오지 못했습니다.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    try {
      final latest = await ref
          .read(budgetEditorProvider.notifier)
          .load(widget.month);
      if (!mounted) return;
      setState(() {
        _fill(latest);
        _version = latest?.version;
        _conflict = false;
        _error = null;
      });
    } catch (_) {
      if (mounted) setState(() => _error = '예산을 불러오지 못했습니다.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Parsed allocations, or null when any filled field is invalid.
  /// Empty fields mean no allocation.
  Map<String, int>? _parsedAllocations(List<Category> categories) {
    final result = <String, int>{};
    for (final category in categories) {
      final raw = _allocationFor(category.id).text;
      if (raw.trim().isEmpty) continue;
      final amount = AmountRules.parseBudget(raw);
      if (amount == null || !AmountRules.isValidBudget(amount)) return null;
      result[category.id] = amount;
    }
    return result;
  }

  Future<void> _save(List<Category> categories) async {
    final amount = AmountRules.parseBudget(_total.text);
    if (amount == null || !AmountRules.isValidBudget(amount)) {
      setState(() => _error = '0~2,147,483,647 사이의 정수를 입력해 주세요.');
      return;
    }
    final allocations = _parsedAllocations(categories);
    if (allocations == null) {
      setState(() => _error = '배분 금액은 0~2,147,483,647 사이의 정수로 입력해 주세요.');
      return;
    }
    if (allocations.values.fold(0, (sum, v) => sum + v) > amount) {
      setState(() => _error = '배분 합계가 총예산을 넘습니다. 배분이나 총예산을 조정해 주세요.');
      return;
    }
    final result = await ref
        .read(budgetEditorProvider.notifier)
        .save(
          widget.month,
          amount: amount,
          allocations: allocations,
          expectedVersion: _version,
        );
    if (!mounted) return;
    _handle(result, failedMessage: '예산을 저장하지 못했습니다. 다시 시도해 주세요.');
  }

  Future<void> _confirmReset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${widget.month.month}월 예산과 카테고리 배분을 모두 지울까요?'),
        content: const Text('이 달은 예산이 없는 상태로 돌아갑니다.'),
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
            child: const Text('초기화'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final result = await ref
        .read(budgetEditorProvider.notifier)
        .reset(widget.month, expectedVersion: _version);
    if (!mounted) return;
    _handle(result, failedMessage: '예산을 초기화하지 못했습니다. 다시 시도해 주세요.');
  }

  void _handle(BudgetWriteResult result, {required String failedMessage}) {
    switch (result) {
      case BudgetWriteResult.done:
        Navigator.of(context).pop();
      case BudgetWriteResult.conflict:
        setState(() {
          _conflict = true;
          _error = '다른 사람이 먼저 예산을 바꿨어요. 다시 불러온 뒤 저장해 주세요.';
        });
      case BudgetWriteResult.failed:
        setState(() => _error = failedMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(budgetEditorProvider) || _loading;
    final categoriesAsync = ref.watch(budgetCategoriesProvider);
    final categories = categoriesAsync.value ?? const <Category>[];
    final total = AmountRules.parseBudget(_total.text);

    return NarooBottomSheet(
      title: '${SeoulDate.monthLabel(widget.month)} 예산',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.budget == null && _version == null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: busy ? null : _loadPrevious,
                child: const Text('지난달 예산 불러오기'),
              ),
            ),
          TextField(
            controller: _total,
            autofocus: true,
            enabled: !busy,
            keyboardType: TextInputType.number,
            style: NarooText.money(NarooText.body, NarooColors.textPrimary),
            decoration: const InputDecoration(
              labelText: '총예산',
              suffixText: '원',
            ),
          ),
          if (total != null) ...[
            const SizedBox(height: NarooSpacing.space24),
            _allocationHeader(total, categories),
            const SizedBox(height: NarooSpacing.space8),
            categoriesAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(NarooSpacing.space16),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, _) =>
                  Text('카테고리를 불러오지 못했습니다.', style: NarooText.bodySecondary),
              data: (categories) => Column(
                children: [
                  for (final category in categories)
                    Padding(
                      padding: const EdgeInsets.only(
                        bottom: NarooSpacing.space8,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              category.name,
                              style: NarooText.body,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: NarooSpacing.space12),
                          SizedBox(
                            width: 160,
                            child: TextField(
                              key: ValueKey('allocation-${category.id}'),
                              controller: _allocationFor(category.id),
                              enabled: !busy,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.end,
                              style: NarooText.money(
                                NarooText.body,
                                NarooColors.textPrimary,
                              ),
                              decoration: InputDecoration(
                                hintText: '0',
                                suffixText: '원',
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (_error case final error?) ...[
            const SizedBox(height: NarooSpacing.space8),
            Text(error, style: NarooText.errorCaption),
            if (_conflict)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: busy ? null : _reload,
                  child: const Text('다시 불러오기'),
                ),
              ),
          ],
          const SizedBox(height: NarooSpacing.space16),
          FilledButton(
            onPressed: busy || _conflict ? null : () => _save(categories),
            child: ref.watch(budgetEditorProvider)
                ? const NarooButtonProgress()
                : const Text('저장'),
          ),
          if (_version != null) ...[
            const SizedBox(height: NarooSpacing.space8),
            TextButton(
              onPressed: busy ? null : _confirmReset,
              style: TextButton.styleFrom(foregroundColor: NarooColors.error),
              child: const Text('예산 초기화'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _allocationHeader(int total, List<Category> categories) {
    var allocated = 0;
    for (final category in categories) {
      allocated +=
          AmountRules.parseBudget(_allocationFor(category.id).text) ?? 0;
    }
    final unallocated = total - allocated;
    return Row(
      children: [
        Expanded(child: Text('카테고리 배분', style: NarooText.section)),
        Text(
          unallocated < 0
              ? '${MoneyFormat.krw(unallocated)}원 초과'
              : '미배분 ${MoneyFormat.krw(unallocated)}원',
          style: NarooText.money(
            NarooText.bodySecondary,
            unallocated < 0 ? NarooColors.expense : NarooColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
