import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/model/customer.dart';
import '../../domain/model/design.dart';
import '../../infrastructure/design_store.dart';
import '../state/workspace.dart';
import '../theme/app_theme.dart';
import 'customers_screen.dart';
import 'designs_screen.dart';
import 'start_screen.dart';
import 'workspace_screen.dart';

/// One customer, and the designs that are theirs.
///
/// **A customer is a person, not a design.** Opening Adam shows Adam — who
/// he is and how to reach him — and beneath that the designs that belong to
/// him, each one his by `customerId`. Nothing is asked and nothing is begun
/// on the way in: no choice of door or window, no new design, no drawing.
/// Those come when **New Design** is pressed, and only then.
class CustomerScreen extends ConsumerStatefulWidget {
  final String customerId;

  const CustomerScreen({super.key, required this.customerId});

  /// How many of the customer's designs are read at a time.
  static const pageSize = 40;

  /// The **New Design** action, in the designs' heading or in the empty
  /// state where the customer has none.
  static const newDesignButton = ValueKey('customer-new-design');

  /// The row of the design [id] in the customer's designs.
  static ValueKey<String> designKey(String id) =>
      ValueKey('customer-design-$id');

  /// The name this customer's page goes by on the navigator, so a design
  /// begun from it can come back to it.
  static String routeName(String customerId) => '/customer/$customerId';

  /// The way to the page of the customer [customerId].
  static Route<void> route(String customerId) => MaterialPageRoute<void>(
    settings: RouteSettings(name: routeName(customerId)),
    builder: (_) => CustomerScreen(customerId: customerId),
  );

  @override
  ConsumerState<CustomerScreen> createState() => _CustomerScreenState();
}

class _CustomerScreenState extends ConsumerState<CustomerScreen> {
  static const pageSize = CustomerScreen.pageSize;

  Customer? _customer;
  final _designs = <DesignSummary>[];
  int _total = 0;
  bool _loaded = false;
  bool _fetching = false;
  int _asked = 0;

  DesignStore get _store => ref.read(designStoreProvider);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final ask = ++_asked;
    _fetching = false;
    Customer? customer;
    DesignPage page;
    try {
      customer = await ref.read(customerStoreProvider).load(widget.customerId);
      page = await _store.page(customerId: widget.customerId, limit: pageSize);
    } on Object {
      customer = null;
      page = const DesignPage([], 0);
    }
    if (!mounted || ask != _asked) return;
    setState(() {
      _customer = customer;
      _designs
        ..clear()
        ..addAll(page.items);
      _total = page.total;
      _loaded = true;
    });
  }

  Future<void> _more() async {
    if (_fetching || _designs.length >= _total) return;
    _fetching = true;
    final ask = _asked;
    DesignPage page;
    try {
      page = await _store.page(
        customerId: widget.customerId,
        offset: _designs.length,
        limit: pageSize,
      );
    } on Object {
      page = const DesignPage([], 0);
    }
    if (!mounted || ask != _asked) return;
    setState(() {
      _designs.addAll(page.items);
      if (page.items.isEmpty) _total = _designs.length;
      _fetching = false;
    });
  }

  /// A new design for this customer: what it is — door, window, both,
  /// sliding — is asked now, on the way to drawing it, and not before.
  void _newDesign(Customer customer) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) =>
          StartScreen(customer: customer.name, customerId: customer.id),
    ),
  );

  /// One of the customer's designs, opened exactly as it was kept.
  Future<void> _open(DesignSummary summary) async {
    final design = await _store.load(summary.id);
    if (design == null || !mounted) return;
    ref.read(workspaceProvider.notifier).openDesign(design);
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const WorkspaceScreen()));
  }

  @override
  Widget build(BuildContext context) {
    ref
      ..listen(customersRevisionProvider, (_, _) => _load())
      ..listen(designsRevisionProvider, (_, _) => _load());
    final p = context.palette;
    final customer = _customer;

    return Scaffold(
      backgroundColor: p.shell,
      appBar: AppBar(
        backgroundColor: p.band,
        foregroundColor: AppTheme.accent,
        title: Text(customer?.name ?? ''),
      ),
      body: !_loaded
          ? const SizedBox.shrink()
          : customer == null
          ? Center(
              child: Text(
                'This customer is no longer kept.',
                style: TextStyle(color: p.muted),
              ),
            )
          : LayoutBuilder(
              builder: (context, room) {
                final gutter = room.maxWidth < 600 ? 16.0 : 32.0;
                final across = room.maxWidth > _contentWidth + gutter * 2
                    ? (room.maxWidth - _contentWidth) / 2
                    : gutter;
                return CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(across, 20, across, 0),
                      sliver: SliverToBoxAdapter(
                        child: _Person(customer: customer, designs: _total),
                      ),
                    ),
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(across, 28, across, 12),
                      sliver: SliverToBoxAdapter(
                        child: _DesignsHeading(
                          count: _total,
                          onNewDesign: _total == 0
                              ? null
                              : () => _newDesign(customer),
                        ),
                      ),
                    ),
                    if (_total == 0)
                      SliverPadding(
                        padding: EdgeInsets.symmetric(horizontal: across),
                        sliver: SliverToBoxAdapter(
                          child: _NoDesigns(
                            name: customer.name,
                            onNewDesign: () => _newDesign(customer),
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: EdgeInsets.symmetric(horizontal: across),
                        sliver: SliverList.separated(
                          itemCount: _designs.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, i) {
                            if (i >= _designs.length - 8) {
                              WidgetsBinding.instance.addPostFrameCallback(
                                (_) => _more(),
                              );
                            }
                            final design = _designs[i];
                            return _DesignRow(
                              key: CustomerScreen.designKey(design.id),
                              design: design,
                              onOpen: () => _open(design),
                            );
                          },
                        ),
                      ),
                    const SliverToBoxAdapter(child: SizedBox(height: 40)),
                  ],
                );
              },
            ),
    );
  }
}

/// The width the customer's page lays its content out in.
const _contentWidth = 760.0;

/// Who the customer is: their initials and name, and then their
/// information — phone, address and notes — each on a line of its own and
/// each said to be missing where nothing was given.
class _Person extends StatelessWidget {
  final Customer customer;
  final int designs;

  const _Person({required this.customer, required this.designs});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    Widget line(
      IconData icon,
      String label,
      String value, {
      bool number = false,
    }) => Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: p.muted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: p.muted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value.isEmpty ? 'Not given' : value,
                  // A number reads left to right whatever the language
                  // around it.
                  textDirection: number && value.isNotEmpty
                      ? TextDirection.ltr
                      : null,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.35,
                    color: value.isEmpty ? p.muted : p.ink,
                    fontStyle: value.isEmpty
                        ? FontStyle.italic
                        : FontStyle.normal,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: p.band,
                child: Text(
                  initialsOf(customer.name),
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.accent,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer.name,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: p.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Customer · ${designsCount(designs).toLowerCase()}',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: p.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Divider(height: 1, color: p.hairline),
          const SizedBox(height: 14),
          Text(
            'Customer information',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
              color: p.ink,
            ),
          ),
          line(Icons.phone_outlined, 'Phone', customer.phone, number: true),
          line(Icons.place_outlined, 'Address', customer.address),
          line(Icons.sticky_note_2_outlined, 'Notes', customer.notes),
        ],
      ),
    );
  }
}

/// **Designs**, how many, and — where there are any — **New Design**
/// beside them. Where there are none the empty state carries the button.
class _DesignsHeading extends StatelessWidget {
  final int count;
  final VoidCallback? onNewDesign;

  const _DesignsHeading({required this.count, required this.onNewDesign});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      children: [
        Flexible(
          child: Row(
            children: [
              Flexible(
                child: Text(
                  'Designs',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: p.ink,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: p.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: p.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (onNewDesign != null) ...[
          const SizedBox(width: 12),
          // Compact beside a heading: the theme's button is sized to stand
          // on its own, and at full size it would push the heading off a
          // narrow phone.
          FilledButton.icon(
            key: CustomerScreen.newDesignButton,
            onPressed: onNewDesign,
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 44),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            icon: const Icon(Icons.add, size: 20),
            label: const Text('New Design'),
          ),
        ],
      ],
    );
  }
}

/// A customer with no designs yet, and the way to begin their first.
class _NoDesigns extends StatelessWidget {
  final String name;
  final VoidCallback onNewDesign;

  const _NoDesigns({required this.name, required this.onNewDesign});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.hairline),
      ),
      child: Column(
        children: [
          Icon(Icons.folder_open_outlined, size: 40, color: p.muted),
          const SizedBox(height: 10),
          Text(
            'No designs yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: p.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Begin $name's first door, window or sliding set.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: p.muted),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            key: CustomerScreen.newDesignButton,
            onPressed: onNewDesign,
            icon: const Icon(Icons.add, size: 20),
            label: const Text('New Design'),
          ),
        ],
      ),
    );
  }
}

/// One of the customer's designs: what it is, what it is called, when it
/// was last edited, and the way into it.
class _DesignRow extends StatelessWidget {
  final DesignSummary design;
  final VoidCallback onOpen;

  const _DesignRow({super.key, required this.design, required this.onOpen});

  static IconData iconOf(DesignKind kind) => switch (kind) {
    DesignKind.door => Icons.door_front_door_outlined,
    DesignKind.window => Icons.window_outlined,
    DesignKind.both => Icons.splitscreen_outlined,
    DesignKind.sliding => Icons.door_sliding_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Material(
      color: p.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onOpen,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: p.hairline),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: p.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(iconOf(design.kind), color: p.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      design.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: p.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${design.kind.label} · '
                      '${editedAgo(design.updatedAt, DateTime.now())}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: p.muted),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: p.muted),
            ],
          ),
        ),
      ),
    );
  }
}
