/// Settings sidebar destinations (Figma 1641:3899).
enum PosSettingsSection {
  general,
  profile,
  staff,
  products,
  addOns,
  payments,
  hardware,
}

extension PosSettingsSectionX on PosSettingsSection {
  String get label => switch (this) {
        PosSettingsSection.general => 'GENERAL',
        PosSettingsSection.profile => 'PROFILE',
        PosSettingsSection.staff => 'STAFF',
        PosSettingsSection.products => 'PRODUCTS',
        PosSettingsSection.addOns => 'ADD-ONS',
        PosSettingsSection.payments => 'PAYMENTS',
        PosSettingsSection.hardware => 'HARDWARE',
      };

  String get title => switch (this) {
        PosSettingsSection.general => 'General',
        PosSettingsSection.profile => 'Profile',
        PosSettingsSection.staff => 'Staff',
        PosSettingsSection.products => 'Products',
        PosSettingsSection.addOns => 'Add-ons',
        PosSettingsSection.payments => 'Payments',
        PosSettingsSection.hardware => 'Hardware',
      };

  String get subtitle => switch (this) {
        PosSettingsSection.general => 'Store identity & locale settings',
        PosSettingsSection.profile => 'Account and terminal profile',
        PosSettingsSection.staff => 'Staff roles and PIN access',
        PosSettingsSection.products => 'Catalogue and menu visibility',
        PosSettingsSection.addOns => 'Modifiers and extras',
        PosSettingsSection.payments => 'Tenders and payment terminals',
        PosSettingsSection.hardware => 'Printers, scanners, and displays',
      };
}
