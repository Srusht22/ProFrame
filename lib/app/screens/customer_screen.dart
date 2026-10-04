import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/model/customer.dart';
import '../../domain/model/design.dart';
import '../../domain/model/new_design_setup.dart';
import '../../infrastructure/design_store.dart';
import '../state/workspace.dart';
import '../theme/app_theme.dart';
import 'customer_price_card.dart';
import 'customers_screen.dart';
import 'design_actions.dart';
import 'design_name_screen.dart';
import 'designs_screen.dart';
import 'new_customer_screen.dart';

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

  /// **Edit** on the customer's information: their name, phone, address
  /// and notes, in a form of their own.
  static const editButton = ValueKey('customer-edit');

  /// The search across the customer's designs, by what they are called.
  static const searchField = ValueKey('customer-search');

  /// The chip that shows only designs of [kind] — or, for null, all of
  /// them.
  static ValueKey<String> filterKey(DesignKind? kind) =>
      ValueKey('customer-filter-${kind?.name ?? 'all'}');

  /// **Show all designs**, where a search or a filter finds none.
  static const clearButton = ValueKey('customer-design-clear');

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

  /// The designs the search and the filter find, read so far, and how many
  /// they find in all.
  final _designs = <DesignSummary>[];
  int _total = 0;

  /// How many of the customer's designs there are of each category — all
  /// of them, whatever is being searched for.
  Map<DesignKind, int> _kinds = const {};
  int get _all => _kinds.values.fold(0, (sum, n) => sum + n);

  /// What the designs are being searched for, and the category they are
  /// filtered to — null for all. Both are only a way of looking: they
  /// choose which designs are shown and change none of them.
  final _search = TextEditingController();
  String _query = '';
  DesignKind? _kind;
  bool get _narrowed => _query.trim().isNotEmpty || _kind != null;
  bool _loaded = false;
  bool _fetching = false;
  int _asked = 0;

  DesignStore get _store => ref.read(designStoreProvider);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _searchFor(String query) {
    _query = query;
    _load();
  }

  void _filterTo(DesignKind? kind) {
    if (kind == _kind) return;
    _kind = kind;
    _load();
  }

  /// Back to every design: the search emptied and the filter on All.
  void _showAll() {
    _search.clear();
    _query = '';
    _kind = null;
    _load();
  }

  Future<void> _load() async {
    final ask = ++_asked;
    _fetching = false;
    Customer? customer;
    DesignPage page;
    Map<DesignKind, int> kinds;
    try {
      customer = await ref.read(customerStoreProvider).load(widget.customerId);
      kinds = await _store.kindsOf(widget.customerId);
      page = await _store.page(
        customerId: widget.customerId,
        query: _query,
        kind: _kind,
        limit: pageSize,
      );
    } on Object {
      customer = null;
      kinds = const {};
      page = const DesignPage([], 0);
    }
    if (!mounted || ask != _asked) return;
    setState(() {
      _customer = customer;
      _kinds = kinds;
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
        query: _query,
        kind: _kind,
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

  /// A new design for this customer: its name, then what it is — door,
  /// window, both, sliding — are asked now, on the way to drawing it, and
  /// not before.
  void _newDesign(Customer customer) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) =>
          DesignNameScreen(setup: NewDesignSetup.forCustomer(customer)),
    ),
  );

  /// The customer's own information — name, phone, address, notes — in
  /// the form a customer is made with, filled in. Saving changes the
  /// customer and nothing else, and the page reads them again when it is
  /// told customers have changed.
  void _edit(Customer customer) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => NewCustomerScreen(editing: customer),
    ),
  );

  Future<void> _editInformation(DesignSummary summary) =>
      editDesignInformation(context, ref, summary);

  /// The **⋮** on a design's card: open it, edit its information,
  /// duplicate it, or delete it. A duplicate is another design of this same
  /// customer, the original untouched (`DesignStore.duplicate`). Deleting is that one design, asked about first by its name
  /// — see `deleteDesign` — and never the customer, whose page this is and
  /// who stays with their other designs.
  Future<void> _moreFor(DesignSummary summary) async {
    final chosen = await showModalBottomSheet<DesignAction>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: context.palette.surface,
      builder: (context) => DesignActionsSheet(summary: summary),
    );
    if (chosen == null || !mounted) return;
    switch (chosen) {
      case DesignAction.open:
        await _open(summary);
      case DesignAction.information:
        await _editInformation(summary);
      case DesignAction.delete:
        await deleteDesign(context, ref, summary);
      case DesignAction.duplicate:
        await _duplicate(summary);
    }
  }

  Future<void> _duplicate(DesignSummary summary) async {
    final copy = await ref.read(designStoreProvider).duplicate(summary.id);
    if (copy == null || !mounted) return;
    ref.read(designsRevisionProvider.notifier).changed();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Copy made: ${DesignSummary.of(copy).shownName}')),
    );
  }

  /// One of the customer's designs, opened exactly as it was kept — see
  /// `openKeptDesign`.
  Future<void> _open(DesignSummary summary) =>
      openKeptDesign(context, ref, summary);

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
      floatingActionButton: customer == null || _all == 0
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
                        child: _Person(
                          customer: customer,
                          designs: _all,
                          onEdit: () => _edit(customer),
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(across, 28, across, 12),
                      sliver: SliverToBoxAdapter(
                        child: _DesignsHeading(
                          count: _all,
                          found: _narrowed ? _total : null,
                        ),
                      ),
                    ),
                    if (_all > 0)
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(across, 0, across, 16),
                        sliver: SliverToBoxAdapter(
                          child: _Finder(
                            search: _search,
                            onSearch: _searchFor,
                            kinds: _kinds,
                            all: _all,
                            chosen: _kind,
                            onFilter: _filterTo,
                          ),
                        ),
                      ),
                    if (_all == 0)
                      SliverPadding(
                        padding: EdgeInsets.symmetric(horizontal: across),
                        sliver: SliverToBoxAdapter(
                          child: _NoDesigns(
                            name: customer.name,
                            onNewDesign: () => _newDesign(customer),
                          ),
                        ),
                      )
                    else if (_total == 0)
                      SliverPadding(
                        padding: EdgeInsets.symmetric(horizontal: across),
                        sliver: SliverToBoxAdapter(
                          child: _NoMatch(
                            query: _query.trim(),
                            kind: _kind,
                            onShowAll: _showAll,
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
                          onEdit: _editInformation,
                          onMore: _moreFor,
                          onNearEnd: () => WidgetsBinding.instance
                              .addPostFrameCallback((_) => _more()),
                        ),
                      ),
                    // What all of their designs come to, together — under
                    // the cards, so it moves none of them.
                    if (_all > 0)
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(across, 16, across, 0),
                        sliver: SliverToBoxAdapter(
                          child: CustomerPriceCard(customerId: customer.id),
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
  final VoidCallback onEdit;

  const _Person({
    required this.customer,
    required this.designs,
    required this.onEdit,
  });

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
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Customer information',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                    color: p.ink,
                  ),
                ),
              ),
              TextButton.icon(
                key: CustomerScreen.editButton,
                onPressed: onEdit,
                style: TextButton.styleFrom(
                  foregroundColor: p.primary,
                  minimumSize: const Size(48, 44),
                ),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Edit'),
              ),
            ],
          ),
          line(Icons.phone_outlined, 'Phone', customer.phone, number: true),
          line(Icons.place_outlined, 'Address', customer.address),
          line(Icons.sticky_note_2_outlined, 'Notes', customer.notes),
        ],
      ),
    );
  }
}

/// **Designs**, and how many — and, while a search or a filter is
/// narrowing them, how many of those are shown.
class _DesignsHeading extends StatelessWidget {
  final int count;

  /// How many the search and the filter find, or null when nothing is
  /// narrowing the list.
  final int? found;

  const _DesignsHeading({required this.count, this.found});

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
            found == null ? '$count' : '$found of $count',
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

/// Finding one design among many: a search by what it is called, and a
/// chip a category — **All**, then Door, Window, Sliding and Door & window
/// in the order a design is begun as — each with how many there are. A
/// category the customer has none of is left off, so the chips are only
/// ever a way to somewhere; the one chosen stays whatever its count.
///
/// Both only choose what is shown. Nothing here begins a design, and
/// nothing here changes one.
class _Finder extends StatelessWidget {
  final TextEditingController search;
  final ValueChanged<String> onSearch;
  final Map<DesignKind, int> kinds;
  final int all;
  final DesignKind? chosen;
  final ValueChanged<DesignKind?> onFilter;

  const _Finder({
    required this.search,
    required this.onSearch,
    required this.kinds,
    required this.all,
    required this.chosen,
    required this.onFilter,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    Widget chip(DesignKind? kind, String label, int count) {
      final on = kind == chosen;
      return Padding(
        padding: const EdgeInsetsDirectional.only(end: 8),
        child: ChoiceChip(
          key: CustomerScreen.filterKey(kind),
          selected: on,
          showCheckmark: false,
          avatar: kind == null
              ? null
              : Icon(
                  kindIcon(kind),
                  size: 16,
                  color: on ? AppTheme.accent : p.primary,
                ),
          label: Text('$label  $count'),
          labelStyle: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: on ? AppTheme.accent : p.ink,
          ),
          selectedColor: p.band,
          backgroundColor: p.surface,
          side: BorderSide(color: on ? p.band : p.hairline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
          onSelected: (_) => onFilter(kind),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: CustomerScreen.searchField,
          controller: search,
          onChanged: onSearch,
          textInputAction: TextInputAction.search,
          style: TextStyle(fontSize: 15, color: p.ink),
          decoration: InputDecoration(
            hintText: 'Search designs by name...',
            hintStyle: TextStyle(color: p.muted),
            filled: true,
            fillColor: p.surface,
            prefixIcon: Icon(Icons.search, color: p.muted),
            suffixIcon: ValueListenableBuilder<TextEditingValue>(
              valueListenable: search,
              builder: (context, value, _) => value.text.isEmpty
                  ? const SizedBox.shrink()
                  : IconButton(
                      tooltip: 'Clear search',
                      icon: Icon(Icons.close, color: p.muted),
                      onPressed: () {
                        search.clear();
                        onSearch('');
                      },
                    ),
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: p.hairline),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: p.primary, width: 1.6),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              chip(null, 'All', all),
              for (final kind in _order)
                if ((kinds[kind] ?? 0) > 0 || kind == chosen)
                  chip(kind, kind.label, kinds[kind] ?? 0),
            ],
          ),
        ),
      ],
    );
  }

  /// The categories in the order a design is begun as.
  static const _order = [
    DesignKind.door,
    DesignKind.window,
    DesignKind.sliding,
    DesignKind.both,
    DesignKind.angled,
    // Last, and only where there is one: a design of a category this
    // version does not know, listed as that rather than as a window.
    DesignKind.unsupported,
  ];
}

/// A search or a filter that finds none of the customer's designs: say
/// what was looked for, and offer the way back to all of them — not a new
/// design, which is a different thing altogether.
class _NoMatch extends StatelessWidget {
  final String query;
  final DesignKind? kind;
  final VoidCallback onShowAll;

  const _NoMatch({
    required this.query,
    required this.kind,
    required this.onShowAll,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final what = [
      if (query.isNotEmpty) '“$query”',
      if (kind != null) 'in ${kind!.label}',
    ].join(' ');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.hairline),
      ),
      child: Column(
        children: [
          Icon(Icons.search_off, size: 36, color: p.muted),
          const SizedBox(height: 10),
          Text(
            'No designs match $what',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: p.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Search by the design\'s name, or choose another category.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5, color: p.muted),
          ),
          const SizedBox(height: 14),
          OutlinedButton(
            key: CustomerScreen.clearButton,
            onPressed: onShowAll,
            child: const Text('Show all designs'),
          ),
        ],
      ),
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
  final ValueChanged<DesignSummary> onEdit;
  final ValueChanged<DesignSummary> onMore;

  /// Called as the last few cards read so far are built, so the next page
  /// is read before the list runs out.
  final VoidCallback onNearEnd;

  const _Cards({
    required this.designs,
    required this.width,
    required this.onOpen,
    required this.onEdit,
    required this.onMore,
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
        // Not for a design of a category this version does not know.
        onEdit: design.kind == DesignKind.unsupported
            ? null
            : () => onEdit(design),
        onMore: () => onMore(design),
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
  String two(int n) => n.toString().padLeft(2, '0');
  final time = '${two(then.hour)}:${two(then.minute)}';
  final day = DateTime(then.year, then.month, then.day);
  final today = DateTime(now.year, now.month, now.day);
  final gone = today.difference(day).inDays;
  if (gone == 0) return 'Today, $time';
  if (gone == 1) return 'Yesterday, $time';
  return '${then.day} ${monthNames[then.month - 1]} ${then.year}, $time';
}

/// One of the customer's designs as a card: its picture — the design itself,
/// drawn from its own geometry by the same `DesignPicture` the designs list
/// uses, or the empty sheet saying *Nothing drawn yet* — then its name, its
/// category, when it was last edited, **Edit information** and **Open**.
class CustomerDesignCard extends StatelessWidget {
  final DesignSummary design;
  final DateTime now;
  final VoidCallback onOpen;

  /// **Edit information** — the design's name — where it can be edited.
  final VoidCallback? onEdit;

  /// The **⋮** beside the name: Open, Edit information and Delete.
  final VoidCallback? onMore;

  /// How tall a card is, in the list and in the grid alike.
  static const height = 328.0;

  /// How tall its picture is.
  static const pictureHeight = 156.0;

  const CustomerDesignCard({
    super.key,
    required this.design,
    required this.now,
    required this.onOpen,
    this.onEdit,
    this.onMore,
  });

  /// The **Open** on the card of the design [id].
  static ValueKey<String> openKey(String id) => ValueKey('open-design-$id');

  /// The **⋮** on the card of the design [id].
  static ValueKey<String> moreKey(String id) => ValueKey('card-more-$id');

  /// The **Edit information** on the card of the design [id].
  static ValueKey<String> editKey(String id) => ValueKey('edit-design-$id');

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Material(
      color: p.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onOpen,
        // Pressing and holding is the ⋮, as a thumb expects of a card.
        onLongPress: onMore,
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
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 4),
                child: Row(
                  children: [
                    Expanded(
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
                    if (onMore != null)
                      IconButton(
                        key: moreKey(design.id),
                        tooltip: 'More options',
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                        onPressed: onMore,
                        icon: Icon(Icons.more_vert, size: 20, color: p.muted),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: [
                    // The category's name as long as the card allows —
                    // *Angled / Asymmetrical* is the longest — and cut
                    // short rather than run off it.
                    Flexible(
                      child: Container(
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
                            Icon(
                              kindIcon(design.kind),
                              size: 14,
                              color: p.primary,
                            ),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                design.kind.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: p.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (onEdit case final onEdit?)
                    Flexible(
                      child: TextButton.icon(
                        key: editKey(design.id),
                        onPressed: onEdit,
                        style: TextButton.styleFrom(
                          foregroundColor: p.muted,
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.edit_outlined, size: 17),
                        label: const Text(
                          'Edit information',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                  else
                    const Spacer(),
                  TextButton.icon(
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
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
