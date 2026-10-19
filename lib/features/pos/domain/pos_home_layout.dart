import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_responsive.dart';
import 'package:flutter/widgets.dart';

/// Every size the POS home screen derives from the window, resolved in one
/// place so the panes, the toolbar and the grid always agree on which device
/// they are on.
///
/// Two compositions:
///
///  * **Rail** (window ≥ [PosResponsive.compactMax]): the Figma frame —
///    category rail, product pane and, room permitting, the pinned receipt.
///    Content scales with the panes via [PosResponsive.homeScale].
///  * **Compact** (phones, narrow windows): a 192px rail would take a third
///    of the screen, so the categories move into a strip above the search
///    field, the tag pills become one swipeable row, gutters tighten, and the
///    receipt docks as a bottom bar.
///
/// In both, the grid's column count follows the width it is handed, so a
/// tile stays near its designed size instead of shrinking inside a fixed
/// three columns.
@immutable
class PosHomeLayout {
  final Size window;

  /// Categories as a top strip instead of the side rail.
  final bool compact;

  /// Receipt pinned beside the products (otherwise a bottom bar + sheet).
  final bool sideReceipt;

  /// Content density, see [PosResponsive.homeScale].
  final double scale;

  final double sidebarWidth;
  final double receiptWidth;

  const PosHomeLayout._({
    required this.window,
    required this.compact,
    required this.sideReceipt,
    required this.scale,
    required this.sidebarWidth,
    required this.receiptWidth,
  });

  /// Widest a tile may grow before the grid adds a column, as a multiple of
  /// its designed (scaled) width. 1.2 keeps three columns at every Figma
  /// desktop size, two on a phone, and adds columns on very large displays
  /// rather than blowing tiles up.
  static const double maxTileStretch = 1.2;

  static const int maxGridColumns = 8;

  factory PosHomeLayout.resolve(Size window) {
    final PosMetrics metrics = PosMetrics.resolve(window);
    final double width = window.width;
    return PosHomeLayout._(
      window: window,
      compact: metrics.isCompact,
      sideReceipt: metrics.showsSideReceipt,
      scale: PosResponsive.homeScale(width),
      sidebarWidth: PosResponsive.sidebarWidth(width),
      // Below the desktop floor the home receipt keeps its flat design
      // width; see PosResponsive.receiptWidth for why home branches here.
      receiptWidth: width >= PosResponsive.desktopFloor
          ? PosResponsive.receiptWidth(width)
          : PosHomeSpec.receiptWidth,
    );
  }

  /// The window [PosShell] published, or MediaQuery's where there is no shell
  /// (widget tests that mount the screen bare).
  static PosHomeLayout of(BuildContext context) => PosHomeLayout.resolve(
      PosMetrics.maybeOf(context)?.window ?? MediaQuery.sizeOf(context));

  // ── Content pane ─────────────────────────────────────────────────────

  /// Product pane edge → search field, pills and grid.
  double get contentInsetLeft => compact
      ? PosHomeSpec.compactGutter
      : PosHomeSpec.contentPaddingLeft * scale;

  double get contentInsetTop => compact
      ? PosHomeSpec.compactGutter
      : PosHomeSpec.contentPaddingTop * scale;

  /// Product pane edge → the grid's scroll track. Held fixed on the rail
  /// layout: it is the track's own geometry, not part of the toolbar.
  double get contentInsetRight =>
      compact ? PosHomeSpec.compactScrollbarInset : PosHomeSpec.scrollbarInset;

  /// Extra right inset on the search field and pills, past
  /// [contentInsetRight], so they end where the tiles do.
  double get toolbarInsetRight => compact
      ? PosHomeSpec.compactGridInsetRight
      : (PosHomeSpec.searchPaddingRight - PosHomeSpec.scrollbarInset) * scale;

  /// Grid viewport's right edge → the last tile column.
  double get gridInsetRight => compact
      ? PosHomeSpec.compactGridInsetRight
      : PosHomeSpec.gridViewportRightPad;

  /// Search → pills, and pills → grid.
  double get sectionGap =>
      compact ? PosHomeSpec.compactSectionGap : PosHomeSpec.sectionGap * scale;

  /// Fade over the bottom of the grid (and the scroll room under its last
  /// row, so that row can clear it).
  double get fadeHeight =>
      compact ? PosHomeSpec.compactFadeHeight : PosHomeSpec.contentFadeHeight;

  double get scrollbarTrackBottom => compact
      ? PosHomeSpec.compactScrollbarTrackBottom
      : PosHomeSpec.scrollbarTrackBottom;

  // ── Grid ─────────────────────────────────────────────────────────────

  /// Columns for a grid viewport [width] wide: the fewest that keep every
  /// tile within [maxTileStretch] of its designed width at this [scale].
  int gridColumns(double width) {
    final double usable = width - gridInsetRight;
    if (!usable.isFinite || usable <= 0) return 1;
    const double gap = PosHomeSpec.gridColumnGap;
    final double maxTile = PosHomeSpec.tileWidth * scale * maxTileStretch;
    return ((usable + gap) / (maxTile + gap)).ceil().clamp(1, maxGridColumns);
  }

  @override
  bool operator ==(Object other) =>
      other is PosHomeLayout && other.window == window;

  @override
  int get hashCode => window.hashCode;
}
