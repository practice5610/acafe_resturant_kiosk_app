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

  /// Tapped to open the Punch In / Out screen. Optional: when null (every
  /// existing caller and the widget's own tests) the action is not rendered, so
  /// the sidebar is unchanged for them. The one caller that passes it is
  /// `pos_home_cart_screen.dart`.
  final VoidCallback? onPunch;

  /// Pane width. Defaults to the flat Figma value — the only width this
  /// widget ever drew before the desktop-floor refactor — so every other
  /// caller (and every existing test that constructs this widget directly)
  /// keeps working unchanged. `pos_home_cart_screen.dart` is the one caller
  /// that now passes [PosResponsive.sidebarWidth]'s continuous value above
  /// the floor.
  final double width;

  /// Multiplier on the rail's item, label and spacing tokens, so the content
  /// grows and shrinks with [width] rather than holding the 1366 frame's
  /// pixels inside a wider or narrower pane. Defaults to 1 (the flat Figma
  /// sizes); `pos_home_cart_screen.dart` passes [PosResponsive.homeScale].
  /// Stroke widths stay fixed so rules and outlines read the same at any size.
  final double scale;

  const PosCategorySidebar({
    super.key,
    required this.categories,
    required this.selectedId,
    required this.onSelect,
    this.onPunch,
    this.width = PosHomeSpec.sidebarWidth,
    this.scale = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      decoration: const BoxDecoration(
        color: PosHomeSpec.pageBg,
        border: Border(
          right: BorderSide(
            color: PosHomeSpec.ink,
            width: PosHomeSpec.paneBorder,
          ),
        ),
      ),
      child: Column(
        children: [
          Expanded(
            child: ScrollConfiguration(
              behavior:
                  ScrollConfiguration.of(context).copyWith(scrollbars: false),
              child: ListView.separated(
                padding: PosHomeSpec.sidebarPadding * scale,
                itemCount: categories.length,
                separatorBuilder: (_, __) =>
                    SizedBox(height: PosHomeSpec.sidebarItemGap * scale),
                itemBuilder: (context, index) {
                  final category = categories[index];
                  return PosCategoryItem(
                    label: category.name ?? '',
                    selected: '${category.id}' == selectedId,
                    onTap: () => onSelect(category),
                    scale: scale,
                  );
                },
              ),
            ),
          ),
          if (onPunch != null)
            _PosSidebarPunchAction(onTap: onPunch!, scale: scale),
        ],
      ),
    );
  }
}

/// The Punch In / Out entry, pinned below the categories. Styled from the same
/// sidebar tokens so it reads as part of the rail, but outlined rather than
/// filled so it is clearly an action, not another category (a filled tile is
/// how the rail draws the *selected* category).
class _PosSidebarPunchAction extends StatelessWidget {
  final VoidCallback onTap;
  final double scale;

  const _PosSidebarPunchAction({required this.onTap, required this.scale});

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius =
        BorderRadius.circular(PosHomeSpec.sidebarItemRadius * scale);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24) * scale,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Opacity(
            opacity: PosHomeSpec.sidebarRuleOpacity,
            child: SizedBox(
              height: PosHomeSpec.sidebarRuleHeight,
              width: double.infinity,
              child: ColoredBox(color: PosHomeSpec.ink),
            ),
          ),
          SizedBox(height: 16 * scale),
          Material(
            key: const Key('pos-sidebar-punch'),
            color: Colors.transparent,
            borderRadius: radius,
            child: InkWell(
              onTap: onTap,
              borderRadius: radius,
              child: Container(
                height: PosHomeSpec.sidebarItemHeight * scale,
                decoration: BoxDecoration(
                  borderRadius: radius,
                  border: Border.all(
                    color: PosHomeSpec.ink,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.schedule_rounded,
                        size: 20 * scale, color: PosHomeSpec.ink),
                    SizedBox(width: 10 * scale),
                    Flexible(
                      child: Text(
                        'Punch In / Out'.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: loewBold.copyWith(
                          fontSize: 13 * scale,
                          color: PosHomeSpec.ink,
                          letterSpacing: 0.5 * scale,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// [style], shrunk just enough that the longest single word of [text] fits
/// on one line of [maxWidth].
///
/// A rail label may wrap onto two lines at its spaces, but a lone word wider
/// than the rail would otherwise be split mid-word (MERCHANDISE drew as
/// MERCHANDIS / E — even at the 1366 frame, where it is a hair over its
/// 134px). Labels whose words already fit keep their size untouched.
TextStyle _fitLongestWord(
  BuildContext context,
  String text,
  TextStyle style,
  double maxWidth,
) {
  if (!maxWidth.isFinite || maxWidth <= 0) return style;
  // Measure what Text will actually paint: the inherited default style (its
  // letter spacing included) merged with ours.
  final TextStyle painted = DefaultTextStyle.of(context).style.merge(style);
  final TextScaler scaler = MediaQuery.textScalerOf(context);

  double widestAt(double fontSize) {
    double widest = 0;
    for (final String word in text.split(RegExp(r'\s+'))) {
      if (word.isEmpty) continue;
      final TextPainter painter = TextPainter(
        text: TextSpan(
            text: word, style: painted.copyWith(fontSize: fontSize)),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      if (painter.width > widest) widest = painter.width;
      painter.dispose();
    }
    return widest;
  }

  final double base = style.fontSize ?? PosHomeSpec.sidebarLabelSize;
  final double widest = widestAt(base);
  if (widest <= maxWidth) return style;

  // Width is near-linear in font size; letter spacing is the part that does
  // not shrink with it, so confirm and step down until the word fits.
  double fontSize = base * maxWidth / widest;
  while (fontSize > 1 && widestAt(fontSize) > maxWidth) {
    fontSize -= 0.25;
  }
  return style.copyWith(fontSize: fontSize);
}

class PosCategoryItem extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// See [PosCategorySidebar.scale].
  final double scale;

  const PosCategoryItem({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.scale = 1,
  });

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius =
        BorderRadius.circular(PosHomeSpec.sidebarItemRadius * scale);
    final double inset = PosHomeSpec.sidebarItemPadding * scale;

    return Material(
      color: selected ? PosHomeSpec.ink : Colors.transparent,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: SizedBox(
          height: PosHomeSpec.sidebarItemHeight * scale,
          child: Stack(
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: inset),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final String text = label.toUpperCase();
                      return Text(
                        text,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: _fitLongestWord(
                          context,
                          text,
                          loewBold.copyWith(
                            fontSize: PosHomeSpec.sidebarLabelSize * scale,
                            color: selected ? Colors.white : PosHomeSpec.ink,
                            height: PosHomeSpec.sidebarLabelHeight,
                          ),
                          constraints.maxWidth,
                        ),
                      );
                    },
                  ),
                ),
              ),
              // The selected item is the one row in the design with no rule
              // under it — the fill replaces the separator.
              if (!selected)
                Positioned(
                  left: inset,
                  right: inset,
                  bottom: 0,
                  height: PosHomeSpec.sidebarRuleHeight,
                  child: const Opacity(
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
