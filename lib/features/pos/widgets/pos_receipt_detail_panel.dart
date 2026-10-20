import 'package:acafe_customer/common/models/cart_model.dart';
import 'package:acafe_customer/di_container.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_product_image_helper.dart';
import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_receipt_history.dart';
import 'package:acafe_customer/features/pos/domain/pos_receipt_reopen_repo.dart';
import 'package:acafe_customer/features/pos/domain/pos_receipt_save_changes_repo.dart';
import 'package:acafe_customer/features/pos/domain/pos_receipts_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_refund_session.dart';
import 'package:acafe_customer/features/pos/domain/pos_method_change.dart';
import 'package:acafe_customer/features/pos/domain/pos_routes.dart';
import 'package:acafe_customer/features/pos/domain/pos_sale_session.dart';
import 'package:acafe_customer/features/pos/providers/pos_access_scope.dart';
import 'package:acafe_customer/features/pos/widgets/pos_receipt_actions_menu.dart';
import 'package:acafe_customer/features/pos/widgets/pos_receipt_change_method_dialog.dart';
import 'package:acafe_customer/features/pos/widgets/pos_receipt_edit_line_dialog.dart';
import 'package:acafe_customer/features/pos/widgets/pos_receipt_changes_saved_dialog.dart';
import 'package:acafe_customer/features/pos/widgets/pos_receipt_confirm_changes_dialog.dart';
import 'package:acafe_customer/features/pos/widgets/pos_receipt_reopen_dialog.dart';
import 'package:acafe_customer/features/pos/widgets/pos_receipt_line.dart';
import 'package:acafe_customer/features/pos/widgets/pos_receipt_panel.dart';
import 'package:acafe_customer/theme/text_legibility.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

enum _ReceiptSidebarMode { view, edit }

/// `receipt-details-sidebar` (1641:3300) — one settled receipt.
///
/// Composed from the very widgets the POS Payment screen composes
/// ([PosReceiptHeader], [PosReceiptCustomerInfo], [PosReceiptOrderListLabel],
/// [PosReceiptLine], [PosReceiptSummary]), so the ticket reads identically
/// either side of the sale. What differs is read-only-ness, and that is carried
/// by their own optional flags rather than by a second copy of the panel.
class PosReceiptDetailPanel extends StatefulWidget {
  final PosReceiptDetail? receipt;
  final bool loading;

  /// Null while nothing is selected or a load is in flight — the button is
  /// drawn disabled rather than removed, so the panel keeps its height.
  final VoidCallback? onPrint;

  /// Opens the email receipt dialog for the currently displayed receipt.
  final VoidCallback? onEmail;

  final String? imageBaseUrl;

  /// Null lets the panel fill its parent (the stacked sheet); the side-by-side
  /// layout pins Figma's 400px.
  final double? width;

  /// Called when this till has just changed the receipt on the server (a saved
  /// edit, a closed method-change dialog) so the screen re-pulls the receipt
  /// and its list row at once instead of waiting on the socket echo.
  final VoidCallback? onRefresh;

  const PosReceiptDetailPanel({
    super.key,
    required this.receipt,
    required this.loading,
    required this.onPrint,
    required this.imageBaseUrl,
    this.onEmail,
    this.onRefresh,
    this.width = PosReceiptsSpec.sidebarWidth,
  });

  @override
  State<PosReceiptDetailPanel> createState() => _PosReceiptDetailPanelState();
}

class _PosReceiptDetailPanelState extends State<PosReceiptDetailPanel> {
  /// The shared customer/table fields are controller-driven, so the panel owns
  /// two controllers and rewrites them whenever the selection changes. Holding
  /// them here (rather than rebuilding a controller per frame) is what keeps
  /// the fields from flickering as the list scrolls behind them.
  final TextEditingController _name = TextEditingController();
  final TextEditingController _table = TextEditingController();

  /// Scoped to this subtree — switching receipts or tapping Discard resets it.
  /// Only the [ValueListenableBuilder] below rebuilds on change; no setState.
  final ValueNotifier<_ReceiptSidebarMode> _sidebarMode =
      ValueNotifier(_ReceiptSidebarMode.view);

  /// Local working copy of receipt lines while in edit mode.
  /// Empty outside edit mode. Updated by [showPosReceiptEditLineDialog].
  final ValueNotifier<List<CartModel>> _editLines = ValueNotifier(const []);

  /// True while save-changes is in flight. The confirm dialog closes before
  /// the request goes out, so without this the sidebar's Save stays live and a
  /// second tap re-submits a receipt the first one already closed.
  final ValueNotifier<bool> _saving = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    _syncControllers();
  }

  @override
  void didUpdateWidget(PosReceiptDetailPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.receipt?.id != widget.receipt?.id) {
      _sidebarMode.value = _ReceiptSidebarMode.view;
      _editLines.value = const [];
    }
    if (oldWidget.receipt?.id != widget.receipt?.id ||
        oldWidget.receipt?.customerName != widget.receipt?.customerName ||
        oldWidget.receipt?.table != widget.receipt?.table) {
      _syncControllers();
    }
  }

  void _syncControllers() {
    // Empty, not a placeholder: POS never persists a table number, and writing
    // a plausible-looking one into the field would be inventing a record.
    _name.text = widget.receipt?.customerName ?? '';
    _table.text = widget.receipt?.table ?? '';
  }

  @override
  void dispose() {
    _name.dispose();
    _table.dispose();
    _sidebarMode.dispose();
    _editLines.dispose();
    _saving.dispose();
    super.dispose();
  }

  Future<void> _saveChanges(PosReceiptDetail receipt, double estimate) async {
    if (_saving.value) return;
    _saving.value = true;
    final result = await sl<PosReceiptSaveChangesRepo>().saveChanges(
      orderId: receipt.id,
      editLines: _editLines.value,
    );
    if (!mounted) return;
    _saving.value = false;

    if (!result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.error?.toString() ?? 'Failed to save changes'),
        ),
      );
      return;
    }

    // Re-pull now, while the success card is up: by the time it fades itself
    // out, the list row and the receipt already carry the new total.
    widget.onRefresh?.call();
    showPosReceiptChangesSavedDialog(
      context: context,
      receipt: receipt,
      // The server re-prices the order; the sidebar's figure is an estimate.
      newTotal: _savedTotal(result.response?.data) ?? estimate,
      onDone: () {
        // The card closes on its own clock; the panel may be gone by then.
        if (!mounted) return;
        _editLines.value = const [];
        _sidebarMode.value = _ReceiptSidebarMode.view;
      },
    );
  }

  static double? _savedTotal(Object? body) {
    if (body is! Map) return null;
    return double.tryParse('${body['new_total']}');
  }

  @override
  Widget build(BuildContext context) {
    final PosReceiptDetail? receipt = widget.receipt;

    return Container(
      width: widget.width,
      clipBehavior: Clip.hardEdge,
      decoration: const BoxDecoration(
        color: PosHomeSpec.panelBg,
        border: Border(
          left: BorderSide(color: Colors.black, width: PosHomeSpec.paneBorder),
        ),
      ),
      child: ValueListenableBuilder<_ReceiptSidebarMode>(
        valueListenable: _sidebarMode,
        builder: (context, mode, _) {
          if (mode == _ReceiptSidebarMode.edit && receipt != null) {
            return _EditModeSidebar(
              receipt: receipt,
              editLinesNotifier: _editLines,
              savingNotifier: _saving,
              imageBaseUrl: widget.imageBaseUrl,
              nameController: _name,
              tableController: _table,
              onDiscard: () {
                _editLines.value = const [];
                _sidebarMode.value = _ReceiptSidebarMode.view;
              },
              onSaveChanges: () {
                final delta = _computeEditDelta(receipt, _editLines.value);
                final newTotal = receipt.total + delta;
                showPosReceiptConfirmChangesDialog(
                  context: context,
                  receipt: receipt,
                  newTotal: newTotal,
                  delta: delta,
                  onConfirm: () => _saveChanges(receipt, newTotal),
                );
              },
              onEditLine: (index) {
                final lines = _editLines.value;
                if (index >= lines.length) return;
                showPosReceiptEditLineDialog(
                  context: context,
                  receiptNumber: receipt.receiptNumber,
                  line: lines[index],
                  onConfirm: (edits) {
                    final updated = List<CartModel>.from(_editLines.value);
                    updated[index] = posApplyLineEdits(lines[index], edits);
                    _editLines.value = updated;
                  },
                );
              },
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PosReceiptHeader(
                orderNumber: receipt?.receiptNumber,
                showOptions: receipt != null,
                onOptions: receipt == null
                    ? null
                    : (btnCtx) => showPosReceiptActionsMenu(
                          context: context,
                          anchorContext: btnCtx,
                          // A refunded sale is closed: both actions go inert
                          // (null = disabled row in the menu).
                          onChangeMethod: receipt.isRefunded
                              ? null
                              : () async {
                                  final PosMethodChangeDraft? draft =
                                      await showPosReceiptChangeMethodDialog(
                                    context: context,
                                    receipt: receipt,
                                  );
                                  if (!mounted) return;
                                  if (draft == null) {
                                    widget.onRefresh?.call();
                                    return;
                                  }
                                  PosSaleSession.instance.methodChange =
                                      PosMethodChange(
                                    orderId: receipt.id,
                                    fromMethod: receipt.method,
                                    toMethod: draft.method,
                                    reason: draft.reason,
                                    total: receipt.total,
                                  );
                                  // go, not push: the payment screen sits outside the
                                  // shell, so pushing would stack two nav bars.
                                  context.go(PosRoutes.payment);
                                },
                          onReopenReceipt: receipt.isRefunded
                              ? null
                              : () => showPosReceiptReopenDialog(
                                    context: context,
                                    receipt: receipt,
                                    onConfirm: (reason) async {
                                      final result =
                                          await sl<PosReceiptReopenRepo>()
                                              .reopen(
                                        orderId: receipt.id,
                                        reason: reason,
                                      );
                                      if (!mounted) return;
                                      if (result.isSuccess) {
                                        _editLines.value =
                                            List<CartModel>.from(receipt.lines);
                                        _sidebarMode.value =
                                            _ReceiptSidebarMode.edit;
                                      } else {
                                        if (!mounted) return;
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              (result.error?.toString()) ??
                                                  'Failed to reopen receipt',
                                            ),
                                          ),
                                        );
                                      }
                                    },
                                  ),
                        ),
              ),
              PosReceiptCustomerInfo(
                nameController: _name,
                tableController: _table,
                readOnly: true,
                showBottomHairline: false,
              ),
              const PosReceiptOrderListLabel(),
              Expanded(
                child: ClipRect(
                  child: _Body(
                    receipt: receipt,
                    loading: widget.loading,
                    imageBaseUrl: widget.imageBaseUrl,
                  ),
                ),
              ),
              PosReceiptSummary(
                subtotal: receipt?.subtotal ?? 0,
                discount: receipt?.discount ?? 0,
                tip: receipt?.tip ?? 0,
                total: receipt?.total ?? 0,
              ),
              _ReceiptsPayWrapper(
                receipt: receipt,
                onPrint: widget.onPrint,
                onEmail: widget.onEmail,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final PosReceiptDetail? receipt;
  final bool loading;
  final String? imageBaseUrl;

  const _Body({
    required this.receipt,
    required this.loading,
    required this.imageBaseUrl,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: PosHomeSpec.ink,
          ),
        ),
      );
    }

    if (receipt == null) {
      return const _Placeholder(
        heading: 'No receipt selected',
        subline: 'Pick a row to see its full breakdown',
      );
    }

    if (receipt!.lines.isEmpty) {
      return const _Placeholder(
        heading: 'No items',
        subline: 'This receipt has no line items',
      );
    }

    // Receipts' own list, deliberately not PosReceiptOrderList: that one is
    // typed to the live cart (List<CartModel?> with index-based +/- callbacks)
    // and widening it would drag cart semantics into a settled receipt. The
    // row widget is shared; only the list around it is local.
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: ListView.builder(
        padding: EdgeInsets.zero,
        clipBehavior: Clip.hardEdge,
        itemCount: receipt!.lines.length,
        itemBuilder: (context, index) {
          final line = receipt!.lines[index];
          return PosReceiptLine(
            line: line,
            imageUrl: KioskProductImageHelper.cartLineImageUrl(
              cart: line,
              productImageBaseUrl: imageBaseUrl,
            ),
            // A record, not a control: no stepper, no EDIT.
            quantityOnly: true,
            showInstruction: true,
          );
        },
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  final String heading;
  final String subline;

  const _Placeholder({required this.heading, required this.subline});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(PosHomeSpec.panelPaddingH),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            heading,
            textAlign: TextAlign.center,
            style: loewExtraBold.copyWith(
              fontSize: PosReceiptsSpec.emptyHeadingSize,
              color: PosHomeSpec.ink,
            ),
          ),
          const SizedBox(height: PosReceiptsSpec.emptyGap),
          Text(
            subline,
            textAlign: TextAlign.center,
            style: swiss721Light.copyWith(
              fontSize: PosReceiptsSpec.emptySublineSize,
              color: TextTones.secondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Manager-gated refund entry point.  Visible only when [receipt.isRefundable].
/// No outer padding — callers supply their own spacing.
class _RefundButton extends StatelessWidget {
  final PosReceiptDetail receipt;

  const _RefundButton({required this.receipt});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (!PosAccessScope.guard(context, PosPermission.processRefunds)) {
            return;
          }
          PosRefundSession.instance.order = receipt;
          PosRefundSession.instance.splits = [];
          // go, not push: /pos-refund lives outside the shell. push stacks
          // the shell nav bar underneath the refund screen's own nav bar.
          context.go(PosRoutes.refund);
        },
        borderRadius: BorderRadius.circular(PosReceiptsSpec.printButtonRadius),
        child: Container(
          height: PosReceiptsSpec.printButtonHeight,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: PosHomeSpec.ink,
            borderRadius:
                BorderRadius.circular(PosReceiptsSpec.printButtonRadius),
          ),
          child: Text(
            'Refund',
            style: loewBold.copyWith(
              fontSize: PosReceiptsSpec.printLabelSize,
              color: Colors.white,
              height: 19 / 16,
            ),
          ),
        ),
      ),
    );
  }
}

/// Pay-wrapper (Figma 1915:20737): Refund (full-width, top) + Print / Email
/// (half-width each, bottom row).  Replaces the old single print button.
class _ReceiptsPayWrapper extends StatelessWidget {
  final PosReceiptDetail? receipt;
  final VoidCallback? onPrint;
  final VoidCallback? onEmail;

  const _ReceiptsPayWrapper({
    required this.receipt,
    required this.onPrint,
    required this.onEmail,
  });

  @override
  Widget build(BuildContext context) {
    final bool refundable = receipt?.isRefundable ?? false;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        PosReceiptsSpec.printPaddingH,
        0,
        PosReceiptsSpec.printPaddingH,
        PosReceiptsSpec.printPaddingBottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (refundable) ...[
            _RefundButton(receipt: receipt!),
            const SizedBox(height: PosReceiptsSpec.payActionsGap),
          ],
          Row(
            children: [
              Expanded(
                child: _HalfOutlinedButton(
                  label: 'Print',
                  onTap: onPrint,
                ),
              ),
              const SizedBox(width: PosReceiptsSpec.payActionsGap),
              Expanded(
                child: _HalfOutlinedButton(
                  label: 'Email receipt',
                  onTap: onEmail,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HalfOutlinedButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _HalfOutlinedButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bool enabled = onTap != null;
    return Opacity(
      opacity: enabled ? 1.0 : 0.35,
      child: Material(
        color: PosReceiptsSpec.surface,
        borderRadius: BorderRadius.circular(PosReceiptsSpec.printButtonRadius),
        child: InkWell(
          onTap: onTap,
          borderRadius:
              BorderRadius.circular(PosReceiptsSpec.printButtonRadius),
          child: Container(
            height: PosReceiptsSpec.printButtonHeight,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius:
                  BorderRadius.circular(PosReceiptsSpec.printButtonRadius),
              border: Border.all(
                color: PosHomeSpec.ink,
                width: PosReceiptsSpec.printButtonBorder,
              ),
            ),
            child: Text(
              label,
              style: loewBold.copyWith(
                fontSize: PosReceiptsSpec.printLabelSize,
                color: PosHomeSpec.ink,
                height: 19 / 16,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Edit-mode sidebar (State 11, Figma 1915:20926) ───────────────────────────

/// Computes the add-on price delta between the original receipt lines and the
/// current edited lines. Positive = extra charge; negative = refund.
double _computeEditDelta(PosReceiptDetail receipt, List<CartModel> editLines) {
  double delta = 0;
  final orig = receipt.lines;
  for (int i = 0; i < editLines.length && i < orig.length; i++) {
    final origIds = {
      for (final a in orig[i].addOnIds ?? const <AddOn>[])
        if (a.id != null) a.id!
    };
    final editIds = {
      for (final a in editLines[i].addOnIds ?? const <AddOn>[])
        if (a.id != null) a.id!
    };
    final qty = (editLines[i].quantity ?? 1).toDouble();
    // A changed size/milk/extra moves the unit price by its surcharge.
    delta += (posLineVariationSurcharge(editLines[i]) -
            posLineVariationSurcharge(orig[i])) *
        qty;
    for (final group
        in editLines[i].product?.effectiveAddOnGroups ?? const []) {
      for (final addon in group.addons) {
        final id = addon.id;
        if (id == null) continue;
        final wasSelected = origIds.contains(id);
        final isSelected = editIds.contains(id);
        if (isSelected && !wasSelected) {
          delta += addon.effectivePrice * qty;
        } else if (!isSelected && wasSelected) {
          delta -= addon.effectivePrice * qty;
        }
      }
    }
  }
  return delta;
}

// ─── Amber for REOPENED badges; the "To charge" row's type is TextTones.warning
const _kReopenedAmber = Color(0xFFD98C1A);
const _kWarningBannerBg = Color(0xFFFFF7E5);
const _kWarningBannerBorder = Color(0xFFF2C74D);

/// Replaces the default sidebar content when a receipt has been reopened for
/// editing.  Switched in by [_ReceiptSidebarMode] without rebuilding the outer
/// [Container] — only the [ValueListenableBuilder] subtree re-renders.
/// Cream/off-white label color used on the ink-bg edit header.
const _editHeaderLabel = Color(0xFFF7F1DE);

class _EditModeSidebar extends StatelessWidget {
  final PosReceiptDetail receipt;
  final ValueNotifier<List<CartModel>> editLinesNotifier;

  /// While true, Save and both Discards are inert — see the panel's `_saving`.
  final ValueNotifier<bool> savingNotifier;
  final String? imageBaseUrl;
  final TextEditingController nameController;
  final TextEditingController tableController;
  final VoidCallback onDiscard;

  /// Wired in State 13. Null until that step is implemented.
  final VoidCallback? onSaveChanges;

  /// Called with the zero-based line index when the user taps EDIT on a line.
  final void Function(int index)? onEditLine;

  const _EditModeSidebar({
    required this.receipt,
    required this.editLinesNotifier,
    required this.savingNotifier,
    required this.imageBaseUrl,
    required this.nameController,
    required this.tableController,
    required this.onDiscard,
    required this.onSaveChanges,
    required this.onEditLine,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ValueListenableBuilder<bool>(
          valueListenable: savingNotifier,
          builder: (context, saving, _) => _EditModeHeader(
            receiptNumber: receipt.receiptNumber,
            onDiscard: saving ? null : onDiscard,
          ),
        ),
        const _EditModeWarningBanner(),
        PosReceiptCustomerInfo(
          nameController: nameController,
          tableController: tableController,
          readOnly: false,
          showBottomHairline: false,
        ),
        const PosReceiptOrderListLabel(),
        Expanded(
          child: ClipRect(
            child: ValueListenableBuilder<List<CartModel>>(
              valueListenable: editLinesNotifier,
              builder: (context, lines, _) => _EditModeLineList(
                lines: lines,
                imageBaseUrl: imageBaseUrl,
                onEditLine: onEditLine,
              ),
            ),
          ),
        ),
        ValueListenableBuilder<List<CartModel>>(
          valueListenable: editLinesNotifier,
          builder: (context, lines, _) {
            final delta = _computeEditDelta(receipt, lines);
            return _EditModeTotals(
              subtotal: receipt.subtotal,
              discount: receipt.discount,
              tip: receipt.tip,
              total: receipt.total,
              delta: delta,
              methodLabel: receipt.methodLabel,
            );
          },
        ),
        ValueListenableBuilder<bool>(
          valueListenable: savingNotifier,
          builder: (context, saving, _) => _EditModeFooter(
            saving: saving,
            onDiscard: saving ? null : onDiscard,
            onSaveChanges: saving ? null : onSaveChanges,
          ),
        ),
      ],
    );
  }
}

class _EditModeHeader extends StatelessWidget {
  final String receiptNumber;
  final VoidCallback? onDiscard;

  const _EditModeHeader({
    required this.receiptNumber,
    required this.onDiscard,
  });

  @override
  Widget build(BuildContext context) {
    // Background lives in the decoration only: a Container given both `color`
    // and `decoration` fails its constructor assert, which in a debug build
    // swapped this whole header for the "Something went wrong" error box.
    return Container(
      height: PosHomeSpec.headerHeight,
      padding: const EdgeInsets.symmetric(
        horizontal: PosHomeSpec.panelPaddingH,
      ),
      decoration: const BoxDecoration(
        color: PosHomeSpec.panelBg,
        border: Border(
          bottom: BorderSide(color: PosHomeSpec.hairline),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Editing receipt',
                  style: loewExtraBold.copyWith(
                    fontSize: PosHomeSpec.headerTitleSize,
                    color: PosHomeSpec.ink,
                    height: PosHomeSpec.headerTitleHeight,
                  ),
                ),
                const SizedBox(height: PosHomeSpec.headerTitleGap),
                Row(
                  children: [
                    Text(
                      '#$receiptNumber · Reopened',
                      style: swiss721Light.copyWith(
                        fontSize: PosHomeSpec.headerNumberSize,
                        color: TextTones.secondary,
                        height: PosHomeSpec.headerNumberHeight,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _kReopenedAmber,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Text(
                        'REOPENED',
                        style: loewExtraBold.copyWith(
                          fontSize: 11,
                          color: Colors.white,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onDiscard,
            child: Container(
              height: 32,
              foregroundDecoration: onDiscard == null
                  ? BoxDecoration(
                      color: PosHomeSpec.panelBg.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(8),
                    )
                  : null,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: PosHomeSpec.ink.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Discard',
                style: loewBold.copyWith(
                  fontSize: 13,
                  color: PosHomeSpec.ink,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Yellow warning banner shown below the edit-mode header.
class _EditModeWarningBanner extends StatelessWidget {
  const _EditModeWarningBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        PosHomeSpec.panelPaddingH,
        10,
        PosHomeSpec.panelPaddingH,
        0,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _kWarningBannerBg,
        border: Border.all(color: _kWarningBannerBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'You are editing a paid receipt. '
        'Changes are logged with your name and time.',
        style: swiss721Light.copyWith(
          fontSize: 12,
          color: PosHomeSpec.ink,
          height: 16 / 12,
        ),
      ),
    );
  }
}

/// Totals block for edit mode: shows the standard subtotal/discount/total rows
/// plus an optional amber "To charge / To refund" line when the delta is non-zero.
class _EditModeTotals extends StatelessWidget {
  final double subtotal;
  final double discount;
  final double tip;
  final double total;
  final double delta;
  final String methodLabel;

  const _EditModeTotals({
    required this.subtotal,
    required this.discount,
    required this.tip,
    required this.total,
    required this.delta,
    required this.methodLabel,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasCharge = delta.abs() >= 0.005;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PosReceiptSummary(
          subtotal: subtotal,
          discount: discount,
          tip: tip,
          total: total,
        ),
        if (hasCharge)
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(
                horizontal: PosHomeSpec.panelPaddingH),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: PosHomeSpec.hairline),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  delta > 0
                      ? 'To charge ($methodLabel)'
                      : 'To refund ($methodLabel)',
                  style: loewBold.copyWith(
                    fontSize: 13,
                    color: TextTones.warning,
                  ),
                ),
                Text(
                  '${delta > 0 ? '+' : '-'} ${PosHomeSpec.formatPrice(delta.abs())}',
                  style: loewExtraBold.copyWith(
                    fontSize: 13,
                    color: TextTones.warning,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _EditModeLineList extends StatelessWidget {
  final List<CartModel> lines;
  final String? imageBaseUrl;
  final void Function(int index)? onEditLine;

  const _EditModeLineList({
    required this.lines,
    required this.imageBaseUrl,
    required this.onEditLine,
  });

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) {
      return const SizedBox.shrink();
    }
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: ListView.builder(
        padding: EdgeInsets.zero,
        clipBehavior: Clip.hardEdge,
        itemCount: lines.length,
        itemBuilder: (context, index) {
          final line = lines[index];
          return _EditableLineRow(
            line: line,
            imageUrl: KioskProductImageHelper.cartLineImageUrl(
              cart: line,
              productImageBaseUrl: imageBaseUrl,
            ),
            onEdit: onEditLine == null ? null : () => onEditLine!(index),
          );
        },
      ),
    );
  }
}

class _EditableLineRow extends StatelessWidget {
  final dynamic line;
  final String? imageUrl;
  final VoidCallback? onEdit;

  const _EditableLineRow({
    required this.line,
    required this.imageUrl,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.centerRight,
      children: [
        PosReceiptLine(
          line: line,
          imageUrl: imageUrl ?? '',
          quantityOnly: true,
          showInstruction: true,
        ),
        Positioned(
          right: PosHomeSpec.panelPaddingH,
          child: Opacity(
            opacity: onEdit != null ? 1.0 : 0.35,
            child: GestureDetector(
              onTap: onEdit,
              child: Container(
                height: 28,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: PosHomeSpec.ink,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'EDIT',
                  style: loewBold.copyWith(
                    fontSize: 11,
                    color: _editHeaderLabel,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _EditModeFooter extends StatelessWidget {
  final bool saving;
  final VoidCallback? onDiscard;
  final VoidCallback? onSaveChanges;

  const _EditModeFooter({
    required this.saving,
    required this.onDiscard,
    required this.onSaveChanges,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        PosReceiptsSpec.printPaddingH,
        0,
        PosReceiptsSpec.printPaddingH,
        PosReceiptsSpec.printPaddingBottom,
      ),
      child: Row(
        children: [
          Expanded(
            child: _HalfOutlinedButton(
              label: 'Discard',
              onTap: onDiscard,
            ),
          ),
          const SizedBox(width: PosReceiptsSpec.payActionsGap),
          Expanded(
            child: _EditSaveButton(saving: saving, onTap: onSaveChanges),
          ),
        ],
      ),
    );
  }
}

class _EditSaveButton extends StatelessWidget {
  final bool saving;
  final VoidCallback? onTap;

  const _EditSaveButton({required this.saving, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // Saving keeps full ink: the spinner says "working", a faded button
    // would say "unavailable".
    final bool enabled = onTap != null || saving;
    return Opacity(
      opacity: enabled ? 1.0 : 0.35,
      child: Material(
        color: PosHomeSpec.ink,
        borderRadius: BorderRadius.circular(PosReceiptsSpec.printButtonRadius),
        child: InkWell(
          onTap: onTap,
          borderRadius:
              BorderRadius.circular(PosReceiptsSpec.printButtonRadius),
          child: SizedBox(
            height: PosReceiptsSpec.printButtonHeight,
            child: Center(
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _editHeaderLabel,
                      ),
                    )
                  : Text(
                      'Save changes',
                      style: loewBold.copyWith(
                        fontSize: PosReceiptsSpec.printLabelSize,
                        color: _editHeaderLabel,
                        height: 19 / 16,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// `print-receipt-btn` (1641:3374) — outlined, where the live panel puts its
/// ink-filled PAY bar. Deliberately a different control: PAY commits money,
/// this reprints a record, and they must not look like the same button.
class PosPrintReceiptButton extends StatelessWidget {
  final VoidCallback? onPrint;

  const PosPrintReceiptButton({super.key, this.onPrint});

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPrint != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        PosReceiptsSpec.printPaddingH,
        PosReceiptsSpec.printPaddingH,
        PosReceiptsSpec.printPaddingH,
        PosReceiptsSpec.printPaddingBottom,
      ),
      child: Opacity(
        opacity: enabled ? 1 : 0.35,
        child: Material(
          color: PosReceiptsSpec.surface,
          borderRadius:
              BorderRadius.circular(PosReceiptsSpec.printButtonRadius),
          child: InkWell(
            onTap: onPrint,
            borderRadius:
                BorderRadius.circular(PosReceiptsSpec.printButtonRadius),
            child: Container(
              height: PosReceiptsSpec.printButtonHeight,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius:
                    BorderRadius.circular(PosReceiptsSpec.printButtonRadius),
                border: Border.all(
                  color: PosHomeSpec.ink,
                  width: PosReceiptsSpec.printButtonBorder,
                ),
              ),
              child: Text(
                'Print Receipt',
                style: loewBold.copyWith(
                  fontSize: PosReceiptsSpec.printLabelSize,
                  color: PosHomeSpec.ink,
                  height: 19 / 16,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
