import 'package:flutter/material.dart';
import 'package:acafe_customer/features/category/providers/category_provider.dart';
import 'package:acafe_customer/features/kiosk/screens/kiosk_checkout_widgets.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_ui.dart';
import 'package:acafe_customer/features/language/providers/localization_provider.dart';
import 'package:acafe_customer/helper/custom_snackbar_helper.dart';
import 'package:acafe_customer/helper/router_helper.dart';
import 'package:acafe_customer/localization/language_constrants.dart';
import 'package:acafe_customer/utill/app_constants.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

/// Kiosk language picker — uses the same form scale + row sizing as login.
class KioskLanguageScreen extends StatefulWidget {
  final bool fromMenu;
  const KioskLanguageScreen({super.key, this.fromMenu = false});

  @override
  State<KioskLanguageScreen> createState() => _KioskLanguageScreenState();
}

class _KioskLanguageScreenState extends State<KioskLanguageScreen> {
  int? _selectedIndex;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final code = Provider.of<LocalizationProvider>(context, listen: false)
        .locale
        .languageCode;
    _selectedIndex = AppConstants.languages.indexWhere(
      (l) => l.languageCode == code,
    );
    if (_selectedIndex! < 0) _selectedIndex = 0;
  }

  Future<void> _onSave() async {
    if (_saving || _selectedIndex == null || _selectedIndex! < 0) {
      showCustomSnackBarHelper(getTranslated('select_a_language', context));
      return;
    }

    final selected = AppConstants.languages[_selectedIndex!];
    final locale = Locale(selected.languageCode!, selected.countryCode);

    setState(() => _saving = true);

    final localization =
        Provider.of<LocalizationProvider>(context, listen: false);
    final category = Provider.of<CategoryProvider>(context, listen: false);

    await localization.setKioskLanguage(locale);
    await category.prefetchKioskMenu(
      localeCode: locale.languageCode,
      force: true,
    );

    if (!mounted) return;

    if (widget.fromMenu) {
      context.pop();
    } else {
      RouterHelper.getKioskWelcomeRoute(action: RouteAction.pushReplacement);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KioskUI.pageBg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double formWidth =
                constraints.maxWidth < kKioskFormDesignWidth
                    ? constraints.maxWidth
                    : kKioskFormDesignWidth;
            final double s = kioskFormScale(formWidth);
            final double side = 40 * s;

            return Center(
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: kKioskFormDesignWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(side, 32 * s, side, 0),
                      child: Row(
                        children: [
                          KioskBackButton.scaled(
                            s: s,
                            fallback: widget.fromMenu
                                ? RouterHelper.getKioskMenuRoute
                                : () => RouterHelper.getKioskWelcomeRoute(
                                      action: RouteAction.pushReplacement,
                                    ),
                          ),
                          Expanded(
                            child: Text(
                              getTranslated('choose_language', context)!,
                              textAlign: TextAlign.center,
                              style: loewExtraBold.copyWith(
                                fontSize: 48 * s,
                                height: 1.1,
                                color: Colors.black,
                              ),
                            ),
                          ),
                          SizedBox(width: 52 * s),
                        ],
                      ),
                    ),
                    SizedBox(height: 12 * s),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: side),
                      child: Opacity(
                        opacity: 0.6,
                        child: Text(
                          getTranslated(
                              'you_want_to_see_for_the_app', context)!,
                          textAlign: TextAlign.center,
                          style: loewRegular.copyWith(
                            fontSize: 18 * s,
                            height: 1.3,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 32 * s),
                    Expanded(
                      child: ListView.separated(
                        padding: EdgeInsets.fromLTRB(side, 0, side, 24 * s),
                        itemCount: AppConstants.languages.length,
                        separatorBuilder: (_, __) => SizedBox(height: 16 * s),
                        itemBuilder: (context, index) {
                          final language = AppConstants.languages[index];
                          return KioskSelectableRow(
                            s: s,
                            label: language.languageName ?? '',
                            leadingAsset: language.imageUrl,
                            selected: _selectedIndex == index,
                            onTap: () => setState(() => _selectedIndex = index),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(side, 0, side, 40 * s),
                      child: KioskPrimaryButton(
                        s: s,
                        label: getTranslated('save', context)!,
                        loading: _saving,
                        onTap: _onSave,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
