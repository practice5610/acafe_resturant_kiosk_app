import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:acafe_customer/common/widgets/custom_image_widget.dart';
import 'package:acafe_customer/features/category/providers/category_provider.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_auth_provider.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_logout_button.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_staff_exit_trigger.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_tap.dart';
import 'package:acafe_customer/features/splash/providers/splash_provider.dart';
import 'package:acafe_customer/utill/images.dart';
import 'package:acafe_customer/utill/styles.dart';

// Portrait-menu sidebar palette (kiosk_menu_screen.dart _MenuSpec).
const Color _kSidebarBg = Color(0xFFF9EBD7);
const Color _kSelectedBg = Color(0xFFFBF1E4);
const Color _kRule = Color(0xFFEADBC4);
const Color _kInk = Color(0xFF111111);

/// Landscape (Option B) left sidebar — the portrait menu's sidebar design:
/// one cream column with the A/CAFÉ logo on top, a scrolling list of
/// categories (circular image + label, selected = lighter cream band) and the
/// existing kiosk logout pinned at the bottom.
///
/// Sizes are authored at the 1190×680 reference and multiplied by [u]
/// (1.0 there): width 130, circle 60, item ~96, logo ~96 wide. Fonts stay the
/// landscape screen's Loew. Data, selection, image rule (shown unless the
/// device is picture-less) and the logo's staff-exit triple tap are unchanged.
class LandscapeCategoryRail extends StatelessWidget {
  final double u;
  final void Function(int id) onSelect;

  const LandscapeCategoryRail({
    super.key,
    required this.u,
    required this.onSelect,
  });

  static double widthFor(double u) => 130 * u;

  @override
  Widget build(BuildContext context) {
    final bool showImages = context.watch<KioskAuthProvider>().showImages;
    final splash = Provider.of<SplashProvider>(context, listen: false);
    final String? base = splash.baseUrls?.categoryImageUrl;

    return Container(
      width: widthFor(u),
      color: _kSidebarBg,
      child: Column(
        children: [
          SizedBox(height: 26 * u),
          KioskStaffExitTrigger(
            child: SizedBox(
              width: 96 * u,
              child: FittedBox(
                fit: BoxFit.contain,
                child: Text(
                  'A/CAFÉ',
                  style: loewExtraBold.copyWith(
                      fontSize: 34,
                      height: 1,
                      letterSpacing: 0.6,
                      color: _kInk),
                ),
              ),
            ),
          ),
          SizedBox(height: 16 * u),
          Expanded(
            child: Consumer<CategoryProvider>(
              builder: (context, category, _) {
                final categories = category.categoryList;
                if (categories == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                return ListView.builder(
                  padding: EdgeInsets.only(bottom: 6 * u),
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final c = categories[index];
                    final String? img = (showImages &&
                            base != null &&
                            (c.image ?? '').trim().isNotEmpty)
                        ? '$base/${c.image}'
                        : null;
                    return _RailItem(
                      u: u,
                      name: c.name ?? '',
                      imageUrl: img,
                      showImage: showImages,
                      selected: '${c.id}' == category.selectedSubCategoryId,
                      onTap: () => onSelect(c.id!),
                    );
                  },
                );
              },
            ),
          ),
          // Existing kiosk logout (same dropdown + confirmation, hidden on a
          // POS till serving as a kiosk), pinned below the list.
          KioskLogoutButton(
            child: Container(
              width: widthFor(u),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: _kRule, width: 1 * u)),
              ),
              padding: EdgeInsets.only(top: 10 * u, bottom: 14 * u),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.logout, size: 18 * u, color: _kInk),
                  SizedBox(height: 3 * u),
                  Text(
                    'Logout',
                    style: loewMedium.copyWith(
                        fontSize: 10 * u, height: 1.2, color: _kInk),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  final double u;
  final String name;
  final String? imageUrl;
  final bool showImage;
  final bool selected;
  final VoidCallback onTap;

  const _RailItem({
    required this.u,
    required this.name,
    required this.imageUrl,
    required this.showImage,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final double d = 60 * u;
    return Material(
      color: selected ? _kSelectedBg : Colors.transparent,
      child: KioskTap(
        onTap: onTap,
        child: SizedBox(
          height: showImage ? 96 * u : 44 * u,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 6 * u),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (showImage) ...[
                  ClipOval(
                    child: SizedBox(
                      width: d,
                      height: d,
                      child: imageUrl == null
                          ? const ColoredBox(color: Colors.white)
                          : CustomImageWidget(
                              emptyWhenMissing: true,
                              placeholder: Images.placeholderImage,
                              image: imageUrl!,
                              fit: BoxFit.cover,
                            ),
                    ),
                  ),
                  SizedBox(height: 6 * u),
                ],
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: loewMedium.copyWith(
                    fontSize: 10 * u,
                    height: 1.15,
                    color: _kInk,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
