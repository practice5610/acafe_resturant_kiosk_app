// Product photo that fills its box by its VISIBLE content, not its canvas.
//
// The product files (rembg + WebP import pipeline) are 667×1000 / 800×1000
// canvases with wide transparent margins: a drink fills ~50% × 65% of the file,
// a poffertjes tray ~77% × 32%. BoxFit.contain fits the whole canvas, so the
// visible photo came out at roughly half the card's image area. This widget
// finds the opaque bounds once per URL (cached for the session) and lays the
// full-resolution image out so those bounds are "contained" in the box —
// tall drinks touch top and bottom, wide trays touch left and right.
//
// Purely visual: same URL, same CustomImageWidget (cache, placeholder,
// shimmer, picture-less mode). If the bounds cannot be read, it falls back to
// plain BoxFit.contain.
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:acafe_customer/common/widgets/custom_image_widget.dart';
import 'package:acafe_customer/utill/images.dart';

/// Opaque bounds as fractions of the image (left, top, right, bottom).
class _Bounds {
  final double l, t, r, b, aspect; // aspect = image width / height
  const _Bounds(this.l, this.t, this.r, this.b, this.aspect);
}

class KioskTrimmedImage extends StatefulWidget {
  final String image;
  const KioskTrimmedImage({super.key, required this.image});

  /// url → bounds (null = could not be read; use plain contain).
  static final Map<String, _Bounds?> _cache = <String, _Bounds?>{};

  @override
  State<KioskTrimmedImage> createState() => _KioskTrimmedImageState();
}

class _KioskTrimmedImageState extends State<KioskTrimmedImage> {
  ImageStream? _stream;
  ImageStreamListener? _listener;

  bool get _known => KioskTrimmedImage._cache.containsKey(widget.image);

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant KioskTrimmedImage old) {
    super.didUpdateWidget(old);
    if (old.image != widget.image) {
      _stop();
      _resolve();
    }
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  void _stop() {
    if (_listener != null) _stream?.removeListener(_listener!);
    _stream = null;
    _listener = null;
  }

  void _resolve() {
    if (_known || !CustomImageWidget.showProductImages || widget.image.isEmpty) return;
    if (CustomImageWidget.isDefaultImage(widget.image) ||
        widget.image.endsWith('/') ||
        widget.image.endsWith('/null')) {
      return;
    }
    final String url = widget.image;
    final ImageStream stream =
        CustomImageWidget.provider(url).resolve(ImageConfiguration.empty);
    final listener = ImageStreamListener(
      (ImageInfo info, bool _) {
        // Clone: the stream owns info.image and may dispose it.
        final ui.Image img = info.image.clone();
        _measure(img).then((bounds) {
          img.dispose();
          KioskTrimmedImage._cache[url] = bounds;
          if (mounted && widget.image == url) setState(() {});
        });
        _stop();
      },
      onError: (Object _, StackTrace? __) {
        KioskTrimmedImage._cache[url] = null;
        if (mounted) setState(() {});
        _stop();
      },
    );
    _stream = stream;
    _listener = listener;
    stream.addListener(listener);
  }

  static Future<_Bounds?> _measure(ui.Image img) async {
    try {
      final int w = img.width, h = img.height;
      final data = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (data == null || w == 0 || h == 0) return null;
      // Sample every 2nd pixel; alpha > 16 counts as content.
      const int step = 2;
      int minX = w, minY = h, maxX = -1, maxY = -1;
      for (int y = 0; y < h; y += step) {
        final int row = y * w * 4;
        for (int x = 0; x < w; x += step) {
          if (data.getUint8(row + x * 4 + 3) > 16) {
            if (x < minX) minX = x;
            if (x > maxX) maxX = x;
            if (y < minY) minY = y;
            if (y > maxY) maxY = y;
          }
        }
      }
      if (maxX < 0) return null; // fully transparent / opaque-less: no trim
      return _Bounds(
        minX / w,
        minY / h,
        ((maxX + step).clamp(0, w)) / w,
        ((maxY + step).clamp(0, h)) / h,
        w / h,
      );
    } catch (_) {
      return null;
    }
  }

  Widget _plain() => CustomImageWidget(
        emptyWhenMissing: true,
        placeholder: Images.placeholderImage,
        image: widget.image,
        fit: BoxFit.contain,
        useShimmer: true,
      );

  @override
  Widget build(BuildContext context) {
    if (!_known) {
      // Still measuring (or nothing to measure): the plain contained image,
      // which also owns the loading shimmer and the missing-file placeholder.
      return _plain();
    }
    final _Bounds? b = KioskTrimmedImage._cache[widget.image];
    if (b == null) return _plain();
    return LayoutBuilder(
      builder: (context, box) {
        final double bw = box.maxWidth, bh = box.maxHeight;
        // Content size per unit of displayed image height.
        final double contentW = (b.r - b.l) * b.aspect;
        final double contentH = b.b - b.t;
        if (contentW <= 0 || contentH <= 0) return _plain();
        // Displayed image height so the content is "contained" in the box.
        final double dispH =
            (bw / contentW) < (bh / contentH) ? bw / contentW : bh / contentH;
        final double dispW = dispH * b.aspect;
        final double left = bw / 2 - (b.l + b.r) / 2 * dispW;
        final double top = bh / 2 - (b.t + b.b) / 2 * dispH;
        return ClipRect(
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned(
                left: left,
                top: top,
                width: dispW,
                height: dispH,
                child: CustomImageWidget(
                  emptyWhenMissing: true,
                  placeholder: Images.placeholderImage,
                  image: widget.image,
                  width: dispW,
                  height: dispH,
                  fit: BoxFit.fill,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

