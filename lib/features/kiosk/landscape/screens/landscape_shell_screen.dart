import 'package:flutter/material.dart';

import 'package:acafe_customer/features/kiosk/landscape/landscape_metrics.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_ui.dart';
import 'package:acafe_customer/theme/brand_colors.dart';

/// Phase-1 placeholder for the landscape (Option B) kiosk.
///
/// It carries no ordering UI yet. Its only job is to confirm, visibly, that the
/// orientation switch fired and that the landscape foundation renders: it draws
/// on the shared [KioskUI] / [BrandColors] tokens and sizes itself through the
/// constraint-based [LandscapeMetrics] scale helper, printing the measured
/// window and the resolved scale so the switch can be checked by eye.
class LandscapeShellScreen extends StatelessWidget {
  const LandscapeShellScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LandscapeScaled(
      child: Builder(
        builder: (context) {
          final LandscapeMetrics m = LandscapeMetrics.of(context);
          final bool isLandscape = m.size.width >= m.size.height;
          return Material(
            color: KioskUI.pageBg,
            child: Center(
              child: isLandscape
                  ? _ShellCard(m: m)
                  : _RotateNotice(m: m),
            ),
          );
        },
      ),
    );
  }
}

class _ShellCard extends StatelessWidget {
  final LandscapeMetrics m;
  const _ShellCard({required this.m});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: m.px(760),
      padding: EdgeInsets.all(m.px(48)),
      decoration: BoxDecoration(
        color: KioskUI.card,
        borderRadius: BorderRadius.circular(m.px(KioskUI.radius)),
        border: Border.all(color: BrandColors.cardBorder, width: m.px(2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _tag(m),
          SizedBox(height: m.px(24)),
          Text(
            'Landscape kiosk — Option B',
            style: TextStyle(
              fontFamily: 'Loew',
              fontWeight: FontWeight.w700,
              fontSize: m.px(44),
              color: KioskUI.dark,
              height: 1.1,
            ),
          ),
          SizedBox(height: m.px(12)),
          Text(
            'Phase 1 foundation. The orientation switch fired and the landscape '
            'shell is rendering. Real Option-B screens arrive in later phases.',
            style: TextStyle(
              fontFamily: 'Loew',
              fontSize: m.px(20),
              color: KioskUI.text,
              height: 1.4,
            ),
          ),
          SizedBox(height: m.px(32)),
          _metric(m, 'Window', '${m.size.width.round()} × ${m.size.height.round()}'),
          SizedBox(height: m.px(12)),
          _metric(m, 'Scale (base 1366 × 1024)', m.scale.toStringAsFixed(3)),
        ],
      ),
    );
  }

  Widget _tag(LandscapeMetrics m) => Container(
        padding: EdgeInsets.symmetric(
            horizontal: m.px(16), vertical: m.px(8)),
        decoration: BoxDecoration(
          color: KioskUI.popularGreen,
          borderRadius: BorderRadius.circular(m.px(999)),
        ),
        child: Text(
          'SWITCH ACTIVE',
          style: TextStyle(
            fontFamily: 'Loew',
            fontWeight: FontWeight.w700,
            fontSize: m.px(16),
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
      );

  Widget _metric(LandscapeMetrics m, String label, String value) => Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'Loew',
                fontSize: m.px(18),
                color: KioskUI.text.withValues(alpha: 0.7),
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Loew',
              fontWeight: FontWeight.w700,
              fontSize: m.px(18),
              color: KioskUI.dark,
            ),
          ),
        ],
      );
}

class _RotateNotice extends StatelessWidget {
  final LandscapeMetrics m;
  const _RotateNotice({required this.m});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(m.px(48)),
      child: Text(
        'Landscape shell — open this in a landscape window (width ≥ height) to '
        'preview the Option-B foundation.',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'Loew',
          fontSize: m.px(22),
          color: KioskUI.text,
          height: 1.4,
        ),
      ),
    );
  }
}
