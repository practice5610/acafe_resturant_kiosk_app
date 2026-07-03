import 'package:flutter/material.dart';
import 'package:acafe_customer/common/models/language_model.dart';
import 'package:acafe_customer/common/providers/theme_provider.dart';
import 'package:acafe_customer/common/widgets/branch_button_widget.dart';
import 'package:acafe_customer/common/widgets/custom_asset_image_widget.dart';
import 'package:acafe_customer/common/widgets/custom_image_widget.dart';
import 'package:acafe_customer/common/widgets/custom_text_field_widget.dart';
import 'package:acafe_customer/common/widgets/on_hover_widget.dart';
import 'package:acafe_customer/common/widgets/theme_switch_button_widget.dart';
import 'package:acafe_customer/features/address/providers/location_provider.dart';
import 'package:acafe_customer/features/branch/providers/branch_provider.dart';
import 'package:acafe_customer/features/cart/providers/cart_provider.dart';
import 'package:acafe_customer/features/category/domain/category_model.dart';
import 'package:acafe_customer/features/category/providers/category_provider.dart';
import 'package:acafe_customer/features/checkout/widgets/selected_address_list_widget.dart';
import 'package:acafe_customer/features/home/widgets/cetegory_hover_widget.dart';
import 'package:acafe_customer/features/home/widgets/language_hover_widget.dart';
import 'package:acafe_customer/features/language/providers/language_provider.dart';
import 'package:acafe_customer/features/language/providers/localization_provider.dart';
import 'package:acafe_customer/features/notification/providers/notification_provider.dart';
import 'package:acafe_customer/features/profile/providers/profile_provider.dart';
import 'package:acafe_customer/features/search/providers/search_provider.dart';
import 'package:acafe_customer/features/search/widget/search_recommended_widget.dart';
import 'package:acafe_customer/features/search/widget/search_suggestion_widget.dart';
import 'package:acafe_customer/features/splash/providers/splash_provider.dart';
import 'package:acafe_customer/features/wishlist/providers/wishlist_provider.dart';
import 'package:acafe_customer/helper/debounce_helper.dart';
import 'package:acafe_customer/helper/responsive_helper.dart';
import 'package:acafe_customer/helper/router_helper.dart';
import 'package:acafe_customer/localization/language_constrants.dart';
import 'package:acafe_customer/utill/app_constants.dart';
import 'package:acafe_customer/utill/dimensions.dart';
import 'package:acafe_customer/utill/images.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';


class WebAppBarWidget extends StatefulWidget implements PreferredSizeWidget {
  const    WebAppBarWidget({super.key});

  @override
  State<WebAppBarWidget> createState() => _WebAppBarWidgetState();

  @override
  Size get preferredSize => throw UnimplementedError();
}

class _WebAppBarWidgetState extends State<WebAppBarWidget> {
  final GlobalKey _searchBarKey = GlobalKey();
  final FocusNode _searchFocusNode = FocusNode();
  final FocusNode _appbarSearchFocusNode = FocusNode();

  // Kept for the user-web-app layout; kiosk now routes to the kiosk search page instead.
  // ignore: unused_element
  Future<void> _showSearchDialog() async {
    final SearchProvider searchProvider = Provider.of(context, listen: false);
    RenderBox renderBox = _searchBarKey.currentContext!.findRenderObject() as RenderBox;
    final searchBarPosition = renderBox.localToGlobal(Offset.zero);
    final DebounceHelper debounce = DebounceHelper(milliseconds: 500);
    searchProvider.initHistoryList();
    searchProvider.onClearSearchSuggestion();

    if(searchProvider.searchController.text.isNotEmpty) {
      searchProvider.onChangeAutoCompleteTag(searchText: searchProvider.searchController.text);
    }


    Future.delayed(const Duration(milliseconds: 200)).then((_){
      _searchFocusNode.requestFocus();
    });

    await showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) => Stack(children: [
        Positioned(
          top: searchBarPosition.dy,
          left: searchBarPosition.dx - 50,
          width: renderBox.size.width + 100,
          child: Material(
            color: Provider.of<ThemeProvider>(context, listen: false).darkTheme ? Theme.of(context).cardColor : null,
            elevation: 0,
            borderRadius: BorderRadius.circular(30),
            child: Consumer<SearchProvider>(builder: (context, searchProvider,_) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 410, height: 50,
                  child: CustomTextFieldWidget(
                    radius: 50,
                    hintText: getTranslated('are_you_hungry', context),
                    isShowBorder: true,
                    fillColor: Theme.of(context).cardColor,
                    isShowPrefixIcon: searchProvider.searchLength == 0,
                    prefixIconUrl: Images.search,
                    prefixIconColor: Theme.of(context).hintColor,
                    suffixIconColor: Theme.of(context).hintColor,
                    onChanged: (str){
                      searchProvider.getSearchText(str);
                      debounce.run(() {
                        if(str.isNotEmpty) {
                          searchProvider.onChangeAutoCompleteTag(searchText: str);
                        }
                      });

                    },
                    focusNode: _searchFocusNode,
                    controller: searchProvider.searchController,
                    inputAction: TextInputAction.search,
                    isIcon: true,
                    isShowSuffixIcon: searchProvider.searchLength > 0,
                    suffixIconUrl: Images.cancelSvg,
                    onSuffixTap: (){
                      searchProvider.searchController.clear();
                      searchProvider.getSearchText('');

                    },

                    onSubmit: (text) {
                      if (searchProvider.searchController.text.isNotEmpty) {
                        RouterHelper.getSearchResultRoute(searchProvider.searchController.text);
                        searchProvider.searchDone();
                      }
                    },
                  ),
                ),
                // Recent Searches and Recommendations
                const SizedBox(height: Dimensions.paddingSizeExtraSmall),
                Container(
                  width: 600,
                  constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),

                  decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      boxShadow: [BoxShadow(
                        color: Theme.of(context).textTheme.bodyLarge!.color!.withValues(alpha:0.05),
                        offset: const Offset(0, 5),
                        spreadRadius: 0,
                        blurRadius: 15,
                      )]
                  ),
                  padding: const EdgeInsets.symmetric(vertical: Dimensions.paddingSizeLarge, horizontal: 30),
                  child:  searchProvider.searchLength > 0
                      ?  SearchSuggestionWidget(searchedText: searchProvider.searchController.text)
                      : const SearchRecommendedWidget(),
                ),
              ],
            )
            ),
          ),
        ),

      ]),
    );


  }



  List<PopupMenuEntry<Object>> popUpMenuList(BuildContext context) {
    List<PopupMenuEntry<Object>> list = <PopupMenuEntry<Object>>[];
    List<CategoryModel>? categoryList =  Provider.of<CategoryProvider>(context, listen: false).categoryList;
    list.add(
        PopupMenuItem(
          padding: EdgeInsets.zero,
          value: categoryList,
          child: MouseRegion(
            onExit: (_)=> context.pop(),
            child: CategoryHoverWidget(categoryList: categoryList),
          ),
        ));
    return list;
  }

  List<PopupMenuEntry<Object>> popUpLanguageList(BuildContext context) {
    List<PopupMenuEntry<Object>> languagePopupMenuEntryList = <PopupMenuEntry<Object>>[];
    List<LanguageModel> languageList =  AppConstants.languages;
    languagePopupMenuEntryList.add(
        PopupMenuItem(
          padding: EdgeInsets.zero,
          value: languageList,
          child: MouseRegion(
            onExit: (_)=> context.pop(),
            child: LanguageHoverWidget(languageList: languageList),
          ),
        ));
    return languagePopupMenuEntryList;
  }



  _showPopupMenu(Offset offset, BuildContext context, bool isCategory) async {
    double left = offset.dx;
    double top = offset.dy;
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;

    List<CategoryModel>? categoryList =  Provider.of<CategoryProvider>(context, listen: false).categoryList;
    if(isCategory && (categoryList?.isNotEmpty ?? false) || !isCategory) {
      await showMenu(
        context: context,
        position: RelativeRect.fromLTRB(left, top, overlay.size.width, overlay.size.height),
        items: isCategory ? popUpMenuList(context) : popUpLanguageList(context),
        elevation: 8.0,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(Dimensions.radiusDefault),
          ),
        ),

      );

    }


  }

  @override
  void initState() {

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final SplashProvider splashProvider = Provider.of<SplashProvider>(context, listen: false);
    final CategoryProvider categoryProvider = Provider.of<CategoryProvider>(context, listen: false);
    final ProfileProvider profileProvider = Provider.of<ProfileProvider>(context, listen: false);
    final BranchProvider branchProvider = Provider.of<BranchProvider>(context, listen: false);


    Provider.of<LanguageProvider>(context, listen: false).initializeAllLanguages(context);
    final LanguageModel currentLanguage = AppConstants.languages.firstWhere((language) => language.languageCode == Provider.of<LocalizationProvider>(context, listen: false).locale.languageCode);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [BoxShadow(
          blurRadius: 15, offset: const Offset(0, 5),
          color: Theme.of(context).textTheme.bodyLarge!.color!.withValues(alpha:0.05),
        )],
      ),
      child: Column(children: [

        Center(child: SizedBox( width: Dimensions.webScreenWidth, child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Dimensions.paddingSizeExtraSmall),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [

            if(!splashProvider.isRestaurantOpenNow(context))
              Text('${getTranslated('restaurant_is_close_now', context)}', style: rubikRegular.copyWith(fontSize: Dimensions.fontSizeLarge)),

            if(splashProvider.isRestaurantOpenNow(context)) GestureDetector(
              onTap: () {
                if(ModalRoute.of(context)?.settings.name != RouterHelper.checkoutScreen) {
                  ResponsiveHelper.showDialogOrBottomSheet(context, SelectedAddressListWidget(
                    currentBranch: branchProvider.getBranch(),
                    isFromAppbar: true,
                  ));
                }

              },
              child: Consumer<LocationProvider>(
                builder: (context, locationProvider, _) {
                  return  locationProvider.isLoading ? const SizedBox() : Row(children: [
                    CustomAssetImageWidget(
                      Images.locationPlacemarkSvg, color: Theme.of(context).primaryColor,
                      width: Dimensions.paddingSizeDefault, height: Dimensions.paddingSizeDefault,
                    ),
                    const SizedBox(width: Dimensions.paddingSizeExtraSmall),


                    Text(locationProvider.currentAddress?.address ?? getTranslated('no_location_selected', context)!, style: rubikRegular.copyWith(fontSize: Dimensions.fontSizeLarge),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(width: Dimensions.fontSizeExtraSmall),

                    const Icon(Icons.expand_more),

                  ]);
                },
              ),
            ),

            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              const ThemeSwitchButtonWidget(),
              const SizedBox(width: Dimensions.paddingSizeExtraLarge),

              if(AppConstants.languages.length > 1) SizedBox(
                height: Dimensions.paddingSizeLarge,
                child: OnHoverWidget(
                  builder: (isHovered) {
                    final color = isHovered ? Theme.of(context).primaryColor : Theme.of(context).textTheme.titleLarge?.color;

                    return MouseRegion(
                      onHover: (details) {
                        _showPopupMenu(details.position, context, false);
                      },
                      child: Row(children: [
                        Text('${currentLanguage.languageCode?.toUpperCase()}', style: rubikSemiBold.copyWith(
                          color: color, fontSize: Dimensions.fontSizeExtraSmall,
                        )),
                        const SizedBox(width: Dimensions.paddingSizeExtraSmall),

                        Icon(Icons.expand_more, color: color, size: Dimensions.paddingSizeLarge)
                      ]),
                    );
                  },
                ),
              ),
            ]),
          ]),
        ))),

        Container(height: 0.5, color: Theme.of(context).dividerColor.withValues(alpha:0.2)),

        Expanded(child: Center(child: SizedBox(width: Dimensions.webScreenWidth, child: Row(mainAxisAlignment: MainAxisAlignment.start, children: [
          InkWell(
            onTap: () {
              RouterHelper.getMainRoute(action: RouteAction.pushReplacement);
            },
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Provider.of<SplashProvider>(context).baseUrls != null?  Consumer<SplashProvider>(
                builder:(context, splash, child) => CustomImageWidget(
                  image: '${splash.baseUrls?.restaurantImageUrl}/${splash.configModel!.restaurantLogo}',
                  placeholder: Images.webAppBarLogo,
                  fit: BoxFit.contain,
                  width: 120, height: 80,
                )): const SizedBox(),
            ),
          ),

          OnHoverWidget(builder: (isHover)=> InkWell(
            onTap: () =>RouterHelper.getHomeRoute(fromAppBar: 'true'),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeDefault),
              child: Text(
                getTranslated('home', context)!, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: rubikRegular.copyWith(
                  color: isHover ? Theme.of(context).primaryColor : Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
            ),
          )),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeSmall),
            child: MouseRegion(
              onHover: (details) {
                if(categoryProvider.categoryList != null) {
                  _showPopupMenu(details.position, context, true);
                }
              },
              child: OnHoverWidget(builder: (isHover)=> Text(
                getTranslated('categories', context)!, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: rubikRegular.copyWith(
                  color: isHover ? Theme.of(context).primaryColor : Theme.of(context).textTheme.bodyLarge?.color,
                ),
              )),
            ),
          ),

          const Spacer(),

          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: SizedBox(
              key: _searchBarKey,
              width: 410, height: 50,
              child: Consumer<SearchProvider>(builder: (context,search,_)=> CustomTextFieldWidget(
                // Kiosk: open the full kiosk search page (same as small screens),
                // not the old user-web-app search overlay.
                onTap: () => RouterHelper.getSearchRoute(),
                isEnabled: Provider.of<BranchProvider>(context, listen: false).getBranchId() != -1,
                focusNode: _appbarSearchFocusNode,
                radius: 50,
                hintText: getTranslated('are_you_hungry', context),
                isShowBorder: true,
                fillColor: Theme.of(context).cardColor,
                isShowPrefixIcon: search.searchLength == 0,
                prefixIconUrl: Images.search,
                prefixIconColor: Theme.of(context).hintColor,
                suffixIconColor: Theme.of(context).hintColor,
                onChanged: (str){
                  search.getSearchText(str);
                },

                controller: search.searchController,
                inputAction: TextInputAction.search,
                isIcon: true,
                isShowSuffixIcon: search.searchLength > 0,
                suffixIconUrl: Images.cancelSvg,
                onSuffixTap: (){
                  search.searchController.clear();
                  search.getSearchText('');

                },

                onSubmit: (text) {
                  if (search.searchController.text.isNotEmpty) {
                    RouterHelper.getSearchResultRoute(search.searchController.text);
                    search.searchDone();
                  }
                },
              )),
            ),
          ),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeExtraLarge),
            child: BranchButtonWidget(isPopup: true),
          ),

          InkWell(
            onTap: ()=> RouterHelper.getDashboardRoute('favourite'),
            child: OnHoverWidget(builder: (isHover) {
              return Consumer<WishListProvider>(
                builder: (context, wishlistProvider, _) {
                  return  CountIconView(count: '${wishlistProvider.wishList?.length ?? 0}', image: Images.navFavoriteSvg);
                }
              );
            }),
          ),

          InkWell(
            onTap: ()=> RouterHelper.getDashboardRoute('cart'),
            child: OnHoverWidget(builder: (isHover)=> CountIconView(
              count: Provider.of<CartProvider>(context).cartList.length.toString(),
              image: Images.navOrderSvg,
            )),
          ),

          InkWell(
            onTap: () {
              // Opening the notification screen marks everything read; clear the
              // badge here too so it reflects immediately.
              Provider.of<NotificationProvider>(context, listen: false).markAsRead();
              RouterHelper.getNotificationRoute();
            },
            child: OnHoverWidget(builder: (isHover)=> Consumer<NotificationProvider>(
              builder: (context, notificationProvider, _) => CountIconView(
                count: notificationProvider.unreadCount.toString(),
                icon: Icons.notifications_none,
                showZero: false,
              ),
            )),
          ),


          OnHoverWidget(builder: (isHover)=> Padding(
            padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeExtraLarge),
            child: InkWell(
              onTap:()=> RouterHelper.getProfileRoute(),
              child: profileProvider.userInfoModel?.image != null ?
              ClipOval(
                child: CustomImageWidget(
                  image: "${splashProvider.baseUrls!.customerImageUrl}/${profileProvider.userInfoModel?.image}",
                  fit: BoxFit.cover,
                  height: Dimensions.paddingSizeExtraLarge,
                  width: Dimensions.paddingSizeExtraLarge,
                ),
              ) : CustomAssetImageWidget(
                fit: BoxFit.cover,
                Images.navUserSvg, width: Dimensions.paddingSizeLarge,
                color: isHover ? Theme.of(context).primaryColor : Theme.of(context).textTheme.bodyLarge?.color?.withValues(alpha:0.5),
              ),
            ),
          )),

          OnHoverWidget(builder: (isHover)=> InkWell(
            onTap: ()=> RouterHelper.getDashboardRoute('menu'),
            child: Icon(
              Icons.menu, size: Dimensions.paddingSizeExtraLarge,
              color: Theme.of(context).primaryColor,
            ),
          )),
        ])))),

      ]),
    );
  }

  @override
  // ignore: override_on_non_overriding_member
  Size get preferredSize => const Size(double.maxFinite, 50);
}

class CountIconView extends StatelessWidget {
  final String? count;
  final IconData? icon;
  final String? image;
  final Color? color;
  // When false, the badge is hidden if the count is 0 (used by the bell).
  final bool showZero;
  const CountIconView({
    super.key, this.count, this.icon, this.image, this.color, this.showZero = true,
  });

  @override
  Widget build(BuildContext context) {
    final bool hideBadge = !showZero && (count == null || count == '0');
    return OnHoverWidget(builder: (isHover)=> Padding(
      padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeExtraLarge),
      child: Stack(clipBehavior: Clip.none, children: [
        image != null ? CustomAssetImageWidget(image!, width: Dimensions.paddingSizeLarge,
          color: isHover ? Theme.of(context).primaryColor : Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha:0.5),
        ) : Icon(
          icon, size: Dimensions.paddingSizeLarge,
          color: color ?? (isHover ? Theme.of(context).primaryColor : Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha:0.5)),
        ),

        if(!hideBadge) Positioned(top: -7, right: -7, child: Container(
          padding: const EdgeInsets.all(4),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle, color: Theme.of(context).primaryColor,
            border: Border.all(color: Colors.white, width: 0.5),
          ),
          child: Center(child: Text('${count ?? 0}', style: rubikSemiBold.copyWith(color: Colors.white, fontSize: 8))),
        ))]),
    ));
  }
}

