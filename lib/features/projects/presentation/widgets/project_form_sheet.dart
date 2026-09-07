import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/id_generator.dart';
import '../../../../domain/entities/customer.dart';
import '../../../../domain/entities/project.dart';
import '../../../../shared/providers/customer_notifier.dart';
import '../../../../shared/providers/project_notifier.dart';

Future<void> showProjectFormSheet(BuildContext context, WidgetRef ref, {Project? existing, String? customerId}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => _ProjectFormSheet(existing: existing, initialCustomerId: customerId),
  );
}

class _ProjectFormSheet extends ConsumerStatefulWidget {
  final Project? existing;
  final String? initialCustomerId;
  const _ProjectFormSheet({this.existing, this.initialCustomerId});

  @override
  ConsumerState<_ProjectFormSheet> createState() => _ProjectFormSheetState();
}

class _ProjectFormSheetState extends ConsumerState<_ProjectFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _location;
  late final TextEditingController _description;
  String? _customerId;
  ProjectType _type = ProjectType.residential;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _location = TextEditingController(text: e?.location ?? '');
    _description = TextEditingController(text: e?.description ?? '');
    _customerId = e?.customerId ?? widget.initialCustomerId;
    _type = e?.type ?? ProjectType.residential;
  }

  @override
  void dispose() {
    _name.dispose();
    _location.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_customerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a customer.')));
      return;
    }
    setState(() => _saving = true);
    final now = DateTime.now();
    final isNew = widget.existing == null;
    final number = widget.existing?.projectNumber ?? await ref.read(projectNotifierProvider.notifier).nextProjectNumber();
    final project = Project(
      id: widget.existing?.id ?? IdGenerator.generate(),
      projectNumber: number,
      name: _name.text.trim(),
      customerId: _customerId!,
      location: _location.text.trim().isEmpty ? null : _location.text.trim(),
      type: _type,
      status: widget.existing?.status ?? ProjectStatus.draft,
      description: _description.text.trim().isEmpty ? null : _description.text.trim(),
      configurationIds: widget.existing?.configurationIds ?? const [],
      createdAt: widget.existing?.createdAt ?? now,
      updatedAt: now,
    );
    await ref.read(projectNotifierProvider.notifier).save(project, isNew: isNew);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final customers = ref.watch(customerNotifierProvider).valueOrNull ?? const <Customer>[];
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
              Text(isEdit ? 'Edit project' : 'New project', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Project name'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: AppSpacing.sm),
              DropdownButtonFormField<String>(
                value: _customerId,
                decoration: const InputDecoration(labelText: 'Customer'),
                items: [
                  for (final c in customers) DropdownMenuItem(value: c.id, child: Text(c.fullName)),
                ],
                onChanged: (v) => setState(() => _customerId = v),
              ),
              const SizedBox(height: AppSpacing.sm),
              DropdownButtonFormField<ProjectType>(
                value: _type,
                decoration: const InputDecoration(labelText: 'Project type'),
                items: [
                  for (final t in ProjectType.values) DropdownMenuItem(value: t, child: Text(t.label)),
                ],
                onChanged: (v) => setState(() => _type = v ?? ProjectType.residential),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(controller: _location, decoration: const InputDecoration(labelText: 'Location (optional)')),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: _description,
                decoration: const InputDecoration(labelText: 'Description (optional)'),
                maxLines: 3,
              ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Saving…' : 'Save project'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
