/// Who may do what with the workshop's prices.
///
/// The price list is the workshop's own figures, so changing it is the
/// owner's, and anybody else may only price designs by it. This is the one
/// rule, and the store that keeps the list asks it before writing
/// (`PriceListStore.save`); a screen asking it as well only decides what
/// to offer, never what is allowed.
///
/// ProFrame has no sign-in, so the application starts every run as
/// [staff], who can price but not change prices. The person at the device
/// becomes the owner for the run by the owner's PIN on the factory prices
/// screen (`OwnerAccessStore`); real accounts would take its place and
/// change nothing here.
enum WorkshopRole {
  owner('Owner'),
  staff('Staff');

  const WorkshopRole(this.label);
  final String label;

  /// Whether this role may change the price list.
  bool get canConfigurePrices => this == WorkshopRole.owner;

  /// Whether this role may see what a design costs. Everybody may.
  bool get canSeePrices => true;
}

/// A change to the price list asked for by somebody who may not make it.
class PricingAccessDenied implements Exception {
  final WorkshopRole role;

  const PricingAccessDenied(this.role);

  @override
  String toString() =>
      'Only the owner can change the price list (asked by ${role.label}).';
}
