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

/// Artboard height of Version B's own chrome: the top inset plus the progress
/// bar (a 165px circle, 16px gap, 46px label) plus the choices row. Version A has
/// no equivalent, so it is added to the shared page height before the scale is
/// chosen — otherwise the bar would eat the room the header was measured for.
const double _kStepProgressArtboardHeight =
    KioskCustomizeSpec.backButtonTop + 227 + _kChoicesRowArtboard;

/// "Your Choices" row: 20px top pad + 160px thumb + 17.5px gap + 73.75px label.
const double _kChoicesRowArtboard = 271;

/// Bare allergen icon row under the hero (Figma 2305-13009 et al.): coloured
/// discs with white glyphs, matching the chip strip's disc size (`_Spec`).
const double _kAllergenDiscSize = 84;
const double _kAllergenDiscGlyph = 48;
const double _kAllergenDiscGap = 18;

/// Gap between the hero and the allergen row.
const double _kAllergenRowGap = 24;

/// Artboard height the allergen row adds to the header — the gap above it plus
/// the disc — folded into every step's budget when the row is present so the
/// single-scale math stays correct.
const double _kAllergenRowArtboard = _kAllergenRowGap + _kAllergenDiscSize;

/// Marks the subtree as Version B so shared section widgets ([_SectionPanel],
/// [_RadioDot]) draw the 2305-130xx/134xx variants without threading a flag
/// through every section constructor. Version A never inserts it.
class _StepFlowScope extends InheritedWidget {
  const _StepFlowScope({required super.child});

  static bool of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_StepFlowScope>() != null;

  @override
  bool updateShouldNotify(_StepFlowScope oldWidget) => false;
}

/// Data rule for the portrait flow (no name matching): a MULTI-select
/// variation group is an add-on list ("Extras", "Classic Toppings", "Syrup Add
/// On"... — no live product uses the add-on table), a single-select one is a
/// real choice (Iced/Hot, Size, Alternative Milk).
List<MapEntry<int, Variation>> _singleSelect(
        List<MapEntry<int, Variation>> groups) =>
    [
      for (final g in groups)
        if (g.value.isMultiSelect != true) g
    ];
List<MapEntry<int, Variation>> _multiSelect(
        List<MapEntry<int, Variation>> groups) =>
    [
      for (final g in groups)
        if (g.value.isMultiSelect == true) g
    ];

/// One screen of the portrait flow: exactly ONE option group. A phase
/// ([_CustomizeStep]) with several groups is paged through one group at a time
/// (e.g. Hojicha Latte: Iced/Hot -> Alternative Milk -> Extras -> Cup/Can).
class _StepPage {
  final _CustomizeStep step;

  /// Variation groups on this page: every Size entry together (they render as
  /// one Size panel), or exactly one dietary / cup-can group.
  final List<MapEntry<int, Variation>> variations;
  final bool isSize;

  /// The single add-on group on an add-ons page.
  final AddOnGroup? addOnGroup;

  /// A multi-select variation group shown on the ADD-ONS step as add-on cards.
  bool get isVariationAddOn =>
      step == _CustomizeStep.addOns && variations.isNotEmpty;
  const _StepPage(this.step,
      {this.variations = const [], this.isSize = false, this.addOnGroup});
}

/// The three questions Version B asks, in order.
enum _CustomizeStep {
  milks,
  addOns,
  cupOrCan;

  /// Label under the step circle. Falls back to English when a locale has no
  /// translation, matching how the rest of the kiosk handles missing keys.
  ///
  /// Step 1 holds every non-cup/can group, so its label comes from the data:
  /// exactly one group -> that group's name ("ALTERNATIVE MILK", "POFFERTJES
  /// SIZE"); several -> "OPTIONS".
  // TODO(back-office): replace with a per-category step-label field so the
  // café can name step 1 itself ("MILKS") instead of deriving it here.
  String label(BuildContext context, KioskCustomizeSections sections) =>
      switch (this) {
        _CustomizeStep.milks => () {
            final groups = [
              ...sections.size,
              ..._singleSelect(sections.dietary),
            ];
            final String name = groups.length == 1
                ? (groups.single.value.name ?? '').trim()
                : '';
            return (name.isNotEmpty
                    ? name
                    : kioskTranslate(context, 'options', 'Options'))
                .toUpperCase();
          }(),
        _CustomizeStep.addOns =>
          kioskTranslate(context, 'add_ons', 'Add-ons').toUpperCase(),
        _CustomizeStep.cupOrCan =>
          kioskTranslate(context, 'cup_or_can', 'Cup or Can').toUpperCase(),
      };

  /// The original label (landscape shell only): fixed keys, as before the
  /// portrait redesign.
  String legacyLabel(BuildContext context) => switch (this) {
        _CustomizeStep.milks =>
          kioskTranslate(context, 'variation', 'Variation').toUpperCase(),
        _CustomizeStep.addOns =>
          kioskTranslate(context, 'add_ons', 'Add-ons').toUpperCase(),
        _CustomizeStep.cupOrCan =>
          kioskTranslate(context, 'cup_or_can', 'Cup or Can').toUpperCase(),
      };

  /// Stable wire name for analytics — never the translated label, so the
  /// back-office report groups correctly regardless of kiosk locale.
  String get analyticsName => name;

  /// SVG asset for the step circle icon (null = text glyph like "+").
  String? get svgAsset => switch (this) {
        _CustomizeStep.milks => Images.stepMilksSvg,
        _CustomizeStep.addOns => null,
        _CustomizeStep.cupOrCan => Images.stepCupSvg,
      };

  /// Fallback text glyph when [svgAsset] is null.
  String get glyph => '+';
}

/// Version B of the customization screen: the same choices as Version A, split
/// across [_CustomizeStep]s behind a clickable segmented progress bar.
class KioskProductCustomizeStepScreen extends StatefulWidget {
  final Product product;
  final int? cartIndex;
  final String? initialInstruction;
  final ValueChanged<CartModel>? onConfigured;
  const KioskProductCustomizeStepScreen({
    super.key,
    required this.product,
    this.cartIndex,
    this.initialInstruction,
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
  late final KioskCustomizeSections _sections;

  /// Current step index, as a notifier rather than setState: moving between
  /// steps must repaint the progress bar, the step body and the action bar —
  /// NOT the hero image, name and quantity stepper above them, which are
  /// identical on every step and would otherwise decode the photo again.
  final ValueNotifier<int> _stepIndex = ValueNotifier<int>(0);

  /// Highest step the customer has completed, so the progress bar knows which
  /// circles are tappable. Going back never lowers it — selections are kept, so
  /// a completed step stays completed.
  final ValueNotifier<int> _furthestStep = ValueNotifier<int>(0);

  /// One page per option group, in phase order. [_stepIndex] always holds the
  /// PHASE of the current page, so the top stepper only advances when the
  /// phase changes.
  late final List<_StepPage> _pages;
  final ValueNotifier<int> _pageIndex = ValueNotifier<int>(0);

  /// Direction of the last page change, for the slide (forward = new group
  /// enters from the right).
  bool _forward = true;

  @override
  Product get product => widget.product;
  @override
  int? get cartIndex => widget.cartIndex;
  @override
  String? get instruction => _instruction;
  @override
  ValueChanged<CartModel>? get onConfigured => widget.onConfigured;

  @override
  void initState() {
    super.initState();
    final String initial = widget.initialInstruction?.trim() ?? '';
    _instruction = initial.isEmpty ? null : initial;

    _sections = KioskCustomizeSections.of(product);
    _steps = [
      if (_sections.size.isNotEmpty ||
          _singleSelect(_sections.dietary).isNotEmpty)
        _CustomizeStep.milks,
      if (product.effectiveAddOnGroups.isNotEmpty ||
          _multiSelect(_sections.dietary).isNotEmpty)
        _CustomizeStep.addOns,
      if (_sections.cupCan.isNotEmpty) _CustomizeStep.cupOrCan,
    ];
    _pages = [
      for (final step in _steps)
        ...switch (step) {
          _CustomizeStep.milks => [
              if (_sections.size.isNotEmpty)
                _StepPage(step, variations: _sections.size, isSize: true),
              for (final e in _singleSelect(_sections.dietary))
                _StepPage(step, variations: [e]),
            ],
          _CustomizeStep.addOns => [
              for (final e in _multiSelect(_sections.dietary))
                _StepPage(step, variations: [e]),
              for (final g in product.effectiveAddOnGroups)
                _StepPage(step, addOnGroup: g),
            ],
          _CustomizeStep.cupOrCan => [
              for (final e in _sections.cupCan)
                _StepPage(step, variations: [e]),
            ],
        },
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
    _pageIndex.dispose();
    super.dispose();
  }

  /// Whether [page]'s group is answered. Single-select required groups must
  /// have a pick; optional / add-on groups can be skipped.
  ///
  /// [silent] is true when this only decides if Next looks enabled — showing a
  /// snackbar on every rebuild would fire on each tap.
  bool _isPageSatisfied(
    BuildContext context,
    ProductProvider productProvider,
    _StepPage page, {
    bool silent = true,
  }) {
    if (page.addOnGroup != null) {
      return _validateAddOnGroups(context, productProvider,
          silent: silent, only: [page.addOnGroup!]);
    }
    return _validateVariations(
      context,
      productProvider,
      page.variations.map((e) => e.key),
      silent: silent,
    );
  }

  /// Moves to page [index] (one option group) and keeps the phase notifiers
  /// in step with it. Selections live in ProductProvider, so they survive.
  void _goToPage(int index) {
    if (index < 0 || index >= _pages.length) return;
    _forward = index >= _pageIndex.value;
    final int phase = _steps.indexOf(_pages[index].step);
    _pageIndex.value = index;
    _stepIndex.value = phase;
    if (phase > _furthestStep.value) _furthestStep.value = phase;
  }

  /// Jump to the FIRST group of phase [index] — the stepper circles and the
  /// "Your Choices" placeholders address phases, not groups.
  void _goToStep(int index) {
    if (index < 0 || index >= _steps.length) return;
    _goToPage(_pages.indexWhere((p) => p.step == _steps[index]));
  }

  /// Forward navigation. Blocked — with a message — while the current group's
  /// required question is unanswered, so a customer can never skip ahead.
  void _next(BuildContext context, ProductProvider productProvider) {
    final int index = _pageIndex.value;
    if (!_isPageSatisfied(context, productProvider, _pages[index],
        silent: false)) {
      return;
    }
    if (index + 1 >= _pages.length) return;
    final _CustomizeStep from = _pages[index].step;
    final _CustomizeStep to = _pages[index + 1].step;
    _goToPage(index + 1);
    if (from != to) {
      track(context, KioskCustomizeEvent.stepCompleted,
          step: from.analyticsName);
      track(context, KioskCustomizeEvent.stepViewed, step: to.analyticsName);
    }
  }

  /// Back steps to the previous GROUP (across phases); only the first group
  /// leaves the screen.
  void _back(BuildContext context) {
    final int index = _pageIndex.value;
    if (index > 0) {
      final _CustomizeStep from = _pages[index].step;
      _goToPage(index - 1);
      if (_pages[index - 1].step != from) {
        track(context, KioskCustomizeEvent.stepViewed,
            step: _pages[index - 1].step.analyticsName);
      }
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
                // The allergen icon row sits under the hero on every step, so it
                // is budgeted into every step's height (below). Present only
                // when the branch toggle is on AND the product declares one.
                final bool hasAllergenRow =
                    Provider.of<KioskAuthProvider>(context, listen: false)
                            .allergenTagEnabled &&
                        kioskProductAllergens(product).isNotEmpty;
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
                      // One group per screen, so a milks page is one panel.
                      variationPanels: step == _CustomizeStep.milks ? 1 : 0,
                      hasAddOns: step == _CustomizeStep.addOns,
                      hasVessel: step == _CustomizeStep.cupOrCan,
                      // `landscape: true` is the OLD two-column budget — the
                      // taller of the header and the panels, not the two
                      // stacked. Only the hero still asks for it; see below.
                      landscape: split,
                    ) +
                    _kStepProgressArtboardHeight +
                    (hasAllergenRow ? _kAllergenRowArtboard : 0);

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
                final double heroTarget = kioskCustomizeHeroTargetArtboard(
                    hasDescription: hasDescription);
                // Picture-less device: collapse the hero (see Version A).
                final bool showImages =
                    context.watch<KioskAuthProvider>().showImages;
                final double heroFactor = !showImages
                    ? 0.0
                    : kioskCustomizeResolvedHeroFactor(
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
                  child: _StepFlowScope(
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
                              builder: (context, furthest, _) =>
                                  _StepProgressBar(
                                s: s,
                                steps: _steps,
                                sections: _sections,
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
                            showImages: showImages,
                            product: product,
                            productProvider: productProvider,
                            showBackButton: false,
                            // Bare allergen icon row under the hero, shown on
                            // every step (Figma 2305-13009/13161/13433).
                            belowHero: hasAllergenRow
                                ? _AllergenIconRow(
                                    s: s,
                                    allergens: kioskProductAllergens(product),
                                  )
                                : null,
                            // "Your Choices" sits between the description and
                            // the quantity stepper (Figma 2305-13009 et al.).
                            // Only this listener rebuilds on a step change.
                            aboveStepper: ValueListenableBuilder<int>(
                              valueListenable: _stepIndex,
                              builder: (context, current, _) => _YourChoicesRow(
                                s: s,
                                steps: _steps,
                                currentStep: current,
                                sections: _sections,
                                product: product,
                                productProvider: productProvider,
                                onStepTap: _goToStep,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: KioskCustomizeSpec.headerToPanels * s),
                        // The step body takes the remaining height. Only this and
                        // the action bar below react to a step change.
                        // One group per screen, sliding horizontally between
                        // groups. Only this panel region animates; header,
                        // stepper and footer stay still.
                        Expanded(
                          child: ClipRect(
                            child: ValueListenableBuilder<int>(
                              valueListenable: _pageIndex,
                              builder: (context, current, _) =>
                                  AnimatedSwitcher(
                                duration: const Duration(milliseconds: 280),
                                switchInCurve: Curves.easeInOut,
                                switchOutCurve: Curves.easeInOut,
                                layoutBuilder: (currentChild, previous) =>
                                    Stack(children: [
                                  ...previous,
                                  if (currentChild != null) currentChild,
                                ]),
                                transitionBuilder: (child, animation) {
                                  final bool incoming =
                                      child.key == ValueKey<int>(current);
                                  final double from = incoming
                                      ? (_forward ? 1.0 : -1.0)
                                      : (_forward ? -1.0 : 1.0);
                                  return SlideTransition(
                                    position: Tween<Offset>(
                                      begin: Offset(from, 0),
                                      end: Offset.zero,
                                    ).animate(animation),
                                    child: child,
                                  );
                                },
                                child: KeyedSubtree(
                                  key: ValueKey<int>(current),
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: gutter),
                                    child: SizedBox.expand(
                                      child: _pageBody(
                                          s, _pages[current], productProvider),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        ValueListenableBuilder<int>(
                          valueListenable: _pageIndex,
                          builder: (context, current, _) => _StepActionBar(
                            s: s,
                            product: product,
                            productProvider: productProvider,
                            isLastStep: current == _pages.length - 1,
                            canAdvance: _isPageSatisfied(
                                context, productProvider, _pages[current]),
                            onNext: () => _next(context, productProvider),
                            onAddToCart: () =>
                                _addToCart(context, productProvider),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  /// The ONE group of [page], as a panel that fills the slot between header
  /// and footer (Figma 2305-13009/13161/13433) and scrolls inside itself.
  Widget _pageBody(double s, _StepPage page, ProductProvider productProvider) {
    if (page.addOnGroup != null) {
      return _AddOnsSection(
        s: s,
        product: product,
        productProvider: productProvider,
        onlyGroup: page.addOnGroup,
        // Reserve the counter row on every card so a selected card and an
        // idle one keep identical layout.
        reserveQuantity: true,
      );
    }
    if (page.isSize) {
      return _SizeOptionsPanel(
        s: s,
        entries: page.variations,
        product: product,
        productProvider: productProvider,
      );
    }
    final MapEntry<int, Variation> group = page.variations.single;
    if (page.isVariationAddOn) {
      return _VariationAddOnSection(
        s: s,
        variation: group.value,
        variationIndex: group.key,
        product: product,
        productProvider: productProvider,
      );
    }
    if (page.step == _CustomizeStep.cupOrCan) {
      return _CupCanSection(
        s: s,
        variation: group.value,
        variationIndex: group.key,
        product: product,
        productProvider: productProvider,
        // Figma 2305-13433 cards (radio + small tracked label).
        redesigned: true,
      );
    }
    return _VariationSection(
      s: s,
      variation: group.value,
      variationIndex: group.key,
      product: product,
      productProvider: productProvider,
    );
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
  final KioskCustomizeSections sections;
  final int currentStep;
  final int furthestStep;
  final ValueChanged<int> onStepTap;
  final VoidCallback onBack;
  const _StepProgressBar({
    required this.s,
    required this.steps,
    required this.sections,
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
          sections: sections,
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
        // Figma: fixed 252 connectors, so the three circles sit as one compact
        // centred group rather than spreading to the screen edges.
        row.add(SizedBox(
          width: 252 * s,
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
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: row,
            ),
          ),
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
  final KioskCustomizeSections sections;
  final bool isCurrent;
  final bool isCompleted;
  final VoidCallback? onTap;
  const _StepCircle({
    required this.s,
    required this.step,
    required this.sections,
    required this.isCurrent,
    required this.isCompleted,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool filled = isCurrent || isCompleted;
    final double d = 165 * s;
    // Figma 2305-13009/13161/13433: current + completed = solid black disc,
    // light icon; upcoming = black OUTLINE with a black icon (not grey).
    const Color line = _kDarkButton;
    final Color iconColor = filled ? _kCreamText : _kDarkButton;

    final Widget iconWidget;
    final String? svg = step.svgAsset;
    if (svg != null) {
      iconWidget = SvgPicture.asset(
        svg,
        width: d * 0.48,
        height: d * 0.48,
        colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
      );
    } else {
      iconWidget = Text(
        step.glyph,
        style: loewExtraBold.copyWith(
          fontSize: d * 0.6,
          height: 1.0,
          color: iconColor,
        ),
      );
    }

    final Widget circle = Container(
      width: d,
      height: d,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? _kDarkButton : Colors.transparent,
        border: Border.all(color: line, width: _border(6, s)),
      ),
      child: iconWidget,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
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
          step.label(context, sections),
          style: loewExtraBold.copyWith(
            fontSize: 46 * s,
            height: 1.0,
            color: Colors.black,
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
    final double d = 165 * s;
    return Padding(
      // Sit on the circle's vertical centre.
      padding: EdgeInsets.only(
        top: d / 2,
        left: 20 * s,
        right: 20 * s,
      ),
      child: Container(
        height: _border(4, s),
        // Figma draws every connector black.
        color: _kDarkButton,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// LANDSCAPE-ONLY step bar: the pre-2026-11-24 bar, kept byte-for-byte so the
// landscape shell (kiosk_product_customize_landscape.dart) is unaffected by
// the portrait Version B redesign (Figma 2305-13009/13161/13433).
// ---------------------------------------------------------------------------

/// Colour of a step circle / connector that the customer has not reached.
const Color _kLegacyStepUpcoming = Color(0xFFB9B5A6);

class _LegacyStepProgressBar extends StatelessWidget {
  final double s;
  final List<_CustomizeStep> steps;
  final int currentStep;
  final int furthestStep;
  final ValueChanged<int> onStepTap;
  final VoidCallback onBack;
  const _LegacyStepProgressBar({
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
        _LegacyStepCircle(
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
          child: _LegacyStepConnector(s: s, filled: i < currentStep),
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

class _LegacyStepCircle extends StatelessWidget {
  final double s;
  final _CustomizeStep step;
  final bool isCurrent;
  final bool isCompleted;
  final VoidCallback? onTap;
  const _LegacyStepCircle({
    required this.s,
    required this.step,
    required this.isCurrent,
    required this.isCompleted,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool filled = isCurrent || isCompleted;
    final double d = 165 * s;
    final Color line = filled ? _kDarkButton : _kLegacyStepUpcoming;
    final Color iconColor = filled ? _kCreamText : _kLegacyStepUpcoming;

    final Widget iconWidget;
    final String? svg = step.svgAsset;
    if (svg != null) {
      iconWidget = SvgPicture.asset(
        svg,
        width: d * 0.48,
        height: d * 0.48,
        colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
      );
    } else {
      iconWidget = Text(
        step.glyph,
        style: loewExtraBold.copyWith(
          fontSize: d * 0.6,
          height: 1.0,
          color: iconColor,
        ),
      );
    }

    final Widget circle = Container(
      width: d,
      height: d,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? _kDarkButton : Colors.transparent,
        border: Border.all(color: line, width: _border(6, s)),
      ),
      child: iconWidget,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
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
          step.legacyLabel(context),
          style: loewExtraBold.copyWith(
            fontSize: 30 * s,
            height: 1.0,
            color: filled ? Colors.black : TextTones.hint,
          ),
        ),
      ],
    );
  }
}

class _LegacyStepConnector extends StatelessWidget {
  final double s;
  final bool filled;
  const _LegacyStepConnector({required this.s, required this.filled});

  @override
  Widget build(BuildContext context) {
    final double d = 165 * s;
    return Padding(
      // Sit on the circle's vertical centre.
      padding: EdgeInsets.only(
        top: d / 2,
        left: 20 * s,
        right: 20 * s,
      ),
      child: Container(
        height: _border(4, s),
        color: filled ? _kDarkButton : _kLegacyStepUpcoming,
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
              // Figma: a blocked NEXT / ADD TO CART is a rgba(0,0,0,0.25) fill
              // with the cream label still on it, not a dimmed whole button.
              disabledUsesFillAlpha: true,
              // A null onTap is what KioskCheckoutButton dims for its disabled
              // state, so an unanswered required step reads as blocked before
              // the customer even taps — including the last step, where ADD TO
              // CART stays blocked until cup/can (the required choice) is made.
              onTap: canAdvance ? (isLastStep ? onAddToCart : onNext) : null,
            ),
          ),
        ],
      ),
    );
  }
}

/// The bare allergen icon row (Version B) — one coloured disc with its white
/// glyph per allergen the product declares, centred under the hero and tappable
/// for the same detail popup the chip strip opened. Returns null when the
/// branch toggle is off or the product declares no allergens, so a product with
/// no allergens costs no layout and no budget.
class _AllergenIconRow extends StatelessWidget {
  final double s;
  final Set<KioskAllergen> allergens;
  const _AllergenIconRow({required this.s, required this.allergens});

  @override
  Widget build(BuildContext context) {
    // Design order, so the row never reshuffles between products.
    final List<KioskAllergen> ordered =
        KioskAllergen.values.where(allergens.contains).toList();
    final double disc = _kAllergenDiscSize * s;
    final double glyph = _kAllergenDiscGlyph * s;

    return Center(
      child: KioskTap(
        onTap: () => showKioskAllergenInfo(context, allergens),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i = 0; i < ordered.length; i++)
              Padding(
                padding:
                    EdgeInsets.only(left: i == 0 ? 0 : _kAllergenDiscGap * s),
                child: Container(
                  width: disc,
                  height: disc,
                  decoration: BoxDecoration(
                    color: ordered[i].swatch,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: ordered[i].swatch.withValues(alpha: 0.35),
                        offset: Offset(0, disc * 0.06),
                        blurRadius: disc * 0.16,
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: SvgPicture.asset(ordered[i].icon,
                      width: glyph, height: glyph),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// YOUR CHOICES ROW — summary tiles for the step flow header
// ---------------------------------------------------------------------------

/// One tile per ACTUAL selection (each variation, add-on, size, cup/can), plus
/// a dashed placeholder for every step that has nothing chosen yet. Tapping a
/// filled tile jumps back to its step; tapping a placeholder jumps to that
/// step; tapping the × badge removes that one choice. Past six tiles the sixth
/// collapses to a black "+N" that opens the full list.
class _YourChoicesRow extends StatelessWidget {
  final double s;
  final List<_CustomizeStep> steps;
  final int currentStep;
  final KioskCustomizeSections sections;
  final Product product;
  final ProductProvider productProvider;
  final ValueChanged<int> onStepTap;
  const _YourChoicesRow({
    required this.s,
    required this.steps,
    required this.currentStep,
    required this.sections,
    required this.product,
    required this.productProvider,
    required this.onStepTap,
  });

  /// At most this many tiles sit in the row; the rest fold into a "+N" tile.
  static const int _maxVisible = 6;

  @override
  Widget build(BuildContext context) {
    final splash = Provider.of<SplashProvider>(context, listen: false);
    final List<_ChoiceEntry> tiles = _buildTiles(context, splash);
    if (tiles.isEmpty) return const SizedBox.shrink();

    // Cap at six: when there are more, the sixth slot becomes a black "+N"
    // overflow tile that opens the full list.
    final bool overflowing = tiles.length > _maxVisible;
    final List<Widget> children = [];
    final int inlineCount = overflowing ? _maxVisible - 1 : tiles.length;
    for (int i = 0; i < inlineCount; i++) {
      children.add(_ChoiceTile(s: s, entry: tiles[i]));
    }
    if (overflowing) {
      final int hidden = tiles.length - inlineCount;
      children.add(_ChoiceTile(
        s: s,
        entry: _ChoiceEntry.overflow(
          count: hidden,
          onTap: () => _showAllChoices(context, tiles),
        ),
      ));
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  /// The ordered tile models: every real selection first (in step order), then
  /// a dashed placeholder for each step that still has no selection.
  List<_ChoiceEntry> _buildTiles(BuildContext context, SplashProvider splash) {
    final List<_ChoiceEntry> filled = [];
    final List<_ChoiceEntry> placeholders = [];

    for (int stepIdx = 0; stepIdx < steps.length; stepIdx++) {
      final _CustomizeStep step = steps[stepIdx];
      final List<_ChoiceEntry> stepTiles =
          _tilesForStep(context, splash, step, stepIdx);
      if (stepTiles.isEmpty) {
        placeholders.add(_ChoiceEntry.placeholder(
          label: step.label(context, sections),
          onTap: () => onStepTap(stepIdx),
        ));
      } else {
        filled.addAll(stepTiles);
      }
    }
    return [...filled, ...placeholders];
  }

  /// Filled tiles for one step — one per selected value / active add-on.
  List<_ChoiceEntry> _tilesForStep(
    BuildContext context,
    SplashProvider splash,
    _CustomizeStep step,
    int stepIdx,
  ) {
    switch (step) {
      case _CustomizeStep.milks:
        // Size panel then the single-select groups — the same order step 1
        // pages them.
        return _variationTiles(splash,
            [...sections.size, ..._singleSelect(sections.dietary)], stepIdx);
      case _CustomizeStep.cupOrCan:
        return _variationTiles(splash, sections.cupCan, stepIdx);
      case _CustomizeStep.addOns:
        // Multi-select variation extras first (their pages come first), then
        // add-on-table items.
        return [
          ..._variationTiles(splash, _multiSelect(sections.dietary), stepIdx),
          ..._addOnTiles(context, stepIdx),
        ];
    }
  }

  /// One tile per selected value across [groups]. Indices key straight into
  /// [ProductProvider.selectedVariations], exactly as the panels and
  /// [buildKioskCartModel] use them.
  List<_ChoiceEntry> _variationTiles(
    SplashProvider splash,
    List<MapEntry<int, Variation>> groups,
    int stepIdx,
  ) {
    final List<_ChoiceEntry> out = [];
    final sel = productProvider.selectedVariations;
    for (final group in groups) {
      final int gi = group.key;
      if (gi >= sel.length) continue;
      final values = group.value.variationValues ?? [];
      // A required single-select choice can only be swapped, never emptied, so
      // it carries no × — the provider would just re-select it.
      final bool removable = !(group.value.isRequired == true &&
          group.value.isMultiSelect != true);
      for (int j = 0; j < values.length; j++) {
        if (j < sel[gi].length && sel[gi][j] == true) {
          out.add(_ChoiceEntry.filled(
            name: (values[j].level ?? group.value.name ?? '').trim(),
            image: _choiceImageUrl(
              KioskProductImageHelper.optionCardImageUrl(
                value: values[j],
                productImageBaseUrl: splash.baseUrls?.productImageUrl,
              ),
            ),
            onTap: () => onStepTap(stepIdx),
            onRemove: removable
                ? () => productProvider.setCartVariationIndex(
                    gi, j, product, group.value.isMultiSelect == true)
                : null,
          ));
        }
      }
    }
    return out;
  }

  /// One tile per ACTIVE add-on. Indices key into the flat [product.addOns]
  /// list, the same source [ProductProvider.addOnActiveList] is seeded from.
  List<_ChoiceEntry> _addOnTiles(BuildContext context, int stepIdx) {
    final List<_ChoiceEntry> out = [];
    final addOns = product.addOns ?? const <AddOns>[];
    for (int i = 0; i < addOns.length; i++) {
      if (i >= productProvider.addOnActiveList.length) break;
      if (!productProvider.addOnActiveList[i]) continue;
      final AddOns addon = addOns[i];
      final int qty = productProvider.addOnQtyList[i] ?? 1;
      out.add(_ChoiceEntry.filled(
        name: (addon.name ?? '').trim(),
        image: _choiceImageUrl(_addonImageUrl(context, addon)),
        quantity: qty,
        onTap: () => onStepTap(stepIdx),
        // Default add-ons are included with the product and cannot be removed.
        onRemove:
            addon.isDefault ? null : () => productProvider.addAddOn(false, i),
      ));
    }
    return out;
  }

  /// Opens the full choices list when the row overflows past six tiles.
  void _showAllChoices(BuildContext context, List<_ChoiceEntry> tiles) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: KioskUI.pageBg,
        insetPadding: EdgeInsets.all(48 * s),
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(KioskCustomizeSpec.panelRadius * s),
        ),
        child: Padding(
          padding: EdgeInsets.all(40 * s),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                getTranslated('your_choices', context)?.toUpperCase() ??
                    'YOUR CHOICES',
                style: loewExtraBold.copyWith(
                    fontSize: 48 * s, height: 1.0, color: Colors.black),
              ),
              SizedBox(height: 32 * s),
              Flexible(
                child: SingleChildScrollView(
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    children: [
                      for (final entry in tiles)
                        if (!entry.isOverflow) _ChoiceTile(s: s, entry: entry),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The data behind one choice tile. Three flavours: a filled selection, a
/// dashed step placeholder, or the black "+N" overflow tile.
class _ChoiceEntry {
  final String label;
  final String? image;
  final int quantity;
  final bool filled;
  final bool isOverflow;
  final String? overflowText;
  final VoidCallback onTap;
  final VoidCallback? onRemove;
  const _ChoiceEntry._({
    required this.label,
    this.image,
    this.quantity = 1,
    required this.filled,
    this.isOverflow = false,
    this.overflowText,
    required this.onTap,
    this.onRemove,
  });

  factory _ChoiceEntry.filled({
    required String name,
    required String image,
    int quantity = 1,
    required VoidCallback onTap,
    VoidCallback? onRemove,
  }) =>
      _ChoiceEntry._(
        label: name,
        image: image,
        quantity: quantity,
        filled: true,
        onTap: onTap,
        onRemove: onRemove,
      );

  factory _ChoiceEntry.placeholder({
    required String label,
    required VoidCallback onTap,
  }) =>
      _ChoiceEntry._(label: label, filled: false, onTap: onTap);

  factory _ChoiceEntry.overflow({
    required int count,
    required VoidCallback onTap,
  }) =>
      _ChoiceEntry._(
        label: 'More',
        filled: false,
        isOverflow: true,
        overflowText: '+$count',
        onTap: onTap,
      );
}

/// A single choice tile — filled selection, dashed placeholder, or "+N".
class _ChoiceTile extends StatelessWidget {
  final double s;
  final _ChoiceEntry entry;
  const _ChoiceTile({required this.s, required this.entry});

  static const double _tileWidth = 280;
  static const double _thumbSize = 160;
  static const double _thumbRadius = 32.5;
  static const double _thumbBorder = 3.75;
  static const double _imageSize = 130;
  static const double _badgeSize = 55;
  static const double _badgeIconSize = 25;
  static const double _labelSize = 35;
  static const double _labelHeight = 73.75;
  static const double _gap = 17.5;
  static const double _padTop = 20;
  static const double _overlap = 25;

  @override
  Widget build(BuildContext context) {
    final double w = _tileWidth * s;
    final double thumb = _thumbSize * s;
    final double radius = _thumbRadius * s;
    final double border = _border(_thumbBorder, s);

    final bool filled = entry.filled;
    final bool overflow = entry.isOverflow;
    final bool showQty = filled && entry.quantity > 1;

    final Widget thumbChild;
    if (overflow) {
      thumbChild = Container(
        width: thumb,
        height: thumb,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(radius),
        ),
        alignment: Alignment.center,
        child: Text(
          entry.overflowText ?? '',
          style: loewExtraBold.copyWith(
            fontSize: 60 * s,
            height: 1.0,
            color: _kCreamText,
          ),
        ),
      );
    } else if (filled) {
      thumbChild = Container(
        width: thumb,
        height: thumb,
        decoration: BoxDecoration(
          color: _kPanelBg,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: Colors.black, width: border),
        ),
        clipBehavior: Clip.antiAlias,
        alignment: Alignment.center,
        child: (entry.image != null && entry.image!.isNotEmpty)
            ? CustomImageWidget(
                key: ValueKey(entry.image),
                placeholder: Images.placeholderImage,
                image: entry.image!,
                width: _imageSize * s,
                height: _imageSize * s,
                fit: BoxFit.contain,
              )
            : const SizedBox.shrink(),
      );
    } else {
      // Dashed placeholder with a grey "+".
      thumbChild = Container(
        width: thumb,
        height: thumb,
        decoration: BoxDecoration(
          color: _kPanelBg,
          borderRadius: BorderRadius.circular(radius),
        ),
        foregroundDecoration: _DashedBorderDecoration(
          color: _kCardIdleBorder,
          strokeWidth: border,
          radius: radius,
        ),
        alignment: Alignment.center,
        child: Text(
          '+',
          style: loewMedium.copyWith(
            fontSize: 70 * s,
            height: 1.0,
            color: _kCardIdleBorder,
          ),
        ),
      );
    }

    return Transform.translate(
      offset: Offset(-_overlap * s * 0.5, 0),
      child: KioskTap(
        onTap: entry.onTap,
        child: SizedBox(
          width: w,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: _padTop * s),
              SizedBox(
                width: thumb,
                height: thumb,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    thumbChild,
                    // Quantity badge (top-left) when a choice count is >1.
                    if (showQty)
                      Positioned(
                        left: -(_badgeSize * 0.3) * s,
                        top: -(_badgeSize * 0.3) * s,
                        child: _badge(
                          size: _badgeSize * s,
                          child: Text(
                            '${entry.quantity}',
                            style: loewExtraBold.copyWith(
                              fontSize: _badgeIconSize * s,
                              height: 1.0,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    // Remove badge (top-right) on removable filled tiles.
                    if (filled && entry.onRemove != null)
                      Positioned(
                        right: -(_badgeSize * 0.3) * s,
                        top: -(_badgeSize * 0.3) * s,
                        child: KioskTap(
                          onTap: entry.onRemove,
                          child: _badge(
                            size: _badgeSize * s,
                            child: Icon(
                              Icons.close_rounded,
                              size: _badgeIconSize * s,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(height: _gap * s),
              SizedBox(
                height: _labelHeight * s,
                child: Center(
                  child: Text(
                    entry.label.toUpperCase(),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: loewBold.copyWith(
                      fontSize: _labelSize * s,
                      height: 1.05,
                      color: (filled || overflow)
                          ? Colors.black
                          : const Color(0xFF8C877A),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge({required double size, required Widget child}) => Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: Colors.black,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: child,
      );
}

/// Paints a dashed rounded-rect border as a [Decoration].
class _DashedBorderDecoration extends Decoration {
  final Color color;
  final double strokeWidth;
  final double radius;
  const _DashedBorderDecoration({
    required this.color,
    required this.strokeWidth,
    required this.radius,
  });

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) =>
      _DashedBorderPainter(
          color: color, strokeWidth: strokeWidth, radius: radius);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _DashedBorderDecoration &&
          color == other.color &&
          strokeWidth == other.strokeWidth &&
          radius == other.radius;

  @override
  int get hashCode => Object.hash(color, strokeWidth, radius);
}

class _DashedBorderPainter extends BoxPainter {
  final Color color;
  final double strokeWidth;
  final double radius;
  _DashedBorderPainter({
    required this.color,
    required this.strokeWidth,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size ?? Size.zero;
    final rrect = RRect.fromRectAndRadius(
      offset & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    // Dash pattern: 12px on, 8px off (scaled by strokeWidth ratio).
    final metrics = path.computeMetrics().first;
    final double totalLength = metrics.length;
    const double dashOn = 12;
    const double dashOff = 8;
    double distance = 0;
    while (distance < totalLength) {
      final double end = math.min(distance + dashOn, totalLength);
      canvas.drawPath(
        metrics.extractPath(distance, end),
        paint,
      );
      distance = end + dashOff;
    }
  }
}

/// Portrait Version B: a MULTI-select variation group ("Extras", "Classic
/// Toppings"...) drawn as the ADD-ONS step's cards (Figma 2305-13161) — the very
/// same [_AddOnCard], 539x535, toggled on/off by a tap (no +/- counter).
///
/// No counter: a variation pick is a yes/no on the order, and
/// the backend prices it with `in_array(label, ...)`, so sending a value twice
/// would be charged once. Real quantities need backend support first.
class _VariationAddOnSection extends StatelessWidget {
  final double s;
  final Variation variation;
  final int variationIndex;
  final Product product;
  final ProductProvider productProvider;
  const _VariationAddOnSection({
    required this.s,
    required this.variation,
    required this.variationIndex,
    required this.product,
    required this.productProvider,
  });

  void _toggle(int i) {
    productProvider.setCartVariationIndex(
        variationIndex, i, product, variation.isMultiSelect!);
    productProvider.checkIsRequiredSelected(
      index: variationIndex,
      isMultiSelect: variation.isMultiSelect!,
      variations: productProvider.selectedVariations[variationIndex],
      min: variation.min,
      max: variation.max,
    );
  }

  @override
  Widget build(BuildContext context) {
    final splash = Provider.of<SplashProvider>(context, listen: false);
    final values = variation.variationValues ?? const <VariationValue>[];
    final bool showImage = context.watch<KioskAuthProvider>().showImages;
    final String title = (variation.name ?? '').trim().isNotEmpty
        ? variation.name!.trim()
        : (getTranslated('add_add_ons', context) ?? 'Add add-ons');

    return _SectionPanel(
      s: s,
      title: title,
      child: LayoutBuilder(builder: (context, constraints) {
        final double gap = _choiceGap(s);
        final double cardWidth = _choiceGridTileWidth(
          viewportWidth: MediaQuery.sizeOf(context).width,
          panelWidth: constraints.maxWidth,
          s: s,
          gap: gap,
          artboardCard: KioskCustomizeSpec.addOnCardWidth,
        );
        final double cardHeight = cardWidth *
            (KioskCustomizeSpec.addOnCardHeight /
                KioskCustomizeSpec.addOnCardWidth);
        return Wrap(
          alignment: WrapAlignment.start,
          spacing: gap,
          runSpacing: gap,
          children: [
            for (int i = 0; i < values.length; i++)
              Builder(builder: (context) {
                final bool selected =
                    productProvider.selectedVariations[variationIndex][i] ??
                        false;
                return _AddOnCard(
                  width: cardWidth,
                  height: cardHeight,
                  name: (values[i].level ?? '').trim(),
                  priceDelta: values[i].optionPrice ?? 0,
                  image: _choiceImageUrl(
                    KioskProductImageHelper.optionCardImageUrl(
                      value: values[i],
                      productImageBaseUrl: splash.baseUrls?.productImageUrl,
                    ),
                  ),
                  showImage: showImage,
                  showPrice: true,
                  selected: selected,
                  // A variation pick is yes/no (see the class doc), so no
                  // −/qty/+ stepper: tapping the card toggles it on and off.
                  showQuantity: false,
                  reserveQuantity: false,
                  onTap: () => _toggle(i),
                );
              }),
          ],
        );
      }),
    );
  }
}
