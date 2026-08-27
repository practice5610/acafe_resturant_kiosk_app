// ignore_for_file: unused_import, dead_code
import 'package:flutter/material.dart';
import 'package:acafe_customer/common/providers/product_provider.dart'; // Veg/Non-Veg filter (commented below)
import 'package:acafe_customer/common/widgets/custom_asset_image_widget.dart';
import 'package:acafe_customer/common/widgets/custom_text_field_widget.dart';
import 'package:acafe_customer/common/widgets/no_data_widget.dart';
import 'package:acafe_customer/common/widgets/paginated_list_widget.dart';
import 'package:acafe_customer/common/widgets/product_shimmer_widget.dart';
import 'package:acafe_customer/features/category/providers/category_provider.dart';
import 'package:acafe_customer/common/models/product_model.dart';
import 'package:acafe_customer/common/widgets/custom_image_widget.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_allergen.dart';
import 'package:acafe_customer/features/kiosk/screens/kiosk_product_customize_sheet.dart';
import 'package:acafe_customer/common/responsive/kiosk_layout.dart';
import 'package:acafe_customer/common/responsive/kiosk_responsive.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_bottom_sheet.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_tap.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_ui.dart';
import 'package:acafe_customer/features/search/search_flow_helper.dart';
import 'package:acafe_customer/features/search/providers/search_provider.dart';
import 'package:acafe_customer/features/search/widget/filter_widget.dart';
import 'package:acafe_customer/features/search/widget/food_filter_button_widget.dart'; // Veg/Non-Veg filter (commented below)
import 'package:acafe_customer/features/search/widget/kiosk_search_theme.dart';
import 'package:acafe_customer/features/splash/providers/splash_provider.dart';
import 'package:acafe_customer/helper/price_converter_helper.dart';
import 'package:acafe_customer/helper/responsive_helper.dart';
import 'package:acafe_customer/localization/language_constrants.dart';
import 'package:acafe_customer/utill/dimensions.dart';
import 'package:acafe_customer/utill/images.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class SearchResultScreen extends StatefulWidget {
  final String? searchString;
  const SearchResultScreen({super.key, required this.searchString});

  @override
  State<SearchResultScreen> createState() => _SearchResultScreenState();
}

class _SearchResultScreenState extends State<SearchResultScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController scrollController = ScrollController();
  String _type = 'all';
  late SearchProvider _searchProvider;
  late CategoryProvider _categoryProvider;

  @override
  void initState() {
    super.initState();

    _categoryProvider = Provider.of<CategoryProvider>(context, listen: false);
    _searchProvider = Provider.of<SearchProvider>(context, listen: false);

    _searchProvider.resetFilterData(isUpdate: false, categoryProvider: _categoryProvider);

    _searchController.text = SearchFlowHelper.queryFromRouteSlug(widget.searchString);

    if (_categoryProvider.categoryList == null) {
      _categoryProvider.getCategoryList(true);
    }
    _searchProvider.saveSearchAddress(_searchController.text);
    _searchProvider.searchProduct(
      offset: 1,
      name: _searchController.text,
      context: context,
      isUpdate: false,
    );
  }

  @override
  void dispose() {
    _searchProvider.resetFilterData(isUpdate: false, categoryProvider: _categoryProvider);
    _searchController.dispose();
    scrollController.dispose();
    super.dispose();
  }

  void _handleBack() => SearchFlowHelper.navigateBack(context);

  Future<void> _openFilterSheet() {
    final double maxValue =
        _searchProvider.searchProductModel?.productMaxPrice ?? 1000;
    return showKioskBottomSheet<void>(
      context,
      maxWidth: KioskUI.filterSheetMaxWidth,
      heightFactor: 0.65,
      expandToHeightFactor: true,
      child: Container(
        decoration: const BoxDecoration(
          color: KioskSearchTheme.pageBg,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(28),
            topRight: Radius.circular(28),
          ),
        ),
        child: FilterWidget(maxValue: maxValue),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // final productProvider = Provider.of<ProductProvider>(context, listen: false); // Veg/Non-Veg filter (commented below)
    // Kiosk always uses the kiosk search-result layout — never the old user-web-app
    // layout — even on large screens.
    const bool isDesktop = false;

    final bool landscape = KioskLayout.isLandscape(context);
    final double barHeight = landscape ? 88.0 : 100.0;
    double topPadding = MediaQuery.of(context).padding.top;

    return PopScope(
      canPop: Navigator.of(context).canPop() || GoRouter.of(context).canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
      backgroundColor: KioskSearchTheme.pageBg,
      appBar: PreferredSize(preferredSize: Size.fromHeight(barHeight), child:
      Container(
        color: KioskSearchTheme.pageBg,
        padding : EdgeInsets.only(
          top: landscape ? 8 : (topPadding < 20 ? 40 : 0),
          bottom: Dimensions.paddingSizeDefault,
          right: Dimensions.paddingSizeLarge,
          left: Dimensions.paddingSizeDefault,
        ),
        child: SafeArea(
          child: Row(children: [

            const KioskBackButton(),
            const SizedBox(width: Dimensions.paddingSizeSmall),

            Consumer<SearchProvider>(
                builder: (context, searchProvider, _) {
                  return Expanded(child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeDefault),
                    decoration: BoxDecoration(
                      color: KioskSearchTheme.surface,
                      borderRadius: BorderRadius.circular(40),
                      border: Border.all(color: KioskSearchTheme.border),
                    ),
                    child: CustomTextFieldWidget(
                      hintText: getTranslated('search_items_here', context),
                      isShowBorder: false,
                      isShowSuffixIcon: true,
                      suffixIconUrl: Images.closeSvg,
                      suffixIconColor: null,
                      controller: _searchController,
                      inputAction: TextInputAction.search,
                      isIcon: true,
                      onSubmit: (value){
                        searchProvider.saveSearchAddress(value);
                        searchProvider.searchProduct(offset: 1, name: value, context: context);
                      },

                      onSuffixTap: () {
                        _searchController.clear();
                      },
                    ),
                  ));
                }
            ),
            const SizedBox(width: Dimensions.paddingSizeSmall),

            SearchFilterButtonWidget(onOpenFilter: _openFilterSheet),

          ]),
        ),
      )),
      body: CustomScrollView(controller: scrollController, slivers: [

        SliverToBoxAdapter(child: Center(child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: KioskResponsive.designWidth),
          child: Consumer<SearchProvider>(
            builder: (context, searchProvider, child) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              /// for search bar
              if(!isDesktop)

              const SizedBox(height: Dimensions.paddingSizeDefault),


              Padding(padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeLarge),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                  searchProvider.searchProductModel != null ? Center(
                    child: Container(
                      padding: const EdgeInsets.only(
                      top: 0,
                      bottom: Dimensions.paddingSizeDefault,
                    ),
                      child: Row(children: [

                        Expanded(child: _searchController.text.trim().isEmpty ? const SizedBox() : RichText(softWrap: true, text: TextSpan(text: '', children: <TextSpan>[
                          TextSpan(
                            text: '${searchProvider.searchProductModel?.products?.length} ',
                            style: swiss721Light.copyWith(fontSize: Dimensions.fontSizeDefault, color: KioskSearchTheme.muted),
                          ),
                          TextSpan(
                            text: '${getTranslated('results_for', context)} ',
                            style: swiss721Light.copyWith(fontSize: Dimensions.fontSizeDefault, color: KioskSearchTheme.muted),
                          ),
                          TextSpan(text: '" ${_searchController.text} "', style: loewExtraBold.copyWith(
                            fontSize: Dimensions.fontSizeDefault,
                            color: KioskSearchTheme.primary,
                          )),
                        ]))),
                        const SizedBox(width: Dimensions.paddingSizeDefault),

                        // Veg / Non-Veg filter hidden (café — not relevant)
                        // IgnorePointer(
                        //   ignoring: searchProvider.searchProductModel == null,
                        //   child: FoodFilterButtonWidget(
                        //     type: _type,
                        //     items: productProvider.productTypeList,
                        //     isBorder: true,
                        //     onSelected: (selected) {
                        //       _type = selected;
                        //       searchProvider.searchProduct(name: _searchController.text, productType: _type, isUpdate: true, offset: 1, context: context);
                        //     },
                        //   ),
                        // ),

                        if(isDesktop) const SizedBox(width: Dimensions.paddingSizeDefault),
                        if(isDesktop) SearchFilterButtonWidget(onOpenFilter: _openFilterSheet),

                      ]),
                    ),
                  ) : const SizedBox.shrink(),

                  searchProvider.searchProductModel == null ? LayoutBuilder(
                    builder: (context, constraints) {
                      final geo = _KioskResultGrid.geometryFor(
                        constraints.maxWidth,
                        landscape: KioskLayout.isLandscape(context, constraints),
                      );
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisSpacing: geo.gap, mainAxisSpacing: geo.gap,
                          crossAxisCount: geo.columns,
                          mainAxisExtent: geo.tileHeight,
                        ),
                        itemCount: geo.columns * 2,
                        itemBuilder: (BuildContext context, int index) =>
                            _KioskResultSkeleton(tileWidth: geo.tileWidth),
                        padding: EdgeInsets.zero,
                      );
                    },
                  ) :
                  (searchProvider.searchProductModel?.products?.isNotEmpty ?? false) ?  Padding(
                    padding: const EdgeInsets.only(bottom: Dimensions.paddingSizeDefault),
                    child: PaginatedListWidget(
                      scrollController: scrollController,
                      onPaginate: (int? offset){
                        searchProvider.searchProduct(name: _searchController.text, offset: offset ?? 1, context: context, productType: _type);
                      },
                      totalSize: searchProvider.searchProductModel?.totalSize,
                      offset: searchProvider.searchProductModel?.offset,
                      builder: (_)=> LayoutBuilder(
                        builder: (context, constraints) {
                          final geo = _KioskResultGrid.geometryFor(
                        constraints.maxWidth,
                        landscape: KioskLayout.isLandscape(context, constraints),
                      );
                          // Search has to honour the allergen answer too — a
                          // customer who declared "no nuts" and then typed
                          // "brownie" must not be handed one. Filtered here
                          // rather than in the provider because the paging
                          // counts (totalSize/offset) are the server's.
                          final List<Product> results =
                              filterKioskProductsByAllergens(
                            products: searchProvider
                                    .searchProductModel?.products ??
                                const <Product>[],
                            avoided:
                                KioskAllergenPreferences.instance.avoided,
                          );
                          if (results.isEmpty) {
                            return const Center(
                                child: NoDataWidget(isFooter: false));
                          }
                          return GridView.builder(
                            padding: EdgeInsets.zero,
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisSpacing: geo.gap, mainAxisSpacing: geo.gap,
                              crossAxisCount: geo.columns,
                              mainAxisExtent: geo.tileHeight,
                            ),
                            itemCount: results.length,
                            physics: const NeverScrollableScrollPhysics(),
                            shrinkWrap: true,
                            itemBuilder: (context, index) => _KioskResultCard(
                              product: results[index],
                              tileWidth: geo.tileWidth,
                            ),
                          );
                        },
                      ),
                    ),
                  ) : const Center(child: NoDataWidget(isFooter: false)),





                ]),
              ),





            ]),
          ),
        ))),



        ],
      ),
    ),
    );
  }
}

/// Responsive geometry for the search result grid — mirrors the kiosk menu:
/// 3 products per row on phones/small screens, growing on larger displays, with
/// tall portrait cards whose text scales with the tile width.
class _KioskResultGrid {
  final int columns;
  final double gap;
  final double tileWidth;
  final double tileHeight;
  const _KioskResultGrid(this.columns, this.gap, this.tileWidth, this.tileHeight);

  static _KioskResultGrid geometryFor(double width, {bool landscape = false}) {
    final resolved = KioskProductGridGeometry.resolve(
      areaWidth: width,
      gap: Dimensions.paddingSizeDefault,
      landscape: landscape,
    );
    return _KioskResultGrid(
      resolved.columns,
      resolved.gap,
      resolved.tileWidth,
      resolved.tileHeight,
    );
  }
}

/// A search-result product card that matches the kiosk menu design: white
/// rounded card with the portrait image and the name + price inside it. No
/// "Add" button — tapping the card opens the customise sheet (same as the menu).
class _KioskResultCard extends StatelessWidget {
  final Product product;
  final double tileWidth;
  const _KioskResultCard({required this.product, required this.tileWidth});

  @override
  Widget build(BuildContext context) {
    final splash = Provider.of<SplashProvider>(context, listen: false);
    final String image = '${splash.baseUrls?.productImageUrl}/${product.image}';
    final double ts = tileWidth / 564.0;

    return KioskTap(
      onTap: () => openKioskCustomize(context, product),
      child: Material(
        color: KioskSearchTheme.surface,
        borderRadius: BorderRadius.circular(60 * ts),
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        shadowColor: Colors.transparent,
        child: Padding(
          padding: EdgeInsets.all(24 * ts),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(40 * ts),
                  child: CustomImageWidget(
                    placeholder: Images.placeholderImage,
                    image: image,
                    fit: BoxFit.cover,
                    useShimmer: true,
                  ),
                ),
              ),
              SizedBox(height: 16 * ts),
              Text(
                product.name ?? '',
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: loewExtraBold.copyWith(fontSize: 32 * ts, height: 1.1, color: KioskSearchTheme.primary),
              ),
              SizedBox(height: 8 * ts),
              Text(
                PriceConverterHelper.convertPrice(
                  product.price,
                  discount: product.discount,
                  discountType: product.discountType,
                ),
                textAlign: TextAlign.center,
                style: swiss721Light.copyWith(fontSize: 36 * ts, color: KioskSearchTheme.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shimmering skeleton card that matches [_KioskResultCard]'s geometry.
class _KioskResultSkeleton extends StatelessWidget {
  final double tileWidth;
  const _KioskResultSkeleton({required this.tileWidth});

  @override
  Widget build(BuildContext context) {
    final double ts = tileWidth / 564.0;
    return Material(
      color: KioskSearchTheme.surface,
      borderRadius: BorderRadius.circular(60 * ts),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.all(24 * ts),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(40 * ts),
                child: CustomImageWidget.shimmerBox(),
              ),
            ),
            SizedBox(height: 24 * ts),
            CustomImageWidget.shimmerBox(width: double.infinity, height: 34 * ts),
            SizedBox(height: 14 * ts),
            Center(child: CustomImageWidget.shimmerBox(width: 140 * ts, height: 34 * ts)),
          ],
        ),
      ),
    );
  }
}

class SearchFilterButtonWidget extends StatelessWidget {
  final Future<void> Function()? onOpenFilter;
  const SearchFilterButtonWidget({
    super.key,
    this.onOpenFilter,
  });


  @override
  Widget build(BuildContext context) {
    final double widthSize = MediaQuery.sizeOf(context).width;
    final double heightSize = MediaQuery.sizeOf(context).height;
    final double maxValue = context.watch<SearchProvider>().searchProductModel?.productMaxPrice ?? 1000;

    // Kiosk always uses the round kiosk filter button + bottom sheet.
    return false ? PopupMenuButton<dynamic>(
      menuPadding: EdgeInsets.zero,
      offset: const Offset(0, 40),
      constraints: BoxConstraints(maxWidth: widthSize * 0.21),
      itemBuilder: (BuildContext context) => [
        PopupMenuItem(
          padding: EdgeInsets.zero,
          value: 'open_filter',
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: heightSize * 0.7, maxWidth: widthSize * 0.21),
            child: FilterWidget(maxValue: maxValue),
          ),
        ),
      ],
      onSelected: (dynamic value) {
      },
      padding: const EdgeInsets.symmetric(horizontal: 2),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(Dimensions.paddingSizeSmall)),
      ),
      child: CustomAssetImageWidget(Images.filterSvg, width: 25, height: 25, color: Theme.of(context).primaryColor),
    ) : KioskTap(
      onTap: () {
        if (onOpenFilter != null) {
          onOpenFilter!();
          return;
        }
        showKioskBottomSheet<void>(
          context,
          maxWidth: KioskUI.filterSheetMaxWidth,
          heightFactor: 0.65,
          expandToHeightFactor: true,
          child: Container(
            decoration: const BoxDecoration(
              color: KioskSearchTheme.pageBg,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(28),
                topRight: Radius.circular(28),
              ),
            ),
            child: FilterWidget(maxValue: maxValue),
          ),
        );
      },
      child: Container(
        width: 52,
        height: 52,
        decoration: const BoxDecoration(
          color: KioskSearchTheme.surface,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: const CustomAssetImageWidget(Images.filterSvg, width: 22, height: 22, color: KioskSearchTheme.primary),
      ),
    );
  }
}
