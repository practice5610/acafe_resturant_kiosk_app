import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_punch_source.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter/material.dart';

/// The visual building blocks of a punch flow, shared by every surface that
/// offers Punch In / Out.
///
/// Kept here, free of any navigation or data wiring, so the two places that
/// punch — the full-screen [PosPunchScreen] reached from the POS sidebar, and
/// the inline flow on the staff lock screen — draw the same tiles and the same
/// result banner rather than two look-alikes that drift apart.

/// One of the two big punch actions.
class PosPunchActionTile extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;

  /// The primary action (Punch In) is filled; the secondary (Punch Out) is
  /// outlined — a clear visual separation without leaving the brand palette.
  final bool filled;
  final VoidCallback onTap;

  const PosPunchActionTile({
    super.key,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color bg = filled ? PosHomeSpec.ink : PosHomeSpec.tileBg;
    final Color fg = filled ? Colors.white : PosHomeSpec.ink;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 240,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: PosHomeSpec.ink.withValues(alpha: filled ? 1 : 0.18),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: filled
                      ? Colors.white.withValues(alpha: 0.12)
                      : PosHomeSpec.ink.withValues(alpha: 0.06),
                ),
                child: Icon(icon, size: 30, color: fg),
              ),
              const SizedBox(height: 18),
              Text(
                label,
                style: loewBold.copyWith(fontSize: 22, color: fg),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: loewRegular.copyWith(
                  fontSize: 13,
                  color: fg.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The success / error confirmation after a punch.
class PosPunchResultBanner extends StatelessWidget {
  final PosPunchResult result;

  const PosPunchResultBanner({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    // Only an actual punch is a success. A skip (not linked / not set up) or a
    // failure is "not recorded" -- never shown as a green confirmation, so the
    // operator is never told they clocked in when they did not.
    final bool ok = result.recorded;
    final Color accent = ok
        ? const Color(0xFF2E7D32)
        : (result.isError ? const Color(0xFFB3261E) : const Color(0xFFB26A00));
    final String heading = ok
        ? (result.staffName != null && result.staffName!.isNotEmpty
            ? result.staffName!
            : (result.direction == 'out' ? 'Punched out' : 'Punched in'))
        : 'Not recorded';

    return Container(
      key: const Key('pos-punch-result'),
      constraints: const BoxConstraints(maxWidth: 520),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Row(
        children: [
          Icon(
            ok ? Icons.check_circle_rounded : Icons.error_outline_rounded,
            color: accent,
            size: 28,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  heading,
                  style: loewBold.copyWith(fontSize: 16, color: accent),
                ),
                if (result.message.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    result.message,
                    style: loewRegular.copyWith(
                      fontSize: 14,
                      color: PosHomeSpec.ink.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
