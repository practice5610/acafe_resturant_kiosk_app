import 'package:flutter/material.dart';
import 'package:acafe_customer/common/responsive/kiosk_layout.dart';
import 'package:acafe_customer/common/responsive/kiosk_responsive.dart';
import 'package:acafe_customer/common/widgets/custom_text_field_widget.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_ui.dart';
import 'package:acafe_customer/features/search/providers/search_provider.dart';
import 'package:acafe_customer/features/search/widget/kiosk_search_theme.dart';
import 'package:acafe_customer/features/search/widget/search_recommended_widget.dart';
import 'package:acafe_customer/features/search/widget/search_suggestion_widget.dart';
import 'package:acafe_customer/helper/debounce_helper.dart';
import 'package:acafe_customer/helper/router_helper.dart';
import 'package:acafe_customer/localization/language_constrants.dart';
import 'package:acafe_customer/utill/dimensions.dart';
import 'package:acafe_customer/utill/images.dart';
import 'package:provider/provider.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();

  final FocusNode _searchBarFocus = FocusNode();
  final DebounceHelper debounce = DebounceHelper(milliseconds: 500);

  @override
  void initState() {
    super.initState();

    final SearchProvider searchProvider = Provider.of<SearchProvider>(context, listen: false);

    searchProvider.initHistoryList();
    searchProvider.onClearSearchSuggestion();

    _searchController.addListener(_onChange);

    _searchBarFocus.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    super.dispose();
    _searchBarFocus.removeListener(_onFocusChange);
  }

  void _onFocusChange() {
    if(mounted){
      setState(() {});
    }
  }

  void _onChange() {
    if(_searchController.text.isEmpty) {
      Provider.of<SearchProvider>(context, listen: false).onClearSearchSuggestion();
    }
    if(mounted){
      setState(() {});
    }
  }


  @override
  Widget build(BuildContext context) {
    final double s = KioskLayout.scaleOf(context);
    final bool landscape = KioskLayout.isLandscape(context);
    final double toolbar = ((landscape ? 72 : 88) *
            s /
            KioskResponsive.scale(1080))
        .clamp(landscape ? 56.0 : 72.0, landscape ? 96.0 : 160.0);
    return Scaffold(
      backgroundColor: KioskSearchTheme.pageBg,
      // Kiosk always uses the kiosk search header, even on large screens.
      appBar: AppBar(
        toolbarHeight: toolbar,
        leadingWidth: 0,
        backgroundColor: KioskSearchTheme.pageBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        title: Consumer<SearchProvider>(
          builder: (context, searchProvider, _) {
            return Padding(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).size.height * 0.015,
                bottom: Dimensions.paddingSizeSmall,
                right: Dimensions.paddingSizeLarge,
                left: Dimensions.paddingSizeDefault,
              ),
              child: Row(children: [
                const KioskBackButton(),
                const SizedBox(width: Dimensions.paddingSizeSmall),
                Expanded(
                  child: _KioskSearchField(
                    child: CustomTextFieldWidget(
                      hintText: getTranslated('search_items_here', context),
                      isShowBorder: false,
                      controller: _searchController,
                      focusNode: _searchBarFocus,
                      inputAction: TextInputAction.search,
                      isIcon: true,
                      suffixIconUrl: Images.closeSvg,
                      isShowSuffixIcon: _searchController.text.isNotEmpty,
                      onSuffixTap: () => _searchController.clear(),
                      onSubmit: (text) {
                        if (_searchController.text.trim().isNotEmpty) {
                          searchProvider.saveSearchAddress(_searchController.text);
                          searchProvider.searchProduct(
                            name: _searchController.text,
                            offset: 1,
                            context: context,
                          );
                          RouterHelper.getSearchResultRoute(
                            _searchController.text.replaceAll(' ', '-'),
                          );
                        }
                      },
                      onChanged: (String text) => debounce.run(() {
                        if (text.isNotEmpty) {
                          searchProvider.onChangeAutoCompleteTag(searchText: text);
                        }
                      }),
                    ),
                  ),
                ),
              ]),
            );
          },
        ),
      ),

      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: KioskResponsive.designWidth,
            ),
            child: _searchController.text.isNotEmpty
                ? SearchSuggestionWidget(searchedText: _searchController.text)
                : const SearchRecommendedWidget(),
          ),
        ),
      ),
    );
  }
}

/// White rounded "pill" wrapper for the search text field (kiosk theme).
class _KioskSearchField extends StatelessWidget {
  final Widget child;
  const _KioskSearchField({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeDefault),
      decoration: BoxDecoration(
        color: KioskSearchTheme.surface,
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: KioskSearchTheme.border),
      ),
      child: child,
    );
  }
}



