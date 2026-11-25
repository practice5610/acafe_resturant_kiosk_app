import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:acafe_customer/common/responsive/kiosk_layout.dart';
import 'package:acafe_customer/common/responsive/kiosk_responsive.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_tip.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_translate.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_scrim.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_tap.dart';
import 'package:acafe_customer/helper/price_converter_helper.dart';
import 'package:acafe_customer/theme/text_legibility.dart';
import 'package:acafe_customer/utill/styles.dart';

// ===========================================================================
// KIOSK — TIP THE TEAM
// ===========================================================================
// Shown every time the customer taps Pay, over the order summary. Tips are
// optional: nothing is preselected. Picking a tile (0/5/10/15%) fills it in
// black and turns the footer into "Go to payment"; the customer confirms
// there. Until a tile is picked, the footer is an outlined "No, thank you!"
// that declines the tip immediately.
// ===========================================================================

const Color _kCardBorder = Color(0xFFE6E0CE);
const Color _kSubtitle = TextTones.secondary; // was #8A8275 (3.4:1)
const Color _kInk = Color(0xFF1E1E1E);
const Color _kCream = Color(0xFFFBF8EF);

/// Opens the tip sheet. Resolves to the chosen percent (`0` for no tip),
/// or `null` when the customer dismissed the scrim without continuing.
Future<int?> openKioskTipSheet(
  BuildContext context, {
  required double payableTotal,
}) {
  return showGeneralDialog<int>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Tip the team',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (context, animation, secondaryAnimation) =>
        _KioskTipSheet(payableTotal: payableTotal),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved =
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.04),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _KioskTipSheet extends StatefulWidget {
  final double payableTotal;
  const _KioskTipSheet({required this.payableTotal});

  @override
  State<_KioskTipSheet> createState() => _KioskTipSheetState();
}

class _KioskTipSheetState extends State<_KioskTipSheet> {
  /// `null` is the empty state — no tile highlighted, footer still declines.
  int? _selected;
  bool _closing = false;

  void _choose(int percent) {
    if (_closing) return;
    setState(() => _selected = _selected == percent ? null : percent);
  }

  void _confirm() {
    if (_closing || _selected == null) return;
    _closing = true;
    Navigator.of(context).pop(_selected);
  }

  void _decline() {
    if (_closing) return;
    _closing = true;
    Navigator.of(context).pop(0);
  }

  void _dismiss() {
    if (_closing) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        fit: StackFit.expand,
        children: [
          KioskScrim(
            key: const ValueKey('kiosk-tip-scrim'),
            animation:
                ModalRoute.of(context)?.animation ?? kAlwaysCompleteAnimation,
            onDismiss: _dismiss,
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final m = _TipMetrics.of(context, constraints);
                return Align(
                  // Sits a little above centre, like the Figma frame.
                  alignment: const Alignment(0, -0.3),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: constraints.maxHeight * 0.92,
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Container(
                        width: m.cardWidth,
                        padding: EdgeInsets.all(m.pad),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(m.modalRadius),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.16),
                              blurRadius: m.shadowBlur,
                              offset: Offset(0, m.shadowY),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              kioskTranslate(
                                context,
                                'enjoying_your_visit_tip_the_team',
                                'Enjoying your visit? Tip the team',
                              ),
                              textAlign: TextAlign.center,
                              style: loewExtraBold.copyWith(
                                fontSize: m.titleSize,
                                height: 1.15,
                                color: _kInk,
                              ),
                            ),
                            SizedBox(height: m.titleGap),
                            Text(
                              kioskTranslate(
                                context,
                                'your_tip_goes_directly_to_the_team',
                                'Your tip goes directly to the team',
                              ),
                              textAlign: TextAlign.center,
                              style: loewMedium.copyWith(
                                fontSize: m.subtitleSize,
                                height: 1.25,
                                color: _kSubtitle,
                              ),
                            ),
                            SizedBox(height: m.headerGap),
                            _TipGrid(
                              metrics: m,
                              payableTotal: widget.payableTotal,
                              selected: _selected,
                              onChoose: _choose,
                            ),
                            SizedBox(height: m.buttonGap),
                            _FooterButton(
                              metrics: m,
                              selected: _selected != null,
                              onTap: _selected == null ? _decline : _confirm,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TipGrid extends StatelessWidget {
  final _TipMetrics metrics;
  final double payableTotal;
  final int? selected;
  final ValueChanged<int> onChoose;

  const _TipGrid({
    required this.metrics,
    required this.payableTotal,
    required this.selected,
    required this.onChoose,
  });

  Widget _tile(int percent) {
    return _TipTile(
      percent: percent,
      payableTotal: payableTotal,
      selected: selected == percent,
      size: metrics.tileSize,
      radius: metrics.optionRadius,
      percentSize: metrics.percentSize,
      captionSize: metrics.captionSize,
      onTap: () => onChoose(percent),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (metrics.landscape) {
      return Row(
        children: [
          for (int i = 0; i < kKioskTipPercents.length; i++) ...[
            if (i > 0) SizedBox(width: metrics.gridGap),
            Expanded(child: _tile(kKioskTipPercents[i])),
          ],
        ],
      );
    }
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _tile(kKioskTipPercents[0])),
            SizedBox(width: metrics.gridGap),
            Expanded(child: _tile(kKioskTipPercents[1])),
          ],
        ),
        SizedBox(height: metrics.gridGap),
        Row(
          children: [
            Expanded(child: _tile(kKioskTipPercents[2])),
            SizedBox(width: metrics.gridGap),
            Expanded(child: _tile(kKioskTipPercents[3])),
          ],
        ),
      ],
    );
  }
}

class _TipTile extends StatelessWidget {
  final int percent;
  final double payableTotal;
  final bool selected;
  final double size;
  final double radius;
  final double percentSize;
  final double captionSize;
  final VoidCallback onTap;

  const _TipTile({
    required this.percent,
    required this.payableTotal,
    required this.selected,
    required this.size,
    required this.radius,
    required this.percentSize,
    required this.captionSize,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final String caption = percent == 0
        ? kioskTranslate(context, 'no_tip', 'No tip')
        : PriceConverterHelper.convertPrice(
            kioskTipAmount(payableTotal, percent),
          );
    final Color fg = selected ? _kCream : _kInk;

    return Material(
      color: selected ? _kInk : _kCream,
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: Clip.antiAlias,
      child: KioskTap(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          key: ValueKey('kiosk-tip-$percent'),
          height: size * 0.72,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? _kInk : _kCream,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: selected ? _kInk : const Color(0xFFF1ECDF),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$percent%',
                style: loewExtraBold.copyWith(
                  fontSize: percentSize,
                  height: 1.0,
                  color: fg,
                ),
              ),
              SizedBox(height: (captionSize * 0.35).clamp(6.0, 12.0)),
              Text(
                caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: loewRegular.copyWith(
                  fontSize: captionSize,
                  height: 1.0,
                  color: fg.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FooterButton extends StatelessWidget {
  final _TipMetrics metrics;
  final bool selected;
  final VoidCallback onTap;

  const _FooterButton({
    required this.metrics,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final String label = selected
        ? kioskTranslate(context, 'go_to_payment', 'Go to payment')
        : kioskTranslate(context, 'no_thank_you', 'No, thank you!');

    return Material(
      color: selected ? _kInk : _kCream,
      borderRadius: BorderRadius.circular(metrics.buttonRadius),
      clipBehavior: Clip.antiAlias,
      child: KioskTap(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          key: ValueKey('kiosk-tip-footer-$selected'),
          height: metrics.buttonHeight,
          width: double.infinity,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? _kInk : _kCream,
            borderRadius: BorderRadius.circular(metrics.buttonRadius),
            border: selected
                ? null
                : Border.all(color: _kCardBorder, width: metrics.buttonBorder),
          ),
          child: Text(
            label.toUpperCase(),
            textAlign: TextAlign.center,
            style: loewExtraBold.copyWith(
              fontSize: metrics.buttonSize,
              height: 1.0,
              letterSpacing: 0.6,
              color: selected ? _kCream : _kInk,
            ),
          ),
        ),
      ),
    );
  }
}

/// Layout tokens. Wide POS uses the Figma preview's ~32px padding / 12px
/// tiles; the portrait kiosk scales the 2572px artboard the same way every
/// other checkout modal does.
class _TipMetrics {
  final double cardWidth;
  final double pad;
  final double outerPad;
  final double titleSize;
  final double subtitleSize;
  final double titleGap;
  final double headerGap;
  final double gridGap;
  final double buttonGap;
  final double tileSize;
  final double percentSize;
  final double captionSize;
  final double optionRadius;
  final double modalRadius;
  final double buttonHeight;
  final double buttonRadius;
  final double buttonSize;
  final double buttonBorder;
  final double shadowBlur;
  final double shadowY;
  final bool landscape;

  const _TipMetrics({
    required this.cardWidth,
    required this.pad,
    required this.outerPad,
    required this.titleSize,
    required this.subtitleSize,
    required this.titleGap,
    required this.headerGap,
    required this.gridGap,
    required this.buttonGap,
    required this.tileSize,
    required this.percentSize,
    required this.captionSize,
    required this.optionRadius,
    required this.modalRadius,
    required this.buttonHeight,
    required this.buttonRadius,
    required this.buttonSize,
    required this.buttonBorder,
    required this.shadowBlur,
    required this.shadowY,
    required this.landscape,
  });

  factory _TipMetrics.of(BuildContext context, BoxConstraints constraints) {
    final double s = KioskLayout.scaleOf(context, constraints);
    final bool landscape = KioskLayout.isLandscape(context, constraints);
    final double width = landscape
        ? kioskBounded(
            2100 * s,
            min: math.min(480.0, constraints.maxWidth * 0.88),
            max: constraints.maxWidth * 0.88,
          )
        : kioskBounded(
            1400 * s,
            min: math.min(300.0, constraints.maxWidth * 0.74),
            max: constraints.maxWidth * 0.74,
          );
    final double gap = (16 * s).clamp(6.0, 16.0);
    final double pad = landscape
        ? (56 * s).clamp(20.0, 56.0)
        : (36 * s).clamp(12.0, 36.0);
    final double inner = width - pad * 2;
    final double tile = landscape
        ? ((inner - gap * 3) / 4).clamp(72.0, 280.0)
        : ((inner - gap) / 2).clamp(88.0, 420.0);
    return _TipMetrics(
      cardWidth: width,
      pad: pad,
      outerPad: (24 * s).clamp(12.0, 24.0),
      titleSize: (56 * s).clamp(17.0, 56.0),
      subtitleSize: (28 * s).clamp(11.0, 28.0),
      titleGap: (16 * s).clamp(6.0, 16.0),
      headerGap: landscape ? (28 * s).clamp(12.0, 28.0) : (32 * s).clamp(12.0, 32.0),
      gridGap: gap,
      buttonGap: (20 * s).clamp(8.0, 20.0),
      tileSize: tile,
      percentSize: (76 * s).clamp(20.0, 76.0),
      captionSize: (28 * s).clamp(10.0, 28.0),
      optionRadius: (16 * s).clamp(6.0, 16.0),
      modalRadius: (24 * s).clamp(8.0, 24.0),
      buttonHeight: landscape
          ? (96 * s).clamp(48.0, 96.0)
          : (112 * s).clamp(40.0, 112.0),
      buttonRadius: (12 * s).clamp(6.0, 12.0),
      buttonSize: (30 * s).clamp(11.0, 30.0),
      buttonBorder: (3 * s).clamp(1.0, 3.0),
      shadowBlur: (60 * s).clamp(24.0, 60.0),
      shadowY: (18 * s).clamp(8.0, 18.0),
      landscape: landscape,
    );
  }
}
