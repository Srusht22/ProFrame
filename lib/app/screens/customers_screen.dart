import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../infrastructure/customer_store.dart';
import '../state/workspace.dart';
import '../theme/app_theme.dart';
import 'appearance_button.dart';
import 'customer_screen.dart';
import 'new_customer_screen.dart';

/// The two letters a customer is known by at a glance: the first letter of
/// each of the first two words of [name], or its first letter alone.
String initialsOf(String name) {
  final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
  final letters = [for (final w in words.take(2)) w.characters.first];
  return letters.join().toUpperCase();
}

/// How many designs, said as a person says it.
String designsCount(int n) => switch (n) {
  0 => 'No designs yet',
  1 => '1 design',
  _ => '$n designs',
};

/// Every person the workshop draws for, a search across them by name or
/// phone, and **New Customer**.
///
/// A customer is not a design: tapping one opens that customer — who they
/// are, how to reach them, and their designs — never a drawing.
class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  /// How many customers are read at a time; the next page is read as the
  /// end of the list comes into view.
  static const pageSize = 40;

  /// The search field.
  static const searchField = ValueKey('customers-search');

  /// The **New Customer** button.
  static const newCustomerButton = ValueKey('new-customer');

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  static const pageSize = CustomersScreen.pageSize;

  final _search = TextEditingController();
  String _query = '';

  final _found = <CustomerSummary>[];
  int _total = 0;
  int _kept = 0;
  Map<String, int> _designs = const {};

  bool _loaded = false;
  bool _fetching = false;
  int _asked = 0;

  CustomerStore get _customers => ref.read(customerStoreProvider);

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final ask = ++_asked;
    _fetching = false;
    CustomerPage page;
    int kept;
    Map<String, int> designs;
    try {
      page = await _customers.page(query: _query, limit: pageSize);
      kept = _query.trim().isEmpty ? page.total : await _customers.count();
      designs = await ref.read(designStoreProvider).countsByCustomer();
    } on Object {
      page = const CustomerPage([], 0);
      kept = 0;
      designs = const {};
    }
    if (!mounted || ask != _asked) return;
    setState(() {
      _found
        ..clear()
        ..addAll(page.items);
      _total = page.total;
      _kept = kept;
      _designs = designs;
      _loaded = true;
    });
  }

  Future<void> _more() async {
    if (_fetching || _found.length >= _total) return;
    _fetching = true;
    final ask = _asked;
    CustomerPage page;
    try {
      page = await _customers.page(
        query: _query,
        offset: _found.length,
        limit: pageSize,
      );
    } on Object {
      page = const CustomerPage([], 0);
    }
    if (!mounted || ask != _asked) return;
    setState(() {
      _found.addAll(page.items);
      if (page.items.isEmpty) _total = _found.length;
      _fetching = false;
    });
  }

  void _searchFor(String query) {
    _query = query;
    _reload();
  }

  void _newCustomer() => Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (_) => const NewCustomerScreen()));

  /// The customer's own page — who they are and their designs — and never
  /// a drawing.
  void _open(CustomerSummary customer) =>
      Navigator.of(context).push(CustomerScreen.route(customer.id));

  @override
  Widget build(BuildContext context) {
    ref
      ..listen(customersRevisionProvider, (_, _) => _reload())
      ..listen(designsRevisionProvider, (_, _) => _reload());

    return Scaffold(
      backgroundColor: context.palette.shell,
      body: LayoutBuilder(
        builder: (context, room) {
          final phone = room.maxWidth < 600;
          final gutter = phone ? 16.0 : 32.0;
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _Header(
                  phone: phone,
                  gutter: gutter,
                  count: _kept,
                  search: _search,
                  onSearch: _searchFor,
                  onNewCustomer: _newCustomer,
                ),
              ),
              if (!_loaded)
                const SliverToBoxAdapter(child: SizedBox.shrink())
              else if (_kept == 0)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _NobodyYet(onNewCustomer: _newCustomer),
                )
              else ...[
                SliverToBoxAdapter(
                  child: _Centred(
                    gutter: gutter,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 28, bottom: 14),
                      child: _SectionTitle(
                        title: _query.trim().isEmpty
                            ? 'All Customers'
                            : 'Results',
                        count: _total,
                      ),
                    ),
                  ),
                ),
                if (_total == 0)
                  SliverToBoxAdapter(
                    child: _Centred(
                      gutter: gutter,
                      child: _NoMatch(query: _query.trim()),
                    ),
                  )
                else
                  _Customers(
                    customers: _found,
                    designs: _designs,
                    width: room.maxWidth,
                    gutter: gutter,
                    phone: phone,
                    onOpen: _open,
                    onNearEnd: () => WidgetsBinding.instance
                        .addPostFrameCallback((_) => _more()),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
            ],
          );
        },
      ),
    );
  }
}

const _contentWidth = 1200.0;

class _Centred extends StatelessWidget {
  final double gutter;
  final Widget child;

  const _Centred({required this.gutter, required this.child});

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _contentWidth),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: gutter),
        child: child,
      ),
    ),
  );
}

/// The band across the top: the way back, the title, how many customers
/// there are, the search, and **New Customer** — laid out as the designs'
/// band is, so the two read as one application.
class _Header extends StatelessWidget {
  final bool phone;
  final double gutter;
  final int count;
  final TextEditingController search;
  final ValueChanged<String> onSearch;
  final VoidCallback onNewCustomer;

  const _Header({
    required this.phone,
    required this.gutter,
    required this.count,
    required this.search,
    required this.onSearch,
    required this.onNewCustomer,
  });

  @override
  Widget build(BuildContext context) {
    final newCustomer = FilledButton.icon(
      key: CustomersScreen.newCustomerButton,
      onPressed: onNewCustomer,
      style: FilledButton.styleFrom(
        backgroundColor: AppTheme.accent,
        foregroundColor: AppTheme.primary,
        minimumSize: const Size(0, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      icon: const Icon(Icons.person_add_alt_1_outlined, size: 22),
      label: const Text('New Customer'),
    );
    final canGoBack = Navigator.of(context).canPop();
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (canGoBack)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: IconButton(
                  tooltip: 'Back',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back, color: AppTheme.accent),
                ),
              ),
            Expanded(
              child: Text(
                'PROFRAME',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.2,
                  color: AppTheme.accent.withValues(alpha: 0.6),
                ),
              ),
            ),
            if (phone) const AppearanceButton(colour: AppTheme.accent),
          ],
        ),
        if (!phone) const SizedBox(height: 6),
        Text(
          'Customers',
          style: TextStyle(
            fontSize: phone ? 30 : 36,
            fontWeight: FontWeight.w700,
            height: 1.1,
            color: AppTheme.accent,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          count == 0
              ? 'Everyone you draw for is kept here.'
              : '$count ${count == 1 ? 'customer' : 'customers'}',
          style: TextStyle(
            fontSize: 14,
            color: AppTheme.accent.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
    final field = TextField(
      key: CustomersScreen.searchField,
      controller: search,
      onChanged: onSearch,
      textInputAction: TextInputAction.search,
      style: TextStyle(fontSize: 15, color: context.palette.ink),
      decoration: InputDecoration(
        hintText: 'Search by name or phone...',
        hintStyle: TextStyle(color: context.palette.muted),
        filled: true,
        fillColor: context.palette.surface,
        prefixIcon: Icon(Icons.search, color: context.palette.muted),
        suffixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: search,
          builder: (context, value, _) => value.text.isEmpty
              ? const SizedBox.shrink()
              : IconButton(
                  tooltip: 'Clear search',
                  icon: Icon(Icons.close, color: context.palette.muted),
                  onPressed: () {
                    search.clear();
                    onSearch('');
                  },
                ),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppTheme.accent, width: 2),
        ),
      ),
    );

    return ColoredBox(
      color: context.palette.band,
      child: SafeArea(
        bottom: false,
        child: _Centred(
          gutter: gutter,
          child: Padding(
            padding: EdgeInsets.only(top: phone ? 12 : 32, bottom: 24),
            child: phone
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      title,
                      const SizedBox(height: 20),
                      field,
                      const SizedBox(height: 12),
                      newCustomer,
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(child: title),
                          const SizedBox(width: 16),
                          const Padding(
                            padding: EdgeInsets.only(bottom: 6),
                            child: AppearanceButton(colour: AppTheme.accent),
                          ),
                          const SizedBox(width: 8),
                          newCustomer,
                        ],
                      ),
                      const SizedBox(height: 24),
                      field,
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final int count;

  const _SectionTitle({required this.title, required this.count});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: context.palette.ink,
        ),
      ),
      const SizedBox(width: 10),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: context.palette.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          '$count',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: context.palette.primary,
          ),
        ),
      ),
    ],
  );
}

/// The customers found: one card a row on a phone, a grid where there is
/// room.
class _Customers extends StatelessWidget {
  final List<CustomerSummary> customers;
  final Map<String, int> designs;
  final double width;
  final double gutter;
  final bool phone;
  final ValueChanged<CustomerSummary> onOpen;
  final VoidCallback onNearEnd;

  const _Customers({
    required this.customers,
    required this.designs,
    required this.width,
    required this.gutter,
    required this.phone,
    required this.onOpen,
    required this.onNearEnd,
  });

  Widget _card(int i) {
    if (i >= customers.length - 8) onNearEnd();
    final customer = customers[i];
    return CustomerCard(
      key: CustomerCard.keyOf(customer.id),
      customer: customer,
      designs: designs[customer.id] ?? 0,
      onOpen: () => onOpen(customer),
    );
  }

  @override
  Widget build(BuildContext context) {
    final across = (width > _contentWidth ? _contentWidth : width) - gutter * 2;
    final side = (width - across) / 2;
    if (phone) {
      return SliverPadding(
        padding: EdgeInsets.symmetric(horizontal: side),
        sliver: SliverList.separated(
          itemCount: customers.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, i) => _card(i),
        ),
      );
    }
    final columns = (across / 340).floor().clamp(2, 3);
    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: side),
      sliver: SliverGrid.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          mainAxisExtent: CustomerCard.height,
        ),
        itemCount: customers.length,
        itemBuilder: (context, i) => _card(i),
      ),
    );
  }
}

/// One customer: their initials, their name, their phone number, how many
/// designs they have, and the way in.
class CustomerCard extends StatefulWidget {
  final CustomerSummary customer;
  final int designs;
  final VoidCallback onOpen;

  /// How tall a card is — the same in the list and in the grid.
  static const height = 92.0;

  const CustomerCard({
    super.key,
    required this.customer,
    required this.designs,
    required this.onOpen,
  });

  /// The key of the card of the customer [id].
  static ValueKey<String> keyOf(String id) => ValueKey('customer-card-$id');

  @override
  State<CustomerCard> createState() => _CustomerCardState();
}

class _CustomerCardState extends State<CustomerCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final customer = widget.customer;
    final phone = customer.phone.trim();
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: CustomerCard.height,
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _hover ? p.primary.withValues(alpha: 0.5) : p.hairline,
          ),
          boxShadow: [
            BoxShadow(
              color: p.shadow.withValues(alpha: _hover ? 0.08 : 0.03),
              blurRadius: _hover ? 18 : 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: widget.onOpen,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: p.band,
                    child: Text(
                      initialsOf(customer.name),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.accent,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          customer.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: p.ink,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Icon(
                              Icons.phone_outlined,
                              size: 14,
                              color: p.muted,
                            ),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                phone.isEmpty ? 'No phone number' : phone,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                // A number reads left to right whatever the
                                // language around it.
                                textDirection: TextDirection.ltr,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  color: p.muted,
                                  fontStyle: phone.isEmpty
                                      ? FontStyle.italic
                                      : FontStyle.normal,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Icon(
                              Icons.folder_outlined,
                              size: 14,
                              color: p.primary,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              designsCount(widget.designs),
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: p.primary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: p.muted),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NobodyYet extends StatelessWidget {
  final VoidCallback onNewCustomer;

  const _NobodyYet({required this.onNewCustomer});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.people_outline, size: 48, color: context.palette.muted),
          const SizedBox(height: 14),
          Text(
            'No customers yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: context.palette.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Add the people you draw for, and keep their designs together.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: context.palette.muted),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onNewCustomer,
            icon: const Icon(Icons.person_add_alt_1_outlined),
            label: const Text('New Customer'),
          ),
        ],
      ),
    ),
  );
}

class _NoMatch extends StatelessWidget {
  final String query;

  const _NoMatch({required this.query});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 32),
    child: Center(
      child: Text(
        'No customer matches "$query".',
        style: TextStyle(fontSize: 15, color: context.palette.muted),
      ),
    ),
  );
}
