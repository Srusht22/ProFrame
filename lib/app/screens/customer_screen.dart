import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/model/customer.dart';
import '../../domain/model/design.dart';
import '../../domain/model/new_design_setup.dart';
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
          StartScreen(setup: NewDesignSetup.forCustomer(customer)),
    ),
  );

  /// Whether a design is being opened, so a second tap on a card while the
  /// first is still on its way does not open the design twice over.
  bool _opening = false;

  /// One of the customer's designs, opened by its id exactly as it was kept
  /// — its drawing, geometry, openings, internal lines, materials and sizes
  /// — straight into the workspace. Nothing is asked on the way: what the
  /// design is was said when it was begun and is kept in it, so *Choose your
  /// design* is not shown again, and nothing new is made.
  Future<void> _open(DesignSummary summary) async {
    if (_opening) return;
    _opening = true;
    try {
      final design = await _store.load(summary.id);
      if (!mounted) return;
      if (design == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${summary.shownName} could not be opened.')),
        );
        return;
      }
      ref.read(workspaceProvider.notifier).openDesign(design);
      await Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const WorkspaceScreen()));
    } finally {
      _opening = false;
    }
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
      // Where the customer has designs, New Design stands at the foot of the
      // screen whatever is scrolled past — a customer with forty designs can
      // begin the forty-first without scrolling back to the top. Where they
      // have none, the empty state carries it instead, in the middle of the
      // page.
      floatingActionButton: customer == null || _total == 0
          ? null
          : FloatingActionButton.extended(
              key: CustomerScreen.newDesignButton,
              onPressed: () => _newDesign(customer),
              backgroundColor: p.band,
              foregroundColor: AppTheme.accent,
              icon: const Icon(Icons.add),
              label: const Text('New Design'),
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
                        child: _DesignsHeading(count: _total),
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
                        sliver: _Cards(
                          designs: _designs,
                          width: room.maxWidth - across * 2,
                          onOpen: _open,
                          onNearEnd: () => WidgetsBinding.instance
                              .addPostFrameCallback((_) => _more()),
                        ),
                      ),
                    // Room under the last card for New Design, so it never
                    // stands over a card that cannot be scrolled clear of it.
                    const SliverToBoxAdapter(child: SizedBox(height: 104)),
                  ],
                );
              },
            ),
    );
  }
}

/// The width the customer's page lays its content out in.
const _contentWidth = 960.0;

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

/// **Designs**, and how many.
class _DesignsHeading extends StatelessWidget {
  final int count;

  const _DesignsHeading({required this.count});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      children: [
        Text(
          'Designs',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: p.ink,
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

/// The customer's designs as cards: one above another on a phone, two or
/// three across where there is room, every card the same height.
class _Cards extends StatelessWidget {
  final List<DesignSummary> designs;
  final double width;
  final ValueChanged<DesignSummary> onOpen;

  /// Called as the last few cards read so far are built, so the next page
  /// is read before the list runs out.
  final VoidCallback onNearEnd;

  const _Cards({
    required this.designs,
    required this.width,
    required this.onOpen,
    required this.onNearEnd,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    Widget card(int i) {
      if (i >= designs.length - 8) onNearEnd();
      final design = designs[i];
      return CustomerDesignCard(
        key: CustomerScreen.designKey(design.id),
        design: design,
        now: now,
        onOpen: () => onOpen(design),
      );
    }

    final columns = (width / 290).floor().clamp(1, 3);
    if (columns == 1) {
      return SliverList.separated(
        itemCount: designs.length,
        separatorBuilder: (_, _) => const SizedBox(height: 14),
        itemBuilder: (context, i) => card(i),
      );
    }
    return SliverGrid.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        mainAxisExtent: CustomerDesignCard.height,
      ),
      itemCount: designs.length,
      itemBuilder: (context, i) => card(i),
    );
  }
}

/// When a design was last edited, as a date and a time: *Today, 09:14*,
/// *Yesterday, 18:02*, or *1 Mar 2026, 09:14*, seen from [now].
String lastEdited(DateTime then, DateTime now) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  String two(int n) => n.toString().padLeft(2, '0');
  final time = '${two(then.hour)}:${two(then.minute)}';
  final day = DateTime(then.year, then.month, then.day);
  final today = DateTime(now.year, now.month, now.day);
  final gone = today.difference(day).inDays;
  if (gone == 0) return 'Today, $time';
  if (gone == 1) return 'Yesterday, $time';
  return '${then.day} ${months[then.month - 1]} ${then.year}, $time';
}

/// One of the customer's designs as a card: its picture — the design itself,
/// drawn from its own geometry by the same `DesignPicture` the designs list
/// uses, or the empty sheet saying *Nothing drawn yet* — then its name, its
/// category, when it was last edited, and **Open**.
class CustomerDesignCard extends StatelessWidget {
  final DesignSummary design;
  final DateTime now;
  final VoidCallback onOpen;

  /// How tall a card is, in the list and in the grid alike.
  static const height = 318.0;

  /// How tall its picture is.
  static const pictureHeight = 156.0;

  const CustomerDesignCard({
    super.key,
    required this.design,
    required this.now,
    required this.onOpen,
  });

  /// The **Open** on the card of the design [id].
  static ValueKey<String> openKey(String id) => ValueKey('open-design-$id');

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
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onOpen,
        child: Container(
          height: height,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: p.hairline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: pictureHeight,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(color: p.hairline),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: RepaintBoundary(
                      child: DesignPicture(summary: design),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  design.shownName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: p.ink,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: p.shell,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(iconOf(design.kind), size: 14, color: p.primary),
                          const SizedBox(width: 5),
                          Text(
                            design.kind.label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: p.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'Last edited: ${lastEdited(design.updatedAt, now)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12.5, color: p.muted),
                ),
              ),
              const Spacer(),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton.icon(
                  key: openKey(design.id),
                  onPressed: onOpen,
                  style: TextButton.styleFrom(
                    foregroundColor: p.primary,
                    visualDensity: VisualDensity.compact,
                  ),
                  iconAlignment: IconAlignment.end,
                  icon: const Icon(Icons.arrow_forward, size: 18),
                  label: const Text('Open'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
