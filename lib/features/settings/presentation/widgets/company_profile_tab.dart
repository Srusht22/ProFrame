import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../domain/entities/app_settings.dart';
import '../../../../shared/providers/settings_notifier.dart';
import '../../../../shared/widgets/async_value_view.dart';

class CompanyProfileTab extends ConsumerWidget {
  const CompanyProfileTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsNotifierProvider);
    return AsyncValueView(
      value: settingsAsync,
      onRetry: () => ref.invalidate(settingsNotifierProvider),
      builder: (settings) => _CompanyForm(company: settings.company),
    );
  }
}

class _CompanyForm extends ConsumerStatefulWidget {
  final CompanyProfile company;
  const _CompanyForm({required this.company});

  @override
  ConsumerState<_CompanyForm> createState() => _CompanyFormState();
}

class _CompanyFormState extends ConsumerState<_CompanyForm> {
  late final TextEditingController _name;
  late final TextEditingController _address;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _website;
  late final TextEditingController _taxNumber;
  late final TextEditingController _footer;
  late final TextEditingController _terms;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    final c = widget.company;
    _name = TextEditingController(text: c.name);
    _address = TextEditingController(text: c.address);
    _phone = TextEditingController(text: c.phone);
    _email = TextEditingController(text: c.email);
    _website = TextEditingController(text: c.website);
    _taxNumber = TextEditingController(text: c.taxRegistrationNumber);
    _footer = TextEditingController(text: c.quotationFooter);
    _terms = TextEditingController(text: c.defaultTermsAndConditions);
    for (final ctrl in [_name, _address, _phone, _email, _website, _taxNumber, _footer, _terms]) {
      ctrl.addListener(() {
        if (!_dirty) setState(() => _dirty = true);
      });
    }
  }

  @override
  void dispose() {
    for (final ctrl in [_name, _address, _phone, _email, _website, _taxNumber, _footer, _terms]) {
      ctrl.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    await ref.read(settingsNotifierProvider.notifier).update(
          (current) => current.copyWith(
            company: current.company.copyWith(
              name: _name.text,
              address: _address.text,
              phone: _phone.text,
              email: _email.text,
              website: _website.text,
              taxRegistrationNumber: _taxNumber.text,
              quotationFooter: _footer.text,
              defaultTermsAndConditions: _terms.text,
            ),
          ),
        );
    if (mounted) {
      setState(() => _dirty = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Company profile saved.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Text(
          'These details automatically appear on every quotation PDF footer and header.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(controller: _name, decoration: const InputDecoration(labelText: 'Company name')),
        const SizedBox(height: AppSpacing.sm),
        TextField(controller: _address, decoration: const InputDecoration(labelText: 'Address')),
        const SizedBox(height: AppSpacing.sm),
        Row(children: [
          Expanded(child: TextField(controller: _phone, decoration: const InputDecoration(labelText: 'Phone'))),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: TextField(controller: _email, decoration: const InputDecoration(labelText: 'Email'))),
        ]),
        const SizedBox(height: AppSpacing.sm),
        Row(children: [
          Expanded(child: TextField(controller: _website, decoration: const InputDecoration(labelText: 'Website'))),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: TextField(controller: _taxNumber, decoration: const InputDecoration(labelText: 'Tax registration #'))),
        ]),
        const SizedBox(height: AppSpacing.sm),
        TextField(controller: _footer, decoration: const InputDecoration(labelText: 'Quotation PDF footer')),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _terms,
          decoration: const InputDecoration(labelText: 'Default terms & conditions'),
          maxLines: 5,
        ),
        const SizedBox(height: AppSpacing.lg),
        FilledButton(onPressed: _dirty ? _save : null, child: const Text('Save company profile')),
      ],
    );
  }
}
