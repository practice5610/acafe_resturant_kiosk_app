import 'package:acafe_customer/common/models/cart_model.dart';
import 'package:acafe_customer/common/widgets/custom_image_widget.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_cart_totals.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_product_image_helper.dart';
import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_receipt_line_copy.dart';
import 'package:acafe_customer/utill/images.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Scrollable cart lines for the cart-active receipt pane.
class PosReceiptOrderList extends StatelessWidget {
  final List<CartModel?> lines;
  final String? imageBaseUrl;
  final String? dealImageBaseUrl;
  final ValueChanged<int> onIncrement;
  final ValueChanged<int> onDecrement;
  final ValueChanged<int> onEdit;

  const PosReceiptOrderList({
    super.key,
    required this.lines,
    required this.imageBaseUrl,
    this.dealImageBaseUrl,
    required this.onIncrement,
    required this.onDecrement,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final List<int> indices = [
      for (int i = 0; i < lines.length; i++)
        if (lines[i] != null) i,
    ];

    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: ListView.builder(
        padding: EdgeInsets.zero,
        clipBehavior: Clip.hardEdge,
        itemCount: indices.length,
        itemBuilder: (context, i) {
          final int index = indices[i];
          return PosReceiptLine(
            line: lines[index]!,
            imageUrl: KioskProductImageHelper.cartLineImageUrl(
              cart: lines[index]!,
              productImageBaseUrl: imageBaseUrl,
              dealImageBaseUrl: dealImageBaseUrl,
            ),
            onIncrement: () => onIncrement(index),
            onDecrement: () => onDecrement(index),
            onEdit: () => onEdit(index),
          );
        },
      ),
    );
  }
}

/// One row from Figma `order-item-*` (1641:2159).
///
/// Layout is a constrained Row, not a Stack of Positioned children: the
/// thumbnail is fixed, details take leftover width (and ellipsize), and the
/// action cluster is a fixed Figma width so long names cannot push EDIT / qty
/// out of the receipt pane.
class PosReceiptLine extends StatelessWidget {
  final CartModel line;
  final String imageUrl;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onEdit;

  const PosReceiptLine({
    super.key,
    required this.line,
    required this.imageUrl,
    required this.onIncrement,
    required this.onDecrement,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final List<PosReceiptNote> notes = posReceiptNotes(line);
    final String? unit = posReceiptUnit(line);
    final String price = PosHomeSpec.formatPrice(kioskLineUnitPrice(line));
    final String priceLine = unit == null ? price : '$price · $unit';

    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: PosHomeSpec.itemDivider),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: PosHomeSpec.linePaddingH,
          vertical: PosHomeSpec.linePaddingV,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Thumb(imageUrl: imageUrl),
            const SizedBox(width: PosHomeSpec.lineGap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    posReceiptLineName(line),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: loewExtraBold.copyWith(
                      fontSize: PosHomeSpec.lineNameSize,
                      color: PosHomeSpec.ink,
                      height: PosHomeSpec.lineNameHeight,
                    ),
                  ),
                  const SizedBox(height: PosHomeSpec.lineDetailsGap),
                  Text(
                    priceLine,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: swiss721Light.copyWith(
                      fontSize: PosHomeSpec.linePriceSize,
                      color: PosHomeSpec.inkAlpha(0.6),
                      height: PosHomeSpec.linePriceHeight,
                    ),
                  ),
                  for (final PosReceiptNote note in notes) ...[
                    const SizedBox(height: PosHomeSpec.lineDetailsGap),
                    _NoteRow(note: note),
                  ],
                ],
              ),
            ),
            const SizedBox(width: PosHomeSpec.lineGap),
            SizedBox(
              width: PosHomeSpec.lineActionsWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _EditButton(onTap: onEdit),
                  const SizedBox(height: PosHomeSpec.editGapBelow),
                  _QtyControls(
                    quantity: line.quantity ?? 1,
                    onIncrement: onIncrement,
                    onDecrement: onDecrement,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  final String imageUrl;

  const _Thumb({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(PosHomeSpec.lineThumbRadius),
      child: SizedBox(
        width: PosHomeSpec.lineThumbWidth,
        height: PosHomeSpec.lineThumbHeight,
        child: CustomImageWidget(
          image: imageUrl,
          width: PosHomeSpec.lineThumbWidth,
          height: PosHomeSpec.lineThumbHeight,
          fit: BoxFit.cover,
          useShimmer: true,
          cacheWidth: CustomImageWidget.kKioskThumbCacheWidth,
        ),
      ),
    );
  }
}

class _NoteRow extends StatelessWidget {
  final PosReceiptNote note;

  const _NoteRow({required this.note});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          note.included ? '+' : '-',
          style: loewRegular.copyWith(
            fontSize: PosHomeSpec.lineNoteMarkSize,
            color: PosHomeSpec.inkAlpha(0.53),
            height: PosHomeSpec.lineNoteMarkHeight,
          ),
        ),
        const SizedBox(width: PosHomeSpec.lineNoteGap),
        Expanded(
          child: Text(
            note.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: swiss721Light.copyWith(
              fontSize: PosHomeSpec.lineNoteSize,
              color: PosHomeSpec.inkAlpha(0.53),
              height: PosHomeSpec.lineNoteHeight,
            ),
          ),
        ),
      ],
    );
  }
}

class _EditButton extends StatelessWidget {
  final VoidCallback onTap;

  const _EditButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(PosHomeSpec.editRadius),
        child: Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: PosHomeSpec.editIconSize,
                height: PosHomeSpec.editIconSize,
                child: Image.asset(
                  Images.posEditPng,
                  width: PosHomeSpec.editIconSize,
                  height: PosHomeSpec.editIconSize,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    // Figma pencil PNG may be missing from a stale web
                    // AssetManifest (hot reload does not pick up new files).
                    // `edit.svg` is already in the bundle.
                    return SvgPicture.asset(
                      Images.editSvg,
                      width: PosHomeSpec.editIconSize,
                      height: PosHomeSpec.editIconSize,
                      colorFilter: const ColorFilter.mode(
                        Colors.black,
                        BlendMode.srcIn,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: PosHomeSpec.editGap),
              Text(
                'EDIT',
                style: loewBold.copyWith(
                  fontSize: PosHomeSpec.editLabelSize,
                  color: Colors.black,
                  height: 1.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QtyControls extends StatelessWidget {
  final int quantity;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  const _QtyControls({
    required this.quantity,
    required this.onIncrement,
    required this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    final bool isSingle = quantity <= 1;

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (isSingle)
          _DeleteButton(onTap: onDecrement)
        else
          _QtyChip(
            key: const Key('pos-qty-minus'),
            label: '−',
            filled: false,
            onTap: onDecrement,
          ),
        const SizedBox(width: PosHomeSpec.qtyGap),
        SizedBox(
          width: PosHomeSpec.qtyDigitWidth,
          child: Text(
            '$quantity',
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.clip,
            style: loewExtraBold.copyWith(
              fontSize: PosHomeSpec.qtyLabelSize,
              color: PosHomeSpec.ink,
              height: 24 / 20,
            ),
          ),
        ),
        const SizedBox(width: PosHomeSpec.qtyGap),
        _QtyChip(
          key: const Key('pos-qty-plus'),
          label: '+',
          filled: true,
          onTap: onIncrement,
        ),
      ],
    );
  }
}

/// Filled black `+` or outlined `−`, matching Figma qty chips (31×26, r6).
class _QtyChip extends StatelessWidget {
  final String label;
  final bool filled;
  final VoidCallback onTap;

  const _QtyChip({
    super.key,
    required this.label,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius =
        BorderRadius.circular(PosHomeSpec.qtyPlusRadius);
    return Material(
      color: filled ? Colors.black : Colors.transparent,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          width: PosHomeSpec.qtyPlusWidth,
          height: PosHomeSpec.qtyControlHeight,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: Colors.black,
              width: PosHomeSpec.qtyPlusBorder,
            ),
          ),
          child: Text(
            label,
            style: loewExtraBold.copyWith(
              fontSize: PosHomeSpec.qtyLabelSize,
              color: filled ? PosHomeSpec.plusLabel : PosHomeSpec.ink,
              height: 1.0,
            ),
          ),
        ),
      ),
    );
  }
}

/// Trash control for qty == 1.
///
/// Inlined from Figma node 1641:2168 so Flutter Web does not depend on a
/// freshly rebuilt AssetManifest (the empty left control users saw was a
/// missing `pos_trash.svg` in the web bundle).
class _DeleteButton extends StatelessWidget {
  static const String _trashSvg = '''
<svg width="26" height="26" viewBox="0 0 26 26" fill="none" xmlns="http://www.w3.org/2000/svg">
<path d="M8.28571 19.6111C8.28571 20.65 8.99286 21.5 9.85714 21.5H16.1429C17.0071 21.5 17.7143 20.65 17.7143 19.6111V10.1667C17.7143 9.12778 17.0071 8.27778 16.1429 8.27778H9.85714C8.99286 8.27778 8.28571 9.12778 8.28571 10.1667V19.6111ZM17.7143 5.44444H15.75L15.1921 4.77389C15.0507 4.60389 14.8464 4.5 14.6421 4.5H11.3579C11.1536 4.5 10.9493 4.60389 10.8079 4.77389L10.25 5.44444H8.28571C7.85357 5.44444 7.5 5.86944 7.5 6.38889C7.5 6.90833 7.85357 7.33333 8.28571 7.33333H17.7143C18.1464 7.33333 18.5 6.90833 18.5 6.38889C18.5 5.86944 18.1464 5.44444 17.7143 5.44444Z" fill="black"/>
</svg>
''';

  final VoidCallback onTap;

  const _DeleteButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const Key('pos-qty-delete'),
      width: PosHomeSpec.qtyMinusWidth,
      height: PosHomeSpec.qtyControlHeight,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Center(
            child: SizedBox(
              width: PosHomeSpec.qtyTrashSize,
              height: PosHomeSpec.qtyTrashSize,
              child: SvgPicture.string(
                _trashSvg,
                width: PosHomeSpec.qtyTrashSize,
                height: PosHomeSpec.qtyTrashSize,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
