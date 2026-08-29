import 'package:acafe_customer/data/datasource/remote/dio/dio_client.dart';
import 'package:acafe_customer/data/datasource/remote/dio/logging_interceptor.dart';
import 'package:acafe_customer/features/category/domain/reposotories/category_repo.dart';
import 'package:acafe_customer/features/category/providers/category_provider.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_allergen.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_allergen_filter_row.dart';
import 'package:acafe_customer/features/search/domain/reposotories/search_repo.dart';
import 'package:acafe_customer/features/search/providers/search_provider.dart';
import 'package:acafe_customer/features/search/widget/filter_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/kiosk_layout_harness.dart';

/// The Filter sheet's allergen slot.
///
/// [FilterWidget] is shared with the customer web app's search results, which
/// has no allergen flow — hence a slot rather than a built-in section. These
/// pin both halves of that contract: the kiosk's row shows up where it should,
/// and a sheet that passes nothing is unchanged.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadKioskTestFonts);
  setUp(() => KioskAllergenPreferences.instance.reset());
  tearDown(() => KioskAllergenPreferences.instance.reset());

  Future<List<SingleChildWidget>> filterProviders() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final dio = DioClient(
      'http://localhost',
      null,
      loggingInterceptor: LoggingInterceptor(),
      sharedPreferences: prefs,
    );
    return [
      ...await kioskBaseProviders(),
      ChangeNotifierProvider<SearchProvider>(
        create: (_) =>
            SearchProvider(searchRepo: SearchRepo(dioClient: dio, sharedPreferences: prefs)),
      ),
      ChangeNotifierProvider<CategoryProvider>(
        create: (_) => CategoryProvider(
            categoryRepo: CategoryRepo(dioClient: dio, sharedPreferences: prefs)),
      ),
    ];
  }

  Future<void> pumpSheet(
    WidgetTester tester,
    Size size, {
    required bool withAllergenRow,
  }) async {
    await pumpKioskScreen(
      tester,
      size,
      Scaffold(
        body: FilterWidget(
          maxValue: 100,
          leadingSection:
              withAllergenRow ? const KioskAllergenFilterRow() : null,
        ),
      ),
      providers: await filterProviders(),
    );
    await settleKiosk(tester);
  }

  testWidgets('the kiosk sheet shows the allergen row above Sort by',
      (tester) async {
    await pumpSheet(tester, const Size(1080, 1920), withAllergenRow: true);

    expectNoOverflow(tester, const Size(1080, 1920));
    expect(find.text('Allergens'), findsOneWidget);
    expect(find.text('Anything to avoid?'), findsOneWidget);

    // Above Sort by — a customer who skipped the popup has to find this, so it
    // must not sit below the price chips.
    final double allergens = tester.getTopLeft(find.text('Allergens')).dy;
    final double sortBy = tester.getTopLeft(find.text('sort_by')).dy;
    expect(allergens, lessThan(sortBy));
  });

  testWidgets('a sheet that passes no section is unchanged', (tester) async {
    await pumpSheet(tester, const Size(1080, 1920), withAllergenRow: false);

    expectNoOverflow(tester, const Size(1080, 1920));
    expect(find.text('Allergens'), findsNothing);
    expect(find.byType(KioskAllergenFilterRow), findsNothing);
    expect(find.text('sort_by'), findsOneWidget);
  });

  testWidgets("the sheet's Reset must not clear the customer's allergens",
      (tester) async {
    // Allergens are a safety choice, not a merchandising filter. Wiring them
    // into Reset would let a stray tap quietly put nuts back on the menu.
    KioskAllergenPreferences.instance
        .applySelection(<KioskAllergen>{KioskAllergen.nuts});

    await pumpSheet(tester, const Size(1080, 1920), withAllergenRow: true);
    expect(find.text('Hiding: Nuts'), findsOneWidget);

    await tester.tap(find.text('reset'));
    await settleKiosk(tester);

    expect(KioskAllergenPreferences.instance.avoided,
        <KioskAllergen>{KioskAllergen.nuts});
    expect(find.text('Hiding: Nuts'), findsOneWidget);
  });
}
