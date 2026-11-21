/// How the POS Menu screen renders its left-hand category rail.
///
/// This is a *presentation* choice only: both variants read the same category
/// data, selection state and tap handlers (see [PosCategorySidebar]). Only the
/// look of each row differs.
///
/// * [list]  — the original flat text rail (Figma 1915 / the shipped default):
///             an uppercase name per row, the active row filled ink, a hairline
///             rule under every inactive row.
/// * [tiles] — "Menu Variant 2 — Category Tiles with Photos" (Figma
///             2305:14526 / node 2305:14721): each row is a rounded card with a
///             cutout product photo above a centred name; the active card is
///             filled ink with a cream name.
enum PosCategoryLayout { list, tiles }

/// Fallback rail variant when no setting is present.
///
/// The live choice is the per-device "Show Category Images" Kiosk Setting (set
/// on admin/branch Device Update), read through [KioskAuthProvider.categoryLayout]
/// and delivered on the same kiosk-config channel as `show_images`. This const
/// is only the safe default for a session that predates the setting (or any
/// missing value): the simple text rail, so nothing changes until an admin opts
/// a device into the photo tiles.
const PosCategoryLayout kDefaultPosCategoryLayout = PosCategoryLayout.list;
