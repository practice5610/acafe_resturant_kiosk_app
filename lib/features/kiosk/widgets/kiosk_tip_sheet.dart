import 'package:flutter/material.dart';
import 'package:acafe_customer/common/responsive/kiosk_responsive.dart';
import 'package:acafe_customer/common/responsive/responsive.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_tip.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_translate.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_scrim.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_tap.dart';
import 'package:acafe_customer/helper/price_converter_helper.dart';
import 'package:acafe_customer/utill/styles.dart';

// ===========================================================================
// KIOSK — TIP THE TEAM
// ===========================================================================
// Shown every time the customer taps Pay, over the order summary. Tips are
// optional: nothing is preselected, and "No, thank you!" continues with €0.
// Picking 5 / 10 / 15% locks that tip in and returns immediately so Pay can
// continue to upsells without showing this sheet again.
// ===========================================================================

const Color _kCardBorder = Color(0xFFE6E0CE);
const Color _kSubtitle = Color(0xFF8A8275);
const Color _kInk = Color(0xFF1E1E1E);

/// Brief pause after a tile is tapped so the selected border is visible
/// before the sheet dismisses. Long enough to read, short enough to not stall.
const Duration _kSelectHold = Duration(milliseconds: 280);

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
  /// `null` is the empty state — no tile highlighted, no tip applied.
  int? _selected;
  bool _closing = false;

  Future<void> _choose(int percent) async {
    if (_closing) return;
    setState(() => _selected = percent);
    _closing = true;
    await Future<void>.delayed(_kSelectHold);
    if (!mounted) return;
    Navigator.of(context).pop(percent);
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
                  alignment: Alignment.center,
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
                            _DeclineButton(
                              metrics: m,
                              onTap: _decline,
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

  @override
  Widget build(BuildContext context) {
    final double tile = metrics.tileSize;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _TipTile(
                percent: kKioskTipPercents[0],
                payableTotal: payableTotal,
                selected: selected == kKioskTipPercents[0],
                size: tile,
                radius: metrics.optionRadius,
                percentSize: metrics.percentSize,
                captionSize: metrics.captionSize,
                onTap: () => onChoose(kKioskTipPercents[0]),
              ),
            ),
            SizedBox(width: metrics.gridGap),
            Expanded(
              child: _TipTile(
                percent: kKioskTipPercents[1],
                payableTotal: payableTotal,
                selected: selected == kKioskTipPercents[1],
                size: tile,
                radius: metrics.optionRadius,
                percentSize: metrics.percentSize,
                captionSize: metrics.captionSize,
                onTap: () => onChoose(kKioskTipPercents[1]),
              ),
            ),
          ],
        ),
        SizedBox(height: metrics.gridGap),
        Row(
          children: [
            Expanded(
              child: _TipTile(
                percent: kKioskTipPercents[2],
                payableTotal: payableTotal,
                selected: selected == kKioskTipPercents[2],
                size: tile,
                radius: metrics.optionRadius,
                percentSize: metrics.percentSize,
                captionSize: metrics.captionSize,
                onTap: () => onChoose(kKioskTipPercents[2]),
              ),
            ),
            SizedBox(width: metrics.gridGap),
            Expanded(
              child: _TipTile(
                percent: kKioskTipPercents[3],
                payableTotal: payableTotal,
                selected: selected == kKioskTipPercents[3],
                size: tile,
                radius: metrics.optionRadius,
                percentSize: metrics.percentSize,
                captionSize: metrics.captionSize,
                onTap: () => onChoose(kKioskTipPercents[3]),
              ),
            ),
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
    final double borderWidth = selected ? (size * 0.018).clamp(2.5, 4.0) : 1.5;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: Clip.antiAlias,
      child: KioskTap(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          key: ValueKey('kiosk-tip-$percent'),
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: selected ? _kInk : _kCardBorder,
              width: borderWidth,
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
                  color: _kInk,
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
                  color: _kInk,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeclineButton extends StatelessWidget {
  final _TipMetrics metrics;
  final VoidCallback onTap;

  const _DeclineButton({required this.metrics, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(metrics.buttonRadius),
      clipBehavior: Clip.antiAlias,
      child: KioskTap(
        onTap: onTap,
        child: Container(
          key: const ValueKey('kiosk-tip-decline'),
          height: metrics.buttonHeight,
          width: double.infinity,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(metrics.buttonRadius),
            border: Border.all(color: _kInk, width: metrics.buttonBorder),
          ),
          child: Text(
            kioskTranslate(context, 'no_thank_you', 'No, thank you!')
                .toUpperCase(),
            textAlign: TextAlign.center,
            style: loewExtraBold.copyWith(
              fontSize: metrics.buttonSize,
              height: 1.0,
              letterSpacing: 0.6,
              color: _kInk,
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
  });

  factory _TipMetrics.of(BuildContext context, BoxConstraints constraints) {
    if (Responsive.isWide(context)) {
      final double width = constraints.maxWidth.clamp(0, 480);
      final double gap = 12;
      final double inner = width - 64;
      final double tile = ((inner - gap) / 2).clamp(96.0, 196.0);
      return _TipMetrics(
        cardWidth: width,
        pad: 32,
        outerPad: 24,
        titleSize: 22,
        subtitleSize: 14,
        titleGap: 8,
        headerGap: 24,
        gridGap: gap,
        buttonGap: 20,
        tileSize: tile,
        percentSize: 32,
        captionSize: 14,
        optionRadius: 12,
        modalRadius: 20,
        buttonHeight: 56,
        buttonRadius: 16,
        buttonSize: 15,
        buttonBorder: 1.5,
        shadowBlur: 32,
        shadowY: 12,
      );
    }

    final double s = KioskResponsive.scale(constraints.maxWidth);
    final double width =
        (1640 * s).clamp(320.0, constraints.maxWidth * 0.86);
    final double gap = (32 * s).clamp(10.0, 32.0);
    final double pad = (88 * s).clamp(24.0, 88.0);
    final double inner = width - pad * 2;
    final double tile = ((inner - gap) / 2).clamp(88.0, 420.0);
    return _TipMetrics(
      cardWidth: width,
      pad: pad,
      outerPad: (24 * s).clamp(12.0, 24.0),
      titleSize: (72 * s).clamp(20.0, 72.0),
      subtitleSize: (36 * s).clamp(13.0, 36.0),
      titleGap: (16 * s).clamp(6.0, 16.0),
      headerGap: (48 * s).clamp(16.0, 48.0),
      gridGap: gap,
      buttonGap: (40 * s).clamp(14.0, 40.0),
      tileSize: tile,
      percentSize: (96 * s).clamp(22.0, 96.0),
      captionSize: (40 * s).clamp(12.0, 40.0),
      optionRadius: (28 * s).clamp(10.0, 28.0),
      modalRadius: (48 * s).clamp(16.0, 48.0),
      buttonHeight: (140 * s).clamp(52.0, 140.0),
      buttonRadius: (28 * s).clamp(12.0, 28.0),
      buttonSize: (44 * s).clamp(14.0, 44.0),
      buttonBorder: (4 * s).clamp(1.5, 4.0),
      shadowBlur: (60 * s).clamp(24.0, 60.0),
      shadowY: (18 * s).clamp(8.0, 18.0),
    );
  }
}
