import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_item_prep_status.dart';
import 'package:acafe_customer/features/pos/domain/pos_order_card.dart';
import 'package:acafe_customer/features/pos/domain/pos_order_detail_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_order_grouping.dart';
import 'package:acafe_customer/features/pos/domain/pos_order_timer.dart';
import 'package:acafe_customer/features/pos/domain/pos_orders_spec.dart';
import 'package:acafe_customer/features/pos/widgets/pos_order_source_icon.dart';
import 'package:acafe_customer/utill/images.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';

/// One order on the board (Figma 1915:15837 `card-27364` and its variants).
///
/// Two independent indicators, which is easy to conflate from the screenshot:
///
///  * `time-row` — an 8px dot coloured by **section** plus the order's **clock
///    time**. Not a duration.
///  * `timer-section` — the elapsed clock, coloured by urgency. This is the one
///    that goes orange and then red, and it is what puts the 4px `urgent-border`
///    down the card's left edge.
///
/// The card face carries no action button — Figma draws none. The forward
/// rung, Hold / Resume and Cancel all live behind its ⋮ ([onMenu]).
class PosOrderCardTile extends StatelessWidget {
  final PosOrderCard order;

  /// Ticks once a second from the board so the elapsed label advances without
  /// each card owning a timer.
  final DateTime now;

  /// A write for this order is in flight: the ⋮ shows a spinner and is inert.
  final bool pending;

  /// Opens the card's ⋮ menu, handed the ⋮ button's own context so the menu
  /// anchors on the button, not the whole card. Null when the order has
  /// nothing left to do; the ⋮ is then drawn dimmed.
  final ValueChanged<BuildContext>? onMenu;

  /// Opens the order detail overlay. A tap anywhere on the card outside the ⋮
  /// (which claims its own tap first) opens the detail.
  final VoidCallback? onTap;

  const PosOrderCardTile({
    super.key,
    required this.order,
    required this.now,
    this.pending = false,
    this.onMenu,
    this.onTap,
  });

  /// The ⋮ of order [orderId], for tests and for anchoring.
  static Key menuKeyFor(int orderId) =>
      ValueKey<String>('pos-order-menu-$orderId');

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
    // FINISHED cards use Figma's ring-less badge and thinner glyphs; the
    // timer and the menu still follow the real status.
    final bool finished = order.section == PosOrderSection.finished;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(PosOrdersSpec.cardRadius),
        // Figma keeps the ink outline on a late card too — lateness is the
        // red bar, dot and clock, not the frame.
        border: Border.all(
          color: PosHomeSpec.ink,
          width: PosOrdersSpec.cardBorder,
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
                    color: PosOrdersSpec.urgentAccent,
                  ),
                Expanded(child: _body(urgency, urgent, finished)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(PosOrderUrgency urgency, bool urgent, bool finished) {
    return Padding(
      padding: const EdgeInsets.all(PosOrdersSpec.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _topRow(urgent, finished),
          const SizedBox(height: PosOrdersSpec.cardBlockGap),
          _customerBlock(),
          const SizedBox(height: PosOrdersSpec.cardBlockGap),
          _timerRow(urgency),
          // Item progress sits between the timer and the price, under the
          // existing subtitle block -- an extra line inside the card, not a
          // change to how the card is sized or laid out.
          if (order.itemStates.isNotEmpty) ...[
            const SizedBox(height: PosOrdersSpec.progressGap),
            _itemProgress(),
          ],
          const SizedBox(height: PosOrdersSpec.cardBlockGap),
          _footer(),
        ],
      ),
    );
  }

  Widget _topRow(bool urgent, bool finished) {
    final Color accent = urgent ? PosOrdersSpec.urgentAccent : PosHomeSpec.ink;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: PosOrdersSpec.statusDotSize,
          height: PosOrdersSpec.statusDotSize,
          decoration: BoxDecoration(
            // A late card swaps in Figma's `urgent-dot`.
            color: urgent ? PosOrdersSpec.urgentAccent : _sectionColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: PosOrdersSpec.clockGap),
        // The order's clock time — `10:36` in Figma. Blank rather than
        // "--:--" when created_at is unparseable; a fake time on an order
        // card is worse than none.
        Text(
          order.createdAt == null ? '' : _clock.format(order.createdAt!),
          style: loewBold.copyWith(
            fontSize: PosOrdersSpec.clockTextSize,
            color: accent,
          ),
        ),
        const Spacer(),
        _MenuButton(
          key: menuKeyFor(order.id),
          pending: pending,
          finished: finished,
          onMenu: onMenu,
        ),
        const SizedBox(width: PosOrdersSpec.menuGap),
        PosOrderSourceIcon(channelKey: order.channelKey, finished: finished),
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
            style: swiss721Light.copyWith(
              fontSize: PosOrdersSpec.subtitleTextSize,
              color: PosHomeSpec.inkAlpha(PosOrdersSpec.subtitleAlpha),
            ),
          ),
        ],
      ],
    );
  }

  Widget _timerRow(PosOrderUrgency urgency) {
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

  /// "2/3 ready" plus one segment per item, coloured by that item's state.
  ///
  /// Segmented rather than a single filled bar because an order is not a
  /// percentage to the person reading it -- it is a small number of things,
  /// each either done or not, and the segments say how many at a glance.
  Widget _itemProgress() {
    final PrepProgress progress = order.progress;

    return Column(
      // Stretch so the bar spans the card rather than shrink-wrapping to the
      // label above it.
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${progress.ready}/${progress.total} ready',
          textAlign: TextAlign.left,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: loewMedium.copyWith(
            fontSize: PosOrdersSpec.progressLabelSize,
            color: progress.allReady
                ? PosOrderDetailSpec.badgeFinished
                : PosHomeSpec.inkAlpha(0.5),
          ),
        ),
        const SizedBox(height: PosOrdersSpec.progressGap),
        SizedBox(
          height: PosOrdersSpec.progressBarHeight,
          child: Row(
            // A childless DecoratedBox collapses under the Row's default
            // centre alignment; stretch gives each segment the full 4px.
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (int i = 0; i < order.itemStates.length; i++) ...[
                if (i > 0)
                  const SizedBox(width: PosOrdersSpec.progressSegmentGap),
                Expanded(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: order.itemStates[i] == PrepStatus.pending
                          ? PosOrdersSpec.progressTrack
                          : order.itemStates[i].color,
                      borderRadius: BorderRadius.circular(
                        PosOrdersSpec.progressBarRadius,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
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
            style: loewExtraBold.copyWith(
              fontSize: PosOrdersSpec.priceTextSize,
              color: PosHomeSpec.ink,
            ),
          ),
        ),
      ],
    );
  }
}

/// `card-actions` — the card's ⋮.
///
/// Its own [Builder], so the tap hands [PosOrderCardTile.onMenu] the button's
/// context: the menu then opens snug under the ⋮ rather than under the card.
class _MenuButton extends StatelessWidget {
  final bool pending;
  final bool finished;
  final ValueChanged<BuildContext>? onMenu;

  const _MenuButton({
    super.key,
    required this.pending,
    required this.finished,
    required this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    if (pending) {
      return const SizedBox(
        width: PosOrdersSpec.menuHitSize,
        height: PosOrdersSpec.menuHitSize,
        child: Center(
          child: SizedBox(
            width: PosOrdersSpec.pendingSpinnerSize,
            height: PosOrdersSpec.pendingSpinnerSize,
            child: CircularProgressIndicator(
              strokeWidth: 1.6,
              valueColor: AlwaysStoppedAnimation<Color>(PosHomeSpec.ink),
            ),
          ),
        ),
      );
    }

    final ValueChanged<BuildContext>? open = onMenu;

    return Tooltip(
      message: 'Order actions',
      child: Opacity(
        opacity: open == null ? PosOrdersSpec.menuDisabledOpacity : 1,
        child: Builder(
          // A dimmed ⋮ still claims its tap, with no ripple: tapping a dead
          // control must not fall through and open the order underneath.
          builder: (buttonContext) => InkWell(
            onTap: open == null ? () {} : () => open(buttonContext),
            splashFactory: open == null ? NoSplash.splashFactory : null,
            highlightColor: open == null ? Colors.transparent : null,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: PosOrdersSpec.menuHitSize,
              height: PosOrdersSpec.menuHitSize,
              child: Center(
                child: SvgPicture.asset(
                  finished
                      ? Images.posOrdersMoreVertFinishedSvg
                      : Images.posOrdersMoreVertSvg,
                  width: PosOrdersSpec.menuIconSize,
                  height: PosOrdersSpec.menuIconSize,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
