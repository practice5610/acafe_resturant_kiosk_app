import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// A section's cards: a left-aligned wrap of [itemWidth]-wide cells in which
/// every card is exactly as tall as the tallest one.
///
/// A plain [Wrap] lets each card keep its own height, so an order with a
/// two-line note, one with a one-line note and one with none come out three
/// different sizes side by side. Here the grid asks each card how tall it
/// wants to be at the cell width (its max intrinsic height), takes the largest,
/// and lays every card out at exactly that size. [PosOrderCardTile] pins its
/// timer and price to its bottom edge, so a shorter card's slack opens up
/// above them and the prices still line up across the row.
///
/// Like [Wrap], a cell never outgrows the grid: once the pane is narrower than
/// [itemWidth], the cards take the pane's width instead of overflowing it.
class PosOrderCardGrid extends MultiChildRenderObjectWidget {
  final double itemWidth;

  /// Between cards on a row.
  final double spacing;

  /// Between rows.
  final double runSpacing;

  const PosOrderCardGrid({
    super.key,
    required this.itemWidth,
    this.spacing = 0,
    this.runSpacing = 0,
    super.children,
  });

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderPosOrderCardGrid(
        itemWidth: itemWidth,
        spacing: spacing,
        runSpacing: runSpacing,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderPosOrderCardGrid renderObject,
  ) {
    renderObject
      ..itemWidth = itemWidth
      ..spacing = spacing
      ..runSpacing = runSpacing;
  }
}

class _GridParentData extends ContainerBoxParentData<RenderBox> {}

class RenderPosOrderCardGrid extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _GridParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _GridParentData> {
  RenderPosOrderCardGrid({
    required double itemWidth,
    required double spacing,
    required double runSpacing,
  })  : _itemWidth = itemWidth,
        _spacing = spacing,
        _runSpacing = runSpacing;

  double _itemWidth;
  set itemWidth(double value) {
    if (value == _itemWidth) return;
    _itemWidth = value;
    markNeedsLayout();
  }

  double _spacing;
  set spacing(double value) {
    if (value == _spacing) return;
    _spacing = value;
    markNeedsLayout();
  }

  double _runSpacing;
  set runSpacing(double value) {
    if (value == _runSpacing) return;
    _runSpacing = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _GridParentData) {
      child.parentData = _GridParentData();
    }
  }

  double _cellWidthFor(double maxWidth) => math.min(_itemWidth, maxWidth);

  /// Cards per row: as many as fit, never fewer than one, never more than
  /// there are cards.
  int _columnsFor(double maxWidth, double cellWidth) {
    final int fit = maxWidth.isFinite
        ? ((maxWidth + _spacing) / (cellWidth + _spacing)).floor()
        : childCount;
    return math.max(1, math.min(fit, childCount));
  }

  /// The one height every card gets: the tallest card's own.
  double _cellHeightFor(double cellWidth) {
    double height = 0;
    RenderBox? child = firstChild;
    while (child != null) {
      height = math.max(height, child.getMaxIntrinsicHeight(cellWidth));
      child = childAfter(child);
    }
    return height;
  }

  Size _sizeFor(BoxConstraints constraints) {
    if (firstChild == null) return constraints.smallest;
    final double cellWidth = _cellWidthFor(constraints.maxWidth);
    final int columns = _columnsFor(constraints.maxWidth, cellWidth);
    final int rows = (childCount / columns).ceil();
    return constraints.constrain(Size(
      columns * cellWidth + (columns - 1) * _spacing,
      rows * _cellHeightFor(cellWidth) + (rows - 1) * _runSpacing,
    ));
  }

  @override
  void performLayout() {
    final BoxConstraints constraints = this.constraints;
    if (firstChild == null) {
      size = constraints.smallest;
      return;
    }

    final double cellWidth = _cellWidthFor(constraints.maxWidth);
    final double cellHeight = _cellHeightFor(cellWidth);
    final int columns = _columnsFor(constraints.maxWidth, cellWidth);
    final BoxConstraints cell =
        BoxConstraints.tight(Size(cellWidth, cellHeight));

    int index = 0;
    RenderBox? child = firstChild;
    while (child != null) {
      child.layout(cell);
      final _GridParentData data = child.parentData! as _GridParentData;
      data.offset = Offset(
        (index % columns) * (cellWidth + _spacing),
        (index ~/ columns) * (cellHeight + _runSpacing),
      );
      child = data.nextSibling;
      index++;
    }

    size = _sizeFor(constraints);
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) =>
      _sizeFor(constraints);

  @override
  double computeMinIntrinsicWidth(double height) =>
      firstChild == null ? 0 : _itemWidth;

  @override
  double computeMaxIntrinsicWidth(double height) => firstChild == null
      ? 0
      : childCount * _itemWidth + (childCount - 1) * _spacing;

  @override
  double computeMinIntrinsicHeight(double width) =>
      _sizeFor(BoxConstraints(maxWidth: width)).height;

  @override
  double computeMaxIntrinsicHeight(double width) =>
      computeMinIntrinsicHeight(width);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);
}
