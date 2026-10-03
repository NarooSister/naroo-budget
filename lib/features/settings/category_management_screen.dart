import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/naroo_colors.dart';
import '../../app/theme/naroo_icons.dart';
import '../../app/theme/naroo_spacing.dart';
import '../../app/theme/naroo_widgets.dart';
import '../../data/models/category.dart';
import 'category_controller.dart';

class CategoryManagementScreen extends ConsumerStatefulWidget {
  const CategoryManagementScreen({super.key});

  @override
  ConsumerState<CategoryManagementScreen> createState() =>
      _CategoryManagementScreenState();
}

class _CategoryManagementScreenState
    extends ConsumerState<CategoryManagementScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _showEditor({
    required CategoryType type,
    Category? category,
  }) async {
    final isEditing = category != null;
    if (_busy || (isEditing && category.isUncategorized)) {
      return;
    }

    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: NarooColors.surface,
      barrierColor: NarooColors.barrier,
      builder: (context) {
        return _CategoryEditorSheet(
          title: isEditing ? '카테고리 수정' : '${type.label} 카테고리 추가',
          initialName: category?.name ?? '',
          submitLabel: isEditing ? '저장' : '추가',
        );
      },
    );

    if (result == null || !mounted) {
      return;
    }

    setState(() => _busy = true);
    try {
      if (isEditing) {
        await ref
            .read(categoriesProvider.notifier)
            .rename(categoryId: category.id, name: result);
      } else {
        await ref
            .read(categoriesProvider.notifier)
            .create(type: type, name: result);
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('카테고리를 저장하지 못했습니다.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(Category category) async {
    if (_busy || category.isUncategorized) return;
    setState(() => _busy = true);
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('‘${category.name}’을 삭제할까요?'),
          content: const Text('카테고리에 포함된 내용은 모두 미분류로 변경됩니다.'),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: NarooColors.error),
              child: const Text('삭제'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      await ref.read(categoriesProvider.notifier).delete(category.id);
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('카테고리를 삭제하지 못했습니다.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('카테고리 관리'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '지출'),
            Tab(text: '수입'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _busy
            ? null
            : () {
                final type = _tabController.index == 0
                    ? CategoryType.expense
                    : CategoryType.income;
                _showEditor(type: type);
              },
        child: const Icon(NarooIcons.add, size: NarooIcons.action),
      ),
      body: categoriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('카테고리를 불러오지 못했습니다.')),
        data: (categories) {
          return TabBarView(
            controller: _tabController,
            children: [
              _CategoryList(
                categories: categories
                    .where((item) => item.type == CategoryType.expense)
                    .toList(growable: false),
                onEdit: (category) =>
                    _showEditor(type: category.type, category: category),
                onDelete: _delete,
                busy: _busy,
              ),
              _CategoryList(
                categories: categories
                    .where((item) => item.type == CategoryType.income)
                    .toList(growable: false),
                onEdit: (category) =>
                    _showEditor(type: category.type, category: category),
                onDelete: _delete,
                busy: _busy,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CategoryEditorSheet extends StatefulWidget {
  const _CategoryEditorSheet({
    required this.title,
    required this.initialName,
    required this.submitLabel,
  });

  final String title;
  final String initialName;
  final String submitLabel;

  @override
  State<_CategoryEditorSheet> createState() => _CategoryEditorSheetState();
}

class _CategoryEditorSheetState extends State<_CategoryEditorSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.of(context).pop(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    return NarooBottomSheet(
      title: widget.title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(labelText: '이름'),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: NarooSpacing.space16),
          FilledButton(onPressed: _submit, child: Text(widget.submitLabel)),
        ],
      ),
    );
  }
}

class _CategoryList extends StatelessWidget {
  const _CategoryList({
    required this.categories,
    required this.onEdit,
    required this.onDelete,
    required this.busy,
  });

  final List<Category> categories;
  final ValueChanged<Category> onEdit;
  final ValueChanged<Category> onDelete;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) {
      return const Center(child: Text('카테고리가 없어요.'));
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        NarooSpacing.space20,
        NarooSpacing.space8,
        NarooSpacing.space20,
        88,
      ),
      itemCount: categories.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final category = categories[index];
        return ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(category.name),
          trailing: category.isUncategorized
              ? null
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: '수정',
                      onPressed: busy ? null : () => onEdit(category),
                      icon: const Icon(
                        NarooIcons.edit,
                        size: NarooIcons.action,
                      ),
                    ),
                    IconButton(
                      tooltip: '삭제',
                      onPressed: busy ? null : () => onDelete(category),
                      icon: const Icon(
                        NarooIcons.delete,
                        size: NarooIcons.action,
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}
