import 'package:acafe_customer/features/pos/domain/pos_responsive.dart';
import 'package:acafe_customer/features/pos/widgets/pos_ui.dart';
import 'package:flutter/material.dart';

/// Scaffolding marker for a POS screen whose layout is not built yet.
///
/// Deliberately plain and clearly unfinished: these are routed so navigation,
/// the guard and the shell chrome can be verified end to end before any visual
/// work starts, and they are replaced wholesale once the Figma frames land.
class PosPlaceholder extends StatelessWidget {
  final String title;
  final String route;
  final String? note;

  const PosPlaceholder({
    super.key,
    required this.title,
    required this.route,
    this.note,
  });

  @override
  Widget build(BuildContext context) {
    final double s = PosMetrics.maybeOf(context)?.scale ?? 1.0;
    return Center(
      child: PosSurface(
        padding: EdgeInsets.all(PosUI.gutter * s),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title,
                style: PosUI.text(context,
                    size: PosUI.titleSize, weight: FontWeight.w700)),
            SizedBox(height: 8 * s),
            Text(route,
                style: PosUI.text(context,
                    size: PosUI.captionSize, color: PosUI.inkMuted)),
            if (note != null) ...[
              SizedBox(height: 12 * s),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 420 * s),
                child: Text(
                  note!,
                  textAlign: TextAlign.center,
                  style: PosUI.text(context,
                      size: PosUI.captionSize, color: PosUI.inkMuted),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
