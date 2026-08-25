part of 'kiosk_product_customize_sheet.dart';

// ===========================================================================
// KIOSK PRODUCT CUSTOMIZE — VERSION B: three-step flow
// ===========================================================================
// The same product, the same ProductProvider selection state, the same
// validation and the same cart write as Version A (see [_KioskCustomizeActions]) —
// only the navigation shell differs. Every section below is the *identical*
// widget Version A renders; this file just decides which one is on screen and
// draws the progress bar and the Back/Next chrome around it.
//
// Which version a kiosk gets is a back-office setting per device
// (Device Update -> Ordering Experience), read here via
// [KioskAuthProvider.orderingExperience]. See [openKioskCustomize].
// ===========================================================================

/// Colour of a step circle / connector that the customer has not reached.
const Color _kStepUpcoming = Color(0xFFB9B5A6);

/// The three questions Version B asks, in order.
enum _CustomizeStep {
  milks,
  addOns,
  cupOrCan;

  /// Label under the step circle. Falls back to English when a locale has no
  /// translation, matching how the rest of the kiosk handles missing keys.
  String label(BuildContext context) => switch (this) {
        _CustomizeStep.milks =>
          kioskTranslate(context, 'milks', 'Milks').toUpperCase(),
        _CustomizeStep.addOns =>
          kioskTranslate(context, 'add_ons', 'Add-ons').toUpperCase(),
        _CustomizeStep.cupOrCan =>
          kioskTranslate(context, 'cup_or_can', 'Cup or Can').toUpperCase(),
      };

  /// Stable wire name for analytics — never the translated label, so the
  /// back-office report groups correctly regardless of kiosk locale.
  String get analyticsName => name;

  IconData get icon => switch (this) {
        _CustomizeStep.milks => Icons.local_drink_rounded,
        _CustomizeStep.addOns => Icons.add_rounded,
        _CustomizeStep.cupOrCan => Icons.local_cafe_rounded,
      };
}

/// Version B of the customization screen: the same choices as Version A, split
/// across [_CustomizeStep]s behind a clickable segmented progress bar.
class KioskProductCustomizeStepScreen extends StatefulWidget {
  final Product product;
  final int? cartIndex;
  final String? initialInstruction;

  /// See [KioskProductCustomizeScreen.replaceOtherProductLines].
  final bool replaceOtherProductLines;
  const KioskProductCustomizeStepScreen({
    super.key,
    required this.product,
    this.cartIndex,
    this.initialInstruction,
    this.replaceOtherProductLines = false,
  });

  @override
  State<KioskProductCustomizeStepScreen> createState() =>
      _KioskProductCustomizeStepScreenState();
}

class _KioskProductCustomizeStepScreenState
    extends State<KioskProductCustomizeStepScreen>
    with _KioskCustomizeActions<KioskProductCustomizeStepScreen> {
  /// See [_KioskProductCustomizeScreenState._instruction].
  String? _instruction;

  /// Which steps this product actually has. A product with no add-ons must not
  /// be shown an empty "Add-ons" step, so the flow is built from the product
  /// rather than assuming all three.
  late final List<_CustomizeStep> _steps;
  late final _CustomizeSections _sections;

  /// Current step index, as a notifier rather than setState: moving between
  /// steps must repaint the progress bar, the step body and the action bar —
  /// NOT the hero image, name and quantity stepper above them, which are
  /// identical on every step and would otherwise decode the photo again.
  final ValueNotifier<int> _stepIndex = ValueNotifier<int>(0);

  /// Highest step the customer has completed, so the progress bar knows which
  /// circles are tappable. Going back never lowers it — selections are kept, so
  /// a completed step stays completed.
  final ValueNotifier<int> _furthestStep = ValueNotifier<int>(0);

  @override
  Product get product => widget.product;
  @override
  int? get cartIndex => widget.cartIndex;
  @override
  String? get instruction => _instruction;
  @override
  bool get replaceOtherProductLines => widget.replaceOtherProductLines;

  @override
  void initState() {
    super.initState();
    final String initial = widget.initialInstruction?.trim() ?? '';
    _instruction = initial.isEmpty ? null : initial;

    _sections = _CustomizeSections.of(product);
    _steps = [
      if (_sections.hasMilkStep) _CustomizeStep.milks,
      if (product.effectiveAddOnGroups.isNotEmpty) _CustomizeStep.addOns,
      if (_sections.cupCan.isNotEmpty) _CustomizeStep.cupOrCan,
    ];

    // After the first frame: `track` reads providers. Skipped entirely when
    // there are no steps — [build] then delegates to Version A, which emits its
    // own started/abandoned pair, and double-counting would corrupt the report.
    if (_steps.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      track(context, KioskCustomizeEvent.customizationStarted);
      precacheSuccessAnimation(context);
      track(context, KioskCustomizeEvent.stepViewed,
          step: _steps.first.analyticsName);
    });
  }

  @override
  void dispose() {
    // Left the flow without the line reaching the cart. `step` records WHERE
    // they dropped out, which is the drop-off-by-step figure in the report.
    if (!_completed && _steps.isNotEmpty) {
      KioskCustomizeAnalytics.instance.track(
        KioskCustomizeEvent.customizationAbandoned,
        experience: _lastExperience,
        productId: product.id,
        step: _steps[_stepIndex.value.clamp(0, _steps.length - 1)].analyticsName,
      );
    }
    unawaited(KioskCustomizeAnalytics.instance.flush());
    _stepIndex.dispose();
    _furthestStep.dispose();
    super.dispose();
  }

  /// Variation indexes owned by [step], so Next gates on that step's questions
  /// only. Add-ons have no variation indexes — they validate through
  /// [_validateAddOnGroups] instead.
  Iterable<int> _variationIndexesFor(_CustomizeStep step) => switch (step) {
        _CustomizeStep.milks => [
            ..._sections.size.map((e) => e.key),
            ..._sections.dietary.map((e) => e.key),
          ],
        _CustomizeStep.cupOrCan => _sections.cupCan.map((e) => e.key),
        _CustomizeStep.addOns => const <int>[],
      };

  /// Whether [step]'s required questions are answered.
  ///
  /// [silent] is true when this only decides if Next looks enabled — showing a
  /// snackbar on every rebuild would fire on each add-on tap.
  bool _isStepSatisfied(
    BuildContext context,
    ProductProvider productProvider,
    _CustomizeStep step, {
    bool silent = true,
  }) {
    if (step == _CustomizeStep.addOns) {
      return _validateAddOnGroups(context, productProvider, silent: silent);
    }
    return _validateVariations(
      context,
      productProvider,
      _variationIndexesFor(step),
      silent: silent,
    );
  }

  void _goToStep(int index) {
    if (index < 0 || index >= _steps.length) return;
    _stepIndex.value = index;
    if (index > _furthestStep.value) _furthestStep.value = index;
  }

  /// Forward navigation. Blocked — with a message — while the current step's
  /// required questions are unanswered, so a customer can never skip ahead.
  void _next(BuildContext context, ProductProvider productProvider) {
    final int index = _stepIndex.value;
    if (!_isStepSatisfied(context, productProvider, _steps[index],
        silent: false)) {
      return;
    }
    track(context, KioskCustomizeEvent.stepCompleted,
        step: _steps[index].analyticsName);
    _goToStep(index + 1);
    if (index + 1 < _steps.length) {
      track(context, KioskCustomizeEvent.stepViewed,
          step: _steps[index + 1].analyticsName);
    }
  }

  /// Back button behaviour: step back through the flow first, and only leave
  /// the screen from the first step — otherwise the hardware/undo back gesture
  /// would drop the whole customization from step 3.
  void _back(BuildContext context) {
    if (_stepIndex.value > 0) {
      _stepIndex.value = _stepIndex.value - 1;
      track(context, KioskCustomizeEvent.stepViewed,
          step: _steps[_stepIndex.value].analyticsName);
      return;
    }
    KioskNavigationHelper.popOrNavigate(
      context,
      fallback: RouterHelper.getKioskMenuRoute,
    );
  }

  @override
  Widget build(BuildContext context) {
    // A product with nothing to ask has no steps to show; fall back to the
    // single-screen version rather than rendering an empty shell.
    if (_steps.isEmpty) {
      return KioskProductCustomizeScreen(
        product: product,
        cartIndex: cartIndex,
        initialInstruction: _instruction,
        replaceOtherProductLines: replaceOtherProductLines,
      );
    }

    return Scaffold(
      backgroundColor: KioskUI.pageBg,
      body: SafeArea(
        child: Consumer<ProductProvider>(
          builder: (context, productProvider, _) {
            return LayoutBuilder(
              builder: (context, constraints) {
                final double s = KioskResponsive.scale(constraints.maxWidth);
                // See [_KioskCustomizeActions._lastExperience].
                _lastExperience = experienceOf(context);
                // Same rule as Version A, minus the progress bar's own height:
                // the bar costs vertical room the hero would otherwise use, so
                // the compact header kicks in slightly sooner here.
                final bool compactHeader =
                    constraints.maxHeight < constraints.maxWidth * 1.45 ||
                        constraints.maxHeight < _kFullHeroMinViewport;

                return KioskCenteredContent(
                  child: Column(
                    children: [
                      // Progress bar + back button. Rebuilt on step change,
                      // which is exactly what it displays.
                      Padding(
                        padding: EdgeInsets.fromLTRB(86 * s, 30 * s, 86 * s, 0),
                        child: ValueListenableBuilder<int>(
                          valueListenable: _stepIndex,
                          builder: (context, current, _) =>
                              ValueListenableBuilder<int>(
                            valueListenable: _furthestStep,
                            builder: (context, furthest, _) => _StepProgressBar(
                              s: s,
                              steps: _steps,
                              currentStep: current,
                              furthestStep: furthest,
                              onStepTap: (i) {
                                _goToStep(i);
                                track(context, KioskCustomizeEvent.stepViewed,
                                    step: _steps[i].analyticsName);
                              },
                              onBack: () => _back(context),
                            ),
                          ),
                        ),
                      ),
                      // Identity block — identical on every step, so it sits
                      // OUTSIDE the step listeners and is never rebuilt by a
                      // step change or an add-on tap.
                      Padding(
                        padding: EdgeInsets.fromLTRB(86 * s, 12 * s, 86 * s, 0),
                        child: compactHeader
                            ? _CompactHeader(
                                s: s,
                                viewportHeight: constraints.maxHeight,
                                product: product,
                                productProvider: productProvider,
                                showBackButton: false,
                              )
                            : _Header(
                                s: s,
                                product: product,
                                productProvider: productProvider,
                                showBackButton: false,
                              ),
                      ),
                      // The step body takes the remaining height. Only this and
                      // the action bar below react to a step change.
                      Expanded(
                        child: ValueListenableBuilder<int>(
                          valueListenable: _stepIndex,
                          builder: (context, current, _) => Padding(
                            padding: EdgeInsets.symmetric(horizontal: 86 * s),
                            child: _stepBody(
                                s, _steps[current], productProvider),
                          ),
                        ),
                      ),
                      ValueListenableBuilder<int>(
                        valueListenable: _stepIndex,
                        builder: (context, current, _) => _StepActionBar(
                          s: s,
                          product: product,
                          productProvider: productProvider,
                          isLastStep: current == _steps.length - 1,
                          canAdvance: _isStepSatisfied(
                              context, productProvider, _steps[current]),
                          onNext: () => _next(context, productProvider),
                          onAddToCart: () =>
                              _addToCart(context, productProvider),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  /// The body of one step — the very same section widgets Version A stacks.
  Widget _stepBody(
      double s, _CustomizeStep step, ProductProvider productProvider) {
    switch (step) {
      case _CustomizeStep.milks:
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_sections.size.isNotEmpty)
                _SizeOptionsPanel(
                  s: s,
                  entries: _sections.size,
                  product: product,
                  productProvider: productProvider,
                ),
              for (final entry in _sections.dietary)
                _VariationSection(
                  s: s,
                  variation: entry.value,
                  variationIndex: entry.key,
                  product: product,
                  productProvider: productProvider,
                ),
            ],
          ),
        );
      case _CustomizeStep.addOns:
        return _AddOnsSection(
          s: s,
          product: product,
          productProvider: productProvider,
        );
      case _CustomizeStep.cupOrCan:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            for (final entry in _sections.cupCan)
              _CupCanSection(
                s: s,
                variation: entry.value,
                variationIndex: entry.key,
                product: product,
                productProvider: productProvider,
              ),
          ],
        );
    }
  }
}

/// Segmented progress bar: circles joined by a line, one per [_CustomizeStep].
///
/// Completed circles are tappable and jump straight back to that step with
/// every selection intact. The current step and any step the customer has not
/// reached are inert — forward navigation only ever happens through Next, which
/// is what enforces the required questions.
class _StepProgressBar extends StatelessWidget {
  final double s;
  final List<_CustomizeStep> steps;
  final int currentStep;
  final int furthestStep;
  final ValueChanged<int> onStepTap;
  final VoidCallback onBack;
  const _StepProgressBar({
    required this.s,
    required this.steps,
    required this.currentStep,
    required this.furthestStep,
    required this.onStepTap,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final List<Widget> row = [];
    for (int i = 0; i < steps.length; i++) {
      row.add(
        _StepCircle(
          s: s,
          step: steps[i],
          isCurrent: i == currentStep,
          // Completed = behind the customer's furthest point AND not where they
          // are standing. Only these accept a tap.
          isCompleted: i < furthestStep && i != currentStep,
          onTap: (i < furthestStep && i != currentStep)
              ? () => onStepTap(i)
              : null,
        ),
      );
      if (i < steps.length - 1) {
        row.add(Expanded(
          child: _StepConnector(s: s, filled: i < currentStep),
        ));
      }
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        KioskBackButton.scaled(
          s: s,
          size: 120,
          border: 2,
          icon: 50,
          onTap: onBack,
          fallback: RouterHelper.getKioskMenuRoute,
        ),
        SizedBox(width: 48 * s),
        Expanded(
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: row),
        ),
        // Balances the back button so the bar stays optically centred.
        SizedBox(width: 120 * s),
      ],
    );
  }
}

class _StepCircle extends StatelessWidget {
  final double s;
  final _CustomizeStep step;
  final bool isCurrent;
  final bool isCompleted;
  final VoidCallback? onTap;
  const _StepCircle({
    required this.s,
    required this.step,
    required this.isCurrent,
    required this.isCompleted,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool filled = isCurrent || isCompleted;
    final double d = (110 * s).clamp(38.0, 110.0);
    final Color line = filled ? _kDarkButton : _kStepUpcoming;

    final Widget circle = Container(
      width: d,
      height: d,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? _kDarkButton : Colors.transparent,
        border: Border.all(color: line, width: (4 * s).clamp(1.5, 4.0)),
      ),
      child: Icon(
        step.icon,
        size: d * 0.5,
        color: filled ? _kCreamText : _kStepUpcoming,
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Only completed circles take a tap; the rest have no callback, so they
        // also get no ripple and no pointer cursor.
        onTap == null
            ? circle
            : Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: KioskTap(onTap: onTap, child: circle),
              ),
        SizedBox(height: (16 * s).clamp(6.0, 16.0)),
        Text(
          step.label(context),
          style: loewExtraBold.copyWith(
            fontSize: (30 * s).clamp(10.0, 30.0),
            height: 1.0,
            // An unreached step's label sits back with its circle.
            color: filled ? Colors.black : _kStepUpcoming,
          ),
        ),
      ],
    );
  }
}

class _StepConnector extends StatelessWidget {
  final double s;
  final bool filled;
  const _StepConnector({required this.s, required this.filled});

  @override
  Widget build(BuildContext context) {
    final double d = (110 * s).clamp(38.0, 110.0);
    return Padding(
      // Sit on the circle's vertical centre.
      padding: EdgeInsets.only(
        top: d / 2,
        left: (20 * s).clamp(8.0, 20.0),
        right: (20 * s).clamp(8.0, 20.0),
      ),
      child: Container(
        height: (4 * s).clamp(1.5, 4.0),
        color: filled ? _kDarkButton : _kStepUpcoming,
      ),
    );
  }
}

/// Version B's bottom bar: Cancel Item always, then Next (steps 1-2) or
/// Add to Cart with the live total (last step) — the same button widget and the
/// same total calculation Version A's [_ActionBar] uses.
class _StepActionBar extends StatelessWidget {
  final double s;
  final Product product;
  final ProductProvider productProvider;
  final bool isLastStep;
  final bool canAdvance;
  final VoidCallback onNext;
  final VoidCallback onAddToCart;
  const _StepActionBar({
    required this.s,
    required this.product,
    required this.productProvider,
    required this.isLastStep,
    required this.canAdvance,
    required this.onNext,
    required this.onAddToCart,
  });

  @override
  Widget build(BuildContext context) {
    final double total = kioskLineTotal(buildKioskCartModel(context, product));
    final String addLabel =
        '${getTranslated('add_to_cart', context)?.toUpperCase() ?? 'ADD TO CART'}'
        '  ${PriceConverterHelper.convertPrice(total)}';
    final String nextLabel =
        getTranslated('next', context)?.toUpperCase() ?? 'NEXT';

    return Padding(
      padding: EdgeInsets.fromLTRB(86 * s, 16 * s, 86 * s, 24 * s),
      child: Row(
        children: [
          Expanded(
            child: KioskCheckoutButton(
              s: s,
              filled: false,
              fontSize: 54,
              label: getTranslated('cancel_item', context)?.toUpperCase() ??
                  'CANCEL ITEM',
              onTap: () => KioskNavigationHelper.popOrNavigate(
                context,
                fallback: RouterHelper.getKioskMenuRoute,
              ),
            ),
          ),
          SizedBox(width: 28 * s),
          Expanded(
            child: KioskCheckoutButton(
              s: s,
              filled: true,
              fontSize: 54,
              label: isLastStep ? addLabel : nextLabel,
              // A null onTap is what KioskCheckoutButton dims for its disabled
              // state, so an unanswered required step reads as blocked before
              // the customer even taps.
              onTap: isLastStep
                  ? onAddToCart
                  : (canAdvance ? onNext : null),
            ),
          ),
        ],
      ),
    );
  }
}
