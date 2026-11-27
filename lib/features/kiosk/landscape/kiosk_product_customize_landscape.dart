part of '../screens/kiosk_product_customize_sheet.dart';

// =============================================================================
// KIOSK PRODUCT CUSTOMIZE — LANDSCAPE REDESIGN
// =============================================================================
// Figma `egyp8Y2o5BtoJLo8SrcWrX`, nodes 2305:4605 (variation/milk step),
// 2305:4681 (add-ons step), 2305:4892 (add-ons overflow — same screen with
// a "+N MORE" tile once a group has more than the choice row's visible
// count), 2305:5454 (cup/can step — see [_LandscapeCupCanCard]) and
// 2305:5319/5320 (the "Your Choices" full-list popup the overflow tile
// opens — see [_LandscapeChoicesModal]).
//
// This is additive and landscape-only — see [classifyKioskLayout] in
// [_openKioskCustomizeNow]. Portrait (Version A/B above) is never built,
// never re-measured and never re-skinned by anything in this file.
//
// Reuse, not reinvention: every section WIDGET this screen draws — the
// progress bar, the allergen row, the "Your Choices" row, the quantity
// stepper, the option/add-on/cup-can cards, the bottom action bar — is the
// exact widget Version A/B already draw, declared above/alongside this file
// as a sibling `part` of the same library. Only the PAGE ARRANGEMENT (a fixed
// left identity column beside a bordered question card, rather than one
// scrolling/stepped column) and the per-card GRID are new, because that
// arrangement has no portrait equivalent to reuse. Where a card's selection
// logic has to be re-wired for a different grid shape (the add-ons wrap and
// the cup/can grid below do NOT use the portrait density rule, which floors
// at 4 columns — wrong for a square-card row), the ProductProvider calls are
// copied verbatim from [_GroupedAddOnCards] / [_CupCanSection] so the business
// rule itself — required/optional groups, single vs multi select, min/max —
// is never re-derived, only re-laid-out.
//
// Sizing follows the landscape convention the rest of this app's Option-B
// screens use ([LandscapeMetrics]/[LandscapeScaled]): every number below is a
// pixel on the shared 1366x1024 design canvas, multiplied by ONE scale that
// fits that canvas into whatever window this screen is actually given.
// =============================================================================

/// Design-canvas pixels (1366x1024) for the landscape customize screen. Not
/// read off a delivered Figma frame for every value — the variation and
/// add-ons steps were (139px / 144.6px cards, 14px / 5.4px gaps, 5-per-row
/// add-ons); the cup/can step and the chrome around both (margins, header row,
/// panel chrome) have no landscape mock and are modelled to match.
class _LandscapeCustomizeSpec {
  _LandscapeCustomizeSpec._();

  /// Page margin on every edge.
  static const double pageMargin = 40;

  /// Header row (back button + step bar) -> the body; body -> action bar.
  static const double rowGap = 28;

  /// Left identity column. Spec: "fixed ~460-540px at the design's 1366x1024
  /// canvas scale".
  static const double leftColumnWidth = 500;

  /// Left column <-> right question card.
  static const double columnGap = 32;

  // -- header row: back button + step bar ----------------------------------
  /// Fed to [_StepProgressBar]'s `s` — it already draws the back button AND
  /// the three step circles (bottle / "+" / cup, connected, current step
  /// filled) in one widget, which is exactly "same row as the back button,
  /// right-aligned" from the spec.
  static const double stepBarFactor = 0.34;

  // -- left column -----------------------------------------------------------
  static const double heroWidth = 280;
  static const double heroHeight = 420;
  static const double heroToAllergen = 16;

  /// Fed to [_AllergenIconRow]'s `s`.
  static const double allergenFactor = 0.36;
  static const double allergenToTitle = 18;

  static const double titleSize = 20;
  static const double titleToDescription = 6;
  static const double descriptionSize = 12;
  static const double descriptionLineHeight = 1.3;

  /// Fed to [_YourChoicesRow]'s `s`. Kept small enough that six overlapping
  /// tiles (its own hard cap — see [_YourChoicesRow._maxVisible]) stay inside
  /// [leftColumnWidth] without this screen reinventing that threshold.
  static const double choicesFactor = 0.3;
  static const double choicesToStepper = 16;

  /// Fed to [_QuantityStepper]'s `s`.
  static const double qtyFactor = 0.34;

  // -- right question card ---------------------------------------------------
  /// Border #B9B5A6 0.5px, radius 15, bg #FBF8EF — see [_kPanelBg]/[_kPanelBorder].
  static const double panelRadius = 15;
  static const double panelBorder = 0.5;
  static const double panelPad = 32;

  /// "Choose your dietary" / "Add add-ons" — bold ~26px.
  static const double panelHeadingSize = 26;
  static const double panelHeadingGap = 20;

  /// Gap between two stacked question groups (e.g. a Size row above a Milk
  /// row) inside one step — a product with several groups on one step is the
  /// uncommon case; the common one is the single heading + single row the
  /// Figma mock shows.
  static const double panelGroupGap = 28;

  /// Variation/milk step: "~139px, gap ~14px".
  static const double optionCard = 139;
  static const double optionCardGap = 14;

  /// Add-ons step: "~144.6px square... 5 per row... gap ~5.4px". The column
  /// count is RECOMPUTED against the panel's actual width (see
  /// [_landscapeGridColumns]) rather than hard-coded at 5, so the grid still
  /// reads correctly on a narrower or wider landscape window; at this card's
  /// own size on the 1366px canvas it lands on 5 by construction.
  static const double addOnCard = 144.6;
  static const double addOnCardGap = 5.4;
  static const int addOnMinColumns = 3;
  static const int addOnMaxColumns = 6;

  // -- bottom action bar -------------------------------------------------------
  /// Fed to [_StepActionBar]'s `s`.
  static const double actionFactor = 0.3;
}

/// How many [cardDesign]-sized cards (plus [gapDesign] between them) fit a
/// row [availableDesign] px wide, clamped to a sane range so a very wide or
/// very narrow landscape window still reads as a grid rather than one column
/// or a strip of slivers. Deliberately NOT [kioskOptionColumns] — that rule
/// floors at 4 columns for portrait's taller rectangular cards; this screen's
/// cards are square and smaller, and 5 across (this rule's answer at the
/// 1366px design canvas) is the number the Figma mock actually shows.
int _landscapeGridColumns({
  required double availableDesign,
  required double cardDesign,
  required double gapDesign,
  required int minColumns,
  required int maxColumns,
}) {
  if (availableDesign <= 0 || cardDesign <= 0) return minColumns;
  final int columns =
      ((availableDesign + gapDesign) / (cardDesign + gapDesign)).floor();
  return columns.clamp(minColumns, maxColumns);
}

/// Landscape-only redesign of the product customize flow. Same product, same
/// [ProductProvider] selection state, same validation and the same cart
/// write as Version A/B — see [_KioskCustomizeActions] — only the page
/// arrangement differs. See the file header above for what is reused.
class KioskProductCustomizeLandscapeScreen extends StatefulWidget {
  final Product product;
  final int? cartIndex;
  final String? initialInstruction;
  final ValueChanged<CartModel>? onConfigured;

  const KioskProductCustomizeLandscapeScreen({
    super.key,
    required this.product,
    this.cartIndex,
    this.initialInstruction,
    this.onConfigured,
  });

  @override
  State<KioskProductCustomizeLandscapeScreen> createState() =>
      _KioskProductCustomizeLandscapeScreenState();
}

class _KioskProductCustomizeLandscapeScreenState
    extends State<KioskProductCustomizeLandscapeScreen>
    with _KioskCustomizeActions<KioskProductCustomizeLandscapeScreen> {
  String? _instruction;
  late final List<_CustomizeStep> _steps;
  late final KioskCustomizeSections _sections;

  /// See [_KioskProductCustomizeStepScreenState._stepIndex] — same role, same
  /// "rebuild the step body, not the identity column" reasoning.
  final ValueNotifier<int> _stepIndex = ValueNotifier<int>(0);
  final ValueNotifier<int> _furthestStep = ValueNotifier<int>(0);

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
      if (_sections.hasMilkStep) _CustomizeStep.milks,
      if (product.effectiveAddOnGroups.isNotEmpty) _CustomizeStep.addOns,
      if (_sections.cupCan.isNotEmpty) _CustomizeStep.cupOrCan,
    ];

    // Same analytics shape as Version B — see
    // [_KioskProductCustomizeStepScreenState.initState]. A product with
    // nothing to customize never gets here: [build] falls back to Version A,
    // which emits its own started/abandoned pair.
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

  /// See [_KioskProductCustomizeStepScreenState._variationIndexesFor] — same
  /// per-step gating, duplicated here because it is a few lines of pure glue
  /// tying [_CustomizeStep] to [_sections], not a widget.
  Iterable<int> _variationIndexesFor(_CustomizeStep step) => switch (step) {
        _CustomizeStep.milks => [
            ..._sections.size.map((e) => e.key),
            ..._sections.dietary.map((e) => e.key),
          ],
        _CustomizeStep.cupOrCan => _sections.cupCan.map((e) => e.key),
        _CustomizeStep.addOns => const <int>[],
      };

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
    // A product with nothing to ask has no steps to show — same fallback
    // Version B uses, rather than an empty landscape shell.
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
            _lastExperience = experienceOf(context);
            return LandscapeScaled(
              child: Builder(
                builder: (innerContext) => _buildBody(
                  innerContext,
                  LandscapeMetrics.of(innerContext),
                  productProvider,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    LandscapeMetrics m,
    ProductProvider productProvider,
  ) {
    final double margin = m.px(_LandscapeCustomizeSpec.pageMargin);
    final double rowGap = m.px(_LandscapeCustomizeSpec.rowGap);
    final double columnGap = m.px(_LandscapeCustomizeSpec.columnGap);
    final double leftWidth = m.px(_LandscapeCustomizeSpec.leftColumnWidth);

    return Padding(
      padding: EdgeInsets.all(margin),
      child: Column(
        children: [
          // Header row: back button + the 3-step bar, right-aligned — both
          // drawn by the ONE widget Version B already uses for this.
          ValueListenableBuilder<int>(
            valueListenable: _stepIndex,
            builder: (context, current, _) => ValueListenableBuilder<int>(
              valueListenable: _furthestStep,
              builder: (context, furthest, _) => _LegacyStepProgressBar(
                s: m.scale * _LandscapeCustomizeSpec.stepBarFactor,
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
          SizedBox(height: rowGap),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: leftWidth,
                  child: _LandscapeLeftColumn(
                    m: m,
                    product: product,
                    productProvider: productProvider,
                    steps: _steps,
                    sections: _sections,
                    stepIndex: _stepIndex,
                    onStepTap: _goToStep,
                  ),
                ),
                SizedBox(width: columnGap),
                Expanded(
                  child: ValueListenableBuilder<int>(
                    valueListenable: _stepIndex,
                    builder: (context, current, _) => _LandscapeRightPanel(
                      m: m,
                      product: product,
                      productProvider: productProvider,
                      sections: _sections,
                      step: _steps[current],
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: rowGap),
          ValueListenableBuilder<int>(
            valueListenable: _stepIndex,
            builder: (context, current, _) => _StepActionBar(
              s: m.scale * _LandscapeCustomizeSpec.actionFactor,
              product: product,
              productProvider: productProvider,
              isLastStep: current == _steps.length - 1,
              canAdvance:
                  _isStepSatisfied(context, productProvider, _steps[current]),
              onNext: () => _next(context, productProvider),
              onAddToCart: () => _addToCart(context, productProvider),
            ),
          ),
        ],
      ),
    );
  }
}

/// Left identity column: hero photo, allergen row, name + description, the
/// "Your Choices" summary and the quantity stepper — all drawn ONCE per step
/// (only "Your Choices" reacts to the step changing), exactly as Version B's
/// header block sits outside its step listeners.
class _LandscapeLeftColumn extends StatelessWidget {
  final LandscapeMetrics m;
  final Product product;
  final ProductProvider productProvider;
  final List<_CustomizeStep> steps;
  final KioskCustomizeSections sections;
  final ValueListenable<int> stepIndex;
  final ValueChanged<int> onStepTap;
  const _LandscapeLeftColumn({
    required this.m,
    required this.product,
    required this.productProvider,
    required this.steps,
    required this.sections,
    required this.stepIndex,
    required this.onStepTap,
  });

  @override
  Widget build(BuildContext context) {
    final splash = Provider.of<SplashProvider>(context, listen: false);
    final bool showImages = context.watch<KioskAuthProvider>().showImages;
    final bool hasAllergenRow =
        Provider.of<KioskAuthProvider>(context, listen: false)
                .allergenTagEnabled &&
            kioskProductAllergens(product).isNotEmpty;
    final String description = kioskProductDescription(product);
    final String heroImage = KioskProductImageHelper.heroImageUrl(
      product: product,
      productImageBaseUrl: splash.baseUrls?.productImageUrl,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (showImages) ...[
          SizedBox(
            width: m.px(_LandscapeCustomizeSpec.heroWidth),
            height: m.px(_LandscapeCustomizeSpec.heroHeight),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(m.px(12)),
              child: CustomImageWidget(
                key: ValueKey(heroImage),
                placeholder: Images.placeholderImage,
                image: heroImage,
                fit: BoxFit.cover,
              ),
            ),
          ),
          SizedBox(height: m.px(_LandscapeCustomizeSpec.heroToAllergen)),
        ],
        if (hasAllergenRow) ...[
          _AllergenIconRow(
            s: m.scale * _LandscapeCustomizeSpec.allergenFactor,
            allergens: kioskProductAllergens(product),
          ),
          SizedBox(height: m.px(_LandscapeCustomizeSpec.allergenToTitle)),
        ],
        Text(
          product.name ?? '',
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: loewExtraBold.copyWith(
            fontSize: m.px(_LandscapeCustomizeSpec.titleSize),
            height: 1.1,
            color: Colors.black,
          ),
        ),
        if (description.isNotEmpty) ...[
          SizedBox(height: m.px(_LandscapeCustomizeSpec.titleToDescription)),
          Text(
            description,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: swiss721Light.copyWith(
              fontSize: m.px(_LandscapeCustomizeSpec.descriptionSize),
              height: _LandscapeCustomizeSpec.descriptionLineHeight,
              color: Colors.black,
            ),
          ),
        ],
        const Spacer(),
        ValueListenableBuilder<int>(
          valueListenable: stepIndex,
          builder: (context, current, _) => SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: _LandscapeYourChoicesRow(
              s: m.scale * _LandscapeCustomizeSpec.choicesFactor,
              m: m,
              steps: steps,
              sections: sections,
              product: product,
              productProvider: productProvider,
              onStepTap: onStepTap,
            ),
          ),
        ),
        SizedBox(height: m.px(_LandscapeCustomizeSpec.choicesToStepper)),
        _QuantityStepper(
          s: m.scale * _LandscapeCustomizeSpec.qtyFactor,
          productProvider: productProvider,
        ),
      ],
    );
  }
}

/// The bordered question card on the right — Figma's #FBF8EF / #B9B5A6 / 15px
/// radius panel — holding whichever step's content is current.
class _LandscapeRightPanel extends StatelessWidget {
  final LandscapeMetrics m;
  final Product product;
  final ProductProvider productProvider;
  final KioskCustomizeSections sections;
  final _CustomizeStep step;
  const _LandscapeRightPanel({
    required this.m,
    required this.product,
    required this.productProvider,
    required this.sections,
    required this.step,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(m.px(_LandscapeCustomizeSpec.panelPad)),
      decoration: BoxDecoration(
        color: _kPanelBg,
        borderRadius:
            BorderRadius.circular(m.px(_LandscapeCustomizeSpec.panelRadius)),
        border: Border.all(
          color: _kPanelBorder,
          width: _border(_LandscapeCustomizeSpec.panelBorder, m.scale),
        ),
      ),
      child: SingleChildScrollView(
        child: switch (step) {
          _CustomizeStep.milks => _LandscapeVariationStep(
              m: m,
              product: product,
              productProvider: productProvider,
              sections: sections,
            ),
          _CustomizeStep.addOns => _LandscapeAddOnsStep(
              m: m,
              product: product,
              productProvider: productProvider,
            ),
          _CustomizeStep.cupOrCan => _LandscapeCupCanStep(
              m: m,
              product: product,
              productProvider: productProvider,
              sections: sections,
            ),
        },
      ),
    );
  }
}

/// A heading row shared by every step's content: the group's own title
/// (never a fabricated English string — see each step's title source) over
/// its row/grid of cards.
Widget _landscapeGroupHeading(LandscapeMetrics m, String title) => Text(
      title,
      style: loewExtraBold.copyWith(
        fontSize: m.px(_LandscapeCustomizeSpec.panelHeadingSize),
        height: 1.15,
        color: Colors.black,
      ),
    );

/// Variation/milk step (Figma 2305:4605): one horizontal row of square cards
/// per question the product actually has — Size flattened into one row, then
/// each dietary variation group its own row. Same split and the same
/// [ProductProvider] selection rule [_SizeOptionsPanel]/[_VariationSection]
/// use; only the card shape (square, fixed) and the single non-wrapping row
/// are new, to match the Figma mock instead of portrait's taller rectangle.
class _LandscapeVariationStep extends StatelessWidget {
  final LandscapeMetrics m;
  final Product product;
  final ProductProvider productProvider;
  final KioskCustomizeSections sections;
  const _LandscapeVariationStep({
    required this.m,
    required this.product,
    required this.productProvider,
    required this.sections,
  });

  @override
  Widget build(BuildContext context) {
    final splash = Provider.of<SplashProvider>(context, listen: false);
    final bool showImage = context.watch<KioskAuthProvider>().showImages;
    final double card = m.px(_LandscapeCustomizeSpec.optionCard);
    final double gap = m.px(_LandscapeCustomizeSpec.optionCardGap);
    final double groupGap = m.px(_LandscapeCustomizeSpec.panelGroupGap);

    final List<({String title, List<MapEntry<int, int>> options})> groups = [];
    if (sections.size.isNotEmpty) {
      final List<MapEntry<int, int>> options = [];
      for (final entry in sections.size) {
        for (int i = 0; i < (entry.value.variationValues?.length ?? 0); i++) {
          options.add(MapEntry(entry.key, i));
        }
      }
      groups.add((
        title: getTranslated('size', context) ?? 'Size',
        options: options,
      ));
    }
    for (final entry in sections.dietary) {
      final List<MapEntry<int, int>> options = [];
      for (int i = 0; i < (entry.value.variationValues?.length ?? 0); i++) {
        options.add(MapEntry(entry.key, i));
      }
      final String title = entry.value.name?.isNotEmpty == true
          ? entry.value.name!
          : (getTranslated('choose_an_option', context) ?? 'Choose an option');
      groups.add((title: title, options: options));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int g = 0; g < groups.length; g++) ...[
          if (g > 0) SizedBox(height: groupGap),
          _landscapeGroupHeading(m, groups[g].title),
          SizedBox(height: m.px(_LandscapeCustomizeSpec.panelHeadingGap)),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (int i = 0; i < groups[g].options.length; i++) ...[
                  if (i > 0) SizedBox(width: gap),
                  _buildOptionCard(
                    context,
                    splash,
                    showImage,
                    card,
                    groups[g].options[i].key,
                    groups[g].options[i].value,
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildOptionCard(
    BuildContext context,
    SplashProvider splash,
    bool showImage,
    double card,
    int variationIndex,
    int valueIndex,
  ) {
    final List<Variation> variations =
        ProductHelper.effectiveVariations(product) ?? [];
    final Variation variation = variations[variationIndex];
    final VariationValue value = variation.variationValues![valueIndex];
    final bool selected =
        productProvider.selectedVariations[variationIndex][valueIndex] ?? false;
    final String image = _choiceImageUrl(
      KioskProductImageHelper.optionCardImageUrl(
        value: value,
        productImageBaseUrl: splash.baseUrls?.productImageUrl,
      ),
    );
    return _DietaryCard(
      width: card,
      height: card,
      name: (value.level ?? variation.name ?? '').trim(),
      priceDelta: value.optionPrice ?? 0,
      image: image,
      showImage: showImage,
      showPrice: true,
      selected: selected,
      onTap: () {
        // Same selection rule Version A/B use — see
        // [_SizeOptionsPanel]/[_VariationSection]: single-select replaces,
        // multi-select toggles; the provider call is identical.
        productProvider.setCartVariationIndex(
            variationIndex, valueIndex, product, variation.isMultiSelect!);
        productProvider.checkIsRequiredSelected(
          index: variationIndex,
          isMultiSelect: variation.isMultiSelect!,
          variations: productProvider.selectedVariations[variationIndex],
          min: variation.min,
          max: variation.max,
        );
      },
    );
  }
}

/// Add-ons step (Figma 2305:4681, overflow state 2305:4892): a wrap-grid of
/// square cards per add-on group, [_AddOnCard] drawn exactly as Version A/B
/// draw it (image, uppercase label, price, qty counter once selected,
/// included-tick for a default add-on). The grouping/selection rules —
/// required vs optional, single vs multi, min/max, defaults — are the exact
/// [ProductProvider] calls [_GroupedAddOnCards] makes; only the grid itself
/// (fixed card size, column count fit to the panel) is re-derived, because
/// the portrait grid forces a 4-column floor that does not match this card's
/// smaller, square shape.
class _LandscapeAddOnsStep extends StatelessWidget {
  final LandscapeMetrics m;
  final Product product;
  final ProductProvider productProvider;
  const _LandscapeAddOnsStep({
    required this.m,
    required this.product,
    required this.productProvider,
  });

  /// See [_GroupedAddOnCards._trackAddOn] — identical event shape.
  void _trackAddOn(BuildContext context, bool nowSelected, AddOns addon) {
    final auth = Provider.of<KioskAuthProvider>(context, listen: false);
    KioskCustomizeAnalytics.instance.track(
      nowSelected
          ? KioskCustomizeEvent.addOnSelected
          : KioskCustomizeEvent.addOnDeselected,
      experience: auth.orderingExperience,
      productId: product.id,
      branchId: auth.branchId,
      deviceId: auth.deviceId,
      addOnId: addon.id,
      value: addon.name,
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<AddOnGroup> groups = product.effectiveAddOnGroups;
    final bool showImage = context.watch<KioskAuthProvider>().showImages;
    final double card = m.px(_LandscapeCustomizeSpec.addOnCard);
    final double gap = m.px(_LandscapeCustomizeSpec.addOnCardGap);
    final double groupGap = m.px(_LandscapeCustomizeSpec.panelGroupGap);

    if (groups.isEmpty) {
      return _landscapeGroupHeading(
          m, getTranslated('add_add_ons', context) ?? 'Add add-ons');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int g = 0; g < groups.length; g++) ...[
          if (g > 0) SizedBox(height: groupGap),
          _landscapeGroupHeading(m, _addonGroupTitle(context, groups[g])),
          SizedBox(height: m.px(_LandscapeCustomizeSpec.panelHeadingGap)),
          LayoutBuilder(
            builder: (context, constraints) => _addOnWrap(
              context,
              groups[g],
              card,
              gap,
              showImage,
              constraints.maxWidth,
            ),
          ),
        ],
      ],
    );
  }

  Widget _addOnWrap(
    BuildContext context,
    AddOnGroup group,
    double card,
    double gap,
    bool showImage,
    double availableWidth,
  ) {
    // Fit the row exactly, the way every other choice-card grid in this
    // screen does — [_landscapeGridColumns], never the portrait density rule.
    final int columns = _landscapeGridColumns(
      availableDesign: availableWidth,
      cardDesign: card,
      gapDesign: gap,
      minColumns: _LandscapeCustomizeSpec.addOnMinColumns,
      maxColumns: _LandscapeCustomizeSpec.addOnMaxColumns,
    );
    final double fitted =
        math.max(1.0, (availableWidth - gap * (columns - 1)) / columns);

    // See [_GroupedAddOnCards.build]: the group's own default indexes and
    // sibling indexes, straight off the catalog — never hard-coded per
    // product.
    final List<int> groupIndexes = [
      for (final addon in group.addons)
        if (product.indexOfAddOn(addon.id) != null)
          product.indexOfAddOn(addon.id)!,
    ];
    final List<int> defaultIndexes = [
      for (final addon in group.addons)
        if (addon.isDefault && product.indexOfAddOn(addon.id) != null)
          product.indexOfAddOn(addon.id)!,
    ];

    return Wrap(
      spacing: gap,
      runSpacing: gap,
      children: [
        for (final addon in group.addons)
          if (product.indexOfAddOn(addon.id) != null)
            Builder(builder: (context) {
              final int index = product.indexOfAddOn(addon.id)!;
              final bool selected =
                  index < productProvider.addOnActiveList.length &&
                      productProvider.addOnActiveList[index];
              final int quantity = index < productProvider.addOnQtyList.length
                  ? (productProvider.addOnQtyList[index] ?? 1)
                  : 1;
              final bool isDefault = addon.isDefault;
              return _AddOnCard(
                width: fitted,
                height: fitted,
                name: addon.name ?? '',
                priceDelta: addon.effectivePrice,
                image: _choiceImageUrl(_addonImageUrl(context, addon)),
                showImage: showImage,
                showPrice: true,
                selected: selected,
                isDefault: isDefault,
                quantity: quantity,
                showQuantity: selected && !group.isSingle && !isDefault,
                reserveQuantity: true,
                onIncrement: () =>
                    productProvider.setAddOnQuantity(true, index),
                onDecrement: () {
                  if (quantity > 1) {
                    productProvider.setAddOnQuantity(false, index);
                  } else {
                    _trackAddOn(context, false, addon);
                    productProvider.toggleAddOnInGroup(
                      index: index,
                      isSingle: group.isSingle,
                      groupIndexes: groupIndexes,
                      isRequired: group.isRequired,
                      maxSelect: group.max,
                      defaultIndexes: defaultIndexes,
                    );
                  }
                },
                onTap: () {
                  // Included with the product: inert, exactly as portrait
                  // treats a default add-on.
                  if (isDefault) return;
                  if (selected && !group.isSingle) return;
                  _trackAddOn(context, !selected, addon);
                  productProvider.toggleAddOnInGroup(
                    index: index,
                    isSingle: group.isSingle,
                    groupIndexes: groupIndexes,
                    isRequired: group.isRequired,
                    maxSelect: group.max,
                    defaultIndexes: defaultIndexes,
                  );
                },
              );
            }),
      ],
    );
  }
}

/// Cup/can step: Figma node 2305:5454 ("B-21 Matcha: cup or can (step 3)",
/// TABLET Final Designs option B page) — two large square-ish cards side by
/// side rather than the add-ons step's small square grid. Sourced from the
/// same vessel data [_CupCanSection] uses — [kioskLocalVesselAsset] for the
/// bundled cup/can artwork, the product's own image otherwise, single
/// select, the exact same [ProductProvider] calls [_CupCanSection.build]
/// makes. Only the card itself ([_LandscapeCupCanCard]) is new, to match
/// this node's own card size/colours instead of [_CupCanCard]'s generic grid
/// shape.
class _LandscapeCupCanStep extends StatelessWidget {
  final LandscapeMetrics m;
  final Product product;
  final ProductProvider productProvider;
  final KioskCustomizeSections sections;
  const _LandscapeCupCanStep({
    required this.m,
    required this.product,
    required this.productProvider,
    required this.sections,
  });

  @override
  Widget build(BuildContext context) {
    final splash = Provider.of<SplashProvider>(context, listen: false);
    final bool showImages = context.watch<KioskAuthProvider>().showImages;
    // Figma 2305:5454: 372.076x267.461 cards, ~11.84px gap.
    final double cardWidth = m.px(372.076);
    final double cardHeight = m.px(267.461);
    final double gap = m.px(11.84);
    final double groupGap = m.px(_LandscapeCustomizeSpec.panelGroupGap);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int g = 0; g < sections.cupCan.length; g++) ...[
          if (g > 0) SizedBox(height: groupGap),
          Builder(builder: (context) {
            final MapEntry<int, Variation> entry = sections.cupCan[g];
            final List<VariationValue> values =
                entry.value.variationValues ?? [];
            // Heading pulled from the product's own group name, falling
            // back to the SAME translation key portrait's [_CupCanSection]
            // uses for this step — never a fabricated English string.
            final String title = entry.value.name?.isNotEmpty == true
                ? entry.value.name!
                : (getTranslated('can_or_cup', context) ?? 'Can or cup?');
            final bool anyPriced =
                values.any((value) => (value.optionPrice ?? 0) > 0);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _landscapeGroupHeading(m, title),
                SizedBox(height: m.px(_LandscapeCustomizeSpec.panelHeadingGap)),
                Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (int i = 0; i < values.length; i++)
                      _LandscapeCupCanCard(
                        m: m,
                        width: cardWidth,
                        height: cardHeight,
                        showImages: showImages,
                        name: values[i].level?.trim() ?? '',
                        priceDelta: values[i].optionPrice ?? 0,
                        showPrice: anyPriced,
                        assetImage: kioskLocalVesselAsset(
                            values[i].level?.trim() ?? ''),
                        image: KioskProductImageHelper.optionCardImageUrl(
                          value: values[i],
                          productImageBaseUrl: splash.baseUrls?.productImageUrl,
                        ),
                        selected: productProvider.selectedVariations[entry.key]
                                [i] ??
                            false,
                        onTap: () {
                          // Same selection + analytics as
                          // [_CupCanSection.build]'s onTap.
                          final auth = Provider.of<KioskAuthProvider>(context,
                              listen: false);
                          KioskCustomizeAnalytics.instance.track(
                            KioskCustomizeEvent.cupOrCanSelected,
                            experience: auth.orderingExperience,
                            productId: product.id,
                            branchId: auth.branchId,
                            deviceId: auth.deviceId,
                            value: values[i].level?.trim() ?? '',
                          );
                          productProvider.setCartVariationIndex(entry.key, i,
                              product, entry.value.isMultiSelect!);
                          productProvider.checkIsRequiredSelected(
                            index: entry.key,
                            isMultiSelect: entry.value.isMultiSelect!,
                            variations:
                                productProvider.selectedVariations[entry.key],
                            min: entry.value.min,
                            max: entry.value.max,
                          );
                        },
                      ),
                  ],
                ),
              ],
            );
          }),
        ],
      ],
    );
  }
}

/// Cup/can card to Figma 2305:5454's own numbers: 372.076x267.461, radius
/// 9.48, bg #FBF8EF, border #0D0D0D 1.354px selected / #E2D9C8 0.508px idle —
/// the SAME selected-state colours [_border]/[_kInkText]/[_kVesselIdleBorder]
/// already carry for every other card on this screen, just re-laid-out at
/// this node's own size instead of [_CupCanCard]'s generic grid shape. The
/// radio dot and the vessel artwork are the exact [_RadioDot]/[_VesselImage]
/// widgets the rest of the screen draws — nothing here invents a new look.
class _LandscapeCupCanCard extends StatelessWidget {
  final LandscapeMetrics m;
  final double width;
  final double height;
  final bool showImages;
  final String name;
  final double priceDelta;
  final bool showPrice;
  final String? assetImage;
  final String image;
  final bool selected;
  final VoidCallback onTap;
  const _LandscapeCupCanCard({
    required this.m,
    required this.width,
    required this.height,
    required this.showImages,
    required this.name,
    required this.priceDelta,
    required this.showPrice,
    required this.assetImage,
    required this.image,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final String lower = name.toLowerCase();
    // The mock gives the cup and can artwork different proportions (a cup
    // reads wide/short, a can tall/narrow) — the same vessel-type read
    // [kioskLocalVesselAsset] already uses, not a new classifier.
    final bool isCan = lower.contains('can') && !lower.contains('cup');
    final double imageWidth = m.px(isCan ? 52.48 : 84.64);
    final double imageHeight = m.px(isCan ? 143.37 : 115.17);
    final double radius = m.px(9.48);
    final double borderWidth = _border(selected ? 1.354 : 0.508, m.scale);

    return KioskTap(
      onTap: onTap,
      // See [_DietaryCard]: the grid owns the size, the card animates only
      // its outline.
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: width,
              height: height,
              decoration: BoxDecoration(
                color: _kPanelBg,
                borderRadius: BorderRadius.circular(radius),
              ),
              foregroundDecoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radius),
                border: Border.all(
                  color: selected ? _kInkText : _kVesselIdleBorder,
                  width: borderWidth,
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (showImages) ...[
                      SizedBox(
                        width: imageWidth,
                        height: imageHeight,
                        child:
                            _VesselImage(assetImage: assetImage, image: image),
                      ),
                      SizedBox(height: m.px(10)),
                    ],
                    Text(
                      name.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: loewBold.copyWith(
                        fontSize: m.px(9.48),
                        letterSpacing: m.px(1.14),
                        height: 1.0,
                        color: _kInkText,
                      ),
                    ),
                    if (showPrice && priceDelta > 0) ...[
                      SizedBox(height: m.px(6)),
                      Text(
                        _addonPriceLabel(priceDelta),
                        style: swiss721Light.copyWith(
                          fontSize: m.px(9),
                          height: 1.0,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Positioned(
              top: m.px(14),
              right: m.px(14),
              child: _RadioDot(size: m.px(12.19), selected: selected),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// "YOUR CHOICES" FULL-LIST POPUP — Figma 2305:5319 ("Overlay") + 2305:5320
// ("Your Choices Popup"), opened from the black "+N" overflow tile in the
// left column's choices row.
//
// [_YourChoicesRow] (step_flow.dart, shared with portrait) already builds
// that "+N" tile, but its `onTap` is hard-wired to its own private
// `_showAllChoices`, which just reopens the same inline tiles in a plain
// centred dialog — not this popup's grouped, editable list. step_flow.dart
// is portrait's file and off-limits here (see the file header), so there is
// no way to swap that one `onTap` without touching it. [_LandscapeYourChoicesRow]
// below is therefore a landscape-only copy of [_YourChoicesRow]'s tile
// construction — same [_ChoiceEntry]/[_ChoiceTile] types, same ordering, same
// six-tile cap — with only the overflow tile's `onTap` replaced.
// =============================================================================

class _LandscapeYourChoicesRow extends StatelessWidget {
  final double s;
  final LandscapeMetrics m;
  final List<_CustomizeStep> steps;
  final KioskCustomizeSections sections;
  final Product product;
  final ProductProvider productProvider;
  final ValueChanged<int> onStepTap;
  const _LandscapeYourChoicesRow({
    required this.s,
    required this.m,
    required this.steps,
    required this.sections,
    required this.product,
    required this.productProvider,
    required this.onStepTap,
  });

  /// See [_YourChoicesRow._maxVisible] — identical cap.
  static const int _maxVisible = 6;

  @override
  Widget build(BuildContext context) {
    final splash = Provider.of<SplashProvider>(context, listen: false);
    final List<_ChoiceEntry> tiles = _buildTiles(context, splash);
    if (tiles.isEmpty) return const SizedBox.shrink();

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
          onTap: () => _openChoicesPopup(context),
        ),
      ));
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  // -- tile construction: mirrors [_YourChoicesRow]'s private methods
  // verbatim (same business read of [sections]/[productProvider]) — see the
  // file-header comment above for why this file cannot just call those
  // methods instead of re-declaring them. --------------------------------

  List<_ChoiceEntry> _buildTiles(BuildContext context, SplashProvider splash) {
    final List<_ChoiceEntry> filled = [];
    final List<_ChoiceEntry> placeholders = [];

    for (int stepIdx = 0; stepIdx < steps.length; stepIdx++) {
      final _CustomizeStep step = steps[stepIdx];
      final List<_ChoiceEntry> stepTiles =
          _tilesForStep(context, splash, step, stepIdx);
      if (stepTiles.isEmpty) {
        placeholders.add(_ChoiceEntry.placeholder(
          label: step.legacyLabel(context),
          onTap: () => onStepTap(stepIdx),
        ));
      } else {
        filled.addAll(stepTiles);
      }
    }
    return [...filled, ...placeholders];
  }

  List<_ChoiceEntry> _tilesForStep(
    BuildContext context,
    SplashProvider splash,
    _CustomizeStep step,
    int stepIdx,
  ) {
    switch (step) {
      case _CustomizeStep.milks:
        return _variationTiles(
            splash, [...sections.size, ...sections.dietary], stepIdx);
      case _CustomizeStep.cupOrCan:
        return _variationTiles(splash, sections.cupCan, stepIdx);
      case _CustomizeStep.addOns:
        return _addOnTiles(context, stepIdx);
    }
  }

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
        onRemove:
            addon.isDefault ? null : () => productProvider.addAddOn(false, i),
      ));
    }
    return out;
  }

  /// Opens the Figma 2305:5319/5320 popup: a 50%-black scrim
  /// (`barrierColor`, dismiss-on-tap-outside via `barrierDismissible`) behind
  /// a non-centred modal positioned straight off the canvas coordinates
  /// rather than Flutter's own dialog centring.
  void _openChoicesPopup(BuildContext context) {
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: getTranslated('your_choices', context) ?? 'Your choices',
      barrierColor: Colors.black.withValues(alpha: 0.5),
      transitionDuration: const Duration(milliseconds: 160),
      pageBuilder: (dialogContext, _, __) => LandscapeScaled(
        child: Builder(builder: (innerContext) {
          final LandscapeMetrics popupM = LandscapeMetrics.of(innerContext);
          return Center(
            child: SizedBox(
              width: popupM.px(657.08),
              height: popupM.px(744.19),
              child: _LandscapeChoicesModal(
                steps: steps,
                sections: sections,
                product: product,
                onStepTap: onStepTap,
              ),
            ),
          );
        }),
      ),
      transitionBuilder: (context, animation, secondaryAnimation, child) =>
          FadeTransition(opacity: animation, child: child),
    );
  }
}

/// Idle-vs-selected colours borrowed from the unanswered-group placeholder
/// style elsewhere on this screen.
const Color _kPopupMutedInk = Color(0xFF8C877A);

/// New landscape-only tokens for this popup — none of these collide with an
/// existing `_k*` constant above (#DED9C7/#FAF9F7/#6B6B6B appear nowhere else
/// on this screen).
const Color _kPopupDivider = Color(0xFFDED9C7);
const Color _kPopupRowBg = Color(0xFFFAF9F7);
const Color _kPopupPriceGrey = Color(0xFF6B6B6B);

/// The modal box itself (Figma 2305:5320): header (back + title), a
/// scrollable grouped list, and a DONE button — all driven LIVE off
/// [ProductProvider] via `context.watch`, never a snapshot, so editing a
/// quantity or removing a choice here updates immediately and is still
/// correct the moment the popup closes and the left column's choices row
/// rebuilds.
class _LandscapeChoicesModal extends StatelessWidget {
  final List<_CustomizeStep> steps;
  final KioskCustomizeSections sections;
  final Product product;
  final ValueChanged<int> onStepTap;
  const _LandscapeChoicesModal({
    required this.steps,
    required this.sections,
    required this.product,
    required this.onStepTap,
  });

  void _jumpToStep(BuildContext context, _CustomizeStep step) {
    final int i = steps.indexOf(step);
    if (i < 0) return;
    Navigator.of(context).pop();
    onStepTap(i);
  }

  @override
  Widget build(BuildContext context) {
    final LandscapeMetrics m = LandscapeMetrics.of(context);
    final ProductProvider pp = context.watch<ProductProvider>();

    final Widget? addOnsBlock = steps.contains(_CustomizeStep.addOns)
        ? _addOnsBlock(context, m, pp)
        : null;
    final List<Widget> blocks = [
      if (steps.contains(_CustomizeStep.milks)) ..._milkBlocks(context, m, pp),
      if (addOnsBlock != null) addOnsBlock,
      if (steps.contains(_CustomizeStep.cupOrCan))
        ..._cupCanBlocks(context, m, pp),
    ];
    final List<Widget> sectionChildren = [];
    for (int i = 0; i < blocks.length; i++) {
      sectionChildren.add(blocks[i]);
      if (i < blocks.length - 1) sectionChildren.add(_popupDivider(m));
    }

    return Material(
      color: Colors.transparent,
      // Swallow taps so they never fall through to the barrier behind the
      // modal and dismiss it — only the barrier's own empty area (outside
      // this Positioned box, per the caller's Stack) is tap-to-dismiss.
      child: GestureDetector(
        onTap: () {},
        child: Container(
          padding: EdgeInsets.all(m.px(30.356)),
          decoration: BoxDecoration(
            color: _kPanelBg,
            border:
                Border.all(color: _kInkText, width: _border(1.897, m.scale)),
            borderRadius: BorderRadius.circular(m.px(9.486)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: m.px(18.972),
                offset: Offset(0, m.px(6.324)),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  KioskBackButton(
                    // Landscape variant: never larger than it is today.
                    s: KioskChrome.scaleOf(
                        context, m.px(44.585) / KioskChromeSpec.backDiameter),
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        getTranslated('your_choices', context) ??
                            'Your choices',
                        style: loewExtraBold.copyWith(
                          fontSize: m.px(26),
                          height: 1.1,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: m.px(44.585)),
                ],
              ),
              SizedBox(height: m.px(17.708)),
              Expanded(
                child: _LandscapeChoicesScroll(m: m, children: sectionChildren),
              ),
              SizedBox(height: m.px(17.708)),
              _popupDoneButton(context, m),
            ],
          ),
        ),
      ),
    );
  }

  // -- sections -------------------------------------------------------------

  /// One block per milk/dietary group — Figma's "Milk:" example generalised
  /// to however many groups the product actually has (the common case is
  /// one). An unanswered group gets the same "Not chosen yet" / CHOOSE
  /// treatment the Figma mock specs for cup/can, applied symmetrically so a
  /// required-but-unanswered milk group never renders an empty section.
  List<Widget> _milkBlocks(
      BuildContext context, LandscapeMetrics m, ProductProvider pp) {
    final List<Widget> out = [];
    final List<MapEntry<int, Variation>> groups = [
      ...sections.size,
      ...sections.dietary,
    ];
    for (final entry in groups) {
      if (entry.key >= pp.selectedVariations.length) continue;
      final List<VariationValue> values = entry.value.variationValues ?? [];
      final String title = entry.value.name?.isNotEmpty == true
          ? entry.value.name!
          : (getTranslated('milks', context) ?? 'Milk');
      final List<int> selectedIdx = [
        for (int j = 0; j < values.length; j++)
          if (j < pp.selectedVariations[entry.key].length &&
              pp.selectedVariations[entry.key][j] == true)
            j,
      ];
      final List<Widget> rows = selectedIdx.isEmpty
          ? [
              _popupNotChosenRow(context, m,
                  onChoose: () => _jumpToStep(context, _CustomizeStep.milks)),
            ]
          : [
              for (final j in selectedIdx)
                _popupChosenRow(
                  context,
                  m,
                  thumb: _popupVariationThumb(context, m, values[j]),
                  name: (values[j].level ?? entry.value.name ?? '').trim(),
                  onChange: () => _jumpToStep(context, _CustomizeStep.milks),
                ),
            ];
      out.add(_popupBlock(m, '$title:', rows));
    }
    return out;
  }

  /// One combined "Add-ons (N):" block — N is every ACTIVE add-on across
  /// every group, the same set [_YourChoicesRow._addOnTiles] counts. Null
  /// when nothing is active, so the popup never shows an empty add-ons
  /// section.
  Widget? _addOnsBlock(
      BuildContext context, LandscapeMetrics m, ProductProvider pp) {
    final List<AddOns> addOns = product.addOns ?? const <AddOns>[];
    final List<Widget> rows = [];
    int activeCount = 0;
    for (int i = 0; i < addOns.length; i++) {
      if (i >= pp.addOnActiveList.length || !pp.addOnActiveList[i]) continue;
      activeCount++;
      rows.add(_popupAddOnRow(context, m, pp, addon: addOns[i], index: i));
    }
    if (rows.isEmpty) return null;
    final String label =
        '${getTranslated('add_ons', context) ?? 'Add-ons'} ($activeCount):';
    return _popupBlock(m, label, rows);
  }

  /// One block per cup/can group (normally exactly one) — Figma's own
  /// "Cup or can:" / "Not chosen yet" + CHOOSE states.
  List<Widget> _cupCanBlocks(
      BuildContext context, LandscapeMetrics m, ProductProvider pp) {
    final List<Widget> out = [];
    for (final entry in sections.cupCan) {
      if (entry.key >= pp.selectedVariations.length) continue;
      final List<VariationValue> values = entry.value.variationValues ?? [];
      final String title = entry.value.name?.isNotEmpty == true
          ? entry.value.name!
          : (getTranslated('cup_or_can', context) ?? 'Cup or can');
      int? selected;
      for (int j = 0; j < values.length; j++) {
        if (j < pp.selectedVariations[entry.key].length &&
            pp.selectedVariations[entry.key][j] == true) {
          selected = j;
          break;
        }
      }
      final Widget row = selected == null
          ? _popupNotChosenRow(context, m,
              onChoose: () => _jumpToStep(context, _CustomizeStep.cupOrCan))
          : _popupChosenRow(
              context,
              m,
              thumb: _popupVesselThumb(context, m, values[selected]),
              name: (values[selected].level ?? '').trim(),
              onChange: () => _jumpToStep(context, _CustomizeStep.cupOrCan),
            );
      out.add(_popupBlock(m, '$title:', [row]));
    }
    return out;
  }

  // -- add-on row + its remove/stepper wiring --------------------------------

  /// Same [ProductProvider.toggleAddOnInGroup] call [_LandscapeAddOnsStep]
  /// makes when a qty-1 add-on's decrement is tapped — the group/default
  /// index lists are re-derived here because this row has no [AddOnGroup] in
  /// scope the way the add-ons step's own build loop does, not because the
  /// removal RULE itself is any different.
  void _removeAddOn(
    BuildContext context,
    ProductProvider pp,
    AddOns addon,
    int index,
  ) {
    AddOnGroup? owner;
    for (final AddOnGroup g in product.effectiveAddOnGroups) {
      if (g.addons.any((a) => a.id == addon.id)) {
        owner = g;
        break;
      }
    }
    final List<int> groupIndexes = owner == null
        ? [index]
        : [
            for (final a in owner.addons)
              if (product.indexOfAddOn(a.id) != null)
                product.indexOfAddOn(a.id)!,
          ];
    final List<int> defaultIndexes = owner == null
        ? const <int>[]
        : [
            for (final a in owner.addons)
              if (a.isDefault && product.indexOfAddOn(a.id) != null)
                product.indexOfAddOn(a.id)!,
          ];
    final auth = Provider.of<KioskAuthProvider>(context, listen: false);
    KioskCustomizeAnalytics.instance.track(
      KioskCustomizeEvent.addOnDeselected,
      experience: auth.orderingExperience,
      productId: product.id,
      branchId: auth.branchId,
      deviceId: auth.deviceId,
      addOnId: addon.id,
      value: addon.name,
    );
    pp.toggleAddOnInGroup(
      index: index,
      isSingle: owner?.isSingle ?? false,
      groupIndexes: groupIndexes,
      isRequired: owner?.isRequired ?? false,
      maxSelect: owner?.max,
      defaultIndexes: defaultIndexes,
    );
  }

  Widget _popupAddOnRow(
    BuildContext context,
    LandscapeMetrics m,
    ProductProvider pp, {
    required AddOns addon,
    required int index,
  }) {
    final bool isDefault = addon.isDefault;
    final int qty =
        index < pp.addOnQtyList.length ? (pp.addOnQtyList[index] ?? 1) : 1;
    final String priceLabel = isDefault
        ? kioskTranslate(context, 'included', 'Included')
        : _addonPriceLabel(addon.effectivePrice);

    final Widget trailing;
    if (isDefault) {
      // Included with the product: nothing to remove or adjust — same as
      // every other default add-on surface on this screen.
      trailing = const SizedBox.shrink();
    } else if (qty > 1) {
      // Same qty rule [_LandscapeAddOnsStep._addOnWrap] draws: a stepper
      // once quantity is above one.
      trailing = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepperButton(
            width: m.px(26),
            height: m.px(26),
            radius: m.px(6),
            borderWidth: _border(0.791, m.scale),
            glyphSize: m.px(13),
            label: '-',
            filled: false,
            background: _kPanelBg,
            borderColor: _kPanelBorder,
            onTap: () => pp.setAddOnQuantity(false, index),
          ),
          SizedBox(width: m.px(6)),
          Text(
            '$qty',
            style:
                loewExtraBold.copyWith(fontSize: m.px(13), color: Colors.black),
          ),
          SizedBox(width: m.px(6)),
          _StepperButton(
            width: m.px(26),
            height: m.px(26),
            radius: m.px(6),
            borderWidth: _border(0.791, m.scale),
            glyphSize: m.px(13),
            label: '+',
            filled: true,
            onTap: () => pp.setAddOnQuantity(true, index),
          ),
        ],
      );
    } else {
      // Qty 1: trash removes it outright — the SAME threshold
      // [_LandscapeAddOnsStep._addOnWrap]'s onDecrement already applies.
      trailing = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          KioskTap(
            onTap: () => _removeAddOn(context, pp, addon, index),
            child: Icon(Icons.delete_outline, size: m.px(18), color: _kInkText),
          ),
          SizedBox(width: m.px(8)),
          Text('$qty',
              style: loewExtraBold.copyWith(
                  fontSize: m.px(13), color: Colors.black)),
        ],
      );
    }

    return _popupRowShell(
      m,
      thumb:
          _popupImageThumb(m, _choiceImageUrl(_addonImageUrl(context, addon))),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            (addon.name ?? '').trim(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: loewBold.copyWith(
                fontSize: m.px(12.65), height: 1.1, color: Colors.black),
          ),
          if (priceLabel.isNotEmpty) ...[
            SizedBox(height: m.px(2)),
            Text(
              priceLabel,
              style: swiss721Light.copyWith(
                  fontSize: m.px(10.75), color: _kPopupPriceGrey),
            ),
          ],
        ],
      ),
      trailing: trailing,
    );
  }

  // -- milk / cup-can rows ----------------------------------------------------

  Widget _popupChosenRow(
    BuildContext context,
    LandscapeMetrics m, {
    required Widget thumb,
    required String name,
    required VoidCallback onChange,
  }) =>
      _popupRowShell(
        m,
        thumb: thumb,
        content: Text(
          name.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: loewBold.copyWith(
              fontSize: m.px(12.65), height: 1.1, color: Colors.black),
        ),
        trailing: _popupActionButton(
          m,
          (getTranslated('change', context) ?? 'Change').toUpperCase(),
          onChange,
        ),
      );

  Widget _popupNotChosenRow(
    BuildContext context,
    LandscapeMetrics m, {
    required VoidCallback onChoose,
  }) =>
      _popupRowShell(
        m,
        thumb: _popupDashedThumb(m),
        content: Text(
          getTranslated('not_chosen_yet', context) ?? 'Not chosen yet',
          style: loewBold.copyWith(
              fontSize: m.px(12.65), height: 1.1, color: _kPopupMutedInk),
        ),
        trailing: _popupActionButton(
          m,
          (getTranslated('choose', context) ?? 'Choose').toUpperCase(),
          onChoose,
        ),
      );

  Widget _popupVariationThumb(
      BuildContext context, LandscapeMetrics m, VariationValue value) {
    final splash = Provider.of<SplashProvider>(context, listen: false);
    final String image = _choiceImageUrl(
      KioskProductImageHelper.optionCardImageUrl(
        value: value,
        productImageBaseUrl: splash.baseUrls?.productImageUrl,
      ),
    );
    return _popupImageThumb(m, image);
  }

  Widget _popupVesselThumb(
      BuildContext context, LandscapeMetrics m, VariationValue value) {
    final splash = Provider.of<SplashProvider>(context, listen: false);
    final String? asset = kioskLocalVesselAsset(value.level?.trim() ?? '');
    final String image = KioskProductImageHelper.optionCardImageUrl(
      value: value,
      productImageBaseUrl: splash.baseUrls?.productImageUrl,
    );
    final double size = m.px(37.945);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(m.px(7.589)),
      ),
      alignment: Alignment.center,
      child: SizedBox(
        width: m.px(31.621),
        height: m.px(31.621),
        child: _VesselImage(assetImage: asset, image: image),
      ),
    );
  }
}

// -- shared popup row chrome (thumb/button/shell/block/divider) -------------

Widget _popupBlock(LandscapeMetrics m, String label, List<Widget> rows) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        label,
        style: loewExtraBold.copyWith(
            fontSize: m.px(12.65), height: 1.1, color: Colors.black),
      ),
      SizedBox(height: m.px(10)),
      for (int i = 0; i < rows.length; i++) ...[
        if (i > 0) SizedBox(height: m.px(8)),
        rows[i],
      ],
    ],
  );
}

Widget _popupDivider(LandscapeMetrics m) => Container(
      margin: EdgeInsets.symmetric(vertical: m.px(14)),
      height: _border(1.265, m.scale),
      color: _kPopupDivider,
    );

Widget _popupRowShell(
  LandscapeMetrics m, {
  required Widget thumb,
  required Widget content,
  required Widget trailing,
}) =>
    Container(
      decoration: BoxDecoration(
        color: _kPopupRowBg,
        border:
            Border.all(color: _kPopupDivider, width: _border(0.949, m.scale)),
        borderRadius: BorderRadius.circular(m.px(7.589)),
      ),
      padding:
          EdgeInsets.symmetric(vertical: m.px(8.85), horizontal: m.px(15.18)),
      child: Row(
        children: [
          thumb,
          SizedBox(width: m.px(7.589)),
          Expanded(child: content),
          SizedBox(width: m.px(7.589)),
          trailing,
        ],
      ),
    );

Widget _popupImageThumb(LandscapeMetrics m, String image) {
  final double size = m.px(37.945);
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(m.px(7.589)),
    ),
    alignment: Alignment.center,
    child: SizedBox(
      width: m.px(31.621),
      height: m.px(31.621),
      child: _OptionImageSlot(image: image, fit: BoxFit.contain),
    ),
  );
}

/// Dashed placeholder thumb for an unanswered choice — reuses
/// [_DashedBorderDecoration], the exact painter [_ChoiceTile] already uses
/// for its own dashed "+" placeholder.
Widget _popupDashedThumb(LandscapeMetrics m) {
  final double size = m.px(37.945);
  final double border = _border(0.949, m.scale);
  final double radius = m.px(7.589);
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: _kPanelBg,
      borderRadius: BorderRadius.circular(radius),
    ),
    foregroundDecoration: _DashedBorderDecoration(
      color: _kVesselIdleBorder,
      strokeWidth: border,
      radius: radius,
    ),
    alignment: Alignment.center,
    child: Text(
      '+',
      style: loewMedium.copyWith(fontSize: m.px(18), color: _kVesselIdleBorder),
    ),
  );
}

Widget _popupActionButton(
        LandscapeMetrics m, String label, VoidCallback onTap) =>
    KioskTap(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: m.px(14), vertical: m.px(7)),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: _kInkText, width: _border(0.791, m.scale)),
          borderRadius: BorderRadius.circular(m.px(5.059)),
        ),
        child: Text(
          label,
          style: loewBold.copyWith(
              fontSize: m.px(11.38), height: 1.0, color: _kInkText),
        ),
      ),
    );

Widget _popupDoneButton(BuildContext context, LandscapeMetrics m) => KioskTap(
      onTap: () => Navigator.of(context).pop(),
      child: Container(
        width: double.infinity,
        height: m.px(79.684),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(m.px(9.486)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: m.px(8.854),
              offset: Offset(0, m.px(2.951)),
            ),
          ],
        ),
        child: Text(
          (getTranslated('done', context) ?? 'Done').toUpperCase(),
          style: loewExtraBold.copyWith(
              fontSize: m.px(17), height: 1.0, color: Colors.white),
        ),
      ),
    );

/// The scroll area inside the modal: a [RawScrollbar] (track #DED9C7, thumb
/// #0D0D0D — Figma's custom 5px track/thumb, via the native scrollbar rather
/// than hand-painted track geometry) plus a bottom gradient fade over the
/// last ~70px so the list reads as continuing past the fold.
class _LandscapeChoicesScroll extends StatelessWidget {
  final LandscapeMetrics m;
  final List<Widget> children;
  const _LandscapeChoicesScroll({required this.m, required this.children});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        RawScrollbar(
          thumbColor: _kInkText,
          trackColor: _kPopupDivider,
          trackBorderColor: _kPopupDivider,
          radius: Radius.circular(m.px(2.5)),
          thickness: m.px(5),
          thumbVisibility: true,
          trackVisibility: true,
          child: SingleChildScrollView(
            padding: EdgeInsets.only(right: m.px(14), bottom: m.px(70)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: children,
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: m.px(70),
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    _kPanelBg.withValues(alpha: 0),
                    _kPanelBg,
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
