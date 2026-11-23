import 'package:flutter/material.dart';

import 'package:acafe_customer/features/kiosk/domain/kiosk_tip.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_translate.dart';
import 'package:acafe_customer/features/kiosk/landscape/landscape_metrics.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_tap.dart';
import 'package:acafe_customer/helper/price_converter_helper.dart';
import 'package:acafe_customer/utill/styles.dart';

// ===========================================================================
// LANDSCAPE KIOSK — "Tip the team" pop-up (Option B).
// Figma TABLET Final Designs (option B), node 2305:9585 "tip-screen - no tip
// selected" (the real content frame sitting beside its "Overlay" sibling
// 2305:9584, same convention as the other landscape pop-ups in this file set).
// 750x757.22 design px, dead-centre of the 1366x1024 canvas. Same return
// contract as portrait's `openKioskTipSheet`: resolves to the chosen percent
// (0 for "no tip"/decline), or null when dismissed without choosing.
// ===========================================================================

const double _kCardWidth = 750;
const double _kCardHeight = 757.218505859375;
const double _kCardPad = 23.099;
const double _kCardRadius = 10.828;
const Color _kCardBg = Color(0xFFFBF8EF);
const Color _kInk = Color(0xFF0D0D0D);
const Color _kSubtitle = Color(0xFF6B7280);
const Color _kTileBorder = Color(0xFFE2D9C8);
const Color _kCream = Color(0xFFF3F3DD);

const double _kTitleFont = 26;
const double _kSubtitleFont = 15.881;
const double _kHeaderGap = 8.662;
const double _kTipGap = 8.662;
const double _kTileRadius = 11.55;
const double _kTilePercentFont = 40;
const double _kTileCaptionFont = 17.324;
const double _kFooterTop = 14.437;
const double _kFooterHeight = 90.953;
const double _kFooterRadius = 10.828;
const double _kFooterFont = 18;

/// Opens the landscape tip pop-up. Same contract as `openKioskTipSheet`:
/// resolves to the chosen percent (`0` for a decline), or `null` when
/// dismissed without choosing.
Future<int?> showLandscapeTipDialog(
  BuildContext context, {
  required double payableTotal,
}) {
  return showGeneralDialog<int>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Tip the team',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (ctx, __, ___) =>
        _LandscapeTipDialog(payableTotal: payableTotal),
    transitionBuilder: (ctx, animation, __, child) => FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
      child: child,
    ),
  );
}

class _LandscapeTipDialog extends StatefulWidget {
  final double payableTotal;
  const _LandscapeTipDialog({required this.payableTotal});

  @override
  State<_LandscapeTipDialog> createState() => _LandscapeTipDialogState();
}

class _LandscapeTipDialogState extends State<_LandscapeTipDialog> {
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

  /// A tap beside the card closes without choosing, like the portrait sheet.
  void _dismiss() {
    if (_closing) return;
    _closing = true;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _dismiss,
      child: _scrim(context),
    );
  }

  Widget _scrim(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.5),
      width: double.infinity,
      height: double.infinity,
      child: LayoutBuilder(
        builder: (context, c) {
          final double s = LandscapeMetrics.scaleFor(c.maxWidth, c.maxHeight);
          final double cardWidth = _kCardWidth * s;
          final double cardHeight = _kCardHeight * s;
          final double left =
              ((c.maxWidth - cardWidth) / 2).clamp(0.0, c.maxWidth);
          final double top =
              ((c.maxHeight - cardHeight) / 2).clamp(0.0, c.maxHeight);

          return Stack(
            children: [
              Positioned(
                left: left,
                top: top,
                child: GestureDetector(
                  onTap: () {}, // swallow — don't close on card taps
                  child: Container(
                    width: cardWidth,
                    height: cardHeight,
                    padding: EdgeInsets.all(_kCardPad * s),
                    decoration: BoxDecoration(
                      color: _kCardBg,
                      borderRadius: BorderRadius.circular(_kCardRadius * s),
                    ),
                    child: Column(
                      children: [
                        // `ExcludeSemantics` keeps this plain decorative copy
                        // out of the web accessibility/DOM shadow tree —
                        // without it, browser extensions that scan page text
                        // (grammar/spell checkers) can paint a stray
                        // underline under these sentences.
                        ExcludeSemantics(
                          child: Text(
                            kioskTranslate(
                                context,
                                'enjoying_your_visit_tip_the_team',
                                'Enjoying your visit? Tip the team'),
                            textAlign: TextAlign.center,
                            style: loewBold.copyWith(
                                fontSize: _kTitleFont * s,
                                height: 1.1,
                                decoration: TextDecoration.none,
                                color: _kInk),
                          ),
                        ),
                        SizedBox(height: _kHeaderGap * s),
                        ExcludeSemantics(
                          child: Text(
                            kioskTranslate(
                                context,
                                'your_tip_goes_directly_to_the_team',
                                'Your tip goes directly to the team'),
                            textAlign: TextAlign.center,
                            style: loewMedium.copyWith(
                                fontSize: _kSubtitleFont * s,
                                height: 1.3,
                                decoration: TextDecoration.none,
                                color: _kSubtitle),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding:
                                EdgeInsets.symmetric(vertical: _kHeaderGap * s),
                            child: _TipGrid(
                              s: s,
                              payableTotal: widget.payableTotal,
                              selected: _selected,
                              onChoose: _choose,
                            ),
                          ),
                        ),
                        SizedBox(height: _kFooterTop * s),
                        _FooterButton(
                          s: s,
                          selected: _selected != null,
                          onTap: _selected == null ? _decline : _confirm,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TipGrid extends StatelessWidget {
  final double s;
  final double payableTotal;
  final int? selected;
  final ValueChanged<int> onChoose;

  const _TipGrid({
    required this.s,
    required this.payableTotal,
    required this.selected,
    required this.onChoose,
  });

  @override
  Widget build(BuildContext context) {
    Widget tile(int percent) => _TipTile(
          s: s,
          percent: percent,
          payableTotal: payableTotal,
          selected: selected == percent,
          onTap: () => onChoose(percent),
        );
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(child: tile(kKioskTipPercents[0])),
              SizedBox(width: _kTipGap * s),
              Expanded(child: tile(kKioskTipPercents[1])),
            ],
          ),
        ),
        SizedBox(height: _kTipGap * s),
        Expanded(
          child: Row(
            children: [
              Expanded(child: tile(kKioskTipPercents[2])),
              SizedBox(width: _kTipGap * s),
              Expanded(child: tile(kKioskTipPercents[3])),
            ],
          ),
        ),
      ],
    );
  }
}

class _TipTile extends StatelessWidget {
  final double s;
  final int percent;
  final double payableTotal;
  final bool selected;
  final VoidCallback onTap;

  const _TipTile({
    required this.s,
    required this.percent,
    required this.payableTotal,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final String caption = percent == 0
        ? kioskTranslate(context, 'no_tip', 'No tip')
        : PriceConverterHelper.convertPrice(
            kioskTipAmount(payableTotal, percent));
    final Color fg = selected ? _kCream : _kInk;

    return Material(
      color: selected ? _kInk : Colors.white,
      borderRadius: BorderRadius.circular(_kTileRadius * s),
      clipBehavior: Clip.antiAlias,
      child: KioskTap(
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? _kInk : Colors.white,
            borderRadius: BorderRadius.circular(_kTileRadius * s),
            border: selected ? null : Border.all(color: _kTileBorder, width: s),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$percent%',
                  style: loewBold.copyWith(
                      fontSize: _kTilePercentFont * s, height: 1.0, color: fg)),
              SizedBox(height: 6 * s),
              Text(
                caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: loewMedium.copyWith(
                    fontSize: _kTileCaptionFont * s,
                    height: 1.2,
                    color: fg.withValues(alpha: 0.85)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FooterButton extends StatelessWidget {
  final double s;
  final bool selected;
  final VoidCallback onTap;
  const _FooterButton(
      {required this.s, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final String label = selected
        ? kioskTranslate(context, 'go_to_payment', 'Go to payment')
        : kioskTranslate(context, 'no_thank_you', 'No, thank you!');
    return Material(
      color: selected ? _kInk : _kCardBg,
      borderRadius: BorderRadius.circular(_kFooterRadius * s),
      clipBehavior: Clip.antiAlias,
      child: KioskTap(
        onTap: onTap,
        child: Container(
          height: _kFooterHeight * s,
          width: double.infinity,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? _kInk : _kCardBg,
            borderRadius: BorderRadius.circular(_kFooterRadius * s),
            border: selected
                ? null
                : Border.all(color: _kInk, width: (0.722 * s).clamp(0.6, 2.0)),
          ),
          child: Text(
            label.toUpperCase(),
            textAlign: TextAlign.center,
            style: loewBold.copyWith(
                fontSize: _kFooterFont * s,
                height: 1.0,
                color: selected ? _kCream : _kInk),
          ),
        ),
      ),
    );
  }
}
