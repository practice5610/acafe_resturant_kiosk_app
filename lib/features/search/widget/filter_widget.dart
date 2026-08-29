// ignore_for_file: unused_import
import 'package:flutter/material.dart';
import 'package:acafe_customer/common/models/config_model.dart'; // Halal filter (commented below)
import 'package:acafe_customer/common/widgets/custom_button_widget.dart';
import 'package:acafe_customer/common/widgets/custom_single_child_list_widget.dart';
import 'package:acafe_customer/features/category/providers/category_provider.dart';
import 'package:acafe_customer/features/search/search_flow_helper.dart';
import 'package:acafe_customer/features/search/providers/search_provider.dart';
import 'package:acafe_customer/features/search/widget/kiosk_search_theme.dart';
import 'package:acafe_customer/features/splash/providers/splash_provider.dart';
import 'package:acafe_customer/helper/responsive_helper.dart';
import 'package:acafe_customer/localization/language_constrants.dart';
import 'package:acafe_customer/utill/dimensions.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

/// Formats a price bound for the filter chip: drops a trailing ".0" (10.0 → 10)
/// but keeps real decimals (9.99 → 9.99).
String _trimPrice(num? value) {
  if (value == null) return '0';
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value.toStringAsFixed(2);
}

class FilterWidget extends StatelessWidget {
  final double? maxValue;
  final VoidCallback? onApply;
  final VoidCallback? onReset;

  /// Optional section rendered above "Sort by".
  ///
  /// The kiosk puts its allergen entry point here. It stays a slot rather than
  /// being built in because this sheet is shared with the customer web app's
  /// search results, which has no allergen flow — and because the allergen
  /// selection is not part of [SearchProvider]'s filter state, so it must not
  /// be wired into Apply / Reset.
  final Widget? leadingSection;

  const FilterWidget({
    super.key,
    required this.maxValue,
    this.onApply,
    this.onReset,
    this.leadingSection,
  });

  @override
  Widget build(BuildContext context) {
    final CategoryProvider categoryProvider = Provider.of<CategoryProvider>(context, listen: true);
    // App currency symbol (e.g. £) used for the price-tier chips instead of '$'.
    final String currencySymbol =
        Provider.of<SplashProvider>(context, listen: false).configModel?.currencySymbol ?? '\$';
    // Halal filter hidden (café — not relevant)
    // final ConfigModel ? configModel = Provider.of<SplashProvider>(context, listen: true).configModel;

    return Consumer<SearchProvider>(
      builder: (context, searchProvider, child) {

        bool canNotFilter = !searchProvider.hasActiveFilters(categoryProvider.selectedCategoryList);

        final Widget scrollBody = SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: Dimensions.paddingSizeSmall),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: Dimensions.paddingSizeLarge),

            if (leadingSection != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: Dimensions.paddingSizeLarge),
                child: leadingSection!,
              ),
              const SizedBox(height: Dimensions.paddingSizeLarge),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: Dimensions.paddingSizeLarge),
                child: Divider(
                    color: Theme.of(context)
                        .textTheme
                        .bodyLarge
                        ?.color
                        ?.withValues(alpha: 0.1)),
              ),
              const SizedBox(height: Dimensions.paddingSizeLarge),
            ],

            ///sort by
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeLarge),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(getTranslated('sort_by', context)!, style: loewBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: KioskSearchTheme.primary)),
                const SizedBox(height: Dimensions.paddingSizeDefault),


                CustomSingleChildListWidget(
                  physics: const NeverScrollableScrollPhysics(),
                  isWrap: true,
                  wrapSpacing: Dimensions.paddingSizeSmall,
                  runSpacing: Dimensions.paddingSizeSmall,
                  itemCount: searchProvider.getSortByList.length,
                  itemBuilder: (index) {
                    final bool selected = searchProvider.selectedSortByIndex == index;
                    return InkWell(
                      borderRadius: BorderRadius.circular(30),
                      onTap: () => searchProvider.onChangeSortByIndex(index),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeDefault, vertical: Dimensions.paddingSizeSmall),
                        decoration: BoxDecoration(
                          color: selected ? KioskSearchTheme.primary : KioskSearchTheme.surface,
                          border: Border.all(
                            color: selected ? KioskSearchTheme.primary : KioskSearchTheme.border,
                          ),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Text(
                          getTranslated(searchProvider.getSortByList[index], context)!,
                          textAlign: TextAlign.center,
                          style: loewBold.copyWith(
                            fontSize: Dimensions.fontSizeSmall,
                            color: selected ? KioskSearchTheme.creamText : KioskSearchTheme.primary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    );
                  },
                ),

              ]),
            ),
            const SizedBox(height: Dimensions.paddingSizeLarge),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeLarge),
              child: Divider(color: Theme.of(context).textTheme.bodyLarge?.color?.withValues(alpha:0.1)),
            ),


            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeLarge),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [


                /// Price section
                Text(getTranslated('price', context)!, style: loewBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: KioskSearchTheme.primary)),
                const SizedBox(height: Dimensions.paddingSizeDefault),

                SizedBox(width: Dimensions.webScreenWidth, height: 38, child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: searchProvider.priceFilterList.length,
                  itemBuilder: (context, index) {
                    final bool selected = searchProvider.selectedPriceIndex == index;
                    final range = searchProvider.priceFilterList[index];
                    // Show the actual price range on the chip, e.g. "£0 - £10".
                    final String label =
                        '$currencySymbol${_trimPrice(range.first)} - $currencySymbol${_trimPrice(range.last)}';
                    return Padding(
                      padding: const EdgeInsets.only(right: Dimensions.paddingSizeSmall),
                      child: Material(
                        color: selected ? KioskSearchTheme.primary : KioskSearchTheme.surface,
                        borderRadius: BorderRadius.circular(30),
                        clipBehavior: Clip.hardEdge,
                        child: InkWell(
                          onTap: () => searchProvider.updatePriceFilter(index),
                          borderRadius: BorderRadius.circular(30),
                          child: Container(
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(
                              horizontal: Dimensions.paddingSizeDefault,
                              vertical: Dimensions.paddingSizeExtraSmall,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: selected ? KioskSearchTheme.primary : KioskSearchTheme.border,
                              ),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Text(
                              label,
                              textAlign: TextAlign.center,
                              style: loewBold.copyWith(
                                fontSize: Dimensions.fontSizeSmall,
                                color: selected ? KioskSearchTheme.creamText : KioskSearchTheme.primary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                )),
                const SizedBox(height: Dimensions.paddingSizeLarge),

                /// Category section
                Text(getTranslated('category', context)!, style: loewBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: KioskSearchTheme.primary)),
                const SizedBox(height: Dimensions.paddingSizeDefault),

                Consumer<CategoryProvider>(
                  builder: (context, category, child) {
                    return category.categoryList != null ? SizedBox(
                      child: GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisExtent: Dimensions.paddingSizeDefault * 2,
                          ),
                          itemCount: category.categoryList?.length,
                          itemBuilder: (context,index){
                            return Container(
                              decoration: BoxDecoration(borderRadius: BorderRadius.circular(Dimensions.radiusSmall)),
                              child: InkWell(
                                onTap: (){
                                  if(category.categoryList?[index].id != null) {
                                    category.updateSelectCategory(id: category.categoryList?[index].id ?? 0);
                                  }
                                },
                                borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
                                child: Row(mainAxisSize: MainAxisSize.min, children: [

                                  Container(
                                    transform: Matrix4.translationValues(-2, 0,0),
                                    child: Checkbox(
                                      value: category.selectedCategoryList.contains(category.categoryList?[index].id),
                                      activeColor: Theme.of(context).primaryColor,
                                      checkColor: Theme.of(context).primaryColor,
                                      fillColor: WidgetStateProperty.all(Colors.transparent),
                                      side: WidgetStateBorderSide.resolveWith((states) {
                                        if(states.contains(WidgetState.pressed)){
                                          return BorderSide(color: category.selectedCategoryList.contains(category.categoryList?[index].id) ? Theme.of(context).primaryColor : Theme.of(context).hintColor);
                                        }
                                        else{
                                          return BorderSide(color: category.selectedCategoryList.contains(category.categoryList?[index].id) ? Theme.of(context).primaryColor : Theme.of(context).hintColor);
                                        }
                                      }),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Dimensions.radiusSmall)),
                                      onChanged:(bool? newValue) {
                                        if(category.categoryList?[index].id != null) {
                                          category.updateSelectCategory(id: category.categoryList?[index].id ?? 0);
                                        }
                                      },
                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      visualDensity: const VisualDensity(horizontal: -4, vertical: -3),
                                    ),
                                  ),

                                  Flexible(
                                    child: Text(
                                      category.categoryList?[index].name ?? '',
                                      textAlign: TextAlign.center,
                                      style: rubikRegular.copyWith(
                                          fontSize: ResponsiveHelper.isDesktop(context) ? Dimensions.fontSizeDefault : Dimensions.fontSizeSmall,
                                          color: category.selectedCategoryList.contains(category.categoryList?[index].id) ? Theme.of(context).textTheme.bodyMedium?.color : Theme.of(context).hintColor),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: Dimensions.paddingSizeDefault),

                                ]),
                              ),
                            );
                          }
                      ),
                    )
                        : const SizedBox.shrink();
                  },
                ),

              ]),
            ),
            ],
          ),
        );

        final Widget footer = Container(
          decoration: BoxDecoration(
            color: KioskSearchTheme.surface,
            boxShadow: [
              BoxShadow(
                offset: const Offset(0, -2),
                blurRadius: 12,
                spreadRadius: 0,
                color: Colors.black.withValues(alpha: 0.06),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeLarge, vertical: Dimensions.paddingSizeDefault),
            child: Row(children: [

              Expanded(child: CustomButtonWidget(
                onTap: () {
                  searchProvider.resetFilterData(categoryProvider: categoryProvider);
                  onReset?.call();
                },
                height: 52,
                btnTxt: getTranslated('reset', context),
                textStyle: loewBold.copyWith(color: KioskSearchTheme.primary),
                borderRadius: 30,
                backgroundColor: KioskSearchTheme.pageBg,
              )),
              const SizedBox(width: Dimensions.paddingSizeDefault),

              Expanded(flex: 2, child: CustomButtonWidget(
                isLoading: searchProvider.isLoading,
                height: 52,
                btnTxt: getTranslated('apply', context),
                textStyle: loewBold.copyWith(color: KioskSearchTheme.creamText),
                borderRadius: 30,
                backgroundColor: KioskSearchTheme.primary,
                onTap: canNotFilter ? null :  () async {
                  if (onApply != null) {
                    onApply!();
                  } else {
                    searchProvider.searchProduct(
                      offset: 1,
                      name: searchProvider.searchText,
                      context: context,
                    );
                  }

                  if(context.mounted) {
                    context.pop();
                  }
                },
              )),

            ]),
          ),
        );

        return LayoutBuilder(
          builder: (context, constraints) {
            final bool boundedHeight = constraints.maxHeight < double.infinity;

            return Column(
              mainAxisSize:
                  boundedHeight ? MainAxisSize.max : MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ResponsiveHelper.isDesktop(context) ? Padding(
                  padding: const EdgeInsets.all(Dimensions.paddingSizeLarge).copyWith(bottom: 0),
                  child: const _HeaderWidget(middleExist: false),
                ) : Padding(
                  padding: const EdgeInsets.all(Dimensions.paddingSizeLarge).copyWith(bottom: 0),
                  child: const _HeaderWidget(),
                ),
                if (boundedHeight)
                  Expanded(child: scrollBody)
                else
                  scrollBody,
                footer,
              ],
            );
          },
        );
      },
    );
  }
}

class _HeaderWidget extends StatelessWidget {
  final bool middleExist;
  const _HeaderWidget({this.middleExist = true});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [

      Text(getTranslated('filter', context)!, textAlign: TextAlign.center, style: loewExtraBold.copyWith(fontSize: Dimensions.fontSizeExtraLarge, color: KioskSearchTheme.primary)),

      middleExist ?  Container(
        transform: Matrix4.translationValues(0, -10, 0),
        width: 35, height: 4, decoration: BoxDecoration(
        color: Theme.of(context).hintColor.withValues(alpha:0.3),
        borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
      ),
        padding: const EdgeInsets.symmetric(vertical: Dimensions.paddingSizeSmall),
      ) : const SizedBox(width: Dimensions.paddingSizeLarge),
    
      InkWell(
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        onTap: () => context.pop(),
        child: Container(
            padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
            transform: Matrix4.translationValues(0, -4, 0),
            decoration: const BoxDecoration(
              color: KioskSearchTheme.primary,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.close, size: Dimensions.paddingSizeDefault, color: KioskSearchTheme.creamText)),
      ),
    
    ]);
  }
}
