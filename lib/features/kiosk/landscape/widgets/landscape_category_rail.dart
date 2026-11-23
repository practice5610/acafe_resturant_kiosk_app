import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:acafe_customer/common/widgets/custom_image_widget.dart';
import 'package:acafe_customer/features/category/providers/category_provider.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_auth_provider.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_tap.dart';
import 'package:acafe_customer/features/splash/providers/splash_provider.dart';
import 'package:acafe_customer/utill/images.dart';
import 'package:acafe_customer/utill/styles.dart';

const Color _kTileBg = Color(0xFFFBF8EF);
const Color _kTileBorder = Color(0xFFDED8C6);
const Color _kSelectedBg = Color(0xFF0D0D0D);

/// Landscape (Option B) category rail — Figma B-01 photo tiles. Each category is
/// an image tile with its name; the selected one inverts to black with a white
/// label. Picture-less devices (or categories without an image) show a clean
/// label-only tile. Data and selection come from [CategoryProvider], exactly as
/// the portrait rail.
class LandscapeCategoryRail extends StatelessWidget {
  final double s;
  final double width;
  final void Function(int id) onSelect;

  const LandscapeCategoryRail({
    super.key,
    required this.s,
    required this.width,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final bool showImages = context.watch<KioskAuthProvider>().showImages;
    final splash = Provider.of<SplashProvider>(context, listen: false);
    final String? base = splash.baseUrls?.categoryImageUrl;

    return Consumer<CategoryProvider>(
      builder: (context, category, _) {
        final categories = category.categoryList;
        if (categories == null) {
          return SizedBox(
              width: width,
              child: const Center(child: CircularProgressIndicator()));
        }
        return SizedBox(
          width: width,
          child: ListView.separated(
            padding: EdgeInsets.zero,
            itemCount: categories.length,
            separatorBuilder: (_, __) => SizedBox(height: 6 * s),
            itemBuilder: (context, index) {
              final c = categories[index];
              final bool selected =
                  '${c.id}' == category.selectedSubCategoryId;
              final String? img = (showImages &&
                      base != null &&
                      (c.image ?? '').trim().isNotEmpty)
                  ? '$base/${c.image}'
                  : null;
              return _RailTile(
                s: s,
                width: width,
                name: c.name ?? '',
                imageUrl: img,
                selected: selected,
                onTap: () => onSelect(c.id!),
              );
            },
          ),
        );
      },
    );
  }
}

class _RailTile extends StatelessWidget {
  final double s;
  final double width;
  final String name;
  final String? imageUrl;
  final bool selected;
  final VoidCallback onTap;

  const _RailTile({
    required this.s,
    required this.width,
    required this.name,
    required this.imageUrl,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Figma tile is 140 × 92 (ratio ≈ 0.657); keep the proportion at any rail
    // width so the rail scales with the window.
    final double height = width * (92 / 140);
    final double radius = (12 / 140) * width;

    return KioskTap(
      onTap: onTap,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: selected ? _kSelectedBg : _kTileBg,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
              color: selected ? _kSelectedBg : _kTileBorder,
              width: (1.5 * s).clamp(1.0, 2.5)),
        ),
        clipBehavior: Clip.antiAlias,
        padding: EdgeInsets.symmetric(vertical: height * 0.08),
        child: Column(
          children: [
            if (imageUrl != null)
              Expanded(
                child: Center(
                  child: CustomImageWidget(
                    emptyWhenMissing: true,
                    placeholder: Images.placeholderImage,
                    image: imageUrl!,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4 * s),
                  child: Text(
                    name.toUpperCase(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: loewBold.copyWith(
                      fontSize: (11.5 / 140) * width,
                      height: 1.05,
                      color: selected ? Colors.white : const Color(0xFF0D0D0D),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
