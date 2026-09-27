import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/workspace.dart';
import '../theme/app_theme.dart';
import 'customer_screen.dart';

/// A new customer: who they are, how to reach them, where they are, and
/// anything the workshop wants to remember about them.
///
/// Only the name is needed — it is what finds the customer again — and
/// saving makes the customer and nothing else: no design is begun for
/// them, because a customer is somebody the workshop draws for, not a
/// drawing. Saving goes straight to the customer's own page.
class NewCustomerScreen extends ConsumerStatefulWidget {
  const NewCustomerScreen({super.key});

  static const nameField = ValueKey('customer-name');
  static const phoneField = ValueKey('customer-phone');
  static const addressField = ValueKey('customer-address');
  static const notesField = ValueKey('customer-notes');
  static const saveButton = ValueKey('customer-save');

  @override
  ConsumerState<NewCustomerScreen> createState() => _NewCustomerScreenState();
}

class _NewCustomerScreenState extends ConsumerState<NewCustomerScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _notes = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    _notes.dispose();
    super.dispose();
  }

  bool get _ready => _name.text.trim().isNotEmpty && !_saving;

  Future<void> _save() async {
    if (!_ready) return;
    setState(() => _saving = true);
    final customer = await ref
        .read(customerStoreProvider)
        .create(
          name: _name.text,
          phone: _phone.text,
          address: _address.text,
          notes: _notes.text,
        );
    if (!mounted) return;
    ref.read(customersRevisionProvider.notifier).changed();
    await Navigator.of(context)
        .pushReplacement(CustomerScreen.route(customer.id));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    Widget label(String text, {bool needed = false}) => Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 18),
      child: Text.rich(
        TextSpan(
          text: text,
          children: [
            if (!needed)
              TextSpan(
                text: '  optional',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: p.muted,
                ),
              ),
          ],
        ),
        style: TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
          color: p.ink,
        ),
      ),
    );
    InputDecoration look(String hint, IconData icon) => InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: p.muted),
      prefixIcon: Icon(icon, color: p.muted),
      filled: true,
      fillColor: p.shell,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: p.primary, width: 1.6),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('New Customer')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: p.hairline),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'New Customer',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: p.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Who are you drawing for? Their designs are kept '
                      'together under them.',
                      style: TextStyle(fontSize: 14, color: p.muted),
                    ),
                    const SizedBox(height: 8),
                    label('Name', needed: true),
                    TextField(
                      key: NewCustomerScreen.nameField,
                      controller: _name,
                      autofocus: true,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      decoration: look('e.g. Adam', Icons.person_outline),
                    ),
                    label('Phone number'),
                    TextField(
                      key: NewCustomerScreen.phoneField,
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[0-9+\-().\s]'),
                        ),
                      ],
                      decoration: look(
                        'e.g. +964 750 123 4567',
                        Icons.phone_outlined,
                      ),
                    ),
                    label('Address'),
                    TextField(
                      key: NewCustomerScreen.addressField,
                      controller: _address,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.next,
                      decoration: look(
                        'e.g. Salim Street 12, Sulaymaniyah',
                        Icons.place_outlined,
                      ),
                    ),
                    label('Notes'),
                    TextField(
                      key: NewCustomerScreen.notesField,
                      controller: _notes,
                      minLines: 3,
                      maxLines: 6,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: look(
                        'Anything to remember about them',
                        Icons.sticky_note_2_outlined,
                      ),
                    ),
                    const SizedBox(height: 28),
                    FilledButton.icon(
                      key: NewCustomerScreen.saveButton,
                      onPressed: _ready ? _save : null,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 52),
                      ),
                      icon: const Icon(Icons.check),
                      label: const Text('Save customer'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
