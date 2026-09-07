import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/id_generator.dart';
import '../../../../domain/entities/customer.dart';
import '../../../../shared/providers/customer_notifier.dart';

Future<void> showCustomerFormSheet(BuildContext context, WidgetRef ref, {Customer? existing}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => _CustomerFormSheet(existing: existing),
  );
}

class _CustomerFormSheet extends ConsumerStatefulWidget {
  final Customer? existing;
  const _CustomerFormSheet({this.existing});

  @override
  ConsumerState<_CustomerFormSheet> createState() => _CustomerFormSheetState();
}

class _CustomerFormSheetState extends ConsumerState<_CustomerFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _company;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _address;
  late final TextEditingController _city;
  late final TextEditingController _country;
  late final TextEditingController _notes;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.fullName ?? '');
    _company = TextEditingController(text: e?.company ?? '');
    _phone = TextEditingController(text: e?.phone ?? '');
    _email = TextEditingController(text: e?.email ?? '');
    _address = TextEditingController(text: e?.address ?? '');
    _city = TextEditingController(text: e?.city ?? '');
    _country = TextEditingController(text: e?.country ?? '');
    _notes = TextEditingController(text: e?.notes ?? '');
  }

  @override
  void dispose() {
    for (final c in [_name, _company, _phone, _email, _address, _city, _country, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final now = DateTime.now();
    final isNew = widget.existing == null;
    final customer = Customer(
      id: widget.existing?.id ?? IdGenerator.generate(),
      fullName: _name.text.trim(),
      company: _company.text.trim().isEmpty ? null : _company.text.trim(),
      phone: _phone.text.trim(),
      email: _email.text.trim().isEmpty ? null : _email.text.trim(),
      address: _address.text.trim().isEmpty ? null : _address.text.trim(),
      city: _city.text.trim().isEmpty ? null : _city.text.trim(),
      country: _country.text.trim().isEmpty ? null : _country.text.trim(),
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      createdAt: widget.existing?.createdAt ?? now,
      updatedAt: now,
    );
    await ref.read(customerNotifierProvider.notifier).save(customer, isNew: isNew);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(isEdit ? 'Edit customer' : 'Add customer', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Full name'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(controller: _company, decoration: const InputDecoration(labelText: 'Company (optional)')),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: _phone,
                decoration: const InputDecoration(labelText: 'Phone'),
                keyboardType: TextInputType.phone,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(controller: _email, decoration: const InputDecoration(labelText: 'Email (optional)')),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(controller: _address, decoration: const InputDecoration(labelText: 'Address (optional)')),
              const SizedBox(height: AppSpacing.sm),
              Row(children: [
                Expanded(child: TextFormField(controller: _city, decoration: const InputDecoration(labelText: 'City'))),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                    child:
                        TextFormField(controller: _country, decoration: const InputDecoration(labelText: 'Country'))),
              ]),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: _notes,
                decoration: const InputDecoration(labelText: 'Notes (optional)'),
                maxLines: 3,
              ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Saving…' : 'Save customer'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
