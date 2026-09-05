import 'package:acafe_customer/common/widgets/custom_image_widget.dart';
import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_settings_list_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_settings_spec.dart';
import 'package:acafe_customer/features/pos/widgets/pos_toggle.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter/material.dart';

/// The white card of availability rows shared by Settings → Products
/// (**1641:3975**) and Settings → Add-Ons (**1641:4088**).
///
/// Deliberately knows nothing about products, add-ons, or any provider: it is
/// handed the visible row ids and a builder. Each section keeps its own
/// `Selector` wiring, which is what preserves the "toggling one row rebuilds
/// only that row" behaviour on both screens.
class PosSettingsAvailabilityCard extends StatelessWidget {
  /// Identity of each visible row, in display order.
  final List<int> ids;

  /// First load with nothing cached — shows a spinner instead of "empty".
  final bool loading;

  /// Shown when [ids] is empty and no search is active.
  final String emptyMessage;

  /// Shown when [ids] is empty because [query] filtered everything out.
  final String Function(String query) noMatchMessage;

  /// Current search text, used only to pick between the two empty states.
  final String query;

  /// Builds one row. [showDivider] is false for the last row (Figma draws no
  /// rule under it).
  final Widget Function(BuildContext context, int id, bool showDivider)
      rowBuilder;

  const PosSettingsAvailabilityCard({
    super.key,
    required this.ids,
    required this.loading,
    required this.emptyMessage,
    required this.noMatchMessage,
    required this.query,
    required this.rowBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(PosSettingsListSpec.cardRadius),
        border: Border.all(color: PosSettingsListSpec.cardBorder),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(PosSettingsListSpec.cardRadius),
        child: _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (loading) {
      return const Center(
        child: SizedBox(
          width: PosSettingsListSpec.spinnerSize,
          height: PosSettingsListSpec.spinnerSize,
          child: CircularProgressIndicator(
            strokeWidth: PosSettingsListSpec.spinnerStroke,
            color: PosSettingsSpec.ink,
          ),
        ),
      );
    }

    if (ids.isEmpty) {
      return Center(
        child: Padding(
          padding: PosSettingsListSpec.emptyPadding,
          child: Text(
            query.isEmpty ? emptyMessage : noMatchMessage(query),
            textAlign: TextAlign.center,
            style: loewRegular.copyWith(
              fontSize: PosSettingsSpec.subtitleSize,
              color: PosSettingsSpec.inkMuted(0.45),
            ),
          ),
        ),
      );
    }

    // Scrolls inside the card, so the settings header and sidebar stay fixed
    // no matter how large the list gets.
    return Scrollbar(
      child: ListView.builder(
        padding: EdgeInsets.zero,
        primary: false,
        itemCount: ids.length,
        itemExtent: PosSettingsListSpec.rowHeight,
        itemBuilder: (context, index) => rowBuilder(
          context,
          ids[index],
          // No rule under the last row (Figma).
          index != ids.length - 1,
        ),
      ),
    );
  }
}

/// One availability row: thumbnail · name · sub-label · price · toggle.
///
/// Purely presentational — the caller resolves the values (normally inside a
/// per-row `Selector`) and handles the toggle.
class PosSettingsAvailabilityRow extends StatelessWidget {
  final String name;

  /// Muted line under the name — a SKU on both current screens.
  final String subLabel;

  /// Absolute image URL. Empty renders the neutral placeholder tile.
  final String image;

  final double price;
  final bool available;

  /// True while a toggle is in flight; disables the switch.
  final bool busy;

  final bool showDivider;

  /// Null disables the toggle (same effect as [busy], for callers that gate on
  /// something else).
  final ValueChanged<bool>? onChanged;

  /// How a zero price reads. [PosHomeSpec.formatPrice] pads it to "00.00" by
  /// default (the POS home reserves that width); Add-Ons opts out so a free
  /// default add-on shows a plain "0.00". Defaults to the padded form so
  /// Products keeps rendering exactly as it did.
  final bool padZeroPrice;

  const PosSettingsAvailabilityRow({
    super.key,
    required this.name,
    required this.subLabel,
    required this.image,
    required this.price,
    required this.available,
    required this.showDivider,
    required this.onChanged,
    this.busy = false,
    this.padZeroPrice = true,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: showDivider
            ? const Border(
                bottom: BorderSide(color: PosSettingsListSpec.rowDivider),
              )
            : null,
      ),
      child: Padding(
        padding: PosSettingsListSpec.rowPadding,
        child: Row(
          children: [
            PosSettingsAvailabilityThumbnail(image: image),
            const SizedBox(width: PosSettingsListSpec.thumbToTextGap),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: loewBold.copyWith(
                      fontSize: PosSettingsListSpec.nameSize,
                      color: PosSettingsSpec.ink,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: PosSettingsListSpec.nameToSubGap),
                  Text(
                    subLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: loewRegular.copyWith(
                      fontSize: PosSettingsListSpec.subSize,
                      color: PosSettingsSpec.inkMuted(),
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: PosSettingsListSpec.textToPriceGap),
            Text(
              PosHomeSpec.formatPrice(price, padZero: padZeroPrice),
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: loewBold.copyWith(
                fontSize: PosSettingsListSpec.priceSize,
                color: PosSettingsSpec.ink,
                height: 1.2,
              ),
            ),
            const SizedBox(width: PosSettingsListSpec.priceToToggleGap),
            PosToggle(
              value: available,
              semanticLabel: '$name available on kiosk',
              onChanged: busy ? null : onChanged,
            ),
          ],
        ),
      ),
    );
  }
}

/// Square thumbnail with the page-background tile behind it, so a transparent
/// or missing image still reads as a deliberate slot rather than a hole.
class PosSettingsAvailabilityThumbnail extends StatelessWidget {
  final String image;

  const PosSettingsAvailabilityThumbnail({super.key, required this.image});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(PosSettingsListSpec.thumbRadius),
      child: ColoredBox(
        color: PosSettingsSpec.pageBg,
        child: SizedBox(
          width: PosSettingsListSpec.thumbSize,
          height: PosSettingsListSpec.thumbSize,
          child: CustomImageWidget(
            image: image,
            width: PosSettingsListSpec.thumbSize,
            height: PosSettingsListSpec.thumbSize,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}
