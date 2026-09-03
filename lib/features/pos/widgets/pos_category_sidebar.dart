import 'package:acafe_customer/features/category/domain/category_model.dart';
import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter/material.dart';

/// Left pane: the branch's top-level categories.
///
/// Selection state lives in `CategoryProvider.selectedSubCategoryId` (which,
/// despite the name, holds the *top-level* id — the kiosk rail uses it the same
/// way). This widget is presentational; the screen owns the provider wiring.
class PosCategorySidebar extends StatelessWidget {
  final List<CategoryModel> categories;
  final String? selectedId;
  final ValueChanged<CategoryModel> onSelect;

  const PosCategorySidebar({
    super.key,
    required this.categories,
    required this.selectedId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: PosHomeSpec.sidebarWidth,
      decoration: const BoxDecoration(
        color: PosHomeSpec.pageBg,
        border: Border(
          right: BorderSide(
            color: PosHomeSpec.ink,
            width: PosHomeSpec.paneBorder,
          ),
        ),
      ),
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: ListView.separated(
          padding: PosHomeSpec.sidebarPadding,
          itemCount: categories.length,
          separatorBuilder: (_, __) =>
              const SizedBox(height: PosHomeSpec.sidebarItemGap),
          itemBuilder: (context, index) {
            final category = categories[index];
            return PosCategoryItem(
              label: category.name ?? '',
              selected: '${category.id}' == selectedId,
              onTap: () => onSelect(category),
            );
          },
        ),
      ),
    );
  }
}

class PosCategoryItem extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const PosCategoryItem({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? PosHomeSpec.ink : Colors.transparent,
      borderRadius: BorderRadius.circular(PosHomeSpec.sidebarItemRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(PosHomeSpec.sidebarItemRadius),
        child: SizedBox(
          height: PosHomeSpec.sidebarItemHeight,
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: PosHomeSpec.sidebarItemPadding),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    label.toUpperCase(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: loewBold.copyWith(
                      fontSize: PosHomeSpec.sidebarLabelSize,
                      color: selected ? Colors.white : PosHomeSpec.ink,
                      height: PosHomeSpec.sidebarLabelHeight,
                    ),
                  ),
                ),
              ),
              // The selected item is the one row in the design with no rule
              // under it — the fill replaces the separator.
              if (!selected)
                const Positioned(
                  left: PosHomeSpec.sidebarItemPadding,
                  right: PosHomeSpec.sidebarItemPadding,
                  bottom: 0,
                  height: PosHomeSpec.sidebarRuleHeight,
                  child: Opacity(
                    opacity: PosHomeSpec.sidebarRuleOpacity,
                    child: ColoredBox(color: PosHomeSpec.ink),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
