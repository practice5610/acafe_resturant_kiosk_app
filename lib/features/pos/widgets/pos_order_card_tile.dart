import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_order_card.dart';
import 'package:acafe_customer/features/pos/domain/pos_order_grouping.dart';
import 'package:acafe_customer/features/pos/domain/pos_order_timer.dart';
import 'package:acafe_customer/features/pos/domain/pos_orders_spec.dart';
import 'package:acafe_customer/features/pos/widgets/pos_order_source_icon.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// One order on the board (Figma `card-27364` and its variants).
///
/// Two independent indicators, which is easy to conflate from the screenshot:
///
///  * `time-row` — an 8px dot coloured by **section** plus the order's **clock
///    time**. Not a duration.
///  * `timer-section` — the elapsed clock, coloured by urgency. This is the one
///    that goes orange and then red, and it is what puts the 4px `urgent-border`
///    down the card's left edge.
class PosOrderCardTile extends StatelessWidget {
  final PosOrderCard order;

  /// Ticks once a second from the board so the elapsed label advances without
  /// each card owning a timer.
  final DateTime now;

  final bool pending;
  final VoidCallback? onAdvance;

  /// Opens the order detail overlay. Figma has no ⋮ menu on this card — the
  /// whole card is the affordance, so a tap anywhere on it (outside the
  /// action button, which claims its own tap first) opens the detail.
  final VoidCallback? onTap;

  const PosOrderCardTile({
    super.key,
    required this.order,
    required this.now,
    this.pending = false,
    this.onAdvance,
    this.onTap,
  });

  static final DateFormat _clock = DateFormat('HH:mm');

  Color get _sectionColor {
    switch (order.section) {
      case PosOrderSection.newOrders:
        return PosOrdersSpec.dotNew;
      case PosOrderSection.inProgress:
        return PosOrdersSpec.dotInProgress;
      case PosOrderSection.finished:
      case PosOrderSection.excluded:
        return PosOrdersSpec.dotFinished;
    }
  }

  @override
  Widget build(BuildContext context) {
    final PosOrderUrgency urgency = PosOrderTimer.urgencyOf(
      orderStatus: order.orderStatus,
      createdAt: order.createdAt,
      now: now,
    );
    final bool urgent = urgency == PosOrderUrgency.urgent;
    // Card *chrome* follows the section (Figma's muted FINISHED variant);
    // the timer and the action follow the real status.
    final bool finished = order.section == PosOrderSection.finished;

    return Container(
      decoration: BoxDecoration(
        color: finished ? PosOrdersSpec.finishedCardBg : Colors.white,
        borderRadius: BorderRadius.circular(PosOrdersSpec.cardRadius),
        border: Border.all(
          color: urgent ? PosOrderTimer.urgentColor : PosHomeSpec.hairline,
          // FINISHED is the outlined variant: Figma insets its `card-inner` by
          // 1.5px rather than filling it.
          width: finished ? PosOrdersSpec.cardBorder : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        // Transparent so the InkWell's ripple sits over the card colour set
        // above rather than painting its own white beneath it.
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // `urgent-border` — a full-height 4px bar, not a rounded stripe.
                if (urgent)
                  Container(
                    width: PosOrdersSpec.urgentBarWidth,
                    color: PosOrderTimer.urgentColor,
                  ),
                Expanded(child: _body(urgency, finished)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(PosOrderUrgency urgency, bool finished) {
    return Padding(
      padding: const EdgeInsets.all(PosOrdersSpec.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _topRow(),
          const SizedBox(height: PosOrdersSpec.cardBlockGap),
          _customerBlock(),
          const SizedBox(height: PosOrdersSpec.cardBlockGap),
          _timerRow(urgency, finished),
          const SizedBox(height: PosOrdersSpec.cardBlockGap),
          _footer(),
        ],
      ),
    );
  }

  Widget _topRow() {
    final String statusLabel = PosOrderGrouping.labelFor(order.section);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: PosOrdersSpec.statusDotSize,
          height: PosOrdersSpec.statusDotSize,
          decoration: BoxDecoration(color: _sectionColor, shape: BoxShape.circle),
        ),
        const SizedBox(width: PosOrdersSpec.clockGap),
        // The order's clock time — `10:36` in Figma. Blank rather than "--:--"
        // when created_at is unparseable; a fake time on an order card is worse
        // than none.
        Text(
          order.createdAt == null ? '' : _clock.format(order.createdAt!),
          style: loewBold.copyWith(
            fontSize: PosOrdersSpec.clockTextSize,
            color: PosHomeSpec.ink,
          ),
        ),
        // The section dot alone reads as decoration, not status — this spells
        // it out. `excluded` orders never reach the board, so an empty label
        // here is only a defensive no-op, not a real case.
        if (statusLabel.isNotEmpty) ...[
          const SizedBox(width: PosOrdersSpec.statusChipGap),
          _StatusChip(label: statusLabel, color: _sectionColor),
        ],
        const Spacer(),
        // Figma draws only the source badge here — no ⋮ menu on this card.
        PosOrderSourceIcon(channelKey: order.channelKey),
      ],
    );
  }

  Widget _customerBlock() {
    final List<String> lines = order.subtitleLines;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          order.customerName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: loewBold.copyWith(
            fontSize: PosOrdersSpec.nameTextSize,
            color: PosHomeSpec.ink,
          ),
        ),
        // Figma's three-line block is the maximum, not the assumption: the card
        // draws however many lines the order actually has. A counter sale with
        // no address gets two; nothing is padded to hold the shape.
        for (final String line in lines) ...[
          const SizedBox(height: PosOrdersSpec.subtitleLineGap),
          Text(
            line,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: loewRegular.copyWith(
              fontSize: PosOrdersSpec.subtitleTextSize,
              color: PosHomeSpec.inkAlpha(0.55),
            ),
          ),
        ],
      ],
    );
  }

  Widget _timerRow(PosOrderUrgency urgency, bool finished) {
    // "Done" is the end of the ladder, not the FINISHED section: an
    // `item_to_collect` order lives in FINISHED but is still running, and
    // labelling it Done beside a live "Mark as complete" button would
    // contradict itself.
    final String label = urgency == PosOrderUrgency.done
        ? 'Done'
        : PosOrderTimer.elapsedLabel(order.createdAt, now: now);

    return Text(
      label,
      style: loewBold.copyWith(
        fontSize: PosOrdersSpec.timerTextSize,
        color: PosOrderTimer.colorFor(urgency),
      ),
    );
  }

  Widget _footer() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            PosHomeSpec.formatPrice(order.orderAmount),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: loewBold.copyWith(
              fontSize: PosOrdersSpec.priceTextSize,
              color: PosHomeSpec.ink,
            ),
          ),
        ),
        _action(),
      ],
    );
  }

  /// Keyed on the order's real status, never on the section it is drawn in.
  ///
  /// That distinction matters for `item_to_collect`: it is grouped under
  /// FINISHED, but it is not a terminal status, so its card still carries the
  /// action that finishes it. Gating on the section instead would have left
  /// those orders permanently un-completable from the counter.
  Widget _action() {
    if (pending) {
      return const SizedBox(
        width: PosOrdersSpec.checkIconSize,
        height: PosOrdersSpec.checkIconSize,
        child: CircularProgressIndicator(
          strokeWidth: 1.6,
          valueColor: AlwaysStoppedAnimation<Color>(PosHomeSpec.ink),
        ),
      );
    }

    final String? label = PosOrderGrouping.actionLabelFor(order.orderStatus);
    if (label == null) {
      // completed / delivered — the end of the ladder. Figma draws price only.
      return const SizedBox.shrink();
    }

    // NEW keeps Figma's bare checkmark; every later rung needs its label,
    // because "ready" and "complete" are different promises to the customer.
    if (order.section == PosOrderSection.newOrders) {
      return _CheckButton(onTap: onAdvance, tooltip: label);
    }

    return _ActionButton(label: label, onTap: onAdvance);
  }
}

/// Spells out the card's section in words, coloured to match its dot —
/// "NEW" / "IN PROGRESS" / "FINISHED". Not in Figma; the dot alone was not
/// legible enough as a status indicator on the card itself.
class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: PosOrdersSpec.statusChipHeight,
      padding: const EdgeInsets.symmetric(
        horizontal: PosOrdersSpec.statusChipPaddingH,
      ),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(PosOrdersSpec.statusChipRadius),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: loewBold.copyWith(
          fontSize: PosOrdersSpec.statusChipTextSize,
          color: Colors.white,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

/// NEW's checkmark — advances the order to `preparing`.
class _CheckButton extends StatelessWidget {
  final VoidCallback? onTap;
  final String tooltip;

  const _CheckButton({this.onTap, required this.tooltip});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: const Padding(
          padding: EdgeInsets.all(2),
          child: Icon(
            Icons.check_rounded,
            size: PosOrdersSpec.checkIconSize,
            color: PosHomeSpec.ink,
          ),
        ),
      ),
    );
  }
}

/// Figma's `btn-complete`, carrying whatever rung of the ladder this order is
/// actually on — "Mark as ready" for a preparing order, "Mark as complete" for
/// one already waiting to be collected, "Resume" for one on hold.
class _ActionButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _ActionButton({required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: PosHomeSpec.ink,
      borderRadius: BorderRadius.circular(PosOrdersSpec.completeButtonRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(PosOrdersSpec.completeButtonRadius),
        child: Container(
          height: PosOrdersSpec.completeButtonHeight,
          padding: const EdgeInsets.symmetric(
            horizontal: PosOrdersSpec.completeButtonPaddingH,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: loewBold.copyWith(
              fontSize: PosOrdersSpec.completeLabelSize,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
