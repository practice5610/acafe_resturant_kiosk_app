import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_item_prep_status.dart';
import 'package:acafe_customer/features/pos/domain/pos_order_card.dart';
import 'package:acafe_customer/features/pos/domain/pos_order_detail_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_order_grouping.dart';
import 'package:acafe_customer/features/pos/domain/pos_order_timer.dart';
import 'package:acafe_customer/features/pos/domain/pos_orders_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_station_status.dart';
import 'package:acafe_customer/features/pos/widgets/pos_item_status_widgets.dart';
import 'package:acafe_customer/features/pos/widgets/pos_order_more_menu.dart';
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

  /// The ⋮ menu's forward rung ("Accept order", "Mark as ready", …), if any.
  final String? menuAdvanceLabel;

  /// Whether the ⋮ menu offers Hold / Resume and Cancel.
  final bool menuSideExits;

  /// Runs the row picked in the card's ⋮ menu. Null when the order has
  /// nothing left to do; the ⋮ is then drawn dimmed.
  final ValueChanged<PosOrderMenuAction>? onMenuAction;

  /// Opens the order detail overlay. A tap anywhere on the card outside the ⋮
  /// (which claims its own tap first) opens the detail.
  final VoidCallback? onTap;

  const PosOrderCardTile({
    super.key,
    required this.order,
    required this.now,
    this.pending = false,
    this.menuAdvanceLabel,
    this.menuSideExits = false,
    this.onMenuAction,
    this.onTap,
  });

  /// The ⋮ of order [orderId], for tests and for anchoring.
  static Key menuKeyFor(int orderId) =>
      ValueKey<String>('pos-order-menu-$orderId');

  /// The order-number headline of order [orderId], for tests.
  static Key numberKeyFor(int orderId) =>
      ValueKey<String>('pos-order-number-$orderId');

  /// The amber note strip of order [orderId], for tests.
  static Key notePreviewKeyFor(int orderId) =>
      ValueKey<String>('pos-order-note-preview-$orderId');

  static final DateFormat _clock = DateFormat('HH:mm');

  Color get _sectionColor {
    switch (order.section) {
      case PosOrderSection.newOrders:
        return PosOrdersSpec.dotNew;
      case PosOrderSection.preparing:
        return PosOrdersSpec.dotPreparing;
      case PosOrderSection.readyToCollect:
        return PosOrdersSpec.dotReadyToCollect;
      case PosOrderSection.onHold:
        return PosOrdersSpec.dotOnHold;
      case PosOrderSection.completed:
      case PosOrderSection.excluded:
        return PosOrdersSpec.dotCompleted;
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
    // READY TO COLLECT and COMPLETED cards use Figma's FINISHED variant:
    // ring-less badge and thinner glyphs. The timer and the menu still follow
    // the real status.
    final bool finished = PosOrderGrouping.usesFinishedCard(order.section);

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: PosOrdersSpec.cardMinHeight),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(PosOrdersSpec.cardRadius),
        ),
        // Figma's stroke sits inside the card and moves nothing — a decoration
        // border would push every child in by 1.5px. It also keeps the ink
        // outline on a late card: lateness is the red bar, dot and clock.
        foregroundDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(PosOrdersSpec.cardRadius),
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
                  // `urgent-border` — a full-height 4px bar, not a rounded
                  // stripe.
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
      ),
    );
  }

  /// Station pills are an IN PROGRESS thing in Figma: NEW cards would only
  /// ever say "Pending", finished ones "Ready", and Figma draws neither.
  /// PREPARING and ON HOLD orders are the ones still in the kitchen.
  bool get _inProgress => PosOrderGrouping.usesInProgressCard(order.section);

  bool get _showStations => _inProgress && order.stations.isNotEmpty;

  /// An in-progress order whose lines have no station keeps its "n/m ready"
  /// line, so the counter still sees how far it has got.
  bool get _showProgress =>
      _inProgress && order.stations.isEmpty && order.itemStates.isNotEmpty;

  Widget _body(PosOrderUrgency urgency, bool urgent, bool finished) {
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.all(PosOrdersSpec.cardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _topRow(urgent),
              const SizedBox(height: PosOrdersSpec.cardBlockGap),
              // An unparseable id comes through as 0; a made-up "#0" would
              // send someone looking for an order that does not exist.
              if (order.id > 0) ...[
                _orderNumber(),
                const SizedBox(height: PosOrdersSpec.orderNumberGap),
              ],
              _customerBlock(),
              const SizedBox(height: PosOrdersSpec.cardBlockGap),
              // `note-slot`: every card keeps room for a two-line note, note
              // or not, so a card with no note, a one-line note and a
              // two-line note are one size. The strip itself stays as tall as
              // its text.
              ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: PosOrdersSpec.notePreviewSlotHeight,
                ),
                child: order.hasNotes
                    ? Align(
                        alignment: Alignment.topLeft,
                        child: _NotePreview(
                          key: notePreviewKeyFor(order.id),
                          notes: order.notes,
                        ),
                      )
                    : null,
              ),
              // The timer and the footer sit on the card's bottom edge in
              // every section, as on Figma's IN PROGRESS card (1915:15986):
              // [PosOrderCardGrid] gives a row one height, and pinning keeps
              // the prices on one line across it.
              const Spacer(),
              const SizedBox(height: PosOrdersSpec.cardBlockGap),
              _timerRow(urgency),
              if (_showProgress) ...[
                const SizedBox(height: PosOrdersSpec.progressGap),
                _itemProgress(),
              ],
              const SizedBox(height: PosOrdersSpec.cardBlockGap),
              _footer(),
            ],
          ),
        ),
        // `source-badge` is pinned to the card's top-right corner, 12 in,
        // outside the 16px `card-top` row — so it never makes that row taller.
        Positioned(
          top: PosOrdersSpec.cardPadding,
          right: PosOrdersSpec.cardPadding,
          child: PosOrderSourceIcon(
            channelKey: order.channelKey,
            finished: finished,
          ),
        ),
        // `card-actions`: Figma's ⋮ sits on `card-top`'s row under the badge,
        // where it can be neither seen nor tapped, so it moves just left of
        // the badge, centred on that row, in a 24px hit box.
        Positioned(
          top: PosOrdersSpec.cardPadding +
              (PosOrdersSpec.cardTopHeight - PosOrdersSpec.menuHitSize) / 2,
          right: PosOrdersSpec.cardPadding +
              PosOrdersSpec.sourceBadgeSize +
              PosOrdersSpec.menuGap,
          child: _MenuButton(
            key: menuKeyFor(order.id),
            pending: pending,
            finished: finished,
            isHeld: order.orderStatus == 'on_hold',
            advanceLabel: menuAdvanceLabel,
            sideExits: menuSideExits,
            onMenuAction: onMenuAction,
          ),
        ),
      ],
    );
  }

  /// `card-top`: the dot and the clock, 16 tall.
  Widget _topRow(bool urgent) {
    final Color accent = urgent ? PosOrdersSpec.urgentAccent : PosHomeSpec.ink;

    return SizedBox(
      height: PosOrdersSpec.cardTopHeight,
      child: Row(
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
        ],
      ),
    );
  }

  /// `order-number`: `#100014`, in the customer name's own style. Ink on a
  /// late card too — lateness is the red bar, dot and clock, and a red number
  /// would read as an error on the order itself.
  Widget _orderNumber() {
    final String label = order.numberLabel;
    final bool hashed = label.startsWith('#');

    return Text.rich(
      key: numberKeyFor(order.id),
      TextSpan(
        children: [
          if (hashed)
            TextSpan(
              text: '#',
              style: TextStyle(
                color: PosHomeSpec.inkAlpha(PosOrdersSpec.orderNumberHashAlpha),
              ),
            ),
          TextSpan(text: hashed ? label.substring(1) : label),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      semanticsLabel: 'Order ${order.id}',
      // Proportional digits: Loew's tabular `1` leaves a hole (`#2736 1`).
      style: loewBold.copyWith(
        fontSize: PosOrdersSpec.orderNumberTextSize,
        color: PosHomeSpec.ink,
      ),
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
        // no address gets two; nothing is padded here — [PosOrderCardGrid]
        // evens the section's cards out instead.
        for (final String line in lines) ...[
          const SizedBox(height: PosOrdersSpec.subtitleLineGap),
          Text(
            line,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: swiss721Light.copyWith(
              fontSize: PosOrdersSpec.subtitleTextSize,
              height: PosOrdersSpec.swissLeading(PosOrdersSpec.subtitleTextSize),
              color: PosHomeSpec.inkAlpha(PosOrdersSpec.subtitleAlpha),
            ),
          ),
        ],
      ],
    );
  }

  Widget _timerRow(PosOrderUrgency urgency) {
    // "Done" is the end of the ladder, not a finished-looking card: an
    // `item_to_collect` order is drawn as finished but is still running, and
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

  /// `card-footer`: the price, and the station pills to its right
  /// (1915:15994 `station-status`). Pills wrap rather than overflow when an
  /// order spans more stations than one line holds.
  Widget _footer() {
    final Widget price = Text(
      PosHomeSpec.formatPrice(order.orderAmount),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: loewExtraBold.copyWith(
        fontSize: PosOrdersSpec.priceTextSize,
        color: PosHomeSpec.ink,
      ),
    );

    if (!_showStations) {
      return Row(children: [Expanded(child: price)]);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        price,
        const SizedBox(width: PosOrdersSpec.stationPillGap * 2),
        Expanded(
          child: Wrap(
            alignment: WrapAlignment.end,
            spacing: PosOrdersSpec.stationPillGap,
            runSpacing: PosOrdersSpec.stationPillGap,
            children: [
              for (final PosStationStatus station in order.stations)
                PosStationPill(
                  station: station,
                  size: PosStationPillSize.card,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// `note-preview` — the amber strip that says "this order has notes".
///
/// Previews the first note (the order's own, else the first line's, prefixed
/// with that line's name) and counts the rest, so a note is seen on the board
/// before anyone opens the order. The full text is in the detail overlay.
class _NotePreview extends StatelessWidget {
  final List<PosOrderCardNote> notes;

  const _NotePreview({super.key, required this.notes});

  @override
  Widget build(BuildContext context) {
    final PosOrderCardNote first = notes.first;
    final String? item = first.itemLabel;
    // A typed line break is a sentence break on two preview lines, not a
    // wasted second line.
    final String text = first.text.replaceAll(RegExp(r'\s*[\r\n]+\s*'), ' ');
    final int more = notes.length - 1;

    const double height =
        PosOrdersSpec.notePreviewLineHeight / PosOrdersSpec.notePreviewTextSize;
    final TextStyle base = loewMedium.copyWith(
      fontSize: PosOrdersSpec.notePreviewTextSize,
      height: height,
      color: PosHomeSpec.ink,
    );
    // The line name and the count, in the label amber. Sized here too: the
    // Loew styles carry a size of their own that would outgrow the text.
    final TextStyle strong = loewBold.copyWith(
      fontSize: PosOrdersSpec.notePreviewTextSize,
      height: height,
      color: PosOrderDetailSpec.itemNoteLabelInk,
    );

    return Semantics(
      label: notes.length == 1 ? 'Order note' : '${notes.length} order notes',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: PosOrdersSpec.notePreviewPadH,
          vertical: PosOrdersSpec.notePreviewPadV,
        ),
        decoration: BoxDecoration(
          color: PosOrderDetailSpec.noteBg,
          borderRadius: BorderRadius.circular(PosOrdersSpec.notePreviewRadius),
        ),
        foregroundDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(PosOrdersSpec.notePreviewRadius),
          border: Border.all(color: PosOrderDetailSpec.noteBorder),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              // Centre the icon on the first line, not on the whole strip.
              padding: EdgeInsets.only(
                top: (PosOrdersSpec.notePreviewLineHeight -
                        PosOrdersSpec.notePreviewIconSize) /
                    2,
              ),
              child: Icon(
                Icons.sticky_note_2_outlined,
                size: PosOrdersSpec.notePreviewIconSize,
                color: PosOrderDetailSpec.itemNoteLabelInk,
              ),
            ),
            const SizedBox(width: PosOrdersSpec.notePreviewIconGap),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    if (item != null) TextSpan(text: '$item: ', style: strong),
                    TextSpan(text: text),
                  ],
                ),
                style: base,
                maxLines: PosOrdersSpec.notePreviewMaxLines,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (more > 0) ...[
              const SizedBox(width: PosOrdersSpec.notePreviewCountGap),
              Text('+$more', style: strong),
            ],
          ],
        ),
      ),
    );
  }
}

/// `card-actions` — the card's ⋮.
///
/// The menu hangs off the ⋮ itself ([PosOrderMoreMenu], root overlay), so it
/// opens snug under the button wherever the board is mounted.
class _MenuButton extends StatelessWidget {
  final bool pending;
  final bool finished;
  final bool isHeld;
  final String? advanceLabel;
  final bool sideExits;
  final ValueChanged<PosOrderMenuAction>? onMenuAction;

  const _MenuButton({
    super.key,
    required this.pending,
    required this.finished,
    required this.isHeld,
    required this.advanceLabel,
    required this.sideExits,
    required this.onMenuAction,
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

    final ValueChanged<PosOrderMenuAction>? onAction = onMenuAction;
    final bool live = onAction != null;

    return PosOrderMoreMenu(
      enabled: live,
      isHeld: isHeld,
      advanceLabel: advanceLabel,
      sideExits: sideExits,
      openBelow: true,
      onSelected: (PosOrderMenuAction action) => onAction?.call(action),
      triggerBuilder: (context, isOpen, toggle) => Tooltip(
        message: 'Order actions',
        child: Opacity(
          opacity: live ? 1 : PosOrdersSpec.menuDisabledOpacity,
          // A dimmed ⋮ still claims its tap, with no ripple: tapping a dead
          // control must not fall through and open the order underneath.
          child: InkWell(
            onTap: live ? toggle : () {},
            splashFactory: live ? null : NoSplash.splashFactory,
            highlightColor: live ? null : Colors.transparent,
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
