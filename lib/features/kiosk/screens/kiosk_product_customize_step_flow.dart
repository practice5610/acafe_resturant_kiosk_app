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

/// Artboard height of Version B's own chrome: the top inset plus the progress
/// bar (a 110px circle over a 30px label, whichever is taller than the 120px
/// back button beside it). Version A has no equivalent, so it is added to the
/// shared page height before the scale is chosen — otherwise the bar would eat
/// the room the header was measured for.
const double _kStepProgressArtboardHeight =
    KioskCustomizeSpec.backButtonTop + 156;

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
  final ValueChanged<CartModel>? onConfigured;
  const KioskProductCustomizeStepScreen({
    super.key,
    required this.product,
    this.cartIndex,
    this.initialInstruction,
    this.replaceOtherProductLines = false,
    this.onConfigured,
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
  ValueChanged<CartModel>? get onConfigured => widget.onConfigured;

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
    // Left the flow without the line reaching the cart — unless an admin
    // live-switched Ordering Experience and this host remounted the other flow.
    // `step` records WHERE they dropped out for the drop-off-by-step report.
    final bool suppress = KioskCustomizeExperienceHost.suppressAbandonOnce;
    if (suppress) {
      KioskCustomizeExperienceHost.suppressAbandonOnce = false;
    }
    if (!_completed && !suppress && _steps.isNotEmpty) {
      KioskCustomizeAnalytics.instance.track(
        KioskCustomizeEvent.customizationAbandoned,
        experience: _lastExperience,
        productId: product.id,
        step:
            _steps[_stepIndex.value.clamp(0, _steps.length - 1)].analyticsName,
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
        onConfigured: onConfigured,
      );
    }

    return Scaffold(
      backgroundColor: KioskUI.pageBg,
      body: SafeArea(
        child: Consumer<ProductProvider>(
          builder: (context, productProvider, _) {
            return LayoutBuilder(
              builder: (context, constraints) {
                // See [_KioskCustomizeActions._lastExperience].
                _lastExperience = experienceOf(context);
                final Size window =
                    Size(constraints.maxWidth, constraints.maxHeight);
                final bool landscape = window.width > window.height;

                // ONE STACK IN EVERY ORIENTATION, exactly as Version A does:
                // progress bar, product header, the step's panels, action bar.
                // The old landscape split (header left, step right) read as two
                // half-finished screens on anything between a tablet and a 4K
                // panel, and it put the product's photo and its question in
                // separate places for the customer to join up.
                //
                // A wide window centres that stack in a column, and the scale
                // is measured against THAT width — the page has to fit the
                // column it is drawn in, not the glass.
                final bool hasDescription =
                    kioskProductDescription(product).isNotEmpty;
                // Same scale rule as Version A, plus the progress bar's own
                // height: the bar costs vertical room the hero would otherwise
                // use, so the page has to be measured with it included.
                //
                // ONE step is on screen at a time, so the page only has to be
                // as tall as the TALLEST step this product actually has —
                // measured per step, not assumed to be the milk one. A product
                // whose only question is add-ons has no milk step at all, and
                // budgeting that step's (absent) panels left the add-on grid
                // with no height to be laid out in.
                double stepArtboard(_CustomizeStep step,
                        {required bool split}) =>
                    kioskCustomizeArtboardHeight(
                      hasDescription: hasDescription,
                      variationPanels: step == _CustomizeStep.milks
                          ? (_sections.size.isEmpty ? 0 : 1) +
                              _sections.dietary.length
                          : 0,
                      hasAddOns: step == _CustomizeStep.addOns,
                      hasVessel: step == _CustomizeStep.cupOrCan,
                      // `landscape: true` is the OLD two-column budget — the
                      // taller of the header and the panels, not the two
                      // stacked. Only the hero still asks for it; see below.
                      landscape: split,
                    ) +
                    _kStepProgressArtboardHeight;

                final double artboard = _steps
                    .map((step) => stepArtboard(step, split: false))
                    .reduce(math.max);
                final double band =
                    math.min(window.width, kKioskContentMaxWidth);
                // The column is the shared reading column, widened by whatever
                // the window's HEIGHT can pay for: a page this many artboard px
                // tall on a 2160px panel affords `2572 * (2160 / artboard)` of
                // width and still fits, and taking that is what stops a 4K
                // kiosk drawing a small page in a sea of beige. Height is what
                // this screen is short of, so height is what sets the width.
                final double heightFit = KioskCustomizeSpec.artboardWidth *
                    (window.height / artboard);
                final double column = math.min(
                  band,
                  math.max(
                    kioskReadingColumnWidth(width: band, landscape: landscape),
                    heightFit,
                  ),
                );
                final Size viewport = Size(column, window.height);
                // Shared with Version A: the photo matches a no-options product
                // on this window so a step with milks/add-ons does not shrink
                // it. See [kioskCustomizeResolvedHeroFactor].
                final double heroTarget =
                    kioskCustomizeHeroTargetArtboard(
                        hasDescription: hasDescription);
                final double heroFactor = kioskCustomizeResolvedHeroFactor(
                  viewport: viewport,
                  artboardHeight: artboard,
                  hasDescription: hasDescription,
                  targetArtboardHeight: heroTarget,
                  targetSplitArtboardHeight: kioskCustomizeArtboardHeight(
                    hasDescription: hasDescription,
                    variationPanels: 0,
                    hasAddOns: false,
                    hasVessel: false,
                    landscape: true,
                  ),
                );
                // The page is then re-measured WITH that hero, so the height
                // the photo takes is height the page knew about: the rest of
                // the screen gives up a few per cent of scale and the step's
                // panels keep their room, instead of the taller photo pushing
                // them under the action bar to be scrolled for.
                final double s = kioskCustomizeScale(
                  viewport: viewport,
                  artboardHeight: kioskCustomizeArtboardWithHero(
                    artboardHeight: artboard,
                    heroFactor: heroFactor,
                  ),
                );
                final double gutter = KioskCustomizeSpec.gutter * s;

                return KioskCenteredContent(
                  maxWidth: column,
                  child: Column(
                    children: [
                      // Progress bar + back button. Rebuilt on step change,
                      // which is exactly what it displays.
                      Padding(
                        padding: EdgeInsets.fromLTRB(gutter,
                            KioskCustomizeSpec.backButtonTop * s, gutter, 0),
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
                        padding: EdgeInsets.symmetric(horizontal: gutter),
                        child: _Header(
                          s: s,
                          heroFactor: heroFactor,
                          product: product,
                          productProvider: productProvider,
                          showBackButton: false,
                        ),
                      ),
                      SizedBox(height: KioskCustomizeSpec.headerToPanels * s),
                      // The step body takes the remaining height. Only this and
                      // the action bar below react to a step change.
                      Expanded(
                        child: ValueListenableBuilder<int>(
                          valueListenable: _stepIndex,
                          builder: (context, current, _) => _stepBody(
                            s,
                            _steps[current],
                            productProvider,
                            padding: EdgeInsets.symmetric(horizontal: gutter),
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
  /// [padding] is handed to the step rather than wrapped around it: a
  /// [_FittedColumn] applies it INSIDE its scroll view, which keeps the scroll
  /// thumb out in the page gutter instead of over the panel's right edge.
  Widget _stepBody(
      double s, _CustomizeStep step, ProductProvider productProvider,
      {EdgeInsets padding = EdgeInsets.zero}) {
    switch (step) {
      case _CustomizeStep.milks:
        final Widget? allergenNotice =
            KioskAllergenNotice.maybe(s: s, product: product);
        final List<Widget> panels = [
          // Above Size, exactly as in Version A — the two flows are an A/B
          // switch on presentation, so a disclosure must not depend on which
          // one the device happens to be running.
          if (allergenNotice != null) allergenNotice,
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
        ];
        // One step's worth of panels is short — a Size row, or a couple of
        // dietary groups — while the body is given the whole page between the
        // progress bar and the action bar. Top-aligned that stranded the panel
        // against the bar with the rest of the screen empty; centred it sits
        // in its own space. See [_FittedColumn].
        return _FittedColumn(
          s: s,
          padding: padding,
          children: [
            for (int i = 0; i < panels.length; i++) ...[
              if (i > 0) SizedBox(height: KioskCustomizeSpec.panelGap * s),
              panels[i],
            ],
          ],
        );
      case _CustomizeStep.addOns:
        // The panel is told the height it may take (`maxHeight`) rather than
        // being left to fill it. It keeps the whole rows that fit — two of
        // them on a large landscape display — and scrolls the remainder inside
        // itself, beside the design's own indicator. What it does not use comes
        // back here, and [_FittedColumn] centres it, which is where the space
        // above and below the panel comes from.
        //
        // Filling the column was the Version A behaviour and the wrong one
        // here: it stretched the panel the full height of the screen and its
        // scroller then cut a row of cards in half at the fold. Version A can
        // fill because its panel sits under a header and above cup/can in one
        // long page, where the leftover height has nowhere better to go.
        return LayoutBuilder(
          builder: (context, constraints) => _FittedColumn(
            s: s,
            padding: padding,
            children: [
              _AddOnsSection(
                s: s,
                product: product,
                productProvider: productProvider,
                maxHeight: constraints.maxHeight.isFinite
                    ? constraints.maxHeight - padding.vertical
                    : null,
              ),
            ],
          ),
        );
      case _CustomizeStep.cupOrCan:
        return _FittedColumn(
          s: s,
          padding: padding,
          children: [
            for (int i = 0; i < _sections.cupCan.length; i++) ...[
              if (i > 0) SizedBox(height: KioskCustomizeSpec.panelGap * s),
              _CupCanSection(
                s: s,
                variation: _sections.cupCan[i].value,
                variationIndex: _sections.cupCan[i].key,
                product: product,
                productProvider: productProvider,
              ),
            ],
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
        KioskBackButton(
          size: KioskCustomizeSpec.backButton * s,
          borderWidth: _border(KioskCustomizeSpec.backButtonBorder, s),
          iconSize: KioskCustomizeSpec.backButtonIcon * s,
          onTap: onBack,
          fallback: RouterHelper.getKioskMenuRoute,
        ),
        SizedBox(width: 48 * s),
        Expanded(
          child:
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: row),
        ),
        // Balances the back button so the bar stays optically centred.
        SizedBox(width: KioskCustomizeSpec.backButton * s),
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
    final double d = 110 * s;
    final Color line = filled ? _kDarkButton : _kStepUpcoming;

    final Widget circle = Container(
      width: d,
      height: d,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? _kDarkButton : Colors.transparent,
        border: Border.all(color: line, width: _border(4, s)),
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
        SizedBox(height: 16 * s),
        Text(
          step.label(context),
          style: loewExtraBold.copyWith(
            fontSize: 30 * s,
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
    final double d = 110 * s;
    return Padding(
      // Sit on the circle's vertical centre.
      padding: EdgeInsets.only(
        top: d / 2,
        left: 20 * s,
        right: 20 * s,
      ),
      child: Container(
        height: _border(4, s),
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
      padding: EdgeInsets.fromLTRB(
        KioskCustomizeSpec.gutter * s,
        KioskCustomizeSpec.actionBarTopGap * s,
        KioskCustomizeSpec.gutter * s,
        KioskCustomizeSpec.actionBarBottomGap * s,
      ),
      child: Row(
        children: [
          Expanded(
            child: KioskCheckoutButton(
              s: s,
              filled: false,
              forceScaled: true,
              fontSize: KioskCustomizeSpec.actionLabelSize,
              label: getTranslated('cancel_item', context)?.toUpperCase() ??
                  'CANCEL ITEM',
              onTap: () => KioskNavigationHelper.popOrNavigate(
                context,
                fallback: RouterHelper.getKioskMenuRoute,
              ),
            ),
          ),
          SizedBox(width: KioskCustomizeSpec.actionGap * s),
          Expanded(
            child: KioskCheckoutButton(
              s: s,
              filled: true,
              forceScaled: true,
              fontSize: KioskCustomizeSpec.actionLabelSize,
              label: isLastStep ? addLabel : nextLabel,
              // A null onTap is what KioskCheckoutButton dims for its disabled
              // state, so an unanswered required step reads as blocked before
              // the customer even taps.
              onTap: isLastStep ? onAddToCart : (canAdvance ? onNext : null),
            ),
          ),
        ],
      ),
    );
  }
}
