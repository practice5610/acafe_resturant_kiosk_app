import 'dart:math';
import 'package:flutter/material.dart';
import 'package:acafe_customer/common/responsive/kiosk_layout.dart';
import 'package:acafe_customer/common/widgets/custom_image_widget.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_tap.dart';
import 'package:acafe_customer/features/search/providers/search_provider.dart';
import 'package:acafe_customer/features/splash/providers/splash_provider.dart';
import 'package:acafe_customer/helper/router_helper.dart';
import 'package:acafe_customer/localization/language_constrants.dart';
import 'package:acafe_customer/utill/dimensions.dart';
import 'package:acafe_customer/utill/images.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:provider/provider.dart';
import 'package:shimmer_animation/shimmer_animation.dart';

class SearchRecommendedWidget extends StatelessWidget {
  const SearchRecommendedWidget({
    super.key,
  });

  @override
  Widget build(BuildContext context) {

    return Consumer<SearchProvider>(
        builder: (context, searchProvider, _) {
          return SingleChildScrollView(
            primary: true,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeLarge),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              /// for resent search section
              const SizedBox(height: Dimensions.paddingSizeDefault),
              if(searchProvider.historyList.isNotEmpty) ...[
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(getTranslated('recent_searches', context)!, style: rubikBold.copyWith(
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  )),

                  KioskTap(
                    onTap: searchProvider.clearSearchAddress,
                    child: Text(getTranslated('clear_all', context)!, style: rubikSemiBold.copyWith(
                      color: Theme.of(context).hintColor, fontSize: Dimensions.fontSizeSmall,
                    )),
                  ),
                ]),
                const SizedBox(height: Dimensions.paddingSizeDefault),
              ],

              /// for recent search list section
              if(searchProvider.historyList.isNotEmpty) ...[
                ListView.builder(
                  itemCount: min(searchProvider.historyList.length, 10),
                  primary: false,
                  shrinkWrap: true,
                  reverse: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemBuilder: (context, index) => Column(children: [

                    KioskTap(
                      onTap: () {
                        searchProvider.searchProduct(name: searchProvider.historyList[index], offset: 1, context: context,);
                        RouterHelper.getSearchResultRoute(searchProvider.historyList[index].replaceAll(' ', '-'));
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: Dimensions.paddingSizeSmall),
                        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [

                          Text(
                            searchProvider.historyList[index],
                            style: rubikSemiBold.copyWith(color: Theme.of(context).hintColor, fontSize: Dimensions.fontSizeSmall),
                          ),

                          KioskTap(
                            onTap: () {
                              searchProvider.removeHistoryItemByIndex(index);
                            },
                            child: Icon(Icons.close, size: Dimensions.fontSizeExtraLarge, color: Theme.of(context).hintColor),
                          ),

                        ]),
                      ),
                    ),

                    Divider(height: 0, color: Theme.of(context).dividerColor.withValues(alpha:0.05)),

                  ]),
                ),
                const SizedBox(height: Dimensions.paddingSizeLarge),
              ],


              /// for recommended
              _RecommendedCategoryWidget(searchProvider: searchProvider)

            ]),
          );
        }
    );
  }
}

class _RecommendedCategoryWidget extends StatelessWidget {
  const _RecommendedCategoryWidget({
    required this.searchProvider,
  });

  final SearchProvider searchProvider;

  @override
  Widget build(BuildContext context) {
    final SplashProvider splashProvider = Provider.of<SplashProvider>(context, listen: false);

    if(searchProvider.searchRecommendModel == null) return const _RecommendedCategoryShimmerWidget();

    if(searchProvider.searchRecommendModel?.categories.isEmpty ?? false) return const SizedBox.shrink();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(getTranslated('recommended', context)!, style: rubikBold.copyWith(
        color: Theme.of(context).textTheme.bodyLarge?.color,
      )),
      const SizedBox(height: Dimensions.paddingSizeDefault),

      LayoutBuilder(
        builder: (context, constraints) {
          final double w = constraints.maxWidth;
          final bool landscape =
              KioskLayout.isLandscape(context, constraints);
          final int cols = w < 520
              ? 3
              : (landscape && w > 1100)
                  ? 6
                  : w > 900
                      ? 5
                      : 4;
          return GridView.builder(
        primary: false,
        shrinkWrap: true,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          mainAxisSpacing: Dimensions.paddingSizeExtraSmall,
          crossAxisSpacing: Dimensions.paddingSizeExtraSmall,
          mainAxisExtent: landscape ? 96 : 110,
        ),
        itemCount: searchProvider.searchRecommendModel?.categories.length,
        itemBuilder: (context, index) => KioskTap(
          onTap: () {
            // Kiosk: category tap runs a product search (no web category page).
            final String name = searchProvider.searchRecommendModel!.categories[index].name ?? '';
            searchProvider.searchProduct(name: name, offset: 1, context: context);
            RouterHelper.getSearchResultRoute(name.replaceAll(' ', '-'));
          },
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).primaryColorLight),
              borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
            ),
            clipBehavior: Clip.hardEdge,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
                child: CustomImageWidget(
                  image: '${splashProvider.baseUrls?.categoryImageUrl}/${searchProvider.searchRecommendModel?.categories[index].image}',
                  placeholder: Images.placeholderImage,
                  width: 30,
                  height: 30,
                ),
              ),
              const SizedBox(height: Dimensions.paddingSizeExtraSmall),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
                  child: Text(
                    '${searchProvider.searchRecommendModel?.categories[index].name}',
                    style: rubikRegular.copyWith(fontSize: Dimensions.fontSizeSmall),
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),

            ]),
          ),
        ),
          );
        },
      ),
      const SizedBox(height: Dimensions.paddingSizeLarge),

    ]);
  }
}

class _RecommendedCategoryShimmerWidget extends StatelessWidget {
  const _RecommendedCategoryShimmerWidget();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Shimmer for the header text
        Shimmer(
          interval: const Duration(seconds: 1), // Delay between shimmers
          color: Theme.of(context).shadowColor.withValues(alpha:0.2), // Base color
          colorOpacity: 0.1, // Opacity of shimmer
          enabled: true, // Enable shimmer effect
          child: Container(
            height: 20,
            width: 150,
            color: Theme.of(context).shadowColor.withValues(alpha:0.2),
            margin: const EdgeInsets.only(bottom: Dimensions.paddingSizeDefault),
          ),
        ),

        // Shimmer for the grid items
        LayoutBuilder(
          builder: (context, constraints) {
            final double w = constraints.maxWidth;
            final bool landscape =
                KioskLayout.isLandscape(context, constraints);
            final int cols = w < 520
                ? 3
                : (landscape && w > 1100)
                    ? 6
                    : w > 900
                        ? 5
                        : 4;
            return GridView.builder(
          primary: false,
          shrinkWrap: true,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            mainAxisExtent: landscape ? 96 : 110,
            crossAxisSpacing: Dimensions.paddingSizeDefault,
            mainAxisSpacing: Dimensions.paddingSizeDefault,
          ),
          itemCount: 8, // Fixed number of shimmer items
          itemBuilder: (context, index) => Shimmer(
            duration: const Duration(seconds: 2),
            interval: const Duration(milliseconds: 300),
            color: Theme.of(context).shadowColor.withValues(alpha:0.2),
            colorOpacity: 0.5,
            enabled: true,
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).shadowColor.withValues(alpha:0.01),
                borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
              ),
              margin: const EdgeInsets.all(Dimensions.paddingSizeDefault / 2),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: Theme.of(context).shadowColor.withValues(alpha:0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  const SizedBox(height: Dimensions.paddingSizeExtraSmall),

                  Container(
                    height: 15,
                    width: 60,
                    color: Theme.of(context).shadowColor.withValues(alpha:0.2),
                    margin: const EdgeInsets.symmetric(vertical: 4),
                  ),
                ],
              ),
            ),
          ),
            );
          },
        ),
      ],
    );
  }
}

