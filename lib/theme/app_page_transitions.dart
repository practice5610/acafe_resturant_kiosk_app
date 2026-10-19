import 'package:flutter/material.dart';

/// Screen-to-screen navigation for the whole app: the new screen slides in
/// from the right over the old one, which eases a little to the left. Going
/// back plays it in reverse. No fade and no zoom: the plain push a till uses.
///
/// Replaces [ZoomPageTransitionsBuilder], which Flutter falls back to on
/// every platform this app runs on (Android, iPad, web/macOS) and which reads
/// as a fade. No back-swipe gesture either, unlike
/// [CupertinoPageTransitionsBuilder]: a swipe must never leave the payment or
/// refund screen mid-charge.
class AppSlidePageTransitionsBuilder extends PageTransitionsBuilder {
  const AppSlidePageTransitionsBuilder();

  @override
  Duration get transitionDuration => const Duration(milliseconds: 250);

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return _AppSlideTransition(
      animation: animation,
      secondaryAnimation: secondaryAnimation,
      child: child,
    );
  }
}

/// Every platform on [AppSlidePageTransitionsBuilder], shared by the light
/// and dark themes.
const PageTransitionsTheme appPageTransitionsTheme = PageTransitionsTheme(
  builders: {
    TargetPlatform.android: AppSlidePageTransitionsBuilder(),
    TargetPlatform.iOS: AppSlidePageTransitionsBuilder(),
    TargetPlatform.fuchsia: AppSlidePageTransitionsBuilder(),
    TargetPlatform.linux: AppSlidePageTransitionsBuilder(),
    TargetPlatform.macOS: AppSlidePageTransitionsBuilder(),
    TargetPlatform.windows: AppSlidePageTransitionsBuilder(),
  },
);

/// Stateful so the curved animations — which listen to the route's — are
/// disposed with the route instead of piling up on every rebuild.
class _AppSlideTransition extends StatefulWidget {
  final Animation<double> animation;
  final Animation<double> secondaryAnimation;
  final Widget child;

  const _AppSlideTransition({
    required this.animation,
    required this.secondaryAnimation,
    required this.child,
  });

  @override
  State<_AppSlideTransition> createState() => _AppSlideTransitionState();
}

class _AppSlideTransitionState extends State<_AppSlideTransition> {
  static final Animatable<Offset> _enter = Tween<Offset>(
    begin: const Offset(1, 0),
    end: Offset.zero,
  );

  static final Animatable<Offset> _underneath = Tween<Offset>(
    begin: Offset.zero,
    end: const Offset(-0.3, 0),
  );

  late CurvedAnimation _primary;
  late CurvedAnimation _secondary;

  @override
  void initState() {
    super.initState();
    _primary = _curved(widget.animation);
    _secondary = _curved(widget.secondaryAnimation);
  }

  @override
  void didUpdateWidget(_AppSlideTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animation != widget.animation) {
      _primary.dispose();
      _primary = _curved(widget.animation);
    }
    if (oldWidget.secondaryAnimation != widget.secondaryAnimation) {
      _secondary.dispose();
      _secondary = _curved(widget.secondaryAnimation);
    }
  }

  @override
  void dispose() {
    _primary.dispose();
    _secondary.dispose();
    super.dispose();
  }

  /// Decelerates both ways: a push settles into place, a pop leaves fast.
  static CurvedAnimation _curved(Animation<double> parent) => CurvedAnimation(
        parent: parent,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _underneath.animate(_secondary),
      child: SlideTransition(
        position: _enter.animate(_primary),
        child: widget.child,
      ),
    );
  }
}
