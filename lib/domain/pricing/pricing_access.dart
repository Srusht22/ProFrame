/// Who may do what with the workshop's prices and a customer's money.
///
/// **What somebody may do is a set of capabilities**, and every place that
/// changes the price list or a customer's money asks for the one it needs
/// before it writes anything (`Authority.require`) — the stores, never only
/// the screens. A screen asking as well only decides what to offer; hiding
/// a button allows nothing and forbids nothing.
///
/// ```
/// the person at the device ─ Authority ─ can(Capability)
///     owner                   every capability
///     a staff member          the capabilities the owner gave them
///     nobody signed in        the standard set while the workshop has no
///                             staff accounts; only viewing once it has
/// ```
///
/// ProFrame has no server and no sign-in of its own, so who is at the
/// device is said there: the owner by the owner's PIN, a member of staff by
/// their own PIN (`StaffStore`). It is a lock on the device, not security
/// against somebody who can clear its storage — real accounts would stand
/// in for it and nothing that asks [Authority.can] would change.
library;

/// One thing a person may be allowed to do.
///
/// Only what is checked where it is done is here: a capability with no
/// check behind it would be a switch that changes nothing. So there is no
/// `customers.delete`: no one can delete a customer (see CLAUDE.md, *A
/// customer cannot be deleted*), and a permission for it would allow
/// nothing.
enum Capability {
  customersView('customers.view', 'Customers', 'View'),
  customersCreate('customers.create', 'Customers', 'Add'),
  customersEdit('customers.edit', 'Customers', 'Edit'),
  designsView('designs.view', 'Designs', 'View'),
  designsCreate('designs.create', 'Designs', 'Create'),
  designsEdit('designs.edit', 'Designs', 'Edit and draw'),
  designsDelete('designs.delete', 'Designs', 'Delete'),
  pricingView('pricing.view', 'Pricing', 'View prices'),
  pricingEdit('pricing.edit', 'Pricing', 'Edit factory prices'),
  financialView('financial.view', 'Customer finances', 'View summary'),
  discountsApply('discounts.apply', 'Discounts', 'Apply and change'),
  quotationsView('quotations.view', 'Quotations', 'View'),
  quotationsCreate('quotations.create', 'Quotations', 'Create'),
  quotationsEdit('quotations.edit', 'Quotations', 'Change status'),
  paymentsView('payments.view', 'Payments', 'View history'),
  paymentsCreate('payments.create', 'Payments', 'Record payments'),
  paymentsRefund('payments.refund', 'Payments', 'Record refunds'),
  receiptsView('receipts.view', 'Receipts', 'View'),
  receiptsCreate('receipts.create', 'Receipts', 'Issue'),
  extrasCreate('extras.create', 'Extra charges', 'Add'),
  extrasEdit('extras.edit', 'Extra charges', 'Edit'),
  extrasDelete('extras.delete', 'Extra charges', 'Remove'),
  usersManage('users.manage', 'Staff', 'Add and edit staff'),
  permissionsManage('permissions.manage', 'Staff', 'Change permissions');

  const Capability(this.key, this.group, this.label);

  /// How it is written down: `payments.create`.
  final String key;

  /// The heading it is listed under.
  final String group;

  /// What it allows, in words.
  final String label;

  static Capability? byKey(Object? key) =>
      values.where((c) => c.key == key).firstOrNull;

  /// What can be seen and nothing more: what a new member of staff starts
  /// with, and what the device allows with nobody signed in once the
  /// workshop has staff accounts.
  static const viewOnly = {
    customersView,
    designsView,
    pricingView,
    financialView,
    quotationsView,
    paymentsView,
    receiptsView,
  };

  /// What the device allowed before there were staff accounts, and still
  /// allows with nobody signed in while there are none: seeing everything,
  /// adding and editing customers and designs, recording money, issuing
  /// receipts and quotations, and writing a job's extra charges. Never
  /// changing the factory's prices, giving a discount, or managing staff —
  /// those were the owner's and stay the owner's.
  static const standard = {
    ...viewOnly,
    customersCreate,
    customersEdit,
    designsCreate,
    designsEdit,
    designsDelete,
    extrasCreate,
    extrasEdit,
    extrasDelete,
    quotationsCreate,
    quotationsEdit,
    paymentsCreate,
    paymentsRefund,
    receiptsCreate,
  };
}

/// Whoever is asking to do something.
abstract interface class Authority {
  /// Who it is, in words: *Owner*, *Ahmed*.
  String get label;

  bool can(Capability capability);
}

extension AuthorityRequires on Authority {
  /// Nothing where [capability] is held; otherwise [AccessDenied], before
  /// anything is written.
  void require(Capability capability) {
    if (!can(capability)) throw AccessDenied(this, capability);
  }
}

/// The two roles a device can be in. The owner may do everything; staff,
/// nobody in particular, what the workshop allows anybody at the device
/// ([Capability.standard]). A named member of staff is a `StaffMember`.
enum WorkshopRole implements Authority {
  owner('Owner'),
  staff('Staff');

  const WorkshopRole(this.label);
  @override
  final String label;

  @override
  bool can(Capability capability) =>
      this == owner || Capability.standard.contains(capability);

  /// Whether this role may change the price list.
  bool get canConfigurePrices => can(Capability.pricingEdit);

  /// Whether this role may see what a design costs.
  bool get canSeePrices => can(Capability.pricingView);
}

/// The device with nobody signed in, once the workshop has staff accounts:
/// it may look, and nothing more.
class NobodySignedIn implements Authority {
  const NobodySignedIn();

  @override
  String get label => 'Nobody signed in';

  @override
  bool can(Capability capability) => Capability.viewOnly.contains(capability);
}

/// The application's own housekeeping, done when a store is read and asked
/// for by nobody: a design kept before customers existed is given the
/// customer its name stands for. That makes a customer, and nothing else
/// — it is never handed to anything a person does.
class Housekeeping implements Authority {
  const Housekeeping();

  @override
  String get label => 'ProFrame';

  @override
  bool can(Capability capability) => capability == Capability.customersCreate;
}

/// Something asked for by somebody who may not do it. Nothing was written.
class AccessDenied implements Exception {
  final Authority by;
  final Capability needed;

  AccessDenied(this.by, [this.needed = Capability.pricingEdit]);

  @override
  String toString() => switch (needed) {
    Capability.pricingEdit =>
      'Only the owner can change the price list (asked by ${by.label}).',
    _ =>
      '${by.label} does not have permission to '
          '${needed.label.toLowerCase()} (${needed.key}).',
  };
}

/// The name the price list's refusal had before there were capabilities.
typedef PricingAccessDenied = AccessDenied;
