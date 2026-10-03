import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/naroo_colors.dart';
import '../../app/theme/naroo_icons.dart';
import '../../app/theme/naroo_spacing.dart';
import '../../app/theme/naroo_text.dart';
import '../../app/theme/naroo_widgets.dart';
import '../../core/amount_rules.dart';
import '../../core/seoul_date.dart';
import '../../core/session/app_session.dart';
import '../../data/models/category.dart';
import '../../data/models/transaction.dart';
import 'transaction_editor_controller.dart';
import 'widgets/transaction_category_picker.dart';

class TransactionCreateScreen extends ConsumerStatefulWidget {
  const TransactionCreateScreen({super.key, this.transactionId});

  final String? transactionId;

  bool get isEditing => transactionId != null;

  @override
  ConsumerState<TransactionCreateScreen> createState() =>
      _TransactionCreateScreenState();
}

class _TransactionCreateScreenState
    extends ConsumerState<TransactionCreateScreen> {
  final _amountController = TextEditingController();
  final _memoController = TextEditingController();
  final _amountFocusNode = FocusNode();

  CategoryType _type = CategoryType.expense;
  String? _categoryId;
  String? _subcategoryId;
  String? _existingCategoryId;
  String? _memberId;
  String? _existingMemberId;
  AttributionKind _attributionKind = AttributionKind.member;
  DateTime _occurredOn = SeoulDate.today();
  String? _errorMessage;
  bool _showOptionalFields = false;

  bool get _isBusy =>
      ref.read(transactionEditorProvider(widget.transactionId)).isBusy ||
      !ref.read(transactionEditorProvider(widget.transactionId)).canWrite;

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) {
      _showOptionalFields = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _loadExisting();
        }
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _amountFocusNode.requestFocus();
        }
      });
    }
  }

  Future<void> _loadExisting() async {
    final existing = await ref
        .read(transactionEditorProvider(widget.transactionId).notifier)
        .loadExisting();
    if (!mounted || existing == null) {
      return;
    }
    setState(() {
      _type = existing.type;
      _categoryId = existing.categoryId;
      _subcategoryId = existing.subcategoryId;
      _existingCategoryId = existing.categoryId;
      _memberId = existing.memberId;
      _existingMemberId = existing.memberId;
      _attributionKind = existing.attributionKind;
      _occurredOn = existing.occurredOn;
      _amountController.text = existing.amount.toString();
      _memoController.text = existing.memo ?? '';
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _memoController.dispose();
    _amountFocusNode.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _occurredOn,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (selected == null) {
      return;
    }
    setState(() {
      _occurredOn = DateTime(selected.year, selected.month, selected.day);
    });
  }

  Future<void> _confirmDelete() async {
    if (_isBusy || !widget.isEditing) {
      return;
    }

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
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
        );
      },
    );

    if (shouldDelete != true || !mounted) {
      return;
    }

    await _delete();
  }

  Future<void> _delete() async {
    if (!widget.isEditing || _isBusy) {
      return;
    }

    setState(() {
      _errorMessage = null;
    });
    final deleted = await ref
        .read(transactionEditorProvider(widget.transactionId).notifier)
        .delete();
    if (mounted && deleted) {
      context.pop(true);
    }
  }

  Future<void> _save() async {
    if (_isBusy) {
      return;
    }

    final session = ref.read(appSessionProvider).value;
    final member = session?.member;
    if (session == null || member == null) {
      setState(() {
        _errorMessage = '가계부에 연결되지 않았습니다.';
      });
      return;
    }

    final amount = AmountRules.parseTransaction(_amountController.text);
    if (amount == null || amount <= 0) {
      setState(() {
        _errorMessage = '금액은 0보다 큰 정수로 입력해 주세요.';
      });
      return;
    }

    if (!AmountRules.isValidTransaction(amount)) {
      setState(() {
        _errorMessage = '금액은 2,147,483,647원 이하로 입력해 주세요.';
      });
      return;
    }

    final categoryId = _categoryId;
    if (categoryId == null) {
      setState(() {
        _errorMessage = '카테고리를 선택해 주세요.';
      });
      return;
    }

    setState(() {
      _errorMessage = null;
    });

    final input = NewTransaction(
      householdId: member.householdId,
      memberId: _attributionKind == AttributionKind.shared
          ? null
          : _memberId ?? member.id,
      attributionKind: _attributionKind,
      type: _type,
      amount: amount,
      categoryId: categoryId,
      subcategoryId: _subcategoryId,
      occurredOn: _occurredOn,
      memo: _memoController.text,
    );

    final saved = await ref
        .read(transactionEditorProvider(widget.transactionId).notifier)
        .save(input);
    if (mounted && saved) {
      context.pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editor = ref.watch(transactionEditorProvider(widget.transactionId));
    final isSubmitting = editor.action == TransactionEditorAction.saving;
    final isDeleting = editor.action == TransactionEditorAction.deleting;
    final isLoadingExisting = editor.action == TransactionEditorAction.loading;
    final errorMessage = _errorMessage ?? editor.errorMessage;
    final session = ref.watch(appSessionProvider).value;
    final currentMemberId = session?.member?.id;
    final selectedMemberId = _attributionKind == AttributionKind.shared
        ? 'shared'
        : _memberId ?? currentMemberId;
    final membersAsync = ref.watch(transactionMembersProvider);
    final categoriesAsync = ref.watch(transactionCategoriesProvider(_type));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? '기록 수정' : '기록 추가'),
        actions: [
          if (widget.isEditing)
            IconButton(
              tooltip: '삭제',
              onPressed: _isBusy ? null : _confirmDelete,
              icon: const Icon(
                NarooIcons.delete,
                size: NarooIcons.action,
                color: NarooColors.error,
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: isLoadingExisting
            ? const Center(child: CircularProgressIndicator())
            : !editor.canWrite
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(editor.errorMessage ?? '기록을 찾을 수 없습니다.'),
                    TextButton.icon(
                      onPressed: _loadExisting,
                      icon: const Icon(
                        NarooIcons.refresh,
                        size: NarooIcons.inline,
                      ),
                      label: const Text('다시 시도'),
                    ),
                  ],
                ),
              )
            : Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(
                        NarooSpacing.space20,
                        NarooSpacing.space16,
                        NarooSpacing.space20,
                        NarooSpacing.space24,
                      ),
                      children: [
                        SegmentedButton<CategoryType>(
                          segments: const [
                            ButtonSegment(
                              value: CategoryType.expense,
                              label: Text('지출'),
                            ),
                            ButtonSegment(
                              value: CategoryType.income,
                              label: Text('수입'),
                            ),
                          ],
                          selected: {_type},
                          onSelectionChanged: _isBusy
                              ? null
                              : (value) {
                                  setState(() {
                                    _type = value.first;
                                    _categoryId = null;
                                    _subcategoryId = null;
                                  });
                                },
                        ),
                        const SizedBox(height: NarooSpacing.space24),
                        TextField(
                          controller: _amountController,
                          focusNode: _amountFocusNode,
                          enabled: !_isBusy,
                          keyboardType: TextInputType.number,
                          style: NarooText.hero,
                          decoration: const InputDecoration(
                            labelText: '금액',
                            suffixText: '원',
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: NarooSpacing.space16,
                              vertical: NarooSpacing.space8,
                            ),
                          ),
                        ),
                        const SizedBox(height: NarooSpacing.space24),
                        Text('카테고리', style: NarooText.section),
                        const SizedBox(height: NarooSpacing.space12),
                        categoriesAsync.when(
                          loading: () =>
                              const Center(child: CircularProgressIndicator()),
                          error: (_, _) => const Text('카테고리를 불러오지 못했습니다.'),
                          data: (categories) {
                            // Uncategorized is only kept for an existing record.
                            final topLevel = categories
                                .where(
                                  (item) =>
                                      !item.isSubcategory &&
                                      (!item.isUncategorized ||
                                          item.id == _existingCategoryId),
                                )
                                .toList(growable: false);
                            if (topLevel.isEmpty) {
                              return const Text('선택할 카테고리가 없어요.');
                            }
                            final subcategories = _categoryId == null
                                ? const <Category>[]
                                : categories
                                      .where(
                                        (item) => item.parentId == _categoryId,
                                      )
                                      .toList(growable: false);

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                TransactionCategoryPicker(
                                  categories: topLevel,
                                  selectedCategoryId: _categoryId,
                                  isBusy: _isBusy,
                                  onSelected: (id) {
                                    if (id == _categoryId) return;
                                    setState(() {
                                      _categoryId = id;
                                      _subcategoryId = null;
                                    });
                                  },
                                ),
                                if (subcategories.isNotEmpty) ...[
                                  const SizedBox(height: NarooSpacing.space16),
                                  Text(
                                    '소분류 (선택)',
                                    style: NarooText.caption.copyWith(
                                      color: NarooColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: NarooSpacing.space8),
                                  TransactionCategoryPicker(
                                    categories: subcategories,
                                    selectedCategoryId: _subcategoryId,
                                    isBusy: _isBusy,
                                    onSelected: (id) {
                                      setState(() {
                                        _subcategoryId = id == _subcategoryId
                                            ? null
                                            : id;
                                      });
                                    },
                                  ),
                                ],
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: NarooSpacing.space16),
                        TextButton(
                          onPressed: _isBusy
                              ? null
                              : () {
                                  setState(() {
                                    _showOptionalFields = !_showOptionalFields;
                                  });
                                },
                          child: Text(
                            _showOptionalFields ? '추가 옵션 숨기기' : '날짜 · 구성원 · 메모',
                          ),
                        ),
                        if (_showOptionalFields) ...[
                          const SizedBox(height: NarooSpacing.space8),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('날짜'),
                            subtitle: Text(SeoulDate.display(_occurredOn)),
                            trailing: const Icon(
                              NarooIcons.calendar,
                              size: NarooIcons.action,
                            ),
                            onTap: _isBusy ? null : _pickDate,
                          ),
                          membersAsync.when(
                            loading: () => const SizedBox.shrink(),
                            error: (_, _) => const Text('구성원을 불러오지 못했습니다.'),
                            data: (members) {
                              return DropdownMenu<String>(
                                expandedInsets: EdgeInsets.zero,
                                key: ValueKey(selectedMemberId),
                                initialSelection: selectedMemberId,
                                label: const Text('구성원'),
                                dropdownMenuEntries: [
                                  const DropdownMenuEntry(
                                    value: 'shared',
                                    label: '공용',
                                  ),
                                  for (final member in members.where(
                                    (member) =>
                                        !member.isHidden ||
                                        member.id == _existingMemberId,
                                  ))
                                    DropdownMenuEntry(
                                      value: member.id,
                                      label:
                                          '${member.displayName}${member.isHidden ? ' (숨김)' : ''}',
                                    ),
                                ],
                                enabled: !_isBusy,
                                onSelected: (value) {
                                  if (value == null) return;
                                  setState(() {
                                    _attributionKind = value == 'shared'
                                        ? AttributionKind.shared
                                        : AttributionKind.member;
                                    _memberId = value == 'shared'
                                        ? null
                                        : value;
                                  });
                                },
                              );
                            },
                          ),
                          const SizedBox(height: NarooSpacing.space16),
                          TextField(
                            controller: _memoController,
                            enabled: !_isBusy,
                            decoration: const InputDecoration(
                              labelText: '메모 (선택)',
                            ),
                          ),
                        ],
                        if (errorMessage != null) ...[
                          const SizedBox(height: NarooSpacing.space16),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: NarooColors.errorSurface,
                              borderRadius: BorderRadius.circular(
                                NarooRadius.input,
                              ),
                              border: Border.all(color: NarooColors.error),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: NarooSpacing.space12,
                                vertical: NarooSpacing.space8,
                              ),
                              child: Text(
                                errorMessage,
                                style: NarooText.caption.copyWith(
                                  color: NarooColors.error,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      NarooSpacing.space20,
                      0,
                      NarooSpacing.space20,
                      NarooSpacing.space16,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FilledButton(
                          onPressed: _isBusy ? null : _save,
                          child: isSubmitting
                              ? const NarooButtonProgress()
                              : Text(widget.isEditing ? '수정 저장' : '저장'),
                        ),
                        if (widget.isEditing) ...[
                          const SizedBox(height: NarooSpacing.space12),
                          OutlinedButton(
                            onPressed: _isBusy ? null : _confirmDelete,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: NarooColors.error,
                              backgroundColor: NarooColors.errorSurface,
                            ),
                            child: isDeleting
                                ? const NarooButtonProgress(
                                    color: NarooColors.error,
                                  )
                                : const Text('삭제'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
