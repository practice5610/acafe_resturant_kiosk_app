import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// One row of chips that scrolls sideways when it is wider than its slot —
/// the compact category strip and tag pills.
///
/// A bare horizontal [SingleChildScrollView] fails a POS that ships as
/// Flutter web in three ways, all fixed here:
///
///  * Flutter drags scrollables with touch only by default, so with a mouse
///    the clipped end of the row was unreachable. Mouse, trackpad and stylus
///    drag are enabled, and a vertical wheel scrolls the row sideways.
///  * Nothing said the row continued. The leading/trailing edge fades out
///    whenever there is more content past it.
///  * Scrollbars stay off — the fade is the affordance, and a bar under a
///    32px chip row is noise.
class PosHorizontalScroller extends StatefulWidget {
  final List<Widget> children;

  /// Gap between neighbouring children.
  final double spacing;

  /// Inside the scroll extent, so the first and last chip can scroll to the
  /// same inset as the rest of the screen's content.
  final EdgeInsetsGeometry padding;

  /// Width of the edge fade.
  final double fadeExtent;

  const PosHorizontalScroller({
    super.key,
    required this.children,
    this.spacing = 8,
    this.padding = EdgeInsets.zero,
    this.fadeExtent = 24,
  });

  @override
  State<PosHorizontalScroller> createState() => _PosHorizontalScrollerState();
}

class _PosHorizontalScrollerState extends State<PosHorizontalScroller> {
  final ScrollController _controller = ScrollController();
  bool _moreBefore = false;
  bool _moreAfter = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _controller.hasClients) _sync(_controller.position);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _sync(ScrollMetrics metrics) {
    final bool before = metrics.extentBefore > 0.5;
    final bool after = metrics.extentAfter > 0.5;
    if (before == _moreBefore && after == _moreAfter) return;
    setState(() {
      _moreBefore = before;
      _moreAfter = after;
    });
  }

  /// A mouse wheel only moves along its own axis, so on a horizontal row a
  /// plain (vertical) wheel would do nothing. Horizontal deltas are left to
  /// the scrollable itself.
  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || !_controller.hasClients) return;
    if (event.scrollDelta.dx != 0 || event.scrollDelta.dy == 0) return;
    final ScrollPosition position = _controller.position;
    if (position.maxScrollExtent <= 0) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (_) {
      position.jumpTo((position.pixels + event.scrollDelta.dy)
          .clamp(position.minScrollExtent, position.maxScrollExtent));
    });
  }

  @override
  Widget build(BuildContext context) {
    final ScrollBehavior behavior = ScrollConfiguration.of(context).copyWith(
      scrollbars: false,
      dragDevices: const {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
        PointerDeviceKind.invertedStylus,
      },
    );

    // The mask is always in the tree, opaque where there is nothing to hint
    // at: toggling the wrapper on and off would remount the scroll view and
    // throw away its position.
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (Rect bounds) {
        final double stop = bounds.width <= 0
            ? 0
            : (widget.fadeExtent / bounds.width).clamp(0.0, 0.5);
        return LinearGradient(
          colors: [
            _moreBefore ? Colors.transparent : Colors.black,
            Colors.black,
            Colors.black,
            _moreAfter ? Colors.transparent : Colors.black,
          ],
          stops: [0, stop, 1 - stop, 1],
        ).createShader(bounds);
      },
      child: NotificationListener<ScrollMetricsNotification>(
        onNotification: (notification) {
          _sync(notification.metrics);
          return false;
        },
        child: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            _sync(notification.metrics);
            return false;
          },
          child: Listener(
            onPointerSignal: _onPointerSignal,
            child: ScrollConfiguration(
              behavior: behavior,
              child: SingleChildScrollView(
                controller: _controller,
                scrollDirection: Axis.horizontal,
                padding: widget.padding,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (int i = 0; i < widget.children.length; i++) ...[
                      if (i > 0) SizedBox(width: widget.spacing),
                      widget.children[i],
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
