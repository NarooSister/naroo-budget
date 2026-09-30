import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/naroo_colors.dart';
import '../../app/theme/naroo_icons.dart';
import '../../app/theme/naroo_spacing.dart';
import '../../app/theme/naroo_text.dart';
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
    if (isEditing && category.isDefault) {
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
    }
  }

  Future<void> _toggleHidden(Category category) async {
    try {
      await ref
          .read(categoriesProvider.notifier)
          .setHidden(categoryId: category.id, isHidden: !category.isHidden);
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('카테고리 숨김 상태를 바꾸지 못했습니다.')));
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
        onPressed: () {
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
                onToggleHidden: _toggleHidden,
              ),
              _CategoryList(
                categories: categories
                    .where((item) => item.type == CategoryType.income)
                    .toList(growable: false),
                onEdit: (category) =>
                    _showEditor(type: category.type, category: category),
                onToggleHidden: _toggleHidden,
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
    required this.onToggleHidden,
  });

  final List<Category> categories;
  final ValueChanged<Category> onEdit;
  final ValueChanged<Category> onToggleHidden;

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
        final subtitle = [
          if (category.isDefault) '기본',
          if (category.isHidden) '숨김',
        ].join(' · ');

        return ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            category.name,
            style: category.isHidden
                ? NarooText.body.copyWith(color: NarooColors.textTertiary)
                : null,
          ),
          subtitle: subtitle.isEmpty ? null : Text(subtitle),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!category.isDefault)
                IconButton(
                  tooltip: '수정',
                  onPressed: () => onEdit(category),
                  icon: const Icon(NarooIcons.edit, size: NarooIcons.action),
                ),
              IconButton(
                tooltip: category.isHidden ? '숨김 해제' : '숨기기',
                onPressed: () => onToggleHidden(category),
                icon: Icon(
                  category.isHidden ? NarooIcons.show : NarooIcons.hide,
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
