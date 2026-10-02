import 'package:acafe_customer/features/pos/domain/pos_item_prep_status.dart';
import 'package:acafe_customer/features/pos/domain/pos_order_detail_spec.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter/material.dart';

/// The per-item status chrome for the Orders detail overlay: the status pill,
/// the one contextual action, the section progress bar and the on-hold banner.
///
/// Kept out of `pos_order_detail_overlay.dart` because all four are pure
/// presentation driven by a [PrepStatus] — the overlay owns the writes, these
/// own how a state looks.
///
/// Everything here reads its metrics from [PosOrderDetailSpec]; there are no
/// inline numbers, so a Figma change is a token change.

/// Read-only status pill: a dot plus the label, tinted with the status colour.
///
/// The kitchen's equivalent is `_PrepStatusChip` (order_ticket_card.dart:
/// 1028-1058). Same idea and same wording; POS palette and POS type.
class PosItemStatusChip extends StatelessWidget {
  final PrepStatus status;

  const PosItemStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final Color color = status.color;

    return AnimatedContainer(
      duration: PosOrderDetailSpec.itemStateAnimation,
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(
        horizontal: PosOrderDetailSpec.itemChipPadH,
        vertical: PosOrderDetailSpec.itemChipPadV,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: PosOrderDetailSpec.itemChipFillOpacity),
        borderRadius:
            BorderRadius.circular(PosOrderDetailSpec.itemChipRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: PosOrderDetailSpec.itemChipDot,
            height: PosOrderDetailSpec.itemChipDot,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: PosOrderDetailSpec.itemChipDotGap),
          Text(
            status.label,
            style: loewBold.copyWith(
              fontSize: PosOrderDetailSpec.itemChipTextSize,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// The single contextual action on an item row — Start, Done or Undo.
///
/// Start and Done are outlined in the colour of the state they move *to*, so
/// the button previews its own result. Undo is deliberately quiet: it is a
/// correction, and it should not compete with the forward action sitting on the
/// rows above and below it.
class PosItemActionButton extends StatelessWidget {
  final PrepAction action;

  /// True while this item's write is in flight. The label is replaced by a
  /// spinner and taps are dropped, which is what stops a double submit.
  final bool busy;

  /// False when the order is on hold or another of its items is mid-write.
  final bool enabled;

  final VoidCallback onTap;

  const PosItemActionButton({
    super.key,
    required this.action,
    required this.busy,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool live = enabled && !busy;
    final Color accent = action.subtle
        ? PosOrderDetailSpec.inkAlpha(0.55)
        : action.target.color;

    final Widget label = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (busy)
          SizedBox(
            width: PosOrderDetailSpec.itemActionSpinner,
            height: PosOrderDetailSpec.itemActionSpinner,
            child: CircularProgressIndicator(
              strokeWidth: PosOrderDetailSpec.itemActionSpinnerStroke,
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
          )
        else
          Icon(
            action.icon,
            size: PosOrderDetailSpec.itemActionIconSize,
            color: accent,
          ),
        const SizedBox(width: PosOrderDetailSpec.itemActionGap),
        Text(
          action.label,
          style: loewBold.copyWith(
            fontSize: PosOrderDetailSpec.itemActionTextSize,
            color: accent,
          ),
        ),
      ],
    );

    return Opacity(
      opacity: enabled ? 1 : PosOrderDetailSpec.itemActionDisabledOpacity,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: live ? onTap : null,
          borderRadius:
              BorderRadius.circular(PosOrderDetailSpec.itemActionRadius),
          child: AnimatedContainer(
            duration: PosOrderDetailSpec.itemStateAnimation,
            curve: Curves.easeOut,
            height: PosOrderDetailSpec.itemActionHeight,
            constraints: const BoxConstraints(
              minWidth: PosOrderDetailSpec.itemActionMinWidth,
            ),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(
              horizontal: PosOrderDetailSpec.itemActionPadH,
            ),
            decoration: BoxDecoration(
              borderRadius:
                  BorderRadius.circular(PosOrderDetailSpec.itemActionRadius),
              // Undo has no outline — it reads as a text button.
              border: action.subtle
                  ? null
                  : Border.all(
                      color: accent,
                      width: PosOrderDetailSpec.itemActionBorder,
                    ),
            ),
            child: label,
          ),
        ),
      ),
    );
  }
}

/// "2 of 3 ready" plus the bar under the Order Items header.
///
/// The counts come from the server so they always agree with the order status
/// drawn beside them; see [PrepProgress].
class PosItemProgressBar extends StatelessWidget {
  final PrepProgress progress;

  const PosItemProgressBar({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    if (progress.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: PosOrderDetailSpec.progressGap),
        ClipRRect(
          borderRadius:
              BorderRadius.circular(PosOrderDetailSpec.progressBarRadius),
          child: SizedBox(
            height: PosOrderDetailSpec.progressBarHeight,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: [
                    const ColoredBox(
                      color: PosOrderDetailSpec.hairline,
                      child: SizedBox.expand(),
                    ),
                    AnimatedContainer(
                      duration: PosOrderDetailSpec.itemStateAnimation,
                      curve: Curves.easeOut,
                      width: constraints.maxWidth * progress.fraction,
                      color: PosOrderDetailSpec.badgeFinished,
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// The "n of m ready" label that sits at the right of the section header.
class PosItemProgressLabel extends StatelessWidget {
  final PrepProgress progress;

  const PosItemProgressLabel({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    if (progress.isEmpty) return const SizedBox.shrink();

    return Text(
      progress.label,
      style: loewMedium.copyWith(
        fontSize: PosOrderDetailSpec.progressLabelSize,
        color: progress.allReady
            ? PosOrderDetailSpec.badgeFinished
            : PosOrderDetailSpec.inkAlpha(0.55),
      ),
    );
  }
}

/// Slim banner above the item list while the order is paused.
///
/// Item actions are disabled underneath it — which the server enforces anyway
/// with a 409 `order_locked`, so this is the explanation rather than the rule.
class PosOnHoldBanner extends StatelessWidget {
  const PosOnHoldBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: PosOrderDetailSpec.progressGap),
      padding: const EdgeInsets.symmetric(
        horizontal: PosOrderDetailSpec.holdBannerPadH,
        vertical: PosOrderDetailSpec.holdBannerPadV,
      ),
      decoration: BoxDecoration(
        color: PosOrderDetailSpec.holdTone
            .withValues(alpha: PosOrderDetailSpec.holdBannerFillOpacity),
        borderRadius:
            BorderRadius.circular(PosOrderDetailSpec.holdBannerRadius),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.pause_circle_outlined,
            size: PosOrderDetailSpec.holdBannerIconSize,
            color: PosOrderDetailSpec.holdTone,
          ),
          const SizedBox(width: PosOrderDetailSpec.holdBannerGap),
          Expanded(
            child: Text(
              'Order on hold — items locked',
              style: loewMedium.copyWith(
                fontSize: PosOrderDetailSpec.holdBannerTextSize,
                color: PosOrderDetailSpec.holdTone,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
