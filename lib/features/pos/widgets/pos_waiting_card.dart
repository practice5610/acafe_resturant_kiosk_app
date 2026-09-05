import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_payment_spec.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter/material.dart';

/// The card shown while a card payment sits with the terminal —
/// Figma `overlay-content-area` / `waiting-card` (**1641:4203**).
///
/// Takes over the payment screen's content area rather than being a route of
/// its own: the sale has not moved anywhere, it is the same ticket waiting on
/// a customer to present a card, and pushing a route would put a Back button on
/// a state that must only be left by paying or cancelling.
class PosWaitingCard extends StatelessWidget {
  /// The sale total. Passed in, never recomputed — this is the same `total`
  /// the summary and the Confirm button were reading a moment ago.
  final double amountDue;

  /// Null while a cancel is already in flight, which disables the button.
  final VoidCallback? onCancel;

  /// True once the operator has asked to cancel and the terminal has not yet
  /// answered. See [PosWaitingCard] docs on why that gap exists.
  final bool cancelling;

  const PosWaitingCard({
    super.key,
    required this.amountDue,
    required this.onCancel,
    this.cancelling = false,
  });

  @override
  Widget build(BuildContext context) {
    return PosPaymentStatusCard(
      indicator: const PosWaitingDots(),
      heading: 'Waiting for payment...',
      amountDue: amountDue,
      actions: [
        Expanded(
          child: PosPaymentCardButton(
            label: cancelling ? 'Cancelling...' : 'Cancel Transaction',
            onTap: onCancel,
          ),
        ),
      ],
    );
  }
}

/// The shell both payment-status cards are drawn on — Figma `waiting-card`
/// (**1641:4204**) and `declined-card` (**1641:4221**).
///
/// The two frames are the same card: 560 wide, `r24`, a 1.5px `#EAE5D5`
/// border, one drop shadow, 36px between every section, and the same white
/// amount box above the same divider. They disagree on exactly two things — the
/// element at the top, and how many buttons sit at the bottom. Those are the
/// two parameters.
class PosPaymentStatusCard extends StatelessWidget {
  /// The dots, or the error mark. Whatever the state leads with.
  final Widget indicator;
  final String heading;

  /// The sale total. Passed in, never recomputed — this is the same `total`
  /// the summary and the Confirm button were reading a moment ago, and it must
  /// read identically across every state of one payment attempt.
  final double amountDue;

  /// Laid out in a row with [PosPaymentSpec.declinedActionsGap] between them.
  /// Each should be `Expanded` so a single button fills the card and a pair
  /// splits it evenly, as both frames draw them.
  final List<Widget> actions;

  const PosPaymentStatusCard({
    super.key,
    required this.indicator,
    required this.heading,
    required this.amountDue,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        // A 560px card on a short window still has to reach its buttons.
        padding: const EdgeInsets.all(PosPaymentSpec.contentPadding),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: PosPaymentSpec.waitCardWidth,
            ),
            child: Container(
              padding: const EdgeInsets.fromLTRB(
                PosPaymentSpec.waitCardPaddingH,
                PosPaymentSpec.waitCardPaddingTop,
                PosPaymentSpec.waitCardPaddingH,
                PosPaymentSpec.waitCardPaddingBottom,
              ),
              decoration: BoxDecoration(
                color: PosHomeSpec.panelBg,
                borderRadius:
                    BorderRadius.circular(PosPaymentSpec.waitCardRadius),
                border: Border.all(
                  color: PosPaymentSpec.waitCardBorderColor,
                  width: PosPaymentSpec.waitCardBorder,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: PosPaymentSpec.waitCardShadow,
                    offset: PosPaymentSpec.waitCardShadowOffset,
                    blurRadius: PosPaymentSpec.waitCardShadowBlur,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(child: indicator),
                  const SizedBox(height: PosPaymentSpec.waitCardGap),
                  Text(
                    heading,
                    textAlign: TextAlign.center,
                    style: loewExtraBold.copyWith(
                      fontSize: PosPaymentSpec.waitHeadingSize,
                      height: PosPaymentSpec.waitHeadingHeight,
                      color: PosHomeSpec.ink,
                    ),
                  ),
                  const SizedBox(height: PosPaymentSpec.waitCardGap),
                  _AmountDue(amount: amountDue),
                  const SizedBox(height: PosPaymentSpec.waitCardGap),
                  const ColoredBox(
                    color: PosPaymentSpec.waitCardBorderColor,
                    child: SizedBox(height: 1, width: double.infinity),
                  ),
                  const SizedBox(height: PosPaymentSpec.waitCardGap),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (int i = 0; i < actions.length; i++) ...[
                        if (i > 0)
                          const SizedBox(
                              width: PosPaymentSpec.declinedActionsGap),
                        actions[i],
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// `center-dots` (1641:4206) — three dots at 100 / 60 / 30 percent, pulsing in
/// sequence.
///
/// Its own [StatefulWidget] with the ticker inside, so the 60fps rebuild is
/// scoped to 42x10 pixels. Driving this from the payment screen's state would
/// rebuild the receipt, the totals and the nav bar on every frame.
///
/// Not `CustomLoaderWidget`: that is a twelve-dot radial spinner, a different
/// shape entirely.
class PosWaitingDots extends StatefulWidget {
  const PosWaitingDots({super.key});

  @override
  State<PosWaitingDots> createState() => _PosWaitingDotsState();
}

class _PosWaitingDotsState extends State<PosWaitingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Each dot rides the same loop a third of a cycle apart, so the bright spot
  /// travels left to right. The resting opacities from Figma are the floor:
  /// the animation lifts a dot toward 1.0 and lets it fall back, rather than
  /// fading all three to nothing and losing the design's static reading.
  double _opacityFor(int index, double t) {
    final double phase = (t - index / 3) % 1.0;
    // Short bright pulse, long settle — a sine would spend too long at full.
    final double lift = phase < 0.5 ? (1 - (phase * 4 - 1).abs()).clamp(0, 1) : 0;
    final double rest = PosPaymentSpec.waitDotOpacities[index];
    return rest + (1 - rest) * lift;
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int i = 0; i < PosPaymentSpec.waitDotOpacities.length;
                  i++) ...[
                if (i > 0) const SizedBox(width: PosPaymentSpec.waitDotGap),
                Opacity(
                  opacity: _opacityFor(i, _controller.value),
                  child: Container(
                    width: PosPaymentSpec.waitDotSize,
                    height: PosPaymentSpec.waitDotSize,
                    decoration: const BoxDecoration(
                      color: PosPaymentSpec.waitDotColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// `total-display-container` (1641:4212).
class _AmountDue extends StatelessWidget {
  final double amount;

  const _AmountDue({required this.amount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: PosPaymentSpec.waitAmountBoxPaddingH,
        vertical: PosPaymentSpec.waitAmountBoxPaddingV,
      ),
      decoration: BoxDecoration(
        color: PosHomeSpec.tileBg,
        borderRadius:
            BorderRadius.circular(PosPaymentSpec.waitAmountBoxRadius),
        border: Border.all(
          color: PosPaymentSpec.waitCardBorderColor,
          width: PosPaymentSpec.waitAmountBoxBorder,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'AMOUNT DUE',
            textAlign: TextAlign.center,
            style: loewBold.copyWith(
              fontSize: PosPaymentSpec.waitAmountLabelSize,
              height: PosPaymentSpec.waitAmountLabelHeight,
              letterSpacing: PosPaymentSpec.waitAmountLabelTracking,
              color: PosHomeSpec.inkAlpha(
                  PosPaymentSpec.waitAmountLabelOpacity),
            ),
          ),
          const SizedBox(height: PosPaymentSpec.waitAmountLabelGap),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              PosHomeSpec.formatPrice(amount, padZero: false),
              maxLines: 1,
              style: loewExtraBold.copyWith(
                fontSize: PosPaymentSpec.waitAmountSize,
                height: PosPaymentSpec.waitAmountHeight,
                color: PosHomeSpec.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A card action — Figma `cancel-button` (1641:4216 / 1641:4231) and
/// `try-again-button` (1641:4233).
///
/// One widget for both treatments because the frames draw one box: identical
/// padding, radius and 1.5px border, with [filled] swapping the fill and the
/// label colour. A null [onTap] renders the disabled state.
class PosPaymentCardButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  /// True for the dark primary (`Try Again`), false for the outlined secondary
  /// (`Cancel` / `Cancel Transaction`).
  final bool filled;

  const PosPaymentCardButton({
    super.key,
    required this.label,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius =
        BorderRadius.circular(PosPaymentSpec.waitCancelRadius);
    final bool enabled = onTap != null;

    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Material(
        color: filled ? PosHomeSpec.ink : PosHomeSpec.tileBg,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Container(
            padding: const EdgeInsets.symmetric(
                vertical: PosPaymentSpec.waitCancelPaddingV),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                color: PosHomeSpec.ink,
                width: PosPaymentSpec.waitCancelBorder,
              ),
            ),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: loewBold.copyWith(
                fontSize: PosPaymentSpec.waitCancelLabelSize,
                height: PosPaymentSpec.waitCancelLabelHeight,
                color: filled ? Colors.white : PosHomeSpec.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
