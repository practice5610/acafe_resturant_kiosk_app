import 'package:acafe_customer/common/widgets/custom_image_widget.dart';
import 'package:acafe_customer/features/category/domain/category_model.dart';
import 'package:acafe_customer/features/pos/domain/pos_category_layout.dart';
import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/features/pos/widgets/pos_kiosk_mode_actions.dart';
import 'package:acafe_customer/features/pos/widgets/pos_punch_actions.dart';
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

  /// Which rail variant to draw. Defaults to [PosCategoryLayout.list] so every
  /// existing caller and test is unchanged; the Menu screen passes the
  /// configured value. Only the per-row presentation differs — data, selection
  /// and tap handling are identical for both. See [PosCategoryLayout].
  final PosCategoryLayout layout;

  /// Base URL for category images, used only by [PosCategoryLayout.tiles]. When
  /// null (or a category has no image), the tile falls back to a name-only row.
  final String? imageBaseUrl;

  /// Tapped to open the Punch In / Out screen. Optional: when null (every
  /// existing caller and the widget's own tests) the action is not rendered, so
  /// the sidebar is unchanged for them. The one caller that passes it is
  /// `pos_home_cart_screen.dart`.
  final VoidCallback? onPunch;

  /// Tapped to turn this till into a kiosk (POS ⇄ Kiosk). Null -- every caller
  /// but a till allowed to switch -- leaves the rail exactly as it was.
  final VoidCallback? onKioskMode;

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
    this.layout = PosCategoryLayout.list,
    this.imageBaseUrl,
    this.onPunch,
    this.onKioskMode,
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
              child: layout == PosCategoryLayout.tiles
                  ? _buildTileList(context)
                  : _buildTextList(context),
            ),
          ),
          if (onPunch != null || onKioskMode != null)
            _PosSidebarFooter(
              onPunch: onPunch,
              onKioskMode: onKioskMode,
              scale: scale,
            ),
        ],
      ),
    );
  }

  /// The original flat text rail.
  Widget _buildTextList(BuildContext context) {
    return ListView.separated(
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
    );
  }

  /// "Menu Variant 2 — Category Tiles with Photos" (Figma 2305:14721).
  ///
  /// Every tile token is a native design pixel scaled by [tileScale] so the
  /// rail keeps the Figma proportions at whatever width the pane was given.
  Widget _buildTileList(BuildContext context) {
    // Scale the design (a 600-wide list) down to the actual pane width.
    final double tileScale = width / PosHomeSpec.sidebarTileDesignWidth;
    return ListView.separated(
      padding: EdgeInsets.symmetric(
        vertical: PosHomeSpec.sidebarTileListPadV * tileScale,
      ),
      itemCount: categories.length,
      separatorBuilder: (_, __) =>
          SizedBox(height: PosHomeSpec.sidebarTileGap * tileScale),
      itemBuilder: (context, index) {
        final category = categories[index];
        final String image = category.image ?? '';
        return Center(
          child: PosCategoryTile(
            label: category.name ?? '',
            imageUrl: (imageBaseUrl != null && image.isNotEmpty)
                ? '$imageBaseUrl/$image'
                : null,
            selected: '${category.id}' == selectedId,
            onTap: () => onSelect(category),
            scale: tileScale,
          ),
        );
      },
    );
  }
}

/// The till's utility actions, pinned below the categories as the rail's
/// footer: a hairline across the pane (so a long, scrolled list ends cleanly
/// against it), then Kiosk Mode and Punch In / Out stacked on the category
/// column's edges.
class _PosSidebarFooter extends StatelessWidget {
  final VoidCallback? onPunch;
  final VoidCallback? onKioskMode;
  final double scale;

  const _PosSidebarFooter({
    required this.onPunch,
    required this.onKioskMode,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: PosHomeSpec.inkAlpha(PosHomeSpec.punchOutlineAlpha),
          ),
        ),
      ),
      child: Padding(
        padding: PosHomeSpec.punchFooterPadding * scale,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onKioskMode != null)
              PosKioskModeEntryButton(onTap: onKioskMode!, expand: true, scale: scale),
            if (onKioskMode != null && onPunch != null)
              SizedBox(height: PosHomeSpec.railActionGap * scale),
            if (onPunch != null)
              PosPunchEntryButton(onTap: onPunch!, expand: true, scale: scale),
          ],
        ),
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

/// A single category row in the tile variant (Figma 2305:14721).
///
/// A rounded card holding a cutout product photo (contain, never cropped) above
/// a centred, uppercase name of up to two lines. The active card is filled ink
/// with a cream name; inactive cards are the cream fill with a faint outline.
/// All geometry is a native design pixel multiplied by [scale].
class PosCategoryTile extends StatelessWidget {
  final String label;

  /// Fully-qualified image URL, or null for a name-only fallback (no image
  /// configured, or no base URL available).
  final String? imageUrl;
  final bool selected;
  final VoidCallback onTap;

  /// `paneWidth / PosHomeSpec.sidebarTileDesignWidth`.
  final double scale;

  const PosCategoryTile({
    super.key,
    required this.label,
    required this.imageUrl,
    required this.selected,
    required this.onTap,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius =
        BorderRadius.circular(PosHomeSpec.sidebarTileCardRadius * scale);
    final Color borderColor = selected
        ? PosHomeSpec.sidebarTileActiveBg
        : PosHomeSpec.sidebarTileCardBorderColor;

    return Material(
      color: selected
          ? PosHomeSpec.sidebarTileActiveBg
          : PosHomeSpec.sidebarTileCardBg,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          width: PosHomeSpec.sidebarTileCardWidth * scale,
          height: PosHomeSpec.sidebarTileCardHeight * scale,
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: borderColor,
              width: PosHomeSpec.sidebarTileCardBorder * scale,
            ),
          ),
          padding: EdgeInsets.only(
            top: PosHomeSpec.sidebarTileCardPadTop * scale,
            bottom: PosHomeSpec.sidebarTileCardPadBottom * scale,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Cutout product shot on the cream (or ink) background: no mask,
              // circle, border or fill behind it; contained so it is never
              // cropped. Missing image -> the slot collapses to nothing and the
              // name takes the whole card.
              if (imageUrl != null)
                SizedBox(
                  width: PosHomeSpec.sidebarTileImageWidth * scale,
                  height: PosHomeSpec.sidebarTileImageHeight * scale,
                  child: CustomImageWidget(
                    image: imageUrl!,
                    fit: BoxFit.contain,
                  ),
                ),
              Expanded(
                child: Center(
                  child: SizedBox(
                    width: PosHomeSpec.sidebarTileLabelWidth * scale,
                    child: Text(
                      label.toUpperCase(),
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: loewBold.copyWith(
                        fontSize: PosHomeSpec.sidebarTileLabelSize * scale,
                        height: 1,
                        color: selected
                            ? Colors.white
                            : PosHomeSpec.sidebarTileInk,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
