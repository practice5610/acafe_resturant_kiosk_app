import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// A top-to-bottom stack that always shows all of its content inside the
/// height it is given — for the payment panes, which Figma draws at 1366×1024
/// but which also run in shorter windows.
///
/// At the frame's size it lays out exactly like a [Column] of natural-height
/// children. When the height runs short it gives way in this order:
///
///  1. the child at [flexIndex] (the keypad, the item list) shrinks from
///     [flexMax] towards [flexMin] — everything else keeps its design size;
///  2. only if even [flexMin] does not fit, the whole stack scales down
///     uniformly until it does, rather than clipping or scrolling it.
///
/// The flex child is always laid out at a tight height, so it should fill
/// whatever it is given (e.g. through a [LayoutBuilder]). With an unbounded
/// height (a stacked, scrolling layout) the flex child gets [flexMax] and
/// nothing scales.
class PosFitColumn extends MultiChildRenderObjectWidget {
  /// Index into [children] of the child that absorbs the spare height; null
  /// when every child keeps its natural height.
  final int? flexIndex;
  final double flexMin;
  final double flexMax;

  const PosFitColumn({
    super.key,
    required super.children,
    this.flexIndex,
    this.flexMin = 0,
    this.flexMax = double.infinity,
  }) : assert(flexMin >= 0 && flexMax >= flexMin);

  @override
  RenderPosFitColumn createRenderObject(BuildContext context) =>
      RenderPosFitColumn(
        flexIndex: flexIndex,
        flexMin: flexMin,
        flexMax: flexMax,
      );

  @override
  void updateRenderObject(
      BuildContext context, RenderPosFitColumn renderObject) {
    renderObject
      ..flexIndex = flexIndex
      ..flexMin = flexMin
      ..flexMax = flexMax;
  }
}

class _FitColumnParentData extends ContainerBoxParentData<RenderBox> {}

class RenderPosFitColumn extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _FitColumnParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _FitColumnParentData> {
  RenderPosFitColumn({
    required int? flexIndex,
    required double flexMin,
    required double flexMax,
  })  : _flexIndex = flexIndex,
        _flexMin = flexMin,
        _flexMax = flexMax;

  int? _flexIndex;
  int? get flexIndex => _flexIndex;
  set flexIndex(int? value) {
    if (value == _flexIndex) return;
    _flexIndex = value;
    markNeedsLayout();
  }

  double _flexMin;
  double get flexMin => _flexMin;
  set flexMin(double value) {
    if (value == _flexMin) return;
    _flexMin = value;
    markNeedsLayout();
  }

  double _flexMax;
  double get flexMax => _flexMax;
  set flexMax(double value) {
    if (value == _flexMax) return;
    _flexMax = value;
    markNeedsLayout();
  }

  /// The uniform scale the stack is painted at; 1 unless the height ran out.
  double get scale => _scale;
  double _scale = 1;

  final LayerHandle<TransformLayer> _transformLayer =
      LayerHandle<TransformLayer>();

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _FitColumnParentData) {
      child.parentData = _FitColumnParentData();
    }
  }

  bool _isFlex(int index) => _flexIndex != null && index == _flexIndex;

  /// The flex child's extent when nothing constrains it.
  double get _flexNatural => _flexMax.isFinite ? _flexMax : _flexMin;

  /// Lays out every child at [width] (the flex child at [flexExtent]) and
  /// stacks them; returns the total height.
  double _layoutAll(double width, double flexExtent) {
    double y = 0;
    int index = 0;
    RenderBox? child = firstChild;
    while (child != null) {
      final _FitColumnParentData data =
          child.parentData! as _FitColumnParentData;
      child.layout(
        _isFlex(index)
            ? BoxConstraints.tightFor(width: width, height: flexExtent)
            : BoxConstraints.tightFor(width: width),
        parentUsesSize: true,
      );
      data.offset = Offset(0, y);
      y += child.size.height;
      child = data.nextSibling;
      index++;
    }
    return y;
  }

  /// Heights of the children that keep their natural size, at [width].
  double _fixedHeight(double width) {
    double fixed = 0;
    int index = 0;
    RenderBox? child = firstChild;
    while (child != null) {
      if (!_isFlex(index)) {
        child.layout(BoxConstraints.tightFor(width: width),
            parentUsesSize: true);
        fixed += child.size.height;
      }
      child = (child.parentData! as _FitColumnParentData).nextSibling;
      index++;
    }
    return fixed;
  }

  bool get _hasFlex => _flexIndex != null && _flexIndex! < childCount;

  @override
  void performLayout() {
    final double width = constraints.maxWidth;
    final double maxHeight = constraints.maxHeight;
    _scale = 1;

    if (!maxHeight.isFinite) {
      final double total = _layoutAll(width, _hasFlex ? _flexNatural : 0);
      size = constraints.constrain(Size(width, total));
      return;
    }

    final double fixed = _fixedHeight(width);
    final double room = maxHeight - fixed;
    if (!_hasFlex || room >= _flexMin) {
      final double flexExtent =
          _hasFlex ? room.clamp(_flexMin, _flexMax).toDouble() : 0;
      if (fixed + flexExtent <= maxHeight + 0.5) {
        size = constraints
            .constrain(Size(width, _layoutAll(width, flexExtent)));
        return;
      }
    }

    // Even the flex child's minimum does not fit: scale the whole stack down.
    // Children are laid out wider by 1/scale so they still fill the width
    // once scaled; wider text can only wrap less, so a second pass settles it.
    double total = fixed + (_hasFlex ? _flexMin : 0);
    double s = maxHeight / total;
    for (int pass = 0; pass < 2; pass++) {
      total = _layoutAll(width / s, _hasFlex ? _flexMin : 0);
      if (total * s <= maxHeight + 0.5) break;
      s = maxHeight / total;
    }
    _scale = math.min(1, s);
    size = constraints.constrain(Size(width, total * _scale));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_scale == 1) {
      _transformLayer.layer = null;
      defaultPaint(context, offset);
      return;
    }
    _transformLayer.layer = context.pushTransform(
      needsCompositing,
      offset,
      Matrix4.diagonal3Values(_scale, _scale, 1),
      defaultPaint,
      oldLayer: _transformLayer.layer,
    );
  }

  @override
  void dispose() {
    _transformLayer.layer = null;
    super.dispose();
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    if (_scale == 1) {
      return defaultHitTestChildren(result, position: position);
    }
    return result.addWithPaintTransform(
      transform: Matrix4.diagonal3Values(_scale, _scale, 1),
      position: position,
      hitTest: (BoxHitTestResult result, Offset position) =>
          defaultHitTestChildren(result, position: position),
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    if (_scale != 1) transform.scaleByDouble(_scale, _scale, 1, 1);
    super.applyPaintTransform(child, transform);
  }

  double _sumHeights(double width, double Function(RenderBox, double) of,
      double flexExtent) {
    double total = 0;
    int index = 0;
    RenderBox? child = firstChild;
    while (child != null) {
      total += _isFlex(index) ? flexExtent : of(child, width);
      child = (child.parentData! as _FitColumnParentData).nextSibling;
      index++;
    }
    return total;
  }

  double _maxWidth(double height, double Function(RenderBox, double) of) {
    double widest = 0;
    RenderBox? child = firstChild;
    while (child != null) {
      widest = math.max(widest, of(child, height));
      child = (child.parentData! as _FitColumnParentData).nextSibling;
    }
    return widest;
  }

  @override
  double computeMinIntrinsicWidth(double height) =>
      _maxWidth(height, (c, h) => c.getMinIntrinsicWidth(h));

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _maxWidth(height, (c, h) => c.getMaxIntrinsicWidth(h));

  @override
  double computeMinIntrinsicHeight(double width) =>
      _sumHeights(width, (c, w) => c.getMinIntrinsicHeight(w), _flexMin);

  @override
  double computeMaxIntrinsicHeight(double width) =>
      _sumHeights(width, (c, w) => c.getMaxIntrinsicHeight(w), _flexNatural);
}
