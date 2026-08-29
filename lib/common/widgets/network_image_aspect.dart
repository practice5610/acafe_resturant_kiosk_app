import 'dart:async';

import 'package:acafe_customer/common/widgets/custom_image_widget.dart';
import 'package:flutter/widgets.dart';

/// Reads the intrinsic aspect ratio (width / height) of a network image.
///
/// A layout that wants to size a slot to the artwork rather than crop it has to
/// know the artwork's shape, and that is only knowable once the image header
/// has been decoded. This resolves it through the SAME [ImageProvider]
/// [CustomImageWidget] renders with, so the decode is shared: the widget that
/// paints the image afterwards reads the already-warm cache entry instead of
/// downloading it a second time.
///
/// Results are cached for the process. Ratios do not change, and a synchronous
/// [peek] on the second build is what keeps the slot from resizing under the
/// user after a scroll or a rebuild.
class NetworkImageAspect {
  NetworkImageAspect._();

  static final Map<String, double> _cache = <String, double>{};
  static final Map<String, Future<double?>> _inFlight =
      <String, Future<double?>>{};

  /// The cached ratio, or null if this URL has not resolved yet. Never starts
  /// a load — call it during build, then [resolve] outside of one.
  static double? peek(String url) => _cache[url];

  /// Resolves the ratio, reusing an in-flight load for the same URL.
  ///
  /// Completes with null when the image is missing or fails to decode; callers
  /// fall back to a design default rather than showing nothing.
  static Future<double?> resolve(String url) {
    if (url.isEmpty) return Future<double?>.value(null);

    final double? cached = _cache[url];
    if (cached != null) return Future<double?>.value(cached);

    final Future<double?>? pending = _inFlight[url];
    if (pending != null) return pending;

    final Completer<double?> completer = Completer<double?>();
    _inFlight[url] = completer.future;

    final ImageStream stream = CustomImageWidget.provider(url)
        .resolve(ImageConfiguration.empty);

    void finish(double? aspect) {
      _inFlight.remove(url);
      if (aspect != null) _cache[url] = aspect;
      if (!completer.isCompleted) completer.complete(aspect);
    }

    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (ImageInfo info, bool _) {
        // The ImageInfo handed to a listener stays owned by the stream, so
        // read the dimensions and leave it alone — disposing it here would
        // pull the decoded frame out from under the widget that paints it.
        final int w = info.image.width;
        final int h = info.image.height;
        stream.removeListener(listener);
        finish(h > 0 ? w / h : null);
      },
      onError: (Object error, StackTrace? stack) {
        stream.removeListener(listener);
        finish(null);
      },
    );
    stream.addListener(listener);

    return completer.future;
  }

  /// Resolves several URLs at once. Used by the deal carousel, which has to
  /// size one shared slot around every banner it will page through.
  static Future<void> resolveAll(Iterable<String> urls) async {
    await Future.wait(urls.where((u) => u.isNotEmpty).toSet().map(resolve));
  }

  /// Test seam: drops everything resolved so far.
  @visibleForTesting
  static void clearCache() {
    _cache.clear();
    _inFlight.clear();
  }

  /// Test seam: seeds a ratio without touching the network.
  @visibleForTesting
  static void seed(String url, double aspect) => _cache[url] = aspect;
}
