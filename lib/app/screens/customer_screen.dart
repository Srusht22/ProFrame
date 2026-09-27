import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/model/customer.dart';
import '../state/workspace.dart';
import '../theme/app_theme.dart';
import 'customers_screen.dart';

/// One customer: who they are, how to reach them, and — in time — their
/// designs.
///
/// This is where tapping a customer goes, and never to a drawing. It shows
/// what is kept of the person and how many designs are theirs; the designs
/// themselves, and beginning a new one for them, come to this page next.
class CustomerScreen extends ConsumerStatefulWidget {
  final String customerId;

  const CustomerScreen({super.key, required this.customerId});

  /// Where the customer's designs will be listed.
  static const designsPlaceholder = ValueKey('customer-designs-placeholder');

  @override
  ConsumerState<CustomerScreen> createState() => _CustomerScreenState();
}

class _CustomerScreenState extends ConsumerState<CustomerScreen> {
  Customer? _customer;
  int _designs = 0;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    Customer? customer;
    var designs = 0;
    try {
      customer = await ref.read(customerStoreProvider).load(widget.customerId);
      designs =
          (await ref
                  .read(designStoreProvider)
                  .page(customerId: widget.customerId, limit: 0))
              .total;
    } on Object {
      customer = null;
    }
    if (!mounted) return;
    setState(() {
      _customer = customer;
      _designs = designs;
      _loaded = true;
    });
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
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _Person(customer: customer, designs: _designs),
                        const SizedBox(height: 28),
                        Text(
                          'Designs',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: p.ink,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          key: CustomerScreen.designsPlaceholder,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 32,
                          ),
                          decoration: BoxDecoration(
                            color: p.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: p.hairline),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.folder_open_outlined,
                                size: 40,
                                color: p.muted,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                designsCount(_designs),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: p.ink,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "${customer.name}'s designs will be shown "
                                'here.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 14, color: p.muted),
                              ),
                            ],
                          ),
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

/// Who the customer is: their initials, name, phone, address and notes,
/// each shown only where something was given.
class _Person extends StatelessWidget {
  final Customer customer;
  final int designs;

  const _Person({required this.customer, required this.designs});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    Widget line(IconData icon, String text, {bool number = false}) => Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: p.muted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              textDirection: number ? TextDirection.ltr : null,
              textAlign: TextAlign.start,
              style: TextStyle(fontSize: 14.5, color: p.ink, height: 1.35),
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
                      designsCount(designs),
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
          const SizedBox(height: 6),
          if (customer.phone.isNotEmpty)
            line(Icons.phone_outlined, customer.phone, number: true),
          if (customer.address.isNotEmpty)
            line(Icons.place_outlined, customer.address),
          if (customer.notes.isNotEmpty)
            line(Icons.sticky_note_2_outlined, customer.notes),
          if (customer.phone.isEmpty &&
              customer.address.isEmpty &&
              customer.notes.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                'No phone, address or notes kept yet.',
                style: TextStyle(
                  fontSize: 13.5,
                  fontStyle: FontStyle.italic,
                  color: p.muted,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
