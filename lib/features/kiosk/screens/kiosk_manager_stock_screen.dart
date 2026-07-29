import 'package:flutter/material.dart';
import 'package:acafe_customer/common/responsive/kiosk_responsive.dart';
import 'package:acafe_customer/common/widgets/custom_image_widget.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_manager_provider.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_ui.dart';
import 'package:acafe_customer/helper/router_helper.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:provider/provider.dart';

/// Full branch product list (same list the Branch panel's product page
/// shows) with an availability toggle per row -- lets a manager pull an
/// item from the menu without leaving the counter.
class KioskManagerStockScreen extends StatefulWidget {
  const KioskManagerStockScreen({super.key});

  @override
  State<KioskManagerStockScreen> createState() => _KioskManagerStockScreenState();
}

class _KioskManagerStockScreenState extends State<KioskManagerStockScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<KioskManagerProvider>().loadProducts();
    });
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 400) {
      final provider = context.read<KioskManagerProvider>();
      if (!provider.productsLoading && provider.hasMoreProducts) {
        provider.loadProducts(reset: false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KioskUI.pageBg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double s = KioskResponsive.scale(constraints.maxWidth);
            return KioskCenteredContent(
              child: Column(
                children: [
                  KioskHeaderBar(
                    s: s,
                    title: 'MARK OUT OF STOCK',
                    fallback: RouterHelper.getKioskManagerDashboardRoute,
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 132 * s),
                    child: TextField(
                      controller: _searchController,
                      onSubmitted: (value) =>
                          context.read<KioskManagerProvider>().loadProducts(search: value),
                      decoration: InputDecoration(
                        hintText: 'Search products',
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: EdgeInsets.symmetric(horizontal: 28 * s, vertical: 20 * s),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18 * s),
                          borderSide: BorderSide(color: Colors.black12, width: 1.5 * s),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 24 * s),
                  Expanded(
                    child: Consumer<KioskManagerProvider>(
                      builder: (context, provider, _) {
                        if (provider.productsLoading && provider.products.isEmpty) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (provider.products.isEmpty) {
                          return Center(
                            child: Text('No products found',
                                style: loewMedium.copyWith(fontSize: 44 * s)),
                          );
                        }
                        return ListView.separated(
                          controller: _scrollController,
                          padding: EdgeInsets.fromLTRB(132 * s, 0, 132 * s, 60 * s),
                          itemCount: provider.products.length + (provider.hasMoreProducts ? 1 : 0),
                          separatorBuilder: (_, __) => SizedBox(height: 16 * s),
                          itemBuilder: (context, index) {
                            if (index >= provider.products.length) {
                              return Padding(
                                padding: EdgeInsets.symmetric(vertical: 40 * s),
                                child: const Center(child: CircularProgressIndicator()),
                              );
                            }
                            final product = provider.products[index];
                            final int id = product['id'];
                            return _ProductStockRow(
                              s: s,
                              product: product,
                              toggling: provider.isTogglingProduct(id),
                              onToggle: (value) => provider.toggleProductAvailability(id, value),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ProductStockRow extends StatelessWidget {
  final double s;
  final Map<String, dynamic> product;
  final bool toggling;
  final ValueChanged<bool> onToggle;

  const _ProductStockRow({
    required this.s,
    required this.product,
    required this.toggling,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final bool isAvailable = product['is_available'] == true;
    final String stockType = product['stock_type']?.toString() ?? 'unlimited';
    final int stock = (product['stock'] as num?)?.toInt() ?? 0;

    return Container(
      padding: EdgeInsets.all(24 * s),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18 * s),
        border: Border.all(color: Colors.black12, width: 1.5 * s),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14 * s),
            child: CustomImageWidget(
              image: product['image_full_path']?.toString() ?? '',
              width: 96 * s,
              height: 96 * s,
              fit: BoxFit.cover,
            ),
          ),
          SizedBox(width: 24 * s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product['name']?.toString() ?? '',
                    style: loewBold.copyWith(fontSize: 32 * s, color: Colors.black)),
                SizedBox(height: 6 * s),
                Text(
                  stockType == 'unlimited' ? 'Unlimited stock' : 'Stock: $stock',
                  style: loewRegular.copyWith(fontSize: 26 * s, color: Colors.black54),
                ),
              ],
            ),
          ),
          if (toggling)
            SizedBox(
              width: 28 * s,
              height: 28 * s,
              child: const CircularProgressIndicator(strokeWidth: 3),
            )
          else
            Switch(
              value: isAvailable,
              onChanged: onToggle,
              activeThumbColor: Colors.black,
            ),
        ],
      ),
    );
  }
}
