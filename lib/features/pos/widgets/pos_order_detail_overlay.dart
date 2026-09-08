import 'package:acafe_customer/common/widgets/custom_image_widget.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_manager_repo.dart';
import 'package:acafe_customer/features/pos/domain/pos_advance_outcome.dart';
import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_order_card.dart';
import 'package:acafe_customer/features/pos/domain/pos_order_detail.dart';
import 'package:acafe_customer/features/pos/domain/pos_order_detail_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_order_grouping.dart';
import 'package:acafe_customer/features/pos/widgets/pos_order_source_icon.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter/material.dart';

/// The Orders board detail overlay — Figma **1641:4341** (App / NEW),
/// **1641:4490** (Kiosk), **1641:4640** (Cashier) and **1641:5129**
/// (In Progress).
///
/// Those four frames are **one modal on two independent axes**, so this is one
/// widget with two conditionals rather than four screens:
///
///   * source — `channelKey` picks the badge glyph and label, delegated whole
///     to [PosOrderSourceIcon] so the badge here and the badge on the board
///     card can never disagree about what a channel looks like.
///   * status — `orderStatus` picks the badge colour and the action.
///
/// The action is **not** hardcoded to "Mark as complete" the way Figma draws
/// it. Both its label and its target come from [PosOrderGrouping], the same
/// ladder the board card runs, so opening a card and opening its modal always
/// offer the same next step. A `preparing` order's next rung is
/// `item_to_collect`, not `completed`; labelling that "complete" would claim
/// an order was handed over when the customer has had nothing, and would skip
/// the `ready_at` stamp and the "ready to collect" push that rung fires.
///
/// Sections the mock always draws are omitted when the order has nothing real
/// behind them — see [PosOrderDetail.hasContact] and
/// [PosOrderDetail.displayNote]. Most orders are guests with no contact row at
/// all, so drawing an empty card would be the common case, not the edge one.
class PosOrderDetailOverlay extends StatefulWidget {
  final PosOrderCard order;
  final KioskManagerRepo repo;

  /// Runs the transition. Supplied by the board as its own gated `_advance`,
  /// not the provider method underneath it — so the completion confirmation
  /// the board shows is the same one this CTA shows, and neither surface can
  /// grow a second completion path.
  ///
  /// The three outcomes are distinct on purpose: a cancelled confirmation must
  /// leave this overlay open and untouched, which a null-means-success return
  /// could not express.
  final Future<PosAdvanceResult> Function(PosOrderCard order)? onAdvance;

  const PosOrderDetailOverlay({
    super.key,
    required this.order,
    required this.repo,
    this.onAdvance,
  });

  @override
  State<PosOrderDetailOverlay> createState() => _PosOrderDetailOverlayState();
}

class _PosOrderDetailOverlayState extends State<PosOrderDetailOverlay> {
  PosOrderDetail? _detail;
  String? _error;
  bool _loading = true;
  bool _advancing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final apiResponse = await widget.repo.getTransactionDetail(widget.order.id);
    if (!mounted) return;

    final response = apiResponse.response;

    if (response != null && response.statusCode == 200 && response.data is Map) {
      setState(() {
        _detail = PosOrderDetail.fromJson(
          Map<String, dynamic>.from(response.data as Map),
        );
        _error = null;
        _loading = false;
      });
      return;
    }

    setState(() {
      _error = apiResponse.error?.toString() ?? 'Could not load this order';
      _loading = false;
    });
  }

  /// The status the action works from. Prefers the freshly-loaded detail so a
  /// card that moved between the board's last refresh and this open does not
  /// offer a stale rung.
  String get _status => _detail?.orderStatus ?? widget.order.orderStatus;

  Future<void> _advance() async {
    final Future<PosAdvanceResult> Function(PosOrderCard)? onAdvance =
        widget.onAdvance;
    if (onAdvance == null || _advancing) return;

    setState(() => _advancing = true);
    final PosAdvanceResult result =
        await onAdvance(widget.order.withStatus(_status));
    if (!mounted) return;

    setState(() => _advancing = false);

    if (result.isAdvanced) {
      Navigator.of(context).maybePop();
      return;
    }

    // Declined confirmation: the operator is still looking at this order, so
    // the overlay stays exactly as it was and nothing is reported.
    if (!result.isFailed) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Order #${widget.order.id}: ${result.message}'),
          backgroundColor: PosOrderDetailSpec.ink,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final Size window = MediaQuery.sizeOf(context);
    final double maxWidth = window.width - PosOrderDetailSpec.viewportInset * 2;
    final double maxHeight = window.height - PosOrderDetailSpec.viewportInset * 2;

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Tapping the dim closes, matching every other POS overlay.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).maybePop(),
              child: const ColoredBox(color: PosOrderDetailSpec.backdrop),
            ),
          ),
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: maxWidth < PosOrderDetailSpec.modalWidth
                    ? maxWidth
                    : PosOrderDetailSpec.modalWidth,
                maxHeight: maxHeight < PosOrderDetailSpec.modalHeight
                    ? maxHeight
                    : PosOrderDetailSpec.modalHeight,
              ),
              // Swallows taps so a click inside the card does not hit the
              // dismiss layer underneath.
              child: GestureDetector(
                onTap: () {},
                child: Container(
                  decoration: BoxDecoration(
                    color: PosOrderDetailSpec.modalBg,
                    borderRadius: BorderRadius.circular(
                      PosOrderDetailSpec.modalRadius,
                    ),
                    border: Border.all(
                      color: PosOrderDetailSpec.hairline,
                      width: PosOrderDetailSpec.modalBorder,
                    ),
                    boxShadow: PosOrderDetailSpec.modalShadow,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Header(
                        orderId: widget.order.id,
                        status: _status,
                        createdAt: _detail?.createdAt ?? widget.order.createdAt,
                        channelKey:
                            _detail?.channelKey ?? widget.order.channelKey,
                        onClose: () => Navigator.of(context).maybePop(),
                      ),
                      Flexible(child: _body()),
                      _actionBar(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(48),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    final PosOrderDetail? detail = _detail;

    if (detail == null) {
      return Padding(
        padding: const EdgeInsets.all(48),
        child: Center(
          child: Text(
            _error ?? 'Could not load this order',
            textAlign: TextAlign.center,
            style: loewRegular.copyWith(
              fontSize: PosOrderDetailSpec.contactTextSize,
              color: PosOrderDetailSpec.inkAlpha(0.6),
            ),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool stacked = constraints.maxWidth <
            PosOrderDetailSpec.stackColumnsBelowWidth;

        final Widget left = _leftColumn(detail);
        final Widget right = _itemsSection(detail);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(PosOrderDetailSpec.bodyPad),
          child: stacked
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    left,
                    const SizedBox(height: PosOrderDetailSpec.columnGap),
                    right,
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: left),
                    const SizedBox(width: PosOrderDetailSpec.columnGap),
                    SizedBox(
                      width: PosOrderDetailSpec.rightColumnWidth,
                      child: right,
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _leftColumn(PosOrderDetail detail) {
    final List<Widget> sections = <Widget>[];

    // Both sections are conditional: a guest order has no contact row, and most
    // notes are the name-carrier string already shown in the header.
    if (detail.hasContact) {
      sections.add(_customerSection(detail));
    }

    final String? note = detail.displayNote;
    if (note != null) {
      sections.add(_notesSection(note));
    }

    sections.add(_totalsSection(detail));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int i = 0; i < sections.length; i++) ...[
          if (i > 0) const SizedBox(height: PosOrderDetailSpec.leftSectionGap),
          sections[i],
        ],
      ],
    );
  }

  Widget _customerSection(PosOrderDetail detail) {
    return _Section(
      label: 'Customer Details',
      gap: PosOrderDetailSpec.sectionLabelGap,
      child: Container(
        padding: const EdgeInsets.all(PosOrderDetailSpec.customerCardPad),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.circular(PosOrderDetailSpec.customerCardRadius),
          border: Border.all(color: PosOrderDetailSpec.hairline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (detail.customerName.isNotEmpty)
              Text(
                detail.customerName,
                style: loewExtraBold.copyWith(
                  fontSize: PosOrderDetailSpec.customerNameSize,
                  color: PosOrderDetailSpec.ink,
                ),
              ),
            const SizedBox(height: PosOrderDetailSpec.customerCardGap),
            if (detail.customerPhone != null)
              _ContactRow(
                icon: Icons.phone_outlined,
                value: detail.customerPhone!,
              ),
            if (detail.customerPhone != null && detail.customerEmail != null)
              const SizedBox(height: PosOrderDetailSpec.contactLineGap),
            if (detail.customerEmail != null)
              _ContactRow(
                icon: Icons.mail_outline,
                value: detail.customerEmail!,
              ),
          ],
        ),
      ),
    );
  }

  Widget _notesSection(String note) {
    return _Section(
      label: 'Order Notes',
      gap: PosOrderDetailSpec.customerCardGap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(PosOrderDetailSpec.notePad),
        decoration: BoxDecoration(
          color: PosOrderDetailSpec.noteBg,
          borderRadius: BorderRadius.circular(PosOrderDetailSpec.noteRadius),
          border: Border.all(color: PosOrderDetailSpec.noteBorder),
        ),
        child: Text(
          note,
          style: loewRegular.copyWith(
            fontSize: PosOrderDetailSpec.noteTextSize,
            height: PosOrderDetailSpec.noteLineHeight /
                PosOrderDetailSpec.noteTextSize,
            color: PosOrderDetailSpec.ink,
          ),
        ),
      ),
    );
  }

  /// Not in Figma's modal, but the three figures are already in the payload and
  /// already reconcile with what was charged. Added under the left column,
  /// where the mock leaves space, rather than left off a screen whose whole job
  /// is "everything about this order".
  Widget _totalsSection(PosOrderDetail detail) {
    return _Section(
      label: 'Total',
      gap: PosOrderDetailSpec.customerCardGap,
      child: Container(
        padding: const EdgeInsets.all(PosOrderDetailSpec.customerCardPad),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.circular(PosOrderDetailSpec.customerCardRadius),
          border: Border.all(color: PosOrderDetailSpec.hairline),
        ),
        child: Column(
          children: [
            _TotalRow(label: 'Subtotal', value: detail.subtotal),
            if (detail.discount > 0) ...[
              const SizedBox(height: PosOrderDetailSpec.contactLineGap),
              _TotalRow(label: 'Discount', value: -detail.discount),
            ],
            const SizedBox(height: PosOrderDetailSpec.customerCardGap),
            _TotalRow(label: 'Total', value: detail.total, emphasised: true),
          ],
        ),
      ),
    );
  }

  Widget _itemsSection(PosOrderDetail detail) {
    return _Section(
      label: 'Order Items',
      gap: PosOrderDetailSpec.itemsLabelGap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final PosOrderDetailItem item in detail.items)
            _ItemRow(item: item),
        ],
      ),
    );
  }

  Widget _actionBar() {
    final String? label = PosOrderGrouping.actionLabelFor(_status);

    return Container(
      padding: const EdgeInsets.fromLTRB(
        PosOrderDetailSpec.barPadH,
        PosOrderDetailSpec.barPadTop,
        PosOrderDetailSpec.barPadH,
        PosOrderDetailSpec.barPadBottom,
      ),
      decoration: const BoxDecoration(
        color: PosOrderDetailSpec.cream,
        border: Border(
          top: BorderSide(
            color: PosOrderDetailSpec.ink,
            width: PosOrderDetailSpec.barTopBorder,
          ),
        ),
      ),
      // A finished order has no rung left, so the bar reports the state it
      // reached instead of offering an action that cannot fire.
      child: label == null
          ? _StatusLabel(status: _status)
          : _ActionButton(
              label: label,
              busy: _advancing,
              onTap: widget.onAdvance == null ? null : _advance,
            ),
    );
  }
}

// ── Header ─────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final int orderId;
  final String status;
  final DateTime? createdAt;
  final String channelKey;
  final VoidCallback onClose;

  const _Header({
    required this.orderId,
    required this.status,
    required this.createdAt,
    required this.channelKey,
    required this.onClose,
  });

  static Color _badgeColour(String status) {
    switch (PosOrderGrouping.sectionOf(status)) {
      case PosOrderSection.newOrders:
        return PosOrderDetailSpec.badgeNew;
      case PosOrderSection.inProgress:
        return PosOrderDetailSpec.badgeInProgress;
      case PosOrderSection.finished:
        return PosOrderDetailSpec.badgeFinished;
      case PosOrderSection.excluded:
        return PosOrderDetailSpec.inkAlpha(0.4);
    }
  }

  String get _clock {
    final DateTime? at = createdAt;
    if (at == null) return '';
    return '${at.hour.toString().padLeft(2, '0')}:'
        '${at.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final String sectionLabel =
        PosOrderGrouping.labelFor(PosOrderGrouping.sectionOf(status));

    return Container(
      padding: const EdgeInsets.fromLTRB(
        PosOrderDetailSpec.headerPadH,
        PosOrderDetailSpec.headerPadTop,
        PosOrderDetailSpec.headerPadH,
        PosOrderDetailSpec.headerPadBottom,
      ),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: PosOrderDetailSpec.hairline),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Wrap(
              spacing: PosOrderDetailSpec.headerGap,
              runSpacing: PosOrderDetailSpec.contactLineGap,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Order #$orderId',
                  style: loewExtraBold.copyWith(
                    fontSize: PosOrderDetailSpec.titleSize,
                    color: PosOrderDetailSpec.ink,
                  ),
                ),
                if (sectionLabel.isNotEmpty)
                  _Pill(
                    background: _badgeColour(status),
                    radius: PosOrderDetailSpec.statusBadgeRadius,
                    child: Text(
                      sectionLabel,
                      style: loewExtraBold.copyWith(
                        fontSize: PosOrderDetailSpec.statusBadgeTextSize,
                        color: PosOrderDetailSpec.cream,
                      ),
                    ),
                  ),
                if (_clock.isNotEmpty)
                  _Pill(
                    background: PosOrderDetailSpec.cream,
                    radius: PosOrderDetailSpec.timeBadgeRadius,
                    padH: PosOrderDetailSpec.timeBadgePadH,
                    child: Text(
                      _clock,
                      style: loewBold.copyWith(
                        fontSize: PosOrderDetailSpec.timeBadgeTextSize,
                        color: PosOrderDetailSpec.ink,
                      ),
                    ),
                  ),
                _Pill(
                  background: PosOrderDetailSpec.cream,
                  radius: PosOrderDetailSpec.sourceBadgeRadius,
                  border: PosOrderDetailSpec.hairline,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        PosOrderSourceIcon.iconFor(channelKey),
                        size: PosOrderDetailSpec.sourceIconSize,
                        color: PosOrderDetailSpec.ink,
                      ),
                      const SizedBox(width: PosOrderDetailSpec.sourceBadgeGap),
                      Text(
                        PosOrderSourceIcon.labelFor(channelKey),
                        style: loewExtraBold.copyWith(
                          fontSize: PosOrderDetailSpec.sourceTextSize,
                          color: PosOrderDetailSpec.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: PosOrderDetailSpec.headerGap),
          IconButton(
            onPressed: onClose,
            tooltip: 'Close',
            iconSize: PosOrderDetailSpec.closeSize,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(
              minWidth: PosOrderDetailSpec.closeSize,
              minHeight: PosOrderDetailSpec.closeSize,
            ),
            icon: Icon(
              Icons.cancel_outlined,
              size: PosOrderDetailSpec.closeSize,
              color: PosOrderDetailSpec.inkAlpha(0.6),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Pieces ─────────────────────────────────────────────────────────────

class _Pill extends StatelessWidget {
  final Widget child;
  final Color background;
  final double radius;
  final double padH;
  final Color? border;

  const _Pill({
    required this.child,
    required this.background,
    required this.radius,
    this.padH = PosOrderDetailSpec.statusBadgePadH,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: padH,
        vertical: PosOrderDetailSpec.statusBadgePadV,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(radius),
        border: border == null ? null : Border.all(color: border!),
      ),
      child: child,
    );
  }
}

class _Section extends StatelessWidget {
  final String label;
  final Widget child;
  final double gap;

  const _Section({required this.label, required this.child, required this.gap});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label.toUpperCase(),
          style: loewBold.copyWith(
            fontSize: PosOrderDetailSpec.sectionLabelSize,
            letterSpacing: PosOrderDetailSpec.sectionLabelTracking,
            color: PosOrderDetailSpec.inkAlpha(0.6),
          ),
        ),
        SizedBox(height: gap),
        child,
      ],
    );
  }
}

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String value;

  const _ContactRow({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: PosOrderDetailSpec.contactIconSize,
          color: PosOrderDetailSpec.inkAlpha(0.6),
        ),
        const SizedBox(width: PosOrderDetailSpec.contactRowGap),
        Expanded(
          child: Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: loewRegular.copyWith(
              fontSize: PosOrderDetailSpec.contactTextSize,
              color: PosOrderDetailSpec.inkAlpha(0.6),
            ),
          ),
        ),
      ],
    );
  }
}

class _TotalRow extends StatelessWidget {
  final String label;
  final double value;
  final bool emphasised;

  const _TotalRow({
    required this.label,
    required this.value,
    this.emphasised = false,
  });

  @override
  Widget build(BuildContext context) {
    final TextStyle style = (emphasised ? loewExtraBold : loewRegular).copyWith(
      fontSize: emphasised
          ? PosOrderDetailSpec.customerNameSize
          : PosOrderDetailSpec.contactTextSize,
      color: emphasised
          ? PosOrderDetailSpec.ink
          : PosOrderDetailSpec.inkAlpha(0.6),
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: style),
        Text(
          PosHomeSpec.formatPrice(value, padZero: false),
          style: style,
        ),
      ],
    );
  }
}

class _ItemRow extends StatelessWidget {
  final PosOrderDetailItem item;

  const _ItemRow({required this.item});

  /// `€ 4.50 · Cup` — the variation labels Figma appends after the price. A
  /// line with no variation just shows the price.
  String get _meta {
    final String price = PosHomeSpec.formatPrice(item.unitPrice, padZero: false);
    if (item.variationLabels.isEmpty) return price;
    return '$price · ${item.variationLabels.join(' · ')}';
  }

  /// One line per add-on plus the line's own instruction. Figma shows a single
  /// `+ Oat Milk`; a real line can carry several add-ons and a free-text note,
  /// and dropping them would hide what the kitchen was actually told.
  List<String> get _notes {
    return <String>[
      for (final PosOrderDetailAddon addon in item.addons)
        addon.quantity > 1 ? '${addon.quantity}× ${addon.name}' : addon.name,
      if (item.instruction != null && item.instruction!.trim().isNotEmpty)
        item.instruction!.trim(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: PosOrderDetailSpec.itemRowPadH,
        vertical: PosOrderDetailSpec.itemRowPadV,
      ),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: PosOrderDetailSpec.itemDivider),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius:
                BorderRadius.circular(PosOrderDetailSpec.itemThumbRadius),
            child: SizedBox(
              width: PosOrderDetailSpec.itemThumbWidth,
              height: PosOrderDetailSpec.itemThumbHeight,
              child: CustomImageWidget(
                image: item.image ?? '',
                width: PosOrderDetailSpec.itemThumbWidth,
                height: PosOrderDetailSpec.itemThumbHeight,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: PosOrderDetailSpec.itemRowGap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.quantity > 1
                      ? '${item.quantity}× ${item.name}'
                      : item.name,
                  style: loewExtraBold.copyWith(
                    fontSize: PosOrderDetailSpec.itemNameSize,
                    color: PosOrderDetailSpec.ink,
                  ),
                ),
                const SizedBox(height: PosOrderDetailSpec.itemDetailGap),
                Text(
                  _meta,
                  style: loewRegular.copyWith(
                    fontSize: PosOrderDetailSpec.itemMetaSize,
                    color: PosOrderDetailSpec.inkAlpha(0.6),
                  ),
                ),
                // Only drawn where the line actually has add-ons or a note.
                for (final String note in _notes) ...[
                  const SizedBox(height: PosOrderDetailSpec.itemDetailGap),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '+',
                        style: loewRegular.copyWith(
                          fontSize: PosOrderDetailSpec.itemMetaSize,
                          color: PosOrderDetailSpec.itemNoteInk,
                        ),
                      ),
                      const SizedBox(
                        width: PosOrderDetailSpec.itemDetailGap,
                      ),
                      Expanded(
                        child: Text(
                          note,
                          style: loewRegular.copyWith(
                            fontSize: PosOrderDetailSpec.itemNoteSize,
                            color: PosOrderDetailSpec.itemNoteInk,
                          ),
                        ),
                      ),
                    ],
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

class _ActionButton extends StatelessWidget {
  final String label;
  final bool busy;
  final VoidCallback? onTap;

  const _ActionButton({required this.label, required this.busy, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: PosOrderDetailSpec.ink,
      borderRadius: BorderRadius.circular(PosOrderDetailSpec.actionRadius),
      child: InkWell(
        onTap: busy ? null : onTap,
        borderRadius: BorderRadius.circular(PosOrderDetailSpec.actionRadius),
        child: SizedBox(
          height: PosOrderDetailSpec.actionHeight,
          child: Center(
            child: busy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    label,
                    style: loewBold.copyWith(
                      fontSize: PosOrderDetailSpec.actionTextSize,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// What a finished order gets instead of a button: the state it reached.
class _StatusLabel extends StatelessWidget {
  final String status;

  const _StatusLabel({required this.status});

  String get _text {
    final String s = status.trim().toLowerCase();
    if (s == 'completed') return 'Completed';
    if (s == 'delivered') return 'Delivered';
    if (s == 'canceled') return 'Canceled';
    if (s.isEmpty) return '';
    return s[0].toUpperCase() + s.substring(1).replaceAll('_', ' ');
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: PosOrderDetailSpec.actionHeight,
      child: Center(
        child: Text(
          _text,
          style: loewBold.copyWith(
            fontSize: PosOrderDetailSpec.actionTextSize,
            color: PosOrderDetailSpec.inkAlpha(0.55),
          ),
        ),
      ),
    );
  }
}
