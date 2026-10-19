import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// One row of [columns] equal-width cells, every one as tall as the tallest —
/// what `IntrinsicHeight(Row(crossAxisAlignment: stretch))` is usually reached
/// for, but measured from real layout instead of intrinsic estimates.
///
/// The difference shows on web. When a glyph is missing from the loaded fonts
/// (`→` in Roboto), CanvasKit downloads a Noto fallback *after* the first
/// frame. Every [RenderParagraph] relayouts with the new, taller line, but
/// Flutter keeps answering intrinsic queries from the old measurement —
/// `systemFontsDidChange` resets the paragraph's painter, not its
/// `_textIntrinsicsCache`. An IntrinsicHeight row therefore keeps its stale
/// height while the tallest card grows, and that card overflows (the Report's
/// Staff Shifts & Tips card, by 10px). Here each cell is laid out at the
/// column width, the tallest result becomes the row height, and the cells are
/// laid out again with that height as their minimum.
///
/// The second pass is a minimum height, not a tight one, on purpose: a tight
/// constraint makes a cell a relayout boundary, so a later change inside a
/// card would stop there and never reach the row to re-measure it. Cells
/// should be min-size columns whose slack falls at the bottom — a vertical
/// [Spacer] or [Expanded] inside one has no bounded height to fill.
///
/// With fewer children than [columns], the trailing columns stay empty, so a
/// lone last card keeps its column width instead of stretching across the gap.
class PosEqualHeightRow extends MultiChildRenderObjectWidget {
  final int columns;

  /// Between cells.
  final double spacing;

  const PosEqualHeightRow({
    super.key,
    required this.columns,
    this.spacing = 0,
    super.children,
  }) : assert(columns > 0);

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderPosEqualHeightRow(
        columns: columns,
        spacing: spacing,
        textDirection: Directionality.maybeOf(context) ?? TextDirection.ltr,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderPosEqualHeightRow renderObject,
  ) {
    renderObject
      ..columns = columns
      ..spacing = spacing
      ..textDirection = Directionality.maybeOf(context) ?? TextDirection.ltr;
  }
}

class _RowParentData extends ContainerBoxParentData<RenderBox> {}

class RenderPosEqualHeightRow extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _RowParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _RowParentData> {
  RenderPosEqualHeightRow({
    required int columns,
    required double spacing,
    required TextDirection textDirection,
  })  : _columns = columns,
        _spacing = spacing,
        _textDirection = textDirection;

  int _columns;
  set columns(int value) {
    if (value == _columns) return;
    _columns = value;
    markNeedsLayout();
  }

  double _spacing;
  set spacing(double value) {
    if (value == _spacing) return;
    _spacing = value;
    markNeedsLayout();
  }

  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (value == _textDirection) return;
    _textDirection = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _RowParentData) {
      child.parentData = _RowParentData();
    }
  }

  double _cellWidthFor(double width) =>
      math.max(0, (width - (_columns - 1) * _spacing) / _columns);

  /// The largest of [measure] over every child.
  double _tallest(double Function(RenderBox child) measure) {
    double height = 0;
    RenderBox? child = firstChild;
    while (child != null) {
      height = math.max(height, measure(child));
      child = childAfter(child);
    }
    return height;
  }

  @override
  void performLayout() {
    final BoxConstraints constraints = this.constraints;
    assert(
      constraints.hasBoundedWidth,
      'PosEqualHeightRow divides its width into columns, so it needs a '
      'bounded width.',
    );
    assert(childCount <= _columns, 'More cells than columns.');

    final double cellWidth = _cellWidthFor(constraints.maxWidth);

    // Pass 1: each cell's own height at the column width. parentUsesSize, so a
    // cell whose content later changes height (a late font) relayouts the row.
    final BoxConstraints natural = BoxConstraints.tightFor(width: cellWidth);
    final double height = constraints.constrainHeight(_tallest((child) {
      child.layout(natural, parentUsesSize: true);
      return child.size.height;
    }));

    // Pass 2: every cell at least the tallest height. Deliberately not tight
    // (see the class doc), so cells stay inside this row's relayout scope.
    final BoxConstraints cell = BoxConstraints(
      minWidth: cellWidth,
      maxWidth: cellWidth,
      minHeight: height,
      maxHeight: constraints.maxHeight,
    );
    int index = 0;
    RenderBox? child = firstChild;
    while (child != null) {
      child.layout(cell, parentUsesSize: true);
      final double x = index * (cellWidth + _spacing);
      final _RowParentData data = child.parentData! as _RowParentData;
      data.offset = Offset(
        _textDirection == TextDirection.rtl
            ? constraints.maxWidth - x - cellWidth
            : x,
        0,
      );
      child = data.nextSibling;
      index++;
    }

    size = constraints.constrain(Size(constraints.maxWidth, height));
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final BoxConstraints natural =
        BoxConstraints.tightFor(width: _cellWidthFor(constraints.maxWidth));
    return constraints.constrain(Size(
      constraints.maxWidth,
      _tallest((child) => child.getDryLayout(natural).height),
    ));
  }

  @override
  double computeMinIntrinsicWidth(double height) =>
      _columns * _tallest((child) => child.getMinIntrinsicWidth(height)) +
      (_columns - 1) * _spacing;

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _columns * _tallest((child) => child.getMaxIntrinsicWidth(height)) +
      (_columns - 1) * _spacing;

  @override
  double computeMinIntrinsicHeight(double width) {
    final double cellWidth = _cellWidthFor(width);
    return _tallest((child) => child.getMinIntrinsicHeight(cellWidth));
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    final double cellWidth = _cellWidthFor(width);
    return _tallest((child) => child.getMaxIntrinsicHeight(cellWidth));
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);
}
