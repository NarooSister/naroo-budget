import 'package:flutter/material.dart';

import '../../../app/theme/naroo_spacing.dart';
import '../../../app/theme/naroo_widgets.dart';
import '../../../data/models/category.dart';

class TransactionCategoryPicker extends StatelessWidget {
  const TransactionCategoryPicker({
    super.key,
    required this.categories,
    required this.selectedCategoryId,
    required this.isBusy,
    required this.onSelected,
  });

  final List<Category> categories;
  final String? selectedCategoryId;
  final bool isBusy;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const columns = 4;
        const gap = NarooSpacing.space8;
        final tileWidth =
            (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Opacity(
          opacity: isBusy ? 0.5 : 1,
          child: Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final category in categories)
                SizedBox(
                  width: tileWidth,
                  height: 72,
                  child: NarooCategoryChip(
                    label: category.name,
                    selected: selectedCategoryId == category.id,
                    onTap: isBusy ? null : () => onSelected(category.id),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
